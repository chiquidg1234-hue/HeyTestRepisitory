#!/usr/bin/env bash
# Instala el stack de verificación en un proyecto Roblox EXISTENTE.
#
#   ./instalar.sh /ruta/al/proyecto            # aplica
#   ./instalar.sh /ruta/al/proyecto --simular  # no escribe nada, solo dice qué haría
#
# Reglas de este instalador:
#   - NO sobrescribe nada. Si un fichero ya existe y es distinto, deja
#     "<fichero>.propuesto" al lado y te lo dice. Tú decides.
#   - La única excepción es .claude/settings.json, que se FUSIONA para no perder
#     tus hooks, y siempre con copia de seguridad previa.
#   - No toca código del juego. No escribe credenciales. No borra nada.
#   - Es idempotente: ejecutarlo dos veces no cambia nada la segunda vez.
set -uo pipefail

AQUI="$(cd "$(dirname "$0")" && pwd)"
PLANTILLA="$AQUI/plantilla"
DESTINO="${1:-}"
SIMULAR=0; [ "${2:-}" = "--simular" ] && SIMULAR=1

[ -n "$DESTINO" ] || { echo "uso: $0 <ruta-del-proyecto> [--simular]"; exit 1; }
DESTINO="$(cd "$DESTINO" 2>/dev/null && pwd)" || { echo "ERROR: no existe $1"; exit 1; }

if [ ! -f "$DESTINO/default.project.json" ]; then
  echo "ERROR: $DESTINO no tiene default.project.json."
  echo "Esto no parece la raíz de un proyecto Rojo. No hago nada."
  exit 1
fi

CREADOS=(); PROPUESTOS=(); IGUALES=()

copiar() {  # copiar <origen-relativo-en-plantilla> <destino-relativo>
  local o="$PLANTILLA/$1" d="$DESTINO/$2"
  [ -f "$o" ] || return 0
  if [ -f "$d" ]; then
    if cmp -s "$o" "$d"; then IGUALES+=("$2"); return 0; fi
    if [ "$SIMULAR" = "0" ]; then mkdir -p "$(dirname "$d")"; cp "$o" "$d.propuesto"; fi
    PROPUESTOS+=("$2"); return 0
  fi
  if [ "$SIMULAR" = "0" ]; then mkdir -p "$(dirname "$d")"; cp "$o" "$d"; fi
  CREADOS+=("$2")
}

echo "== Proyecto destino: $DESTINO"
[ "$SIMULAR" = "1" ] && echo "== MODO SIMULACIÓN: no se escribe nada"
echo

# ---------------------------------------------------------------- 1. detectar
# Las carpetas de código salen del propio default.project.json, no se suponen.
DETECTADO=$(cd "$DESTINO" && python3 - <<'PY'
import json,os
p=json.load(open("default.project.json"))
rutas=[]
def walk(n):
    if isinstance(n,dict):
        r=n.get("$path")
        if isinstance(r,str): rutas.append(r)
        for k,v in n.items():
            if not k.startswith("$"): walk(v)
walk(p.get("tree",{}))
raices=sorted({r.split("/")[0].split("\\")[0] for r in rutas if os.path.isdir(r.split("/")[0].split("\\")[0])})
print(" ".join(raices) if raices else "src")
PY
) || DETECTADO="src"
echo "Carpetas de código detectadas en default.project.json: $DETECTADO"

TESTS_DIR="tests"
[ -d "$DESTINO/test" ] && [ ! -d "$DESTINO/tests" ] && TESTS_DIR="test"
echo "Carpeta de tests: $TESTS_DIR"
echo

# ---------------------------------------------------------------- 2. ficheros
for f in .luaurc selene.toml stylua.toml rokit.toml verificar.sh \
         .pre-commit-config.yaml CLAUDE.fragmento.md gitignore.fragmento; do
  copiar "$f" "$f"
done
copiar ".claude/hooks/post-tool-use-luau.sh" ".claude/hooks/post-tool-use-luau.sh"
copiar ".claude/hooks/stop-gate.sh"          ".claude/hooks/stop-gate.sh"
copiar "tests/run.luau"                      "$TESTS_DIR/run.luau"
copiar "tests/engine_smoke.luau"             "$TESTS_DIR/engine_smoke.luau"
copiar ".github/workflows/roblox-ci.yml"     ".github/workflows/roblox-ci.yml"
copiar "herramientas/rbxdocs"                "herramientas/rbxdocs"
if [ -f "$AQUI/../fase-7-autonomia/scripts/open_cloud_luau.py" ]; then
  if [ ! -f "$DESTINO/scripts/open_cloud_luau.py" ]; then
    [ "$SIMULAR" = "0" ] && { mkdir -p "$DESTINO/scripts"; cp "$AQUI/../fase-7-autonomia/scripts/open_cloud_luau.py" "$DESTINO/scripts/"; }
    CREADOS+=("scripts/open_cloud_luau.py")
  else IGUALES+=("scripts/open_cloud_luau.py"); fi
fi
[ "$SIMULAR" = "0" ] && chmod +x "$DESTINO/verificar.sh" "$DESTINO/.claude/hooks/"*.sh "$DESTINO/herramientas/rbxdocs" 2>/dev/null

# ---------------------------------------------------- 3. configuración del stack
CFG="$DESTINO/.claude/roblox-stack.json"
CFG_EXISTIA=0; [ -f "$CFG" ] && CFG_EXISTIA=1
if [ "$SIMULAR" = "0" ]; then
  mkdir -p "$DESTINO/.claude"
  python3 - "$CFG" "$TESTS_DIR" $DETECTADO <<'PY'
import json,sys
destino, tests, *dirs = sys.argv[1:]
json.dump({"sourceDirs": dirs or ["src"], "testsDir": tests}, open(destino,"w"), indent=2)
PY
fi
if [ "$CFG_EXISTIA" = "1" ]; then IGUALES+=(".claude/roblox-stack.json"); else CREADOS+=(".claude/roblox-stack.json"); fi

# ------------------------------------------- 4. alias de Lune para los tests
# Se obtiene ejecutando 'lune setup' en un directorio temporal, para no tocar
# el .luaurc de la raíz del proyecto.
if command -v lune >/dev/null 2>&1; then
  TMP=$(mktemp -d); (cd "$TMP" && lune setup >/dev/null 2>&1)
  if [ -f "$TMP/.luaurc" ]; then
    if [ -f "$DESTINO/$TESTS_DIR/.luaurc" ]; then
      IGUALES+=("$TESTS_DIR/.luaurc (ya existía, no se toca)")
    else
      [ "$SIMULAR" = "0" ] && { mkdir -p "$DESTINO/$TESTS_DIR"; cp "$TMP/.luaurc" "$DESTINO/$TESTS_DIR/.luaurc"; }
      CREADOS+=("$TESTS_DIR/.luaurc (alias @lune)")
    fi
  fi
  rm -rf "$TMP"
else
  echo "AVISO: lune no está en PATH; no se pudo generar el alias @lune de los tests."
fi

# ------------------------------------------------- 5. fusionar settings.json
S="$DESTINO/.claude/settings.json"
RES_SETTINGS=$(SIMULAR="$SIMULAR" python3 - "$S" <<'PY'
import json,os,sys,shutil,time
ruta=sys.argv[1]; simular=os.environ.get("SIMULAR")=="1"
PTU={"matcher":"Write|Edit","hooks":[{"type":"command",
     "command":"${CLAUDE_PROJECT_DIR}/.claude/hooks/post-tool-use-luau.sh"}]}
STOP={"matcher":"","hooks":[{"type":"command",
     "command":"${CLAUDE_PROJECT_DIR}/.claude/hooks/stop-gate.sh"}]}
try: cfg=json.load(open(ruta))
except Exception: cfg={}
hooks=cfg.setdefault("hooks",{})
cambios=[]
def ya(lista,marca):
    return any(marca in json.dumps(e) for e in lista)
for clave,entrada,marca in (("PostToolUse",PTU,"post-tool-use-luau.sh"),
                            ("Stop",STOP,"stop-gate.sh")):
    lista=hooks.setdefault(clave,[])
    if ya(lista,marca): continue
    lista.append(entrada); cambios.append(clave)
if not cambios:
    print("settings.json: ya estaba configurado, no se toca"); raise SystemExit
if simular:
    print("settings.json: se AÑADIRÍA "+", ".join(cambios)+" (conservando lo existente)"); raise SystemExit
if os.path.exists(ruta):
    copia=ruta+".bak-"+time.strftime("%Y%m%d-%H%M%S"); shutil.copy2(ruta,copia)
    print("settings.json: copia de seguridad en "+os.path.basename(copia))
os.makedirs(os.path.dirname(ruta),exist_ok=True)
json.dump(cfg,open(ruta,"w"),indent=2,ensure_ascii=False)
print("settings.json: añadido "+", ".join(cambios)+" conservando lo existente")
PY
)

# ------------------------------------------------------------------ 6. informe
echo "--- CREADOS ---";     printf '  %s\n' "${CREADOS[@]:-(ninguno)}"
echo "--- YA IGUALES ---";  printf '  %s\n' "${IGUALES[@]:-(ninguno)}"
echo "--- PROPUESTOS (existían y son distintos; revisa el .propuesto) ---"
printf '  %s\n' "${PROPUESTOS[@]:-(ninguno)}"
echo "--- SETTINGS ---";    echo "  $RES_SETTINGS"
echo
echo "--- TE FALTA HACER A MANO ---"
echo "  1. Añadir a .gitignore lo que hay en gitignore.fragmento"
echo "  2. Pegar CLAUDE.fragmento.md dentro de tu CLAUDE.md"
echo "  3. curl -sSfL -o globalTypes.d.luau https://raw.githubusercontent.com/JohnnyMorganz/luau-lsp/main/scripts/globalTypes.d.luau"
echo "  4. selene generate-roblox-std        (necesita red; deja roblox.yml en la raíz)"
echo "  5. ./verificar.sh"
