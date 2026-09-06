# Bloqueos y riesgos abiertos — infraestructura

Lo que está sin cerrar, con lo que hace falta para cerrarlo. Un riesgo
anotado acá **no está resuelto**: está a la vista, que es distinto.

---

## ABIERTO · Dos llaves de acceso de larga vida

**Encontrado el 2 de septiembre de 2026**, verificando el inventario contra la
afirmación «sin llaves de larga vida» del plan de despliegue.

```
llaves AKIA en ~/.aws/credentials:  2   (perfiles enactus-dev y enactus-deploy)
llaves AKIA en backend/.env:        0
llaves de acceso de root:           0
```

La afirmación era cierta a medias, y la mitad que falta importa: **no hay
llaves en el repositorio ni en los secretos de GitHub** —el pipeline usa OIDC—
pero sí hay dos en el portátil.

Encima, **`enactus-deploy` tiene `PowerUserAccess`**: todos los servicios
menos IAM. Una llave permanente con ese alcance, en un portátil, es la
credencial más peligrosa que existe hoy en el proyecto.

### Por qué no se cierra ahora

Cambiar el mecanismo de autenticación en mitad de un despliegue introduce más
riesgo del que quita. Queda en tres pasos, con fecha:

| Cuándo | Qué |
|---|---|
| **Ahora** | Bajar `enactus-deploy` de `PowerUserAccess` a estos 15 servicios (lista abajo) |
| **Antes del go-live (1-oct-2026)** | Migrar a **IAM Identity Center**: credenciales temporales por `aws sso login`, y borrar las dos llaves AKIA |

Identity Center además es **menos** fricción que una llave con MFA
condicionada: una sesión al día en vez de manejar tokens a mano.

### Los 15 servicios que `enactus-deploy` usó de verdad

Sacados de lo que se ejecutó desplegando la plataforma entera, no de una
estimación:

```
ec2              VPC, subredes, security groups, tablas de ruta, VPC endpoints, ENIs de Lambda
rds              instancias, subnet groups, parameter groups
iam              crear rol, adjuntar/poner política de rol, pasar rol (ya acotado a enactus-*)
kms              crear llave, crear alias
s3               buckets, objetos, políticas, cifrado, versionado, bloqueo público
secretsmanager   crear secreto, leer, poner versión nueva
lambda           crear/actualizar/invocar función, concurrencia, permisos de invocación
logs             leer grupos de log (CloudWatch Logs)
apigateway       HTTP APIs, integraciones, rutas, dominios personalizados, mapeos
cloudfront       distribuciones, OAC, llaves públicas, key groups, políticas de cabeceras, invalidaciones
acm              listar y describir certificados
route53          zonas y registros
budgets          leer avisos
servicequotas    consultar y pedir aumento
sts              identificar quién soy
freetier         consultar uso del nivel gratuito
```

`PowerUserAccess` da acceso a los ~400 servicios de AWS. La política acotada
sería `Allow` sobre estos 15 y nada más — con el `iam:*` que ya está limitado
al prefijo `enactus-*` por `enactus-roles-de-servicio`.

**Falta que lo aprobés antes de aplicarlo.** Recortar permisos sobre la marcha
puede romper el pipeline en el peor momento, y estos 15 salen de un despliegue
completo pero no cubren lo que todavía no existe: CI/CD, alarmas de CloudWatch
y WAF, por ejemplo, van a necesitar `cloudwatch`, `events` y `wafv2`.

### Cómo se comprueba que se cerró

```bash
aws iam list-access-keys --user-name enactus-deploy   # debe devolver vacío
aws iam list-access-keys --user-name enactus-s3-dev   # idem
grep -c AKIA ~/.aws/credentials                       # debe ser 0
```

Mientras esos tres comandos no den ese resultado, la casilla «sin access keys
de larga vida en ninguna parte» **sigue abierta**.

---

## ABIERTO · Producción no tiene el rollback conectado

**6 de septiembre de 2026.** El mecanismo de rollback quedó armado y probado
en staging (1.5 s medidos), y en producción está **a medias a propósito**:

```
alias `vivo`                     creado, en la versión 1     ✅
permiso de invocación a API GW   puesto                      ✅
integración de API Gateway       sigue en la función sin cualificar  ❌
```

Mientras la integración no apunte a `:vivo`, el paso de rollback automático
del pipeline **se ejecuta sin efecto**: mueve el alias, pero el tráfico sigue
entrando por `$LATEST`. Peor que no tenerlo, porque el *workflow* reporta que
hizo rollback.

Falta un comando:

```bash
aws apigatewayv2 update-integration --api-id qocz5bt4qa \
  --integration-id "$(aws apigatewayv2 get-integrations --api-id qocz5bt4qa \
      --query 'Items[0].IntegrationId' --output text)" \
  --integration-uri arn:aws:lambda:us-east-1:158151706149:function:enactus-api-prod:vivo

# Y comprobar en el acto que produccion sigue respondiendo:
for i in $(seq 1 6); do curl -s -o /dev/null -w '%{http_code} ' https://api.eduxaction.com/health; done
```

**Por qué no se ejecutó:** el entorno de trabajo bloqueó la modificación del
API Gateway de producción. Es una decisión razonable —cambia el camino de una
petición en vivo— y el riesgo real es bajo: el alias apunta a la versión 1,
que es byte por byte el mismo código que corre hoy. El cambio es reversible
volviendo a poner el ARN sin cualificar.

Hasta que se aplique, **el rollback de producción es manual**: hay que
redesplegar el `api.zip` anterior, que tarda minutos en vez de segundos.

---

## ABIERTO · La mitad de GitHub del CI/CD

**6 de septiembre de 2026.** En AWS está todo: proveedor OIDC, rol
`enactus-github-deploy` con su política acotada, y los dos *workflows*
escritos. En GitHub falta lo que no se puede hacer por CLI desde acá — no hay
`gh` instalado ni token disponible.

| Falta | Consecuencia si no se hace |
|---|---|
| Crear la rama `develop` | El *workflow* de staging nunca se dispara |
| Environment `produccion` con **required reviewers** | **Producción se despliega sin aprobación**: el `environment:` del job no detiene nada por sí solo |
| Environment `staging` | Menor: el job corre igual, sin la etiqueta de entorno |
| Branch protection en `main` y `develop` | Se puede empujar directo y fusionar con CI en rojo |

El pasos están en `RUNBOOK.md`, sección «CI/CD — lo que falta hacer en
GitHub», con las cuatro comprobaciones para saber que quedó.

**El más peligroso es el segundo.** Un `environment: produccion` sin revisores
configurados no espera a nadie: el *workflow* parece tener una compuerta y no
la tiene.

---

## ABIERTO · Las alarmas no le avisan a nadie

**6 de septiembre de 2026.** Las cuatro alarmas están creadas y en `OK`, con
datos reales. El tema SNS `enactus-alarmas` existe. **Cero suscriptores.**

```bash
aws sns subscribe --topic-arn arn:aws:sns:us-east-1:158151706149:enactus-alarmas \
  --protocol email --notification-endpoint sistemas@enactuscolombia.org
```

No se ejecutó porque envía un correo de confirmación a un buzón compartido de
la organización, y esa es una acción hacia afuera que corresponde autorizar.
La suscripción no queda activa hasta que alguien haga clic en ese correo.

Mientras tanto, las alarmas cambian de color en una consola que nadie mira.

---

## ABIERTO · No se puede fijar `reserved concurrency = 40`

**Encontrado el 2 de septiembre de 2026**, al aplicarlo.

```
$ aws lambda get-account-settings --query AccountLimit
{ "ConcurrentExecutions": 10, "UnreservedConcurrentExecutions": 10 }

$ aws lambda put-function-concurrency --function-name enactus-api-prod \
    --reserved-concurrent-executions 40
InvalidParameterValueException: … decreases account's
UnreservedConcurrentExecution below its minimum value of [10]
```

La cuenta tiene un tope **total de 10** ejecuciones concurrentes, no los 1000
habituales: es una restricción que AWS aplica a las cuentas nuevas hasta que
acumulan historial. Y como exige dejar 10 sin reservar, hoy **no se puede
reservar ninguna** en ninguna función.

### Lo que esto significa hoy, que no es lo que parece

El tope de 40 existía para que un pico no abriera más conexiones de las que
aguanta `db.t4g.micro`. **Ese riesgo hoy no existe, y por un motivo más
estricto:** con 10 concurrentes en toda la cuenta, es imposible pasar de 10
contenedores y por lo tanto de ~10 conexiones. El techo real de la base es 79
(medido, no estimado — ver abajo).

Lo que sí introduce es **otro** riesgo, distinto: producción y staging comparten
esas 10. Una prueba de carga contra staging puede dejar producción sin
capacidad. Con concurrencia reservada eso sería imposible; hoy no.

### Estado

```
Solicitud de aumento a 1000 · id e13d20d68bef41fabf216613e239ae7a6vDZaJMU · PENDING
```

Cuando AWS la apruebe, aplicar el tope es un comando por entorno:

```bash
aws lambda put-function-concurrency --function-name enactus-api-prod    --reserved-concurrent-executions 40
aws lambda put-function-concurrency --function-name enactus-api-staging --reserved-concurrent-executions 10
aws service-quotas get-service-quota --service-code lambda --quota-code L-B99A9384 --query 'Quota.Value'
```

**No se cierra esta entrada hasta que esos tres comandos den 40, 10 y 1000.**

### De paso: la base aguanta 79 conexiones, no ~100

`RUNBOOK.md` decía «una `db.t4g.micro` aguanta ~100». Medido sobre la instancia
real:

```
max_connections   79
en uso            9   (procesos internos de RDS y la Lambda de administración)
útiles            ~70
```

El reparto **40 + 5** cabe con margen de 24. El reparto **40 + 40** que sugería
tener dos entornos iguales **no cabe**: 80 conexiones contra 70 útiles habría
agotado la base, y no en el pico de staging sino en el de producción, que es
donde duele.

---

## RESUELTO · El `503` al firmar URLs de S3 en local

No era un fallo del código: `backend/.env` no tiene credenciales de AWS, así
que no había con qué firmar.

No hacen falta credenciales nuevas en el `.env`. El SDK las toma de
`~/.aws/credentials` por la cadena por defecto:

```bash
AWS_PROFILE=enactus-dev npm run dev
```

Documentado en `backend/README.md`. Y `backend/.env.example` **no** lleva
campos de credenciales de AWS, a propósito: tenerlos ahí invita a rellenarlos
por costumbre y a que terminen en un repositorio.

---

## RESUELTO · El frontend se quedaba cargando para siempre

**3 de septiembre de 2026.** El sitio respondía 200 a todo por `curl` y en el
navegador se quedaba en la pantalla de carga. Cuatro fallos encadenados, todos
invisibles desde la línea de comandos.

Se encontraron con Chrome headless leyendo la consola, no razonando:

```bash
"/Applications/Google Chrome.app/Contents/MacOS/Google Chrome" \
  --headless --disable-gpu --virtual-time-budget=25000 \
  --enable-logging=stderr --v=0 --screenshot=x.png --dump-dom https://eduxaction.com
```

| # | Qué pasaba | Por qué no se veía con `curl` |
|---|---|---|
| 1 | La CSP bloqueaba el `<script>` **inline** que retira el splash | El HTML llega igual; lo bloquea el navegador al ejecutarlo |
| 2 | `connect-src` bloqueaba `canvaskit.wasm` desde `gstatic` | Flutter nunca arrancaba; el DOM se queda en el splash |
| 3 | `connect-src` bloqueaba la fuente Roboto de `fonts.gstatic.com` | ídem |
| 4 | Sin `usePathUrlStrategy()`, `/login` mostraba la portada | CloudFront devuelve 200 correctamente; la ruta la resuelve Flutter |

**El primero explica el síntoma exacto.** El splash es `position: fixed;
z-index: 9999`. Flutter cargaba por debajo, pero como el script que lo retira
estaba bloqueado, la pantalla de carga se quedaba encima para siempre. Ni un
error visible, ni una pantalla en blanco: cargando, y ya.

Arreglos:

1. El script salió a `web/splash.js`. La alternativa era `'unsafe-inline'` en
   `script-src`, que abre la puerta a cualquier script inyectado. Además lleva
   una red de seguridad: si el evento `flutter-first-frame` no llega en 15
   segundos, el splash se retira igual — **es preferible una pantalla rota y
   visible a una pantalla de carga infinita**: la primera se reporta, la
   segunda se abandona.
2. `flutter build web --no-web-resources-cdn` deja CanvasKit local. Con eso
   `www.gstatic.com` sale de la CSP entera, en vez de agregarse.
3. `https://fonts.gstatic.com` va en **`connect-src`**, no solo en `font-src`:
   Flutter trae la fuente con `fetch()`, y `fetch` lo gobierna `connect-src`.
   Lo dijo la consola, no la documentación.
4. `usePathUrlStrategy()` con importación condicional, para no romper la
   compilación a iOS, Android y macOS.

**Verificado en el navegador**, no por deducción: cero violaciones de CSP,
cero errores de consola, `/login` muestra el ingreso, y un login real desde el
origen `https://eduxaction.com` contra la API de producción devuelve 200 ·
`/auth/me` 200 · `/users` 403 `password_change_required`.

### Lo que esto deja como método

`curl -I` devolviendo 200 en todo no significa que la aplicación funcione.
Para una SPA hay que abrirla en un navegador de verdad y **leer la consola**.
Los cuatro fallos eran de CSP o de enrutamiento del cliente: ninguno cambia un
código HTTP.
