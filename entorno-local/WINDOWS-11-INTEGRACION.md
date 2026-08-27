# Windows 11 — instalar el stack en tu proyecto Roblox real

Comandos exactos. Nada de esto se ha ejecutado en tu máquina: **el proyecto real
no está en el contenedor**, así que esta parte sólo puedes hacerla tú.

Orden recomendado. Cada bloque es independiente y se puede repetir sin daño.

---

## 1. Toolchain, con versiones fijadas (PowerShell)

```powershell
# Rokit, si aún no lo tienes
Invoke-RestMethod https://raw.githubusercontent.com/rojo-rbx/rokit/main/scripts/install.ps1 | Invoke-Expression

cd C:\ruta\a\tu\proyecto
rokit install        # usa el rokit.toml que instala el paquete de integración
```

`rokit.toml` fija: rojo 7.7.0 · luau-lsp 1.69.0 · selene 0.31.0 · stylua 2.5.2 ·
lune 0.10.5. Son las versiones con las que se midió todo. No las subas sin
volver a comprobar; en concreto **StyLua necesita estar compilado con la feature
`luau`** o no parsea el código (`cargo install stylua` a secas produce un binario
que no sirve; los binarios oficiales de la release sí).

## 2. Instalar el paquete de integración

Desde **Git Bash** (viene con Git para Windows):

```bash
cd /c/ruta/a/este/repositorio/integracion
./instalar.sh /c/ruta/a/tu/proyecto --simular    # primero mira qué haría
./instalar.sh /c/ruta/a/tu/proyecto              # luego hazlo
```

Lee el informe que imprime. Si aparece algo en **PROPUESTOS**, ese fichero ya
existía en tu proyecto y **no se ha tocado**: tienes el nuestro al lado como
`fichero.propuesto` y decides tú.

## 3. Definiciones de la API de Roblox (necesita red)

```powershell
cd C:\ruta\a\tu\proyecto
curl.exe -sSfL -o globalTypes.d.luau `
  https://raw.githubusercontent.com/JohnnyMorganz/luau-lsp/main/scripts/globalTypes.d.luau
```

Sin este fichero, `luau-lsp` no comprueba los tipos de la API de Roblox y el
verificador te lo dirá con un `--` en vez de un `OK`. **No lo subas a git**: está
en `gitignore.fragmento` porque se regenera y envejece.

## 4. Completar selene (necesita red)

```powershell
cd C:\ruta\a\tu\proyecto
selene generate-roblox-std          # deja roblox.yml en la raíz
```

Después, edita `selene.toml` y cambia estas dos líneas:

```toml
std = "roblox"
undefined_variable = "deny"
```

**Por qué no viene así de fábrica:** `std = "roblox"` descarga el volcado de la
API al arrancar y sin red falla entero. Medido en el contenedor:

| `std` | Resultado |
|---|---|
| `lua51` | **18 parse errors** — no entiende `export type` ni `: string` |
| `luau` | **0 parse errors**, funciona sin red, pero no conoce `game`/`workspace` |
| `roblox` | `ERROR: failed to collect roblox standard library` sin red |

Por eso el paquete instala `std = "luau"` con `undefined_variable = "allow"`:
es lo mejor que funciona hoy, y el paso 4 lo completa.

## 5. Pegar los fragmentos

- `gitignore.fragmento` → al final de tu `.gitignore`
- `CLAUDE.fragmento.md` → dentro de tu `CLAUDE.md`

No se hace automáticamente a propósito: son ficheros tuyos con contenido tuyo.

## 6. Documentación local de Roblox (opcional, 64 MB)

```powershell
git clone --depth 1 https://github.com/Roblox/creator-docs.git `
  "$env:LOCALAPPDATA\creator-docs"
$env:RBXDOCS = "$env:LOCALAPPDATA\creator-docs"     # hazlo permanente si te sirve
```

El helper `herramientas/rbxdocs` es un script de Bash: se usa desde Git Bash.
Medido: 10 ms en local frente a 435 ms por web.

## 7. Comprobar que todo funciona

Desde Git Bash, en la raíz del proyecto:

```bash
./verificar.sh
```

Salida esperada, seis líneas: sourcemap · tipos del código · tipos de los tests ·
lint · formato · tests. La primera vez es normal que falle el **formato**: tu
código no está pasado por StyLua todavía. Arreglo:

```bash
stylua src tests          # ajusta a tus carpetas reales
```

## 8. Comprobar que los hooks están vivos

Es la prueba que de verdad importa, porque un hook mal registrado falla en
silencio. En una sesión de Claude Code dentro del proyecto, pídele que
introduzca a propósito un error de tipos en un fichero `.luau` del juego.

**Debe aparecer un mensaje `Verificación fallida en ...` y Claude debe
corregirlo solo.** Si no aparece nada, el hook no se está ejecutando: mira
`.claude/settings.json` y comprueba que las rutas de
`${CLAUDE_PROJECT_DIR}/.claude/hooks/...` existen.

Nota: en Windows, Claude Code ejecuta los hooks con **Git Bash** si está
instalado, y sólo cae a PowerShell si no lo está. Los hooks de este paquete son
scripts de Bash, así que **necesitas Git Bash**. Ya lo tienes si instalaste Git
para Windows con las opciones por defecto.

---

## Lo que sigue sin poder hacerse desde aquí

| Acción | Por qué es tuya |
|---|---|
| **UEFN Beta Access** | Project Settings → Beta Access → UEFN MCP Toolset. Requiere tu cuenta |
| **Clave de Open Cloud** | Créala acotada al universo de **desarrollo**, con el permiso `universe.place.luau-execution-session:write`. Guárdala en GitHub → Settings → Secrets → Actions como `ROBLOX_OPEN_CLOUD_KEY`. **Nunca en un fichero** |
| `ROBLOX_UNIVERSE_ID` / `ROBLOX_PLACE_ID` | Como *variables* de repositorio (no secretos): no son sensibles |
| **Entorno `roblox-open-cloud`** | GitHub → Settings → Environments → crear con ese nombre. El workflow ya lo exige; sin él ese job no arranca |
| **Borrar `BugTestScript`** | Está en tu place de prueba. Aquí no hay Studio |
