# CHECKPOINT PARA LA PRÓXIMA SESIÓN

**Última sesión:** 27-08-2026 · **Rama:** `claude/github-intelligence-research-0dnet7`
**Contexto completo:** [`docs/INFORME-MAESTRO-MISION-2.md`](INFORME-MAESTRO-MISION-2.md)
— léelo sólo si necesitas el detalle. Este fichero basta para arrancar.

---

## ESTADO ACTUAL

La investigación está **cerrada**. Ocho fases ejecutadas y medidas, con sus
correcciones. No queda nada que investigar.

Existe un paquete instalable en `integracion/` que lleva el stack de verificación
a un proyecto Roblox existente sin romperlo. Está probado contra dos proyectos de
estructura realista, uno de ellos con carpeta `source/` en vez de `src/`.

**Lo que falta no es conocimiento: es aplicarlo.** Y el primer paso lo tiene que
dar el usuario en su Windows, porque **el proyecto Roblox real no está en el
contenedor** (comprobado: `/home/user` sólo contiene este repositorio).

## LO QUE YA ESTÁ DEMOSTRADO

- **Verificación estática accionable.** `luau-lsp` sobre un sourcemap de Rojo
  detecta errores de tipo entre módulos con línea y columna. **Sin sourcemap no
  detecta nada**: el `require` ni siquiera resuelve. Probado con control.
- **Los tests de Lune también se comprueban de tipos**, vía el alias que genera
  `lune setup`. Antes se saltaban.
- **Las puertas bloquean de verdad.** `PostToolUse` da `exit 2` con el error;
  `Stop` impide cerrar el turno con el proyecto roto, y a los 3 bloqueos suelta
  con aviso para no quemar presupuesto. Probados con payload real.
- **El instalador no es destructivo.** No sobrescribe, fusiona `settings.json`
  conservando los hooks del usuario, es idempotente y detecta las rutas leyendo
  `default.project.json`.
- **El ciclo del motor funciona** (editar → jugar → leer consola → corregir):
  4/4 casillas, con Roblox Studio MCP. **Lo ejecutó el usuario desde PowerShell
  en Windows 11. No es ejecución de esta sesión.**
- **Métricas duras:** verificación automática 0/2 → 2/2 · 10 errores de tipo
  entregados → 0 · contexto de arranque +0,38 % · **0 MCP permanentes**.

## LO QUE NO ESTÁ DEMOSTRADO

- **El stack sobre el proyecto real.** Nunca se ha aplicado. Es lo único que
  convierte todo esto en capacidad.
- **El CI.** El YAML está validado y auditado, pero **nunca se ha ejecutado**.
- **Open Cloud.** El script y el workflow están listos, pero **la API nunca se ha
  llamado**. Falta la credencial.
- **UEFN.** Cero. Bloqueado por Beta Access.
- **`instalar.ps1`.** No hay PowerShell en el contenedor. Usar `instalar.sh`
  desde Git Bash.
- **Que Serena aporte algo.** De 21 herramientas expuestas ejecutó 1 y ninguna
  simbólica. No atribuirle mejoras.
- **`srt`.** Inerte aquí. La prueba que se hizo no probaba nada.

## PRÓXIMA ACCIÓN RECOMENDADA

Que el usuario ejecute, **desde Git Bash en su Windows**:

```bash
cd /c/ruta/a/este/repositorio/integracion
./instalar.sh /c/ruta/a/su/proyecto --simular
```

Leer el informe. Si convence, repetir sin `--simular`. Después, los pasos W3–W7
de `entorno-local/WINDOWS-11-INTEGRACION.md`.

Todo lo demás depende de eso. **No hay ninguna tarea productiva que Claude pueda
hacer antes** salvo responder dudas.

## NO HACER

- **No repetir T-01.** Hay cinco corridas. Otra cuesta ~$1,9 y no cambia ninguna
  decisión pendiente.
- **No aumentar la n de H2.** Está declarada no confirmada y ya no bloquea nada.
- **No reinstalar ni reevaluar Serena** hasta que exista un proyecto de ≥50
  ficheros o ≥10 000 líneas.
- **No tocar UEFN** hasta que haya Beta Access.
- **No añadir MCPs "por si acaso".** El stack tiene 0 permanentes y el contexto
  de arranque sólo subió un 0,38 % en toda la misión. Eso es un logro.
- **No modificar la evidencia congelada** (§L del informe maestro): las salidas
  de run1/run2/run3a/run3b/run4, `TAREA-PATRON.md` y `PRE-REGISTRO.md`.
- **No usar `print(2 + "2")` como bug de prueba.** Luau coerciona cadenas
  numéricas. El bug válido es `print(2 + {})`.
- **No presentar la evidencia de FASE 6 como propia.** Es del usuario, en Windows.
- **No usar `--no-verify`, no desactivar gitleaks, no pedir ni escribir secretos.**
- **No arrastrar esta sesión.** Ver abajo.

## PRIMER PASO DE LA PRÓXIMA SESIÓN

**Empezar en una sesión nueva, no continuar ésta.** La misión gastó $127,17, de
los cuales sólo $6,33 fueron experimentos: el **95,7 % de todos los tokens fue
`cache_read`**, es decir, releer un historial de tres misiones acumuladas en cada
turno. Arrastrar este contexto es la partida de gasto dominante.

Concretamente, al abrir la sesión nueva:

1. Leer **sólo** este fichero y, si hace falta el detalle, el informe maestro.
2. Preguntar al usuario si ya ejecutó `instalar.sh` en su Windows.
   - **Si sí:** pedirle la salida de `./verificar.sh` y trabajar sobre lo que
     falle. Las tareas automatizables están en §J del informe maestro (formato,
     primeros tests reales, separar lógica pura, afinar CI).
   - **Si no:** no empezar trabajo nuevo. Acompañarle en W1–W7 de
     `entorno-local/WINDOWS-11-INTEGRACION.md` y parar.
3. Mantener los experimentos caros —si alguno llega a hacer falta— **en
   subproceso `claude -p` aislado**, nunca dentro de la conversación principal.
