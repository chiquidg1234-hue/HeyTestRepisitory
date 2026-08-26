# FASE 5 — Testing y puertas de verificación

**Fecha:** 26-08-2026 · **Estado:** **COMPLETADA**
**Criterio:** *«el agente ya no puede cerrar un turno con el build roto»* → **demostrado con caso válido y caso inválido para los cinco componentes.**

## Resultado que importa

> **Verificación automática: 1/2 → 2/2.** Por primera vez se pueden comprobar los tipos **y**
> ejecutar los tests. La deuda que arrastraba desde FASE 0 queda saldada.

## Los cinco componentes, cada uno con prueba positiva y negativa

| # | Componente | Versión | Caso válido | Caso inválido | Evidencia |
|---|---|---|---|---|---|
| 1 | **selene** | 0.31.0 | `exit 0`, 0 errores | Variable global prohibida → **`exit 1`** | ejecución real |
| 2 | **StyLua** | 2.5.2 **+ feature `luau`** | `exit 0` | Formato roto → **`exit 1`** con diff | ejecución real |
| 3 | **Hook `PostToolUse`** | propio | src y tests válidos → **`exit 0`** | Error de tipos → **`exit 2`** con el mensaje exacto | 5 invocaciones |
| 4 | **Lune + runner propio** | 0.10.5 | 4 tests → **`exit 0`** | Bug inyectado → **3/1, `exit 1`** con el valor esperado y el obtenido | ejecución real |
| 5 | **Hook `Stop`** | propio | Proyecto limpio → **`exit 0`** | Tests rotos → **`exit 2`** · Error de tipos → **`exit 2`** | 4 invocaciones |

**Ninguna de estas líneas es una mención en un mensaje.** Todas son ejecuciones con código de
salida observado — la lección de la corrección de FASE 2 aplicada.

## Tres defectos de integración encontrados y corregidos

Ninguno estaba documentado en el sitio obvio. Los tres los encontró el testing negativo.

### 1. `cargo install stylua` produce un binario que **no parsea Luau**

```
error: could not format file src/Contador.luau: error parsing:
 - unexpected token `type` (6:8 to 6:12)
 - unexpected token `number` (12:57), expected arguments after `:`
```

`--syntax All` **tampoco** lo arregla: las únicas opciones son `All` y `Lua51`, y ninguna activa
Luau. **La solución es una feature de compilación:**

```bash
cargo install stylua --locked --features luau
```

Tras reinstalar: `exit 0` sobre el mismo fichero. **Sin esa feature, StyLua rechaza todo tu
código tipado** y el hook produce falsos positivos permanentes.

### 2. `require` dinámico en Lune necesita la ruta **sin extensión**

`require("./Contador.spec.luau")` → `could not resolve child component`.
`require("./Contador.spec")` → funciona. El runner hace el `gsub` para quitar `.luau`.

### 3. Los tests **no se pueden analizar con `luau-lsp`**

Los tests usan `require("@lune/fs")`, un alias que `luau-lsp` no resuelve:

```
TypeError: Unknown require: …/tests/@lune/fs.lua
```

Quitar `--platform=roblox` **no basta**. La solución correcta, y es una decisión de diseño:

> **Para los ficheros de test, la verificación de tipos NO aplica. Su comprobación es
> ejecutarlos.** El hook `PostToolUse` les pasa lint y formato pero salta el análisis de tipos;
> el hook `Stop` los ejecuta con Lune.

Esto cierra correctamente el requisito que dejé anotado en FASE 3 (`src/` y `tests/` por separado).

## El runner propio: 40 líneas en vez de una dependencia muerta

En la investigación medí que **todos** los frameworks de test de Luau están abandonados: TestEZ
1 302 días, jest-lua 609, EzSpec 1 738, tiniest 415. El runner
([`proyecto-demo/tests/run.luau`](proyecto-demo/tests/run.luau)) descubre `*.spec.luau`, los
ejecuta con `pcall`, imprime `[OK]`/`[FAIL]` y sale con `process.exit(1)` si algo falla.

Salida real con un bug inyectado:

```
3 pasados, 1 fallos
  ! Contador.spec.luau :: incrementa dentro del máximo -> assert: se esperaba 4, se obtuvo 8
```

## Limitación medida: `selene` sin el std de Roblox

`selene generate-roblox-std` **falla en este contenedor**: necesita descargar el volcado de la
API de Roblox y la red está restringida. Se usó `std = "luau"` como reserva.

**Consecuencia:** selene detecta globales indefinidas y errores de estilo, pero **no conoce los
tipos de la API de Roblox**. En tu máquina Windows ejecuta `selene generate-roblox-std` una vez
dentro del proyecto para obtener la cobertura completa. Marcado como **NO VERIFICADO aquí**.

## Cómo se cablea (fragmento listo para copiar)

[`config/settings-fragmento.json`](config/settings-fragmento.json) → va en `.claude/settings.json`
del proyecto. Los scripts van en `.claude/hooks/`.

**Importante:** el hook `PostToolUse` sólo verifica **el fichero que se acaba de tocar** (rápido,
milisegundos). El hook `Stop` verifica **el proyecto entero** (tipos de `src/` + ejecución de
tests). Esa división es deliberada: feedback inmediato barato, puerta final completa.

## CHECKPOINT

| Campo | Valor |
|---|---|
| **Fase** | 5 — Testing |
| **Estado** | **COMPLETADA** |
| **Herramientas nuevas** | selene 0.31.0 · StyLua 2.5.2 (+luau) · Lune 0.10.5 · 2 hooks propios · runner propio |
| **Pruebas reales** | 5 componentes × (caso válido + caso inválido) = **14 ejecuciones con exit code observado** |
| **Métrica clave** | **Verificación automática 1/2 → 2/2** |
| **Limitaciones** | `selene` sin std de Roblox (red); hooks probados por invocación directa, no dentro de una sesión interactiva |
| **Pendiente de humano** | `selene generate-roblox-std` en Windows; copiar hooks a `.claude/` del proyecto real |
| **Siguiente paso** | FASE 6 — tooling del motor (Studio MCP y UEFN MCP: ambos requieren GUI y autorización humana) |
