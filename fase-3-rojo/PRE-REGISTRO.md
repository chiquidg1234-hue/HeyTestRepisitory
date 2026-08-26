# FASE 3 — Pre-registro del experimento

**Escrito y commiteado ANTES de instalar Rojo o ejecutar nada.**
Fecha: 26-08-2026.

> Se pre-registra para que la predicción no pueda ajustarse después de ver el resultado.
> Si el commit de este fichero no precede al de los resultados, el experimento no vale.

## Hipótesis aprobada

> *"Integrar Rojo/sourcemap con luau-lsp y medir si reduce falsos positivos e iteraciones."*

Se descompone en dos hipótesis independientes, que pueden salir una sí y otra no.

---

### H1 — Falsos positivos

**Predicción:** con un sourcemap generado por **Rojo real**, `luau-lsp analyze` sobre el
**mismo código sin modificar** elimina la clase de errores `Unknown require` /
`Key '…' not found in external type`.

**Cómo se mide:** analizar el código de `T01-run1` y `T01-run2` con y sin sourcemap de Rojo,
contando errores por clase.

**Criterio de éxito:** la clase desaparece por completo (0 errores de esa clase).
**Criterio de falsación:** quedan errores de esa clase, o aparecen otros nuevos.

**Confianza previa: ALTA.** En FASE 2 ya observé 20 → 0 con un sourcemap **escrito a mano por
mí**. H1 verifica principalmente que **Rojo genera lo mismo que escribí a mano** — es decir, que
mis números de FASE 2 no dependían de un sourcemap hecho a medida.

---

### H2 — Iteraciones

**Predicción:** dar al agente Rojo + sourcemap reduce las iteraciones respecto a las **25** de
`T01-run2`.

**Cómo se mide:** ejecutar T-01 una vez con la configuración de FASE 3 y comparar `num_turns`.

**Confianza previa: BAJA.** Lo digo antes de medir. Hay dos fuerzas opuestas:
- A favor: el agente deja de perseguir errores irresolubles.
- **En contra: Rojo añade trabajo** — instalar, escribir `default.project.json`, generar el
  sourcemap, regenerarlo al cambiar ficheros. Eso son pasos que run2 no tenía.

**Es perfectamente posible que H2 salga al revés y las iteraciones suban.** Si pasa, se reporta
tal cual.

#### Criterios de decisión, fijados ahora

| Resultado | Veredicto |
|---|---|
| ≤ 18 turnos | H2 **confirmada** (−28 % o más sobre 25) |
| 19 – 22 turnos | **Inconcluso a la baja** — dirección correcta, magnitud dentro de lo que podría ser ruido |
| 23 – 27 turnos | **Inconcluso** — indistinguible de run2 |
| ≥ 28 turnos | H2 **falsada** — Rojo empeora las iteraciones |

---

## Limitación que invalida cualquier conclusión fuerte: **n = 1**

Cada ejecución de T-01 es **una muestra de un proceso estocástico**. Tengo dos puntos:
`run1 = 11` turnos, `run2 = 25`. **No tengo ninguna estimación de la varianza.**

Eso significa que **no puedo distinguir un efecto real de la variabilidad entre ejecuciones**.
La diferencia 11 → 25 de FASE 2 podría ser en parte ruido, y lo mismo valdrá para FASE 3.

**Compromiso:** ningún resultado de H2 se presentará como demostrado. Se presentará como
*una observación de una sola ejecución*, con la banda de decisión de arriba, y diciendo
explícitamente qué haría falta para convertirlo en evidencia: **3–5 ejecuciones por
configuración**, a ~1,2 USD cada una.

## Lo que NO se hace en esta fase

- No se modifica el código de `T01-run1` ni `T01-run2`: son evidencia congelada.
- No se toca `~/.claude`.
- No se instala nada de FASE 4 en adelante (memoria, research, testing, MCP del motor).
- No se ajusta el prompt de T-01. Sigue congelado en `fase-0-baseline/TAREA-PATRON.md`.

## Variable que cambia respecto a FASE 2

**Sólo una:** el `CLAUDE.md` del directorio de ejecución pasa de mencionar `luau-lsp` a
mencionar `luau-lsp` **+ Rojo/sourcemap**. La herramienta `rojo` estará en el `PATH`.

Es el mismo tipo de cambio de dos variables que ya declaré en FASE 2 (herramienta + saber que
existe), por la misma razón: una herramienta que el agente ignora vale cero.
