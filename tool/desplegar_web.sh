#!/usr/bin/env bash
# Sube el frontend compilado a S3 y refresca CloudFront.
#
# La política de caché no es la que uno copiaría de un tutorial, y el motivo
# importa: **en un build de Flutter Web ningún archivo lleva hash en el
# nombre.** `main.dart.js` pesa 4.4 MB y siempre se llama igual, así que la
# receta habitual —"assets con hash, caché de un año"— no aplica: dejaría a
# todo el mundo con la aplicación anterior después de cada despliegue.
#
# Por eso todo lo que decide el COMPORTAMIENTO va con `no-cache`. Ojo con lo
# que significa: no es "no guardes", es "guarda pero revalida". Con ETag, una
# recarga devuelve 304 sin cuerpo — un viaje de ida y vuelta, no 4.4 MB.
#
# Solo los medios de `assets/` llevan caché larga: una imagen vieja se ve
# rara, una aplicación vieja está rota.
set -euo pipefail
cd "$(dirname "$0")/.."

BUCKET="${1:-enactus-web-158151706149}"
DIST="${2:-E1KLNF0TNH6TPX}"

[ -d build/web ] || { echo "Falta build/web. Corré primero:"; \
  echo "  flutter build web --release --dart-define=API_BASE_URL=https://api.eduxaction.com"; exit 1; }

# 1. Medios: caché larga. Van primero para que el resto los pise si hace falta.
aws s3 sync build/web "s3://$BUCKET" --delete --only-show-errors \
  --cache-control "public, max-age=604800" \
  --exclude "*" --include "assets/*" --include "icons/*" --include "canvaskit/*"

# 2. Todo lo demás: revalidar siempre.
aws s3 sync build/web "s3://$BUCKET" --delete --only-show-errors \
  --cache-control "no-cache" \
  --exclude "assets/*" --exclude "icons/*" --exclude "canvaskit/*"

# 3. index.html explícito, con su tipo. Es el que decide qué versión ve la
#    gente: si se cachea, siguen en la anterior aunque todo lo demás cambie.
aws s3 cp build/web/index.html "s3://$BUCKET/index.html" \
  --cache-control "no-cache" --content-type "text/html; charset=utf-8" --only-show-errors

# 4. Invalidación. `/*` cuenta como UNA ruta de las 1000 gratuitas al mes.
ID=$(aws cloudfront create-invalidation --distribution-id "$DIST" --paths '/*' \
  --query 'Invalidation.Id' --output text)
echo "subido · invalidación $ID"
