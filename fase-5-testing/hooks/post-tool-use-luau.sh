#!/usr/bin/env bash
# PostToolUse: se ejecuta tras cada escritura. Verifica SOLO el fichero tocado.
# Contrato: exit 2 + stderr  ->  Claude recibe el error y debe corregirlo.
set -uo pipefail
INPUT=$(cat)
FILE=$(printf '%s' "$INPUT" | python3 -c "
import json,sys
try: d=json.load(sys.stdin)
except Exception: print(''); raise SystemExit
print(d.get('tool_input',{}).get('file_path','') or '')" 2>/dev/null)
case "$FILE" in *.luau|*.lua) ;; *) exit 0 ;; esac
[ -f "$FILE" ] || exit 0
PROJ="${CLAUDE_PROJECT_DIR:-$(pwd)}"
DEFS="$PROJ/globalTypes.d.luau"
ERRS=""
# 1) tipos — src/ y tests/ con configuración distinta
if command -v luau-lsp >/dev/null 2>&1; then
  ARGS=(analyze --platform=roblox)
  [ -f "$DEFS" ] && ARGS+=(--defs="$DEFS")
  [ -f "$PROJ/sourcemap.json" ] && ARGS+=(--sourcemap="$PROJ/sourcemap.json")
  # Los tests corren en Lune, no en Roblox: usan alias @lune/* que luau-lsp no resuelve.
  # Para ellos la verificación de tipos NO aplica; su comprobación es EJECUTARLOS (hook Stop).
  case "$FILE" in
    */tests/*|*.test.luau|*.spec.luau) SKIP_TYPES=1 ;;
    *) SKIP_TYPES=0 ;;
  esac
  if [ "$SKIP_TYPES" = "0" ]; then
    OUT=$(luau-lsp "${ARGS[@]}" "$FILE" 2>&1 | grep -E ': (TypeError|SyntaxError)' || true)
    [ -n "$OUT" ] && ERRS="${ERRS}${OUT}"$'\n'
  fi
fi
# 2) lint
if command -v selene >/dev/null 2>&1 && [ -f "$PROJ/selene.toml" ]; then
  OUT=$(cd "$PROJ" && selene --display-style quiet "$FILE" 2>&1 | grep -E '^(error|warning)' || true)
  [ -n "$OUT" ] && ERRS="${ERRS}${OUT}"$'\n'
fi
# 3) formato
if command -v stylua >/dev/null 2>&1; then
  stylua --check "$FILE" >/dev/null 2>&1 || ERRS="${ERRS}stylua: formato incorrecto. Ejecuta: stylua $FILE"$'\n'
fi
if [ -n "$ERRS" ]; then
  printf 'Verificación fallida en %s:\n%s' "$FILE" "$ERRS" >&2
  exit 2
fi
exit 0
