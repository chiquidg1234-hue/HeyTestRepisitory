# GitHub Intelligence Research — Informe de investigación independiente

**Objetivo:** descubrir, verificar y clasificar repositorios públicos de GitHub que puedan mejorar de forma real un entorno de Claude / Claude Code.
**Fecha de la medición:** 25 de agosto de 2026.
**Estado:** investigación cerrada. **No se ha instalado ni modificado nada.** Pendiente de tu autorización.

---

## 0. Metodología y cómo leer este informe

Para no depender de estrellas ni de listas de blogs, cada repositorio candidato se midió con **evidencia primaria reproducible**:

| Señal | Cómo se obtuvo | Qué prueba |
|---|---|---|
| Fecha del último commit, commits en 30/90/365 días | `git clone --depth 100 --filter=blob:none` + `git log` sobre el repo real | Mantenimiento real, no percibido |
| Nº de autores distintos | `git log --format='%ae' \| sort -u` | Bus factor / concentración |
| Existencia de LICENSE, `SECURITY.md`, workflows CI, ficheros de test | `git ls-tree -r HEAD` | Higiene de ingeniería |
| Licencia exacta | descarga directa del fichero `LICENSE` | Restricciones legales reales |
| Estrellas, forks, issues abiertos, contributors | página del repositorio | Adopción (señal secundaria) |
| Renombrados / repos vaciados | comparación entre URL solicitada y URL final | Proyectos "zombi" o migrados |

**Límite conocido del método:** los clones son de profundidad 100, así que cuando ves `≥100 commits` significa "al menos 100" (el contador tocó techo). Las cifras de 30 y 90 días son exactas salvo en repos que superan 100 commits en ese periodo, donde también son cotas inferiores.

**Cuatro reglas que he aplicado y que explican decisiones que pueden sorprenderte:**

1. **Las estrellas no puntúan por sí solas.** Hay repos aquí con 240.000 estrellas en la lista de "no recomendados" y repos con 1.100 estrellas en el núcleo recomendado.
2. **Un repositorio parado no es un repositorio estable, salvo que sea trivial.** Una lista de 3 ficheros puede sobrevivir sin commits; un escáner de seguridad o un parser de PDF, no.
3. **Lo que Claude Code ya trae de serie descalifica al equivalente externo.** En 2026 Claude Code incorpora sandbox de Bash a nivel de SO, skills con carga progresiva, marketplace de plugins con allowlist/blocklist, auto-memoria por repositorio, telemetría OpenTelemetry nativa y hooks. Muchas herramientas de 2025 sobran hoy.
4. **Todo lo que ejecuta código o lee ficheros pasa antes por la sección de seguridad.** Una skill *es* código ejecutable. Un servidor MCP *es* un canal de inyección de prompt.

Cuando no he podido verificar algo, lo digo explícitamente con la etiqueta **[no verificado]**.

---

## 1. RESUMEN EJECUTIVO — Los 10 descubrimientos más importantes

### 1. El mejor "repositorio meta" no es una awesome-list: es `anthropics/claude-plugins-official`

El marketplace oficial de plugins de Claude Code vive en un repositorio público, con **105 commits en los últimos 30 días** y 456 ficheros. La documentación oficial de MCP lo referencia directamente (`/plugin install mcp-server-dev@claude-plugins-official`). Descubrir desde aquí tiene una propiedad que ninguna awesome-list ofrece: **el código lo mantiene el mismo equipo que mantiene el runtime**, y el marketplace soporta allowlists/blocklists por owner (`"owner/*"`) para control organizativo.

Casi todo el ecosistema de "listas curadas" que domina las búsquedas de Google es, comparado con esto, ruido con SEO.

### 2. El 26,1 % de las skills públicas contienen al menos una vulnerabilidad

Es el hallazgo más importante de todo el informe y cambia la forma de instalar cosas. Un estudio empírico de enero de 2026 recopiló **42.447 skills** de dos marketplaces y analizó 31.132 con un detector validado (86,7 % precisión / 82,5 % recall):

- **26,1 %** tienen ≥1 vulnerabilidad, en 14 patrones distintos
- **13,3 %** exfiltración de datos, **11,8 %** escalada de privilegios
- **5,2 %** presentan patrones de alta severidad "que sugieren fuertemente intención maliciosa"
- Las skills **que empaquetan scripts ejecutables tienen 2,12× más probabilidad** de ser vulnerables que las que solo llevan instrucciones (OR=2,12, p<0,001)

Fuente: [*Agent Skills in the Wild*, arXiv:2601.10338](https://arxiv.org/abs/2601.10338).

Consecuencia práctica: **instalar una colección de 183 skills de un desconocido no es "probar una herramienta", es ejecutar código de 183 procedencias distintas.**

### 3. El repositorio de Claude Code más famoso del mundo tiene un clon con malware en circulación

`affaan-m/ECC` (antes `everything-claude-code`) tiene **241.210 estrellas**. Una auditoría independiente de junio de 2026 clonó el original más 19 re-subidas públicas y las diffeó contra upstream. Conclusión doble:

- El **original no es malware**, pero "instala una superficie grande, globalmente activa y de auto-ejecución que la mayoría de la gente que pulsa install nunca ha evaluado".
- Una de las re-subidas (`arabicapp/everything-claude-code`) **sí es un dropper de malware**: README falso de "Visit Here to Download", ZIP con `Launch.bat` → `luajit.exe x64.txt` y un payload Lua ofuscado de 307 KB, más un segundo archivo escondido bajo `docs/zh-TW/skills/postgres-patterns/`. Reportado a GitHub.

Fuente: [auditoría en DEV, jun-2026](https://dev.to/joergmichno/we-audited-the-viral-213k-star-everything-claude-code-repo-and-found-a-malware-clone-in-the-wild-14hb).

La lección no es "ECC es malo". Es que **la popularidad extrema genera automáticamente clones envenenados**, y que copiar el comando de instalación de un vídeo o un tuit es el vector.

### 4. `ruvnet/claude-flow` (ahora `ruvnet/ruflo`) es el caso más claro de repositorio viral sin sustancia técnica

66.205 estrellas, 118 commits en 30 días, y **6.806 de las contribuciones son de una sola persona**. Una auditoría técnica independiente de abril de 2026 probó sus 300+ herramientas MCP a mano y documentó:

- `agent_spawn` crea una entrada en un `Map` de JavaScript. Sin subproceso, sin llamada al LLM. Los agentes quedan `idle` con `taskCount: 0` para siempre.
- El "consenso bizantino" son eventos de un `EventEmitter` **dentro de un único proceso Node**. No hay red.
- El "hive-mind" es literalmente `child_process.spawn('claude', ['--dangerously-skip-permissions', '<prompt largo>'])`.
- El "agente WASM" devuelve `echo: <tu input>`.
- El "entrenamiento neuronal" ignora los datos y devuelve `Math.random()` como precisión.
- Conclusión del auditor: **~10 de 300+ herramientas son reales**, y el overhead añade 15.000-25.000 tokens de ruido por sesión.

Fuente: [auditoría técnica, abr-2026](https://gist.github.com/roman-rr/ed603b676af019b8740423d2bb8e4bf6). No he re-ejecutado la auditoría; la clasifico como **evidencia independiente fuerte, no replicada por mí**.

Que use `--dangerously-skip-permissions` internamente es, por sí solo, motivo suficiente para no instalarlo.

### 5. La guerra de benchmarks de memoria de agentes invalida las cifras de ambos bandos

Mem0 y Zep llevan desde 2025 corrigiéndose mutuamente sobre LoCoMo:

- Zep publicó 84 %. Mem0 [demostró](https://github.com/getzep/zep-papers/issues/5) que el cálculo incluía la categoría adversarial que el protocolo excluye → **58,44 %** corregido.
- Zep [rectificó públicamente](https://blog.getzep.com/lies-damn-lies-statistics-is-mem0-really-sota-in-agent-memory/) ("Correction: erramos en cómo calculamos el score de Zep") y publicó **75,14 % ±0,17**, alegando que Mem0 había configurado mal Zep.
- Un análisis independiente encontró que **el 6,4 % de las respuestas correctas del propio benchmark están mal**, que el juez LLM acepta el **63 %** de respuestas intencionadamente incorrectas, y que el **56 %** de las comparaciones por categoría son estadísticamente indistinguibles del ruido.

**Traducción: no elijas sistema de memoria por benchmark. Elígelo por arquitectura, licencia y coste operativo.** Esa es la base de mis recomendaciones en la categoría C.

### 6. Letta (MemGPT) ya no es lo que la mayoría de listas dice que es

`letta-ai/letta` tiene hoy **12 ficheros**: es una landing page. El README lo declara: *"This repository now serves as a landing page. The retired Letta V1 server source is preserved on the `archive` branch"*. El desarrollo real está en `letta-ai/letta-code` (3.111 estrellas, ≥100 commits/30d), que **ya no es un servidor de memoria: es un harness de agente de codificación** que compite con Claude Code, no que lo complementa.

Cualquier lista que en 2026 te recomiende "Letta para dar memoria a Claude" está desactualizada.

### 7. Arize Phoenix no es software libre, y casi ningún artículo comparativo lo menciona

`Arize-ai/phoenix` se licencia bajo **Elastic License 2.0**, no una licencia OSI. Langfuse mantiene núcleo MIT con carpetas `ee/` restringidas, y desde enero de 2026 [pertenece a ClickHouse, Inc.](https://clickhouse.com/blog/clickhouse-acquires-langfuse-open-source-llm-observability) (sin cambio de licencia anunciado). El único de los tres grandes con **Apache-2.0 limpio en todo el repositorio es `comet-ml/opik`**.

Si el criterio es "self-host sin sorpresas legales", el ranking de observabilidad cambia de orden.

### 8. Hay un cementerio enorme de herramientas de seguridad para IA

Herramientas que aparecen constantemente recomendadas y que están **muertas**, medido hoy:

| Repo | Días sin commits | Veredicto |
|---|---|---|
| `protectai/rebuff` | **942** | Abandonado |
| `protectai/vulnhuntr` | **564** | Abandonado |
| `riseandignite/mcp-shield` | **486** | Abandonado |
| `slowmist/MCP-Security-Checklist` | **484** | Abandonado |
| `lasso-security/mcp-gateway` | **215** | Abandonado |
| `protectai/llm-guard` | 47 días, **1 commit en 90 días** | Agonizando |

Recomendar defensa contra prompt injection con una librería sin mantenimiento es peor que no recomendar nada: da falsa confianza en un área donde los ataques evolucionan cada mes.

### 9. Existe un ataque de skills que evade el 100 % de los escáneres actuales

*Semantic Compliance Hijacking* (SCH): en lugar de incluir un payload, la skill escribe **reglas de cumplimiento en lenguaje natural** que llevan al agente a generar y ejecutar el código malicioso por sí mismo. Sin AST reconocible, sin intención explícita.

Resultados: hasta **77,67 % de éxito en fuga de confidencialidad** y **67,33 % en RCE** en las configuraciones más vulnerables, con **0,00 % de detección** por las herramientas de escaneo actuales. Fuente: [arXiv:2605.14460](https://arxiv.org/abs/2605.14460).

Esto significa que `snyk/agent-scan` (que sí recomiendo) es **necesario pero no suficiente**. El control que sí funciona contra SCH es el sandbox a nivel de sistema operativo, porque limita lo que el código generado *puede hacer*, no lo que *parece*.

### 10. El mejor hallazgo "oculto" del informe: `UKGovernmentBEIS/inspect_ai`

2.601 estrellas — ridículas para lo que es — pero **580 commits en 30 días, 1.430 en el año, 104 autores distintos, 780 ficheros de test, MIT**. Es el framework de evaluación del AI Safety Institute británico. Ratio calidad/fama probablemente el más alto de todo lo que he revisado.

Menciones honoríficas del mismo tipo: `safedep/vet` (1.096 ★, detección de paquetes maliciosos, Apache-2.0, activo), `54yyyu/zotero-mcp` (177 commits/30d, 163 ficheros de test, gestión de citas por MCP) y `LearningCircuit/local-deep-research` (66 workflows de CI y 2.132 ficheros de test con muy poca visibilidad).

---

## 2. LOS MEJORES REPOSITORIOS META (para descubrir otros proyectos)

Evaluados por una pregunta: **¿me ayudan a encontrar cosas buenas, o solo acumulan enlaces?**

### Nivel 1 — Fuentes con autoridad real

| Repo | Estado medido | Por qué es la mejor puerta de entrada |
|---|---|---|
| [`anthropics/claude-plugins-official`](https://github.com/anthropics/claude-plugins-official) | ≥105 commits/30d · 456 ficheros · 6 autores | Marketplace oficial. Lo mantiene quien mantiene el runtime. Soporta allowlist/blocklist por owner. **Empieza siempre aquí.** |
| [`agentskills/agentskills`](https://github.com/agentskills/agentskills) | 24.654 ★ · Apache-2.0 · creado 16-dic-2025 | La **especificación** del estándar Agent Skills, originado en Anthropic y ahora multi-proveedor (Cursor lo implementa). Leer la spec vale más que leer 50 listas. |
| [`modelcontextprotocol/registry`](https://github.com/modelcontextprotocol/registry) | 30 commits/30d · 65/90d · SECURITY.md · 10 workflows | Registro oficial de MCP. Es la única fuente con identidad de publicador verificable. |
| [`modelcontextprotocol/servers`](https://github.com/modelcontextprotocol/servers) | 21 commits/30d · **684 autores distintos** · SECURITY.md | Servidores de referencia oficiales. Úsalo como *implementación canónica*, no como catálogo. |
| [`modelcontextprotocol/modelcontextprotocol`](https://github.com/modelcontextprotocol/modelcontextprotocol) | 187 commits/30d · 2.335/año · 245 autores | La especificación del protocolo. Aquí es donde se debaten las decisiones de seguridad antes de existir. |
| [`anthropics/claude-cookbooks`](https://github.com/anthropics/claude-cookbooks) | 17 commits/30d · 367/año · 87 autores | Patrones oficiales verificables. Menos "framework", más "así se hace bien". |

### Nivel 2 — Listas con curación o ranking automático

| Repo | Estado medido | Juicio |
|---|---|---|
| [`tolkonepiu/best-of-mcp-servers`](https://github.com/tolkonepiu/best-of-mcp-servers) | 10 commits/30d · 154/año · 400 proyectos | **El mejor descubridor no oficial.** Ranking por *project-quality score* calculado automáticamente de métricas de GitHub y gestores de paquetes, actualizado semanalmente. Es exactamente el patrón "repositorio que se actualiza solo" que pedías. |
| [`hesreallyhim/awesome-claude-code`](https://github.com/hesreallyhim/awesome-claude-code) | 52.913 ★ · ≥100 commits/30d · **922 issues abiertos** | Curación manual real y automatización de validación de enlaces. **Pega importante: licencia CC BY-NC-ND 4.0** — no comercial y sin obras derivadas. Consúltala, no la reutilices en material de empresa. |
| [`e2b-dev/awesome-ai-agents`](https://github.com/e2b-dev/awesome-ai-agents) | 3 commits/30d · **solo 5 en 365 días** | Buena estructura, mantenimiento mínimo. Útil como mapa histórico, no como fuente actual. |
| [`DavidZWZ/Awesome-Deep-Research`](https://github.com/DavidZWZ/Awesome-Deep-Research) | 18 commits/90d · vinculado a ACL 2026 | Nicho pero honesto: papers + implementaciones de deep research. |
| [`Shubhamsaboo/awesome-llm-apps`](https://github.com/Shubhamsaboo/awesome-llm-apps) | 47 commits/30d · 415/año · 62 autores | Muy activo, pero es un repositorio de *demos*, no de herramientas de producción. Útil para aprender patrones. |

### Nivel 3 — Listas enormes sin curación (usar con pinzas)

| Repo | Evidencia | Problema |
|---|---|---|
| [`punkpeye/awesome-mcp-servers`](https://github.com/punkpeye/awesome-mcp-servers) | 6.843 commits/año · **2.892 autores distintos** en 9.009 commits | Es una manguera de pull requests de autopromoción. Estar en la lista no significa absolutamente nada sobre la calidad. Sirve para *saber que algo existe*, jamás como recomendación. |
| [`wong2/awesome-mcp-servers`](https://github.com/wong2/awesome-mcp-servers) | 43 días sin commits · 66 autores | Mismo patrón, menor volumen. |
| [`appcypher/awesome-mcp-servers`](https://github.com/appcypher/awesome-mcp-servers) | **111 días sin commits** · sin fichero LICENSE | Obsoleta. |

### Nivel 4 — Metarrepos muertos que siguen circulando

| Repo | Días sin commits | Nota |
|---|---|---|
| `WooooDyy/LLM-Agent-Paper-List` | **347** | Fue la referencia de papers de agentes. Hoy está congelada. |
| `Puliczek/awesome-mcp-security` | **174** | Sin licencia, 2 ficheros. |
| `slowmist/MCP-Security-Checklist` | **484** | Se sigue citando en artículos de 2026. Está muerto. |
| `ml-tooling/best-of-generator` | **359** | El generador del patrón "best-of" está parado; los forks activos (como best-of-mcp-servers) siguen funcionando. |

**Conclusión de la sección:** de ~15 repositorios "meta" evaluados, solo **6 fuentes oficiales + 2 listas (best-of-mcp-servers y awesome-claude-code)** aportan valor real de descubrimiento. El resto es volumen.

---

## 3. TOP REPOSITORIOS POR CATEGORÍA

Notación: `★` estrellas · `30d/90d/365d` commits en ese periodo · `≥100` significa que el contador tocó el techo del clon.

### A. AI Agents (frameworks y runtimes)

| Repo | Métricas | Licencia | Veredicto |
|---|---|---|---|
| [`pydantic/pydantic-ai`](https://github.com/pydantic/pydantic-ai) | ≥100/30d · 1.707 test files · 65 workflows | MIT | **Mejor de la categoría para Python.** Tipado, testeable, disciplina de ingeniería visible en la relación test/código. |
| [`stanfordnlp/dspy`](https://github.com/stanfordnlp/dspy) | 65/30d · 136 test files | MIT | Optimización programática de prompts. Vale la pena aunque no lo adoptes: cambia cómo piensas los prompts. |
| [`BoundaryML/baml`](https://github.com/BoundaryML/baml) | ≥100/30d · 1.085 test files · 48 workflows | Apache-2.0 | Salidas estructuradas con lenguaje propio. Muy sólido técnicamente, coste de aprendizaje real. |
| [`langchain-ai/langgraph`](https://github.com/langchain-ai/langgraph) | 36/30d · 222 test files | MIT | Estándar de facto para grafos de estado. Ecosistema enorme, abstracciones pesadas. |
| [`agno-agi/agno`](https://github.com/agno-agi/agno) | 55/30d · 1.386 test files · 43 autores | MPL/otras | Alternativa ligera y sorprendentemente bien testeada. |
| [`crewAIInc/crewAI`](https://github.com/crewAIInc/crewAI) | ≥100/30d · 27.142 ficheros | MIT | Muy popular, muy pesado. Su modelo de "roles" produce demos bonitas y sistemas difíciles de depurar. |
| `microsoft/autogen` | **140 días sin commits** | MIT | ⚠️ En pausa larga. No lo elegiría para empezar algo hoy. |
| `humanlayer/12-factor-agents` | **338 días sin commits** | Apache-2.0 | Documento excelente y todavía válido conceptualmente, pero congelado. Léelo, no dependas de él. |

**Nota de encuadre:** para tu caso (mejorar Claude Code), **ninguno de estos es prioritario**. Claude Code ya *es* el runtime de agente. Estos frameworks son para construir agentes propios, no para mejorar el que usas.

### B. Claude / AI Coding Agents

| Repo | Métricas | Licencia | Veredicto |
|---|---|---|---|
| [`oraios/serena`](https://github.com/oraios/serena) | 28.465 ★ · 117/30d · 423/año · **704 test files** · 52 autores | MIT | **El mejor MCP para código que existe.** Recuperación y edición semántica a nivel de símbolo vía language servers. Su propio README avisa: *"No lo instales desde marketplaces de MCP o plugins — contienen comandos de instalación obsoletos"*. |
| [`github/spec-kit`](https://github.com/github/spec-kit) | 131.139 ★ · ≥100/30d · 25 workflows · 162 test files | MIT | Desarrollo dirigido por especificación. Mantenimiento de GitHub, no de un hobbyista. La metodología es sólida y es agnóstica de agente. |
| [`obra/superpowers`](https://github.com/obra/superpowers) | 277.365 ★ · ≥100/90d · 60 test files | MIT | Metodología brainstorm→plan→implement→verify empaquetada como skills. **Ver análisis crítico en §6.** Valioso, pero caro en tokens y con solapamiento creciente con las skills nativas. |
| [`wshobson/agents`](https://github.com/wshobson/agents) | 39.105 ★ · 29/30d · **solo 10 issues abiertos** | MIT | Colección de subagentes multi-harness. La cifra de issues abiertos frente a 39k estrellas indica mantenimiento real, no abandono. |
| [`ryoppippi/ccusage`](https://github.com/ryoppippi/ccusage) | 18.094 ★ · ≥100/30d · 29 issues | Otra | Analiza los JSONL locales de Claude Code para reportar uso y coste. **No hace red.** Riesgo prácticamente nulo, utilidad inmediata. |
| [`daaain/claude-code-log`](https://github.com/daaain/claude-code-log) | 9/30d · 102/90d · **359 test files** | MIT | Convierte transcripciones de Claude Code en HTML navegable. Nicho, muy bien construido. |
| [`davila7/claude-code-templates`](https://github.com/davila7/claude-code-templates) | 30.311 ★ · ≥100/30d · 9.228 ficheros · **24 test files** | MIT | Activo, pero la relación 9.228 ficheros / 24 tests indica volumen sobre verificación. |
| [`musistudio/claude-code-router`](https://github.com/musistudio/claude-code-router) | 154/30d · 463/año | MIT | Enruta Claude Code hacia otros modelos. Técnicamente vivo. **Implicación de privacidad seria: tus prompts y tu código salen hacia el proveedor que configures.** |
| `SuperClaude_Framework` / `NomenAK/SuperClaude` | **1 commit/30d, 2/90d** | MIT | Fue el framework de referencia en 2025. Hoy está prácticamente parado. |
| `eyaltoledano/claude-task-master` | **0 commits en 90 días** (124 días) | MIT | 422 commits el año pasado, cero en el último trimestre. Detenido. |
| `BloopAI/vibe-kanban` | **0 commits en 90 días** (123 días) | — | Detenido. |
| `getAsterisk/claudia` | **313 días** | — | Muerto. |
| `brennercruvinel/CCPlugins` | **322 días** | MIT | Muerto. |
| `carlrannaberg/claudekit` | **146 días** | MIT | Parado. |
| `disler/claude-code-hooks-mastery` | **204 días** · sin LICENSE | — | Parado y sin licencia. |
| `Pimzino/claude-code-spec-workflow` | **352 días** | MIT | Muerto (superado por spec-kit). |
| `ericbuess/claude-code-project-index` | **348 días** | MIT | Muerto. |
| `wshobson/commands` | **317 días** | MIT | Absorbido por `wshobson/agents`. |
| `steipete/agent-rules` | **120 días** | MIT | Parado. |

### C. Agent Memory

Recuerda el hallazgo #5: **los benchmarks de esta categoría no son fiables**. Juzgo por arquitectura, licencia y coste.

| Repo | Métricas | Licencia | Veredicto |
|---|---|---|---|
| [`topoteretes/cognee`](https://github.com/topoteretes/cognee) | 30.253 ★ · **667/30d · 2.047/90d · 5.995/año** · 53 workflows · 750 test files · 267 autores | Apache-2.0 | **El proyecto de memoria OSS más activo del ecosistema, con diferencia.** Grafo de conocimiento auto-alojable. Si vas a apostar por memoria en grafo, esta es la apuesta con menos riesgo de abandono. |
| [`getzep/graphiti`](https://github.com/getzep/graphiti) | 30.283 ★ · 39/30d · 72 test files | Apache-2.0 | **La mejor arquitectura conceptual: grafo temporal con ventanas de validez de hechos.** Modela "me mudé de Londres a Tokio" como cambio de estado, no como dos hechos simultáneos. Requiere Neo4j/FalkorDB. La plataforma Zep completa es SaaS. |
| [`mem0ai/mem0`](https://github.com/mem0ai/mem0) | 63.960 ★ · 93/30d · 291 test files · **681 issues abiertos** | Apache-2.0 | La integración más rápida y la comunidad más grande. Sus afirmaciones de SOTA están disputadas (§1.5). Varias fuentes secundarias indican que la capa de grafo completa es de pago **[no verificado por mí en el repo]**. |
| [`basicmachines-co/basic-memory`](https://github.com/basicmachines-co/basic-memory) | 3.705 ★ · ≥100/30d · 412 test files | **AGPL-3.0** | **Mi favorito para tu caso concreto.** Memoria como ficheros Markdown locales, legibles y editables por ti, expuestos por MCP. Sin base de datos vectorial, sin nube obligatoria. Ojo a dos cosas: **AGPL-3.0** (copyleft fuerte, relevante si construyes producto) y un upsell de nube muy presente en el README. |
| [`doobidoo/mcp-memory-service`](https://github.com/doobidoo/mcp-memory-service) | 1.902 ★ · 174/30d · 306 test files · **solo 13 issues abiertos** | Apache-2.0 | **Joya oculta.** Self-hosted completo con sqlite-vec, REST + MCP + OAuth, consolidación autónoma. La proporción issues/estrellas es la mejor de la categoría. |
| [`MemTensor/MemOS`](https://github.com/MemTensor/MemOS) | 84/30d · 1.324/año · 432 test files · 96 autores | Apache-2.0 | Origen académico con ingeniería seria. Menos maduro para uso diario. |
| `letta-ai/letta` | **repositorio vaciado: 12 ficheros** | Apache-2.0 | Es una landing page. El sucesor `letta-ai/letta-code` es un harness rival, no memoria para Claude. |
| `redis/agent-memory-server` | 2/30d · 34/90d | MIT | Correcto si ya usas Redis. Poco movimiento. |
| `BAI-LAB/MemoryOS` | 2 commits/90d | Apache-2.0 | Se está apagando. |
| `Mirix-AI/MIRIX` | 2/30d · 12/90d | Apache-2.0 | Desacelerando fuerte. |
| `agiresearch/A-mem` | **255 días** | MIT | Paper interesante, código abandonado. |
| `Olow304/memvid` | 42 días · **4 commits/90d** | MIT | Concepto viral (memoria codificada en vídeo). La actividad se ha desplomado. **Ver §6.** |

**Aviso importante sobre esta categoría entera:** Claude Code **ya tiene auto-memoria nativa** (notas que Claude escribe solo, por repositorio, compartidas entre worktrees, cargadas cada sesión hasta 200 líneas / 25 KB) además de `CLAUDE.md` y `.claude/rules/`. Para memoria *de proyecto de código*, lo nativo probablemente ya te basta. Un MCP de memoria aporta valor sobre todo para **conocimiento transversal entre proyectos y entre herramientas**.

### D. Knowledge / Research / RAG

| Repo | Métricas | Licencia | Veredicto |
|---|---|---|---|
| [`docling-project/docling`](https://github.com/docling-project/docling) | 65.525 ★ · ≥100/30d · **1.154 test files** · 39 autores | MIT | **El mejor conversor documento→IA que existe.** PDF, DOCX, PPTX, XLSX, HTML con estructura y tablas. Proyecto IBM. Sin discusión en su categoría. |
| [`HKUDS/LightRAG`](https://github.com/HKUDS/LightRAG) | 39.166 ★ · **723/30d · 1.352/90d** · 544 test files | MIT | GraphRAG ligero, origen académico (EMNLP 2025), ritmo de desarrollo extremo. Mejor relación coste/resultado que GraphRAG de Microsoft. |
| [`microsoft/graphrag`](https://github.com/microsoft/graphrag) | 35.664 ★ · 13/30d · 187 test files · **36 issues abiertos** | MIT | Maduro y estabilizado (no muerto). Indexación cara en tokens. Buena referencia conceptual. |
| [`assafelovic/gpt-researcher`](https://github.com/assafelovic/gpt-researcher) | 29/30d · 391/año · **178 autores** | Apache-2.0 | El agente de investigación autónoma con más adopción real y comunidad más amplia. |
| [`LearningCircuit/local-deep-research`](https://github.com/LearningCircuit/local-deep-research) | ≥100/30d · **66 workflows CI · 2.132 test files** | Apache-2.0 | **Joya oculta.** Nivel de verificación automática impropio de un proyecto de su visibilidad. |
| [`bytedance/deer-flow`](https://github.com/bytedance/deer-flow) | ≥100/30d · 787 test files · 48 autores | MIT | Multi-agente sobre LangGraph, respaldo corporativo. |
| [`54yyyu/zotero-mcp`](https://github.com/54yyyu/zotero-mcp) | **177/30d · 493/año** · 163 test files · 65 autores | MIT | **Joya oculta.** Gestión de citas y bibliografía Zotero por MCP. Si haces trabajo con fuentes, esto resuelve *source tracking* de verdad. |
| [`google/langextract`](https://github.com/google/langextract) | 2/30d · 80/año | Apache-2.0 | Extracción estructurada **con anclaje al texto fuente** (source grounding). Pequeño, de Google, exactamente lo que pide "fact checking + source tracking". |
| [`infiniflow/ragflow`](https://github.com/infiniflow/ragflow) | ≥100/30d · 600 test files | Apache-2.0 | Plataforma RAG completa. Excelente si quieres un producto; excesivo si quieres una librería. |
| `SciPhi-AI/R2R` | **291 días sin commits** | MIT | ⚠️ Se sigue recomendando en listas. Está parado. |
| `explodinggradients/ragas` | **182 días sin commits** | Apache-2.0 | ⚠️ Librería de evaluación RAG muy citada, sin commits en 6 meses. |
| `stanford-oval/storm` | **328 días** | MIT | Investigación excelente, repositorio congelado. |
| `nano-graphrag` / `fast-graphrag` | **210 / 296 días** | MIT | Muertos. |
| `cyclotruc/gitingest` | **374 días** | MIT | Muerto. Usa repomix. |
| `dzhng/deep-research` | **135 días** | MIT | Fue viral en 2025. Parado. |

### E. Security

Categoría con la peor relación entre reputación y realidad de todo el informe.

| Repo | Métricas | Licencia | Veredicto |
|---|---|---|---|
| [`snyk/agent-scan`](https://github.com/invariantlabs-ai/mcp-scan) (antes `invariantlabs-ai/mcp-scan`) | 2.929 ★ · 49/30d · 175/90d · **339 test files · 9 issues abiertos** | Apache-2.0 | **Lo más cercano a imprescindible en esta categoría.** Escanea servidores MCP, agentes **y skills** de tu máquina buscando inyecciones de prompt y vulnerabilidades. Invariant Labs fue adquirida por Snyk. **Dos avisos del propio README:** el formato de salida del CLI es experimental y **v0.5.x está marcada para deprecación**; no construyas automatismos que dependan de sus códigos de issue. Se instala con `uvx`, sin paquete npm. |
| [`anthropic-experimental/sandbox-runtime`](https://github.com/anthropic-experimental/sandbox-runtime) | 4.990 ★ · 52/30d · 475/año · 189 test files | Apache-2.0 | **El descubrimiento más útil de la categoría.** Es el motor de sandbox de Claude Code liberado como herramienta independiente (`srt`): `sandbox-exec` en macOS, `bubblewrap` en Linux, más filtrado de red por proxy. **Sirve para meter servidores MCP de terceros en una jaula.** Etiquetado por Anthropic como *beta research preview*: las APIs pueden cambiar. |
| [`promptfoo/promptfoo`](https://github.com/promptfoo/promptfoo) | 24.538 ★ · ≥100/30d · **1.132 test files** | MIT | Evaluación + red teaming en un solo config declarativo, integrable en CI. Su propia descripción afirma que lo usan OpenAI y Anthropic **[afirmación del proyecto, no verificada por mí]**. |
| [`NVIDIA/garak`](https://github.com/NVIDIA/garak) | 9.006 ★ · 76/30d · **1.817/año** · 219 test files | Apache-2.0 | Escáner de vulnerabilidades de LLM con respaldo corporativo serio. |
| [`microsoft/PyRIT`](https://github.com/microsoft/PyRIT) | ≥100/30d · 626 test files · 30 autores | MIT | ⚠️ **Ojo: `Azure/PyRIT` está vacío y redirige.** El repo vivo es `microsoft/PyRIT`. Muchas listas apuntan al muerto. |
| [`trufflesecurity/trufflehog`](https://github.com/trufflesecurity/trufflehog) | 27.573 ★ · 48/30d | **AGPL-3.0** | Detección de secretos **con verificación** (comprueba si la credencial filtrada sigue viva). La licencia AGPL importa si lo integras en producto. |
| [`gitleaks/gitleaks`](https://github.com/gitleaks/gitleaks) | 28.925 ★ · 0/30d · 19/90d | MIT | Más simple y con licencia más permisiva que TruffleHog. Ritmo lento pero no muerto. |
| [`semgrep/semgrep`](https://github.com/semgrep/semgrep) | 16.304 ★ · 36/30d · **8.260 test files** | LGPL-2.1 | SAST multilenguaje con reglas legibles. Base sólida para hooks de pre-commit. |
| [`google/osv-scanner`](https://github.com/google/osv-scanner) | 10.914 ★ · 42/30d | Apache-2.0 | Vulnerabilidades de dependencias contra osv.dev. Cero fricción. |
| [`safedep/vet`](https://github.com/safedep/vet) | 1.096 ★ · 32/30d · 231/año | Apache-2.0 | **Joya oculta.** No busca CVEs: busca **paquetes maliciosos** — el vector real cuando un agente instala dependencias por ti. Policy-as-code. |
| [`aquasecurity/trivy`](https://github.com/aquasecurity/trivy) | 43/30d | Apache-2.0 | Todoterreno (contenedores, IaC, SBOM). |
| [`superradcompany/microsandbox`](https://github.com/microsandbox/microsandbox) | 7.534 ★ · 169/30d · 294/año | Apache-2.0 | microVMs locales. Aislamiento más fuerte que `srt`, coste operativo mayor. |
| [`OWASP/...top-10-for-llm-applications`](https://github.com/OWASP/www-project-top-10-for-large-language-model-applications) | 2/30d · 96/año · 41 autores | — | Marco de referencia, no herramienta. Vale para estructurar tu propio criterio. |
| `dagger/container-use` | 7/30d · **8/90d** · 0 test files | Apache-2.0 | Desacelerando y sin tests. Vigilar. |
| `anthropics/claude-code-security-review` | **194 días** | MIT | Superado por `/security-review` nativo y por Claude Code Security. |
| `protectai/llm-guard` | **1 commit en 90 días** | MIT | ⛔ Agonizando. |
| `protectai/rebuff` | **942 días** | Apache-2.0 | ⛔ Abandonado. |
| `protectai/vulnhuntr` | **564 días** | AGPL | ⛔ Abandonado. |
| `riseandignite/mcp-shield` | **486 días** | MIT | ⛔ Abandonado. |
| `lasso-security/mcp-gateway` | **215 días** | Apache-2.0 | ⛔ Abandonado. |
| `slowmist/MCP-Security-Checklist` | **484 días** | — | ⛔ Abandonado pero muy citado. |

### F. AI Fluency / Agent Fluency

Aquí GitHub aporta poco: lo valioso es marco conceptual, no código.

- **Marco 4D de Anthropic** (Delegation, Description, Discernment, Diligence): desarrollado con los profesores Rick Dakan (Ringling College) y Joseph Feller (University College Cork). Curso oficial gratuito en [Claude Academy](https://academy.claude.com/courses/ai-fluency-framework-foundations) y [Coursera](https://www.coursera.org/learn/ai-fluency-framework-foundations). Materiales abiertos en [aifluencyframework.org](https://aifluencyframework.org/).
- [`anthropics/courses`](https://github.com/anthropics/courses) — **284 días sin commits**. Contenido válido, repositorio congelado. Usa las plataformas de curso, no el repo.
- [`agentskills/agentskills`](https://github.com/agentskills/agentskills) — la spec es la mejor lectura práctica sobre cómo estructurar conocimiento reutilizable.
- [`obra/superpowers`](https://github.com/obra/superpowers) — **léelo como currículo aunque no lo instales.** Las skills describen una metodología de ingeniería (brainstorm → plan → implementar → verificar) que es correcta con independencia de si pagas los tokens del harness.
- `humanlayer/12-factor-agents` — **338 días sin commits**, pero sigue siendo el mejor texto corto sobre por qué los agentes fallan en producción.
- `davidkimai/Context-Engineering` (**179 días**) y `coleam00/context-engineering-intro` (**162 días**) — muy citados en redes, ambos parados. Contenido educativo, no infraestructura.

### G. Installation / Developer Productivity

| Repo | Métricas | Licencia | Veredicto |
|---|---|---|---|
| [`astral-sh/uv`](https://github.com/astral-sh/uv) | 89.041 ★ · ≥100/30d · 592 test files · 42 workflows | Apache-2.0/MIT | **Imprescindible si tocas Python.** Además es el instalador recomendado por varias herramientas de este informe (`uvx snyk-agent-scan`). Entornos reproducibles y efímeros = menos superficie. |
| [`jdx/mise`](https://github.com/jdx/mise) | ≥100/30d · 23 workflows | MIT | Gestor de versiones de runtimes + tareas + entorno, en una sola herramienta. Reemplaza asdf/nvm/pyenv/direnv. |
| [`cachix/devenv`](https://github.com/cachix/devenv) | **237/30d** · 460 test files | Apache-2.0 | Reproducibilidad total vía Nix. Curva de aprendizaje real. |
| [`twpayne/chezmoi`](https://github.com/twpayne/chezmoi) | 51/30d · ≥100/90d | MIT | Gestión de dotfiles con secretos. Aquí es donde debe vivir tu configuración de `~/.claude/`. |
| [`casey/just`](https://github.com/casey/just) | 6/30d · ≥100/90d · 116 test files | CC0 | Runner de comandos. Darle a Claude un `justfile` es más seguro y más barato que dejarle improvisar comandos. |
| [`simonw/llm`](https://github.com/simonw/llm) | **147/30d** · 179/año | Apache-2.0 | CLI de LLMs con plugins y log en SQLite. Complemento perfecto para tareas one-shot fuera de Claude Code. |
| [`pre-commit/pre-commit`](https://github.com/pre-commit/pre-commit) | 5/30d · 90/año | MIT | La forma correcta de imponer gitleaks/semgrep/ruff **antes** de que el agente haga commit. |
| [`astral-sh/ruff`](https://github.com/astral-sh/ruff) · [`biomejs/biome`](https://github.com/biomejs/biome) | ambos ≥100/30d | MIT | Linters rápidos. Feedback inmediato al agente = menos iteraciones. |
| `BurntSushi/ripgrep` · `sharkdp/fd` · `junegunn/fzf` · `jqlang/jq` | todos activos | MIT/Apache | Base. `ripgrep` ya lo usa Claude Code internamente. |
| `direnv/direnv` | **146 días** | MIT | Estable/maduro, pero `mise` cubre lo mismo con más movimiento. |

### H. Observability & Evaluation

| Repo | Métricas | Licencia | Veredicto |
|---|---|---|---|
| **OTEL nativo de Claude Code** | — | — | **Empieza por aquí.** Claude Code emite spans por petición de modelo y por ejecución de herramienta, métricas de tokens/coste y eventos estructurados por OTLP. Atributos `message.uuid`, `client_request_id`, `tool_source`. No necesitas ningún repo para tener trazas. |
| [`comet-ml/opik`](https://github.com/comet-ml/opik) | 21.577 ★ · ≥100/30d · **1.591 test files** · 82 workflows | **Apache-2.0** | **Mi recomendación para self-host.** Único de los tres grandes con licencia permisiva en todo el repositorio. |
| [`langfuse/langfuse`](https://github.com/langfuse/langfuse) | 33.563 ★ · ≥100/30d · 476 test files | MIT + `ee/` restringido | El más adoptado y con mejores integraciones (incluida Claude Agent SDK). Propiedad de ClickHouse, Inc. desde enero de 2026; sin cambio de licencia anunciado. |
| [`Arize-ai/phoenix`](https://github.com/Arize-ai/phoenix) | 11.151 ★ · ≥100/30d · 1.004 test files | **Elastic License 2.0** | Técnicamente excelente. **No es software libre OSI.** Casi ningún comparativo lo dice. |
| [`UKGovernmentBEIS/inspect_ai`](https://github.com/UKGovernmentBEIS/inspect_ai) | 2.601 ★ · **580/30d · 1.430/año · 104 autores** · 780 test files | MIT | **La joya del informe.** Framework de evaluación del AI Safety Institute británico. Si quieres medir de verdad, no medir bonito. |
| [`promptfoo/promptfoo`](https://github.com/promptfoo/promptfoo) | ver §E | MIT | Doble uso: evals de regresión + red teaming, con integración CI/CD. |
| [`confident-ai/deepeval`](https://github.com/confident-ai/deepeval) | **237/30d · 1.615/año** · 775 test files | Apache-2.0 | Evaluación tipo pytest. Muy activo. |
| [`open-telemetry/semantic-conventions`](https://github.com/open-telemetry/semantic-conventions) | 48/30d | Apache-2.0 | Convenciones GenAI. Léelas antes de inventarte nombres de atributos. |
| [`mlflow/mlflow`](https://github.com/mlflow/mlflow) | ≥100/30d · 89 workflows | Apache-2.0 | Opción si ya tienes MLflow. |
| `traceloop/openllmetry` | 4/30d · 20/90d | Apache-2.0 | Desacelerando. |
| `Helicone/helicone` | **2 commits/90d** | — | ⚠️ Parándose. |
| `AgentOps-AI/agentops` | **1 commit/90d** | MIT | ⚠️ Parándose. |
| `laude-institute/terminal-bench` | **1 commit/90d** | Apache-2.0 | ⚠️ Benchmark relevante para agentes de terminal, con poco movimiento reciente. |
| `explodinggradients/ragas` | **182 días** | Apache-2.0 | ⚠️ Ver §D. |

### I. Context Engineering

| Repo | Métricas | Licencia | Veredicto |
|---|---|---|---|
| [`yamadashy/repomix`](https://github.com/yamadashy/repomix) | 28.028 ★ · 116/30d · 509/año · 188 test files | MIT | **El mejor empaquetador de repo→contexto.** Punto clave de seguridad: su modo MCP tiene flag `--sandbox` que confina las herramientas de fichero a un directorio, rechaza rutas absolutas y desactiva empaquetado remoto. Es de las pocas herramientas del ecosistema con seguridad pensada por diseño. |
| [`oraios/serena`](https://github.com/oraios/serena) | ver §B | MIT | Context engineering real: en vez de comprimir 400 líneas, lee solo el símbolo que importa. |
| [`ast-grep/ast-grep`](https://github.com/ast-grep/ast-grep) | 49/30d · ≥100/90d | MIT | Búsqueda y reescritura estructural por AST. Mucho más preciso que regex para que el agente localice patrones. |
| [`upstash/context7`](https://github.com/upstash/context7) | 61.191 ★ · 33/30d · **54 issues abiertos** | MIT | Documentación actualizada por librería y versión. **Importante: es un servicio alojado.** Tus consultas salen a los servidores de Context7 y se recomienda API key. Utilidad alta, privacidad a considerar. |
| [`stanfordnlp/dspy`](https://github.com/stanfordnlp/dspy) | 65/30d | MIT | Optimización sistemática en lugar de "prompt a ojo". |
| `zilliztech/claude-context` | 42 días · **0 test files** | MIT | Menos maduro que las alternativas. |
| `mufeedvh/code2prompt` | 68 días sin commits | MIT | Válido, pero repomix está mucho más vivo. |
| `simonw/files-to-prompt` | **552 días** | Apache-2.0 | Herramienta minúscula y "terminada". Sigue funcionando. |
| `microsoft/LLMLingua` | **301 días** | MIT | ⚠️ Compresión de prompts muy citada, sin mantenimiento. |
| `davidkimai/Context-Engineering` | **179 días** | MIT | Material educativo parado. |

### J. Multimodal / Vídeo / Audio / Web

| Repo | Métricas | Licencia | Veredicto |
|---|---|---|---|
| [`docling-project/docling`](https://github.com/docling-project/docling) | ver §D | MIT | Documentos → Markdown estructurado. **El mejor de todos.** |
| [`ChromeDevTools/chrome-devtools-mcp`](https://github.com/ChromeDevTools/chrome-devtools-mcp) | 49.646 ★ · ≥100/30d · 103 test files · 22 autores | Apache-2.0 | **Mejor MCP de navegador.** Mantenido por el equipo de Chrome DevTools: trazas de rendimiento, red, consola, no solo clics. |
| [`microsoft/playwright-mcp`](https://github.com/microsoft/playwright-mcp) | 8/30d · 22/90d · SECURITY.md | Apache-2.0 | Sólido y oficial. Ritmo más lento que chrome-devtools-mcp. |
| [`browser-use/browser-use`](https://github.com/browser-use/browser-use) | 127/30d · **1.859/año** · 115 autores | MIT | Agente de navegador autónomo. Potente y **de alto riesgo**: ver matriz §9. |
| [`browserbase/stagehand`](https://github.com/browserbase/stagehand) | 62/30d · 208 test files | MIT | Enfoque híbrido código+lenguaje natural. Buen diseño. |
| [`ggml-org/whisper.cpp`](https://github.com/ggml-org/whisper.cpp) | ≥100/30d · 48 autores | MIT | Transcripción **100 % local**. Cero fuga de datos de audio. |
| [`opendatalab/MinerU`](https://github.com/opendatalab/MinerU) | 6/30d · 188/90d · 1.037/año | AGPL | PDF científicos complejos (fórmulas, tablas). Licencia restrictiva. |
| [`trycua/cua`](https://github.com/trycua/cua) | ≥100/30d · **102 workflows** · 407 test files | MIT | Computer-use en VMs aisladas. Ingeniería seria. |
| [`yt-dlp/yt-dlp`](https://github.com/yt-dlp/yt-dlp) | 37/30d | Unlicense | Ingesta de vídeo/audio web. |
| `datalab-to/marker` | 1/30d · 34/90d | licencia con restricciones comerciales **[no verificada en detalle]** | Buena calidad de conversión, revisa la licencia antes de uso comercial. |
| `microsoft/markitdown` | 3/30d · **37/año** | MIT | Desacelerando mucho. Docling lo supera. |
| `SYSTRAN/faster-whisper` | **279 días** | MIT | ⚠️ Muy usado, sin mantenimiento reciente. |
| `openai/whisper` | 2 commits/90d | MIT | Repo del modelo, congelado por diseño. Usa whisper.cpp. |
| `microsoft/OmniParser` | 2 commits/90d | MIT | Parándose. |
| `m-bain/whisperX` | 4 commits/90d | BSD | Parándose. |

---

## 4. TOP 25 GLOBAL

Sistema de puntuación solicitado: Impacto 20 · Calidad técnica 15 · Mantenimiento 10 · Seguridad 15 · Compatibilidad 10 · Evidencia/benchmarks 10 · Documentación 5 · Comunidad 5 · Integración 5 · Coste 5.

**Regla anti-hype aplicada:** ninguna puntuación alta compensa un problema grave de seguridad. Por eso `ruvnet/ruflo` (66k ★) y `affaan-m/ECC` (241k ★) no aparecen aquí, y sí aparece `safedep/vet` con 1.096 ★.

| # | Repositorio | Imp /20 | Téc /15 | Mnt /10 | Seg /15 | Cmp /10 | Evi /10 | Doc /5 | Com /5 | Int /5 | Cst /5 | **Total** |
|---|---|---|---|---|---|---|---|---|---|---|---|---|
| 1 | [anthropics/claude-plugins-official](https://github.com/anthropics/claude-plugins-official) | 19 | 13 | 10 | 14 | 10 | 8 | 5 | 4 | 5 | 5 | **93** |
| 2 | [oraios/serena](https://github.com/oraios/serena) | 19 | 14 | 10 | 11 | 10 | 8 | 5 | 4 | 5 | 5 | **91** |
| 3 | [docling-project/docling](https://github.com/docling-project/docling) | 17 | 14 | 10 | 13 | 9 | 8 | 5 | 5 | 4 | 4 | **89** |
| 4 | [yamadashy/repomix](https://github.com/yamadashy/repomix) | 15 | 14 | 10 | 13 | 10 | 7 | 5 | 4 | 5 | 5 | **88** |
| 5 | [snyk/agent-scan](https://github.com/invariantlabs-ai/mcp-scan) | 17 | 13 | 9 | 15 | 9 | 8 | 4 | 3 | 4 | 5 | **87** |
| 6 | [anthropic-experimental/sandbox-runtime](https://github.com/anthropic-experimental/sandbox-runtime) | 18 | 13 | 9 | 15 | 9 | 7 | 4 | 3 | 4 | 5 | **87** |
| 7 | [agentskills/agentskills](https://github.com/agentskills/agentskills) | 16 | 12 | 9 | 13 | 10 | 7 | 5 | 4 | 5 | 5 | **86** |
| 8 | [github/spec-kit](https://github.com/github/spec-kit) | 16 | 13 | 10 | 12 | 9 | 7 | 5 | 5 | 4 | 5 | **86** |
| 9 | [ChromeDevTools/chrome-devtools-mcp](https://github.com/ChromeDevTools/chrome-devtools-mcp) | 16 | 14 | 10 | 10 | 10 | 7 | 4 | 4 | 5 | 5 | **85** |
| 10 | [github/github-mcp-server](https://github.com/github/github-mcp-server) | 16 | 13 | 10 | 10 | 10 | 7 | 5 | 4 | 5 | 5 | **85** |
| 11 | [astral-sh/uv](https://github.com/astral-sh/uv) | 12 | 15 | 10 | 12 | 8 | 7 | 5 | 5 | 5 | 5 | **84** |
| 12 | [promptfoo/promptfoo](https://github.com/promptfoo/promptfoo) | 15 | 13 | 10 | 13 | 8 | 8 | 4 | 4 | 4 | 4 | **83** |
| 13 | [ryoppippi/ccusage](https://github.com/ryoppippi/ccusage) | 11 | 13 | 10 | 14 | 10 | 6 | 4 | 4 | 5 | 5 | **82** |
| 14 | [semgrep/semgrep](https://github.com/semgrep/semgrep) | 13 | 14 | 9 | 14 | 8 | 8 | 4 | 4 | 4 | 4 | **82** |
| 15 | [UKGovernmentBEIS/inspect_ai](https://github.com/UKGovernmentBEIS/inspect_ai) | 14 | 15 | 10 | 12 | 7 | 9 | 4 | 3 | 3 | 5 | **82** |
| 16 | [comet-ml/opik](https://github.com/comet-ml/opik) | 15 | 13 | 10 | 12 | 8 | 8 | 4 | 4 | 4 | 4 | **82** |
| 17 | [langfuse/langfuse](https://github.com/langfuse/langfuse) | 14 | 13 | 10 | 11 | 8 | 8 | 5 | 5 | 4 | 3 | **81** |
| 18 | [modelcontextprotocol/registry](https://github.com/modelcontextprotocol/registry) | 15 | 11 | 9 | 13 | 10 | 6 | 4 | 4 | 4 | 5 | **81** |
| 19 | [tolkonepiu/best-of-mcp-servers](https://github.com/tolkonepiu/best-of-mcp-servers) | 13 | 11 | 9 | 14 | 9 | 6 | 4 | 2 | 5 | 5 | **78** |
| 20 | [safedep/vet](https://github.com/safedep/vet) | 13 | 12 | 9 | 14 | 8 | 6 | 4 | 2 | 4 | 5 | **77** |
| 21 | [basicmachines-co/basic-memory](https://github.com/basicmachines-co/basic-memory) | 14 | 12 | 10 | 11 | 9 | 5 | 4 | 3 | 4 | 4 | **76** |
| 22 | [obra/superpowers](https://github.com/obra/superpowers) | 16 | 11 | 9 | 9 | 10 | 6 | 4 | 5 | 4 | 2 | **76** |
| 23 | [doobidoo/mcp-memory-service](https://github.com/doobidoo/mcp-memory-service) | 13 | 12 | 10 | 11 | 9 | 5 | 4 | 2 | 4 | 5 | **75** |
| 24 | [topoteretes/cognee](https://github.com/topoteretes/cognee) | 15 | 12 | 10 | 9 | 8 | 6 | 4 | 4 | 3 | 3 | **74** |
| 25 | [getzep/graphiti](https://github.com/getzep/graphiti) | 13 | 13 | 9 | 11 | 7 | 6 | 4 | 4 | 3 | 3 | **73** |

**A un punto del corte:** `gitleaks` (73), `HKUDS/LightRAG` (72), `ast-grep` (72), `whisper.cpp` (72), `pre-commit` (72), `google/osv-scanner` (74), `54yyyu/zotero-mcp` (71), `jdx/mise` (71), `LearningCircuit/local-deep-research` (70), `stanfordnlp/dspy` (70), `simonw/llm` (70).

**Por qué el nº1 no es una herramienta:** porque el mayor riesgo de tu entorno no es que le falte una capacidad, sino que instales la capacidad equivocada. Un marketplace oficial con allowlist por owner reduce más superficie de ataque de la que añade cualquier herramienta de seguridad.

---

## 5. LOS 10 QUE MÁS PODRÍAN MEJORAR TU CLAUDE

Fichas completas con el formato que pediste.

### 5.1 — oraios/serena

- **Nombre:** Serena
- **URL:** https://github.com/oraios/serena
- **Categoría:** Context engineering / navegación semántica de código (MCP)
- **Qué hace:** expone a Claude herramientas de un IDE reales (buscar símbolo, encontrar referencias, editar cuerpo de función) a través de language servers, para ~60 lenguajes.
- **Qué problema resuelve:** que el agente lea ficheros de 400 líneas para cambiar una función.
- **Cómo mejoraría Claude:** menos tokens gastados en lectura, ediciones más precisas, y capacidad real de trabajar en monorepos donde la búsqueda por texto se ahoga.
- **Compatibilidad:** MCP nativo. Diseñado explícitamente para Claude Code (contexto `ide-assistant`).
- **Madurez:** alta. 28.465 ★, creado marzo 2025, 423 commits en 12 meses.
- **Actividad reciente:** 117 commits/30d, 333/90d. Último commit hace 5 días.
- **Documentación:** buena y honesta — el README avisa de no instalarlo desde marketplaces por comandos obsoletos.
- **Licencia:** MIT.
- **Dependencias:** Python + los language servers de cada lenguaje que uses.
- **Seguridad:** lee y **escribe** en tu código fuente. No requiere red para funcionar. Riesgo principal: edición incorrecta, no exfiltración.
- **Privacidad:** local. El código no sale de tu máquina por culpa de Serena.
- **Permisos necesarios:** lectura/escritura del proyecto, ejecución de procesos (los language servers).
- **Riesgo de ejecución:** **medio** — arranca subprocesos de servidores de lenguaje.
- **Coste:** gratis; **ahorra** tokens.
- **Complejidad de instalación:** media (seguir el Quick Start oficial, no el marketplace).
- **Mantenimiento:** 52 autores distintos, 704 ficheros de test. Excelente.
- **Comunidad:** 1.914 forks, 140 issues abiertos sobre 28k ★ — proporción sana.
- **Benchmarks:** el proyecto publica una evaluación propia con ~20 tareas de codificación **[autoevaluación, no independiente]**.
- **Evidencia independiente:** consenso en reseñas de que aporta en repos grandes y sobra en proyectos pequeños.
- **Pros:** la mejora individual más grande para trabajo en bases de código medianas/grandes. Ahorra dinero.
- **Contras:** en proyectos de <2.000 líneas no compensa el coste de contexto de sus herramientas.

### 5.2 — anthropic-experimental/sandbox-runtime

- **URL:** https://github.com/anthropic-experimental/sandbox-runtime
- **Categoría:** Seguridad / aislamiento
- **Qué hace:** `srt` ejecuta cualquier proceso con restricciones de sistema de ficheros y de red a nivel de SO, sin contenedor.
- **Qué problema resuelve:** el problema que las herramientas anti-prompt-injection **no** pueden resolver (ver hallazgo #9): limitar lo que el código *puede hacer* en vez de intentar adivinar si es malicioso.
- **Cómo mejoraría Claude:** te permite ejecutar servidores MCP de terceros dentro de una jaula. Hoy, un MCP cualquiera corre con tus permisos completos.
- **Compatibilidad:** es literalmente el motor de sandbox de Claude Code, publicado aparte. macOS (`sandbox-exec`) y Linux (`bubblewrap`).
- **Madurez:** **beta research preview declarada por Anthropic.** APIs y formatos de configuración pueden cambiar.
- **Actividad reciente:** 52 commits/30d, 475/año, 22 autores, 189 ficheros de test.
- **Licencia:** Apache-2.0. **Documentación:** buena para ser preview.
- **Seguridad / permisos:** es la herramienta de permisos. Requiere `bubblewrap` en Linux.
- **Riesgo de ejecución:** **bajo** (reduce riesgo). El riesgo real es la falsa sensación de seguridad si lo configuras mal.
- **Coste:** gratis. **Complejidad:** media.
- **Pros:** procedencia inmejorable; resuelve el punto ciego estructural del ecosistema MCP.
- **Contras:** preview; sin soporte Windows nativo (requiere WSL2).

### 5.3 — snyk/agent-scan (antes invariantlabs-ai/mcp-scan)

- **URL:** https://github.com/invariantlabs-ai/mcp-scan → redirige a `snyk/agent-scan`
- **Categoría:** Seguridad / auditoría de componentes de agente
- **Qué hace:** descubre y escanea los agentes, servidores MCP **y skills** instalados en tu máquina buscando inyecciones de prompt y vulnerabilidades.
- **Qué problema resuelve:** el 26,1 % de skills vulnerables del hallazgo #2.
- **Cómo mejoraría Claude:** convierte "instalé 183 skills de un repo viral" en una decisión informada.
- **Compatibilidad:** total — lee las configuraciones locales de MCP/skills.
- **Madurez:** buena, con salvedad. **v0.5.x marcada para deprecación y salida de CLI declarada experimental por sus propios autores.**
- **Actividad:** 49 commits/30d, 175/90d, 339 ficheros de test, **solo 9 issues abiertos**.
- **Licencia:** Apache-2.0. **Instalación:** `uvx` o binario. No hay paquete npm oficial.
- **Seguridad/privacidad:** verifica antes de usarlo si la versión que instalas envía telemetría a Snyk. **[No verificado por mí.]**
- **Riesgo de ejecución:** **bajo-medio** (lee configuración; puede requerir red).
- **Pros:** el único escáner de este tipo vivo y con respaldo corporativo.
- **Contras:** **no detecta ataques payload-less tipo SCH (0,00 % de detección según arXiv:2605.14460).** Úsalo con sandbox, no en lugar del sandbox.

### 5.4 — anthropics/claude-plugins-official

- **URL:** https://github.com/anthropics/claude-plugins-official
- **Categoría:** Meta / distribución
- **Qué hace:** marketplace oficial de plugins de Claude Code (skills + agentes + hooks + MCP empaquetados).
- **Cómo mejoraría Claude:** te da capacidades nuevas con una cadena de suministro de riesgo drásticamente menor.
- **Compatibilidad:** nativa (`/plugin install <plugin>@claude-plugins-official`).
- **Actividad:** ≥105 commits/30d, 456 ficheros, 9 workflows de CI.
- **Licencia:** presente en el repo. **Riesgo de ejecución:** medio pero acotado — un plugin sigue siendo código, pero con procedencia verificable y soporte de allowlist/blocklist por owner (`"owner/*"`).
- **Pros:** el mejor ratio capacidad/riesgo del ecosistema.
- **Contras:** catálogo más pequeño que el ecosistema salvaje. Eso es una característica, no un defecto.

### 5.5 — yamadashy/repomix

- **URL:** https://github.com/yamadashy/repomix — **Categoría:** Context engineering
- **Qué hace:** empaqueta un repositorio (o partes) en un único fichero optimizado para LLM, con conteo de tokens y filtros.
- **Cómo mejoraría Claude:** control explícito de qué entra en contexto en revisiones globales, auditorías o migraciones.
- **Seguridad — el detalle que lo distingue:** en modo MCP acepta `--sandbox [dir]`, que confina las herramientas de fichero a un directorio, **rechaza rutas absolutas** y desactiva el empaquetado remoto y la generación de skills. Muy pocos MCP tienen esto.
- **Actividad:** 116/30d, 509/año, 188 ficheros de test, 19 workflows. **Licencia:** MIT.
- **Riesgo de ejecución:** **bajo** con `--sandbox`; medio sin él.
- **Contras:** solapa parcialmente con la lectura nativa de ficheros de Claude Code; su valor está en el empaquetado dirigido, no en el uso diario.

### 5.6 — docling-project/docling

- **URL:** https://github.com/docling-project/docling — **Categoría:** Multimodal / documentos
- **Qué hace:** convierte PDF, DOCX, PPTX, XLSX y HTML a Markdown/JSON **conservando estructura y tablas**.
- **Cómo mejoraría Claude:** hoy los PDF complejos son el punto ciego más común. Docling los convierte en algo que Claude entiende bien.
- **Actividad:** ≥100/30d, **1.154 ficheros de test**, 39 autores, 65.525 ★, MIT, proyecto IBM.
- **Seguridad:** procesa ficheros no confiables → parser como superficie de ataque. Ejecútalo sobre ficheros de origen dudoso dentro de `srt`.
- **Riesgo de ejecución:** bajo-medio. **Coste:** gratis, local (modelos opcionales de OCR).
- **Contras:** dependencias pesadas (modelos de visión) si activas OCR.

### 5.7 — ChromeDevTools/chrome-devtools-mcp

- **URL:** https://github.com/ChromeDevTools/chrome-devtools-mcp — **Categoría:** Multimodal / web
- **Qué hace:** da a Claude las DevTools de Chrome: red, consola, trazas de rendimiento, DOM, no solo clics.
- **Cómo mejoraría Claude:** depuración de front-end real ("¿por qué esta página tarda 4 s?") en vez de adivinar.
- **Actividad:** ≥100/30d, 103 test files, 22 autores, 49.646 ★, Apache-2.0, mantenido por el equipo de Chrome DevTools.
- **Seguridad — crítico:** cualquier MCP de navegador introduce **inyección de prompt desde el contenido web**. Una página puede contener instrucciones dirigidas a tu agente. Úsalo con perfil de navegador dedicado y sin sesiones autenticadas sensibles.
- **Riesgo de ejecución:** **alto** por diseño (contenido no confiable → contexto del agente).

### 5.8 — github/spec-kit

- **URL:** https://github.com/github/spec-kit — **Categoría:** Workflow / AI fluency aplicada
- **Qué hace:** flujo de trabajo dirigido por especificación: especificar → planificar → tareas → implementar.
- **Cómo mejoraría Claude:** ataca la causa número uno de resultados malos con agentes — empezar a codificar antes de haber definido el problema. Es la parte de la metodología de `superpowers` **sin el coste permanente de tokens**, porque lo invocas cuando lo necesitas.
- **Actividad:** ≥100/30d, 25 workflows, 162 test files, 131.139 ★, MIT, mantenido por GitHub.
- **Riesgo de ejecución:** bajo (plantillas y comandos). **Coste:** gratis.
- **Contras:** ceremonia excesiva para cambios pequeños.

### 5.9 — Un sistema de memoria: basic-memory **o** doobidoo/mcp-memory-service

No instales los dos. Comparación directa:

| | [basic-memory](https://github.com/basicmachines-co/basic-memory) | [mcp-memory-service](https://github.com/doobidoo/mcp-memory-service) |
|---|---|---|
| Modelo de datos | Markdown local + wikilinks | SQLite-vec + grafo causal |
| Licencia | **AGPL-3.0** (copyleft fuerte) | **Apache-2.0** |
| Legible/editable por ti | **Sí, es texto plano** | No directamente |
| Actividad 30d | ≥100 | 174 |
| Tests | 412 | 306 |
| Issues abiertos | 72 | **13** |
| Presión comercial | Alta (upsell de nube en el README) | Baja |
| Mejor para | Que tu conocimiento siga siendo tuyo y portable | Backend compartido entre varios agentes/pipelines |

**Mi recomendación:** `basic-memory` si valoras que la memoria sea ficheros de texto que puedes leer, versionar en git y llevarte; `mcp-memory-service` si la licencia AGPL te bloquea o si necesitas servir memoria a varias herramientas por REST.

- **Riesgo de ejecución de ambos:** medio — leen y escriben en disco de forma persistente y la memoria envenenada es un vector de inyección persistente.
- **Aviso:** Claude Code ya tiene auto-memoria nativa por repositorio. Estos MCP aportan sobre todo **conocimiento entre proyectos**.

### 5.10 — Observabilidad: OTEL nativo + comet-ml/opik

- **Qué hace:** Claude Code ya emite spans por petición y por herramienta, métricas de tokens y coste, y eventos estructurados vía OTLP. Solo falta dónde mirarlos.
- **URL del backend recomendado:** https://github.com/comet-ml/opik
- **Por qué Opik y no Langfuse ni Phoenix:** Opik es **Apache-2.0 en todo el repositorio**; Langfuse tiene núcleo MIT pero carpetas `ee/` restringidas y ahora pertenece a ClickHouse, Inc.; Phoenix es **Elastic License 2.0, que no es software libre OSI**.
- **Actividad Opik:** ≥100/30d, 1.591 ficheros de test, 82 workflows, 21.577 ★.
- **Cómo mejoraría Claude:** deja de ser una caja negra. Ves coste por sesión, latencia por herramienta, dónde se van los tokens y qué llamadas fallan.
- **Riesgo:** las trazas contienen prompts y salidas → **contienen tu código y posibles secretos**. Self-host obligatorio si el contenido es sensible; Claude Code permite limitar longitud con `CLAUDE_CODE_OTEL_CONTENT_MAX_LENGTH`.
- **Complemento gratis y sin riesgo:** [`ccusage`](https://github.com/ryoppippi/ccusage) para coste, que solo lee JSONL locales.

---

## 6. LOS REPOSITORIOS QUE NO RECOMIENDO

### 6.1 — Populares con problemas graves

#### ⛔ `ruvnet/claude-flow` → `ruvnet/ruflo` — 66.205 ★
**Motivo: las funciones anunciadas no existen.**
Evidencia: [auditoría técnica independiente, abr-2026](https://gist.github.com/roman-rr/ed603b676af019b8740423d2bb8e4bf6) que probó las herramientas a mano y documentó que ~10 de 300+ son reales; `agent_spawn` solo crea una entrada en un `Map`; el consenso bizantino son eventos locales de un `EventEmitter`; el agente WASM devuelve `echo: <input>`; el "entrenamiento neuronal" devuelve `Math.random()`; el hive-mind es `spawn('claude', ['--dangerously-skip-permissions', ...])`.
Evidencia adicional que sí he medido yo: **6.806 de las contribuciones son de una sola persona**, y el proyecto se ha renombrado múltiples veces.
**Motivo independiente y suficiente por sí solo:** invoca `--dangerously-skip-permissions`. Eso desactiva la capa de permisos que es tu principal defensa contra prompt injection.
*Contrapunto honesto:* el repositorio está genuinamente activo (118 commits/30d) y hay usuarios satisfechos en sus discusiones. Pero "activo" no es "funciona", y la carga de la prueba está en el proyecto.

#### ⚠️ `affaan-m/ECC` (ex `everything-claude-code`) — 241.210 ★
**Motivo: superficie de auto-ejecución enorme + ecosistema de clones envenenados.**
La [auditoría de junio de 2026](https://dev.to/joergmichno/we-audited-the-viral-213k-star-everything-claude-code-repo-and-found-a-malware-clone-in-the-wild-14hb) concluye que **el original no es malware** pero instala "una superficie grande, globalmente activa y de auto-ejecución"; y que una re-subida (`arabicapp/everything-claude-code`) es un dropper con payload LuaJIT ofuscado.
No lo pongo en ⛔ porque el proyecto original es legítimo y su autor tiene credenciales reales. Lo pongo en ⚠️ porque **48 agentes + 183 skills + hooks globales instalados de golpe es exactamente el patrón que produce el 26,1 % de vulnerabilidad del estudio de arXiv**. Si lo quieres: clona, lee `hooks/`, `.mcp.json` y el instalador, y **copia solo las 3-5 skills que te sirvan**. No ejecutes el instalador.

#### ⚠️ `obra/superpowers` — 277.365 ★ — recomendado *con condiciones*
Aparece en el top 25 (#22), pero merece su matiz aquí. La crítica sustantiva, documentada en el propio issue tracker y en Hacker News:
- [Issue #190](https://github.com/obra/superpowers/issues/190): todas las skills se cargaban completas al inicio, **22.448 tokens = 11 % de una ventana de 200k**, frente a los ~1.400 esperados con carga progresiva. *El autor lo cerró como completado en 2 días*, y v6.1.0 se dedicó a comprimir el bootstrap — señal de mantenimiento serio.
- Críticas de HN (jun-2026): "huge token guzzler", "quemó todo mi plan max" en tareas simples, rigidez en trabajo exploratorio, y el argumento de que los modelos actuales ya planifican bien sin harness.
- A favor: una comparación controlada de la comunidad reportó **9 % más barato y 14 % menos tokens con mejor salida en tareas no triviales** — pero *más caro* en tareas simples. **[Una sola medición comunitaria, no independiente ni replicada.]**
**Veredicto:** instálalo si haces features de varias horas; desactívalo para tareas cortas. No es un "siempre encendido".

#### ⚠️ `upstash/context7` — 61.191 ★
Excelente utilidad, pero **es un servicio alojado**: cada consulta de documentación sale de tu máquina hacia sus servidores y se recomienda API key. Si trabajas con código o nombres de proyecto confidenciales, eso es una fuga de metadatos, no un detalle.

#### ⚠️ `musistudio/claude-code-router`
Vivo y competente (154 commits/30d), pero su función *es* enviar tus prompts y tu código a proveedores de terceros. Legítimo si es lo que buscas, inaceptable si no lo has pensado.

#### ⚠️ `Olow304/memvid`
Idea viral (memoria comprimida como vídeo) que circuló mucho en redes. Actividad real: **4 commits en 90 días**, y la propuesta técnica nunca fue validada frente a alternativas convencionales. Curiosidad, no infraestructura.

### 6.2 — Muertos o parados que se siguen recomendando

| Repo | Días sin commits | Por qué importa |
|---|---|---|
| `protectai/rebuff` | **942** | Se sigue citando como defensa contra prompt injection. |
| `protectai/vulnhuntr` | **564** | Idem, para descubrimiento de vulnerabilidades. |
| `riseandignite/mcp-shield` | **486** | "Escáner de seguridad MCP" abandonado. |
| `slowmist/MCP-Security-Checklist` | **484** | Citado en artículos de 2026. |
| `cyclotruc/gitingest` | **374** | Sustituido por repomix. |
| `Pimzino/claude-code-spec-workflow` | **352** | Sustituido por spec-kit. |
| `ericbuess/claude-code-project-index` | **348** | Sustituido por serena. |
| `WooooDyy/LLM-Agent-Paper-List` | **347** | Referencia de papers congelada. |
| `stanford-oval/storm` | **328** | Gran investigación, código detenido. |
| `getAsterisk/claudia` | **313** | GUI de Claude Code muerta. |
| `microsoft/LLMLingua` | **301** | Compresión de prompts muy citada. |
| `SciPhi-AI/R2R` | **291** | Plataforma RAG en listas de 2026. |
| `SYSTRAN/faster-whisper` | **279** | Base de muchos pipelines de audio. |
| `agiresearch/A-mem` | **255** | Paper de memoria agéntica. |
| `lasso-security/mcp-gateway` | **215** | "Gateway de seguridad MCP". |
| `nano-graphrag` / `fast-graphrag` | **210 / 296** | Alternativas ligeras a GraphRAG. |
| `explodinggradients/ragas` | **182** | Evaluación RAG omnipresente en tutoriales. |
| `davidkimai/Context-Engineering` | **179** | Viral en X. |
| `coleam00/context-engineering-intro` | **162** | Viral en YouTube. |
| `carlrannaberg/claudekit` | **146** | Toolkit de Claude Code. |
| `microsoft/autogen` | **140** | Framework multi-agente de referencia. |
| `neo4j-contrib/mcp-neo4j` | **136** | MCP oficial-ish de Neo4j. |
| `eyaltoledano/claude-task-master` | **124** | 422 commits el año pasado, 0 el último trimestre. |
| `BloopAI/vibe-kanban` | **123** | 0 commits en 90 días. |
| `steipete/agent-rules` | **120** | Reglas para agentes. |
| `Azure/PyRIT` | repo **vaciado** | Movido a `microsoft/PyRIT`; muchas listas apuntan al muerto. |
| `letta-ai/letta` | repo **vaciado** | Landing page; el sucesor es otra cosa. |

### 6.3 — Categorías enteras donde recomiendo no meterse (por ahora)

1. **Frameworks multi-agente generalistas** (crewAI, autogen, swarm-*). Para *mejorar Claude Code* no aportan: Claude Code ya orquesta subagentes de forma nativa, con profundidad de anidación configurable y hasta 20 concurrentes. Añadir otro orquestador encima multiplica complejidad y coste sin capacidad nueva.
2. **Mega-colecciones de skills/agentes de terceros.** Coste esperado (26,1 % de vulnerabilidad, ataques SCH indetectables) mayor que el beneficio. Copia skills sueltas, revisadas.
3. **Listas awesome como fuente de decisión.** Úsalas para descubrir la existencia de algo; nunca como aval.

---

## 7. ARQUITECTURA RECOMENDADA

### Principio de diseño

> **Cada capa que añadas debe darte una capacidad que Claude Code no tiene, no una versión distinta de una que ya tiene.**

Claude Code en agosto de 2026 ya trae: sandbox de Bash con aislamiento de SO y allowlist de red, skills con carga progresiva, marketplace de plugins con allow/blocklist, subagentes anidados, auto-memoria por repo, hooks (`PreToolUse`, `DirectoryAdded`…), OTEL nativo, y `/security-review`. **Eso es la base. No la dupliques.**

### CORE — imprescindibles

| Capa | Elección | Por qué |
|---|---|---|
| Distribución | **`anthropics/claude-plugins-official`** | Procedencia verificable + allowlist por owner. |
| Aislamiento | **`anthropic-experimental/sandbox-runtime`** + sandbox nativo de Bash | Contención real frente a inyección; único control eficaz contra ataques payload-less. |
| Auditoría | **`snyk/agent-scan`** | Escanea skills y MCP antes de confiar en ellos. |
| Código | **`oraios/serena`** | La mayor mejora individual de rendimiento y coste. |
| Repos/PRs | **`github/github-mcp-server`** | Oficial, activo, integración limpia. |
| Coste | **`ryoppippi/ccusage`** | Riesgo cero, visibilidad inmediata del gasto. |
| Entorno | **`astral-sh/uv`** (+ `mise` si usas varios runtimes) | Instalaciones efímeras y reproducibles = menos superficie. |
| Secretos | **`gitleaks`** vía `pre-commit` | Impide que el agente commitee credenciales. |

### HIGH VALUE — muy recomendables

| Capa | Elección | Cuándo |
|---|---|---|
| Método | **`github/spec-kit`** | Features de más de una sesión. |
| Contexto | **`yamadashy/repomix --sandbox`** | Auditorías, migraciones, revisión global. |
| Documentos | **`docling-project/docling`** | Si trabajas con PDF/DOCX/PPTX. |
| Web/front | **`ChromeDevTools/chrome-devtools-mcp`** | Depuración real de front-end. *Perfil de navegador dedicado.* |
| Observabilidad | **OTEL nativo → `comet-ml/opik`** self-hosted | Cuando quieras medir, no intuir. |
| Dependencias | **`google/osv-scanner`** + **`safedep/vet`** | Cuando el agente instala paquetes por ti. |
| Metodología | **`obra/superpowers`** con activación selectiva | Features largos y sensibles a corrección. |

### OPTIONAL — según tu uso

| Necesidad real | Elección | Nota |
|---|---|---|
| Memoria entre proyectos | `basic-memory` (AGPL) **o** `doobidoo/mcp-memory-service` (Apache-2.0) | Uno, no dos. |
| Grafo de conocimiento | `topoteretes/cognee` **o** `getzep/graphiti` | Solo si tu dominio tiene relaciones temporales o causales reales. |
| RAG documental | `HKUDS/LightRAG` | Sobre corpus grande y estable. |
| Investigación | `assafelovic/gpt-researcher` | Con verificación humana de citas. |
| Citas/bibliografía | `54yyyu/zotero-mcp` | Si escribes con fuentes. |
| Evaluación seria | `UKGovernmentBEIS/inspect_ai` + `promptfoo` | Cuando cambies prompts/skills y necesites no regresionar. |
| SAST | `semgrep` | Reglas propias en pre-commit. |
| Audio | `ggml-org/whisper.cpp` | 100 % local. |
| Búsqueda estructural | `ast-grep` | Refactors por patrón. |

### EXPERIMENTAL — interesantes, aún no maduros

`MemTensor/MemOS` · `trycua/cua` · `superradcompany/microsandbox` · `stanfordnlp/dspy` · `google/langextract` · `bytedance/deer-flow` · `LearningCircuit/local-deep-research` · `letta-ai/letta-code` (como harness alternativo, no como memoria).

### AVOID

`ruvnet/ruflo` · el instalador completo de `affaan-m/ECC` · `protectai/*` (rebuff, llm-guard, vulnhuntr) · `mcp-shield` · `mcp-gateway` de Lasso · `memvid` · cualquier framework multi-agente encima de Claude Code · cualquier repo de la tabla §6.2.

### Diagrama conceptual

```
┌──────────────────────────────────────────────────────────┐
│  CAPA 0 — CLAUDE CODE NATIVO (no duplicar)               │
│  sandbox Bash · skills · plugins · subagentes ·          │
│  auto-memoria · hooks · OTEL · /security-review          │
└──────────────────────────────────────────────────────────┘
        │
        ├── CONTENCIÓN ──► srt (sandbox-runtime)  ── envuelve a todos los MCP
        │                  snyk/agent-scan        ── audita antes de confiar
        │
        ├── CÓDIGO ──────► serena (semántica) · repomix --sandbox · ast-grep
        │                  github-mcp-server
        │
        ├── MÉTODO ──────► spec-kit  (+ superpowers selectivo)
        │
        ├── CONOCIMIENTO ► docling → [basic-memory | mcp-memory-service]
        │                  (opcional: cognee/graphiti si hay relaciones reales)
        │
        ├── MUNDO ───────► chrome-devtools-mcp  (perfil aislado)
        │                  whisper.cpp (local)
        │
        └── MEDICIÓN ────► OTEL nativo → opik (self-host) · ccusage
                           inspect_ai / promptfoo para regresión
```

**Cuenta final: 8 piezas en CORE, 7 en HIGH VALUE.** Deliberadamente pequeño. Con 10.000+ servidores MCP públicos, la disciplina de mantener 3-6 activos a la vez es lo que separa un entorno rápido de uno lento.

---

## 8. PLAN DE IMPLEMENTACIÓN

Ninguna fase empieza hasta que autorices la anterior. Cada fase incluye su criterio de reversión.

### FASE 0 — Antes de instalar nada (30 min, riesgo nulo)

1. Ejecutar `/doctor` y `/context` en Claude Code y anotar el consumo base de tokens de arranque. **Sin línea base no puedes saber si algo empeora.**
2. Revisar `/sandbox`: comprobar si el sandbox de Bash está activo y qué modo usa. En Linux/WSL2 verificar dependencias.
3. Poner `~/.claude/` bajo control de versiones (git o `chezmoi`). **Esto es lo que hace reversible todo lo demás.**
4. Anotar el gasto actual con `npx ccusage` (no instala nada permanente).

### FASE 1 — Bajo riesgo, alto retorno (1-2 h)

| Paso | Acción | Reversión |
|---|---|---|
| 1.1 | `uv` (o verificar que ya lo tienes) | desinstalar binario |
| 1.2 | `ccusage` como herramienta habitual | ninguna instalación persistente |
| 1.3 | `snyk/agent-scan` vía `uvx` y **escaneo del estado actual** | `uv cache clean` |
| 1.4 | `gitleaks` + `pre-commit` en tus repos activos | borrar `.pre-commit-config.yaml` |
| 1.5 | Explorar `/plugin marketplace` oficial; **no instalar todavía** | — |
| 1.6 | Leer la spec de `agentskills/agentskills` | — |

**Criterio de éxito de la fase:** sabes qué tienes instalado, cuánto te cuesta y si algo de lo que ya usas está marcado como riesgo.

### FASE 2 — Mejoras importantes (medio día)

| Paso | Acción | Reversión |
|---|---|---|
| 2.1 | **`serena`** siguiendo el Quick Start **oficial** (no marketplace) | `claude mcp remove serena` |
| 2.2 | **`github-mcp-server`** con token de **permisos mínimos** (repos concretos, no `repo` completo) | revocar token + quitar servidor |
| 2.3 | **`sandbox-runtime` (`srt`)** y envolver con él los MCP de terceros | desinstalar paquete global |
| 2.4 | **`spec-kit`** en un proyecto piloto | borrar directorio del proyecto |
| 2.5 | Medir de nuevo con `/context` y `ccusage`: **¿bajó el coste por tarea?** | revertir 2.1 si no |

**Regla de la fase:** instala **uno cada vez** y mide entre pasos. Si instalas cuatro cosas juntas no sabrás cuál causó la regresión.

### FASE 3 — Funcionalidades avanzadas (1-2 días)

| Paso | Acción | Reversión |
|---|---|---|
| 3.1 | **`repomix`** (usar siempre `--sandbox` en modo MCP) | desinstalar |
| 3.2 | **`docling`** en entorno `uv` aislado | borrar entorno virtual |
| 3.3 | **`chrome-devtools-mcp`** con **perfil de navegador dedicado y sin sesiones sensibles** | quitar servidor + borrar perfil |
| 3.4 | **Observabilidad:** activar exportación OTEL nativa → `opik` self-hosted en Docker | desactivar variables OTEL + `docker compose down` |
| 3.5 | **Memoria:** elegir `basic-memory` **o** `mcp-memory-service` y probar 2 semanas en un solo dominio | quitar servidor; los datos de basic-memory son Markdown que conservas |
| 3.6 | `osv-scanner` + `safedep/vet` en el flujo de dependencias | desinstalar binarios |

### FASE 4 — Experimental (solo con sandbox y sin datos reales)

| Paso | Acción | Condición obligatoria |
|---|---|---|
| 4.1 | `superpowers` activado selectivamente en un proyecto | medir `/context` antes/después; desactivar si el arranque sube >5k tokens sin beneficio |
| 4.2 | `cognee` o `graphiti` sobre un corpus de prueba | contenedor aislado; nunca datos de cliente |
| 4.3 | `inspect_ai` / `promptfoo` para una suite de regresión propia | — |
| 4.4 | `browser-use` o `trycua/cua` | **exclusivamente en VM desechable**; nunca con credenciales reales |
| 4.5 | `dspy`, `langextract`, `local-deep-research` | proyectos aparte, no en el entorno principal |

### Lo que NO haría en ninguna fase

- Ejecutar un instalador `curl | bash` de un repositorio de terceros.
- Instalar una colección completa de skills/agentes sin leer sus hooks.
- Usar `--dangerously-skip-permissions` fuera de un contenedor desechable.
- Activar más de 6 servidores MCP simultáneos.
- Instalar dos herramientas de la misma categoría "para comparar" sin desinstalar una.

---

## 9. MATRIZ DE RIESGO

Escalas: Beneficio/Complejidad/Riesgo = Bajo · Medio · Alto. Reversibilidad = Total (borrar y ya) · Alta (queda config) · Media (quedan datos/estado) · Baja (cambios en el sistema).

| Herramienta | Beneficio | Complejidad | Riesgo | Permisos que exige | Reversibilidad |
|---|---|---|---|---|---|
| `ccusage` | Medio | Baja | **Muy bajo** | Solo lectura de `~/.claude/*.jsonl`. Sin red. | Total |
| `claude-plugins-official` | Alto | Baja | Bajo-Medio | Instala código que corre en tu sesión; procedencia oficial | Total (`/plugin uninstall`) |
| `agentskills` (spec) | Medio | Nula | Nulo | Ninguno, es documentación | Total |
| `best-of-mcp-servers` | Medio | Nula | Nulo | Ninguno, es una lista | Total |
| `uv` | Alto | Baja | Bajo | Escribe en `~/.local`, descarga paquetes de PyPI | Total |
| `gitleaks` + `pre-commit` | Alto | Baja | Bajo | Lectura del repo; hook de git | Total |
| `snyk/agent-scan` | Alto | Baja | Bajo | **Lee toda tu configuración de MCP y skills**; posible telemetría | Total |
| `sandbox-runtime` (`srt`) | Alto | Media | Bajo | Instala binario global; usa `bubblewrap`/`sandbox-exec`; **proxy de red** | Alta |
| `serena` | **Muy alto** | Media | Medio | **Lee y escribe tu código**; lanza subprocesos (language servers) | Alta |
| `github-mcp-server` | Alto | Baja | **Medio-Alto** | **Token de GitHub.** Con permisos amplios puede leer/escribir repos y abrir PRs | Alta (revocar token) |
| `repomix` (`--sandbox`) | Medio | Baja | Bajo | Lectura del repo; sin `--sandbox` puede leer fuera y empaquetar remoto | Total |
| `spec-kit` | Alto | Baja | Bajo | Escribe plantillas en el proyecto | Total |
| `superpowers` | Alto (condicional) | Media | Medio | **Hook de session-start que inyecta contexto en cada sesión** + skills ejecutables | Alta |
| `docling` | Alto | Media | Medio | Procesa ficheros no confiables (parser = superficie de ataque); descarga modelos | Alta |
| `chrome-devtools-mcp` | Alto | Media | **Alto** | **Controla un navegador**: cookies, sesiones, formularios. Contenido web = inyección de prompt | Alta |
| `browser-use` | Alto | Alta | **Muy alto** | Navegación autónoma con credenciales. Combina las tres patas de la "lethal trifecta" | Media |
| `basic-memory` | Medio-Alto | Media | Medio | Lee/escribe un directorio de notas; **memoria envenenada = inyección persistente**. AGPL-3.0 | Media (los datos son tuyos, en Markdown) |
| `mcp-memory-service` | Medio-Alto | Media | Medio | Igual; además abre **REST + OAuth** si lo activas | Media |
| `cognee` / `graphiti` | Medio | **Alta** | Medio | Base de datos de grafos + llamadas LLM de indexación (**coste real en tokens**) | Media |
| `LightRAG` | Medio | Alta | Medio | Indexación cara; almacena embeddings | Media |
| `opik` (self-host) | Alto | Media | Medio | **Las trazas contienen tus prompts, código y posibles secretos** | Alta |
| `langfuse` (self-host) | Alto | Media | Medio | Igual; licencia mixta MIT + `ee/` | Alta |
| `promptfoo` / `inspect_ai` | Alto | Media | Bajo | Llama a modelos (coste); lee tus prompts | Total |
| `semgrep` | Alto | Media | Bajo | Lectura de código; reglas de la nube si usas registry remoto | Total |
| `osv-scanner` / `safedep/vet` | Alto | Baja | Bajo | Lee manifiestos; consulta bases de datos remotas | Total |
| `whisper.cpp` | Medio | Media | Bajo | Local, sin red. Descarga de modelo inicial | Total |
| `context7` | Medio | Baja | **Medio (privacidad)** | **Envía consultas a servidores de terceros**; API key | Total |
| `claude-code-router` | Variable | Media | **Alto (privacidad)** | **Redirige prompts y código a otros proveedores** | Alta |
| `ruflo` | ❌ | Alta | **Crítico** | Usa `--dangerously-skip-permissions` | Baja (5.607 ficheros) |
| Instalador de `ECC` | ❌ | Media | **Alto** | Hooks globales + 183 skills + MCP, todo de golpe | Baja |

### Reglas transversales de permisos

1. **Tokens con el mínimo alcance.** Un token de GitHub para el MCP debe apuntar a repos concretos, no llevar `repo` completo ni `admin:*`.
2. **Un MCP no confiable = un `srt` alrededor.** Sin excepciones para servidores que tocan red.
3. **Navegador = perfil desechable.** Nunca el perfil con tus sesiones de banco, correo o GitHub.
4. **Memoria = revisable.** Prefiere formatos que puedas leer (Markdown) sobre blobs binarios: si alguien envenena la memoria, quieres poder verlo.
5. **Trazas = datos sensibles.** Observabilidad autoalojada si tu código es confidencial.

---

## 10. FUENTES

### Documentación oficial
- [Claude Code — Changelog](https://code.claude.com/docs/en/changelog) · [Skills](https://code.claude.com/docs/en/skills) · [Plugins](https://code.claude.com/docs/en/plugins) · [Sandboxing](https://code.claude.com/docs/en/sandboxing) · [MCP](https://code.claude.com/docs/en/mcp) · [Memory](https://code.claude.com/docs/en/memory) · [Observabilidad OTEL](https://code.claude.com/docs/en/agent-sdk/observability)
- [Agent Skills — estándar abierto](https://agentskills.io) · [spec en GitHub](https://github.com/agentskills/agentskills)
- [Model Context Protocol — Security Best Practices](https://modelcontextprotocol.io/docs/2026-07-28/tutorials/security/security_best_practices)
- [Anthropic — AI Fluency: Framework & Foundations](https://academy.claude.com/courses/ai-fluency-framework-foundations) · [materiales abiertos](https://aifluencyframework.org/)

### Papers y estudios
- [*Agent Skills in the Wild: An Empirical Study of Security Vulnerabilities at Scale* — arXiv:2601.10338](https://arxiv.org/abs/2601.10338) — 42.447 skills, 26,1 % vulnerables
- [*Exploiting LLM Agent Supply Chains via Payload-less Skills* — arXiv:2605.14460](https://arxiv.org/abs/2605.14460) — SCH, 77,67 % éxito, 0,00 % detección
- [*Agent Skills: A Data-Driven Analysis of Claude Skills* — arXiv:2602.08004](https://arxiv.org/abs/2602.08004) — 40.285 skills, redundancia y homogeneidad del ecosistema
- [*When Safe Skills Collide: Measuring Compositional Risk in Agent Skill Ecosystems* — arXiv:2606.00448](https://arxiv.org/pdf/2606.00448)
- [NSA/CISA — *Model Context Protocol: Security Design* (CSI, jun-2026)](https://media.defense.gov/2026/Jun/02/2003943289/-1/-1/0/CSI_MCP_SECURITY.PDF)
- [Cloud Security Alliance — MCP Security Crisis](https://labs.cloudsecurityalliance.org/research/csa-research-note-mcp-security-crisis-20260504-csa-styled/) · [Tool Poisoning y auto-ejecución en IDE](https://labs.cloudsecurityalliance.org/research/csa-research-note-mcp-tool-poisoning-auto-execution-20260701/)
- [OWASP — MCP Security Cheat Sheet](https://cheatsheetseries.owasp.org/cheatsheets/MCP_Security_Cheat_Sheet.html)

### Auditorías y evidencia independiente
- [Auditoría técnica de Ruflo/Claude-Flow (abr-2026)](https://gist.github.com/roman-rr/ed603b676af019b8740423d2bb8e4bf6)
- [Auditoría de ECC y clon con malware (jun-2026)](https://dev.to/joergmichno/we-audited-the-viral-213k-star-everything-claude-code-repo-and-found-a-malware-clone-in-the-wild-14hb)
- [obra/superpowers — issue #190, 22k tokens al arranque](https://github.com/obra/superpowers/issues/190)
- [Los compromisos honestos de Superpowers (jul-2026)](https://www.joanmedia.dev/ai-blog/the-honest-tradeoffs-of-superpowers-token-costs-overkill-and-the-alternatives)

### La disputa de benchmarks de memoria (ambos lados)
- [Mem0 — *Revisiting Zep's 84% LoCoMo Claim* (issue en zep-papers)](https://github.com/getzep/zep-papers/issues/5)
- [Zep — *Is Mem0 Really SOTA in Agent Memory?* (con corrección publicada)](https://blog.getzep.com/lies-damn-lies-statistics-is-mem0-really-sota-in-agent-memory/)
- [Crítica independiente al propio benchmark LoCoMo](https://dev.to/gde03/the-ai-memory-benchmark-everyone-quotes-forbids-saying-i-dont-know-o1n)

### Gobernanza y licencias
- [ClickHouse adquiere Langfuse (ene-2026)](https://clickhouse.com/blog/clickhouse-acquires-langfuse-open-source-llm-observability) · [nota de Langfuse](https://langfuse.com/blog/joining-clickhouse)
- Licencias verificadas descargando el fichero `LICENSE` de cada repositorio: Phoenix = Elastic License 2.0; Langfuse = MIT + `ee/` restringido (© ClickHouse, Inc.); basic-memory y trufflehog = AGPL-3.0; awesome-claude-code = CC BY-NC-ND 4.0.

### Vulnerabilidades citadas
- CVE-2025-6514 (`mcp-remote`, CVSS 9.6, RCE) · CVE-2025-59536 (Claude Code, RCE vía `.claude/settings.json` en repos clonados, CVSS 8.7) · CVE-2026-33032 ("MCPwn", CVSS 9.8) · CVE-2026-12957 / 12958 (Amazon Q). **Recogidas de recopilaciones secundarias; verifica los detalles en la NVD antes de citarlas en un contexto formal.**

---

## Nota final sobre el método

Lo que **sí** he verificado personalmente: fechas de commits, frecuencia de actividad, autores distintos, presencia de licencia/CI/tests/SECURITY.md, contenido de ficheros LICENSE y README, renombrados y repos vaciados. Todo mediante clones y descargas directas el 25-08-2026.

Lo que **no** he verificado y señalo como tal: no he ejecutado ninguna herramienta, no he replicado la auditoría de Ruflo ni la de ECC, no he corrido benchmarks propios, y las cifras de estrellas/issues son las que muestra GitHub en ese momento.

Lo que es **opinión razonada, no hecho**: las puntuaciones de la §4 y el reparto CORE/HIGH VALUE/OPTIONAL. Están construidas sobre las mediciones anteriores, pero los pesos son un juicio, y otro analista con las mismas mediciones podría ordenar distinto.

**No se ha instalado, ejecutado ni modificado nada en tu entorno.**
