#!/usr/bin/env bash
# Compila la app para las tiendas: Android (App Bundle para Google Play) o iOS
# (IPA para App Store Connect / TestFlight).
#
#   CORREO_SOPORTE=soporte@ejemplo.org tool/build_movil.sh android [número]
#   CORREO_SOPORTE=soporte@ejemplo.org tool/build_movil.sh ios     [número]
#
# [número] es el número de compilación (`versionCode` en Android,
# `CFBundleVersion` en iOS). Cada subida a una tienda necesita uno MAYOR que el
# anterior; sin él se usa el que dice `pubspec.yaml` después del `+`.
#
# Lo que este script garantiza, y por eso existe en vez de escribir el comando
# a mano cada vez (ver docs/movil/PUBLICACION.md):
#
# - La app apunta a la API de producción, por https. Sin `API_BASE_URL`, la app
#   apuntaría a `http://localhost:3000`; `lib/main.dart` se niega a arrancar
#   así en una versión de tienda, pero es mejor no llegar a compilarla.
# - Lleva el correo de soporte, que el foro necesita publicar (App Store, 1.2).
# - El código va ofuscado, y los símbolos para leer los reportes de fallos
#   quedan aparte, en build/simbolos/. NO se suben a ninguna parte ni van al
#   repositorio: guárdelos junto a la versión que publicó.
# - Android no se compila sin la llave de subida: un paquete firmado con la
#   llave de depuración lo rechaza Google Play.
set -euo pipefail
cd "$(dirname "$0")/.."

PLATAFORMA="${1:-}"
NUMERO="${2:-}"
API_BASE_URL="${API_BASE_URL:-https://api.eduxaction.com}"

uso() {
  sed -n '2,10p' "$0" | sed 's/^# \{0,1\}//'
  exit 1
}

[ -n "$PLATAFORMA" ] || uso

case "$API_BASE_URL" in
  https://*) ;;
  *) echo "API_BASE_URL tiene que empezar por https:// (dice: $API_BASE_URL)." >&2; exit 1 ;;
esac

if [ -z "${CORREO_SOPORTE:-}" ]; then
  echo "Falta el correo de soporte. Compile así:" >&2
  echo "  CORREO_SOPORTE=correo@dominio tool/build_movil.sh $PLATAFORMA" >&2
  exit 1
fi

if [ -n "$NUMERO" ] && ! [[ "$NUMERO" =~ ^[0-9]+$ ]]; then
  echo "El número de compilación tiene que ser un entero (dice: $NUMERO)." >&2
  exit 1
fi

SIMBOLOS="build/simbolos/$PLATAFORMA"
OPCIONES=(
  --release
  --obfuscate
  "--split-debug-info=$SIMBOLOS"
  "--dart-define=API_BASE_URL=$API_BASE_URL"
  "--dart-define=CORREO_SOPORTE=$CORREO_SOPORTE"
)
[ -n "$NUMERO" ] && OPCIONES+=("--build-number=$NUMERO")

case "$PLATAFORMA" in
  android)
    if [ ! -f android/key.properties ]; then
      echo "Falta android/key.properties (la llave de subida de Google Play)." >&2
      echo "Cómo crearla: docs/movil/PUBLICACION.md, sección «Llave de firma de Android»." >&2
      exit 1
    fi
    flutter build appbundle "${OPCIONES[@]}"
    echo
    echo "Listo: build/app/outputs/bundle/release/app-release.aab"
    echo "Súbalo en Google Play Console › Prueba › Prueba cerrada (o interna)."
    ;;
  ios)
    flutter build ipa "${OPCIONES[@]}"
    echo
    echo "Listo: build/ios/ipa/"
    echo "Súbalo con la app Transporter, o desde Xcode › Window › Organizer."
    ;;
  *)
    uso
    ;;
esac

echo "Símbolos de esta versión: $SIMBOLOS (guárdelos; no van al repositorio)."
