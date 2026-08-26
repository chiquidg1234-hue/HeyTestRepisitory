# FASE 7 — Autonomía

**Fecha:** 26-08-2026 · **Estado:** **PARCIAL**

| Componente | Estado |
|---|---|
| Open Cloud — andamiaje de CI | ✅ **Preparado y verificado sin credenciales** |
| Spec Kit | ⚠️ **Instalado, verificación parcial** |
| `srt` (sandbox-runtime) | ⚠️ **Instalado, NO verificable en este contenedor** |
| Serena | ⏸️ **No evaluada — deliberadamente** |

---

## Open Cloud: listo para recibir el secreto, sin secreto dentro

**No se ha generado, solicitado, copiado ni almacenado ningún token.**

| Entregable | Qué hace |
|---|---|
| [`ci/roblox-ci.yml`](ci/roblox-ci.yml) | Workflow con **dos jobs separados por nivel de confianza** |
| [`scripts/open_cloud_luau.py`](scripts/open_cloud_luau.py) | Cliente de la Luau Execution API |

### La decisión de diseño que importa

El workflow separa **verificación estática** (sin credenciales, corre en cualquier PR incluidos
los de forks) de **verificación en motor** (con credenciales, nunca en PRs de forks, con
`environment: roblox-open-cloud` para poder exigir aprobación manual).

Eso responde directamente a la corrección de FASE 1: **gitleaks no detecta todas las claves**, así
que la defensa no puede ser el escáner. La defensa es que **la clave nunca llegue a un fichero**:
vive en GitHub Secrets, se inyecta como variable de entorno y sólo existe durante el paso que la
usa.

El script **nunca imprime, registra ni escribe la clave**. Respeta los límites documentados por
Roblox: 5 minutos por tarea, 10 concurrentes por place.

### Verificado

| Prueba | Resultado |
|---|---|
| Ejecutar sin `ROBLOX_OPEN_CLOUD_KEY` | **Falla limpio con `exit 1`** y mensaje claro, no crashea |
| YAML del workflow | **Sintaxis válida** |
| `gitleaks` sobre todo el andamiaje | **`no leaks found`** |

### Pendiente de ti (no lo hago yo)

1. Crear la clave de Open Cloud **acotada al universo de desarrollo**, nunca al de producción.
2. Guardarla como `ROBLOX_OPEN_CLOUD_KEY` en GitHub Secrets.
3. Definir `ROBLOX_UNIVERSE_ID` y `ROBLOX_PLACE_ID` como *variables* (no secretos).
4. Escribir `tests/engine_smoke.luau`.

---

## Spec Kit

| | |
|---|---|
| Instalación | `pip install specify-cli` → **1.0.1**, binario en `/usr/local/bin/specify` |
| **Procedencia verificada** | ✅ El `pyproject.toml` del repo oficial `github/spec-kit` declara `name = "specify-cli"`. **PyPI es la fuente legítima** |
| Comandos que aporta | 10: `constitution`, `specify`, `clarify`, `plan`, `tasks`, `checklist`, `analyze`, `implement`, `converge`, `taskstoissues` |

**Verificación parcial y por qué:** `specify init` se ejecuta y genera estructura, pero la
selección de agente es interactiva en 1.0.1 y `--ai` ya no existe. En mi ejecución no interactiva
generó `.github/` y `.specify/` pero **0 comandos en `.claude/commands/`**. Existe
`--integration-options="--commands-dir …"` para dirigirlo.

**No declaro la integración con Claude Code verificada.** Queda como paso de 2 minutos en tu
máquina: `specify init` de forma interactiva y elegir Claude.

> Contraste deliberado con el caso del npm `luau-lsp`: allí el paquete del nombre obvio **no** era
> el oficial y lo descarté; aquí sí lo es y lo instalé. **La regla no es "desconfía de todo": es
> "verifica la procedencia antes de instalar".**

---

## `srt`: instalado, **no verificable aquí**

| | |
|---|---|
| Instalación | `npm install -g @anthropic-ai/sandbox-runtime` → **1.0.0** |
| Dependencias | `bubblewrap 0.9.0` y `socat` instalados vía apt |
| **Ejecución** | ❌ **`apply-seccomp: write /proc/self/uid_map: Operation not permitted`** |

**Causa:** este contenedor no permite *namespaces de usuario anidados*. `srt` necesita crearlos.
No es un fallo de `srt`: es que un sandbox no puede anidarse dentro de este sandbox.

**Aviso de honestidad:** en mi prueba «escribir fuera del cwd» no se creó el fichero — **pero eso
no demuestra que el aislamiento funcione.** El comando no llegó a ejecutarse. Sería deshonesto
contarlo como una prueba superada.

**Pendiente:** verificarlo en tu máquina (WSL2 en Windows) con las tres pruebas: lectura dentro
permitida, lectura de credenciales fuera bloqueada, red no permitida bloqueada.

---

## Serena: **no evaluada, a propósito**

Tu instrucción era que Serena fuese la última comparación, con la misma tarea patrón y criterios
objetivos. **No la he tocado.** Evaluarla ahora habría sido:

- **Prematuro:** aún faltan datos de FASE 6 (el ciclo del motor) que cambian el contexto.
- **Caro:** una comparación honesta necesita ≥2 ejecuciones de T-01 (~2,4 USD) más su instalación.
- **Poco concluyente:** con `n = 1` por configuración, ya sabemos por H2 que no distinguiríamos el
  efecto del ruido.

**Cuando toque, el diseño es:** T-01 con luau-lsp+Rojo (línea base ya medida) frente a T-01 con
Serena añadida, midiendo tokens, iteraciones, coste, tiempo, errores entregados **y uso real de
herramientas verificado en el transcript**.

---

## CHECKPOINT

| Campo | Valor |
|---|---|
| **Fase** | 7 — Autonomía |
| **Estado** | **PARCIAL** |
| **Herramientas nuevas** | `srt` 1.0.0 (no verificable) · `specify` 1.0.1 (parcial) · bubblewrap + socat |
| **Pruebas reales** | Open Cloud: 3 verificaciones pasadas. Spec Kit: init ejecutado. srt: **0 pruebas útiles** |
| **Limitaciones** | Sin namespaces anidados → srt inerte; selección de agente de Spec Kit es interactiva |
| **Pendiente de humano** | Clave de Open Cloud · `specify init` interactivo · verificar srt en WSL2 |
| **Siguiente paso** | FASE 6 (requiere tu máquina) y después la comparación de Serena |
