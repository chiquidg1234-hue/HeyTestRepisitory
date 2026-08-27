#!/usr/bin/env bash
# Stop: puerta final. El turno no se cierra si el proyecto no está entregable.
# Contrato: exit 2 + stderr -> Claude NO puede parar y sigue trabajando.
#
# Freno de presupuesto: bloquea como mucho MAX_BLOQUEOS veces seguidas. Si tras eso
# sigue roto, deja pasar con un aviso muy visible en lugar de girar en bucle
# quemando tokens. El contador se borra en cuanto la puerta pasa.
set -uo pipefail
MAX_BLOQUEOS="${ROBLOX_STACK_MAX_BLOQUEOS:-3}"

INPUT=$(cat)
PROJ="${CLAUDE_PROJECT_DIR:-$(pwd)}"
cd "$PROJ" || exit 0
[ -f default.project.json ] || exit 0     # no es un proyecto Roblox: la puerta no aplica

CONTADOR="$PROJ/.claude/.stop-gate-bloqueos"

# Si Claude ya viene de un bloqueo de esta misma puerta, el propio payload lo dice.
YA_ACTIVO=$(printf '%s' "$INPUT" | python3 -c "
import json,sys
try: print('1' if json.load(sys.stdin).get('stop_hook_active') else '0')
except Exception: print('0')" 2>/dev/null)

CFG="$PROJ/.claude/roblox-stack.json"
LEE() { python3 -c "
import json
try: c=json.load(open('$CFG'))
except Exception: c={}
print($1)" 2>/dev/null; }
TESTS_DIR=$(LEE "c.get('testsDir','tests')"); TESTS_DIR="${TESTS_DIR:-tests}"
SRC_DIRS=$(LEE "' '.join(c.get('sourceDirs',['src']))"); SRC_DIRS="${SRC_DIRS:-src}"

FALLO=""

command -v rojo >/dev/null 2>&1 && \
  rojo sourcemap default.project.json --output sourcemap.json >/dev/null 2>&1

# --- tipos del código del juego ---
if command -v luau-lsp >/dev/null 2>&1; then
  FICHEROS=$(for d in $SRC_DIRS; do [ -d "$d" ] && find "$d" -name '*.luau' -print; done)
  if [ -n "$FICHEROS" ]; then
    A=(analyze --platform=roblox)
    [ -f globalTypes.d.luau ] && A+=(--defs=globalTypes.d.luau)
    [ -f sourcemap.json ]     && A+=(--sourcemap=sourcemap.json)
    N=$(printf '%s\n' "$FICHEROS" | xargs luau-lsp "${A[@]}" 2>&1 \
        | grep -cE ': (TypeError|SyntaxError)' || true)
    [ "${N:-0}" -gt 0 ] && FALLO="${FALLO}- el código del juego tiene ${N} error(es) de tipo"$'\n'
  fi
fi

# --- tests, con su propia estrategia ---
if command -v lune >/dev/null 2>&1 && [ -f "$TESTS_DIR/run.luau" ]; then
  LOG=$(mktemp)
  if ! lune run "$TESTS_DIR/run.luau" >"$LOG" 2>&1; then
    FALLO="${FALLO}- los tests fallan:"$'\n'"$(tail -8 "$LOG")"$'\n'
  fi
  rm -f "$LOG"
fi

if [ -z "$FALLO" ]; then
  rm -f "$CONTADOR"
  exit 0
fi

N_PREV=0; [ -f "$CONTADOR" ] && N_PREV=$(cat "$CONTADOR" 2>/dev/null || echo 0)
case "$N_PREV" in ''|*[!0-9]*) N_PREV=0 ;; esac

if [ "$YA_ACTIVO" = "1" ] || [ "$N_PREV" -gt 0 ]; then
  N_PREV=$((N_PREV + 1))
else
  N_PREV=1
fi
echo "$N_PREV" > "$CONTADOR"

if [ "$N_PREV" -gt "$MAX_BLOQUEOS" ]; then
  rm -f "$CONTADOR"
  printf 'PUERTA DE SALIDA: sigue roto tras %s intentos. Se deja pasar para no gastar más presupuesto.\n%s\nARREGLA ESTO ANTES DE DAR EL TRABAJO POR BUENO.\n' \
    "$MAX_BLOQUEOS" "$FALLO" >&2
  exit 0
fi

printf 'PUERTA DE SALIDA (intento %s de %s): el proyecto no está en estado entregable.\n%s\nCorrige antes de terminar.' \
  "$N_PREV" "$MAX_BLOQUEOS" "$FALLO" >&2
exit 2
