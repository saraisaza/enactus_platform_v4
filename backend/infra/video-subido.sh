#!/usr/bin/env bash
# Lo que AWS necesita para que «Subir video» funcione en las lecciones.
#
#   backend/infra/video-subido.sh             revisa y dice qué falta; no cambia nada
#   backend/infra/video-subido.sh --aplicar   además aplica lo que falte
#
# El pipeline no puede hacer nada de esto: su rol no tiene permisos de IAM, ni
# de CORS, ni de ciclo de vida, ni sobre las políticas de cabeceras de
# CloudFront, y está bien que no los tenga. Se corre a mano, con el perfil de
# administración (`enactus-deploy` si no se elige otro con AWS_PROFILE).
#
# Todo es aditivo: no quita ningún permiso, ningún origen de CORS, ninguna
# regla de ciclo de vida ni ninguna fuente de la CSP que ya estén. Se puede
# correr las veces que haga falta.
#
# Qué es cada cosa y por qué: backend/infra/README.md, «Video subido».
#
# Escrito para el bash 3.2 de macOS: sin arreglos asociativos ni "${a[@]}"
# vacíos, que con `set -u` revientan ahí.
set -uo pipefail

APLICAR=0
case "${1:-}" in
  --aplicar) APLICAR=1 ;;
  '') ;;
  *) echo "uso: $0 [--aplicar]" >&2; exit 2 ;;
esac

export AWS_PROFILE="${AWS_PROFILE:-enactus-deploy}"
export AWS_DEFAULT_REGION=us-east-1
export AWS_PAGER=""

INFRA="$(cd "$(dirname "$0")" && pwd)"
CSP_JS="$INFRA/../scripts/csp-video.mjs"
BUCKET=enactus-media-dev
ROL=enactus-backend-lambda
POLITICA_ROL=enactus-video-subido
VPCE=vpce-01fd4eef0b54f6287
TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT

pendientes=0
ok()     { printf '  ✔ %s\n' "$*"; }
falta()  { printf '  ✘ %s\n' "$*"; pendientes=$((pendientes + 1)); }
hecho()  { printf '  → %s\n' "$*"; pendientes=$((pendientes - 1)); }
aviso()  { printf '  ! %s\n' "$*"; }
titulo() { printf '\n%s\n' "$*"; }
vacio()  { [ -z "$(printf '%s' "$1" | tr -d '[:space:]')" ]; }

for programa in aws node curl; do
  command -v "$programa" > /dev/null || { echo "falta $programa en el PATH" >&2; exit 2; }
done

titulo "Credencial (perfil $AWS_PROFILE)"
if ! quien="$(aws sts get-caller-identity --query Arn --output text 2>&1)"; then
  echo "  ✘ no hay credenciales: $quien" >&2
  exit 1
fi
ok "$quien"
[ "$APLICAR" = 1 ] || aviso "solo se revisa; nada cambia sin --aplicar"

# ---------------------------------------------------------------------------
titulo "1. Permisos del rol de la Lambda ($ROL) sobre s3://$BUCKET/lessons/"
# Antes la API solo FIRMABA (un cálculo local). Ahora abre la subida por
# partes, pregunta qué partes llegaron, la cierra, mira el tamaño final y
# borra los videos reemplazados: llamadas de verdad, cada una con su permiso.
ACCIONES="s3:PutObject s3:GetObject s3:DeleteObject s3:AbortMultipartUpload s3:ListMultipartUploadParts"
sin_permiso=""
rol_arn="$(aws iam get-role --role-name "$ROL" --query Role.Arn --output text 2> /dev/null || true)"
if [ -n "$rol_arn" ] && simulado="$(aws iam simulate-principal-policy \
      --policy-source-arn "$rol_arn" \
      --action-names $ACCIONES \
      --resource-arns "arn:aws:s3:::$BUCKET/lessons/0/prueba.mp4" \
      --query 'EvaluationResults[?EvalDecision!=`allowed`].EvalActionName' \
      --output text 2> /dev/null)"; then
  sin_permiso="$(printf '%s' "$simulado" | tr '\t' ' ' | sed 's/None//g')"
  if vacio "$sin_permiso"; then
    ok "el rol ya puede: $ACCIONES"
  else
    falta "al rol le falta: $sin_permiso"
  fi
elif aws iam get-role-policy --role-name "$ROL" --policy-name "$POLITICA_ROL" > /dev/null 2>&1; then
  ok "la política $POLITICA_ROL está puesta"
else
  sin_permiso="?"
  falta "no se pudo simular el rol y la política $POLITICA_ROL no está"
fi
if ! vacio "$sin_permiso" && [ "$APLICAR" = 1 ]; then
  if aws iam put-role-policy --role-name "$ROL" --policy-name "$POLITICA_ROL" \
       --policy-document "file://$INFRA/iam/lambda-video-subido.json"; then
    hecho "política $POLITICA_ROL puesta en $ROL (se suma a las que ya tenía)"
  else
    aviso "no se pudo: hace falta un perfil con iam:PutRolePolicy sobre $ROL"
  fi
fi

# ---------------------------------------------------------------------------
titulo "2. CORS del bucket: el navegador sube cada parte directo a S3"
URL_S3="https://$BUCKET.s3.us-east-1.amazonaws.com/lessons/0/prueba.mp4"
preflight() { # origen [cabeceras pedidas]
  if [ -n "${2:-}" ]; then
    curl -s -o /dev/null -w '%{http_code}' -X OPTIONS "$URL_S3" \
      -H "Origin: $1" -H 'Access-Control-Request-Method: PUT' \
      -H "Access-Control-Request-Headers: $2"
  else
    curl -s -o /dev/null -w '%{http_code}' -X OPTIONS "$URL_S3" \
      -H "Origin: $1" -H 'Access-Control-Request-Method: PUT'
  fi
}
revisar_cors() {
  local malos="" origen
  for origen in https://eduxaction.com https://www.eduxaction.com https://staging.eduxaction.com; do
    # Las partes van sin cabeceras; la portada, con content-type.
    [ "$(preflight "$origen")" = 200 ] || malos="$malos $origen(partes)"
    [ "$(preflight "$origen" content-type)" = 200 ] || malos="$malos $origen(portada)"
  done
  printf '%s' "$malos"
}
malos="$(revisar_cors)"
if vacio "$malos"; then
  ok "S3 acepta el PUT desde los tres dominios"
else
  falta "S3 rechaza el preflight de:$malos"
  if [ "$APLICAR" = 1 ]; then
    if aws s3api put-bucket-cors --bucket "$BUCKET" \
         --cors-configuration "file://$INFRA/s3-cors.json"; then
      sleep 5
      if vacio "$(revisar_cors)"; then
        hecho "CORS aplicado desde s3-cors.json, y el preflight ya pasa"
      else
        aviso "CORS aplicado, pero el preflight todavía falla: revisar s3-cors.json"
      fi
    else
      aviso "no se pudo aplicar el CORS"
    fi
  fi
fi

# ---------------------------------------------------------------------------
titulo "3. Ciclo de vida: subidas que nadie terminó y videos ya borrados"
# `put-bucket-lifecycle-configuration` REEMPLAZA todas las reglas: se leen las
# que haya y se agregan las de s3-lifecycle.json que falten, por ID.
if aws s3api get-bucket-lifecycle-configuration --bucket "$BUCKET" --output json \
     > "$TMP/ciclo-actual.json" 2> "$TMP/error"; then
  leido=1
elif grep -q NoSuchLifecycleConfiguration "$TMP/error"; then
  echo '{"Rules":[]}' > "$TMP/ciclo-actual.json"
  leido=1
else
  leido=0
  aviso "no se pudo leer el ciclo de vida: $(cat "$TMP/error")"
fi
if [ "$leido" = 1 ]; then
  node -e '
    const fs = require("fs");
    const actuales = JSON.parse(fs.readFileSync(process.argv[1], "utf8")).Rules ?? [];
    const nuestras = JSON.parse(fs.readFileSync(process.argv[2], "utf8")).Rules;
    const faltan = nuestras.filter((r) => !actuales.some((a) => a.ID === r.ID));
    console.error(faltan.map((r) => r.ID).join(", "));
    process.stdout.write(JSON.stringify({ Rules: [...actuales, ...faltan] }, null, 2));
    process.exit(faltan.length ? 0 : 3);
  ' "$TMP/ciclo-actual.json" "$INFRA/s3-lifecycle.json" > "$TMP/ciclo-nuevo.json" 2> "$TMP/faltan"
  case $? in
    3) ok "las dos reglas de s3-lifecycle.json están" ;;
    0)
      falta "faltan reglas: $(cat "$TMP/faltan")"
      if [ "$APLICAR" = 1 ]; then
        if aws s3api put-bucket-lifecycle-configuration --bucket "$BUCKET" \
             --lifecycle-configuration "file://$TMP/ciclo-nuevo.json"; then
          hecho "reglas agregadas; las que ya había siguen igual"
        else
          aviso "no se pudo aplicar el ciclo de vida"
        fi
      fi
      ;;
    *) aviso "no se pudo combinar el ciclo de vida: $(cat "$TMP/faltan")" ;;
  esac
fi

# ---------------------------------------------------------------------------
titulo "4. Endpoint de S3 de la VPC ($VPCE): la Lambda ahora sí llama a S3"
# La Lambda no tiene salida a internet: llega a S3 solo por este endpoint. Si
# su política estuviera acotada al bucket de secretos, cada llamada al de
# medios moriría con AccessDenied. No se cambia solo: se avisa.
if aws ec2 describe-vpc-endpoints --vpc-endpoint-ids "$VPCE" \
     --query 'VpcEndpoints[0].PolicyDocument' --output text > "$TMP/vpce.json" 2> "$TMP/error"; then
  veredicto="$(node -e '
    const p = JSON.parse(require("fs").readFileSync(process.argv[1], "utf8"));
    const lista = (x) => (Array.isArray(x) ? x : [x]);
    const st = lista(p.Statement ?? []);
    if (st.some((s) => s.Effect === "Deny")) { console.log("deny"); process.exit(0); }
    const todos = (pr) => pr === "*" || (pr && pr.AWS === "*");
    const abierta = st.some((s) => s.Effect === "Allow" && todos(s.Principal) &&
      lista(s.Action).some((a) => a === "*" || a === "s3:*") &&
      lista(s.Resource).includes("*"));
    const texto = JSON.stringify(p);
    console.log(abierta ? "abierta" : texto.includes(process.argv[2]) ? "menciona" : "cerrada");
  ' "$TMP/vpce.json" "$BUCKET" 2> /dev/null)"
  case "$veredicto" in
    abierta) ok "la política del endpoint deja pasar todo S3" ;;
    menciona) aviso "la política está acotada y nombra $BUCKET: confirmar que deje las acciones del paso 1" ;;
    deny) aviso "la política tiene un Deny: confirmar que no alcance a $BUCKET" ;;
    *) falta "la política del endpoint no deja pasar $BUCKET (ver README, «Video subido»)" ;;
  esac
else
  aviso "no se pudo leer el endpoint: $(cat "$TMP/error")"
fi

# ---------------------------------------------------------------------------
titulo "5. CSP del frontend: el reproductor, la portada y la vista previa"
for nombre in enactus-web-seguridad enactus-web-staging-seguridad; do
  id="$(aws cloudfront list-response-headers-policies --type custom \
    --query "ResponseHeadersPolicyList.Items[?ResponseHeadersPolicy.ResponseHeadersPolicyConfig.Name=='$nombre'].ResponseHeadersPolicy.Id | [0]" \
    --output text 2> /dev/null || true)"
  if [ -z "$id" ] || [ "$id" = None ]; then
    aviso "no encontré la política de cabeceras $nombre"
    continue
  fi
  if ! aws cloudfront get-response-headers-policy-config --id "$id" --output json \
         > "$TMP/$nombre.json" 2> "$TMP/error"; then
    aviso "no se pudo leer $nombre: $(cat "$TMP/error")"
    continue
  fi
  node "$CSP_JS" < "$TMP/$nombre.json" > "$TMP/$nombre-nueva.json" 2> "$TMP/$nombre-cambios.txt"
  case $? in
    3) ok "$nombre ya tiene todo" ;;
    0)
      falta "$nombre necesita:"
      sed 's/^/      /' "$TMP/$nombre-cambios.txt"
      if [ "$APLICAR" = 1 ]; then
        etag="$(node -e 'console.log(JSON.parse(require("fs").readFileSync(process.argv[1], "utf8")).ETag)' "$TMP/$nombre.json")"
        if aws cloudfront update-response-headers-policy --id "$id" --if-match "$etag" \
             --response-headers-policy-config "file://$TMP/$nombre-nueva.json" > /dev/null; then
          hecho "$nombre actualizada; CloudFront la sirve en unos minutos, sin invalidar nada"
        else
          aviso "no se pudo actualizar $nombre"
        fi
      fi
      ;;
    *) falta "$nombre: $(cat "$TMP/$nombre-cambios.txt")" ;;
  esac
done

# Lo que de verdad le llega al navegador. Justo después de aplicar puede
# tardar unos minutos en verse.
for sitio in https://eduxaction.com https://staging.eduxaction.com; do
  curl -sI "$sitio/" | tr -d '\r' \
    | sed -n 's/^[Cc][Oo][Nn][Tt][Ee][Nn][Tt]-[Ss][Ee][Cc][Uu][Rr][Ii][Tt][Yy]-[Pp][Oo][Ll][Ii][Cc][Yy]: //p' \
    > "$TMP/servida.txt"
  if node "$CSP_JS" --revisar < "$TMP/servida.txt" 2> "$TMP/faltan"; then
    ok "$sitio ya sirve la CSP con todo"
  else
    aviso "$sitio todavía sirve una CSP sin: $(tr '\n' ' ' < "$TMP/faltan")"
  fi
done

# ---------------------------------------------------------------------------
titulo "Resumen"
if [ "$pendientes" -le 0 ]; then
  echo "  Nada pendiente en AWS para subir videos."
  exit 0
fi
if [ "$APLICAR" = 0 ]; then
  echo "  Faltan $pendientes cosas. Para aplicarlas: $0 --aplicar"
else
  echo "  Quedaron $pendientes sin aplicar; el detalle está arriba."
fi
exit 1
