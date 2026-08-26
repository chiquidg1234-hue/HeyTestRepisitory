# GitHub Intelligence Research

Investigación independiente sobre repositorios públicos de GitHub que pueden mejorar
un entorno de Claude / Claude Code.

- **[INFORME-GITHUB-INTELLIGENCE.md](INFORME-GITHUB-INTELLIGENCE.md)** — el informe completo.
- **[datos/](datos/)** — la evidencia bruta y el script para reproducirla.

232 repositorios evaluados el 25-08-2026 con medición directa de mantenimiento
(commits, autores, licencia, CI, tests), no con estrellas.

**No se ha instalado ni ejecutado nada.** El informe es previo a cualquier cambio en el entorno.

- **[dossier.html](dossier.html)** — versión navegable del informe (fuente de la página publicada).

---

## Investigación 2 — Stack para Roblox Studio y UEFN

- **[STACK-ROBLOX-UEFN.md](STACK-ROBLOX-UEFN.md)** — arquitectura para convertir Claude Code
  en un agente de desarrollo de juegos para Roblox Studio (Luau) y UEFN (Verse).

- **[stack-roblox-uefn.html](stack-roblox-uefn.html)** — versión navegable.

75 repositorios del ecosistema medidos el 25-08-2026. Hallazgo principal: ambos editores ya
traen su propio servidor MCP integrado, y el de UEFN se lanzó el 20 de agosto de 2026.

---

## Ejecución por fases

- **[fase-0-baseline/](fase-0-baseline/)** — baseline medido y reproducible (25-08-2026).
- **[fase-1-seguridad/](fase-1-seguridad/)** — gitleaks + pre-commit + osv-scanner.
- **[fase-2-code-intelligence/](fase-2-code-intelligence/)** — luau-lsp: 10 errores de tipo encontrados en el baseline, 0 en la re-ejecución.
- **[entorno-local/WINDOWS-11.md](entorno-local/WINDOWS-11.md)** — instalación en Windows 11 (corrige las instrucciones `brew` de FASE 1).
