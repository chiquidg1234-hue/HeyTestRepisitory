# CHECKPOINT — trabajo nocturno del 27-08-2026

> **Para retomar el trabajo, lee antes
> [`docs/NEXT-SESSION-CHECKPOINT.md`](docs/NEXT-SESSION-CHECKPOINT.md).**
> El estado consolidado de toda la misión está en
> [`docs/INFORME-MAESTRO-MISION-2.md`](docs/INFORME-MAESTRO-MISION-2.md).
> Este fichero es el registro concreto de la sesión del 27-08.

**Rama:** `claude/github-intelligence-research-0dnet7`
**Encargo:** integrar el stack verificado en el proyecto Roblox real. Sin
experimentos nuevos, sin benchmarks, sin T-01, sin Serena.

Documento largo con las pruebas: [`INTEGRACION.md`](INTEGRACION.md).

---

## COMPLETADO

1. **Auditoría del proyecto real (PRIORIDAD 1).** Resultado que condiciona todo:
   **el proyecto Roblox real no está en este contenedor.** Búsqueda exhaustiva de
   `default.project.json`, `*.rbxl`, `*.rbxlx`, `rokit.toml`, `aftman.toml`,
   `wally.toml` en todo el sistema de ficheros: sólo aparecen las plantillas
   internas de Rojo, los proyectos de prueba de este repositorio y el demo de
   FASE 5. `/home/user` contiene únicamente este repositorio.
2. **Paquete instalable `integracion/`** con instalador no destructivo,
   verificador, hooks, configuración, runner, CI y fragmentos de documentación.
3. **Fixture realista** (`proyecto-ficticio`, fuera del repositorio) con
   estructura `ServerScriptService` / `ReplicatedStorage` / `StarterPlayer` y
   ficheros preexistentes, para probar la integración sin tocar nada tuyo.
4. **Comprobación de tipos de los tests de Lune**, que antes se saltaba. Ahora
   funciona con el alias que genera `lune setup`.
5. **Auditoría y endurecimiento del CI y de Open Cloud** (PRIORIDAD 6 y 7).
6. **Cinco correcciones** a artefactos anteriores que estaban mal. Detalle en
   `INTEGRACION.md`, sección «Correcciones».
7. **Instrucciones exactas para Windows** en
   `entorno-local/WINDOWS-11-INTEGRACION.md`.

## VERIFICADO

Prueba → resultado. Todo ejecutado en esta sesión salvo donde se dice.

| Prueba | Resultado |
|---|---|
| Resolución entre módulos **con** sourcemap | Detecta `TypeError: Expected this to be 'number', but got 'string'` en `(6,25)` y resuelve `[game/ServerScriptService/Juego/Servidor]` |
| El mismo caso **sin** sourcemap (control) | `Unknown require: game/ReplicatedStorage/Modulos/Puntuacion` — no detecta el error |
| Rama de `default.project.json` con directorio sin `.luau` | Desaparece del sourcemap. `verificar.sh` lo detecta y falla |
| Tipos de un `.spec.luau` con error, vía alias `@lune` | `TypeError` + `EXIT=1`; corregido → `EXIT=0` |
| `./verificar.sh` con el proyecto sano | 6 comprobaciones OK, `EXIT=0` |
| 5 pruebas negativas (tipos juego / tipos test / test que falla / directorio vacío / formato) | Las 5 fallan la puerta, `EXIT=1`, cada una señalando **sólo** lo roto |
| Hook PostToolUse, fichero del juego con error | `exit 2` + `TypeError` en stderr |
| Hook PostToolUse, fichero correcto | `exit 0` |
| Hook PostToolUse, `.spec.luau` con error | `exit 2` + los 3 errores |
| Hook Stop, proyecto roto, 4 veces seguidas | `2, 2, 2, 0` — bloquea 3 y suelta con aviso |
| Hook Stop tras arreglar | `exit 0`, contador borrado |
| Instalador `--simular` | No escribió nada |
| Instalador con `selene.toml` preexistente distinto | **No lo tocó**; dejó `.propuesto` y lo reportó |
| Instalador con `.claude/settings.json` preexistente | Hooks y permisos del usuario **conservados**, copia de seguridad creada |
| Instalador ejecutado dos veces | `CREADOS: (ninguno)` — idempotente |
| Instalador contra un destino sin `default.project.json` | Se niega, `exit 1` |
| `selene` con `std` = `lua51` / `luau` / `roblox` | 18 parse errors / **0 parse errors, offline** / falla sin red |
| `gitleaks detect` sobre todo el árbol | `no leaks found`, 1,54 MB |
| `open_cloud_luau.py` sin credenciales | Mensaje claro, `exit 1`, sin traza |
| `open_cloud_luau.py` con credencial falsa | Mensaje limpio, **sin traza y sin imprimir la clave** |
| YAML del workflow | Válido; `permissions: contents: read`; job de motor excluido de `pull_request` |
| `--no-trust-check` de rokit | Existe; su propia fuente lo recomienda para CI |
| Evidencia congelada | `git status` limpio en las 6 rutas protegidas |

**No verificado, y así se declara:** `integracion/instalar.ps1` (no hay
PowerShell en el contenedor) y la respuesta HTTP real de Open Cloud (el proxy
del contenedor bloquea la salida). El camino de red sí está probado: da mensaje
limpio y no filtra la clave.

## PENDIENTE DE MI MÁQUINA WINDOWS

Todo esto está en `entorno-local/WINDOWS-11-INTEGRACION.md` con los comandos.

1. `rokit install` en la raíz del proyecto (usa el `rokit.toml` del paquete).
2. Desde **Git Bash**: `./instalar.sh /c/ruta/a/tu/proyecto --simular` y luego sin
   `--simular`. Revisa lo que salga como **PROPUESTOS**.
3. Descargar `globalTypes.d.luau` (necesita red).
4. `selene generate-roblox-std` y después subir `selene.toml` a
   `std = "roblox"` + `undefined_variable = "deny"`.
5. Pegar `gitignore.fragmento` en tu `.gitignore` y `CLAUDE.fragmento.md` en tu
   `CLAUDE.md`.
6. `./verificar.sh`. La primera vez es normal que falle el **formato**; se arregla
   con `stylua src tests`.
7. **Comprobar que los hooks están vivos**: pedirle a Claude que meta un error de
   tipos a propósito y confirmar que aparece `Verificación fallida en ...`. Un
   hook mal registrado falla en silencio, así que esta prueba no es opcional.
8. Borrar `BugTestScript` del place de prueba.

Nota: los hooks son scripts de Bash. En Windows, Claude Code los ejecuta con Git
Bash si está instalado, y sólo cae a PowerShell si no lo está — así que **hace
falta Git Bash**, que ya viene con Git para Windows.

## PENDIENTE DE CREDENCIALES

No se ha pedido, generado ni escrito ninguna. Lo que falta decidir y hacer tú:

- Clave de Open Cloud **acotada al universo de desarrollo**, con el permiso
  `universe.place.luau-execution-session:write`, guardada como secreto de GitHub
  `ROBLOX_OPEN_CLOUD_KEY`. **Nunca en un fichero.**
- `ROBLOX_UNIVERSE_ID` y `ROBLOX_PLACE_ID` como *variables* de repositorio (no son
  sensibles).
- Crear el entorno `roblox-open-cloud` en GitHub → Settings → Environments. El
  workflow ya lo exige; sin él ese job no arranca.

## BLOQUEADO

| Qué | Por qué |
|---|---|
| Integrar en el proyecto Roblox real | **No está en el contenedor.** Vive en tu Windows |
| UEFN | Beta Access en Project Settings. Requiere tu cuenta |
| Probar `instalar.ps1` | No hay PowerShell aquí |
| Probar Open Cloud de extremo a extremo | Sin credencial y con la salida de red filtrada |
| `selene generate-roblox-std` | Descarga el volcado de la API; sin red aquí |

## NO TOCADO

- Evidencia congelada: `fase-0-baseline/T01-run1-salida/`,
  `fase-2-code-intelligence/T01-run2-salida/`, `fase-3-rojo/T01-run3a-salida/`,
  `fase-3-rojo/T01-run3b-salida/`, `fase-8-serena/T01-run4-salida/`,
  `fase-0-baseline/TAREA-PATRON.md`, `fase-3-rojo/PRE-REGISTRO.md`.
  Comprobado con `git status`: limpias.
- `~/.claude` global: sin cambios.
- Serena: no reevaluada. Sigue POSPUESTA.
- Ningún benchmark repetido, ningún T-01, ninguna `n` aumentada, ninguna
  ejecución de Claude como subproceso.
- Ninguna herramienta nueva instalada.

## FICHEROS MODIFICADOS

Nuevos:
- `INTEGRACION.md`
- `entorno-local/WINDOWS-11-INTEGRACION.md`
- `integracion/` (README, `instalar.sh`, `instalar.ps1`, `plantilla/**`)

Modificados:
- `CHECKPOINT.md` (este fichero)
- `entorno-local/WINDOWS-11.md` — tabla de pendientes que ya habías hecho
- `fase-5-testing/FASE-5.md` — corrección de `luaurc-tests.json`
- `fase-7-autonomia/scripts/open_cloud_luau.py` — manejo limpio de errores HTTP

## COMANDOS EJECUTADOS (representativos)

```
find / -xdev \( -name default.project.json -o -name '*.rbxl' -o -name rokit.toml ... \)
rojo sourcemap default.project.json --output sourcemap.json
luau-lsp analyze --platform=roblox --defs=globalTypes.d.luau --sourcemap=sourcemap.json <ficheros>
luau-lsp analyze --platform=standard tests/*.spec.luau
lune setup ; lune run tests/run.luau
selene src        (con std = lua51 / luau / roblox)
stylua --check src tests
gitleaks detect --source . --no-git --redact
./instalar.sh <fixture> --simular ; ./instalar.sh <fixture>   (x3, idempotencia)
./verificar.sh                                                 (sano + 5 roturas)
echo '{"stop_hook_active":true}' | ./.claude/hooks/stop-gate.sh   (x4)
python3 scripts/open_cloud_luau.py <fichero>   (sin credencial y con credencial falsa)
```

## SIGUIENTE PASO

**Uno solo:** desde Git Bash en tu Windows, ejecutar
`./instalar.sh /c/ruta/a/tu/proyecto --simular`, leer el informe, y si te
convence, repetirlo sin `--simular`. Todo lo demás de la lista de Windows va
después y depende de eso.

## PRESUPUESTO

**No se ejecutó ninguna tarea cara.** Cero subprocesos de Claude, cero T-01,
cero benchmarks. Todo el trabajo fue con herramientas locales, que no cuestan.

Aun así, el bloque de integración consumió **~12,75 USD estimados** en tokens de
conversación: 15,3 M de tokens, de los cuales **14,8 M son `cache_read`**, es
decir, releer un contexto ya enorme en cada turno.

Esto confirma el diagnóstico del informe anterior: **el gasto de estas sesiones
no viene de los experimentos, viene de la longitud del contexto.** La sesión
lleva 3 misiones acumuladas. La medida correcta no es trabajar menos, es
**empezar en una sesión nueva** para el próximo bloque de trabajo.

---

## Estado global por fase

| Fase | Estado |
|---|---|
| 0 Baseline | CERRADA (congelada) |
| 1 Seguridad | CERRADA con limitación conocida (gitleaks parcial) |
| 2 Code intelligence | CERRADA con corrección |
| 3 Rojo | CERRADA — H1 sí, H2 no |
| 4 Research | CERRADA |
| 5 Testing | CERRADA — y **mejorada**: los tests ya se comprueban de tipos |
| 6 Motor | CERRADA (Roblox, evidencia externa tuya) · BLOQUEADA (UEFN) |
| 7 Autonomía | PARCIAL — CI endurecido; falta la clave |
| 8 Serena | CERRADA — POSPUESTA |
| 9 Integración | **PAQUETE LISTO Y PROBADO** — falta ejecutarlo en tu máquina |
