# Tarea patrón T-01 — especificación congelada

**ID:** `T-01-inventario-persistente`
**Versión:** 1.0.0 (congelada el 25-08-2026)
**Propósito:** unidad de comparación reproducible entre fases del toolchain.

> **Regla:** esta especificación **no se modifica nunca**. Si hace falta cambiarla,
> se crea `T-02` y se reinicia la serie de mediciones. Comparar fases con
> especificaciones distintas invalida el experimento.

## Por qué esta tarea

Toca a la vez los cinco ejes que el toolchain debe mejorar:

| Eje | Cómo lo ejercita |
|---|---|
| Arquitectura servidor/cliente | Exige autoridad de servidor y validación en el borde |
| Persistencia | DataStore con semántica de sesión |
| Separabilidad para test | Exige núcleo de lógica pura sin servicios de Roblox |
| Tipado Luau | Exige `--!strict` y anotaciones |
| Estructura de proyecto | Exige disposición compatible con Rojo |

## Prompt exacto (copiar literalmente)

```
Crea un sistema de inventario para un juego de Roblox en Luau, listo para
sincronizar con Rojo. Requisitos obligatorios:

1. Núcleo de lógica PURA en un ModuleScript que no importe ningún servicio de
   Roblox: añadir item, quitar item, comprobar espacio, apilar cantidades,
   serializar y deserializar. Debe poder ejecutarse fuera de Roblox.
2. Capa de servidor que use el núcleo y persista con DataStoreService, con
   bloqueo de sesión para que dos servidores no escriban el mismo perfil.
3. API remota con validación completa en servidor: el cliente nunca decide
   cantidades ni identidades de item.
4. Capa de cliente mínima que pida el estado y lo muestre por print.
5. Todos los ficheros con --!strict y tipos explícitos en las funciones
   públicas.
6. Un fichero de tests del núcleo puro, en Luau, que se pueda ejecutar sin
   Roblox y que salga con código distinto de cero si algo falla.
7. Un default.project.json de Rojo que mapee la estructura.

Escribe los ficheros en el directorio actual. No expliques nada al final:
termina cuando los ficheros estén escritos.
```

## Métricas registradas en cada ejecución

| Métrica | Fuente | Campo |
|---|---|---|
| **Tokens** | `claude -p --output-format json` | `usage.*` (input, output, cache_creation, cache_read) |
| **Iteraciones** | idem | `num_turns` |
| **Tiempo** | idem + reloj de pared | `duration_api_ms`, `duration_ms` |
| **Coste** | idem | `total_cost_usd` |
| **Contexto de arranque** | ejecución trivial de control | `cache_creation_input_tokens` |
| **Verificación** | herramientas del toolchain | nº de comprobaciones que pasan / total disponible |

## Protocolo de ejecución

1. Directorio de trabajo vacío, fuera del repo de informes, para que el agente
   no lea documentación previa.
2. Una sola ejecución por fase. Sin reintentos, sin ayuda, sin correcciones.
3. `claude -p --output-format json` para que las métricas sean del propio
   runtime y no estimaciones.
4. Guardar el JSON completo y el árbol de ficheros producido.
5. **No optimizar el entorno para mejorar el resultado.**

## Cómo se compara entre fases

La comparación válida es, en este orden de importancia:

1. **Comprobaciones que pasan** — lo que de verdad importa.
2. **Iteraciones hasta verde** — mide convergencia.
3. **Tokens y coste** — mide eficiencia.
4. **Tiempo** — el más ruidoso; úsalo sólo como desempate.

Una herramienta que gasta un 20 % más de tokens pero converge en 3 iteraciones
en vez de 8 es una ganancia, no una pérdida.
