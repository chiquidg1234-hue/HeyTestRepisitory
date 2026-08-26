# El ciclo que debes ejecutar tú (no pude aquí)

**Usa un place NUEVO y desechable. Nunca el bueno.**

## Roblox — implementar → playtest → leer consola → corregir

1. Studio → Assistant → **…** → Manage MCP Servers → *Enable Studio as MCP server*.
2. Quick connect → **Claude Code**. Verifica el indicador verde.
3. En Claude Code, comprueba que las herramientas existen: `/mcp`.
4. **Prueba del ciclo completo**, con un bug plantado a propósito:

```
Crea un Script en ServerScriptService que imprima la suma de 2 y 2,
pero escribe deliberadamente `print(2 + "2")`.
Luego: inicia playtest, lee la consola, corrige el error y vuelve a probar.
```

**Evidencia que demuestra el ciclo** (las cuatro, o no cuenta):
- [ ] `execute_luau` o `multi_edit` escribió el script
- [ ] `start_stop_play` arrancó la partida
- [ ] `get_console_output` devolvió el error real
- [ ] El agente corrigió y volvió a probar **sin que se lo pidieras**

## UEFN — pendiente de Beta Access

1. Project Settings → **Beta Access** → activar **UEFN MCP Toolset**. ← acción humana
2. Conectar Claude Code por configuración MCP.
3. Ciclo equivalente: escribir Verse → compilar → leer el output log → corregir.

**Recuerda:** el toolset de UEFN se lanzó el 20-08-2026. Trátalo como beta.
