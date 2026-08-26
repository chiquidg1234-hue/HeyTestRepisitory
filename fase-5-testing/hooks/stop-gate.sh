#!/usr/bin/env bash
# Stop: puerta final. El turno no se cierra como exitoso si el proyecto está roto.
# Contrato: exit 2 + stderr -> Claude debe seguir trabajando.
set -uo pipefail
cat > /dev/null
PROJ="${CLAUDE_PROJECT_DIR:-$(pwd)}"
cd "$PROJ" || exit 0
[ -f default.project.json ] || exit 0    # no es un proyecto Roblox: no aplica
FAIL=""
command -v rojo >/dev/null 2>&1 && rojo sourcemap default.project.json --output sourcemap.json >/dev/null 2>&1
if command -v luau-lsp >/dev/null 2>&1 && [ -d src ]; then
  A=(analyze --platform=roblox); [ -f globalTypes.d.luau ] && A+=(--defs=globalTypes.d.luau)
  [ -f sourcemap.json ] && A+=(--sourcemap=sourcemap.json)
  N=$(luau-lsp "${A[@]}" $(find src -name '*.luau') 2>&1 | grep -cE ': (TypeError|SyntaxError)' || true)
  [ "${N:-0}" -gt 0 ] && FAIL="${FAIL}- src/ tiene $N error(es) de tipo"$'\n'
fi
if command -v lune >/dev/null 2>&1 && [ -f tests/run.luau ]; then
  lune run tests/run.luau >/tmp/_stopgate_tests.log 2>&1 || \
    FAIL="${FAIL}- los tests fallan:"$'\n'"$(tail -5 /tmp/_stopgate_tests.log)"$'\n'
fi
if [ -n "$FAIL" ]; then
  printf 'PUERTA DE SALIDA: el proyecto no está en estado entregable.\n%s\nCorrige antes de terminar.' "$FAIL" >&2
  exit 2
fi
exit 0
