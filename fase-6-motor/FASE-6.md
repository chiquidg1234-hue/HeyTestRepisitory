# FASE 6 — Tooling del motor

**Fecha:** 26-08-2026 · **Estado:** **COMPLETADA (Roblox)** / **BLOQUEADA (UEFN)**

> **Actualización:** el ciclo del motor **se ejecutó con éxito** en Windows 11 + Claude Code +
> Roblox Studio MCP. Ver [`CICLO-A-VERIFICAR.md`](CICLO-A-VERIFICAR.md) con las 4 casillas marcadas.
> Lo que sigue describe por qué **este contenedor Linux** no podía hacerlo — la limitación era del
> entorno de la sesión, no del stack.

## Por qué está bloqueada (verificado, no supuesto)

| Comprobación | Resultado |
|---|---|
| SO del contenedor | **Linux**, sin GUI (`DISPLAY` vacío) |
| `/Applications/RobloxStudio.app` | NO existe |
| Binario `RobloxStudio` en PATH | NO |
| Roblox Studio para Linux | **No se distribuye** |
| UEFN | **Exclusivo de Windows** |
| Rokit | Descarga binarios de GitHub Releases → **403 por el proxy** (verificado en FASE 1) |

**El servidor MCP de Studio vive DENTRO de Roblox Studio.** Sin Studio no hay servidor, y sin
GUI no hay Studio. No es una limitación de permisos que se pueda sortear: es ausencia de la
aplicación.

~~**No declaro este criterio cumplido.**~~ → **Superado:** el ciclo *implementar → playtest →
leer consola → corregir* **sí se ha demostrado**, ejecutado por el usuario en su máquina Windows.
La evidencia es de clase «reportada por el usuario», no medida por mí en esta sesión.

## Lo que sí se ha preparado

| Entregable | Qué es |
|---|---|
| [`config/rokit.toml`](config/rokit.toml) | Manifiesto con las **5 versiones exactas verificadas** en esta sesión: Rojo 7.7.0, luau-lsp 1.69.0, selene 0.31.0, StyLua 2.5.2, Lune 0.10.5 |
| [`config/mcp-studio.json`](config/mcp-studio.json) | Configuración MCP para Windows, copiada de la documentación oficial de Roblox |
| [`CICLO-A-VERIFICAR.md`](CICLO-A-VERIFICAR.md) | El experimento exacto, con bug plantado y cuatro casillas de evidencia |

**Nota sobre `rokit.toml`:** es más valioso de lo que parece. Fija las versiones que **han
funcionado juntas y están verificadas**, incluida la trampa de StyLua — aunque `rokit` instala
binarios de release, que ya vienen con Luau activado, así que ahí el problema no aplica.

**Rojo NO se reinstala.** Ya quedó validado en FASE 3 como fuente correcta de sourcemaps.

## Pendiente de intervención humana

1. Instalar Rokit en Windows y ejecutar `rokit install` con el manifiesto.
2. Activar el MCP en Studio y hacer quick-connect a Claude Code.
3. **Ejecutar el ciclo de `CICLO-A-VERIFICAR.md` en un place desechable** y marcar las 4 casillas.
4. UEFN: activar **Beta Access → UEFN MCP Toolset**. *No lo he intentado automáticamente: requiere
   autorización humana explícita.*

## CHECKPOINT

| Campo | Valor |
|---|---|
| **Fase** | 6 — Tooling del motor |
| **Estado** | **BLOQUEADA** (preparación completa, verificación imposible) |
| **Herramientas nuevas** | ninguna |
| **Pruebas reales** | Bloqueo verificado por inspección del sistema. **Cero pruebas del ciclo** |
| **Limitaciones** | Studio y UEFN no existen para Linux; Rokit bloqueado por el proxy |
| **Pendiente de humano** | Las 4 acciones de arriba |
| **Siguiente paso** | FASE 7 — Open Cloud (andamiaje sin credenciales), Spec Kit, srt |
