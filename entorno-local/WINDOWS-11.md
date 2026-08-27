# Instalación en Windows 11 — corrección

**Contexto:** en FASE 1 te di comandos `brew install`. **Eso fue un error mío:** `brew` es de
macOS y Linux, no de Windows. Este documento lo corrige y cubre FASE 0, 1 y 2 en tu entorno real.

**Nada de esto se ha ejecutado en tu máquina.** Son instrucciones para que las ejecutes tú.

---

## Qué gestor usar

Para este stack concreto, **Scoop** es la mejor opción en Windows: instala binarios sueltos en
tu perfil de usuario, **sin privilegios de administrador**, y tiene las dos herramientas de
FASE 1 en su bucket principal.

**Verificado por mí** contra el índice real de Scoop (`ScoopInstaller/Main`, HTTP 200):

| Herramienta | Manifiesto en Scoop |
|---|---|
| `gitleaks` | ✅ `bucket/gitleaks.json` existe |
| `osv-scanner` | ✅ `bucket/osv-scanner.json` existe |

**No verificado:** los nombres de paquete en `winget`. Consulté las rutas que me parecían
correctas en el índice de `microsoft/winget-pkgs` y devolvieron 404, pero eso puede deberse a
que adivinué mal la ruta del manifiesto, no a que el paquete no exista. **No te doy comandos de
winget que no he podido confirmar.**

### Instalar Scoop (PowerShell, sin admin)

```powershell
Set-ExecutionPolicy -ExecutionPolicy RemoteSigned -Scope CurrentUser
Invoke-RestMethod -Uri https://get.scoop.sh | Invoke-Expression
```

---

## FASE 1 en Windows

```powershell
scoop install gitleaks osv-scanner
python -m pip install --user pre-commit
```

`pre-commit` va por pip porque es un paquete de Python y funciona igual en los tres sistemas.
Asegúrate de que `%APPDATA%\Python\Scripts` está en tu `PATH`, o usa `python -m pre_commit`.

### Comprobaciones que tienes pendientes

**1. gitleaks funciona y la puerta está viva** — la prueba negativa:

```powershell
cd <tu-repo>
Copy-Item <ruta>\.pre-commit-config.yaml .     # el del repo de esta investigación
pre-commit install

# Planta un secreto FALSO y comprueba que bloquea
"AWS_ACCESS_KEY_ID=AKIA3QZ7XKPLMNBV2WRT" | Out-File -Encoding ascii prueba-negativa.env  # gitleaks:allow
git add prueba-negativa.env
git commit -m "debe fallar"
echo "exit code: $LASTEXITCODE"      # DEBE ser distinto de 0

# Limpieza
git reset HEAD prueba-negativa.env
Remove-Item prueba-negativa.env
```

Si `$LASTEXITCODE` es 0, la puerta **no** está activa y hay que revisarlo.

**2. osv-scanner consulta la base de vulnerabilidades** — lo que yo no pude verificar porque
`api.osv.dev` está bloqueado en el contenedor remoto:

```powershell
mkdir $env:TEMP\osv-test; cd $env:TEMP\osv-test
@'
{ "name":"t","version":"1.0.0","lockfileVersion":3,"requires":true,
  "packages":{ "":{"name":"t","version":"1.0.0","dependencies":{"lodash":"4.17.11"}},
    "node_modules/lodash":{"version":"4.17.11","resolved":"https://registry.npmjs.org/lodash/-/lodash-4.17.11.tgz"} } }
'@ | Out-File -Encoding ascii package-lock.json
osv-scanner scan source .
```

**Debe reportar CVEs de `lodash` 4.17.11.** Si dice "0 vulnerabilities", algo va mal.

---

## FASE 2 en Windows — el camino fácil que yo no tuve

En el contenedor remoto **las descargas de GitHub Releases están bloqueadas**, así que compilé
`luau-lsp` desde la fuente con CMake. **Tú no tienes que hacer eso.**

En Windows usa **Rokit**, el gestor de toolchain del ecosistema Roblox. Instala binarios desde
las releases oficiales de GitHub y fija versiones por proyecto, que es justo lo que quieres para
que el toolchain sea reproducible.

```powershell
# 1. Instalar Rokit (verificado en su README oficial)
Invoke-RestMethod https://raw.githubusercontent.com/rojo-rbx/rokit/main/scripts/install.ps1 | Invoke-Expression

# 2. En la carpeta de tu proyecto de Roblox
rokit init
rokit add JohnnyMorganz/luau-lsp
rokit install

# 3. Comprobar
luau-lsp --version
```

Rokit escribe un `rokit.toml` con las versiones fijadas. **Ese fichero va a git**: es lo que
hace que tu toolchain sea reproducible entre máquinas y en CI.

### Alternativa sin Rokit

Descarga el `.zip` de la [release de luau-lsp](https://github.com/JohnnyMorganz/luau-lsp/releases)
para Windows, extrae `luau-lsp.exe` y ponlo en el `PATH`. Menos reproducible, igual de válido
para empezar.

---

## Diferencias de Windows que te van a morder

| Tema | Qué cambia |
|---|---|
| **Sandbox de Claude Code** | **No hay soporte nativo en Windows.** La documentación oficial dice que hay que ejecutar Claude Code dentro de una distribución **WSL2**. Si quieres el sandbox de Bash, WSL2 no es opcional |
| **Rutas en hooks** | Los hooks de `.pre-commit-config.yaml` son portables, pero cualquier hook propio que escribas con rutas `~/...` fallará. Usa rutas relativas al proyecto |
| **Finales de línea** | Git en Windows puede convertir LF↔CRLF. Para un proyecto de Roblox, añade un `.gitattributes` con `*.luau text eol=lf` para que Rojo y el LSP no se confundan |
| **`~/.claude`** | En Windows está en `%USERPROFILE%\.claude`. El `.gitignore` de lista blanca que te dejé funciona igual |

---

## Estado de tus verificaciones pendientes

| Verificación | Estado |
|---|---|
| gitleaks instalado en tu máquina | ✅ hecho (26-08-2026) |
| Prueba negativa de gitleaks en tu repo real | ✅ hecho |
| osv-scanner instalado | ✅ hecho |
| Prueba de osv-scanner con lodash | ✅ hecho |
| pre-commit instalado y hook activo | ✅ hecho |
| Decidir WSL2 sí/no para el sandbox | ✅ decidido: **sí, más adelante**. No bloqueante |

Para instalar el stack de verificación en tu proyecto Roblox real, continúa en
[`WINDOWS-11-INTEGRACION.md`](WINDOWS-11-INTEGRACION.md).
