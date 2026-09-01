#!/usr/bin/env python3
"""Captura las respuestas REALES del backend y las guarda como fixtures.

`test/portals_render_test.dart` monta los ocho portales contra una API falsa.
Si esa API inventara los payloads, la prueba mediría la maquetación de datos
que el servidor no devuelve nunca — y una pantalla puede dibujarse perfecto
con datos imaginarios y romperse con los de verdad.

Por eso los fixtures NO se escriben a mano: se capturan de la base sembrada,
con la cuenta que de verdad puede ver cada cosa, y se regeneran cuando el
contrato cambia.

    cd backend && npm run db:reset && npm run dev
    python3 tool/capturar_payloads.py

Genera `test/fixtures/api_payloads.json`.
"""

import json
import os
import pathlib
import sys
import urllib.error
import urllib.request

BASE = os.environ.get("ENACTUS_API", "http://localhost:3000")

# Las mismas credenciales del seed que ya usa `e2e_provider_contract_test`.
CUENTAS = {
    "superadmin": ("superadmin1@enactus.co", "Super123"),
    "admin": ("admin@enactus.co", "Admin123"),
    "lxd": ("lxd.ia@enactus.co", "Lxd123"),
    "mentor": ("mentor.ia@enactus.co", "Mentor123"),
    "advisor": ("asesor@uniandes.edu.co", "Asesor123"),
    "company": ("empresa@bancolombia.com", "Empresa123"),
    "donor": ("donante@gmail.com", "Donante123"),
    "student": ("estudiante1@uniandes.edu.co", "Est123"),
    "alumni": ("alumni1@uniandes.edu.co", "Alumni123"),
}

# Rutas que piden los portales, y con qué cuentas intentarlas EN ORDEN.
#
# El orden importa: se queda con la primera respuesta 200 que traiga datos.
# Una pantalla vacía y una poblada son maquetaciones distintas, y la que más
# se rompe es la poblada — así que se prefiere la cuenta que ve contenido.
RUTAS = [
    ("/site-content", ["student"]),
    ("/catalogs", ["student"]),
    ("/admin/metrics", ["superadmin"]),
    ("/users?pageSize=100&include=team,progress", ["superadmin"]),
    ("/projects?pageSize=100", ["superadmin"]),
    ("/groups?pageSize=100", ["superadmin"]),
    ("/laboratories?pageSize=100", ["superadmin"]),
    ("/courses?pageSize=100", ["student", "superadmin"]),
    ("/certificates?pageSize=100", ["superadmin", "student"]),
    ("/submissions?pageSize=100", ["superadmin"]),
    ("/evidences?pageSize=100", ["superadmin"]),
    ("/calendar-events?pageSize=100", ["student", "superadmin"]),
    ("/forum-posts?pageSize=100", ["student"]),
    ("/forum-posts/stats", ["student"]),
    ("/communication-resources?pageSize=100", ["superadmin"]),
    ("/talent?pageSize=100", ["superadmin"]),
    ("/notifications?pageSize=100", ["student", "superadmin"]),
]


def pedir(metodo, ruta, token=None, cuerpo=None):
    req = urllib.request.Request(BASE + ruta, method=metodo)
    req.add_header("content-type", "application/json")
    if token:
        req.add_header("authorization", "Bearer " + token)
    datos = json.dumps(cuerpo).encode() if cuerpo is not None else None
    try:
        with urllib.request.urlopen(req, datos, timeout=20) as r:
            return r.status, json.loads(r.read().decode())
    except urllib.error.HTTPError as e:
        try:
            return e.code, json.loads(e.read().decode())
        except Exception:
            return e.code, None
    except Exception as e:
        print(f"  ✗ {ruta}: {e}", file=sys.stderr)
        return 0, None


def tiene_datos(cuerpo):
    """Una página con `data` vacía cuenta como 'sin datos'."""
    if isinstance(cuerpo, dict) and isinstance(cuerpo.get("data"), list):
        return len(cuerpo["data"]) > 0
    return cuerpo is not None


def main():
    estado, _ = pedir("GET", "/health")
    if estado != 200:
        print(
            f"Backend apagado en {BASE}. Levantalo con: cd backend && npm run dev",
            file=sys.stderr,
        )
        return 1

    tokens, usuarios = {}, {}
    for rol, (correo, clave) in CUENTAS.items():
        estado, cuerpo = pedir(
            "POST", "/auth/login", cuerpo={"email": correo, "password": clave}
        )
        if estado != 200:
            print(f"No se pudo entrar como {rol} ({estado}).", file=sys.stderr)
            return 1
        tokens[rol] = cuerpo["accessToken"]
        usuarios[rol] = cuerpo["user"]
        print(f"  ✓ sesión {rol}")

    compartidas = {}
    estados = {}
    for ruta, candidatos in RUTAS:
        camino = ruta.split("?")[0]
        elegido = None
        for rol in candidatos:
            estado, cuerpo = pedir("GET", ruta, tokens[rol])
            if estado == 200:
                elegido = (rol, cuerpo)
                if tiene_datos(cuerpo):
                    break
        if elegido is None:
            print(f"  ✗ {camino}: ninguna cuenta la pudo leer", file=sys.stderr)
            return 1
        rol, cuerpo = elegido
        compartidas[camino] = cuerpo
        n = len(cuerpo["data"]) if isinstance(cuerpo, dict) and isinstance(
            cuerpo.get("data"), list
        ) else "objeto"
        print(f"  ✓ {camino}  ({rol}, {n})")

    # Detalles por id. Una pestaña que muestra una tarjeta suele pedir después
    # el detalle de cada elemento, y sin estas respuestas la prueba de
    # maquetación se queda sin la mitad de lo que dibuja.
    for camino, incluir in [
        ("/courses", "modules,lessons,ods"),
        ("/laboratories", "phases,ods"),
        ("/projects", "team,ods"),
        ("/groups", "members"),
        ("/users", "team,progress,reviews"),
    ]:
        pagina = compartidas.get(camino)
        if not isinstance(pagina, dict):
            continue
        for fila in pagina.get("data", []):
            ident = fila.get("id")
            if not ident:
                continue
            for rol in ("superadmin", "student"):
                estado, cuerpo = pedir(
                    "GET", f"{camino}/{ident}?include={incluir}", tokens[rol]
                )
                if estado == 200:
                    compartidas[f"{camino}/{ident}"] = cuerpo
                    break
        n = sum(1 for k in compartidas if k.startswith(camino + "/"))
        print(f"  ✓ {camino}/:id  ({n} detalles)")

    # Progreso por (estudiante, curso). Lo piden las pantallas de seguimiento
    # de Mentor, Asesor y LXD, una por cada estudiante que muestran.
    estudiantes = [
        u["id"]
        for u in compartidas["/users"]["data"]
        if u.get("role") in ("student", "alumni")
    ]
    cursos = [c["id"] for c in compartidas["/courses"]["data"]]
    n = 0
    for est in estudiantes:
        for curso in cursos:
            ruta = f"/students/{est}/course-progress/{curso}"
            estado, cuerpo = pedir("GET", ruta, tokens["superadmin"])
            if estado == 200:
                compartidas[ruta] = cuerpo
                n += 1
    print(f"  ✓ /students/:id/course-progress/:cursoId  ({n})")

    # URL firmada de descarga. Es un POST con la key en el cuerpo; el fake
    # responde por camino, así que alcanza con una.
    llaves = set()

    def buscar_llaves(o):
        if isinstance(o, dict):
            for k, v in o.items():
                if k.endswith("S3Key") or k == "s3Key":
                    if isinstance(v, str) and v:
                        llaves.add(v)
                buscar_llaves(v)
        elif isinstance(o, list):
            for x in o:
                buscar_llaves(x)

    buscar_llaves(compartidas)
    llave = sorted(llaves)[0] if llaves else None
    if llave:
        estado, cuerpo = pedir(
            "POST", "/files/download-url", tokens["superadmin"], {"key": llave}
        )
        compartidas["/files/download-url"] = cuerpo
        if estado != 200:
            # Se guarda el fallo REAL, no un 200 inventado. Hoy este entorno
            # devuelve 503 porque S3 no está configurado, y `AppImage` degrada
            # a su marcador de posición — que es exactamente lo que ve la
            # gente. Fingir un 200 acá probaría una pantalla que no existe.
            estados["/files/download-url"] = estado
            print(f"  ! /files/download-url: HTTP {estado} (S3 sin configurar)")
        else:
            print("  ✓ /files/download-url")

    # La Ruta de Impacto es por estudiante: se guarda la del estudiante del
    # seed, que tiene avance parcial (fase 1 en 1/2 módulos) — el estado más
    # interesante de dibujar.
    sid = usuarios["student"]["id"]
    estado, ruta_progreso = pedir("GET", f"/students/{sid}/ruta-progress", tokens["student"])
    if estado != 200:
        print(f"  ✗ ruta-progress: HTTP {estado}", file=sys.stderr)
        return 1
    print(f"  ✓ /students/:id/ruta-progress  ({len(ruta_progreso['laboratories'])} labs)")

    salida = pathlib.Path(__file__).resolve().parent.parent / "test/fixtures"
    salida.mkdir(parents=True, exist_ok=True)
    destino = salida / "api_payloads.json"
    destino.write_text(
        json.dumps(
            {
                "_generado_por": "tool/capturar_payloads.py contra la base sembrada",
                "compartidas": compartidas,
                "estados": estados,
                "me": usuarios,
                "rutaProgress": ruta_progreso,
            },
            ensure_ascii=False,
            indent=2,
        )
        + "\n",
        encoding="utf-8",
    )
    print(f"\nEscrito {destino.relative_to(destino.parent.parent.parent)}")
    return 0


if __name__ == "__main__":
    sys.exit(main())
