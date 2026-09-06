#!/usr/bin/env bash
# Compila y publica el frontend de STAGING.
#
# Tres diferencias con producción, y ninguna es cosmética:
#
#   1. Apunta a `staging-api.eduxaction.com`. Si esto se equivoca, staging
#      escribe en la base de producción y nadie se entera hasta que es tarde.
#   2. Lleva `noindex` y un `robots.txt` que bloquea todo. Un entorno de
#      pruebas indexado compite con el sitio real en los buscadores y muestra
#      datos de demostración a quien buscaba la organización.
#   3. Lleva una franja visible. Sin ella, una captura de staging y una de
#      producción son indistinguibles — y alguien va a reportar como fallo de
#      producción algo que vio en staging, o peor, al revés.
#
# La franja se inyecta en el HTML y no en Flutter a propósito: así aparece
# desde el primer byte, incluso mientras la aplicación carga, y no depende de
# que el árbol de widgets llegue a construirse.
set -euo pipefail
cd "$(dirname "$0")/.."

API="${API:-https://staging-api.eduxaction.com}"
BUCKET="${BUCKET:-enactus-web-staging-158151706149}"
DIST="${DIST:-EEVHZXN8CN0MA}"

echo "compilando contra $API"
flutter build web --release --no-web-resources-cdn --dart-define=API_BASE_URL="$API"

# --- noindex ----------------------------------------------------------------
# Va además de la cabecera X-Robots-Tag que pone CloudFront. Dos capas porque
# fallan distinto: la cabecera se pierde si alguien sirve el bucket por otro
# camino, y la etiqueta se pierde si un buscador solo mira cabeceras.
python3 - <<'PY'
from pathlib import Path
p = Path("build/web/index.html")
html = p.read_text(encoding="utf-8")

meta = '<meta name="robots" content="noindex, nofollow, noarchive">'
if meta not in html:
    html = html.replace("<head>", f"<head>\n  {meta}", 1)

franja = """
  <style>
    #franja-staging {
      position: fixed; left: 0; right: 0; bottom: 0; z-index: 2147483647;
      background: #FFC107; color: #21120A;
      font: 600 12px/1.6 system-ui, -apple-system, "Segoe UI", sans-serif;
      letter-spacing: .06em; text-align: center; padding: 5px 10px;
      pointer-events: none;
    }
  </style>
  <div id="franja-staging">ENTORNO DE PRUEBAS — DATOS DE DEMOSTRACIÓN</div>
"""
if "franja-staging" not in html:
    html = html.replace("</body>", f"{franja}</body>", 1)

p.write_text(html, encoding="utf-8")
print("  index.html: noindex y franja puestos")
PY

cat > build/web/robots.txt <<'ROBOTS'
# Entorno de pruebas. No debe indexarse nada.
User-agent: *
Disallow: /
ROBOTS

BUCKET="$BUCKET" DIST="$DIST" tool/desplegar_web.sh "$BUCKET" "$DIST"

aws s3 cp build/web/robots.txt "s3://$BUCKET/robots.txt" \
  --cache-control "no-cache" --content-type "text/plain; charset=utf-8" --only-show-errors
echo "staging publicado"
