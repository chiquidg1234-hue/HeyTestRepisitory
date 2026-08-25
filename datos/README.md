# Evidencia reproducible

- `probe.sh` — script usado para medir cada repositorio. Clona solo metadatos
  (`--depth 100 --filter=blob:none --no-checkout`) y lee el historial. **No ejecuta
  código del repositorio evaluado.**
- `repositorios-evaluados.txt` — los 232 repositorios candidatos analizados.
- `evidencia-repositorios-2026-08-25.csv` — resultado de la medición del 25-08-2026.

## Reproducir

```bash
cd datos
xargs -P 8 -I{} ./probe.sh {} < repositorios-evaluados.txt | sort
```

## Cómo leer el CSV

| Columna | Significado |
|---|---|
| `dias_sin_commits` | Días transcurridos desde el último commit de la rama por defecto |
| `commits_30d` / `90d` / `365d` | Commits en esa ventana. **`100` significa "≥100"**: el clon tiene profundidad 100 y el contador toca techo |
| `autores_distintos` | Direcciones de email únicas en los `commits_muestreados` |
| `ficheros_en_HEAD` | Ficheros rastreados en el árbol de HEAD |
| `tiene_LICENSE` | 1 si existe `LICENSE`/`COPYING` en la raíz |
| `ficheros_test` | Ficheros bajo `test/`, `tests/`, `spec/` o `__tests__/` |
| `CLONE_FAILED` | El repositorio fue renombrado, movido o no es accesible con esa ruta |

Las estrellas, forks e issues abiertos **no** están en el CSV porque proceden de la
página de GitHub, no de esta medición; están citadas en el informe.
