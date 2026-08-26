# Corrección a FASE 1 — el alcance de la puerta de secretos

**Fecha de la corrección:** 25-08-2026, durante FASE 2.
**Qué corrijo:** en FASE 1 escribí que la puerta quedaba *"validada"*. **Era una afirmación
sobredimensionada.** Quedó validada contra **una sola entrada**, y esa entrada resultó ser de las
que gitleaks sí detecta.

## Cómo lo descubrí

Al preparar el commit de FASE 2, la puerta **bloqueó mi propio commit**: había puesto una clave
AWS de ejemplo en `entorno-local/WINDOWS-11.md` para que pudieras copiar la prueba negativa.

Al intentar resolverlo, cometí un segundo error y encontré el primero.

## Error nº 1 (mío): una configuración que desactivó la puerta entera

Escribí un `.gitleaks.toml` con `[extend] useDefault = true` y un `[allowlist]` con la cadena
literal, creyendo que era una excepción estrecha. Medición:

| | Resultado |
|---|---|
| Con mi `.gitleaks.toml` | `no leaks found` |
| Sin él | `leaks found: 1` |

**Mi configuración suprimía mucho más que la cadena permitida.** No llegué a determinar el
mecanismo exacto en esa versión de gitleaks; el hecho empírico basta: **la configuración rompió
la puerta**, y la borré.

**Solución adoptada:** el mecanismo documentado de gitleaks, un comentario `# gitleaks:allow` en
la línea concreta. Alcance: esa línea y nada más. Sin fichero de configuración.

> **Lección:** una configuración de seguridad que no verificas con una prueba de no-regresión es
> peor que no tener configuración. Yo escribí una y **la di por buena sin probarla**.

## Error nº 2 (el importante): la puerta no detecta todas las claves AWS

Prueba aislada, repositorio limpio, sin configuración ni allowlist, tres claves **todas
sintácticamente válidas** (`AKIA` + 16 alfanuméricos en mayúscula), todas con el mismo contexto
`AWS_ACCESS_KEY_ID=`:

| Clave | ¿Detectada? |
|---|---|
| `AKIA3QZ7…2WRT` *(clave de la prueba de FASE 1)* | ✅ **sí** (RuleID `aws-access-token`, entropía 4,121928) |
| `AKIA5H3N…7VMT` *(clave nueva, misma forma)* | ❌ **no** |
| `AKIAIOSF…MPLE` *(ejemplo de la documentación de AWS)* | ❌ no (es la clave de ejemplo de la documentación de AWS; tiene sentido que esté excluida) |

La segunda tiene la misma entropía calculada que la primera y la misma forma. **Aun así no se
detecta.** No he determinado el mecanismo — probablemente la entropía que calcula gitleaks sobre
la coincidencia completa difiere de la del literal.

### Qué significa esto en la práctica

**La puerta es real y útil:** hoy mismo bloqueó un commit mío, y detecta claves con forma
realista. **Pero no es una garantía.** Un secreto puede pasar.

Consecuencias para el plan:

1. **`gitleaks` es una red, no un muro.** Sigue siendo obligatorio no meter secretos en el repo.
2. **La prueba negativa hay que hacerla con varias claves**, no con una. Si sólo pruebas una y
   pasa, no sabes nada sobre las demás.
3. **Cuando llegue el momento de credenciales reales** —el token de Open Cloud en FASE 7— la
   defensa principal no puede ser gitleaks. Tiene que ser: el token nunca se escribe en un
   fichero del repo, vive en una variable de entorno o en el gestor de credenciales del sistema.

## Estado corregido de FASE 1

| Afirmación original | Estado corregido |
|---|---|
| «gitleaks: validada con prueba negativa» | **Parcialmente cierto.** Detecta *algunas* claves con forma válida, no todas. Probado con 1 entrada; ampliado a 3 en esta corrección |
| «pre-commit: bloquea commits» | ✅ **Confirmado dos veces**, incluida una vez contra mi propio commit |
| «osv-scanner: no verificable aquí» | Sin cambios |
| Impacto en contexto: 0 | Sin cambios |
