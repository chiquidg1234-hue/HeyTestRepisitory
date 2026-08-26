# FASE 2 — Code intelligence (`luau-lsp`)

**Fecha:** 25-08-2026 · **Estado:** COMPLETADA · **No se avanzó a FASE 3.**
**Criterio de la fase:** el agente encuentra referencias sin leer ficheros enteros y la tarea
patrón baja en tokens o en iteraciones. → **CUMPLIDO A MEDIAS. Ver "El resultado incómodo".**

---

## El resultado en una línea

**El código del baseline tenía 10 errores de tipo que nadie podía detectar. Con `luau-lsp`, la
misma tarea sale con 0 errores — a cambio de un 24 % más de coste.**

| | FASE 0 (sin herramientas) | FASE 2 (con `luau-lsp`) |
|---|---|---|
| **Errores de tipo en el código entregado** | **10** | **0** ✅ |
| Verificación automática posible | **0 / 2** | **1 / 2** |
| Iteraciones | 11 | **25** (+127 %) |
| Tokens totales | 934 029 | **2 077 499** (+122 %) |
| Coste | 0,9739 USD | **1,2144 USD** (+24,3 %) |
| Tiempo de API | 479,1 s | 482,7 s (+0,8 %) |
| Contexto de arranque | 34 830 | **34 964 (idéntico a FASE 1)** |

Ambos análisis se hicieron en igualdad de condiciones: con `--sourcemap` y las definiciones de
tipos de Roblox. La evidencia bruta está en `evidencia/`.

---

## Lo que encontró en el código del baseline

`luau-lsp analyze` sobre los 1 104 lines que produjo FASE 0, **con sourcemap**, devolvió
`exit 1` y **10 errores**. Deduplicados, son **5 defectos reales** en 3 ficheros:

| # | Fichero | Defecto |
|---|---|---|
| 1 | `ProfileStore.luau(82)` | `return nil` donde el tipo declarado no admite `nil`. La anotación de retorno está mal |
| 2 | `ProfileStore.luau(120)` | Devuelve una tabla donde el tipo dice `nil` |
| 3 | `ProfileStore.luau(151)` | Ídem |
| 4 | `init.server.luau(38, 52, 94)` | **El más grave.** El tipo `ProfileStoreInstance` se declaró como `{ _dataStore: DataStore, _sessionId: string }` — **sin sus propios métodos**. Al llamar a `Load` y `ReleaseLock` el tipo no cuadra. Autocompletado incorrecto y errores enmascarados |
| 5 | `tests/InventoryCore.spec.luau(189)` | **El fichero de tests tiene un error de tipos.** El baseline entregó una suite que ni siquiera se comprueba a sí misma |

El nº 5 es el que mejor resume FASE 0: **el agente escribió el test que debía demostrar que su
código funciona, y el test estaba roto.** Sin herramienta, indetectable.

---

## El resultado incómodo: coste al alza, no a la baja

Mi criterio original decía *"la tarea patrón baja en tokens o en iteraciones"*. **No bajó:
subió un 122 % en tokens y un 127 % en iteraciones.** Lo digo sin adornos porque es lo que
midieron los números.

**Y aun así considero la fase un éxito**, por la razón que dejé escrita en el informe antes de
medir nada: *"una herramienta que gasta un 20 % más de tokens pero converge en 3 iteraciones en
vez de 8 es una ganancia, no una pérdida"*. Aquí es **+24 % de coste a cambio de pasar de 5
defectos reales a cero**. En un proyecto de meses, esos defectos se pagan mucho más caros que
0,24 USD.

Pero hay una causa concreta y evitable detrás de esa subida, y es el hallazgo más útil de la fase.

---

## Hallazgo principal: `luau-lsp` sin sourcemap genera ruido infalseable

El agente ejecutó `luau-lsp analyze` **siete veces** durante la tarea (verificado en el JSON del
runtime, junto a un `luau-lsp --version` inicial). Pero yo **no le di un sourcemap de Rojo**.

Sin sourcemap, `luau-lsp` no puede resolver `game.ReplicatedStorage.Shared.X` y emite errores
como:

```
TypeError: Unknown require: game/ReplicatedStorage/Shared/Inventory
TypeError: Key 'Shared' not found in external type 'ReplicatedStorage'
TypeError: Unknown type 'Inventory.ItemId'
```

**Esos errores son imposibles de arreglar tocando el código**, porque no son del código. La
prueba: el mismo código de run2 da **20 errores sin sourcemap y 0 con sourcemap**.

Es decir: **el agente pasó parte de sus 25 iteraciones persiguiendo fantasmas.**

### Consecuencia para el plan: el orden de las fases estaba mal

Mi plan ponía `luau-lsp` en FASE 2 y Rojo en FASE 6. **Los números dicen que eso es un error.**
El sourcemap lo genera Rojo (`rojo sourcemap`), así que:

> **Propuesta de corrección: adelantar Rojo a FASE 2, junto a `luau-lsp`.**
> Son una sola capacidad, no dos. Separarlos hace que la primera llegue coja.

**Hipótesis medible, aún no verificada:** con sourcemap, las iteraciones deberían bajar
sustancialmente respecto a las 25 de run2, posiblemente por debajo de las 11 del baseline. **No
lo he comprobado** — requeriría una tercera ejecución de T-01, y no quise gastarla sin tu visto
bueno. Es la primera medición que propongo para FASE 3.

---

## Coste en contexto: cero — y la trampa que casi me lo hace reportar mal

**El plugin LSP añade 0 tokens al contexto de arranque.** Medido con dos controles consecutivos
en la misma máquina:

| Control | `cache_creation` | `cache_read` | **Suma real** |
|---|---|---|---|
| FASE 1 (sin plugin, caché fría) | 34 964 | 0 | **34 964** |
| FASE 2 **con** plugin | 7 976 | 26 988 | **34 964** |
| FASE 2 **sin** plugin | 7 982 | 26 988 | **34 970** |

Diferencia con y sin plugin: **−6 tokens.** Ruido.

> ### ⚠️ Trampa de medición — apúntatela
> Mi primera lectura fue **`cache_creation` = 7 976 vs 34 830 → −77 % de contexto**. Habría sido
> un titular espectacular **y completamente falso**: la caché estaba caliente, así que el
> contexto no se creó, se leyó.
>
> **La métrica correcta es `cache_creation + cache_read`.** Si comparas sólo
> `cache_creation` entre fases, medirás la temperatura de la caché, no tu toolchain.

Esto confirma empíricamente el argumento del informe: **el LSP nativo no tiene el sobrecoste de
superficie de herramientas que sí tiene un servidor MCP** (a Serena la comunidad le estima ~24 k
tokens). Cero herramientas MCP cargadas, cero tokens.

---

## Instalación: lo que costó y por qué

**Las descargas de GitHub Releases siguen bloqueadas en este contenedor**, así que compilé
`luau-lsp` desde la fuente oficial. **Tú no tienes que hacer esto** — ver `entorno-local/WINDOWS-11.md`.

| Paso | Resultado |
|---|---|
| Clonar `JohnnyMorganz/luau-lsp` (commit `1808bef`, Luau 0.735 vendorizado) | 6 s |
| **Primer intento con g++ 13** | ❌ **FALLÓ** |
| Segundo intento con clang | ✅ 432 s, 0 fallos |
| Binario resultante | 11,9 MB · `luau-lsp 1.69.0` |

### El fallo de compilación, documentado

```
FAILED: CMakeFiles/Luau.LanguageServer.dir/src/operations/CallHierarchy.cpp.o
error: '...basic_string...' may be used uninitialized [-Werror=maybe-uninitialized]
```

Es un **falso positivo conocido de GCC 13** con `std::optional<std::string>` dentro de
`std::pair`, escalado a error por el `-Werror` del proyecto. **No es un bug de luau-lsp.**

Lo resolví cambiando de compilador (`-DCMAKE_CXX_COMPILER=clang++`) en lugar de parchear la
fuente ajena, que es la opción limpia: no modifico código de terceros que voy a ejecutar.

### Bonus: las definiciones de tipos de Roblox venían incluidas

`scripts/globalTypes.d.luau` está **commiteado en el repositorio de luau-lsp**: 837 KB, 19 728
líneas, con `DataStoreService`, `RemoteEvent` y el resto de la API. No hay que descargar nada de
la CDN de Roblox.

---

## Decisión de seguridad: el paquete npm `luau-lsp` NO se instaló

La ruta "obvia" habría sido `npm install -g luau-lsp`. **La descarté tras auditarla**, y merece
que lo sepas porque es una trampa fácil de pisar.

| Señal | Valor |
|---|---|
| Publicado | **2026-08-09 — 16 días de antigüedad** |
| Autor / mantenedor | `evilbocchi` — **no es JohnnyMorganz** |
| Repositorio | `Unreal-Works/luau-lsp-npm` — **no es el proyecto oficial** |
| Tamaño desempaquetado | **3 368 bytes** — es un envoltorio, no el servidor |
| Qué hace | `export * from "@unrealworks/rkkit-core"` y delega la resolución del binario en otro paquete del mismo autor |

Descargué el tarball y lo leí **sin instalarlo ni ejecutarlo**. **No afirmo que sea malicioso** —
puede ser perfectamente benigno y útil. Pero ocupa el nombre obvio en npm para una herramienta
que va a leer todo tu código fuente, y añade dos saltos de confianza innecesarios.

**Regla que aplico y te recomiendo: para un componente del toolchain, fuente oficial o nada.**

---

## Lo que quedó instalado y configurado

| Elemento | Ubicación | Reversible con |
|---|---|---|
| `luau-lsp` 1.69.0 | `~/.local/bin/luau-lsp` | `rm ~/.local/bin/luau-lsp` |
| Definiciones de tipos | `~/.local/share/luau-lsp/globalTypes.d.luau` | `rm -rf ~/.local/share/luau-lsp` |
| Envoltorio stdio | `~/.local/bin/luau-lsp-stdio` | `rm ~/.local/bin/luau-lsp-stdio` |
| Plugin LSP | `fase-2-code-intelligence/luau-lsp-plugin/` (en el repo) | `git rm -r` |

**`~/.claude` sigue sin tocarse.** El plugin se probó con `--plugin-dir`, que no persiste nada.
Para uso diario en tu máquina hay que instalarlo de verdad — instrucciones abajo.

### El plugin LSP: esquema verificado

Claude Code arranca automáticamente los servidores LSP de los plugins instalados. El esquema lo
verifiqué contra `boostvolt/claude-code-lsps`:

```json
// .lsp.json
{ "luau": { "command": "luau-lsp-stdio",
            "extensionToLanguage": { ".luau": "luau", ".lua": "luau" } } }
```

**Por qué hace falta el envoltorio:** Claude Code invoca el comando **sin argumentos**, pero
`luau-lsp` necesita el subcomando `lsp`. El envoltorio es una línea: `exec luau-lsp lsp "$@"`.

Comprobado que el servidor responde JSON-RPC por stdio. **Limitación honesta:** hice un
*handshake* mínimo que confirma que habla LSP, pero **no verifiqué las nueve operaciones**
(`goToDefinition`, `findReferences`, etc.) desde dentro de una sesión de Claude Code, porque
`ENABLE_LSP_TOOL` requiere configuración persistente en `~/.claude`, que acordamos no tocar.

---

---

## Incidente durante esta fase: la puerta de FASE 1 bloqueó mi propio commit

Al intentar commitear FASE 2, `gitleaks` detectó la clave AWS de ejemplo que puse en
`entorno-local/WINDOWS-11.md`. **La puerta funcionó.**

Al resolverlo cometí un error de configuración que **desactivó la puerta entera**, y al
investigarlo descubrí que la validación de FASE 1 estaba sobredimensionada: gitleaks **no detecta
todas las claves AWS sintácticamente válidas**.

Ambas cosas están documentadas en **[../fase-1-seguridad/CORRECCION.md](../fase-1-seguridad/CORRECCION.md)**.

## CHECKPOINT — estado al cerrar FASE 2

| | FASE 0 | FASE 1 | **FASE 2** |
|---|---|---|---|
| Contexto de arranque (cc+cr) | 34 830 | 34 964 | **34 964** |
| **Verificación automática de Luau** | 0 / 2 | 0 / 2 | **1 / 2** ✅ |
| Errores de tipo en T-01 entregado | 10 (invisibles) | — | **0** ✅ |
| Puerta de secretos | — | activa | activa |
| Herramientas instaladas | 0 | 3 | **4** |
| MCP configurados | 0 | 0 | **0** |
| Plugins persistentes en `~/.claude` | 0 | 0 | **0** |

**Falta 1/2 de verificación: ejecutar los tests.** Eso es Lune o Lute, y está en FASE 5.

---

## Limitaciones y elementos NO verificados

1. **El plugin LSP no se probó dentro de una sesión interactiva de Claude Code.** Sólo el
   handshake stdio. Requiere `ENABLE_LSP_TOOL` y `~/.claude` intacto.
2. **La hipótesis del sourcemap no está medida.** Predigo menos iteraciones con Rojo; no lo he
   comprobado.
3. **Compilado con clang, no con la release oficial.** El binario debería ser equivalente, pero
   no es bit-a-bit el que descargarías tú.
4. **Sigue siendo un contenedor efímero.** Todo esto muere con la sesión.
5. **La comparación T-01 cambia dos variables a la vez**: la herramienta *y* un `CLAUDE.md` que
   le dice al agente que la use. Lo hice a propósito —una herramienta que el agente no sabe que
   existe vale cero— pero es un cambio de dos variables y debe constar.

## Lo que necesitas hacer tú

1. Instalar `luau-lsp` en Windows con Rokit (ver `entorno-local/WINDOWS-11.md`).
2. Decidir sobre la **propuesta de adelantar Rojo a FASE 3**, antes que memoria.
3. Si quieres el plugin LSP permanente: copiarlo a `~/.claude/plugins/` y activar
   `ENABLE_LSP_TOOL` en tu `settings.json`. **Eso sí toca `~/.claude`; no lo hago sin tu permiso.**
