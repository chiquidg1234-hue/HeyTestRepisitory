# AUDITORÍA FINAL DEL STACK

Fecha: 2026-08-27 · Rama: `claude/github-intelligence-research-0dnet7`
Cierra el plan que empezó en la MISIÓN 1 y terminó con la evaluación de Serena (FASE 8).

---

## 1. Serena — veredicto

**POSPONER.** Detalle completo y evidencia en [`fase-8-serena/FASE-8-SERENA.md`](fase-8-serena/FASE-8-SERENA.md).

Resumen en una línea: de 21 herramientas expuestas, el agente ejecutó **1**
(`initial_instructions`) y **0 simbólicas**; el coste subió +62,5 % y el beneficio medido fue 0.
Además, el motor de Luau de Serena **es el mismo `luau-lsp` que ya está instalado**, así que no
puede detectar nada que el stack actual no detecte.

## 2. Estado del stack, componente a componente

Leyenda: **FUNCIONA Y VERIFICADO** = lo ejecuté y observé el resultado ·
**PARCIAL** = funciona con una limitación medida · **BLOQUEADO** = requiere algo que no puedo
hacer yo · **NO NECESARIO** = evaluado y descartado.

### Núcleo de código Luau

| Componente | Estado | Evidencia |
|---|---|---|
| `luau-lsp` 1.69.0 (compilado con clang) | **FUNCIONA Y VERIFICADO** | Encuentra 10 errores reales que el baseline entregó; `analyze` limpio en `src/` de run3b y run4 |
| `rojo` 7.7.0 + sourcemap | **FUNCIONA Y VERIFICADO** | Sourcemap generado idéntico al escrito a mano; H1 del pre-registro confirmada |
| `lune` 0.10.5 + runner propio | **FUNCIONA Y VERIFICADO** | 14 ejecuciones con código de salida observado; detecta bugs plantados |
| `stylua` 2.5.2 **con feature `luau`** | **FUNCIONA Y VERIFICADO** | Sin esa feature el binario no parsea Luau — trampa documentada |
| `selene` 0.31.0 | **PARCIAL** | Falta `generate-roblox-std` (requiere red desde tu máquina). Sin el std de Roblox, los avisos globales son ruido |

### Seguridad

| Componente | Estado | Evidencia |
|---|---|---|
| `pre-commit` 4.6.2 | **FUNCIONA Y VERIFICADO** | Bloqueó dos commits míos de verdad |
| `gitleaks` 8.30.1 | **PARCIAL — y es importante** | Detecta 1 de 3 claves AWS válidas de prueba. Ver `fase-1-seguridad/CORRECCION.md` |
| `osv-scanner` 2.5.1 | **BLOQUEADO aquí / verificado por ti** | `api.osv.dev` inalcanzable desde este contenedor; tú lo probaste con `lodash` en local |
| Sandbox `srt` | **NO NECESARIO por ahora** | Inerte aquí (sin user namespaces anidados). Sustituto decidido: WSL2, más adelante |

### Motor de juego

| Componente | Estado | Evidencia |
|---|---|---|
| Roblox Studio MCP (ciclo implementar→probar→observar→corregir) | **FUNCIONA Y VERIFICADO — evidencia externa** | Ejecutado **por ti** desde PowerShell en Windows 11, place "CONSEGUE EL HUEVO", 4/4 casillas. No es ejecución de esta sesión |
| Open Cloud Luau Execution API | **PREPARADO, BLOQUEADO** | `fase-7-autonomia/scripts/open_cloud_luau.py` falla limpio sin clave; falta que tú crees la clave |
| UEFN Unreal MCP | **BLOQUEADO** | Requiere Beta Access en Project Settings. Único bloqueo de motor que queda |

### Research y contexto

| Componente | Estado | Evidencia |
|---|---|---|
| Corpus local `creator-docs` | **FUNCIONA Y VERIFICADO** | 7/8 preguntas respondidas, 10 ms frente a 435 ms por web |
| Regla "local antes que web" en `CLAUDE.md` | **FUNCIONA Y VERIFICADO** | `reglas/CLAUDE-fragmento-research.md` |
| Hooks `PostToolUse` + `Stop` | **FUNCIONA Y VERIFICADO** | Verificación pasó de 0/2 a 2/2 |

### Descartado tras evaluarlo

| Componente | Motivo |
|---|---|
| Paquete npm `luau-lsp` | **No es oficial.** 16 días de vida, autor `evilbocchi`, shim de 3,4 KB. Rechazado por procedencia |
| Serena | Ver §1. Pospuesto, no descartado |
| Spec Kit (`specify` 1.0.1) | **PARCIAL / no justificado**. La integración con Claude Code no está verificada y el flujo de spec ya lo cubre `CLAUDE.md` + la TAREA-PATRON |

## 3. Estado real por fase

| Fase | Estado | Lo que queda |
|---|---|---|
| 0 · Baseline | **CERRADA** | Nada. Congelada como referencia |
| 1 · Seguridad | **CERRADA con limitación conocida** | Asumir que gitleaks no es una red completa ⇒ la clave de Open Cloud **nunca** toca un fichero |
| 2 · Code intelligence | **CERRADA con corrección** | Nada. La atribución causal falsa quedó corregida y documentada |
| 3 · Rojo | **CERRADA** | H1 confirmada, H2 refutada. No se repite |
| 4 · Research | **CERRADA** | Nada |
| 5 · Testing | **CERRADA** | Copiar `fase-5-testing/hooks/` al proyecto real (acción tuya) |
| 6 · Motor | **CERRADA para Roblox · BLOQUEADA para UEFN** | Beta Access de UEFN |
| 7 · Autonomía | **PARCIAL** | Clave de Open Cloud en GitHub Secrets |
| 8 · Serena | **CERRADA — POSPUESTA** | Re-evaluar solo si aparece un proyecto de ≥50 ficheros |

## 4. Bloqueos reales (solo los que exigen intervención humana)

1. **UEFN Beta Access.** Project Settings → Beta Access → UEFN MCP Toolset. Sin esto, todo el
   lado UEFN del plan está parado. Es el único bloqueo de capacidad, no de comodidad.
2. **Clave de Open Cloud**, acotada al universo de **desarrollo**, guardada en GitHub Secrets y
   nunca en un fichero. Desbloquea la ejecución de Luau en servidor real desde CI.
3. **`selene generate-roblox-std`** ejecutado dentro de tu proyecto, con red. Hasta entonces el
   lint de Roblox produce falsos positivos globales.
4. **Borrar `BugTestScript`** del place de prueba. No puedo: no hay Studio en Linux.

## 5. Lo que de verdad falta (máximo 5, priorizado)

1. **Llevar el stack al proyecto Roblox real.** Todo lo verificado vive en un proyecto de
   prueba de 8 ficheros. Copiar `fase-5-testing/hooks/` a `.claude/hooks/`, el
   `default.project.json`, el `rokit.toml` de `fase-6-motor/config/` y el fragmento de
   `CLAUDE.md`. **Esto es lo que convierte el trabajo en capacidad usable.**
2. **Desbloquear UEFN** (Beta Access). Es la mitad del objetivo de la MISIÓN 2 y está a cero.
3. **Cerrar Open Cloud** con la clave acotada, para que CI pueda ejecutar Luau en servidor.
4. **Arreglar el lint**: `selene generate-roblox-std` + decidir qué avisos son obligatorios.
5. **Presupuesto por tarea, no por sesión.** Esta sesión gastó ~12,5 USD contra un tope de 5,
   y el 85 % fue relectura de un contexto enorme, no experimentos. La regla operativa que
   sale de aquí: los experimentos caros van en subproceso `claude -p` (medibles, aislados,
   ~1,9 USD cada uno) y la conversación principal se corta antes de crecer.

## 6. Lista de NO HACER

- **No repetir T-01.** Hay cuatro ejecuciones (run1, run2, run3a/b, run4) y ya sabemos lo que
  enseñan. Otra ronda cuesta ~2 USD y no cambia ninguna decisión.
- **No instalar Serena de forma permanente** ni registrarla en `~/.claude` ni en `.mcp.json`.
  Sigue viviendo en un venv efímero, y así se queda hasta que haya un proyecto grande.
- **No añadir MCPs "por si acaso".** El stack tiene 0 MCP configurados de forma permanente y
  el contexto de arranque solo subió +0,38 % en todo el proyecto. Eso es un logro, no un hueco.
- **No tocar la evidencia congelada**: `fase-0-baseline/T01-run1-salida/`,
  `fase-2-code-intelligence/T01-run2-salida/`, `fase-3-rojo/T01-run3{a,b}-salida/`,
  `fase-8-serena/T01-run4-salida/`, ni `fase-0-baseline/TAREA-PATRON.md`.
- **No volver a usar `print(2 + "2")` como bug de prueba.** Luau coerciona cadenas numéricas y
  no da error. El bug válido es `print(2 + {})`.
- **No presentar la evidencia de FASE 6 como ejecución de esta sesión.** Vino de tu Claude Code
  en PowerShell sobre Windows 11.
- **No inventar ejecuciones.** Una mención textual del nombre de una herramienta no demuestra
  que se ejecutó. Se comprueba en el transcript, contando bloques `tool_use`.
- **No desactivar gitleaks, no usar `--no-verify`, no pedir credenciales, no escribir secretos.**
- **No seguir gastando presupuesto solo por seguir trabajando.**
