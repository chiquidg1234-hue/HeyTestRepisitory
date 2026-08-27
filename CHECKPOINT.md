# CHECKPOINT GLOBAL — estado tras la ejecución nocturna

**Última actualización:** 26-08-2026 · **Rama:** `claude/github-intelligence-research-0dnet7`

## Estado por fase

| Fase | Estado | Criterio demostrado |
|---|---|---|
| 0 · Baseline | ✅ COMPLETADA | Sí — 934 029 tokens / 11 turnos / 484 s, y **0/2 de verificación** |
| 1 · Seguridad | ✅ COMPLETADA *(con corrección)* | Parcial — la puerta bloquea, pero **no detecta todas las claves** |
| 2 · Code intelligence | ✅ COMPLETADA *(con corrección grave)* | Sí, tras corregir: `luau-lsp` encuentra 10 errores reales. **La atribución causal original era falsa** |
| 3 · Rojo | ✅ COMPLETADA | H1 sí, **H2 no** |
| 4 · Research | ✅ COMPLETADA | Sí — 7/8 preguntas, 10 ms vs 435 ms |
| 5 · Testing | ✅ COMPLETADA | Sí — 14 ejecuciones con exit code observado. **Verificación 2/2** |
| 6 · Motor | ✅ **COMPLETADA (Roblox)** / 🔴 BLOQUEADA (UEFN) | **Sí** — ciclo verificado por el usuario en Windows, 4/4 casillas |
| 7 · Autonomía | 🟡 **PARCIAL** | Open Cloud sí; Spec Kit parcial; `srt` no verificable |
| — · Serena | ⏸️ No iniciada | Deliberadamente aplazada |

## Herramientas instaladas y verificadas

| Herramienta | Versión | Verificada | Nota |
|---|---|---|---|
| gitleaks | 8.30.1 | ⚠️ parcial | No detecta todas las claves AWS válidas |
| pre-commit | 4.6.2 | ✅ | Bloqueó 2 commits míos |
| osv-scanner | 2.5.1 | ❌ | `api.osv.dev` bloqueado |
| luau-lsp | 1.69.0 | ✅ | Compilado con clang (g++ 13 falla) |
| rojo | 7.7.0 | ✅ | Sourcemap idéntico al escrito a mano |
| selene | 0.31.0 | ⚠️ parcial | Sin std de Roblox (red) |
| stylua | 2.5.2 **+luau** | ✅ | **La feature `luau` es obligatoria** |
| lune | 0.10.5 | ✅ | Runner propio, 4/4 y detecta bugs |
| specify | 1.0.1 | ⚠️ parcial | Integración con Claude sin verificar |
| srt | 1.0.0 | ❌ | Namespaces anidados no permitidos |

## Métricas

| Métrica | FASE 0 | Ahora |
|---|---|---|
| **Verificación automática** | **0 / 2** | **2 / 2** |
| Errores de tipo entregados en `src/` | 10 | 0 |
| Contexto de arranque | 34 830 | 34 964 (+0,38 %) |
| MCP configurados | 0 | **0** |
| Cambios en `~/.claude` | 0 | **0** |

## Hecho por el usuario (26-08-2026)

| Acción | Estado |
|---|---|
| gitleaks, osv-scanner y pre-commit en la máquina local | ✅ hecho |
| Prueba negativa de gitleaks en el repo real | ✅ hecho |
| Prueba de osv-scanner con lodash | ✅ hecho |
| **Ciclo del motor con Studio MCP** | ✅ **hecho, 4/4 casillas** |
| **Decisión WSL2** | ✅ **SÍ, a futuro. NO bloqueante** |

**Decisión WSL2 registrada:** Windows puro no tiene sandbox nativo de Claude Code. Se adopta
WSL2 **más adelante** como entorno endurecido (Claude Code + sandbox en WSL2, Roblox Studio en
Windows). **No es requisito para FASE 6 ni para el trabajo actual**, porque está demostrado que
Claude Code en Windows conecta con Studio MCP sin él.

## Pendiente de intervención humana

1. **UEFN:** Project Settings → Beta Access → UEFN MCP Toolset. *(único bloqueo de motor)*
2. **`selene generate-roblox-std`** dentro del proyecto.
3. **Open Cloud:** clave acotada al universo de **desarrollo**, en GitHub Secrets.
4. **`specify init`** interactivo eligiendo Claude · verificar `srt` en WSL2 cuando lo adoptes.
5. Copiar `fase-5-testing/hooks/` a `.claude/hooks/` del proyecto real.
6. Borrar `BugTestScript` del place de prueba.

## Nivel de autonomía alcanzado

**Nivel 3 demostrado en Roblox** (implementar → probar → observar → corregir sin ayuda), con las
dos mitades verificadas: la estática en esta sesión (tipos + lint + tests headless, 2/2) y la del
motor en la máquina del usuario (playtest + consola + corrección).

## Siguiente paso

**FASE 6 cerrada para Roblox ⇒ la comparación de Serena queda desbloqueada.** Es el último
elemento pendiente del plan original.
