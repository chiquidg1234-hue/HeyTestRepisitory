# Entorno

Verificador de tipos y sincronizador Rojo disponibles. Las definiciones de la
API de Roblox están en `./globalTypes.d.luau`, dentro de este proyecto.

**Flujo obligatorio de verificación:**

```bash
rojo sourcemap default.project.json --output sourcemap.json
luau-lsp analyze --platform=roblox --defs=./globalTypes.d.luau \
  --sourcemap=sourcemap.json <ficheros.luau>
```

Regenera `sourcemap.json` cada vez que añadas o muevas un fichero: sin él, el
analizador no resuelve los `require` y da errores que no se pueden arreglar.

Sale con código 0 si no hay errores. **No des la tarea por terminada hasta que salga limpio.**
