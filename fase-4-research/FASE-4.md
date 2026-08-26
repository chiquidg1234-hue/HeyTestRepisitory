# FASE 4 — Research local

**Fecha:** 26-08-2026 · **Estado:** **COMPLETADA** (con una laguna medida y documentada)
**Criterio:** *«las búsquedas web por dudas de API caen a casi cero»* → **demostrado con medición, no por existencia de ficheros.**

## Qué se instaló

| | |
|---|---|
| Corpus | `Roblox/creator-docs`, commit `9d486bb`, **9 295 ficheros / 64 MB** |
| Ubicación | `~/.local/share/creator-docs` (**fuera del repo**: 64 MB no se commitean) |
| Tiempo de clonado | **3 s** (`--depth 1`) |
| Helper | `rbxdocs` → [`herramientas/rbxdocs`](herramientas/rbxdocs), instalado en `~/.local/bin` |
| Reversible con | `rm -rf ~/.local/share/creator-docs ~/.local/bin/rbxdocs` |

## Composición del corpus (medida)

| Tipo | Cantidad |
|---|---|
| Clases de la API (`.yaml`) | **641** |
| Bibliotecas Luau (`.yaml`) | 11 |
| Datatypes (`.yaml`) | 48 |
| Guías narrativas (`.md`) | **1 007** |

## Medición: batería de preguntas reales

No inventé preguntas: usé las **ocho dudas de API que surgieron realmente** en las fases 0-3.

| # | Pregunta | Resultado |
|---|---|---|
| 1 | ¿Existe `os.exit` en Roblox? | ✅ **Respuesta definitiva** |
| 2 | `UpdateAsync`: semántica | ✅ En `GlobalDataStore.yaml` |
| 3 | Session locking de perfiles | ✅ `player-data-purchasing.md` |
| 4 | `OnServerEvent`: primer argumento | ✅ Firma exacta con `player` |
| 5 | Límites de presupuesto de DataStore | ✅ `error-codes-and-limits.md` |
| 6 | Riesgo de `RemoteFunction` | ✅ `security/client-server-boundary.md` |
| 7 | Open Cloud Luau Execution: límites | ❌ **NO está en el corpus** |
| 8 | `SetAsync` vs `UpdateAsync` | ✅ |

**Puntuación: 7 / 8.**

### Corrección de método aplicada en el sitio

Mi primera pasada dio **4/8**. Antes de puntuar comprobé si los fallos eran del corpus
o **de mis consultas** — el mismo error que cometí en FASE 2. **Tres de los cuatro fallos eran
míos:** buscaba sólo en los `.md` y las respuestas estaban en los `.yaml`.

**Esa lección es el contenido principal de la regla que escribí**: hay que buscar en las dos formas.

### El caso que justifica la fase entera

> **Pregunta 1 responde exactamente el defecto que `run3b` entregó en FASE 3.**

La referencia oficial `libraries/os.yaml` lista **cuatro** funciones: `os.clock`, `os.date`,
`os.difftime`, `os.time`. **`os.exit` aparece 0 veces.**

`run3b` entregó 2 errores de tipo por usar `os.exit()`. **Una consulta local de 10 ms lo habría
evitado.** No es un beneficio hipotético: es un defecto real ya cometido, con su antídoto medido.

## Latencia medida

| Operación | Tiempo |
|---|---|
| `grep` local sobre los 1 260 `.yaml` | **10 ms** |
| Una sola petición de red (mejor caso) | **435 ms** |

**43× más rápido que una única petición**, y una búsqueda web real son varios segundos más varias
peticiones. Además: sin variabilidad de red, sin alucinación, sin coste de tokens de fetch.

## Laguna medida

**Las APIs de Open Cloud no están en `creator-docs`.** Viven en `create.roblox.com/docs/cloud`.
Afecta a la Luau Execution API, que es la pieza de CI de FASE 7. **Documentado en la regla como
la única excepción legítima para buscar en la web.**

## Digests de Verse: **BLOQUEADO**

Los digests (`Fortnite.digest.verse`, `UnrealEngine.digest.verse`, `Assets.digest.verse`) se
generan **dentro de una instalación de UEFN**, en
`C:\Users\<USUARIO>\AppData\Local\UnrealEditorFortnite\Saved\VerseProject\FortniteGame\`.

- UEFN es **sólo Windows** y este entorno es Linux.
- No existe descarga pública de los digests: los produce el compilador local.

**No se puede hacer nada aquí.** Queda como paso pendiente en tu máquina: localizar la ruta y
añadir la regla equivalente de verificación de símbolos para Verse.

## Entregables

1. `herramientas/rbxdocs` — helper verificado funcionalmente con tres consultas reales.
2. [`../reglas/CLAUDE-fragmento-research.md`](../reglas/CLAUDE-fragmento-research.md) — la regla
   «local antes que web», con la recomendación de buscar en ambas formas y la regla de
   verificación de símbolos.

## CHECKPOINT

| Campo | Valor |
|---|---|
| **Fase** | 4 — Research |
| **Estado** | **COMPLETADA** |
| **Herramientas** | corpus `creator-docs` + helper `rbxdocs` |
| **Pruebas reales** | 8 consultas ejecutadas; helper verificado con 3 invocaciones |
| **Métricas** | 7/8 preguntas respondidas · 10 ms vs 435 ms · 64 MB · clonado en 3 s |
| **Limitaciones** | Open Cloud fuera del corpus; digests de Verse inaccesibles desde Linux |
| **Pendiente de humano** | Localizar los digests de Verse en la máquina Windows |
| **Siguiente paso** | FASE 5 — testing (selene → StyLua → hook PostToolUse → Lune/Lute → hook Stop) |
