# FASE 8 — Evaluación de Serena

Fecha: 2026-08-27
Estado: **EVALUADA — veredicto: POSPONER**
Presupuesto asignado: ~5 USD. Presupuesto realmente consumido: ver `## Coste`.

---

## 1. Procedencia (auditada antes de instalar)

| Comprobación | Resultado |
|---|---|
| Repositorio oficial | `github.com/oraios/serena`, commit `7fcbca7` |
| Nombre de paquete declarado en `pyproject.toml` | `name = "serena-agent"` |
| Versión en el repo | `1.7.1.dev0` |
| Licencia | MIT |
| `requires-python` | `>=3.11, <3.15` |
| Paquete en PyPI | `serena-agent` 1.7.0 |
| `Homepage` del paquete PyPI | `https://github.com/oraios/serena` — **coincide** |

Veredicto de procedencia: **legítimo**. El nombre del paquete de PyPI coincide con el manifiesto
del repositorio oficial, que es exactamente la comprobación que evita el patrón de
typosquatting que rechazó el paquete npm `luau-lsp` en FASE 2.

## 2. Instalación

- `pip3 install serena-agent` **falló**: la dependencia transitiva `proxy_tools` rompe con
  setuptools moderno (`AttributeError: install_layout`).
- Solución aplicada: entorno virtual aislado en el scratchpad →
  `$SCRATCH/serena-venv/bin/serena`, **Serena 1.7.0**.
- No se modificó `~/.claude` de forma permanente. La configuración MCP se pasó
  por `--mcp-config` a un único proceso, no se registró globalmente.

## 3. Hallazgo previo al experimento: qué motor usa Serena para Luau

`solidlsp/language_servers/luau_lsp.py` del propio código de Serena dice:

> "This uses JohnnyMorganz/luau-lsp as the language server backend"
> "luau-lsp binary must be installed and available in PATH, or it will be automatically
> downloaded from GitHub releases"

**Serena no aporta un motor de análisis nuevo para Luau.** Usa el mismo `luau-lsp` que ya
está instalado desde FASE 2. Lo que Serena añade encima es: herramientas MCP a nivel de
símbolo, edición por símbolo, y un sistema de memorias por proyecto.

Esto acota de antemano el beneficio posible: no puede detectar errores de tipos que
`luau-lsp analyze` no detecte ya, porque es el mismo analizador.

## 4. Experimento (n=1): T-01 con Serena

Una única ejecución, como se acordó. Mismas condiciones que run3b salvo Serena:

- Misma TAREA-PATRON congelada.
- Mismo `CLAUDE.md` (verificado idéntico con `diff -q`).
- Mismos `--allowedTools` + `mcp__serena`.
- `--mcp-config` apuntando a `serena start-mcp-server --context claude-code --project <dir>`.
- `--permission-mode acceptEdits`.

### 4.1 ¿Se usó Serena realmente?

Verificado **en el transcript JSONL**, contando bloques `tool_use` reales, no menciones textuales.

| Métrica | Valor |
|---|---|
| Herramientas Serena **expuestas** al agente | **21** |
| Llamadas `tool_use` totales en run4 | 48 |
| Llamadas `tool_use` a `mcp__serena__*` | **1** |
| Cuál | `mcp__serena__initial_instructions` |
| Herramientas **simbólicas** ejecutadas (`find_symbol`, `get_symbols_overview`, `find_referencing_symbols`, `replace_symbol_body`, …) | **0** |

Las 21 herramientas estaban disponibles (aparecen en el `deferred_tools_delta` del transcript,
lista completa abajo). El agente hizo `ToolSearch` de `initial_instructions`, la ejecutó,
recibió ~8,9 KB de instrucciones que le decían explícitamente que usara las herramientas
simbólicas… y a continuación **no usó ninguna**. Editó con `Write` (9) y `Edit` (5) y
verificó con `Bash` (28).

`find_symbol`, `find_referencing_symbols`, etc. aparecen 10, 8, … veces en el fichero del
transcript, pero **todas esas apariciones están dentro del texto de `initial_instructions` y
del listado de herramientas diferidas**, no en ninguna llamada. Este es exactamente el error
de FASE 2 y esta vez se comprobó antes de escribir la conclusión.

Herramientas Serena expuestas (21): `delete_memory`, `edit_memory`, `find_declaration`,
`find_implementations`, `find_referencing_symbols`, `find_symbol`, `get_diagnostics_for_file`,
`get_symbols_overview`, `initial_instructions`, `insert_after_symbol`, `insert_before_symbol`,
`list_memories`, `onboarding`, `read_memory`, `rename_memory`, `rename_symbol`,
`replace_content`, `replace_in_files`, `replace_symbol_body`, `safe_delete_symbol`,
`write_memory`.

### 4.2 Métricas comparadas

| Métrica | run3b (sin Serena) | run4 (con Serena) | Δ |
|---|---|---|---|
| Turnos (`num_turns`) | 24 | 49 | **+104 %** |
| Coste (`total_cost_usd`) | $1.1525 | $1.8730 | **+62,5 %** |
| Tokens totales (in+out+cache_creation+cache_read) | 1.888.019 | 4.325.959 | **+129 %** |
| Tiempo de API | 465 s | 534 s | +15 % |
| Llamadas de herramienta | 23 | 48 | +109 % |
| Ficheros entregados (`src` + `tests`) | 7 | 8 | +1 |
| Líneas entregadas | 919 | 1029 | +12 % |

### 4.3 Calidad entregada (medida, no estimada)

Procedimiento idéntico en ambos: `rojo sourcemap` → `luau-lsp analyze --sourcemap --definitions`.

| Comprobación | run3b | run4 |
|---|---|---|
| Errores de `luau-lsp analyze` en `src/` | **0** | **0** |
| Errores de `luau-lsp analyze` en `tests/` | **2** | **0** |
| Los tests se ejecutan con Lune | Sí | Sí |
| Aserciones que pasan | 27/27 | 33/33 |
| Código de salida cuando **todo pasa** | **1 (incorrecto)** | **0 (correcto)** |
| Código de salida cuando **algo falla** | no comprobable (siempre falla) | **1 (correcto)** — verificado rompiendo una aserción en una copia |

Causa del fallo de run3b: usa `os.exit(0)` / `os.exit(1)`. `os.exit` **no existe** en Lune ni
en Roblox Luau, así que la suite revienta con `attempt to call a nil value` después de pasar
las 27 comprobaciones. Es decir: **la suite de run3b nunca puede dar verde**, y eso incumple el
requisito 6 de la TAREA-PATRON. run4 usa `error()`, que da 0 al pasar y 1 al fallar.

### 4.4 ¿Es esa mejora atribuible a Serena?

**No.** Serena no ejecutó ninguna herramienta simbólica ni de diagnóstico. Su única aportación
material a la ejecución fue un bloque de instrucciones de ~8,9 KB. El `os.exit` de run3b lo
habría detectado igual `luau-lsp analyze` sobre `tests/` — de hecho run3b **lo ejecutó y vio
los dos errores**, y no los corrigió. run4 ejecutó `luau-lsp analyze` sobre `tests/` y salió
limpio porque no había usado `os.exit` de entrada.

Con n=1, y sin un mecanismo causal por el que Serena pudiera producir esa diferencia, la
explicación honesta es **variabilidad entre ejecuciones**, no efecto de Serena.

Lo que sí es atribuible a Serena con mecanismo claro es el **coste**: +62,5 % en dinero y
+129 % en tokens, por un bloque de instrucciones reinyectado en cada turno y por el doble de
turnos.

## 5. Veredicto: POSPONER

Criterios que el usuario fijó, respondidos uno a uno:

| Criterio | Respuesta |
|---|---|
| ¿Se usó Serena de verdad? | Solo `initial_instructions`. **0 herramientas simbólicas.** |
| ¿Encontró referencias que el stack anterior no podía? | No. No se ejecutó ninguna búsqueda de referencias. |
| ¿Redujo errores reales? | No demostrable. La diferencia en `tests/` no tiene mecanismo causal vía Serena. |
| ¿Mejoró alguna capacidad que importe? | No en esta ejecución. |
| ¿El beneficio justifica coste/complejidad/permisos? | **No.** Coste medido +62,5 %, beneficio medido 0. |

**No DESCARTAR**, porque la hipótesis no está refutada, solo no confirmada:

- El proyecto de prueba tiene 8 ficheros y ~1000 líneas. Las herramientas simbólicas de Serena
  están pensadas para bases de código donde leer ficheros enteros es caro. A esta escala,
  `Read` de un fichero completo es más barato que un `get_symbols_overview` + `find_symbol`.
- El motor es el mismo `luau-lsp` ya instalado, así que en un proyecto Roblox grande y real
  el valor de Serena sería la navegación por símbolos y las memorias, no el análisis.

**Condición para re-evaluar**: un proyecto Roblox real de ≥ 50 ficheros o ≥ 10.000 líneas,
midiendo específicamente tokens por tarea de refactor multi-fichero. Antes de eso, no.

## 6. Coste

| Concepto | USD |
|---|---|
| Auditoría de procedencia + instalación | ~0 (sin llamadas de API caras) |
| Ejecución T-01 run4 (subproceso medido) | **1,8730** |
| Mi propio coste conversacional desde la orden (01:47 Z), estimado a partir de los tokens del transcript | **~10,60** |
| **Total del bloque Serena** | **~12,47** |

**El presupuesto de ~5 USD se ha excedido (~2,5×).** Se declara sin adornos. La partida
dominante no es el experimento (1,87 USD) sino la lectura repetida de un contexto ya muy
grande en cada turno: 17,5 M de tokens de `cache_read` desde las 01:47 Z. La lección operativa
está en la sección de próximos pasos de la auditoría final.

## 7. Estado dejado en el sistema

- Serena vive **solo** en `$SCRATCH/serena-venv`, que es efímero. No se registró en `~/.claude`,
  ni en `.mcp.json` del repositorio, ni globalmente.
- El proyecto Roblox principal no se tocó.
- La evidencia congelada (`fase-0-baseline/T01-run1-salida/`,
  `fase-2-code-intelligence/T01-run2-salida/`, `fase-3-rojo/T01-run3{a,b}-salida/`) no se tocó.
- No se creó ninguna credencial, token ni secreto.
