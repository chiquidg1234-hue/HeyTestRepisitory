# FASE 0 — BASELINE

**Fecha:** 25 de agosto de 2026
**Estado:** CERRADA. No se avanzó a FASE 1.
**Regla cumplida:** no se instaló ninguna herramienta de fases posteriores y no se optimizó el entorno para mejorar el resultado.

---

## ⚠️ Advertencia de validez — léela antes que los números

Esta FASE 0 se ejecutó en **un contenedor remoto efímero de Claude Code on the web**
(`root@vm`, Linux 6.18.44), **no en tu máquina**. Consecuencias que debes asumir:

1. **`~/.claude` de aquí no es el tuyo.** Contiene sólo esta sesión y hooks inyectados
   por el runner remoto (`stop-hook-git-check.sh`, `session-start-git-identity.sh`,
   `user-prompt-submit-reply-reminder.py`). Tu configuración real no está aquí.
2. **El contenedor se destruye.** Cualquier `git init` sobre `~/.claude` aquí moriría con él.
3. **Los números son válidos como baseline de *este* runtime**, y son reproducibles con el
   protocolo descrito. Para que sirvan como tu línea base personal, **repite el mismo
   protocolo en tu máquina**: los comandos están todos aquí y no requieren nada instalado.

Lo que sí es plenamente transferible: la **especificación de la tarea patrón**, el
**protocolo de medición** y el **`.gitignore` de `~/.claude`**.

---

## 1. Inventario del entorno

| Elemento | Valor medido |
|---|---|
| Claude Code | **2.1.245** (native, linux-x64, commit `28b7e8c41235`) |
| Node | v22.22.2 · npx 10.9.7 |
| Búsqueda | OK (`/usr/bin/rg`) |
| **Servidores MCP configurados** | **0** (`claude mcp list` → "No MCP servers configured") |
| **Plugins instalados** | **0** (`claude plugin list` → "No plugins installed") |
| Avisos de `claude doctor` | 3, todos sobre método de instalación del contenedor |
| Tamaño de `~/.claude` | 6,6 MB |

> **Nota honesta sobre los MCP:** `claude mcp list` dice 0 porque los servidores que esta
> sesión usa (Exa, GitHub, Nimble, Google Drive) los **inyecta el harness remoto**, no
> `claude mcp add`. En tu máquina, `claude mcp list` sí reflejará los tuyos.

### Herramientas de fases posteriores — todas ausentes, como debe ser

```
luau · luau-analyze · lune · lute · lua · selene · stylua · rojo  →  TODAS AUSENTES
```

Esto es lo que hace que este baseline sea limpio: **no hay nada con que verificar código Luau.**

---

## 2. Comandos que ejecuté y los que no pude ejecutar

| Pedido | Qué hice | Resultado |
|---|---|---|
| `/doctor` | **`claude doctor`** (subcomando CLI equivalente) | ✅ Ejecutado, salida guardada abajo |
| `/context` | **No existe equivalente CLI.** Medido por proxy reproducible: coste de contexto de arranque de una sesión `-p` trivial | ✅ **34.830 tokens** de `cache_creation` para el prompt «Responde exactamente: OK» |
| `/sandbox` | **No existe equivalente CLI.** Inspeccioné la configuración de permisos y el estado del proxy | ⚠️ Parcial — debes ejecutarlo tú en sesión interactiva |
| `npx ccusage` | ✅ Ejecutado sin instalación permanente | ✅ Snapshots antes y después guardados |

`/context` y `/sandbox` son comandos de la TUI interactiva: un agente no puede invocarlos.
**Esos dos los tienes que teclear tú.** El proxy de `/context` que usé es reproducible y
sirve para comparar entre fases, pero no sustituye al desglose que te da el comando real.

### Salida de `claude doctor`

```
Running: native (2.1.245) · Commit: 28b7e8c41235 · Platform: linux-x64
Search: OK (/usr/bin/rg) · Auto-updates: enabled
3 warnings:
 - Running native installation but config install method is 'unknown'
 - claude command at /root/.local/bin/claude missing or broken
 - Leftover npm global installation at /opt/node22/bin/claude
```

Los tres avisos son artefactos del contenedor remoto, no de tu configuración.

---

## 3. Auditoría de secretos en `~/.claude`

Escaneo de patrones (`sk-ant`, `ghp_`, `github_pat_`, `gho_`, `AKIA`, claves privadas,
`access_token`, `refresh_token`, `Bearer`), **sin imprimir ningún valor**.

| Resultado | Detalle |
|---|---|
| **Credenciales reales encontradas** | **0** |
| Coincidencias con cuerpo de clave válido (`sk-ant-…{20,}`, `ghp_…{36}`, `AKIA…{16}`) | **0** |
| Falsos positivos | 5 patrones × 2 coincidencias cada uno, **todas eran mis propios comandos `grep` reflejados en el transcript de la sesión** |

### Hallazgo de seguridad que sí importa

`~/.claude/projects/**/*.jsonl` es el **transcript completo de la conversación** — 1,9 MB
sólo en esta sesión. Contiene todo lo que se ha pegado, leído y ejecutado.

**Nunca commitees `~/.claude` entero.** El `.gitignore` de lista blanca está en
[`claude-config.gitignore`](claude-config.gitignore).

`~/.claude.json` (fuera de `~/.claude/`, modo 600) contiene `oauthAccount`. **Nunca lo versiones.**

### Git de `~/.claude`: NO lo hice, y necesito tu aprobación

**Lo dejé sin hacer deliberadamente.** Razones:

1. Aquí es efímero: moriría con el contenedor, dándote una falsa sensación de respaldo.
2. Lo que hay es la configuración del *runner remoto*, no la tuya.
3. Hacerlo mal —incluyendo `projects/*.jsonl`— es exactamente el fallo que queremos evitar.

**Procedimiento para tu máquina** (revísalo antes de ejecutarlo):

```bash
cp claude-config.gitignore ~/.claude/.gitignore   # 1. PRIMERO el gitignore
cd ~/.claude && git init                          # 2. después el repo
git status --short                                # 3. VERIFICA qué entraría
git add -A && git status --short                  # 4. vuelve a verificar
# Sólo si la lista contiene únicamente configuración:
git commit -m "baseline de configuración de Claude Code"
```

El paso 3 no es opcional. Si aparece cualquier `.jsonl`, para y avísame.

---

## 4. La tarea patrón

**`T-01-inventario-persistente`**, especificación congelada en [`TAREA-PATRON.md`](TAREA-PATRON.md).

Un sistema de inventario de Roblox en Luau con siete requisitos obligatorios: núcleo de
lógica pura sin servicios de Roblox, persistencia con bloqueo de sesión, API remota validada
en servidor, cliente mínimo, `--!strict` en todo, tests ejecutables fuera de Roblox y
`default.project.json` de Rojo.

**Por qué esta:** ejercita a la vez los cinco ejes que el toolchain debe mejorar —
arquitectura cliente/servidor, persistencia, separabilidad para test, tipado y estructura
de proyecto. Si una herramienta futura no mueve ninguno de esos números, no merece estar.

---

## 5. Resultado de la ejecución única

**Una sola ejecución. Sin reintentos, sin ayuda, sin correcciones.**
Directorio vacío aislado fuera del repo, para que el agente no leyera la investigación previa.

```bash
claude -p "<prompt de TAREA-PATRON.md>" --output-format json --permission-mode acceptEdits
```

### Los tres números del baseline

| Métrica | Valor | Fuente |
|---|---|---|
| **TOKENS (total)** | **934 029** | `usage` del runtime |
| ├ input | 22 | |
| ├ output | 54 906 | |
| ├ cache creation | 65 166 | |
| └ cache read | 813 935 | |
| **ITERACIONES** | **11 turnos** | `num_turns` |
| **TIEMPO** | **484 s** de reloj · 479,1 s de API | `date` + `duration_api_ms` |
| Coste | **0,9739 USD** | `total_cost_usd` |
| Contexto de arranque | **34 830 tokens** | ejecución de control trivial |
| Salida | `is_error: false` · `stop_reason: end_turn` | |

**Discrepancia que hay que conocer:** el delta de `ccusage` en la misma ventana fue de
1 893 238 tokens y 1,51 USD — **casi el doble**. No es un error: `ccusage` mide *todo* lo
que ocurrió en la máquina durante ese intervalo, incluyendo mi propia conversación de
supervisión. **El número autoritativo por tarea es el JSON del runtime**, no el delta de
`ccusage`. Para comparaciones entre fases, usa siempre `--output-format json`.

### Qué produjo: 8 ficheros, 1 104 líneas

```
default.project.json                                              39
src/ReplicatedStorage/Shared/InventoryCore.luau                  345
src/ReplicatedStorage/Shared/ItemCatalog.luau                     29
src/ServerScriptService/InventoryService/InventoryServer.luau    171
src/ServerScriptService/InventoryService/ProfileStore.luau       160
src/ServerScriptService/InventoryService/init.server.luau        101
src/StarterPlayer/StarterPlayerScripts/InventoryClient.client.luau 56
tests/InventoryCore.spec.luau                                    203
```

Copia íntegra en [`T01-run1-salida/`](T01-run1-salida/).

---

## 6. Verificación — **el hallazgo central de la FASE 0**

| # | Comprobación | Resultado |
|---|---|---|
| **V1** | **Ejecutar los tests** | 🔴 **IMPOSIBLE** — no hay runtime de Luau |
| **V2** | **Comprobar los tipos** | 🔴 **IMPOSIBLE** — no hay `luau-analyze` |
| V3 | `--!strict` en todos los ficheros | 🟢 **7/7** |
| V4 | Núcleo puro sin servicios de Roblox | 🟢 **PASA** (la única coincidencia estaba dentro de un comentario de bloque; falso positivo corregido) |
| V5 | Validación en servidor de los remotos | 🟢 **PASA** — doble comprobación de tipo, allowlist `USABLE_ITEMS`, cantidad fijada por servidor (`CONSUME_QUANTITY = 1`) |
| V6 | Bloqueo de sesión en persistencia | 🟢 **PASA** — `SessionLock`, `jobId`, `LOCK_TIMEOUT_SECONDS` |
| V7 | `default.project.json` válido | 🟢 **PASA** |
| V8 | El test sale con código ≠ 0 | 🟢 **PASA** — usa `error()` |
| **V9** | **Rate limiting en los remotos** | 🔴 **FALLA** — ningún cooldown; un cliente puede spamear `UseItem` sin límite |

### **Verificación automática posible en FASE 0: 0 de 2.**

Este es el número que importa. El agente produjo 1 104 líneas de Luau con arquitectura
correcta y **nadie —ni él ni yo— puede demostrar que compilan.** Las seis comprobaciones
verdes las hice con `grep` y leyendo el código a mano: eso no escala y no es una puerta.

**El defecto V9 es la ilustración perfecta:** el código es bueno, pasa la revisión
estructural, y aun así trae un vector de exploit clásico. Sin un revisor automático, ese
defecto llega a producción.

---

## 7. Qué quedó modificado en el entorno

| Cambio | Dónde | Reversible |
|---|---|---|
| Ficheros nuevos de FASE 0 | `fase-0-baseline/` en el repo | Sí, `git rm -r` |
| Caché de npx para `ccusage` | `~/.npm/_npx` | Sí, `npm cache clean` |
| Directorios temporales | scratchpad de la sesión | Se destruyen con el contenedor |
| **Instalaciones permanentes** | **NINGUNA** | — |
| **Cambios en `~/.claude`** | **NINGUNO** | — |
| **Cambios en `settings.json`** | **NINGUNO** | — |

---

## 8. Cómo reproducir esta FASE 0 en tu máquina

```bash
# 1. Inventario
claude doctor && claude mcp list && claude plugin list
npx -y ccusage@latest daily

# 2. En sesión interactiva, apunta los números
/context      # tokens de arranque y su desglose
/sandbox      # modo y dependencias del sandbox

# 3. Contexto de arranque, medible sin TUI
cd /tmp && mkdir -p ctl && cd ctl
claude -p "Responde exactamente: OK" --output-format json | python3 -m json.tool | grep cache_creation

# 4. Tarea patrón, UNA vez, en directorio vacío
mkdir -p /tmp/T01 && cd /tmp/T01
claude -p "<prompt literal de TAREA-PATRON.md>" --output-format json --permission-mode acceptEdits > resultado.json

# 5. Los tres números
python3 -c "import json;d=json.load(open('resultado.json'));u=d['usage'];print('turnos',d['num_turns'],'| ms',d['duration_api_ms'],'| coste',d['total_cost_usd'],'| tokens',sum(int(u.get(k) or 0) for k in ['input_tokens','output_tokens','cache_creation_input_tokens','cache_read_input_tokens']))"
```

---

## 9. Criterio de éxito para las fases siguientes

Cualquier herramienta que se instale a partir de aquí tiene que mover **al menos uno** de
estos números en la dirección correcta, medido con la **misma** tarea patrón:

| Métrica | Baseline | Qué esperamos de FASE 2+ |
|---|---|---|
| Verificación automática | **0 / 2** | **2 / 2** — es el objetivo real de todo el plan |
| Defectos como V9 detectados | 0 automáticos | ≥1 automático |
| Iteraciones | 11 | ≤ 11 con verificación activada |
| Tokens | 934 029 | Sin subida > 20 % sin ganancia en verificación |
| Tiempo | 484 s | Ruido; sólo desempate |
| Contexto de arranque | 34 830 | Vigilar: > +5 000 sin beneficio ⇒ revertir |

**Si una herramienta no mueve ninguno, se quita.**
