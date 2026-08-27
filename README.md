> ## 📌 FUENTE DE VERDAD
>
> - **[docs/INFORME-MAESTRO-MISION-2.md](docs/INFORME-MAESTRO-MISION-2.md)** — estado real y
>   final de toda la misión, con las correcciones aplicadas. **Manda sobre cualquier documento
>   anterior que lo contradiga.**
> - **[docs/NEXT-SESSION-CHECKPOINT.md](docs/NEXT-SESSION-CHECKPOINT.md)** — lo mínimo para
>   retomar el trabajo en una sesión nueva.
>
> Los documentos de fase que hay más abajo son el registro de cómo se llegó hasta aquí.
> Varios contienen conclusiones que **fueron corregidas después**; el informe maestro dice
> cuáles y por qué.

---

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
- **[fase-2-code-intelligence/](fase-2-code-intelligence/)** — luau-lsp encuentra los 10 errores de tipo que el baseline entregó. **Léase junto a su [`CORRECCION.md`](fase-2-code-intelligence/CORRECCION.md): la atribución causal del titular original era falsa.**
- **[entorno-local/WINDOWS-11.md](entorno-local/WINDOWS-11.md)** — instalación en Windows 11 (corrige las instrucciones `brew` de FASE 1).

- **[CHECKPOINT.md](CHECKPOINT.md)** — checkpoint del trabajo del 27-08 (integración).
- **[AUDITORIA-FINAL.md](AUDITORIA-FINAL.md)** · **[INTEGRACION.md](INTEGRACION.md)** · **[fase-8-serena/](fase-8-serena/)** · **[integracion/](integracion/)** — paquete instalable.
- **[fase-4-research/](fase-4-research/)** · **[fase-5-testing/](fase-5-testing/)** · **[fase-6-motor/](fase-6-motor/)** · **[fase-7-autonomia/](fase-7-autonomia/)**
