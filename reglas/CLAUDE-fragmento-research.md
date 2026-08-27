# Fragmento para CLAUDE.md — regla «local antes que web»

> Copiar en el `CLAUDE.md` del proyecto de Roblox.

## Documentación de la API de Roblox: consulta local obligatoria

La documentación oficial completa está clonada en `~/.local/share/creator-docs`
(9 295 ficheros, 64 MB). **Consúltala antes de buscar en la web.** Es la misma
fuente que publica Roblox, en local, sin latencia de red y sin riesgo de
alucinación.

Usa el helper `rbxdocs`:

```bash
rbxdocs lib os                        # todas las funciones de una biblioteca Luau
rbxdocs api "GlobalDataStore:UpdateAsync"   # firma exacta de un método
rbxdocs guide "client-server boundary"      # guías narrativas
```

**El corpus tiene dos formas y hay que buscar en LAS DOS:**

| Forma | Ruta | Sirve para |
|---|---|---|
| Referencia de API | `content/en-us/reference/engine/{classes,libraries,datatypes}/*.yaml` | Firmas exactas, parámetros, tipos de retorno. **641 clases, 11 bibliotecas, 48 datatypes** |
| Guías | `content/en-us/**/*.md` | Patrones, seguridad, arquitectura. **1 007 documentos** |

Buscar sólo en los `.md` hace que parezca que la respuesta no existe cuando sí
está en el `.yaml`. Es el error más fácil de cometer con este corpus.

## Regla de verificación de símbolos

**Antes de usar cualquier función de una biblioteca Luau, comprueba que existe
en Roblox:**

```bash
rbxdocs lib <biblioteca>
```

Motivo concreto: `os.exit` **no existe** en Roblox — la biblioteca `os` sólo
tiene `os.clock`, `os.date`, `os.difftime` y `os.time`. Escribir `os.exit()` en
código de Roblox es un error de tipos garantizado.

> **CORRECCIÓN (27-08-2026).** Una versión anterior de este fragmento decía que
> «el código de tests, que se ejecuta en Lune, sí puede usar `os.exit`».
> **Es falso: `os.exit` tampoco existe en Lune.** Una suite que lo usaba pasaba
> sus 27 comprobaciones y luego reventaba con `attempt to call a nil value`, de
> modo que nunca podía dar verde. En Lune el corte es
> `require("@lune/process").exit(n)`.
>
> `src/` y `tests/` **sí** se analizan por separado, pero por otra razón: los
> tests corren en Lune y usan alias `@lune/*`, así que van con
> `--platform=standard` y el alias de tipos que genera `lune setup`.

**Este fichero está superado por
[`integracion/plantilla/CLAUDE.fragmento.md`](../integracion/plantilla/CLAUDE.fragmento.md),
que es el que hay que pegar en el `CLAUDE.md` del proyecto.**

## Cuándo sí buscar en la web

- APIs de **Open Cloud** (`create.roblox.com/docs/cloud`) — **no están en este
  corpus**. Es la única laguna medida.
- Novedades posteriores al commit clonado. Refresca con `git -C ~/.local/share/creator-docs pull`.
