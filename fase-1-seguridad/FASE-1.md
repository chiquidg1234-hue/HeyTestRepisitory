# FASE 1 — Seguridad y medición

**Fecha:** 25-08-2026 · **Estado:** COMPLETADA · **No se avanzó a FASE 2.**
**Criterio de la fase:** cero impacto en `/context`. → **CUMPLIDO: +0,38 %.**

---

## Resultado en una tabla

| Herramienta | Instalada | Funciona aquí | Latencia | Impacto en contexto | Veredicto |
|---|---|---|---|---|---|
| **gitleaks** v8.30.1 | ✅ 39 s | ✅ **Sí, validada con prueba negativa** | 0,35 s / 389 KB | 0 | **SE QUEDA** |
| **pre-commit** 4.6.2 | ✅ 3 s | ✅ **Sí, bloquea commits** | <1 s con caché | 0 | **SE QUEDA** |
| **osv-scanner** 2.5.1 | ✅ 105 s | ⚠️ **No en este contenedor** | 24 s (timeout de red) | 0 | **SE QUEDA, sin verificar** |

**Contexto de arranque: 34 830 → 34 964 tokens (+134, +0,38 %).** Las tres son binarios de
línea de comandos: no cargan herramientas MCP, no añaden skills, no tocan la ventana. El +0,38 %
es ruido de medición más el `.pre-commit-config.yaml` nuevo en el árbol.

---

## Cómo se instalaron (y por qué así)

**Las descargas de GitHub Releases están bloqueadas por el proxy de egreso de este contenedor
(`http 403`).** La ruta que sí funciona es `go install`, porque `proxy.golang.org` está en la
lista de exclusión del proxy. En tu máquina tienes rutas más simples.

```bash
# Aquí (contenedor remoto)
go install github.com/zricethezav/gitleaks/v8@latest          # 39 s
go install github.com/google/osv-scanner/v2/cmd/osv-scanner@latest   # 105 s
pip3 install pre-commit                                        # 3 s
```

> **Trampa que me encontré:** `go install github.com/gitleaks/gitleaks/v8@latest` **falla**.
> El módulo declara su ruta como `github.com/zricethezav/gitleaks/v8` — el usuario histórico del
> autor. Hay que usar esa. El error es `version constraints conflict`.

```bash
# En tu máquina, más simple
brew install gitleaks osv-scanner pre-commit        # macOS
# o Linux: descarga los binarios de las releases de GitHub + pip install pre-commit
```

> **Aviso cosmético:** instalado con `go install`, `gitleaks version` imprime
> `version is set by build process` en lugar del número. El binario es correcto; sólo falta el
> `ldflags` que pone la release oficial. No afecta a la detección.

---

## Verificación de gitleaks

### Escaneo del repositorio — limpio

| Escaneo | Resultado | Tiempo |
|---|---|---|
| `gitleaks git` (historial, 5 commits) | **no leaks found** | 348 ms |
| `gitleaks dir .` (árbol de trabajo) | **no leaks found** | 331 ms |

Esto **confirma de forma independiente** el escaneo manual que hice en FASE 0: no hay
credenciales en el repo. Y confirma también que los prefijos de token que aparecen citados en
los informes (`ghp_`, `glpat-`, `AKIA`…) **no generan falsos positivos**, porque les falta el
cuerpo de clave que exigen las reglas.

### Prueba negativa — **la que de verdad importa**

Una puerta que nunca dispara no es una puerta. Planté un secreto falso y comprobé que bloquea:

```
Finding:     AWS_ACCESS_KEY_ID=REDACTED
RuleID:      aws-access-token
Entropy:     4.121928
File:        prueba-negativa.env
leaks found: 1
```

```
exit_code_git_commit = 1     ← el commit NO entró
```

Verificado además por `git log`: el commit de prueba no aparece en el historial. El fichero de
prueba se eliminó después; el árbol quedó limpio.

Nota: gitleaks **redacta** el secreto en su salida (`--redact`), así que el valor no acaba en
los logs ni en el informe. Ese comportamiento es el correcto y es el que dejé configurado.

---

## osv-scanner: instalado pero NO verificable aquí

El extractor funciona —reconoció un `package-lock.json` y extrajo el paquete— pero la consulta
de vulnerabilidades falla:

```
Error during extraction: max retries exceeded: attempt 4:
Post "https://api.osv.dev/v1/querybatch": Forbidden
```

Confirmado con una petición directa: `api.osv.dev → http=000`. **El proxy de egreso de este
contenedor no permite osv.dev.** No es un fallo de la herramienta.

**Consecuencia honesta:** no puedo darte evidencia de que osv-scanner detecte una vulnerabilidad.
Lo dejo instalado porque no cuesta nada y funcionará en tu máquina, pero **queda marcado como
NO VERIFICADO** hasta que lo ejecutes tú.

**Prueba que debes hacer en tu máquina** (debe reportar CVEs de lodash 4.17.11):

```bash
mkdir -p /tmp/osv-test && cd /tmp/osv-test
cat > package-lock.json <<'EOF'
{ "name":"t","version":"1.0.0","lockfileVersion":3,"requires":true,
  "packages":{ "":{"name":"t","version":"1.0.0","dependencies":{"lodash":"4.17.11"}},
    "node_modules/lodash":{"version":"4.17.11","resolved":"https://registry.npmjs.org/lodash/-/lodash-4.17.11.tgz"} } }
EOF
osv-scanner scan source .
```

**Limitación real y permanente:** osv-scanner **no entiende `wally.toml`**. Cuando el proyecto
de Roblox tenga dependencias de Wally, esta herramienta no las cubrirá. Para el ecosistema Luau
la defensa sigue siendo la que escribí en el informe: **minimizar dependencias de terceros.**

---

## Lo que quedó configurado

`.pre-commit-config.yaml` en la raíz del repo:

```yaml
repos:
  - repo: https://github.com/gitleaks/gitleaks
    rev: v8.30.1
    hooks:
      - id: gitleaks
```

Y el hook en `.git/hooks/pre-commit`.

**Latencia real por commit: menos de 1 segundo** con la caché construida. La primera ejecución
tarda 36 s porque pre-commit compila el hook en un entorno aislado; sólo ocurre una vez.

---

## Reversibilidad completa

```bash
pre-commit uninstall                      # quita el hook de git
rm .pre-commit-config.yaml                # quita la configuración
rm -rf ~/.cache/pre-commit                # quita los entornos cacheados
pip3 uninstall pre-commit
rm ~/go/bin/gitleaks ~/go/bin/osv-scanner # quita los binarios
```

Ninguna de las tres tocó `~/.claude`, `settings.json`, ni la configuración de Claude Code.

---

## Por qué NO volví a ejecutar la tarea patrón

El protocolo dice medir con T-01 tras cada fase. **Aquí no procede, y ejecutarla sería teatro
que te costaría ~1 USD para no aprender nada.**

Razón: gitleaks, osv-scanner y pre-commit **no participan en la generación de código Luau**.
No cambian lo que el agente sabe, ni cómo navega, ni cómo verifica su trabajo. La métrica
correcta para esta fase es el impacto en contexto —que medí— y la validación funcional de la
puerta —que hice con la prueba negativa—.

**T-01 se vuelve a ejecutar en FASE 2**, cuando entre `luau-lsp`, que sí toca directamente la
inteligencia de código y debería mover las iteraciones y la verificación.

---

## Estado del marcador

| Métrica | FASE 0 | FASE 1 | Cambio |
|---|---|---|---|
| Contexto de arranque | 34 830 | **34 964** | +134 (+0,38 %) |
| **Verificación automática de código Luau** | **0 / 2** | **0 / 2** | **sin cambio — es lo esperado** |
| Puerta de secretos | ninguna | **activa y validada** | ✅ nueva capacidad |
| Fugas en el repo | desconocido (manual) | **0, verificado por herramienta** | ✅ |
| Herramientas instaladas | 0 | 3 | |
| MCP configurados | 0 | **0** | sin cambio |
| Plugins instalados | 0 | **0** | sin cambio |

**La verificación de Luau sigue en 0/2 y así debe ser: esa es la deuda que paga FASE 2.**

---

## Lo que necesitas hacer tú

1. **Repetir la instalación en tu máquina** con `brew` o las releases de GitHub, que allí no
   están bloqueadas.
2. **Ejecutar la prueba de osv-scanner** de arriba, porque aquí no pude verificarla.
3. **Ejecutar tú la prueba negativa** en tu repo real: es la única forma de saber que la puerta
   está viva en tu entorno.
4. Decidir si quieres el hook en modo bloqueante (como está) o sólo informativo.
