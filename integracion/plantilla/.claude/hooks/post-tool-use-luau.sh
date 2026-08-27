#!/usr/bin/env bash
# PostToolUse (matcher Write|Edit): verifica SOLO el fichero recién tocado.
# Contrato: exit 2 + stderr -> Claude ve el error y lo corrige. La herramienta ya se ejecutó.
#
# Estrategias DISTINTAS según el fichero:
#   - código del juego  -> --platform=roblox con globalTypes.d.luau y sourcemap
#   - tests de Lune     -> --platform=standard con el alias @lune (NUNCA con defs de Roblox)
set -uo pipefail

INPUT=$(cat)
PROJ="${CLAUDE_PROJECT_DIR:-$(pwd)}"
CFG="$PROJ/.claude/roblox-stack.json"

leer_json() { python3 -c "$1" 2>/dev/null; }

FILE=$(printf '%s' "$INPUT" | python3 -c "
import json,sys
try: d=json.load(sys.stdin)
except Exception: print(''); raise SystemExit
print(d.get('tool_input',{}).get('file_path','') or '')" 2>/dev/null)

case "$FILE" in *.luau|*.lua) ;; *) exit 0 ;; esac
[ -f "$FILE" ] || exit 0

# Ruta relativa al proyecto, para clasificar
REL="${FILE#"$PROJ"/}"

TESTS_DIR=$(leer_json "
import json;print(json.load(open('$CFG')).get('testsDir','tests'))" || true)
TESTS_DIR="${TESTS_DIR:-tests}"

# Un fichero es "test de Lune" SOLO si Lune lo va a ejecutar: *.spec.luau o el
# propio runner. Todo lo demás (incluido tests/engine_smoke.luau, que corre en el
# motor vía Open Cloud) se verifica como código de Roblox.
es_test=0
case "$REL" in
  *.spec.luau|*.test.luau)        es_test=1 ;;
  "$TESTS_DIR"/run.luau)          es_test=1 ;;
esac

ERRS=""

# ---------- 1) tipos ----------
if command -v luau-lsp >/dev/null 2>&1; then
  if [ "$es_test" = "1" ]; then
    # Lune, no Roblox. Los tipos de @lune/* vienen del alias en <tests>/.luaurc.
    OUT=$(luau-lsp analyze --platform=standard "$FILE" 2>&1 \
          | grep -E ': (TypeError|SyntaxError)' || true)
  else
    ARGS=(analyze --platform=roblox)
    [ -f "$PROJ/globalTypes.d.luau" ] && ARGS+=(--defs="$PROJ/globalTypes.d.luau")
    [ -f "$PROJ/sourcemap.json" ]     && ARGS+=(--sourcemap="$PROJ/sourcemap.json")
    OUT=$(cd "$PROJ" && luau-lsp "${ARGS[@]}" "$FILE" 2>&1 \
          | grep -E ': (TypeError|SyntaxError)' || true)
  fi
  [ -n "$OUT" ] && ERRS="${ERRS}${OUT}"$'\n'
fi

# ---------- 2) lint ----------
# selene con std="roblox" NECESITA roblox.yml (se genera con red desde tu máquina).
# Si no está, se avisa una sola vez y NO se bloquea: un lint roto no debe parar el trabajo.
if command -v selene >/dev/null 2>&1 && [ -f "$PROJ/selene.toml" ]; then
  if grep -q '^std *= *"roblox"' "$PROJ/selene.toml" && [ ! -f "$PROJ/roblox.yml" ]; then
    if [ ! -f "$PROJ/.claude/.aviso-selene" ]; then
      echo "AVISO: falta roblox.yml. Ejecuta 'selene generate-roblox-std' en la raíz del proyecto." >&2
      touch "$PROJ/.claude/.aviso-selene"
    fi
  else
    OUT=$(cd "$PROJ" && selene --display-style quiet "$FILE" 2>&1 | grep -E '^(error|warning)' || true)
    [ -n "$OUT" ] && ERRS="${ERRS}${OUT}"$'\n'
  fi
fi

# ---------- 3) formato ----------
if command -v stylua >/dev/null 2>&1; then
  stylua --check "$FILE" >/dev/null 2>&1 \
    || ERRS="${ERRS}stylua: formato incorrecto. Ejecuta: stylua \"$FILE\""$'\n'
fi

if [ -n "$ERRS" ]; then
  printf 'Verificación fallida en %s:\n%s' "$REL" "$ERRS" >&2
  exit 2
fi
exit 0
