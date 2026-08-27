# INTEGRACIÓN DEL STACK EN EL PROYECTO REAL

Fecha: 2026-08-27 · Rama: `claude/github-intelligence-research-0dnet7`

Objetivo de esta sesión: **no más experimentos**. Convertir lo verificado en las
FASES 1–7 en infraestructura instalable y usable por el proyecto Roblox real.

---

## Hallazgo que condiciona todo lo demás

**El proyecto Roblox real no está en este contenedor.** Se buscó de forma
exhaustiva (`default.project.json`, `*.rbxl`, `*.rbxlx`, `rokit.toml`,
`aftman.toml`, `wally.toml` en todo el sistema de ficheros): los únicos
resultados son las plantillas internas de Rojo, los proyectos de prueba de este
repositorio y el demo de FASE 5. `/home/user` contiene sólo este repositorio.

Consecuencia: **no se puede "integrar en el proyecto real" desde aquí**. Lo que
sí se puede hacer, y es lo que se ha hecho, es construir un paquete instalable,
probarlo contra un proyecto con estructura realista, y dejar los comandos
exactos para tu máquina.

Nada del proyecto real ha sido tocado, porque no es alcanzable.

---

## Qué se ha construido

`integracion/` — paquete instalable. Ver [`integracion/README.md`](integracion/README.md).

```
integracion/
  instalar.sh              instalador no destructivo (el real, probado)
  instalar.ps1             envoltorio para PowerShell (NO verificado)
  plantilla/
    verificar.sh           la puerta completa
    .claude/hooks/         PostToolUse + Stop
    .luaurc  selene.toml  stylua.toml  rokit.toml
    tests/run.luau  tests/engine_smoke.luau
    .github/workflows/roblox-ci.yml
    herramientas/rbxdocs
    CLAUDE.fragmento.md  gitignore.fragmento  .pre-commit-config.yaml
```

Instrucciones para Windows:
[`entorno-local/WINDOWS-11-INTEGRACION.md`](entorno-local/WINDOWS-11-INTEGRACION.md).

---

## Verificado, con la prueba y el resultado

Todo contra `proyecto-ficticio`: un proyecto Rojo con estructura realista
(`ServerScriptService` / `ReplicatedStorage` / `StarterPlayer`), con
`selene.toml` y `.claude/settings.json` **preexistentes** para comprobar que el
instalador no los pisa.

### Resolución de Rojo + luau-lsp (PRIORIDAD 3)

Prueba concreta, con control, no "parece funcionar":

| Prueba | Resultado |
|---|---|
| Código correcto, con sourcemap | `EXIT=0` |
| `Puntuacion.sumar(m, "diez")` donde se espera `number`, **con** sourcemap | `TypeError: Expected this to be 'number', but got 'string'` en `(6,25)`, y resuelve la ruta de instancia `[game/ServerScriptService/Juego/Servidor]` |
| El mismo error **sin** sourcemap | `TypeError: Unknown require: game/ReplicatedStorage/Modulos/Puntuacion` — no llega ni a mirar los tipos |

El control es lo que demuestra la causa: **sin sourcemap la resolución entre
módulos no existe**, así que un error de tipos cruzado pasa desapercibido.

**Trampa encontrada y cubierta:** si una rama de `default.project.json` apunta a
un directorio sin ningún `.luau`, Rojo la omite del sourcemap entera y esa parte
del juego deja de verificarse **sin avisar**. `verificar.sh` ahora lo detecta y
falla.

### Tipos de los tests de Lune — mejora real sobre lo que había

Antes, los ficheros de `tests/` se **saltaban** la comprobación de tipos, porque
`luau-lsp` no resolvía los alias `@lune/*`. Ya no hace falta saltárselos:

```
lune setup   ->   .luaurc con  { "aliases": { "lune": "~/.lune/.typedefs/0.10.5/" } }
```

Con ese alias en `tests/.luaurc`, `luau-lsp analyze --platform=standard` sí
resuelve `require("@lune/fs")` y comprueba los tipos. Verificado: un error
deliberado da `TypeError: Expected this to be 'number', but got '{string}'` y
`EXIT=1`; el mismo fichero corregido da `EXIT=0`.

El instalador genera ese alias ejecutando `lune setup` en un directorio temporal,
para no tocar el `.luaurc` de la raíz del proyecto.

### La puerta completa (PRIORIDAD 5)

`./verificar.sh` sobre el proyecto sano:

```
  OK    sourcemap regenerado
  OK    tipos del código del juego
  OK    tipos de los tests
  OK    lint (parcial: std=luau, sin globales de Roblox; ver selene.toml)
  OK    formato
  OK    tests (3 casos)
TODO CORRECTO                                    EXIT=0
```

Cinco pruebas negativas, cada una rompiendo **una sola cosa**:

| Rotura introducida | Resultado |
|---|---|
| Error de tipos en el código del juego | `FALLA tipos: 1 error(es)` · EXIT=1 |
| Error de tipos en un `.spec.luau` de Lune | `FALLA tipos de tests: 3 error(es)` · EXIT=1 |
| Una aserción que no se cumple | `FALLA tests` + el caso concreto · EXIT=1 |
| Rama de `default.project.json` con directorio vacío | `FALLA ... desaparecen del sourcemap` · EXIT=1 |
| Formato incorrecto (y nada más) | `FALLA formato` y **el resto en OK** · EXIT=1 |

### Los hooks

| Prueba | Esperado | Obtenido |
|---|---|---|
| PostToolUse sobre fichero del juego con error de tipos | exit 2 + stderr | **exit 2**, con el `TypeError` y su posición |
| PostToolUse sobre el mismo fichero correcto | exit 0 | **exit 0** |
| PostToolUse sobre un `.spec.luau` de Lune con error | exit 2 | **exit 2**, con los 3 errores |
| Stop con el proyecto sano | exit 0 | **exit 0** |
| Stop con el proyecto roto, 4 veces seguidas | bloquear 3, luego soltar | **2, 2, 2, 0** con aviso final |
| Stop tras arreglarlo | exit 0 y contador borrado | **exit 0**, contador borrado |

**Freno de presupuesto en el hook Stop:** bloquea como mucho 3 veces seguidas
(`ROBLOX_STACK_MAX_BLOQUEOS`). A la cuarta deja pasar con un aviso muy visible en
lugar de girar en bucle quemando tokens. El contador se borra en cuanto la puerta
pasa. Es la lección de esta sesión aplicada al código.

### El instalador no destructivo

| Prueba | Resultado |
|---|---|
| `--simular` | No escribió ni un byte |
| `selene.toml` preexistente y distinto | **Intacto**. Dejó `selene.toml.propuesto` al lado y lo reportó |
| `.claude/settings.json` con un hook y permisos del usuario | **Conservados**, los nuestros añadidos, copia de seguridad con marca de tiempo |
| Segunda ejecución seguida | `CREADOS: (ninguno)` — idempotente |
| Destino sin `default.project.json` | Se niega y sale 1 |
| Detección de carpetas | Leídas de `default.project.json`, no supuestas |

### Seguridad (PRIORIDAD 6)

| Comprobación | Resultado |
|---|---|
| `gitleaks detect` sobre todo el árbol | `no leaks found` (1,54 MB escaneados) |
| Búsqueda manual de claves/tokens/contraseñas en `integracion/` | nada |
| `open_cloud_luau.py` sin credenciales | `ERROR: falta la variable de entorno ROBLOX_OPEN_CLOUD_KEY` · exit 1, sin traza |
| `open_cloud_luau.py` con credencial falsa | mensaje limpio de red, **sin traza y sin imprimir la clave** · exit 1 |

Se mantiene la regla principal: **los secretos nunca se escriben en el
repositorio**. `gitleaks` es red de seguridad, no la defensa: en FASE 1 detectó
1 de 3 claves AWS válidas.

### CI y Open Cloud (PRIORIDAD 7)

Auditoría del workflow y correcciones aplicadas:

| Punto | Antes | Ahora |
|---|---|---|
| Permisos del token | por defecto del repo | `permissions: contents: read` |
| Job con credenciales alcanzable desde un fork | no (excluye `pull_request`) | igual, y documentado |
| `globalTypes.d.luau` | se asumía presente | se descarga en el propio job |
| Tipos de los tests | no se comprobaban | paso propio con `lune setup` + `--platform=standard` |
| `roblox.yml` para selene | faltaba | `selene generate-roblox-std` en el job (allí sí hay red) |
| Ejecuciones solapadas | posibles | `concurrency` con `cancel-in-progress` |
| `rokit install` en CI | sin flag | `--no-trust-check`, que la propia fuente de rokit recomienda para CI |

`tests/engine_smoke.luau` existe ya, y **no toca gameplay**: sólo confirma que
el place arranca y que los servicios esperados existen.

**Decisión humana que falta:** crear la clave de Open Cloud acotada al universo
de desarrollo, guardarla como secreto `ROBLOX_OPEN_CLOUD_KEY`, definir
`ROBLOX_UNIVERSE_ID` y `ROBLOX_PLACE_ID` como variables, y crear el entorno
`roblox-open-cloud` en GitHub.

---

## Correcciones a artefactos anteriores

1. **`reglas/CLAUDE-fragmento-research.md` decía que en los tests «sí puede usar
   `os.exit`». Es falso.** Lune tampoco tiene `os.exit`; el corte es
   `require("@lune/process").exit(n)`. Es exactamente el fallo que dejaba la
   suite de run3b sin poder dar verde nunca. Corregido en
   `integracion/plantilla/CLAUDE.fragmento.md`.
2. **`fase-5-testing/config/luaurc-tests.json` declaraba
   `"globals": ["os.exit", "process"]`.** Mal por partida doble: `os.exit` no
   existe y `process` no es un global sino `require("@lune/process")`. Sustituido
   por el alias real que genera `lune setup`. El fichero antiguo se conserva como
   registro histórico, con la corrección anotada en `fase-5-testing/FASE-5.md`.
3. **`selene.toml` con `std = "roblox"` no funciona sin red.** Medido: `lua51`
   da 18 parse errors en Luau normal, `luau` da 0 y funciona offline, `roblox`
   falla al arrancar. El paquete instala `std = "luau"` y documenta el ascenso.
4. **`engine_smoke.luau` no es un test de Lune.** Se analizaba con
   `--platform=standard` y daba `Unknown global 'game'`. Ahora la regla es:
   es test de Lune **sólo** si es `*.spec.luau` o el propio `run.luau`; todo lo
   demás se verifica como código de Roblox.
5. **`open_cloud_luau.py`**: un 401/403 producía una traza de Python. Ahora da un
   mensaje limpio por código de error, sin imprimir nunca la clave.

---

## Lo que NO se ha tocado, a propósito

- Evidencia congelada: `fase-0-baseline/T01-run1-salida/`,
  `fase-2-code-intelligence/T01-run2-salida/`, `fase-3-rojo/T01-run3a-salida/`,
  `fase-3-rojo/T01-run3b-salida/`, `fase-8-serena/T01-run4-salida/`,
  `fase-0-baseline/TAREA-PATRON.md`, `fase-3-rojo/PRE-REGISTRO.md`.
- `~/.claude` global: sin cambios.
- Serena: sin volver a evaluar. Sigue POSPUESTA.
- UEFN: sin tocar. Sigue bloqueada por Beta Access.
- Ningún benchmark repetido. Ningún T-01 nuevo. Ninguna ejecución de Claude como
  subproceso.
