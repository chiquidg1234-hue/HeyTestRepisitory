# Auditoría de seguridad — `bradautomates/claude-video`

**Fecha:** 25-08-2026 · **Commit auditado:** `83da59f` · **Método:** clonado y lectura estática. **Nada se ejecutó.**

## Veredicto

> **Seguro de usar, con dos advertencias reales.** Es de las skills mejor escritas que he auditado:
> sin `shell=True`, argumentos como lista, `--` antes de la URL, `chmod 600` en el fichero de
> claves, y una sección de privacidad honesta en el propio `SKILL.md`. **No busques alternativa.**

## Qué es

Plugin de Claude Code que añade el comando `/watch`: descarga un vídeo con `yt-dlp`, extrae
fotogramas con `ffmpeg`, saca la transcripción de los subtítulos nativos (o de Whisper como
respaldo) y le entrega fotogramas + transcripción a Claude.

| Señal | Valor medido |
|---|---|
| Estrellas / forks | 16 147 / 1 586 |
| Licencia | MIT |
| Creado | 24-04-2026 (4 meses) |
| Último commit | hace **56 días** |
| Commits: 30 d / 90 d / año | **0 / 5 / 11** |
| **Autores distintos** | **1** (todas las contribuciones son del autor) |
| Ficheros de test | 10 · 1 workflow de CI |
| Issues abiertos | 128 |

## Lo que hace bien

| Control | Evidencia |
|---|---|
| **Sin inyección de comandos** | `shell=True` no aparece en ningún fichero |
| **Argumentos como lista** | `subprocess.run([...])` en todos los casos |
| **Protección contra option-injection** | `"--", url` antes de la URL en el comando de `yt-dlp` |
| **Permisos del fichero de claves** | `CONFIG_FILE.chmod(0o600)` en `setup.py` |
| **El hook avisa si aflojas los permisos** | `check-setup.sh` alerta si `~/.config/watch/.env` no es 600 o 400 |
| **No auto-instala nada** | El hook `SessionStart` es sólo lectura, timeout 5 s, y se limita a imprimir una línea de estado |
| **Instalación explícita y acotada** | `setup.py` instala vía Homebrew **sólo en macOS**; en Linux y Windows únicamente imprime sugerencias |
| **No mezcla credenciales** | La clave de Groq sólo va a `api.groq.com`; la de OpenAI sólo a `api.openai.com` |
| **Divulgación de flujo de datos** | El `SKILL.md` tiene una sección explícita de qué sale y qué no |

## Advertencia 1 — el audio sale a un tercero

Cuando el vídeo **no tiene subtítulos nativos** y no usas `--no-whisper`, el script extrae el
audio y lo **sube a Groq (`whisper-large-v3`) o a OpenAI (`whisper-1`)**.

El propio `SKILL.md` lo dice: *no sube el vídeo, sólo el audio extraído, y sólo cuando faltan
los subtítulos*. Es honesto y es evitable — pero **es una salida de datos a un proveedor que no
es Anthropic**, y necesitas una clave de API tuya de esos servicios.

**Mitigación:** usa `--no-whisper` si el contenido es sensible, o limítate a vídeos con
subtítulos. Sin clave configurada, el respaldo simplemente no se activa.

## Advertencia 2 — bus factor de 1, y viral

16 147 estrellas en cuatro meses con **un solo autor** y **cero commits en 30 días**. La calidad
actual del código no garantiza respuesta ante un fallo de seguridad futuro. Y por la primera
investigación ya sabes lo que la popularidad extrema atrae: **clones envenenados**.

**Mitigación:** instala **sólo** desde `bradautomates/claude-video`, verifica el nombre del
propietario carácter a carácter, y fija la versión si tu flujo lo permite.

## Advertencia 3 — superficie de inyección de prompt (inherente, no un fallo del proyecto)

`/watch` mete en el contexto de Claude la transcripción de un vídeo arbitrario de internet.
Una transcripción **puede contener instrucciones dirigidas a tu agente**. Esto no es un defecto
de esta skill: es la naturaleza de cualquier herramienta que ingiere contenido externo.

**Mitigación:** no lo uses en una sesión con permisos amplios sobre un repositorio de producción.

## Permisos que exige

`allowed-tools: Bash, Read, AskUserQuestion` · binarios `ffmpeg` y `yt-dlp` · red hacia el
alojamiento del vídeo y, opcionalmente, hacia Groq u OpenAI · escritura en `~/.config/watch/.env`.

## Relación con el stack de Roblox/UEFN

**Ninguna.** No aporta nada al agente de desarrollo de juegos. Es una herramienta útil e
independiente — por ejemplo, para que Claude analice un vídeo de referencia de gameplay o un
tutorial. Instálala si te sirve para eso, **no como parte del plan de fases**.

## Decisión

| | |
|---|---|
| **Veredicto** | **APTA** — instalable |
| **Fase** | Fuera del plan. No es parte de FASE 1-7 |
| **Condiciones** | `--no-whisper` con contenido sensible · no usarla en sesiones con permisos amplios · verificar el propietario del repo |
