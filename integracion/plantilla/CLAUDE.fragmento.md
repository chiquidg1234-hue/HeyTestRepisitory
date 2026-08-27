<!-- ─────────────────────────────────────────────────────────────────────────
     Fragmento para el CLAUDE.md del proyecto Roblox.
     Pégalo tal cual. Todo lo que hay aquí está medido, no supuesto.
     ───────────────────────────────────────────────────────────────────── -->

## Verificación obligatoria antes de dar algo por terminado

Este proyecto tiene una puerta automática. No la esquives.

```bash
rojo sourcemap default.project.json --output sourcemap.json   # SIEMPRE primero
./verificar.sh                                                # tipos + lint + formato + tests
```

**El sourcemap no es opcional.** Sin él, `luau-lsp` no resuelve
`require(ReplicatedStorage.Modulos.X)` y responde `Unknown require`, de modo que
un error de tipos entre módulos pasa desapercibido. Comprobado con control: con
sourcemap el error se detecta en la línea exacta; sin sourcemap no se detecta
ninguno porque ni siquiera resuelve el módulo.

Si añades una carpeta nueva a `default.project.json`, **crea al menos un fichero
dentro antes de generar el sourcemap**: Rojo omite del sourcemap las ramas cuyo
`$path` apunta a un directorio vacío, y esa parte del juego deja de verificarse
sin avisar.

## El código del juego y los tests se verifican de forma DISTINTA

| | Dónde se ejecuta | Cómo se verifica |
|---|---|---|
| Código del juego | Motor de Roblox | `luau-lsp analyze --platform=roblox --defs=globalTypes.d.luau --sourcemap=sourcemap.json` |
| `tests/*.spec.luau` | Lune (headless) | `luau-lsp analyze --platform=standard`, con el alias `@lune` de `tests/.luaurc` |

Nunca analices los tests con las definiciones de Roblox, ni el código del juego
sin ellas. Son dos entornos distintos y mezclarlos produce errores falsos en
ambos sentidos.

## Símbolos: comprobar antes de usar

**`os.exit` NO existe en Roblox** — la biblioteca `os` sólo tiene `os.clock`,
`os.date`, `os.difftime` y `os.time`.

**`os.exit` tampoco existe en Lune.** En los tests el corte es:

```lua
local process = require("@lune/process")
process.exit(1)
```

Esto no es teórico: una versión anterior de estos tests usaba `os.exit(0)` al
final, pasaba las 27 comprobaciones y luego reventaba con
`attempt to call a nil value`, así que la suite **nunca podía dar verde**.

Antes de usar cualquier función de una biblioteca Luau, compruébala en la
documentación local (ver abajo).

## Documentación de la API: local antes que web

Si el corpus está clonado en `~/.local/share/creator-docs`, consúltalo antes de
buscar en internet. Medido: 10 ms en local frente a 435 ms por web.

**Hay que buscar en las DOS formas del corpus:**

| Forma | Ruta | Sirve para |
|---|---|---|
| Referencia de API | `content/en-us/reference/engine/{classes,libraries,datatypes}/*.yaml` | Firmas exactas, parámetros, tipos de retorno |
| Guías | `content/en-us/**/*.md` | Patrones, seguridad, arquitectura |

Buscar sólo en los `.md` hace parecer que la respuesta no existe cuando está en
el `.yaml`. Es el error más fácil de cometer con este corpus.

**Laguna conocida:** las APIs de **Open Cloud** no están en el corpus. Para eso
sí hay que ir a `create.roblox.com/docs/cloud`.

## Secretos

**Los secretos nunca se escriben en el repositorio.** Ni en código, ni en JSON,
ni en un `.env` versionado, ni "temporalmente".

`gitleaks` está instalado como red de seguridad, pero **no es la defensa**: en la
prueba de FASE 1 detectó 1 de 3 claves AWS válidas. Trátalo como un detector
parcial, no como una garantía.

La clave de Open Cloud vive **solo** en GitHub Secrets y se inyecta como
variable de entorno en el paso que la necesita. Nunca en disco.

## Alcance

No cambies arquitectura ni comportamiento del juego sin que te lo pidan.
Inspecciona primero, propón el cambio mínimo, y ejecútalo solo si es necesario.
