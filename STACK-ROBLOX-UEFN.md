# Stack óptimo: Claude Code como agente de desarrollo para Roblox Studio y UEFN

**Investigación 2.0 — arquitectura, no lista de herramientas.**
**Fecha de medición:** 25 de agosto de 2026.
**Estado:** investigación cerrada. **No se ha instalado ni ejecutado nada.**

---

## Resumen en una página

La respuesta a "¿cuál es el mejor stack?" cambió hace cinco días y la mayoría de guías todavía no lo sabe.

**Los dos motores ya traen su propio servidor MCP dentro del editor.** No es un proyecto comunitario: es primera parte, en ambos casos.

| | Roblox | UEFN |
|---|---|---|
| Servidor MCP oficial | **Integrado en Studio** (Assistant → Manage MCP Servers) | **Unreal MCP, integrado en el editor** desde Fortnite v42.00 (20-ago-2026) |
| Quick-connect a Claude Code | **Sí, explícito en la documentación** | Vía config MCP estándar tras activar el toolset en Beta Access |
| Puede ejecutar código | `execute_luau` en Edit / Client / Server | Compilar Verse |
| Puede probar | `start_stop_play`, `get_console_output`, `screen_capture`, `user_keyboard_input`, `character_navigation`, subagente `playtest` | Ejecutar sesiones de juego |
| Madurez | Meses de rodaje, ~25 herramientas documentadas | **5 días** |
| CI sin GUI | **Sí** — Open Cloud Luau Execution API | **No** |

Eso significa que **el 80 % de la capacidad que pides ya no requiere instalar nada de terceros.** Requiere activar dos interruptores y construir disciplina alrededor.

Y significa algo incómodo que digo ya, en la primera página: **los dos perfiles no pueden llegar al mismo nivel de autonomía.** Roblox puede cerrar el ciclo plan → implementar → probar → observar → corregir con evidencia real y sin humano. UEFN, hoy, no: su ciclo depende de un editor GUI con una integración de cinco días de vida, sin framework de tests, sin ejecución headless y sin CI. Roblox llega realistamente a **Nivel 4**. UEFN, a **Nivel 2-3**.

**El stack final son 11 piezas, de las cuales 3 son interruptores y 4 son binarios de línea de comandos.** No hay ningún framework multi-agente, ninguna base de datos de grafos y ningún sistema de memoria vectorial.

---

## 0. Método y honestidad sobre las fuentes

Mismo método que la investigación anterior: medición directa por clonado de metadatos (`--depth 100 --filter=blob:none --no-checkout`) más lectura de fuentes primarias. **Nada se ejecutó.**

Tres limitaciones que debes conocer antes de leer el resto:

1. **`dev.epicgames.com` está bloqueado por el proxy de egreso de esta sesión** y además devuelve 403 a rastreadores. No he podido leer la documentación oficial de Epic con mis propios ojos. Todo lo que afirmo sobre UEFN procede de: las notas de la versión 42.00 leídas por buscador, el anuncio de Epic en `fortnite.com/news/unreal-mcp-is-now-available-in-uefn`, el foro oficial de Epic, y prensa especializada. **Lo marco como `[fuente secundaria]` donde corresponde.** Antes de la Fase 6 de UEFN tendrás que abrir esas páginas tú.
2. **La documentación de Roblox sí la he leído en crudo**, desde `raw.githubusercontent.com/Roblox/creator-docs`. Todo lo que digo del Studio MCP viene del fichero `content/en-us/studio/mcp.md` del repositorio oficial.
3. Las cifras de commits con valor `100` significan "≥100": el clon tiene profundidad 100 y el contador toca techo.

---

## PARTE 1 — Auditoría: qué hace ya Claude Code y no debes duplicar

Esta sección existe para poder decir "no" al 90 % de las herramientas que aparecerán después.

| Capacidad | Estado nativo en agosto 2026 | ¿Necesita ayuda externa? |
|---|---|---|
| **Sandbox** | Sandbox de Bash a nivel de SO: Seatbelt en macOS, bubblewrap+seccomp en Linux/WSL2. `/sandbox` con modos, allowlist de red, `strictAllowlist`, enmascarado de credenciales, reglas deny con comodín (`**/.env`) | **No** para Bash. Sí para *aislar servidores MCP de terceros* |
| **Bash / filesystem** | Lectura, escritura, edición, glob, grep (ripgrep interno), permisos por patrón, comprobación de redirecciones de entrada | **No** |
| **LSP / diagnósticos** | **Soporte LSP nativo**: Claude Code arranca automáticamente los servidores LSP de los plugins instalados y expone `goToDefinition`, `findReferences`, `hover`, `documentSymbol`, `workspaceSymbol`, `goToImplementation`, jerarquía de llamadas y **diagnósticos en tiempo real**. No activo por defecto | **Parcialmente** — hay que aportar el servidor de lenguaje. Ver Parte 6 |
| **Skills** | Carga progresiva (~100 tokens de metadatos por skill, cuerpo bajo demanda), invocación por `/nombre` o automática, ejecución en subagente, hot-reload, argumentos | **No** |
| **Plugins** | Marketplace oficial, allowlist/blocklist por owner, fuentes GitHub/GitLab/archivo con fijación SHA-256 | **No** |
| **Subagentes** | Contexto propio por subagente, prompt y herramientas restringidas, **anidamiento hasta profundidad 3**, hasta 20 concurrentes, `fork` que hereda conversación y caché, ejecución en segundo plano por defecto, memoria persistente propia. Built-ins `Explore` y `Plan` saltan CLAUDE.md para abaratar | **No** |
| **Hooks** | `PreToolUse`, `PostToolUse`, `SessionStart`, `Notification`, `Stop`, `DirectoryAdded`… más **hooks basados en prompt y en agente** para decisiones de juicio. Control determinista: se ejecutan siempre | **No.** Esta es la pieza clave del ciclo de verificación |
| **Memoria** | `CLAUDE.md` (tú escribes) + `.claude/rules/` con ámbito por tipo de fichero + **auto-memoria** (Claude escribe, por repositorio, compartida entre worktrees, primeras 200 líneas / 25 KB por sesión) + memoria propia por subagente | **Depende del horizonte.** Ver Parte 3 |
| **Gestión de contexto** | `/context` (desglose de qué ocupa la ventana), `/compact`, `/btw`, plan mode, caché de prompt de 1 h | **No** |
| **MCP** | Cliente completo: stdio y remoto, OAuth 2.1, reconexión, `headersHelper`, enmascarado de variables de entorno, servidores por proyecto con confirmación de confianza | **No** |
| **Git / GitHub** | Git por Bash. GitHub por el MCP oficial de GitHub | **Sí, un servidor MCP de GitHub** (opcional) |
| **Testing / debugging** | Ejecuta cualquier runner por Bash y lee su salida. No conoce ningún motor de juego | **Sí — esta es la brecha real** |
| **`/doctor`, `/security-review`** | Diagnóstico de configuración y revisión de seguridad del diff | **No** |
| **OTEL** | Spans por petición de modelo y por ejecución de herramienta, métricas de tokens y coste, eventos estructurados por OTLP, `CLAUDE_CODE_OTEL_CONTENT_MAX_LENGTH` | **No** |
| **Permisos / aislamiento** | Modos de permiso, allowlist por herramienta, confianza por carpeta y por repositorio anidado, worktrees aislados | **No** |

### Las cuatro brechas reales

Todo lo demás está cubierto. Lo que Claude Code **no** puede hacer solo:

1. **No puede tocar el motor.** No abre Studio, no compila Verse, no lanza una partida, no ve la pantalla del juego. → *Servidor MCP del editor.*
2. **No entiende Luau ni Verse semánticamente sin un servidor de lenguaje.** Grep encuentra texto; no encuentra "todos los sitios donde se llama a esta RemoteFunction". → *`luau-lsp`.*
3. **No recuerda por qué se descartó una arquitectura hace tres semanas.** La auto-memoria son notas breves, no un registro de decisiones. → *Registro de decisiones en el repo.*
4. **No tiene forma de demostrar que terminó.** Puede decir "hecho" sin evidencia. → *Puerta de verificación en hooks.*

**Todo el stack que sigue existe para cubrir exactamente esas cuatro brechas. Nada más.**

---

## PARTE 2 — Matriz de capacidades del agente

| Capacidad | Quién la aporta | ¿Hace falta instalar algo? |
|---|---|---|
| **A. Cerebro** — razonar, planificar, descomponer, decidir, revisar | Claude Code: plan mode, subagentes anidados, `Explore`/`Plan`, skills | **Nada.** Añadir metodología (Parte 8), no herramientas |
| **B. Investigación** — web, GitHub, docs, APIs | WebSearch/WebFetch nativos + **`Roblox/creator-docs` clonado en local** + **digests de Verse en disco** | Un `git clone`. Ver Parte 7 |
| **C. Code intelligence** — símbolos, referencias, dependencias, AST | `luau-lsp` vía LSP nativo (Luau) · digests + grep (Verse) | Un binario. Ver Parte 6 |
| **D. Memoria de proyecto** | `CLAUDE.md` + `.claude/rules/` + auto-memoria + registro de decisiones en el repo | **Nada al principio.** Ver Parte 3 |
| **E. Manipular el motor** | Studio MCP · UEFN Unreal MCP | Dos interruptores |
| **F. Verificar** | `luau-lsp analyze`, `selene`, tests en Lune/Lute, playtest por MCP, Open Cloud | Ver Partes 8-9 |
| **G. Seguridad** | Sandbox nativo + `srt` + `gitleaks` + `osv-scanner` | Ver Parte 10 |
| **H. Medición** | OTEL nativo + `ccusage` | Un binario |

---

## PARTE 3 — Memoria: la respuesta corta es "todavía no instales nada"

Es la sección donde más gente construye un Frankenstein, así que voy al grano.

### Qué necesitas recordar durante meses

Arquitectura · decisiones tomadas · **decisiones rechazadas y por qué** · convenciones · sistemas existentes y sus contratos · bugs conocidos · peculiaridades de la API del motor · diseño de juego · dependencias · objetivos · estado actual.

Fíjate en la naturaleza de esa lista: **casi todo es texto estable que tú también quieres leer, revisar y versionar.** No son "hechos temporales con ventana de validez" ni "embeddings sobre un corpus que cambia". Eso descarta media categoría de golpe.

### Comparación de los candidatos

| | Coste de tokens | Latencia | Complejidad | Calidad del retrieval | Riesgo | Escalabilidad | Actividad medida |
|---|---|---|---|---|---|---|---|
| **CLAUDE.md + `.claude/rules/` + auto-memoria** (nativo) | El más bajo: se carga lo que tú decides, con ámbito por tipo de fichero | Cero | Cero | Determinista: está o no está | Ninguno nuevo | Se degrada cuando `CLAUDE.md` crece sin control | Nativo |
| **Registro de decisiones en el repo** (Markdown, un fichero por decisión) | Bajo: sólo se lee bajo demanda vía grep/LSP | Cero | Muy baja | Excelente si los ficheros tienen títulos buenos | Ninguno | Escala a cientos de decisiones | N/A |
| **basic-memory** | Medio: herramientas MCP siempre cargadas | Baja (local) | Media | Buena; el grafo son wikilinks sobre Markdown | Medio: memoria envenenada = inyección persistente | Buena | ≥100 commits/30 d, 412 test files, **AGPL-3.0** |
| **mcp-memory-service** | Medio | Baja | Media | Buena, con sqlite-vec | Medio; además REST+OAuth si lo activas | Buena | 174 commits/30 d, 306 tests, 13 issues abiertos, Apache-2.0 |
| **Graphiti** | **Alto**: la ingesta pasa por un LLM | Media | **Alta**: exige Neo4j o FalkorDB | Excelente **para hechos con validez temporal** | Medio | Excelente | 39 commits/30 d, Apache-2.0 |
| **Cognee** | **Alto**: indexación con LLM | Media | **Alta** | Buena en dominios con muchas relaciones | Medio | Excelente | 667 commits/30 d — el más activo del sector |

### La decisión

**Fase inicial: nada externo.** Usa `CLAUDE.md` para convenciones, `.claude/rules/` para reglas por tipo de fichero (una para `*.server.luau`, otra para `*.client.luau`, otra para `*.verse`), auto-memoria para correcciones, y **un directorio `docs/decisiones/` con un fichero Markdown por decisión** siguiendo el formato ADR: contexto, opciones consideradas, decisión, **alternativas rechazadas y motivo**, consecuencias.

Esto no es una solución de segunda. Para un proyecto de código, un registro de decisiones en el repositorio gana a un MCP de memoria en cinco de los siete ejes: cuesta menos tokens, no añade latencia, no añade superficie de ataque, es revisable por ti en un diff, y sobrevive a que el proyecto de memoria muera.

**Único upgrade justificado, y sólo si se cumple el disparador:** cuando tengas conocimiento que cruza *varios* proyectos (por ejemplo, una biblioteca de patrones de Luau que reutilizas entre juegos), añade **`basic-memory`** — porque guarda Markdown que sigue siendo tuyo y legible. El disparador medible: *"he tenido que reexplicar lo mismo en dos proyectos distintos más de tres veces"*.

**Descarto Graphiti y Cognee para este caso concreto**, y quiero ser preciso sobre por qué, porque ambos son proyectos excelentes: su ventaja real es el modelado de hechos que cambian de validez en el tiempo y de grafos densos de entidades. El desarrollo de un juego tiene un grafo de entidades denso —sistemas, dependencias— pero **ese grafo ya existe en el código y lo consulta mejor un servidor de lenguaje que un grafo reconstruido por un LLM**. Pagar indexación con LLM para reconstruir lo que `luau-lsp` te da exacto y gratis es el error de diseño más caro de esta categoría.

**Nunca instales dos.** Memoria nativa + basic-memory + Graphiti + Cognee no es "más memoria": son cuatro fuentes que se contradicen, y no tienes forma de saber cuál ganó cuando el agente decide algo raro.

---

## PARTE 4 — Roblox Studio: el ecosistema real, medido

### 4.1 El hallazgo que reordena todo: el MCP oficial de Studio

Fuente primaria: `Roblox/creator-docs`, fichero `content/en-us/studio/mcp.md`, leído en crudo. El repositorio tiene **49 commits en 30 días y 9 295 ficheros**.

**El servidor MCP está integrado en Roblox Studio.** Se activa en Assistant → **…** → Manage MCP Servers → *Enable Studio as MCP server*. Transporte `stdio`. Y la lista de quick-connect incluye **Claude Code de forma explícita**, junto a Codex CLI, Cursor, Gemini CLI, VS Code, Antigravity y Claude Desktop.

Herramientas que expone, agrupadas por lo que te habilitan:

| Grupo | Herramientas | Qué desbloquea para el agente |
|---|---|---|
| **Scripts** | `script_read` (con rangos de líneas), `multi_edit`, `script_search` (difuso), `script_grep` | Leer y editar código dentro del DataModel sin pasar por ficheros |
| **Exploración** | `search_game_tree`, `inspect_instance`, `subagent` (`explore`, `playtest`) | Entender la jerarquía del juego, no sólo el código |
| **Ejecución** | **`execute_luau`** con `datamodel_type` = Edit / Client / **Server** | **Ejecutar código real en el motor y ver el resultado** |
| **Playtest** | `get_studio_state`, `start_stop_play`, **`get_console_output`**, **`screen_capture`** | Cerrar el ciclo: probar, leer errores, *ver* el resultado |
| **Simulación de input** | `character_navigation`, `user_keyboard_input` | Probar mecánicas de verdad, no sólo funciones puras |
| **Assets** | `generate_mesh`, `generate_material`, `generate_procedural_model`, `search_asset`, `insert_asset`, `upload_image`, `store_image` | Pipeline de contenido sin salir del agente |
| **Multi-instancia** | `list_roblox_studios`, parámetro `studio_id` en toda llamada | Varios Studio y varios agentes en paralelo, sin estado de sesión ambiguo |

Advertencia textual de la propia documentación: *"MCP clients can read and modify content in your open Roblox places. Make sure to only connect clients you trust."*

**Consecuencia arquitectónica:** casi todos los servidores MCP comunitarios de Roblox Studio quedan obsoletos. Los medí igualmente: `boshyxd/robloxstudio-mcp` lleva **80 días sin commits** (1 en 90 días); `Chrrxs/roblox-mcp-primitives`, **98 días**. La excepción honesta es **`Chrrxs/robloxstudio-mcp`**, que sigue muy vivo (30 commits/30 d, 82/90 d, 57 ficheros de test) y se especializa en *debugging en runtime, control de playtest, multijugador y evaluación por peer cliente/servidor*. Aun así: **primera parte primero.** Sólo si te falta algo concreto de multijugador, evalúalo después, midiendo.

### 4.2 La segunda pata: ejecución headless sin GUI

El Studio MCP requiere **Studio abierto**, es decir, una GUI y una máquina. Para CI existe la otra mitad:

**Open Cloud — Luau Execution API.** Ejecuta Luau contra una versión concreta de un place, sin GUI, con acceso completo al DataModel y a la API del motor. Límites documentados: **5 minutos por tarea, 10 tareas concurrentes por place**. Permite `SavePlaceAsync` y payloads binarios. Referencia oficial: `Roblox/place-ci-cd-demo` (construir el RBXL con Rojo → subirlo → ejecutar Luau).

Aviso de mantenimiento: ese repositorio de demo lleva **706 días sin commits**. La API está viva y documentada; **el ejemplo está congelado**. Úsalo como patrón, no como plantilla.

### 4.3 Estado real del toolchain de Roblox (medido 25-08-2026)

Aquí viene la parte que ninguna guía te cuenta: **el ecosistema open source de Roblox está mucho menos mantenido que el ecosistema de tooling de IA.**

| Herramienta | Último commit | 30 d / 90 d / año | Veredicto |
|---|---|---|---|
| **`luau-lang/luau`** | hace 3 d | 17 / 46 / 152 | ✅ Vivo. Aquí vive `luau-analyze` |
| **`JohnnyMorganz/luau-lsp`** | **hace 0 d** | **16 / 51 / ≥100** | ✅ **La pieza más importante del perfil.** 14 autores |
| **`luau-lang/lute`** | hace 1 d | 36 / ≥100 / ≥100 · **750 test files** | ✅ Runtime Luau autónomo **del propio equipo de Luau**. Su `std` se está haciendo compartido con Roblox |
| **`Roblox/creator-docs`** | hace 0 d | 49 / ≥100 | ✅ 9 295 ficheros de documentación oficial, clonable |
| **`rojo-rbx/rojo`** | hace 50 d | 0 / 14 / 53 | ✅ Lento pero vivo; proyecto maduro |
| **`rojo-rbx/rbx-dom`** | hace 26 d | 3 / 25 / 74 | ✅ La base de Rojo |
| **`lune-org/lune`** | hace 52 d | 0 / 31 / 62 | ⚠️ Vivo, ritmo bajo. Lute empieza a solaparse |
| **`pesde-pkg/pesde`** | hace 18 d | 7 / 15 / 116 | ⚠️ Gestor de paquetes moderno, en ascenso |
| **`Kampfkarren/selene`** | hace 96 d | 0 / 0 / **7** | ⚠️ Linter casi parado, pero es una herramienta "terminada" |
| **`JohnnyMorganz/StyLua`** | hace 101 d | 0 / 0 / 83 | ⚠️ Formateador, mismo caso. 851 test files |
| **`rojo-rbx/rokit`** | hace 108 d | 0 / 0 / 17 | ⚠️ Gestor de toolchain; simple y suficiente |
| **`Kampfkarren/full-moon`** | hace 131 d | 0 / 0 / 6 | ⚠️ Parser Luau que sostiene selene y StyLua. 1 296 test files |
| **`UpliftGames/wally`** | **497 d** | 0 / 0 / **0** | ⛔ El gestor de paquetes estándar lleva **año y medio sin un commit** |
| **`Sleitnick/rbxcloud`** | **520 d** | 0 | ⛔ CLI de Open Cloud, abandonado |
| **`Roblox/testez`** | **1 302 d** | 0 | ⛔ Muerto. Sigue siendo lo que recomienda medio internet |
| **`jsdotlua/jest-lua`** | **609 d** | 0 | ⛔ El sucesor de TestEZ, también muerto |
| **`dphfox/tiniest`** | 415 d | 0 | ⛔ Alternativa mínima, parada |
| **`l3dotdev/EzSpec`** | **1 738 d** | 0 | ⛔ |
| **`rojo-rbx/run-in-roblox`** | **2 227 d** | 0 | ⛔ Seis años. Sustituido por el MCP y Open Cloud |
| **`Sleitnick/Knit`** | **755 d** | 0 | ⛔ El framework más recomendado del ecosistema, muerto |
| **`matter-ecs/matter`** | 638 d | 0 | ⛔ ECS |
| **`jsdotlua/react-lua`** | 628 d | 0 | ⛔ |
| **`MadStudioRoblox/ProfileStore`** | 390 d | 0 | ⚠️ *Ver matiz abajo* |
| **`evaera/roblox-lua-promise`** | 1 044 d | 0 | ⚠️ *Ver matiz abajo* |
| **`dphfox/Fusion`** | 204 d | 0 / 0 / 5 | ⚠️ UI, ritmo muy bajo |
| **`red-blox/Zap`** | 63 d | 0 / 1 / 20 | ⚠️ Codegen de red, vivo a ritmo lento |

**El matiz que evita una conclusión injusta:** para una *biblioteca* de Luau, "sin commits" no significa lo mismo que para un escáner de seguridad. Luau es retrocompatible y la API de Roblox no rompe. `ProfileStore` o `Promise` pueden estar terminados. **Para el toolchain sí importa**, porque el toolchain persigue cambios de la plataforma: que Wally lleve 497 días parado es un riesgo real de suministro.

**Regla de diseño que se deriva de esta tabla:** *minimiza dependencias de terceros y prefiere primera parte*. Un juego de Roblox construido por un agente debería apoyarse en la API del motor, no en cinco frameworks comunitarios congelados. Esto tiene que ir escrito en `CLAUDE.md`.

### 4.4 Qué debe dominar el agente (conocimiento, no herramientas)

Esto va en `.claude/rules/` y en skills, no en instalaciones:

- **Arquitectura servidor/cliente y autoridad de servidor.** El cliente miente siempre. Toda validación en servidor. Esta regla sola previene la mayoría de exploits.
- **RemoteEvent / RemoteFunction**: validación de tipos y de rate-limit en el borde; nunca confiar en argumentos; `RemoteFunction` en servidor puede colgarse si el cliente no responde.
- **DataStore**: presupuesto de peticiones, `UpdateAsync` sobre `SetAsync`, sesión-locking para evitar duplicación de items. `ProfileStore` implementa esto; si no lo usas, tendrás que reimplementarlo bien.
- **ModuleScripts** y frontera de requires; `ServerScriptService` vs `ReplicatedStorage` vs `StarterPlayerScripts`.
- **Optimización**: streaming, `task.wait` vs `RunService`, coste de replicación, presupuesto de instancias.
- **Estructura de proyecto**: `default.project.json` de Rojo como fuente de verdad de la jerarquía.

---

## PARTE 5 — UEFN: qué cambió el 20 de agosto y qué sigue sin existir

### 5.1 Unreal MCP en UEFN — cinco días de vida

`[fuente secundaria: notas de la versión 42.00 de Epic, anuncio en fortnite.com, foro oficial]`

Fortnite v42.00 salió el **20 de agosto de 2026**. Con él, **Unreal MCP —el plugin MCP que ya venía con UE 5.8— llega a UEFN, integrado en el editor**, sin instalación aparte. Se activa en **Project Settings → Beta Access → UEFN MCP Toolset**, y se conecta cualquier cliente MCP: Claude Code, Codex, Cursor.

Capacidades anunciadas: **escribir y compilar Verse**, colocar y configurar devices, crear entidades de Scene Graph, construir UI con UMG, y **ejecutar sesiones de juego** para probar el resultado. Y un detalle importante de diseño: *todo lo que crea el agente es parte real y editable del proyecto* — ficheros Verse que abres, devices que ajustas en el panel Details, entidades que seleccionas en el outliner.

**Es la mejor noticia posible para el perfil B, y también la más frágil: tiene cinco días.** No hay experiencia acumulada, no hay bugs conocidos catalogados, no hay comparativas. Cualquiera que te diga hoy que sabe cómo se comporta en un proyecto de tres meses, se lo está inventando.

Contexto estratégico relevante: Epic ha declarado que **UE6 fusionará UE5 y UEFN**. Lo que aprendas de este toolset probablemente sobreviva; los detalles concretos, no necesariamente.

### 5.2 El activo que nadie aprovecha: los digests de Verse

Todo proyecto Verse genera **ficheros digest**: un listado autogenerado de todos los símbolos públicos —módulos, funciones, clases— que ha procesado el compilador.

- `Fortnite.digest.verse` — la API de Fortnite
- `UnrealEngine.digest.verse` — la API de Unreal
- `Assets.digest.verse` — los assets de *tu* proyecto

Ubicación reportada: `C:\Users\<USUARIO>\AppData\Local\UnrealEditorFortnite\Saved\VerseProject\FortniteGame\` `[fuente secundaria]`.

**Esto resuelve el problema número uno de escribir Verse con un LLM: la alucinación de APIs.** Es un fichero de texto, en tu disco, con las firmas exactas. Una regla en `CLAUDE.md` del tipo *"antes de usar cualquier símbolo de Fortnite o Unreal, verifícalo con grep contra el digest correspondiente; si no aparece, no existe"* convierte una fuente constante de errores en una comprobación de coste casi cero.

No necesitas ningún MCP de documentación de Verse para esto. Ya lo tienes.

### 5.3 Lo que UEFN sigue sin tener — y por qué limita la autonomía

| Necesidad | Estado real | Impacto |
|---|---|---|
| **Framework de tests unitarios para Verse** | **No existe.** Ni oficial ni comunitario creíble. Los frameworks de test de Unreal (CQTest, Automation, Gauntlet) son para C++ en UE estándar, **no para Verse en UEFN** | El agente **no puede demostrar corrección** salvo jugando |
| **Ejecución headless / CI** | **No existe** equivalente al Open Cloud de Roblox | Sin GUI no hay verificación. No hay pipeline nocturno |
| **Debugging** | `Print` del módulo Diagnostics hacia el output log es la vía principal y establecida. El soporte de breakpoints es ambiguo entre fuentes | Depuración por logs, no por inspección de estado |
| **Language server externo** | Existe **la extensión oficial de Verse para VS Code de Epic (LSP)**, pensada para editar y empujar ficheros a la sesión de UEFN | Existe un LSP, pero **ningún agente lo integra hoy** |
| **Gramática tree-sitter para Verse** | **No existe mantenida.** `verse-lang/tree-sitter-verse` lleva **2 814 días** parado y además corresponde a otro lenguaje llamado Verse, no al de Epic | Ninguna herramienta de AST/code-graph funciona con Verse |
| **Control de versiones** | Unreal Revision Control es propio de UEFN y no interopera. Git sobre la carpeta del proyecto se usa en la práctica `[fuente secundaria]` | Viable con cuidado; los binarios de UEFN no hacen buen diff |
| **Python de editor** | Beta con lista de permitidos. Hay creadores pidiendo acceso en el foro oficial en agosto de 2026. Solo automatización de editor; **la lógica de juego sigue siendo Verse** | No cuentes con ello |

### 5.4 Consecuencia honesta

**El perfil UEFN no puede alcanzar el mismo nivel de autonomía que el perfil Roblox, y no es un problema de herramientas: es un problema de plataforma.** Sin ejecución headless y sin framework de tests, la única evidencia de que algo funciona es una sesión de juego observada. Eso exige un editor abierto y, en la práctica, un humano mirando.

Cualquier propuesta que te prometa "un agente autónomo que construye tu isla de Fortnite mientras duermes" está vendiendo humo en agosto de 2026.

---

## PARTE 6 — Code graph: la pregunta con la respuesta más contraintuitiva

Preguntabas si existe algo mejor que Serena, ast-grep o Repomix. La respuesta tiene dos mitades, una por lenguaje.

### 6.1 Para Luau

Primero, los hechos medidos:

- **Serena soporta Luau explícitamente.** Su documentación lista Luau como lenguaje propio, separado de Lua, entre más de 40. Actividad: 116 commits/30 d, 704 ficheros de test, 52 autores.
- **ast-grep NO soporta Luau.** Su enumeración de lenguajes incluye `Lua`, no `Luau`. Luau es un superconjunto con anotaciones de tipo, genéricos y casts `::`. **Una gramática de Lua fallará al parsear Luau tipado**, que es exactamente el estilo que quieres que escriba el agente. `[deducción técnica a partir de la lista de lenguajes; no lo he ejecutado]`
- **`code-graph-rag`** (931 commits/30 d, extremadamente activo) soporta "Lua", mismo problema, y además exige **Memgraph**. Complejidad alta, beneficio dudoso aquí.
- **`sourcegraph/scip`** está vivo (9/30 d) pero no hay indexador SCIP para Luau. **`github/stack-graphs`**: 349 días parado.
- **`luau-lsp` es el servidor de lenguaje real de Luau**, con 16 commits/30 d, y —dato clave— **corre en modo standalone como `luau-lsp analyze`, con resolución completa de Rojo y tipos de la API de Roblox**, pensado para CI.

Y ahora el hecho que cambia la recomendación: **Claude Code tiene LSP nativo.** Arranca automáticamente los servidores LSP que aporten los plugins instalados y expone definiciones, referencias, hover, símbolos de documento y de workspace, implementaciones, jerarquía de llamadas y **diagnósticos en tiempo real**. No está activo por defecto.

Es decir: **puedes tener code intelligence de Luau sin ningún servidor MCP**, envolviendo `luau-lsp` en un plugin LSP local. Coste en contexto: **cero herramientas MCP**. Serena, en cambio, carga su superficie de herramientas en cada sesión —la comunidad la estima en torno a 24 000 tokens, motivo por el que existen forks "slim"—.

**¿Entonces Serena sobra?** No necesariamente, y aquí está la mejor evidencia independiente que he encontrado, en ambas direcciones:

> **A favor** — Benchmark de ManoMano (19-mar-2026, medido el 2-feb-2026 con Sonnet 4.5) sobre un servicio de pagos Java real: 381 clases, 36 407 líneas, 1 017 tests. En la tarea de refactor masivo:
> - Claude vainilla: 12 subagentes, 1 hora, **23,54 $**, proyecto que **no compila**.
> - Claude Code **con LSP nativo**: 1 hora, **28,63 $**, se rindió tras tres iteraciones con **9 tests fallando**.
> - Claude + **Serena**: **45 minutos, 27,30 $, compila y pasan los 1 017 tests**.
>
> **En contra** — El mismo cuerpo de evidencia recoge que, para una consulta simple de localizar una regla de negocio, **Serena costó casi 4× más y tardó un 60 % más** que Claude vainilla.
>
> **Del propio mantenedor de Serena** (discusión #1592, junio 2026): admite que las ganancias de tokens *"dependen del escenario"* y que aún estaban preparando benchmarks públicos. Su argumento es indirecto y razonable: recuperar sólo lo necesario y editar de forma fiable ahorra tokens *por consecuencia*, no por compresión.

**Mi decisión:** `luau-lsp` es **INSTALAR**. Serena es **PROBAR PRIMERO**, con un criterio de aceptación explícito: instalarla sólo cuando tengas una refactorización real que cruce más de 10 ficheros, y medir `/context` y `ccusage` antes y después. Si tu proyecto está por debajo de ~10 000 líneas de Luau, la evidencia disponible dice que **pierdes** dinero y velocidad.

**Repomix: opcional.** Con Rojo, el proyecto ya está en el sistema de ficheros y Claude Code lee ficheros nativamente. Repomix aporta en auditorías puntuales del repo completo, con `--sandbox`. No es una pieza del día a día.

### 6.2 Para Verse

**Ninguna de las tres funciona.** No hay gramática tree-sitter mantenida, no hay indexador, y el único LSP es la extensión de Epic para VS Code, que ningún agente integra.

La sustitución honesta es de baja tecnología y funciona:
1. **grep sobre los digests** para verificar cualquier símbolo antes de usarlo.
2. **grep sobre tu propio código** para referencias.
3. **El compilador como oráculo**: compilar Verse por el MCP de UEFN y leer los errores. En Verse, el compilador *es* tu herramienta de análisis estático.

### 6.3 Respuesta directa a "¿una, dos o ninguna?"

| Perfil | Serena | ast-grep | Repomix | Respuesta |
|---|---|---|---|---|
| **Roblox** | Probar primero | **No** (no soporta Luau) | Opcional | **Una como mucho** — y sólo tras probar que el LSP nativo con `luau-lsp` no basta |
| **UEFN** | **No** | **No** | Opcional | **Ninguna** |

La mejor relación *comprensión del proyecto / consumo de tokens* la da, en ambos casos, algo que no es ninguna de las tres: **una jerarquía de ficheros bien diseñada y descrita en `CLAUDE.md`**, más el servidor de lenguaje donde exista. Un `default.project.json` de Rojo legible y una convención de nombres estricta ahorran más tokens que cualquier índice semántico.

---

## PARTE 7 — Research agent: no instales ninguno

Preguntabas si hacen falta GPT Researcher, Local Deep Research o MCPs de búsqueda. Respuesta: **no, y en este dominio concreto serían peores.**

Motivo: la investigación que necesitas **no es investigación web abierta**. Es consulta de documentación de API de dos plataformas cerradas. Y esa documentación está disponible en formatos mucho mejores que una búsqueda:

| Necesidad | Solución de coste casi cero | Por qué gana a un research agent |
|---|---|---|
| API de Roblox, guías, patrones | **`git clone https://github.com/Roblox/creator-docs`** — 9 295 ficheros, 49 commits/30 d | Documentación oficial completa, grepeable en local, sin latencia de red, sin alucinación, versionada. Un agente de research te daría un resumen de segunda mano de esto mismo |
| API de Verse y Fortnite | **Los digests en disco** | Es la fuente de verdad del compilador. Superior a cualquier documentación |
| Tipos de la API de Roblox en el editor | **`luau-lsp` los incorpora** | Verificación en tiempo de escritura, no de lectura |
| Novedades de plataforma, cambios de versión | **WebSearch/WebFetch nativos** | Puntual y suficiente |
| Analizar juegos de referencia, patrones de diseño | Claude Code nativo + criterio humano | Ningún agente automatiza el buen gusto |

**Descartados y por qué:**
- **GPT Researcher** (29 commits/30 d, 178 autores, sano): excelente para investigación abierta con síntesis y citas. Aquí resolvería un problema que no tienes, con coste de tokens alto.
- **Local Deep Research** (≥100/30 d, 66 workflows CI, 2 132 tests — técnicamente impresionante): mismo argumento.
- **MCPs de documentación de Verse** de terceros: te ponen un intermediario entre el agente y un fichero que ya está en tu disco y es más exacto.
- **Crawling (Firecrawl, Crawl4AI)**: la documentación de Epic devuelve 403 a rastreadores, como he comprobado en esta misma sesión. No lo vas a resolver con un crawler.

**La única "instalación" de esta capa es un `git clone` y una regla en `CLAUDE.md`** que diga dónde está la documentación local y que debe consultarse antes que la web.

---

## PARTE 8 — El agent loop: el corazón del sistema

Esta es la parte que más determina si tienes un agente o un generador de código.

### 8.1 El principio

> **El agente no puede declarar "terminado". Sólo puede presentar evidencia, y la evidencia la comprueba una máquina.**

Esto no se consigue con un framework. Se consigue con **hooks**, que es la única parte de Claude Code que es determinista: se ejecutan siempre, no cuando el modelo decide.

### 8.2 Superpowers vs Spec Kit: complementarios, pero no los dos

Se solapan más de lo que parece. Ambos imponen el mismo ciclo: entender → diseñar → planificar → implementar → verificar.

| | Spec Kit | Superpowers |
|---|---|---|
| Mantenimiento | GitHub, ≥100 commits/30 d, 25 workflows, 162 tests | MIT, ≥100 commits/90 d, autor único dominante |
| Cómo se activa | **Bajo demanda**, cuando invocas el flujo | **Siempre**, vía hook de session-start |
| Coste recurrente | Prácticamente cero cuando no lo usas | Real y constante. El issue #190 documentó 22 448 tokens de skills cargadas al arranque (~11 % de una ventana de 200 k); el autor lo corrigió en dos días y dedicó la v6.1.0 a comprimir el bootstrap |
| Evidencia de beneficio | Metodología estándar de la industria | Una medición comunitaria: 9 % más barato y 14 % menos tokens en tareas no triviales, **más caro en tareas simples** |

**Decisión: Spec Kit sí, Superpowers no — al principio.** Razón: en desarrollo de juegos alternas constantemente entre trabajo grande (un sistema de inventario) y trabajo minúsculo (ajustar una constante de daño). Un harness siempre activo penaliza el segundo caso, que es la mayoría de tus interacciones. Spec Kit lo invocas para lo grande y desaparece para lo pequeño.

**Léete las skills de Superpowers igualmente.** La metodología es correcta y es gratis; lo que cuesta es el harness.

### 8.3 El ciclo, implementado de verdad

No con un framework: con cuatro piezas nativas.

```
   [1] PLAN            → plan mode + Spec Kit + docs/decisiones/
        ↓
   [2] IMPLEMENT       → LSP nativo (luau-lsp) + edición de ficheros (Rojo)
        ↓                  · Verse: MCP de UEFN + grep contra digests
   [3] VERIFY ESTÁTICO → hook PostToolUse:
        ↓                  luau-lsp analyze + selene + StyLua --check
   [4] TEST            → Lune/Lute (lógica pura, sin motor)
        ↓                  Studio MCP execute_luau (lógica con motor)
   [5] OBSERVE         → get_console_output + screen_capture
        ↓                  user_keyboard_input + character_navigation
   [6] DEBUG / FIX     → vuelta a [2] con evidencia concreta
        ↓
   [7] GATE            → hook Stop: si el build o los tests fallan,
        ↓                  el turno NO se cierra como completo
   [8] REVIEW          → subagente con contexto limpio + /security-review
        ↓
   [9] RECORD          → docs/decisiones/NNN-*.md antes de continuar
```

**Las dos piezas que hacen que esto sea un ciclo y no una sugerencia:**

- **Hook `PostToolUse`** sobre escrituras de `*.luau`: ejecuta `luau-lsp analyze` y `selene` sobre el fichero tocado. El agente recibe el error **inmediatamente**, no tres pasos después.
- **Hook `Stop`**: comprueba que la última ejecución de la suite pasó. Si no, el turno no se da por bueno. Esto es lo que impide el "ya terminé" sin evidencia.

En UEFN, el paso [3] se sustituye por *compilar Verse vía MCP y leer errores*, y el paso [4] **no existe**. Por eso el perfil B tiene techo.

### 8.4 Autonomía con control, no sin él

Tres cosas que **no** debe poder hacer el agente sin ti, y cómo imponerlo:

1. **Publicar el juego.** Nunca en un hook, nunca en una skill automática. Acción manual.
2. **Tocar datos de producción** (DataStores de un juego con jugadores). Separa universo de desarrollo del de producción; el token de Open Cloud del agente sólo alcanza al de desarrollo.
3. **Instalar dependencias nuevas** sin pasar por `osv-scanner` y una revisión tuya.

---

## PARTE 9 — Testing y self-debugging: cómo se demuestra "hecho"

Cuatro niveles de evidencia, de más barato a más caro. **El agente debe subir por ellos en orden.**

| Nivel | Roblox | UEFN | Coste | Qué demuestra |
|---|---|---|---|---|
| **1 · Tipos y lint** | `luau-lsp analyze` (con resolución de Rojo y tipos de la API), `selene`, `StyLua --check` | Compilación de Verse vía MCP | Segundos, sin motor | Que compila y no viola convenciones |
| **2 · Unitario headless** | **Lune** o **Lute** ejecutando lógica pura | **No existe** | Segundos | Que la lógica de negocio es correcta |
| **3 · En motor** | `execute_luau` en `Server` y `Client` vía Studio MCP | Sesión de juego vía MCP | Decenas de segundos | Que funciona con la API real |
| **4 · Jugado** | `start_stop_play` + `user_keyboard_input` + `character_navigation` + `get_console_output` + `screen_capture`; subagente `playtest` | Play session observada | Minutos | Que la mecánica *se siente* como debe |
| **5 · CI sin GUI** | **Open Cloud Luau Execution** (5 min/tarea, 10 concurrentes) sobre RBXL construido con Rojo | **No existe** | Minutos | Que no hay regresión, sin humano |

**Decisión sobre framework de tests:** ninguno de los populares está vivo. TestEZ (**1 302 días**), jest-lua (**609**), tiniest (415), EzSpec (**1 738**). Recomendación: **escribe un runner mínimo propio sobre Lune o Lute** —cincuenta líneas: descubrir ficheros `*.spec.luau`, ejecutarlos, contar fallos, salir con código distinto de cero—. Suena a herejía; es lo correcto. Adoptar una dependencia muerta para ahorrarte cincuenta líneas es peor negocio que mantener cincuenta líneas.

**Cómo se separa la lógica para que esto funcione:** el agente debe escribir la lógica de juego en ModuleScripts puros que no toquen servicios de Roblox, y dejar los servicios en una capa fina. Eso hace que el nivel 2 cubra la mayor parte del código. **Esta es la regla de arquitectura más importante de todo el informe**, porque es la que convierte "probar un juego" en algo automatizable. Va en `CLAUDE.md`, no en una herramienta.

---

## PARTE 10 — Seguridad con un agente cada vez más autónomo

Se mantiene lo de la investigación anterior, con dos matices propios de este dominio.

| Control | Herramienta | Por qué aquí |
|---|---|---|
| **Aislamiento de procesos** | Sandbox de Bash nativo + **`srt`** (`anthropic-experimental/sandbox-runtime`, 52 commits/30 d, Apache-2.0, *beta research preview*) | Envolver binarios de terceros del toolchain |
| **Auditoría de MCP y skills** | **`snyk/agent-scan`** (49/30 d, 339 tests, 9 issues) | Antes de conectar cualquier MCP comunitario de Roblox |
| **Secretos** | **`gitleaks`** vía `pre-commit` | **Crítico aquí**: las claves de Open Cloud son credenciales de producción con acceso a datos de jugadores |
| **Dependencias** | `osv-scanner` + `safedep/vet` | Cada paquete de Wally o pesde que el agente proponga |
| **Revisión del diff** | `/security-review` nativo | Antes de cada merge |

### Los dos matices del dominio

1. **Los MCP del editor son de máxima confianza por diseño.** La propia documentación de Roblox lo dice: *"MCP clients can read and modify content in your open Roblox places"*. No hay forma de sandboxearlos: **son el editor**. La mitigación no es técnica, es de proceso: trabaja siempre sobre un place de desarrollo, nunca con Studio abierto en el place de producción mientras el agente actúa.

2. **La seguridad del juego es una categoría aparte de la seguridad del entorno.** Que tu entorno esté sandboxeado no impide que el agente escriba un `RemoteEvent` que permita a cualquier cliente darse mil monedas. **Esto no lo resuelve ninguna herramienta de esta lista.** Se resuelve con una regla explícita en `.claude/rules/*.server.luau.md` —autoridad de servidor, validar todo argumento remoto, nunca confiar en el cliente— y con una skill de revisión específica de exploits que se invoque antes de publicar.

**Permisos mínimos concretos:**
- Token de Open Cloud: sólo el universo de desarrollo, sólo los scopes que uses.
- Token de GitHub: repositorios concretos, nunca `repo` completo.
- Nunca `--dangerously-skip-permissions` fuera de un contenedor desechable.

---

## PARTE 11 — Optimización de tokens: qué ahorra de verdad

Ordenado por ahorro real, **no por lo que promete cada README**.

| Palanca | Ahorro | Evidencia | Coste |
|---|---|---|---|
| **Arquitectura de ficheros pequeña y predecible** | **El mayor de todos** | Estructural: si un sistema vive en un fichero de 150 líneas con nombre evidente, el agente lee 150 líneas en vez de explorar | Cero. Es diseño |
| **Documentación oficial en local** (`creator-docs`, digests) | Alto | Grep local en vez de búsqueda web y lectura de páginas | Un clone |
| **Subagentes para exploración** | Alto | Nativo: el subagente consume su propia ventana y devuelve sólo el resumen | Cero |
| **LSP nativo + `luau-lsp`** | Alto | Recuperar un símbolo en vez de leer el fichero. **Cero herramientas MCP cargadas** | Un binario |
| **`.claude/rules/` con ámbito por fichero** | Medio | Las reglas de servidor no se cargan al editar UI | Cero |
| **Skills con carga progresiva** | Medio | ~100 tokens por skill dormida | Cero |
| **Caché de prompt (1 h)** | Medio | Nativo | Cero |
| **`/compact` y `/btw`** | Medio | Nativo | Cero |
| **Serena** | **Disputado** | Gana claramente en refactors grandes (ManoMano); **pierde 4× en consultas simples**. Su propio mantenedor dice que depende del escenario | ~24 k tokens de superficie de herramientas |
| **Repomix** | Bajo en uso diario | Útil sólo para empaquetados dirigidos | Bajo |
| **Compresores de contexto genéricos** | **Negativo** | El mantenedor de Serena, sobre Headroom: *"gran parte de lo que hace es activamente dañino y contraproducente"*; un error de compresión puede arruinar una sesión entera | — |

### Cómo medir en serio

Antes y después de cada instalación, tres números:

1. **`/context`** — tokens de arranque. Si sube más de 5 000 sin beneficio demostrable, revierte.
2. **`ccusage`** — coste por tarea comparable. Define una tarea patrón, por ejemplo *"añade un sistema de inventario con persistencia"*, y ejecútala antes y después.
3. **Latencia y calidad** — tiempo hasta el primer test verde y número de iteraciones hasta pasar. Es el número que de verdad importa: **una herramienta que gasta 20 % más tokens pero convierge en 3 iteraciones en vez de 8 es una ganancia enorme.**

**No aceptes ninguna afirmación de ahorro que no puedas reproducir con estos tres números en tu propio proyecto.**

---

## PARTE 12 — Análisis de redundancias

| Combinación | Veredicto |
|---|---|
| Auto-memoria + basic-memory + Graphiti + Cognee | **Frankenstein.** Cuatro fuentes contradictorias sin arbitraje. **Quédate con una** |
| Serena + ast-grep + Repomix | **Dos sobran.** ast-grep no soporta Luau; Repomix es puntual. Como mucho Serena, y sólo tras probar el LSP nativo |
| Serena + LSP nativo con `luau-lsp` | **Solapamiento del 80 %.** Ambos dan símbolos, referencias y diagnósticos. Serena añade edición a nivel de símbolo y memorias de proyecto, y cuesta ~24 k tokens de superficie. **Empieza por el nativo** |
| Superpowers + Spec Kit | **Se pisan.** Mismo ciclo, distinto momento de activación. **Spec Kit** |
| Studio MCP oficial + MCP comunitario de Roblox | **Redundante** salvo necesidad específica de multijugador. Primera parte primero |
| MCP de documentación de Verse + digests en disco | **Redundante y peor.** El digest es la fuente de verdad |
| GPT Researcher + WebSearch nativo + creator-docs local | **Redundante.** El clone local gana en exactitud y coste |
| Lune + Lute | **Redundante.** Elige uno. Lute lo hace el equipo de Luau y su `std` converge con Roblox; Lune tiene más rodaje y ecosistema |
| Wally + pesde | **Redundante y ambos discutibles.** Wally lleva 497 días parado. Minimiza dependencias y el problema desaparece |
| Rojo + Studio MCP | **Complementarios, no redundantes.** Rojo da git, ficheros y CI; el MCP da ejecución y observación. **Necesitas los dos** |
| `luau-lsp` + `selene` | **Complementarios.** Uno da tipos, el otro reglas de estilo y errores lógicos |
| ccusage + OTEL | **Complementarios.** ccusage es cero-fricción; OTEL es para cuando quieras trazas por herramienta |

---

## PARTE 13 — Arquitectura final

```
╔══════════════════════════════════════════════════════════════╗
║  CAPA 0 · CLAUDE CODE NATIVO — no duplicar nada de esto      ║
║  plan mode · subagentes anidados · skills · hooks ·          ║
║  LSP nativo · sandbox de Bash · auto-memoria · /context ·    ║
║  /compact · OTEL · /security-review · worktrees              ║
╚══════════════════════════════════════════════════════════════╝
        │
        ├─ MOTOR ────────► Studio MCP (Roblox)  ·  Unreal MCP (UEFN)
        │                  ▲ la pieza nº1. Ejecutar, probar, observar
        │
        ├─ CÓDIGO ───────► luau-lsp  (LSP nativo, sin MCP)
        │                  digests de Verse  (grep, sin herramienta)
        │
        ├─ VERIFICACIÓN ─► hooks PostToolUse (analyze + selene)
        │                  hook Stop (puerta de evidencia)
        │                  Lune|Lute (unitario)  ·  Open Cloud (CI)
        │
        ├─ CONOCIMIENTO ─► creator-docs clonado  ·  digests
        │                  CLAUDE.md + .claude/rules/
        │                  docs/decisiones/  ◄── la memoria real
        │
        ├─ PROYECTO ─────► Rojo + Rokit  ·  git
        │
        ├─ SEGURIDAD ────► gitleaks+pre-commit · osv-scanner
        │                  srt · agent-scan · /security-review
        │
        └─ MEDICIÓN ─────► ccusage  ·  /context
```

**Nota de diseño:** no hay capa "orquestación" ni "multi-agente". Claude Code ya anida subagentes hasta profundidad 3 con 20 concurrentes. Añadir un orquestador encima multiplica coste sin añadir capacidad.

---

## PARTE 14 — Los dos perfiles

### Compartido por ambos (7 piezas)

| Pieza | Tipo | Coste de instalación |
|---|---|---|
| Claude Code nativo bien configurado | Configuración | Horas de criterio, cero instalación |
| `docs/decisiones/` + `CLAUDE.md` + `.claude/rules/` | Convención | Cero |
| Spec Kit | Plantillas | Baja |
| `gitleaks` + `pre-commit` | Binario | Baja |
| `osv-scanner` | Binario | Baja |
| `ccusage` | `npx`, sin instalación permanente | Nula |
| `srt` (sandbox-runtime) | Binario global | Media |

### PROFILE A — ROBLOX (5 piezas específicas)

| Pieza | Por qué | Decisión |
|---|---|---|
| **Studio MCP oficial** | Ejecutar, probar, observar, ver. Cierra el ciclo | **INSTALL** (interruptor) |
| **`luau-lsp`** como plugin LSP + `analyze` en hooks | Semántica de Luau + puerta de tipos. Sin coste MCP | **INSTALL** |
| **Rojo** (+ `Rokit` para fijar versiones) | Ficheros, git, CI. Sin esto no hay control de versiones real | **INSTALL** |
| **`selene`** + **`StyLua`** | Lint y formato deterministas en el hook | **INSTALL** |
| **Lune** *o* **Lute** + runner propio | El nivel 2 de evidencia | **INSTALL** (elige uno) |
| `creator-docs` clonado | Documentación oficial local | **INSTALL** (`git clone`) |
| Open Cloud Luau Execution | CI sin GUI | **FASE 7** |
| Serena | Sólo si el proyecto crece | **PROBAR PRIMERO** |

### PROFILE B — UEFN (3 piezas específicas)

| Pieza | Por qué | Decisión |
|---|---|---|
| **Unreal MCP en UEFN** | Escribir y compilar Verse, devices, Scene Graph, UMG, play sessions | **INSTALL con cautela** — 5 días de vida |
| **Regla de digests** | Antídoto contra alucinación de API | **INSTALL** (es una regla, no software) |
| **git sobre la carpeta del proyecto** | Historial real; UEFN Revision Control no interopera | **INSTALL con cuidado** con los binarios |
| Extensión Verse de Epic para VS Code | Para ti, no para el agente | **OPCIONAL** |
| Cualquier tooling de Unreal genérico | **No es compatible con UEFN.** CQTest, Automation y Gauntlet son de UE estándar | **NO INSTALAR** |

**Total: 7 compartidas + 5 Roblox + 3 UEFN.** Si trabajas sólo en Roblox: **12**. Sólo en UEFN: **10**. Y de esas, tres son interruptores y cuatro son binarios sin estado.

---

## PARTE 15 — Ranking

### TOP: absolutamente necesarias (8, no 10)

Sólo llegan ocho a este nivel. Añadir dos más para redondear sería exactamente el error que me pediste evitar.

1. **Studio MCP oficial** (Roblox) / **Unreal MCP** (UEFN) — sin esto no hay agente de juegos, sólo un escritor de scripts.
2. **`luau-lsp`** — semántica de Luau y puerta de tipos. La mejor relación capacidad/coste del stack.
3. **Rojo** — sin ficheros no hay git, ni CI, ni revisión, ni reversibilidad.
4. **Hooks de verificación** (`PostToolUse` + `Stop`) — lo único que convierte "creo que funciona" en evidencia.
5. **`CLAUDE.md` + `.claude/rules/` + `docs/decisiones/`** — la memoria que de verdad usarás.
6. **`selene` + `StyLua`** — feedback determinista y barato en cada escritura.
7. **`gitleaks` + `pre-commit`** — las claves de Open Cloud son credenciales de producción.
8. **`creator-docs` clonado / digests de Verse** — la fuente de verdad de la API, en local.

### HIGH VALUE (6)

9. **Lune o Lute + runner propio** — el nivel 2 de evidencia. Sube a "necesaria" en cuanto tengas lógica de negocio real.
10. **Spec Kit** — para features de varias sesiones.
11. **Open Cloud Luau Execution** — CI nocturno sin GUI. Sólo Roblox.
12. **`ccusage`** — riesgo cero, mide lo que decides.
13. **`osv-scanner`** — cada dependencia que el agente proponga.
14. **`srt`** — cuando empieces a añadir binarios de terceros.

### OPTIONAL (4)
`Rokit` (fija versiones del toolchain; imprescindible si trabajas en equipo) · **Serena** (proyectos grandes, tras medir) · **Repomix** (auditorías puntuales, con `--sandbox`) · **MCP de GitHub** (si el flujo de PRs es central).

### EXPERIMENTAL (3)
**Unreal MCP en UEFN** — sí, es necesaria *y* experimental a la vez: es la única vía y tiene cinco días. · **`pesde`** como alternativa a Wally. · **`Chrrxs/robloxstudio-mcp`** para escenarios de multijugador que el oficial no cubra.

### REDUNDANT (7)
`ast-grep` (no soporta Luau) · Repomix en uso diario · MCPs comunitarios de Studio ahora que existe el oficial · MCPs de documentación de Verse · GPT Researcher y Local Deep Research para este dominio · Superpowers junto a Spec Kit · cualquier segundo sistema de memoria.

### AVOID (6)
Frameworks multi-agente sobre Claude Code · **TestEZ** (1 302 días), **jest-lua** (609), **EzSpec** (1 738) — muertos · **Knit** (755 días) y frameworks comunitarios congelados como base de arquitectura · Herramientas de test de Unreal (CQTest, Automation, Gauntlet) para UEFN — **no son compatibles** · Compresores genéricos de contexto tipo Headroom · `run-in-roblox` (2 227 días), sustituido por MCP y Open Cloud.

---

## PARTE 16 — Matriz de decisión

| Herramienta | Capacidad que aporta | ¿Claude ya lo hace? | Beneficio | Tokens | Latencia | Seguridad | Complejidad | Roblox | UEFN | **Decisión** |
|---|---|---|---|---|---|---|---|---|---|---|
| **Studio MCP (oficial)** | Ejecutar, probar, observar en el motor | **No** | Muy alto | Medio | Baja | Confianza total por diseño | Baja (interruptor) | ✅ | — | **INSTALL** |
| **Unreal MCP (UEFN)** | Escribir/compilar Verse, devices, play | **No** | Muy alto | Medio | Media | Confianza total; beta | Baja | — | ✅ | **INSTALL con cautela** |
| **`luau-lsp`** (LSP nativo + analyze) | Símbolos, referencias, tipos | Parcial: LSP nativo sin servidor | Muy alto | **Negativo (ahorra)** | Baja | Local | Baja | ✅ | — | **INSTALL** |
| **Rojo** | Proyecto en ficheros ↔ Studio | **No** | Muy alto | Neutro | Baja | Local | Media | ✅ | — | **INSTALL** |
| **Hooks de verificación** | Puerta de evidencia | Sí (mecanismo), no (contenido) | Muy alto | Bajo | Baja | Refuerza | Baja | ✅ | ✅ | **INSTALL** |
| **`selene` + `StyLua`** | Lint y formato | No | Alto | Bajo | Muy baja | Local | Baja | ✅ | — | **INSTALL** |
| **`docs/decisiones/` + rules** | Memoria de decisiones | Parcial | Alto | **Negativo** | Cero | Ninguno | Muy baja | ✅ | ✅ | **INSTALL** |
| **`creator-docs` local** | API oficial grepeable | No | Alto | **Negativo** | Cero | Ninguno | Muy baja | ✅ | — | **INSTALL** |
| **Digests de Verse** | API real de Verse | No | Muy alto | **Negativo** | Cero | Ninguno | Nula | — | ✅ | **INSTALL** |
| **`gitleaks` + pre-commit** | Secretos | No | Alto | Cero | Baja | Refuerza | Baja | ✅ | ✅ | **INSTALL** |
| **Lune / Lute + runner** | Test unitario headless | No | Alto | Bajo | Baja | Local | Media | ✅ | ❌ | **INSTALL (uno)** |
| **Spec Kit** | Metodología bajo demanda | Parcial (plan mode) | Alto | Bajo | Cero | Plantillas | Baja | ✅ | ✅ | **INSTALL** |
| **Open Cloud Luau Exec** | CI sin GUI | No | Alto | Bajo | Media | **Credenciales de producción** | Media | ✅ | ❌ | **INSTALL en Fase 7** |
| **`ccusage`** | Medición de coste | Parcial (`/usage`) | Medio | Cero | Cero | Sin red | Nula | ✅ | ✅ | **INSTALL** |
| **`osv-scanner`** | Vulnerabilidades de dependencias | No | Medio | Cero | Baja | Refuerza | Baja | ✅ | ✅ | **INSTALL** |
| **`srt`** | Aislar binarios de terceros | Parcial (sandbox Bash) | Medio | Cero | Baja | **Refuerza mucho** | Media | ✅ | ✅ | **INSTALL** |
| **`Rokit`** | Fijar versiones del toolchain | No | Medio | Cero | Cero | Reproducibilidad | Baja | ✅ | — | **OPTIONAL** |
| **Serena** | Símbolos + edición semántica + memorias | **Sí, en gran parte** | Disputado | **~24 k de superficie** | Media | Lee y escribe código | Media | ⚠️ | ❌ | **TEST FIRST** |
| **Repomix** | Empaquetado de repo | Parcial | Bajo en diario | Medio | Baja | `--sandbox` disponible | Baja | ⚠️ | ⚠️ | **OPTIONAL** |
| **MCP de GitHub** | PRs, issues | No | Medio | Medio | Baja | **Token de GitHub** | Baja | ⚠️ | ⚠️ | **OPTIONAL** |
| **`Chrrxs/robloxstudio-mcp`** | Debug runtime, multijugador | No, pero el oficial casi | Medio | Medio | Baja | Confianza alta | Media | ⚠️ | — | **TEST FIRST** |
| **`pesde`** | Gestor de paquetes moderno | No | Bajo | Cero | Baja | Suministro | Baja | ⚠️ | — | **OPTIONAL** |
| **Superpowers** | Metodología siempre activa | Se solapa con Spec Kit | Medio | **Alto y recurrente** | Cero | Hook global | Media | ❌ | ❌ | **DO NOT INSTALL** (léelo) |
| **`ast-grep`** | Búsqueda estructural | Parcial | **Nulo aquí** | Bajo | Baja | Local | Baja | ❌ | ❌ | **DO NOT INSTALL** |
| **Graphiti / Cognee** | Grafo de conocimiento | Sí, suficientemente | Bajo aquí | **Alto** | Media | Base de datos extra | **Alta** | ❌ | ❌ | **DO NOT INSTALL** |
| **basic-memory** | Memoria Markdown por MCP | Sí, al principio | Medio a futuro | Medio | Baja | Inyección persistente | Media | ⚠️ | ⚠️ | **DO NOT INSTALL aún** |
| **GPT Researcher / LDR** | Investigación profunda | Sí, para este dominio | Bajo | **Alto** | Alta | Red | Media | ❌ | ❌ | **DO NOT INSTALL** |
| **TestEZ / jest-lua / EzSpec** | Test unitario | — | — | — | — | Abandonados | — | ❌ | ❌ | **DO NOT INSTALL** |
| **Knit / Matter / react-lua** | Frameworks de arquitectura | — | — | — | — | 638-755 días parados | — | ❌ | ❌ | **DO NOT INSTALL** |
| **CQTest / Gauntlet / Automation** | Test de Unreal | — | — | — | — | **Incompatibles con UEFN** | — | ❌ | ❌ | **DO NOT INSTALL** |

---

## PARTE 17 — Plan de instalación

**Una herramienta cada vez.** Tras cada una: comprobar que funciona · `/context` · `ccusage` · latencia · errores · seguridad · comparar con la medición anterior. **Si empeora, se quita.**

### FASE 0 — Baseline (sin instalar nada)
`/doctor` · `/context` y anotar tokens de arranque · `/sandbox` y verificar aislamiento · poner `~/.claude/` bajo git · `npx ccusage` para el coste actual · **definir la tarea patrón** con la que compararás todo (propuesta: *"añade un sistema de inventario persistente con UI mínima"*) · ejecutarla una vez y guardar los tres números.

### FASE 1 — Seguridad y medición
`gitleaks` + `pre-commit` → `osv-scanner` → `ccusage` como hábito. *Criterio: cero impacto en `/context`.*

### FASE 2 — Code intelligence
**Sólo `luau-lsp`.** Instalar el binario, verificar `luau-lsp analyze` en línea de comandos con resolución de Rojo, y después exponerlo como plugin LSP a Claude Code. *Criterio: el agente encuentra referencias sin leer ficheros enteros; la tarea patrón baja en tokens o en iteraciones.*
**No instales Serena en esta fase.** Es la comparación que quieres hacer más tarde, con datos.

### FASE 3 — Memoria
No se instala software. Se escribe: `CLAUDE.md`, tres o cuatro ficheros en `.claude/rules/`, y el primer `docs/decisiones/001-*.md`. *Criterio: reabrir el proyecto tras una semana y que el agente no pregunte nada que ya esté decidido.*

### FASE 4 — Investigación
`git clone` de `creator-docs` (Roblox) y localizar los digests (UEFN). Una regla en `CLAUDE.md`: consultar local antes que web. *Criterio: las búsquedas web por dudas de API caen a casi cero.*

### FASE 5 — Testing
`selene` + `StyLua` → hook `PostToolUse` → Lune o Lute + runner propio → hook `Stop` como puerta. *Criterio: el agente ya no puede cerrar un turno con el build roto.*

### FASE 6 — Tooling del motor
**Roblox:** Rojo (+ Rokit) → activar **Studio MCP** → quick-connect a Claude Code. **UEFN:** activar **UEFN MCP Toolset** en Beta Access → conectar → probar en un proyecto de usar y tirar, nunca en el bueno. *Criterio: el agente completa el ciclo implementar → playtest → leer consola → corregir sin ayuda.*

### FASE 7 — Autonomía
Open Cloud Luau Execution para CI nocturno con token limitado al universo de desarrollo → Spec Kit → `srt` alrededor de binarios de terceros → **y sólo entonces**, si el proyecto lo pide, evaluar Serena con la tarea patrón.

---

## PARTE 18 — Niveles de autonomía

| Nivel | Qué significa | Qué hace falta | Roblox | UEFN |
|---|---|---|---|---|
| **1** · Escribe código bajo instrucciones | "Escribe este script" | Claude Code nativo | ✅ Ya | ✅ Ya |
| **2** · Planifica + implementa | "Añade inventario" | + `CLAUDE.md`/rules + `luau-lsp` + Rojo | ✅ Fase 2 | ✅ Fase 6 |
| **3** · + prueba + corrige | Cierra el ciclo con evidencia | + selene/StyLua + hooks + Lune/Lute + **MCP del editor** | ✅ Fase 6 | ⚠️ **Parcial** — sin tests unitarios, la evidencia es una sesión jugada |
| **4** · Feature completa de principio a fin | "Sistema de combate con progresión" | + Spec Kit + `docs/decisiones/` + Open Cloud en CI | ✅ **Alcanzable, Fase 7** | ❌ **No hoy** |
| **5** · "Construye este juego" | Investigar → diseñar → implementar → probar → iterar → entregar | — | ⚠️ **No de forma fiable** | ❌ **No** |

---

## PARTE 19 — Objetivo realista: qué se automatiza y qué no

Me pediste ser crítico. Lo soy.

### Lo que sí se automatiza de forma fiable

- Implementar un sistema bien especificado con contratos claros.
- Refactorizar con red de seguridad de tipos y tests.
- Detectar y corregir errores de tipo, lint y compilación **sin intervención**.
- Escribir y ejecutar tests de lógica pura (Roblox).
- Verificar en el motor que una función hace lo que dice (`execute_luau`).
- Mantener consistencia de convenciones a lo largo de meses, si están escritas.
- Documentar decisiones — de hecho lo hace mejor que la mayoría de humanos.

### Lo que necesita supervisión

- **Diseño de juego.** Un agente puede implementar un loop de progresión; no sabe si es divertido. Nadie lo sabe sin probarlo con personas.
- **Balanceo.** Requiere criterio y datos de jugadores reales.
- **Rendimiento en carga.** El playtest de Studio con un jugador no predice 50 jugadores.
- **Seguridad anti-exploit.** El agente sigue reglas; los exploiters buscan lo que no está en las reglas.
- **Arte, audio, sensación.** El MCP genera meshes y materiales; la coherencia estética no.

### Lo que todavía no es fiable

- **UEFN por encima del nivel 3.** Sin ejecución headless ni tests, no hay bucle cerrado.
- **Sesiones muy largas sin puntos de control.** La deriva de contexto es real; por eso `docs/decisiones/` importa más que cualquier MCP de memoria.
- **"Construye este juego" de una sola frase.** No por falta de herramientas, sino porque un juego es miles de decisiones de producto, y delegarlas todas produce un juego genérico. El nivel 5 no está limitado por tecnología: está limitado por que **tú** eres quien sabe qué juego quiere.
- **El MCP de UEFN a 5 días de su lanzamiento.** Trátalo como beta hasta que tengas tus propias horas de vuelo.

### Lo que requiere intervención humana, siempre

Publicar. Tocar datos de jugadores reales. Aprobar gasto. Decidir el alcance. Decir "esto no es divertido, rehazlo".

---

## PARTE 20 — Respuesta a la pregunta única

> **¿Cuál es el mejor stack técnico posible para convertir Claude Code en un agente avanzado especializado en desarrollar juegos completos para Roblox Studio y UEFN?**

**Doce piezas para Roblox, diez para UEFN, y la más importante de todas es un interruptor que ya está en tu editor.**

La arquitectura es:

1. **Claude Code nativo** hace el 90 % del trabajo cognitivo y no hay que ayudarle: ya planifica, anida subagentes, tiene LSP, sandbox, hooks y memoria.
2. **El MCP del editor** es lo que lo convierte en un agente de juegos en vez de un escritor de scripts, porque es lo único que le deja **ejecutar y observar**.
3. **`luau-lsp` y los digests de Verse** le dan verdad sobre el código y sobre la API, a coste negativo de tokens.
4. **Dos hooks** —uno tras cada escritura, otro al cerrar el turno— transforman "creo que está hecho" en evidencia comprobada por una máquina.
5. **`docs/decisiones/` en el repositorio** es la memoria que sobrevive meses, y gana a cualquier sistema de memoria vectorial porque tú también la lees.
6. **Todo lo demás es opcional**, y varias de las herramientas más recomendadas de este dominio llevan entre uno y seis años sin un commit.

**Lo que no instalarás y por qué importa:** ni un framework multi-agente (Claude Code ya orquesta), ni una base de datos de grafos (el grafo está en el código y lo lee mejor un servidor de lenguaje), ni un agente de investigación (la documentación cabe en un `git clone`), ni un framework de tests de Luau (todos están muertos; escribe cincuenta líneas), ni ast-grep (no habla Luau).

**Cómo medir que funciona:** una tarea patrón, tres números —tokens de arranque, coste por tarea, iteraciones hasta verde— antes y después de cada instalación.

**Cómo hacerlo reversible:** `~/.claude/` en git desde el minuto cero; una herramienta por fase; y la disciplina de quitar lo que no demuestre su beneficio.

**Y cómo llegar progresivamente a un agente que construya juegos:** subiendo los cinco niveles de la Parte 18 en orden, sin saltarte el 3. El nivel 3 —probar, observar, corregir sin ayuda— es la frontera real. Todo lo que hay antes es autocompletado sofisticado. Todo lo que hay después es acumulación de horas de vuelo sobre ese ciclo.

---

## Qué he verificado y qué no

**Verificado en fuente primaria por mí:** el listado completo de herramientas del Studio MCP de Roblox, su forma de activación y su advertencia de seguridad (leído en crudo del repositorio `Roblox/creator-docs`) · toda la tabla de actividad de repositorios, mediante clonado de metadatos · el soporte explícito de Luau en Serena y su ausencia en ast-grep, leídos de sus propias fuentes · la existencia del LSP nativo de Claude Code vía plugins.

**Fuente secundaria, no verificada por mí directamente:** todo lo relativo a UEFN. `dev.epicgames.com` está bloqueado por el proxy de egreso de esta sesión y además devuelve 403 a rastreadores. El lanzamiento de Unreal MCP en UEFN, sus capacidades, la ruta de los digests y el estado del Python de editor proceden de las notas de la versión 42.00, el anuncio de Epic y su foro oficial, leídos a través de buscadores. **Antes de la Fase 6 de UEFN, ábrelas tú.**

**Opinión razonada, no hecho:** el reparto en niveles, el orden de las fases y la decisión de aplazar Serena y basic-memory. Se apoyan en las mediciones, pero son un juicio.

**No se ha instalado, ejecutado ni modificado nada en tu entorno.**
