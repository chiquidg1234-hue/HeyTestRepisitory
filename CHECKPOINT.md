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
| 6 · Motor | 🔴 **BLOQUEADA** | **No** — Studio y UEFN no existen para Linux |
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

## Pendiente de intervención humana

1. **Windows:** instalar el toolchain con Scoop/Rokit (`entorno-local/WINDOWS-11.md`).
2. **`selene generate-roblox-std`** dentro del proyecto.
3. **FASE 6:** activar el MCP de Studio y ejecutar `fase-6-motor/CICLO-A-VERIFICAR.md` en un place desechable.
4. **UEFN:** Project Settings → Beta Access → UEFN MCP Toolset.
5. **Open Cloud:** crear la clave acotada al universo de desarrollo y guardarla en GitHub Secrets.
6. **`specify init`** interactivo eligiendo Claude.
7. **Verificar `srt`** en WSL2.
8. Copiar `fase-5-testing/hooks/` a `.claude/hooks/` del proyecto real y cablear `settings.json`.

## Siguiente paso

**FASE 6 requiere tu máquina.** Lo único que puedo avanzar sin ti es la comparación de Serena,
que conviene hacer *después* de FASE 6.
