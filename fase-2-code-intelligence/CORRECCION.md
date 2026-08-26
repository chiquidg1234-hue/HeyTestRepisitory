# Corrección a FASE 2 — la atribución causal era falsa

**Fecha:** 26-08-2026, al comenzar FASE 3.
**Descubierto por:** inspección del transcript real de `T01-run2`, que en FASE 2 no llegué a abrir.

---

## Lo que dije y no se sostiene

> *"El código del baseline tenía 10 errores de tipo indetectables. **Con `luau-lsp` la misma
> tarea sale con 0 errores**, a cambio de +24 % de coste y +127 % de iteraciones."*
>
> *"El agente ejecutó `luau-lsp analyze` siete veces durante la tarea."*
>
> *"El agente pasó parte de sus 25 iteraciones persiguiendo fantasmas."*

**Las tres afirmaciones son falsas.**

## La evidencia

El transcript de `T01-run2` (`~/.claude/projects/…-T01-run2/*.jsonl`, 320 KB) dice:

| Medición | Valor |
|---|---|
| Ejecuciones de `luau-lsp analyze` **completadas** | **0** |
| Intentos **bloqueados por permisos** | **3** |
| Bloqueos de permisos totales en run2 | **6** |
| Bloqueos de permisos totales en run1 | **0** |
| Menciones de `TypeError` en todo el transcript | **0** |
| Menciones de `Unknown require` | **0** |

Los mensajes que recibió el agente:

```
ls in '/root/.local/share/luau-lsp' was blocked. For security, Claude Code may only
list files in the allowed working directories for this session: '…/T01-run2'.

This Bash command contains multiple operations. The following parts require approval:
luau-lsp analyze --platform=roblox --defs=/root/.local/share/luau-lsp/globalTypes.d.luau …

Claude requested permissions to read from /root/.local/share/luau-lsp/globalTypes.d.luau,
but you haven't granted it yet.

cp in '/root/.local/share/luau-lsp/globalTypes.d.luau' was blocked.
```

**Lo que conté como 7 invocaciones de `analyze` eran 7 apariciones del texto del comando en
mensajes de denegación.** Conté menciones en el JSON de resultado, no ejecuciones. Error de
método por mi parte: medí una cadena de texto, no un hecho.

## Qué pasó realmente en run2

El agente **escribió el código sin verificarlo nunca**, igual que run1. Las 25 iteraciones no
fueron trabajo de verificación: fueron **el agente peleándose con el sistema de permisos** —
intentando leer `globalTypes.d.luau`, que está fuera del directorio de trabajo permitido, y
recibiendo denegaciones una y otra vez.

Que el código de run2 saliera con 0 errores de tipo **no lo causó `luau-lsp`**. Salió limpio y
punto. Con n=1 no puedo distinguir eso de la variabilidad entre ejecuciones.

---

## Qué sobrevive de FASE 2 y qué no

| Afirmación | Estado |
|---|---|
| `luau-lsp` encuentra **10 errores de tipo reales** en el código de FASE 0 | ✅ **Sostiene.** Lo verifiqué yo, es reproducible desde la evidencia commiteada |
| Los 5 defectos concretos (tipo sin métodos, test roto, etc.) | ✅ **Sostiene** |
| El plugin LSP añade **0 tokens** de contexto | ✅ **Sostiene.** Dos controles independientes |
| La trampa de `cache_creation` vs `cache_creation + cache_read` | ✅ **Sostiene** |
| Sin sourcemap: 20 errores; con sourcemap: 0, sobre el mismo código | ✅ **Sostiene.** Medido por mí |
| El paquete npm `luau-lsp` no es el oficial | ✅ **Sostiene** |
| **«Con `luau-lsp` la tarea sale con 0 errores»** | ❌ **FALSO.** El agente nunca ejecutó la herramienta |
| **«+24 % de coste compra 5 defectos → 0»** | ❌ **FALSO.** El coste extra fue de denegaciones de permisos |
| **«El agente persiguió errores fantasma»** | ❌ **FALSO.** Persiguió permisos |
| **«Verificación automática: 1/2»** | ⚠️ **Matizado.** *Yo* puedo verificar. **El agente no podía** |

---

## El hallazgo que sale de este error, y vale más que el resultado que creí tener

> **Instalar una herramienta no es darle la herramienta al agente.**

En run2 la herramienta estaba instalada, en el `PATH`, y el `CLAUDE.md` le decía que la usara.
**Y aun así el agente no pudo ejecutarla ni una sola vez**, por dos motivos que ninguna guía de
instalación menciona:

1. **`--permission-mode acceptEdits` permite editar ficheros, no ejecutar Bash arbitrario.** Cada
   `luau-lsp analyze` pedía aprobación que nadie podía dar en modo no interactivo.
2. **El directorio de trabajo acota las lecturas.** `globalTypes.d.luau` vivía en
   `~/.local/share/`, fuera del proyecto. Todo intento de leerlo o copiarlo fue bloqueado.

**Consecuencia para el diseño del stack:** cualquier herramienta de verificación tiene que
cumplir dos requisitos que hay que comprobar explícitamente:

- **Sus datos viven dentro del proyecto** (las definiciones de tipos se copian al repo, no se
  referencian desde el home).
- **Sus comandos están pre-aprobados** en la configuración de permisos.

Esto adelanta trabajo que yo había puesto en fases posteriores y **debe verificarse en cada
fase que instale una herramienta ejecutable**, con una comprobación explícita:
*¿el agente consiguió ejecutarla?* — mirando el transcript, no el resumen.

## Efecto sobre FASE 3

El pre-registro fijaba las bandas de H2 contra **25 turnos de run2**. Ese número ya no
representa "luau-lsp funcionando": representa una configuración rota.

**Enmienda al pre-registro** (declarada ahora, antes de ejecutar): el punto de comparación
válido de H2 pasa a ser **run1 = 11 turnos, sin herramientas**. Las bandas originales contra 25
se conservan en el pre-registro como registro histórico, pero **no se usarán para el veredicto**.
