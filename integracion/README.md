# Paquete de integración — stack de verificación Roblox

Convierte lo verificado en las FASES 1–7 en algo que tu proyecto Roblox real
pueda usar. **No es un experimento nuevo**: es el mismo toolchain, empaquetado
para instalarse encima de un proyecto que ya existe sin romperlo.

> **El proyecto Roblox real no está en este contenedor.** Vive en tu Windows.
> Por eso esto es un paquete instalable y no una integración ya hecha. Todo lo
> que hay aquí se ha probado contra un proyecto de prueba con estructura
> realista (`ServerScriptService` / `ReplicatedStorage` / `StarterPlayer`,
> con ficheros preexistentes que el instalador debía respetar).

## Uso

Desde **Git Bash** en Windows (o WSL2, o Linux):

```bash
./instalar.sh /c/ruta/a/tu/proyecto --simular   # enseña qué haría, no escribe nada
./instalar.sh /c/ruta/a/tu/proyecto             # lo hace
```

Desde PowerShell hay un envoltorio, `instalar.ps1`, que sólo localiza Git Bash y
llama al script de arriba. **Ese envoltorio no está ejecutado ni verificado**
(no hay PowerShell en el contenedor donde se escribió); si da problemas, usa
Git Bash directamente.

## Qué hace el instalador

1. **Se niega a actuar** si el destino no tiene `default.project.json`.
2. **Detecta tus carpetas de código leyendo tu `default.project.json`**, no las
   supone. Si tu código está en `source/` en vez de `src/`, se adapta.
3. **No sobrescribe nada.** Si un fichero ya existe y es distinto, deja
   `fichero.propuesto` al lado y te lo dice en el informe final.
4. **Fusiona** `.claude/settings.json` conservando tus hooks y permisos, con
   copia de seguridad previa con marca de tiempo.
5. Es **idempotente**: la segunda ejecución no cambia nada.
6. No toca código del juego, no escribe credenciales, no borra nada.

## Qué instala

| Fichero | Para qué |
|---|---|
| `verificar.sh` | La puerta completa: sourcemap, tipos, lint, formato, tests. Ejecutable a mano |
| `.claude/hooks/post-tool-use-luau.sh` | Verifica el fichero recién editado. `exit 2` → Claude ve el error y corrige |
| `.claude/hooks/stop-gate.sh` | Impide cerrar el turno con el proyecto roto. Con freno de presupuesto |
| `.claude/roblox-stack.json` | Rutas detectadas, para que hooks y verificador no supongan `src/` |
| `.luaurc` · `tests/.luaurc` | Modo estricto; alias `@lune` para que los tests también se comprueben |
| `selene.toml` · `stylua.toml` · `rokit.toml` | Lint, formato y versiones fijadas |
| `tests/run.luau` | Runner de Lune. Sale != 0 si algo falla |
| `tests/engine_smoke.luau` | Comprobación mínima **en el motor**, para Open Cloud |
| `.github/workflows/roblox-ci.yml` | CI. Job estático sin credenciales + job de motor protegido |
| `scripts/open_cloud_luau.py` | Ejecuta Luau en un place real. Sin credenciales dentro |
| `herramientas/rbxdocs` | Consulta local de la documentación de Roblox |
| `CLAUDE.fragmento.md` | Reglas para pegar en tu `CLAUDE.md` |
| `.pre-commit-config.yaml` | Puerta de secretos |

## La idea de fondo: dos entornos, dos verificaciones

Es el error más caro de esta clase de proyectos y aquí está resuelto:

| | Dónde corre | Cómo se verifica |
|---|---|---|
| Código del juego | Motor de Roblox | `--platform=roblox` + `globalTypes.d.luau` + **sourcemap** |
| `tests/*.spec.luau` | Lune, headless | `--platform=standard` + alias `@lune` |
| `tests/engine_smoke.luau` | Motor, vía Open Cloud | como código del juego |

Analizar los tests con las definiciones de Roblox, o el código del juego sin
ellas, produce errores falsos en ambos sentidos.

## Lo que NO hace, y por qué

- **No descarga `globalTypes.d.luau`.** Necesita red desde tu máquina. Sin él,
  los tipos de la API de Roblox no se comprueban y el verificador lo dice.
- **No genera `roblox.yml` para selene.** Necesita red. Mientras tanto el
  `selene.toml` que instala usa `std = "luau"`, que sí funciona sin red.
- **No añade nada a tu `.gitignore` ni a tu `CLAUDE.md`.** Deja los fragmentos y
  te dice qué pegar. Son ficheros tuyos con contenido tuyo.
- **No toca credenciales.** Ni las pide, ni las genera, ni las escribe.

Ver `INTEGRACION.md` en la raíz del repositorio para el estado verificado, las
pruebas que se pasaron y lo que te toca hacer a ti.
