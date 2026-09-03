#!/usr/bin/env bash
# Empaqueta la API para Lambda.
#
# Se usa esbuild y no un `npm install --production` dentro del zip: el paquete
# sin bundlear pesa unos 40 MB —el SDK de AWS solo son 30— y Lambda cobra el
# arranque en frío en tiempo de descompresión. Bundleado baja a ~2 MB.
#
# `--packages=bundle` mete TODO, incluido el SDK de AWS. Podría excluirse
# porque el runtime lo trae, pero AWS lo ha ido sacando de runtimes nuevos sin
# aviso, y descubrirlo en producción no vale los 2 MB que ahorra.
set -euo pipefail
cd "$(dirname "$0")/.."

rm -rf dist-lambda && mkdir -p dist-lambda

npx esbuild src/lambda.ts \
  --bundle \
  --platform=node \
  --target=node22 \
  --format=esm \
  --packages=bundle \
  --outfile=dist-lambda/index.mjs \
  --banner:js="import{createRequire}from'node:module';const require=createRequire(import.meta.url);" \
  --log-level=warning

# El bundle de CA viaja al lado: la conexión valida el certificado de RDS
# contra él (ver `tlsDeRds()` en src/db/connection.ts).
cp infra/rds-ca.pem dist-lambda/rds-ca.pem

cd dist-lambda && zip -qr ../infra/api.zip . && cd ..
echo "infra/api.zip  $(du -h infra/api.zip | cut -f1)"

# --- Lambda de tareas de base de datos ---------------------------------------
# Lleva el codigo real de la aplicacion: el migrador de Drizzle y los dos
# seeds. Asi lo que corre en produccion es lo mismo que se probo en local.
rm -rf dist-tareas && mkdir -p dist-tareas

npx esbuild src/lambda-tareas.ts \
  --bundle --platform=node --target=node22 --format=esm --packages=bundle \
  --outfile=dist-tareas/index.mjs \
  --banner:js="import{createRequire}from'node:module';const require=createRequire(import.meta.url);" \
  --log-level=warning

cp infra/rds-ca.pem dist-tareas/rds-ca.pem
# El migrador lee los .sql en tiempo de ejecucion desde ./drizzle, relativo al
# directorio de trabajo — que en Lambda es /var/task.
cp -R drizzle dist-tareas/drizzle

cd dist-tareas && zip -qr ../infra/tareas.zip . && cd ..
echo "infra/tareas.zip  $(du -h infra/tareas.zip | cut -f1)"
