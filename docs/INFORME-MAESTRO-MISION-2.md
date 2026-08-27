# INFORME MAESTRO — MISIÓN 2: Claude Code como agente de desarrollo Roblox

**Fecha de cierre:** 27-08-2026
**Rama:** `claude/github-intelligence-research-0dnet7`
**Alcance temporal:** 25 → 27 de agosto de 2026
**Naturaleza de este documento:** fuente de verdad única. Sustituye a cualquier
conclusión anterior que lo contradiga. Donde un documento antiguo dice otra cosa,
manda éste.

---

## A. RESUMEN EJECUTIVO

**El objetivo.** Convertir Claude Code en un agente capaz de desarrollar juegos
de Roblox de forma autónoma: escribir Luau, verificarlo sin ayuda humana,
probarlo dentro del motor, ver el resultado y corregirse solo. El principio
rector fue **capacidad > cantidad**: no acumular herramientas, sino demostrar
que cada una añade una capacidad que antes no existía.

**Qué se investigó.** Primero un rastreo del ecosistema público de GitHub (232
repositorios medidos con clones ciegos para ver mantenimiento real, no estrellas)
y del ecosistema Roblox/UEFN (75 más). Después, ocho fases de ejecución medida:
cada herramienta se instaló, se ejecutó contra una tarea patrón congelada, y se
midió el antes y el después con pruebas positivas **y negativas**.

**Qué quedó verificado.** El ciclo completo de verificación estática y de tests
funciona y bloquea de verdad: tipos con `luau-lsp` sobre un sourcemap de Rojo,
lint con `selene`, formato con `StyLua`, tests headless con `Lune`, y dos hooks
que impiden cerrar el turno con el proyecto roto. La métrica dura: la
verificación automática pasó de **0/2 a 2/2**, y los **10 errores de tipo** que
el baseline entregaba pasaron a **0**. El ciclo dentro del motor (editar →
jugar → leer consola → corregir) también quedó demostrado, aunque **en tu
máquina Windows, no aquí**.

**Qué quedó bloqueado.** UEFN entero, por Beta Access. La ejecución en servidor
real vía Open Cloud, por falta de una credencial que sólo tú puedes crear. Y la
integración en el proyecto Roblox real, porque **ese proyecto no está en este
contenedor**: vive en tu Windows.

**Estado actual.** Toda la investigación está cerrada. Existe un paquete
instalable, probado contra dos proyectos de estructura realista, listo para
ejecutarse sobre tu proyecto. Nada del proyecto real ha sido tocado.

**Siguiente paso recomendado.** Uno solo: desde Git Bash en tu Windows, ejecutar
`integracion/instalar.sh /c/ruta/a/tu/proyecto --simular`, leer el informe, y si
convence, repetirlo sin `--simular`. Todo lo demás depende de eso.

---

## B. TABLA MAESTRA DE FASES

| Fase | Objetivo | Estado | Resultado | Evidencia | Pendiente |
|---|---|---|---|---|---|
| **0 — Baseline** | Medir el punto de partida sin herramientas | ✅ COMPLETADA | 934 029 tokens · 11 turnos · 479 s · $0,9739 · contexto de arranque 34 830. **Verificación 0/2** y **10 errores de tipo entregados** | `fase-0-baseline/BASELINE.md`, `T01-run1-salida/` (congelada), `T01-run1-result.json` | Nada. Es la referencia |
| **1 — Seguridad** | Puerta de secretos y de dependencias | ⚠️ COMPLETADA CON LIMITACIONES | `pre-commit` + `gitleaks` bloquean commits de verdad (bloquearon dos míos). **`gitleaks` detecta 1 de 3 claves AWS sintácticamente válidas**. `osv-scanner` no verificable aquí | `fase-1-seguridad/FASE-1.md` + **`CORRECCION.md`**, `evidencia/*.json` | Asumir que gitleaks no es red completa. Tú ya verificaste osv-scanner en local |
| **2 — Code intelligence** | Tipos de Luau accionables | ⚠️ COMPLETADA CON CORRECCIÓN GRAVE | `luau-lsp` 1.69.0 compilado con clang. Encuentra los 10 errores reales del baseline. **El titular causal original era falso** (ver §D-2) | `fase-2-code-intelligence/FASE-2.md` + **`CORRECCION.md`**, `T01-run2-salida/` (congelada) | Nada |
| **3 — Rojo** | ¿El sourcemap mejora la señal? | ✅ COMPLETADA | **H1 confirmada, H2 NO confirmada.** El código entregado, analizado **sin** sourcemap, arroja 32 errores (run3a) y 21 (run3b), casi todos `Unknown require`; **con** sourcemap, 0 y 2. Turnos 27 → 24: dentro del ruido | `fase-3-rojo/PRE-REGISTRO.md` (congelado, escrito **antes**), `FASE-3.md`, `T01-run3a/3b-salida/` (congeladas) | Nada. No repetir con más n |
| **4 — Research** | Documentación local antes que web | ✅ COMPLETADA | Corpus `creator-docs` clonado (64 MB). **7/8 preguntas reales** respondidas. **10 ms vs 435 ms** | `fase-4-research/FASE-4.md`, `herramientas/rbxdocs` | Clonarlo en tu Windows si lo quieres allí |
| **5 — Testing** | Cerrar el bucle de verificación | ✅ COMPLETADA (y mejorada el 27-08) | **Verificación 1/2 → 2/2** (el arco completo es 0/2 en FASE 0 → 1/2 al llegar los tipos en FASE 2 → 2/2 aquí, al llegar los tests). 5 componentes × (caso válido + inválido) = **14 ejecuciones con exit code observado**. El 27-08 se añadió comprobación de tipos también para los tests | `fase-5-testing/FASE-5.md` + corrección al final, `hooks/`, `proyecto-demo/` | Copiar los hooks al proyecto real |
| **6 — Motor** | Ciclo editar → jugar → leer → corregir | ✅ COMPLETADA (Roblox) · 🔴 BLOQUEADA (UEFN) | Roblox Studio MCP: 4/4 casillas, dos rondas. **Evidencia externa: la ejecutaste tú desde PowerShell en Windows 11, no esta sesión** | `fase-6-motor/CICLO-A-VERIFICAR.md`, tabla de evidencia que aportaste | UEFN: Beta Access |
| **7 — Autonomía** | CI y ejecución en servidor real | 🟡 PARCIAL | Open Cloud: andamiaje completo **sin credenciales**, falla limpio sin ellas. Spec Kit: instalado, integración con Claude **no verificada**. `srt`: **inerte** en este contenedor | `fase-7-autonomia/FASE-7.md`, `ci/roblox-ci.yml`, `scripts/open_cloud_luau.py` | Clave de Open Cloud + entorno de GitHub |
| **8 — Serena** | ¿Aporta valor sobre el stack? | ⏸️ POSPUESTA | De **21 herramientas expuestas, 1 ejecutada** (`initial_instructions`) y **0 simbólicas**. Coste +62,5 %, beneficio medido 0. Su motor de Luau **es el mismo `luau-lsp` ya instalado** | `fase-8-serena/FASE-8-SERENA.md`, `T01-run4-llamadas.txt`, `T01-run4-salida/` | Re-evaluar sólo con un proyecto de ≥50 ficheros |
| **9 — Integración** | Llevar el stack al proyecto real | 🟡 PARCIAL — paquete listo, sin aplicar | Instalador no destructivo probado contra 2 proyectos, uno con carpeta `source/` en vez de `src/`. **El proyecto real no está en el contenedor** | `INTEGRACION.md`, `integracion/`, `entorno-local/WINDOWS-11-INTEGRACION.md` | Ejecutarlo tú en Windows |

---

## C. STACK FINAL

| Componente | Versión | Estado | Verificado | Notas |
|---|---|---|---|---|
| `luau-lsp` | 1.69.0 | ✅ FUNCIONA | **Sí** — detecta los 10 errores del baseline; 0 errores en `src/` de run3b y run4 | Compilado con **clang**; g++ 13 falla por `-Werror=maybe-uninitialized`. El paquete npm homónimo **no es oficial** |
| Rojo | 7.7.0 | ✅ FUNCIONA | **Sí** — sourcemap idéntico al escrito a mano; control con/sin sourcemap | Sin sourcemap, `luau-lsp` ni resuelve los `require` entre módulos |
| Lune | 0.10.5 | ✅ FUNCIONA | **Sí** — 14 ejecuciones con exit code observado; detecta bugs plantados | Runner propio de ~40 líneas. `lune setup` da los tipos de `@lune/*` |
| StyLua | 2.5.2 **+ feature `luau`** | ✅ FUNCIONA | **Sí** — `exit 0` válido / `exit 1` con diff | **Sin esa feature el binario no parsea Luau.** `cargo install stylua` a secas no sirve |
| selene | 0.31.0 | ⚠️ PARCIAL | **Sí, en el modo que funciona hoy** | `std="lua51"` → 18 parse errors en Luau; `std="luau"` → 0, offline; `std="roblox"` → falla sin red. Falta `generate-roblox-std` |
| `pre-commit` | 4.6.2 | ✅ FUNCIONA | **Sí** — bloqueó dos commits reales míos | — |
| `gitleaks` | 8.30.1 | ⚠️ PARCIAL | **Sí, y por eso sabemos que es parcial** | Detecta **1 de 3** claves AWS válidas. Red adicional, nunca la defensa principal |
| `osv-scanner` | 2.5.1 | 🔴 NO VERIFICABLE AQUÍ | No aquí · **tú lo verificaste en local con `lodash`** | `api.osv.dev` inalcanzable desde el contenedor |
| `creator-docs` | clon del 26-08 | ✅ FUNCIONA | **Sí** — 7/8 preguntas, 10 ms vs 435 ms | 64 MB. **Laguna medida:** no cubre Open Cloud |
| Roblox Studio MCP | primera parte, integrado en Studio | ✅ FUNCIONA | **Sí — evidencia externa tuya**, no de esta sesión | `multi_edit`, `start_stop_play`, `get_console_output`, 4/4 casillas |
| Open Cloud (Luau Execution) | API v2 | 🟡 PREPARADO | **No** — nunca se ha llamado a la API | Script y CI listos, fallan limpio sin credencial. Límites: 5 min/tarea, 10 concurrentes |
| Spec Kit (`specify`) | 1.0.1 | ⚠️ INSTALADO, NO INTEGRADO | Procedencia sí; integración con Claude **no** | `specify init` generó `.github/` y `.specify/` pero **0 comandos** en `.claude/commands/`. Requiere init interactivo |
| `srt` (sandbox-runtime) | 1.0.0 | 🔴 INERTE | **No** | `apply-seccomp: write /proc/self/uid_map: Operation not permitted`. **La prueba de "no escribe fuera del cwd" no prueba nada: el comando nunca llegó a correr** |
| Serena | 1.7.0 | ⏸️ POSPUESTA | Procedencia sí (MIT, `oraios/serena`); utilidad **no** | Vive sólo en un venv efímero. **No registrada** en `~/.claude` ni en `.mcp.json` |
| UEFN MCP | Fortnite v42.00 | 🔴 BLOQUEADA | **No** — nunca se ha podido abrir | Requiere Beta Access en Project Settings |

**Regla aplicada en esta tabla:** «instalado» nunca cuenta como «verificado».
Cuatro componentes están instalados y explícitamente **no** verificados.

---

## D. ERRORES DE CONCLUSIONES ANTERIORES Y CORRECCIONES

Esta es la sección más importante del informe. Cada entrada dice qué se creyó,
qué se descubrió y qué es válido hoy.

### D-1. FASE 1 — `gitleaks` no detecta todas las claves AWS

- **Se creyó:** «gitleaks validado con prueba negativa; la puerta de secretos funciona.»
- **Se descubrió:** en una prueba aislada con tres claves **todas sintácticamente
  válidas** (`AKIA` + 16 alfanuméricos), gitleaks detectó **una**. La que sí
  detecta tiene entropía 4,12; las otras dos pasan sin ruido. Además, un
  `.gitleaks.toml` que yo mismo escribí **desactivaba la puerta entera**: con él
  «no leaks found», sin él «leaks found: 1».
- **Válido hoy:** la puerta es real y útil —bloqueó dos commits míos— pero
  **es un detector parcial, no una garantía**. La regla operativa es
  **los secretos nunca se escriben en el repositorio**, y la clave de Open Cloud
  no toca un fichero jamás. La prueba negativa se hace con **varias** claves.

### D-2. FASE 2 — la atribución causal era falsa

- **Se creyó:** *«El baseline entregó 10 errores de tipo. Con `luau-lsp` la misma
  tarea sale con 0 errores. El agente ejecutó `luau-lsp analyze` siete veces.»*
- **Se descubrió:** al abrir por fin el transcript de `run2`: **0 ejecuciones
  completadas** de `luau-lsp`, **3 intentos bloqueados por permisos**, 6 bloqueos
  totales, **0 menciones de `TypeError`**. Las «siete ejecuciones» que conté eran
  siete apariciones del texto del comando **dentro de mensajes de denegación**.
- **Válido hoy:** que `luau-lsp` encuentra los 10 errores reales **es cierto y
  está medido por separado**. Lo que era falso es la cadena causal de run2. La
  regla que nace de aquí: **una mención textual del nombre de una herramienta no
  demuestra que la herramienta se ejecutó**; se cuenta en bloques `tool_use` del
  transcript.

### D-3. FASE 2/3 — el sourcemap de Rojo no es opcional

- **Se creyó:** que Rojo era comodidad de sincronización, y que el sourcemap
  «ayudaba» al LSP.
- **Se descubrió:** con control explícito. Un error de tipos entre módulos
  (`sumar(m, "diez")` donde se espera `number`), **con** sourcemap se detecta en
  la línea y columna exactas y resuelve la ruta de instancia
  `[game/ServerScriptService/Juego/Servidor]`. **Sin** sourcemap el resultado es
  `TypeError: Unknown require: game/ReplicatedStorage/Modulos/Puntuacion` — ni
  siquiera llega a mirar los tipos.
- **Válido hoy:** **sin sourcemap la verificación de tipos entre módulos no
  existe**. Regenerarlo es el paso 0 de cualquier verificación.
- **Corolario descubierto el 27-08:** si una rama de `default.project.json`
  apunta a un directorio **sin ningún `.luau`**, Rojo la omite del sourcemap
  entera y esa parte del juego deja de verificarse **sin avisar**.

### D-4. FASE 3 — H2 no fue confirmada

- **Se creyó (por mí, al proponer la fase):** que Rojo reduciría las iteraciones.
- **Se descubrió:** turnos 27 (sin Rojo) → 24 (con Rojo). El pre-registro,
  escrito **antes** de instalar nada, fijaba «≤18 turnos = confirmada, ≥28 =
  falsada». 24 cae en la banda de ruido.
- **Válido hoy:** **H2 no confirmada, tirando a negativa.** Rojo no reduce
  iteraciones de forma demostrable. Lo que sí hace es otra cosa, y es más
  importante (ver D-5). El pre-registro sigue congelado precisamente para que
  este resultado no se pueda reescribir a posteriori.

### D-5. FASE 3 — errores reales frente a artefactos del sourcemap

- **Se creyó:** que «menos errores» era el indicador de calidad.
- **Se descubrió:** el código entregado por cada corrida se analizó **de las dos
  formas**. Sin sourcemap: 32 errores en el de `run3a` y 21 en el de `run3b`,
  casi todos `Unknown require`. Con sourcemap: **0 y 2**. Ambas corridas
  entregaron 0 errores en `src/`.
  Lo decisivo es la primera columna, porque **es la que el agente de `run3a`
  tenía delante mientras trabajaba**: 32 errores que no podía arreglar, y aun
  así declaró la tarea terminada.
- **Válido hoy:** el valor de Rojo **no es reducir el número de errores, es
  hacerlos accionables**. Un agente que recibe 32 errores irresolubles aprende a
  ignorar al verificador. Ése es el hallazgo sólido de la FASE 3.

### D-6. FASE 4 — las consultas malas eran mías, no del corpus

- **Se creyó:** que el corpus `creator-docs` respondía 4 de 8 preguntas.
- **Se descubrió:** 3 de los 4 fallos eran **consultas mal formuladas por mí**:
  busqué sólo en los `.md` cuando las respuestas estaban en los `.yaml` de
  `reference/engine/`.
- **Válido hoy:** **7/8**. Y la regla: el corpus tiene **dos formas** y hay que
  buscar en las dos. Buscar sólo en `.md` hace parecer que la respuesta no existe.

### D-7. FASE 5 — StyLua necesita `--features luau`

- **Se creyó:** que `cargo install stylua` bastaba.
- **Se descubrió:** ese binario **no parsea Luau**; `--syntax All` no lo arregla.
- **Válido hoy:** hace falta `cargo install stylua --features luau`, o los
  binarios oficiales de la release. Versión fijada: 2.5.2.

### D-8. FASE 5 — el código del juego y los tests necesitan estrategias distintas

- **Se creyó primero:** que se podía analizar todo con `--platform=roblox`.
- **Se descubrió:** analizar los tests con las definiciones de Roblox produce
  errores que no lo son, porque los tests corren en Lune y usan alias `@lune/*`.
  La decisión de FASE 5 fue **saltarse** la comprobación de tipos en los tests.
- **Válido hoy (mejorado el 27-08):** saltársela ya no hace falta. `lune setup`
  genera el alias de tipos; con él en `tests/.luaurc`,
  `luau-lsp analyze --platform=standard` **sí** comprueba los tests. Verificado:
  error deliberado → `EXIT=1`; corregido → `EXIT=0`.
  La regla final es: es test de Lune **sólo** si es `*.spec.luau` o el propio
  `run.luau`; todo lo demás —incluido `engine_smoke.luau`— se verifica como
  código de Roblox.

### D-9. FASE 5 — `os.exit` no existe **ni en Roblox ni en Lune**

- **Se creyó, en dos sitios distintos:** (a) `reglas/CLAUDE-fragmento-research.md`
  decía que en Roblox no existe pero que «en los tests, que corren en Lune, sí
  puede usarse»; (b) `fase-3-rojo/FASE-3.md` calificó los 2 errores de `os.exit`
  de `run3b` como *«un artefacto de analizar un fichero no-Roblox con
  `--platform=roblox`, no un defecto del código»*.
- **Se descubrió:** **tampoco existe en Lune.** La suite de `run3b` pasaba sus
  27 comprobaciones y luego reventaba con `attempt to call a nil value` en
  `os.exit(0)`: **nunca podía dar verde**.
- **Válido hoy:** **las dos afirmaciones anteriores son falsas.** No era un
  artefacto del analizador: era un defecto real que hacía imposible que la suite
  diera verde. En Lune el corte es `require("@lune/process").exit(n)`. Y en
  código de Roblox, `os` sólo tiene `clock`, `date`, `difftime` y `time`.
  *(Lo que sí sigue siendo cierto de FASE 3 es que analizar tests de Lune con
  `--platform=roblox` produce falsos positivos; simplemente, éste no lo era.)*

### D-10. FASE 6 — `print(2 + "2")` no era un bug válido

- **Se creyó:** que serviría como bug plantado para probar el ciclo del motor.
- **Se descubrió:** **Luau coerciona cadenas numéricas**, así que imprime `4` sin
  error. Lo encontraste tú en tu ejecución independiente.
- **Válido hoy:** el bug válido es **`print(2 + {})`** →
  `attempt to perform arithmetic (add) on number and table`. **No volver a usar
  el original como evidencia.**

### D-11. FASE 6 — la evidencia del motor es externa

- **Se creyó (riesgo de presentarlo así):** que el ciclo del motor lo demostró
  esta sesión.
- **Válido hoy:** lo ejecutaste **tú**, desde Claude Code en PowerShell sobre
  Windows 11, con Roblox Studio MCP, en el place «CONSEGUE EL HUEVO». Es
  evidencia legítima de la capacidad del entorno Windows, y **no** es ejecución
  propia de esta sesión. Aquí no hay Roblox Studio.

### D-12. FASE 7 — `srt` no quedó verificado

- **Se creyó:** que una prueba de «escribir fuera del cwd» que no creó fichero
  demostraba aislamiento.
- **Se descubrió:** `srt` ni siquiera arranca aquí —
  `apply-seccomp: write /proc/self/uid_map: Operation not permitted`, no hay
  namespaces de usuario anidados. **El comando nunca corrió, así que el fichero
  no aparecer no prueba nada.**
- **Válido hoy:** `srt` **no verificado**. Sustituto decidido: WSL2, más adelante.

### D-13. Serena — no hubo llamadas simbólicas reales

- **Se creyó (riesgo):** que run4 salió mejor que run3b «gracias a Serena».
- **Se descubrió:** en el transcript, de **21 herramientas Serena expuestas** el
  agente ejecutó **1** (`initial_instructions`) y **0 simbólicas**. La única
  diferencia de calidad —los tests de run3b con `os.exit`— no tiene mecanismo
  causal vía Serena, y además el motor de Luau de Serena **es el mismo `luau-lsp`
  ya instalado**.
- **Válido hoy:** **no atribuirle ninguna mejora.** Lo único atribuible con
  mecanismo claro es el sobrecoste: +62,5 % en dinero, +129 % en tokens.

### D-14. Medición de tokens — `cache_creation` solo mide la temperatura del caché

- **Se creyó, y estuve a punto de reportarlo:** una reducción de contexto del
  −77 %.
- **Se descubrió:** era caché caliente. El total real es
  `input + output + cache_creation + cache_read`.
- **Válido hoy:** cualquier comparación de tokens suma los cuatro campos.

---

## E. ARQUITECTURA FINAL DEL PIPELINE

```
                        ┌─────────────────────────────────────────┐
                        │  Claude Code  (edita Luau)              │
                        └───────────────┬─────────────────────────┘
                                        │ Write / Edit
                                        ▼
  ╔══════════════════ HOOK PostToolUse ═══════════════════════════════════╗
  ║  ¿es *.spec.luau o run.luau?                                          ║
  ║     SÍ → luau-lsp analyze --platform=standard   (alias @lune)         ║
  ║     NO → rojo sourcemap ─► luau-lsp --platform=roblox --defs --sourcemap║
  ║  + selene   + stylua --check                                          ║
  ║  error ⇒ exit 2 + stderr ⇒ Claude lo ve y corrige                     ║
  ╚═══════════════════════════════════════════════════════════════════════╝
                                        │
                                        ▼
  ╔══════════════════ HOOK Stop (puerta de salida) ═══════════════════════╗
  ║  regenera sourcemap · tipos de TODO el código · lune run tests/run.luau║
  ║  roto ⇒ exit 2 ⇒ Claude NO puede terminar                             ║
  ║  freno de presupuesto: bloquea 3 veces, a la 4ª suelta con aviso       ║
  ╚═══════════════════════════════════════════════════════════════════════╝
                                        │
                    ┌───────────────────┴───────────────────┐
                    ▼                                       ▼
        ┌───────────────────────┐              ┌─────────────────────────┐
        │ Roblox Studio MCP     │              │ CI (GitHub Actions)     │
        │ multi_edit            │              │ job estático: sin claves│
        │ start_stop_play       │              │ job de motor: Open Cloud│
        │ get_console_output    │              │   entorno protegido     │
        │ → corregir → repetir  │              └───────────┬─────────────┘
        └───────────────────────┘                          ▼
                                                 ┌─────────────────────┐
                                                 │ Open Cloud Luau     │
                                                 │ engine_smoke.luau   │
                                                 └─────────────────────┘
```

### Qué está realmente demostrado y qué no

| Tramo | Estado |
|---|---|
| Edición → PostToolUse → tipos/lint/formato → `exit 2` | ✅ **Demostrado**, con payload real: `exit 2` en fichero roto, `exit 0` en correcto |
| Rama de tests con alias `@lune` | ✅ **Demostrado**: `EXIT=1` con error, `EXIT=0` corregido |
| Stop → sourcemap + tipos + `lune run` → `exit 2` | ✅ **Demostrado**, incluido el freno (`2, 2, 2, 0`) |
| Detección de directorio vacío en el sourcemap | ✅ **Demostrado** |
| Studio MCP: editar → jugar → consola → corregir | ✅ **Demostrado — por ti, en Windows.** Evidencia externa |
| CI: job estático | 🟡 **Escrito y auditado, no ejecutado.** YAML válido, permisos mínimos |
| CI: job de motor + Open Cloud | 🔴 **No ejecutado nunca.** Falta la credencial |
| Todo lo anterior **sobre el proyecto Roblox real** | 🔴 **Sin aplicar.** Requiere ejecutar el instalador en tu Windows |

---

## F. RESULTADOS EXPERIMENTALES

Las cinco ejecuciones de la tarea patrón T-01. **Tokens = `input + output +
cache_creation + cache_read`**, los cuatro campos sumados.

| Corrida | Configuración | Turnos | Coste | Tokens | API | Errores entregados |
|---|---|---|---:|---:|---:|---|
| **run1** | Baseline, sin herramientas | 11 | $0,9739 | 934 029 | 479 s | **10 de tipo** · verificación 0/2 |
| **run2** | Con `luau-lsp` «disponible» | 25 | $1,2105 | 2 077 499 | 483 s | **`luau-lsp` nunca se ejecutó** (3 intentos bloqueados) |
| **run3a** | Sin Rojo, permisos corregidos | 27 | $1,1163 | 1 857 402 | 382 s | 0 en `src/` · **trabajó contra 32 errores irresolubles** (`Unknown require`) |
| **run3b** | Con Rojo + sourcemap | 24 | $1,1525 | 1 888 019 | 465 s | 0 en `src/` · **2 en `tests/`**, y esos 2 eran un defecto real: `os.exit` |
| **run4** | run3b + Serena | 49 | $1,8730 | 4 325 959 | 534 s | 0 en `src/` · **0 en `tests/`** |

**Herramientas realmente ejecutadas** (contadas en bloques `tool_use` del
transcript, no en menciones):

| Corrida | `luau-lsp analyze` | `rojo sourcemap` | `lune run` | Serena |
|---|---:|---:|---:|---|
| run2 | **0 completadas / 3 bloqueadas** | 0 | 0 | — |
| run3b | 5 | 1 | 0 | — |
| run4 | 6 | 5 | 0 | **1 de 21 expuestas, 0 simbólicas** |

### Cómo hay que leer estos números

- **n = 1 por configuración.** Estaba declarado en el pre-registro de FASE 3
  antes de ejecutar nada. **Ninguna diferencia pequeña entre corridas está
  demostrada como causal.** Turnos 27 → 24 es ruido, no mejora.
- **Lo que sí es sólido** no viene de comparar corridas, sino de mediciones
  directas con control: los 10 errores del baseline; el mismo código analizado
  con y sin sourcemap (32 → 0 y 21 → 2); y el `Unknown require` que aparece en
  cuanto se quita el sourcemap.
- **run2 no mide `luau-lsp`.** Mide un agente al que se le denegó el permiso.
  Sirve como registro de un error metodológico, no como resultado.
- **La diferencia de run4 en `tests/` no es de Serena.** Serena no ejecutó
  ninguna herramienta simbólica. Es variabilidad entre ejecuciones.

---

## G. DECISIONES

Cada decisión, con su razón y su estado a día de hoy.

| Decisión | Estado | Razón |
|---|---|---|
| **Serena → POSPUESTA** | Vigente | 0 herramientas simbólicas ejecutadas, +62,5 % de coste, mismo motor `luau-lsp`. No descartada: el proyecto de prueba era demasiado pequeño para que sus herramientas tengan sentido. Re-evaluar sólo con ≥50 ficheros o ≥10 000 líneas |
| **UEFN → POSPUESTO hasta Beta Access** | Vigente | Es un bloqueo de cuenta, no técnico |
| **WSL2 → SÍ a futuro, NO bloqueante ahora** | Vigente | Windows puro no tiene sandbox nativo de Claude Code, pero está demostrado que conecta con Studio MCP sin WSL2 |
| **`srt` → NO NECESARIO ahora** | Vigente | Inerte aquí; el sustituto es WSL2 |
| **Open Cloud → preparado, credencial nunca en el repo** | Vigente | El script y el CI fallan limpio sin ella. gitleaks es parcial, luego la clave no toca un fichero jamás |
| **`gitleaks` → red adicional, no defensa única** | Vigente | 1 de 3 claves válidas detectadas |
| **`creator-docs` → local antes que web** | Vigente | 10 ms vs 435 ms, 7/8 preguntas. Laguna medida: Open Cloud no está en el corpus |
| **T-01 → no repetir** | Vigente | Cinco corridas. Otra cuesta ~$1,9 y no cambia ninguna decisión pendiente |
| **No aumentar la n de H2** | Vigente | H2 está declarada no confirmada y eso ya no bloquea nada |
| **Experimentos caros → en subproceso aislado** | Vigente **y reforzada** | Ver §H: los experimentos fueron el 5 % del gasto; el 95 % fue contexto conversacional |
| **`std = "luau"` en selene por defecto** | **Nueva (27-08)** | Es la única configuración que funciona sin red y parsea Luau. Se asciende a `"roblox"` tras `generate-roblox-std` |
| **Spec Kit → descartado por ahora** | **Revisada (27-08)** | Instalado pero su integración con Claude no se verificó, y el flujo de especificación ya lo cubren `CLAUDE.md` + la tarea patrón. No aporta capacidad nueva demostrada |

**Ninguna decisión anterior ha resultado incorrecta a la luz de la evidencia
final.** Las dos marcadas como nueva/revisada son añadidos, no rectificaciones.

---

## H. COSTE TOTAL

Datos de `ccusage`, tres días de misión.

| Día | Coste | Tokens | de ellos `cache_read` |
|---|---:|---:|---:|
| 25-08-2026 | $59,26 | 65 557 122 | 63 060 469 |
| 26-08-2026 | $40,11 | 46 206 796 | 44 362 281 |
| 27-08-2026 | $27,80 | 25 711 695 | 24 121 595 |
| **TOTAL** | **$127,17** | **137 475 613** | **131 544 345 (95,7 %)** |

### Desglose por naturaleza

| Concepto | Coste | Cómo se sabe |
|---|---:|---|
| **Experimentos** (5 corridas de T-01 en subproceso) | **$6,33** | Medido: suma de `total_cost_usd` de los cinco `result.json` |
| **Instalaciones** (compilar `luau-lsp`, cargo, pip, clones) | **~$0** | Herramientas locales; no consumen API |
| **Conversación y contexto** | **~$120,84** | ESTIMADO: total menos experimentos |
| — bloque Serena (desde 01:47 Z del 27-08) | **~$10,60** ESTIMADO | Tokens del transcript × tarifas publicadas de Opus 5 |
| — bloque Integración (desde 02:30 Z del 27-08) | **~$12,75** ESTIMADO | Igual método |

### La conclusión que importa

**Los experimentos costaron el 5 % de la misión. El 95 % fue releer un contexto
que no paraba de crecer.** El 95,7 % de todos los tokens de la misión son
`cache_read`: el mismo historial, reenviado turno tras turno.

Los números marcados **ESTIMADO** se calculan aplicando las tarifas publicadas de
Opus 5 a los tokens del transcript. Los de `ccusage` y los de los `result.json`
son medidos. No hay más precisión disponible y no se finge que la haya.

---

## I. ACCIONES QUE DEBO HACER YO

Comandos completos en
[`entorno-local/WINDOWS-11-INTEGRACION.md`](../entorno-local/WINDOWS-11-INTEGRACION.md).
**Ninguna de estas acciones requiere escribir un secreto en un fichero.**

### Windows 11

| # | Qué | Dónde | Qué esperar | Cómo comprobarlo |
|---|---|---|---|---|
| W1 | `rokit install` | Raíz del proyecto, PowerShell | Instala las 5 herramientas fijadas | `rojo --version` → 7.7.0, `luau-lsp --version` → 1.69.0 |
| W2 | `./instalar.sh /c/ruta/al/proyecto --simular` y luego sin `--simular` | **Git Bash** | Informe con CREADOS / YA IGUALES / PROPUESTOS | Que no aparezca nada inesperado en **PROPUESTOS** |
| W3 | Descargar `globalTypes.d.luau` | Raíz del proyecto | Fichero de ~2 MB | `./verificar.sh` deja de avisar de que faltan las definiciones |
| W4 | `selene generate-roblox-std` y subir `selene.toml` a `std="roblox"` + `undefined_variable="deny"` | Raíz del proyecto | Genera `roblox.yml` | `selene src` deja de marcar `game` como indefinido |
| W5 | Pegar `gitignore.fragmento` y `CLAUDE.fragmento.md` | Tu `.gitignore` y tu `CLAUDE.md` | — | `git status` no propone `sourcemap.json` |
| W6 | `./verificar.sh` | Raíz del proyecto | 6 líneas OK | `EXIT=0`. La 1ª vez es normal que falle **formato**: `stylua src tests` |
| W7 | **Probar que los hooks están vivos** | Sesión de Claude Code en el proyecto | Pedirle que meta un error de tipos a propósito | Debe salir `Verificación fallida en ...` y corregirse solo. **Si no sale nada, el hook no se ejecuta** |

Nota: los hooks son Bash. En Windows, Claude Code los ejecuta con **Git Bash** si
está instalado y sólo cae a PowerShell si no lo está. Git Bash viene con Git para
Windows.

### Roblox Studio

| # | Qué | Cómo comprobarlo |
|---|---|---|
| R1 | Borrar `ServerScriptService.BugTestScript` del place de prueba | Ya no aparece en el explorador |
| R2 | Confirmar que el MCP de Studio sigue conectado tras la integración | `get_console_output` responde |

### GitHub

| # | Qué | Dónde | Cómo comprobarlo |
|---|---|---|---|
| G1 | Crear el entorno `roblox-open-cloud` | Settings → Environments | Aparece en la lista; el job `verificacion-en-motor` deja de fallar por entorno inexistente |
| G2 | Definir `ROBLOX_UNIVERSE_ID` y `ROBLOX_PLACE_ID` como **variables** (no secretos) | Settings → Variables → Actions | No son sensibles |
| G3 | Comprobar que el job estático pasa en un PR | Actions | Verde sin necesidad de credenciales |

### Open Cloud

| # | Qué | Cómo comprobarlo |
|---|---|---|
| O1 | Crear la clave **acotada al universo de desarrollo**, con permiso `universe.place.luau-execution-session:write` | La consola de Roblox muestra el ámbito limitado |
| O2 | Guardarla como secreto `ROBLOX_OPEN_CLOUD_KEY` en GitHub. **Nunca en un fichero** | `gitleaks detect` sigue diciendo `no leaks found` |
| O3 | Lanzar el workflow a mano | `engine_smoke.luau` imprime «servicio OK: …» por cada servicio |

### UEFN

| # | Qué | Cómo comprobarlo |
|---|---|---|
| U1 | Project Settings → Beta Access → activar **UEFN MCP Toolset** | El toolset aparece disponible en UEFN |

### Proyecto Roblox real

| # | Qué | Cómo comprobarlo |
|---|---|---|
| P1 | Ejecutar W1–W7 sobre él | `./verificar.sh` → `EXIT=0` |
| P2 | Revisar cada fichero `.propuesto` y decidir si lo adoptas | No queda ningún `.propuesto` sin decidir |

---

## J. PENDIENTES AUTOMATIZABLES

Lo que una sesión futura de Claude Code puede hacer **sin ti**, una vez hayas
completado W1–W2:

| # | Tarea | Requisito previo |
|---|---|---|
| A1 | Adaptar el `default.project.json` y los hooks a la estructura real del proyecto, si el instalador dejó `.propuesto` | W2 hecho |
| A2 | Pasar `stylua` sobre todo el código y dejar el formato en verde | W2 hecho |
| A3 | Escribir los primeros `*.spec.luau` reales sobre la lógica pura que ya exista | W2 hecho |
| A4 | Separar lógica pura de código acoplado a Roblox donde haga falta para poder testear | A3 |
| A5 | Ajustar `selene.toml` y silenciar avisos que no interesen, tras `generate-roblox-std` | W4 hecho |
| A6 | Afinar el workflow de CI a la estructura real y verificar que el job estático pasa | W2 hecho |
| A7 | Escribir `engine_smoke.luau` específico del juego, sin tocar gameplay | O1 decidido |
| A8 | Mantener la documentación del proyecto al día | — |

**No automatizable sin ti:** nada que requiera credencial, Beta Access, Roblox
Studio, o una decisión de arquitectura del juego.

---

## K. ARTEFACTOS EXISTENTES

| Ruta | Propósito | Estado | ¿Listo para usar? |
|---|---|---|---|
| `integracion/instalar.sh` | Instalador no destructivo del stack | Probado contra 2 proyectos | ✅ **Sí** |
| `integracion/instalar.ps1` | Envoltorio que localiza Git Bash | **NO VERIFICADO** (no hay PowerShell aquí) | ⚠️ Usar `instalar.sh` desde Git Bash |
| `integracion/plantilla/verificar.sh` | Puerta completa de verificación | Probado: 1 positiva + 5 negativas | ✅ **Sí** |
| `integracion/plantilla/.claude/hooks/*.sh` | PostToolUse y Stop | Probados con payload real | ✅ **Sí** |
| `integracion/plantilla/tests/run.luau` | Runner de Lune | Probado, sale ≠0 al fallar | ✅ **Sí** |
| `integracion/plantilla/tests/engine_smoke.luau` | Comprobación en el motor | Escrito, **nunca ejecutado en el motor** | 🟡 Listo, sin probar |
| `integracion/plantilla/.github/workflows/roblox-ci.yml` | CI | YAML validado, permisos mínimos, **no ejecutado** | 🟡 Listo, sin probar |
| `integracion/plantilla/{selene,stylua,rokit}.toml`, `.luaurc` | Configuración | Probados | ✅ **Sí** |
| `integracion/plantilla/CLAUDE.fragmento.md` | Reglas para tu `CLAUDE.md` | Corregido (incluye D-9) | ✅ **Sí** |
| `integracion/plantilla/herramientas/rbxdocs` | Consulta local de la doc | Probado en FASE 4 | ✅ Sí, requiere el corpus clonado |
| `fase-7-autonomia/scripts/open_cloud_luau.py` | Ejecutar Luau en un place real | Sin credenciales; errores HTTP limpios. **API nunca llamada** | 🟡 Listo, sin probar |
| `fase-5-testing/proyecto-demo/` | Demo de la FASE 5 | Histórico | 🔬 Experimental |
| `fase-5-testing/config/` | Configuración de la FASE 5 | **Superada** por `integracion/plantilla/` | 🔬 Histórico. Ver la corrección al final de `FASE-5.md` |
| `INFORME-GITHUB-INTELLIGENCE.md` + `dossier.html` | Misión 1 | Cerrado | 📄 Referencia |
| `STACK-ROBLOX-UEFN.md` + `stack-roblox-uefn.html` | Misión 2, arquitectura | Cerrado | 📄 Referencia |
| `AUDITORIA-FINAL.md` | Auditoría del 27-08 | Cerrado | 📄 Referencia. **Este informe maestro lo engloba** |
| `INTEGRACION.md` | Detalle de las pruebas de integración | Cerrado | 📄 Referencia |
| `datos/probe.sh` + `datos/*.csv` | Medición de 307 repositorios | Cerrado | 📄 Reproducible |

**No se han duplicado ficheros.** Este informe referencia, no copia.

---

## L. EVIDENCIA CONGELADA

**Estos ficheros no se modifican nunca.** No son documentación: son el registro
de lo que ocurrió. Si se editan, deja de ser posible comprobar que las
conclusiones se sostienen, y en particular deja de ser posible detectar que una
conclusión fue reescrita después de conocer el resultado.

| Ruta | Por qué está congelada |
|---|---|
| `fase-0-baseline/TAREA-PATRON.md` | Es la tarea idéntica en las 5 corridas. Si cambia, ninguna comparación vale |
| `fase-0-baseline/T01-run1-salida/` | Salida del baseline. Contiene los 10 errores de tipo originales |
| `fase-2-code-intelligence/T01-run2-salida/` | Salida de la corrida cuyos permisos bloquearon `luau-lsp`. Es la prueba física de D-2 |
| `fase-3-rojo/PRE-REGISTRO.md` | Hipótesis y criterios de falsación escritos **antes** de instalar Rojo. Es lo que impide reescribir H2 a posteriori |
| `fase-3-rojo/T01-run3a-salida/` | Sin Rojo. Los 32 errores irresolubles |
| `fase-3-rojo/T01-run3b-salida/` | Con Rojo. Los 21 accionables y los 2 de `os.exit` |
| `fase-8-serena/T01-run4-salida/` | Salida con Serena |
| `fase-8-serena/T01-run4-llamadas.txt` | Registro de las 48 llamadas `tool_use` reales. Prueba de que sólo 1 fue de Serena |

Verificado en esta sesión con `git status`: las ocho rutas están limpias.

---

## M. REGLAS PARA FUTURAS SESIONES

Las diez lecciones, cada una nacida de un error concreto de esta misión.

1. **Comprobar que una herramienta se ejecutó de verdad.** Se cuenta en bloques
   `tool_use` del transcript JSONL. *(D-2: conté 7 «ejecuciones» que eran 7
   mensajes de denegación.)*
2. **Un texto que menciona una herramienta no es una llamada a esa herramienta.**
   Las instrucciones de Serena nombran `find_symbol` diez veces; se ejecutó cero.
   *(D-13.)*
3. **Los tokens son `input + output + cache_creation + cache_read`.**
   `cache_creation` a solas mide la temperatura del caché, no el contexto.
   *(D-14: estuve a punto de reportar un −77 % inexistente.)*
4. **No lanzar experimentos desde una conversación con el contexto ya enorme.**
   El 95,7 % de los tokens de la misión fueron `cache_read`. *(§H.)*
5. **Los experimentos caros van en subproceso aislado** (`claude -p`), que además
   deja un `result.json` medible. Cinco corridas costaron $6,33; la conversación
   costó $120,84.
6. **Verificar la procedencia antes de instalar:** el nombre del paquete debe
   coincidir con el manifiesto del repositorio oficial. *(El npm `luau-lsp` era
   un shim de 3,4 KB de un tercero; Serena sí coincidía.)*
7. **Una prueba positiva no basta: hace falta la negativa.** Y con más de un
   caso. *(D-1: una sola clave AWS daba la falsa impresión de que la puerta
   funcionaba entera.)*
8. **Con n = 1 no se atribuye causalidad.** Se declara la limitación antes de
   ejecutar, no después. *(D-4, y el pre-registro que lo dejó por escrito.)*
9. **La evidencia experimental se congela.** Incluidas las hipótesis, escritas
   antes del experimento. *(§L.)*
10. **Parar cuando el trabajo adicional no cambia ninguna decisión.** Otra corrida
    de T-01 cuesta ~$1,9 y no cambia nada de lo que está pendiente.

Dos reglas más que esta misión ganó por la vía dura:

11. **Cuando algo falla, preguntarse primero si el fallo es propio.** *(D-6: tres
    de mis cuatro «fallos del corpus» eran consultas mías mal hechas.)*
12. **Tras tocar una configuración de seguridad, ejecutar una prueba de no
    regresión.** *(D-1: mi propio `.gitleaks.toml` desactivaba la puerta entera y
    sólo se vio comparando con y sin él.)*
