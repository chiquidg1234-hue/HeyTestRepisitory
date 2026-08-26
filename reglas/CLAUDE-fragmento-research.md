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

*(El código de tests, que se ejecuta en Lune o Lute y no en Roblox, sí puede usar
`os.exit`. Por eso `src/` y `tests/` se analizan por separado.)*

## Cuándo sí buscar en la web

- APIs de **Open Cloud** (`create.roblox.com/docs/cloud`) — **no están en este
  corpus**. Es la única laguna medida.
- Novedades posteriores al commit clonado. Refresca con `git -C ~/.local/share/creator-docs pull`.
