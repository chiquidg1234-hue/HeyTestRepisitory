# FASE 3 — Rojo + sourcemap

**Fecha:** 26-08-2026 · **Estado:** COMPLETADA · **No se avanzó a FASE 4.**
**Pre-registro:** [`PRE-REGISTRO.md`](PRE-REGISTRO.md), commiteado en `9ddc6cc` **antes** de instalar Rojo.

---

## Veredicto

| | Predicción | Resultado |
|---|---|---|
| **H1 — falsos positivos** | Confianza ALTA | ✅ **CONFIRMADA** |
| **H2 — iteraciones** | Confianza BAJA, declarada | ❌ **NO confirmada** |

**Me equivoqué en la razón por la que propuse adelantar Rojo.** Dije que reduciría iteraciones.
No lo hace. Pero encontré una razón mejor para adoptarlo, que no había previsto.

---

## Antes de los resultados: una corrección que invalida parte de FASE 2

Al abrir el transcript real de `T01-run2` —cosa que en FASE 2 no hice— descubrí que
**el agente nunca llegó a ejecutar `luau-lsp` ni una sola vez.** Los 3 intentos fueron bloqueados
por permisos.

Mi titular de FASE 2 («con luau-lsp la tarea sale con 0 errores») **era falso en su atribución
causal**. Está documentado en [`../fase-2-code-intelligence/CORRECCION.md`](../fase-2-code-intelligence/CORRECCION.md).

**Consecuencia para este experimento:** los 25 turnos de run2 no representan «luau-lsp
funcionando», sino una configuración rota. Por eso este experimento ejecuta **dos**
configuraciones nuevas, ambas con los permisos arreglados, para aislar lo que aporta Rojo de lo
que aporta simplemente que las herramientas funcionen.

---

## H1 — Falsos positivos: **CONFIRMADA**

Mismo código, sin modificar, tres condiciones:

| Código analizado | Sin sourcemap | Sourcemap escrito a mano (FASE 2) | **Sourcemap de Rojo 7.7.0** |
|---|---|---|---|
| `T01-run1` (baseline) | 14 | 10 | **10** |
| `T01-run2` | 20 | 0 | **0** |

**Clase-fantasma restante con Rojo (`Unknown require`, `not found in external type`,
`Unknown type`): 0 en ambos casos.**

Dos conclusiones:

1. **Rojo elimina por completo la clase de error irresoluble.** H1 confirmada.
2. **El sourcemap de Rojo da resultados idénticos al que escribí a mano.** Eso valida
   retroactivamente los números de FASE 2: no dependían de un sourcemap hecho a medida.

---

## H2 — Iteraciones: **NO confirmada**

Cuatro configuraciones. Las dos últimas son nuevas y tienen los permisos arreglados.

| Configuración | Turnos | Coste | Tokens | API |
|---|---|---|---|---|
| `run1` · sin herramientas | **11** | 0,974 $ | 934 029 | 479 s |
| `run2` · herramientas **bloqueadas** *(config. inválida)* | 25 | 1,211 $ | 2 077 499 | 483 s |
| `run3a` · luau-lsp funcionando, **sin** Rojo | **27** | 1,116 $ | 1 857 402 | 382 s |
| **`run3b` · luau-lsp + Rojo** | **24** | 1,153 $ | 1 888 019 | 465 s |

**Verificación previa obligatoria** (la lección de la corrección de FASE 2): en run3a y run3b el
transcript confirma **0 bloqueos de permisos**, 4 y 6 ejecuciones completadas de `analyze`
respectivamente, y 2 invocaciones de `rojo sourcemap` en run3b. **Esta vez las herramientas sí
se usaron.**

### Lectura contra las bandas pre-registradas

- Contra el baseline enmendado (`run1` = 11 turnos): **24 turnos es +118 %.** Rojo no reduce
  iteraciones frente a no tener herramientas.
- Contra la comparación que aísla Rojo (`run3a` = 27): **24 vs 27 = −11 %.** Con **n = 1** eso es
  **ruido, no evidencia**.
- Contra la banda original del pre-registro (vs 25 turnos): 24 cae en **«23–27 = inconcluso»**.

**Veredicto: H2 inconclusa tirando a negativa. Rojo no reduce las iteraciones de forma
demostrable.**

### Lo que sí es robusto en estos números

`run3a` = 27 y `run3b` = 24, frente a `run1` = 11. **Verificar cuesta aproximadamente 2,3× las
iteraciones**, y eso se repite en dos configuraciones independientes. Ese es el hallazgo sólido:
no es Rojo, **es verificar**.

Y compra: **10 errores de tipo entregados → 0 en `src/`**.

---

## El hallazgo que no había previsto, y que sí justifica adoptar Rojo

Analicé el código entregado por cada configuración **con y sin** sourcemap:

| | Sin sourcemap | Con sourcemap | Sólo `src/` |
|---|---|---|---|
| `run3a` (sin Rojo) | **32 errores** | 0 | **0** |
| `run3b` (con Rojo) | 21 errores | 2 | **0** |

Los 2 de `run3b` son ambos `Key 'exit' not found in table 'typeof(os)'` en el fichero de tests:
el agente usó `os.exit()` para cumplir el requisito 6, y **`os.exit` no existe en la API de
Roblox** — pero el test está pensado para correr *fuera* de Roblox. Es un artefacto de analizar
un fichero no-Roblox con `--platform=roblox`, no un defecto del código.

**Lo importante es la primera columna:**

> **El agente de `run3a` trabajó todo el tiempo contra 32 errores que no podía arreglar, y aun
> así declaró la tarea terminada.**

Sin Rojo, la instrucción *«no termines hasta que salga limpio»* **es imposible de cumplir**. El
agente no puede llegar a cero, así que acaba ignorando la instrucción. Con Rojo llega a 2, y esos
2 son explicables.

> ### La razón real para adoptar Rojo
> No es reducir iteraciones. Es que **sin él la señal de verificación no es accionable**: el
> agente recibe decenas de errores irresolubles y aprende a ignorar al verificador.
>
> Rojo no hace al agente más rápido. Hace que **verificar signifique algo**.

---

## Tercer hallazgo: analizar los tests con `--platform=roblox` da falsos positivos

El fichero de tests debe ejecutarse en un runtime autónomo (Lune o Lute), donde `os.exit` **sí**
existe. Analizarlo con las definiciones de Roblox produce errores que no lo son.

**Corrección de método para FASE 5:** `src/` y `tests/` necesitan invocaciones de `analyze`
distintas, o un `.luaurc` que acote las definiciones por carpeta. Lo dejo anotado como requisito
de la fase de testing.

---

## Instalación

| | |
|---|---|
| Método | `cargo install rojo --locked` (crates.io accesible; GitHub Releases sigue bloqueado) |
| Versión | **Rojo 7.7.0** |
| Ubicación | `~/.cargo/bin/rojo` |
| Reversible con | `cargo uninstall rojo` |

`~/.claude` sigue sin tocarse.

---

## El arreglo de permisos, que es transferible y obligatorio

Dos cambios respecto a FASE 2, y **ambos son necesarios**:

1. **Las definiciones de tipos se copian DENTRO del proyecto** (`./globalTypes.d.luau`). Desde
   `~/.local/share/` el agente no puede leerlas: el directorio de trabajo acota las lecturas.
2. **Los comandos se pre-aprueban:**
   `--allowedTools "Bash(luau-lsp:*)" "Bash(rojo:*)" "Bash(ls:*)" "Bash(cat:*)" "Bash(find:*)"`

Resultado medido: **0 bloqueos de permisos**, frente a 6 en run2.

---

## CHECKPOINT — estado al cerrar FASE 3

| | FASE 0 | FASE 1 | FASE 2 | **FASE 3** |
|---|---|---|---|---|
| Herramientas instaladas | 0 | 3 | 4 | **5** |
| Verificación de tipos disponible | ❌ | ❌ | ✅ | ✅ |
| **Verificación accionable por el agente** | ❌ | ❌ | ❌ *(permisos)* | ✅ |
| Errores entregados en `src/` | 10 | — | — | **0** |
| Contexto de arranque | 34 830 | 34 964 | 34 964 | sin cambio (binarios CLI) |
| MCP configurados | 0 | 0 | 0 | **0** |
| Cambios en `~/.claude` | 0 | 0 | 0 | **0** |

**Verificación automática: 1 / 2.** Falta ejecutar los tests → FASE 5 (Lune o Lute).

---

## Limitaciones

1. **n = 1 por configuración.** Declarado en el pre-registro. Para convertir H2 en evidencia
   harían falta 3–5 ejecuciones por configuración, a ~1,15 USD cada una (≈ 7 USD).
2. Las cuatro ejecuciones produjeron **estructuras de proyecto distintas**, lo que introduce
   variabilidad que no controlo.
3. Sigue siendo un contenedor efímero.
4. El plugin LSP sigue **sin probarse dentro de una sesión interactiva**.

---

## Corrección (27-08-2026)

Este documento dice, sobre los 2 errores de `os.exit` en el código entregado por
`run3b`:

> *«Es un artefacto de analizar un fichero no-Roblox con `--platform=roblox`, no
> un defecto del código.»*

**Es falso.** `os.exit` **tampoco existe en Lune**. Al ejecutar esa suite se
comprobó que pasa sus 27 comprobaciones y a continuación revienta con
`attempt to call a nil value` en `os.exit(0)`: **nunca podía dar verde**, así que
incumplía el requisito 6 de la TAREA-PATRON. Era un defecto real, no un artefacto.

Lo que sí sigue siendo válido de este documento: analizar tests de Lune con
`--platform=roblox` **sí** produce falsos positivos en general; simplemente, éste
no era uno de ellos. El corte correcto en Lune es
`require("@lune/process").exit(n)`.

Ver `docs/INFORME-MAESTRO-MISION-2.md` §D-9.
