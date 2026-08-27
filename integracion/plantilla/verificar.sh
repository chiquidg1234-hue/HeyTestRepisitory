#!/usr/bin/env bash
# Puerta de verificación completa del proyecto. La misma que usan el hook Stop y la CI.
#   ./verificar.sh          -> verifica todo
#   ./verificar.sh --rapido -> salta lint y formato
# Sale 0 si todo está bien, 1 si algo falla. No modifica código; sólo regenera el sourcemap.
set -uo pipefail
cd "$(dirname "$0")" || exit 1

RAPIDO=0; [ "${1:-}" = "--rapido" ] && RAPIDO=1
CFG=".claude/roblox-stack.json"
LEE() { python3 -c "
import json
try: c=json.load(open('$CFG'))
except Exception: c={}
print($1)" 2>/dev/null; }
TESTS_DIR=$(LEE "c.get('testsDir','tests')"); TESTS_DIR="${TESTS_DIR:-tests}"
SRC_DIRS=$(LEE "' '.join(c.get('sourceDirs',['src']))"); SRC_DIRS="${SRC_DIRS:-src}"

ok()   { printf '  \033[32mOK\033[0m    %s\n' "$1"; }
mal()  { printf '  \033[31mFALLA\033[0m %s\n' "$1"; FALLOS=$((FALLOS+1)); }
salta(){ printf '  --    %s\n' "$1"; }
FALLOS=0

echo "Proyecto: $(pwd)"
echo "Código:   $SRC_DIRS"
echo "Tests:    $TESTS_DIR"
echo

# 0) sourcemap
if command -v rojo >/dev/null 2>&1 && [ -f default.project.json ]; then
  if rojo sourcemap default.project.json --output sourcemap.json >/dev/null 2>&1; then
    ok "sourcemap regenerado"
    # ramas perdidas por directorios vacíos
    VACIOS=$(python3 - <<'PY' 2>/dev/null
import json,os
try: p=json.load(open("default.project.json"))
except Exception: raise SystemExit
malos=[]
def walk(n):
    if isinstance(n,dict):
        ruta=n.get("$path")
        if isinstance(ruta,str) and os.path.isdir(ruta) and not any(
            f.endswith((".luau",".lua")) for _,_,fs in os.walk(ruta) for f in fs):
            malos.append(ruta)
        for k,v in n.items():
            if not k.startswith("$"): walk(v)
walk(p.get("tree",{}))
print(" ".join(malos))
PY
)
    [ -n "$VACIOS" ] && mal "estas rutas de default.project.json no tienen ningún .luau y desaparecen del sourcemap: $VACIOS"
  else
    mal "rojo sourcemap"
  fi
else
  salta "rojo no disponible o no hay default.project.json"
fi

# 1) tipos del código del juego
if command -v luau-lsp >/dev/null 2>&1; then
  F=$(for d in $SRC_DIRS; do [ -d "$d" ] && find "$d" -name '*.luau' -print; done
      [ -d "$TESTS_DIR" ] && find "$TESTS_DIR" -name '*.luau' \
          ! -name '*.spec.luau' ! -name 'run.luau' -print)
  if [ -n "$F" ]; then
    A=(analyze --platform=roblox)
    [ -f globalTypes.d.luau ] && A+=(--defs=globalTypes.d.luau) || salta "sin globalTypes.d.luau: los tipos de la API de Roblox NO se comprueban"
    [ -f sourcemap.json ] && A+=(--sourcemap=sourcemap.json)
    N=$(printf '%s\n' "$F" | xargs luau-lsp "${A[@]}" 2>&1 | grep -E ': (TypeError|SyntaxError)' | tee /tmp/_v_tipos.txt | wc -l)
    if [ "$N" -eq 0 ]; then ok "tipos del código del juego"; else mal "tipos: $N error(es)"; sed 's/^/        /' /tmp/_v_tipos.txt | head -20; fi
  else
    salta "no se encontró código en: $SRC_DIRS"
  fi
fi

# 2) tipos de los tests (Lune, sin definiciones de Roblox)
if command -v luau-lsp >/dev/null 2>&1 && [ -d "$TESTS_DIR" ]; then
  if [ -f "$TESTS_DIR/.luaurc" ]; then
    # Solo lo que ejecuta Lune. engine_smoke.luau corre en el MOTOR y se
    # analiza con el resto del código de Roblox, no aquí.
    T=$(find "$TESTS_DIR" \( -name '*.spec.luau' -o -name 'run.luau' \) -print)
    N=$(printf '%s\n' "$T" | xargs luau-lsp analyze --platform=standard 2>&1 | grep -E ': (TypeError|SyntaxError)' | tee /tmp/_v_tt.txt | wc -l)
    if [ "$N" -eq 0 ]; then ok "tipos de los tests"; else mal "tipos de tests: $N error(es)"; sed 's/^/        /' /tmp/_v_tt.txt | head -20; fi
  else
    salta "sin $TESTS_DIR/.luaurc: no se pueden resolver los alias @lune. Ejecuta el instalador."
  fi
fi

# 3) lint
if [ "$RAPIDO" = "0" ] && command -v selene >/dev/null 2>&1 && [ -f selene.toml ]; then
  if grep -q '^std *= *"roblox"' selene.toml && [ ! -f roblox.yml ]; then
    salta "selene: std=roblox pero falta roblox.yml. Ejecuta: selene generate-roblox-std"
  else
    if selene $SRC_DIRS >/tmp/_v_lint.txt 2>&1; then
      if grep -q '^std *= *"luau"' selene.toml; then
        ok "lint (parcial: std=luau, sin globales de Roblox; ver selene.toml)"
      else ok "lint"; fi
    else mal "lint"; tail -20 /tmp/_v_lint.txt | sed 's/^/        /'; fi
  fi
fi

# 4) formato
if [ "$RAPIDO" = "0" ] && command -v stylua >/dev/null 2>&1; then
  if stylua --check $SRC_DIRS "$TESTS_DIR" >/tmp/_v_fmt.txt 2>&1; then ok "formato"; else mal "formato (arregla con: stylua $SRC_DIRS $TESTS_DIR)"; fi
fi

# 5) tests
if command -v lune >/dev/null 2>&1 && [ -f "$TESTS_DIR/run.luau" ]; then
  if lune run "$TESTS_DIR/run.luau" >/tmp/_v_tests.txt 2>&1; then
    ok "tests ($(grep -c '\[OK\]' /tmp/_v_tests.txt) casos)"
  else
    mal "tests"; tail -15 /tmp/_v_tests.txt | sed 's/^/        /'
  fi
else
  salta "no hay $TESTS_DIR/run.luau o falta lune"
fi

echo
if [ "$FALLOS" -eq 0 ]; then echo "TODO CORRECTO"; exit 0; fi
echo "$FALLOS comprobación(es) fallida(s)"; exit 1
