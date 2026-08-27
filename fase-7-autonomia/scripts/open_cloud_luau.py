#!/usr/bin/env python3
"""Ejecuta un script Luau en un place real vía Open Cloud Luau Execution API.

SIN CREDENCIALES EMBEBIDAS. La clave se lee de la variable de entorno
ROBLOX_OPEN_CLOUD_KEY y nunca se imprime, ni se registra, ni se escribe a disco.

Límites documentados por Roblox: 5 min por tarea, 10 tareas concurrentes por place.
Uso:  python3 open_cloud_luau.py <fichero.luau>
"""
import os, sys, json, time, urllib.request, urllib.error

API = "https://apis.roblox.com/cloud/v2"

def _need(name: str) -> str:
    v = os.environ.get(name)
    if not v:
        sys.exit(f"ERROR: falta la variable de entorno {name}. "
                 "No se ha configurado el secreto; nada que hacer.")
    return v

def _post(url: str, key: str, body: dict) -> dict:
    req = urllib.request.Request(
        url, data=json.dumps(body).encode(),
        headers={"x-api-key": key, "Content-Type": "application/json"}, method="POST")
    with urllib.request.urlopen(req, timeout=60) as r:
        return json.load(r)

def _get(url: str, key: str) -> dict:
    req = urllib.request.Request(url, headers={"x-api-key": key})
    with urllib.request.urlopen(req, timeout=60) as r:
        return json.load(r)

def _fallo_http(e: "urllib.error.HTTPError") -> int:
    """Mensaje limpio. Nunca imprime la clave: solo el codigo y el motivo."""
    motivos = {401: "clave invalida o revocada",
               403: "la clave no tiene el permiso universe.place.luau-execution-session:write "
                    "o no cubre este universo",
               404: "universo o place inexistente, o la API no esta habilitada",
               429: "limite de peticiones alcanzado"}
    print(f"ERROR HTTP {e.code}: {motivos.get(e.code, e.reason)}", file=sys.stderr)
    return 1


def main() -> int:
    if len(sys.argv) < 2:
        sys.exit("uso: open_cloud_luau.py <fichero.luau>")
    key = _need("ROBLOX_OPEN_CLOUD_KEY")          # nunca se imprime
    universe, place = _need("ROBLOX_UNIVERSE_ID"), _need("ROBLOX_PLACE_ID")
    script = open(sys.argv[1], encoding="utf-8").read()

    try:
        task = _post(f"{API}/universes/{universe}/places/{place}/luau-execution-session-tasks",
                     key, {"script": script})
    except urllib.error.HTTPError as e:
        return _fallo_http(e)
    except urllib.error.URLError as e:
        print(f"ERROR de red: {e.reason}", file=sys.stderr)
        return 1
    path, deadline = task["path"], time.time() + 300   # 5 min: límite de la API
    while time.time() < deadline:
        try:
            st = _get(f"{API}/{path}", key)
        except urllib.error.HTTPError as e:
            return _fallo_http(e)
        if st.get("state") in ("COMPLETE", "FAILED"):
            logs = _get(f"{API}/{path}/logs", key)
            for chunk in logs.get("luauExecutionSessionTaskLogs", []):
                for line in chunk.get("messages", []):
                    print(line)
            if st["state"] == "FAILED":
                print("FALLO:", json.dumps(st.get("error", {}))[:400], file=sys.stderr)
                return 1
            out = st.get("output", {}).get("results")
            print("RESULTADO:", json.dumps(out)[:400] if out else "(sin valor de retorno)")
            return 0
        time.sleep(5)
    print("TIMEOUT: la tarea superó los 5 minutos", file=sys.stderr)
    return 1

if __name__ == "__main__":
    raise SystemExit(main())
