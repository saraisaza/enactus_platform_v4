# Runbook de infraestructura — Enactus Platform

Qué hay desplegado, cómo se opera y cómo se recupera. **Se escribe a medida que
las cosas existen de verdad**: cada sección afirma solo lo que se verificó
contra AWS, no lo que está planeado.

Cuenta: `158151706149` · Región principal: `us-east-1`

---

## Estado real de la infraestructura

Relevado con `aws` CLI el 1 de septiembre de 2026, revisado el 2.

| Recurso | Estado |
|---|---|
| Zona Route 53 `eduxaction.com` | ✅ `Z0527409CO28GN2VRE99` |
| Certificado ACM | ✅ emitido — ver abajo |
| Bucket S3 `enactus-media-dev` | ✅ privado, cifrado, versionado |
| Usuario IAM `enactus-s3-dev` | ✅ acotado al bucket |
| Llave de acceso de root | ✅ **borrada** (`AccountAccessKeysPresent = 0`) |
| MFA en root | ✅ **activado** (`AccountMFAEnabled = 1`, verificado 2-sep) |
| VPC `enactus-vpc` | ✅ `10.0.0.0/16`, dos subredes **privadas**, sin internet gateway |
| RDS `enactus-db` | ✅ PostgreSQL 17.11 · `db.t4g.micro` · privada · cifrada |
| Secrets Manager | ✅ `enactus/prod/runtime`, `enactus/staging/runtime` + la maestra de RDS |
| Bucket de secretos | ✅ `enactus-secretos-…` · SSE-KMS · solo lo lee la Lambda |
| Lambda `enactus-db-admin` | ✅ administración de la base privada |
| API Gateway / CloudFront | ❌ no existen |
| Alarmas de AWS Budgets | ✅ 4 avisos — ver abajo |
| Rol OIDC `enactus-github-deploy` | ✅ existe, sin llave |
| Rol `enactus-backend-lambda` | ✅ creado, con lectura de secretos acotada |

Es decir: **existe la base de datos y su red, no la aplicación.** Falta la
Lambda de la API, API Gateway y CloudFront.

---

## Base de datos

```
enactus-db.cop602mo6lg7.us-east-1.rds.amazonaws.com:5432
PostgreSQL 17.11 · db.t4g.micro · 20 GB gp3 · cifrada · us-east-1a
```

Dos bases en una sola instancia, con **un usuario por base**:

| Base | Usuario | Secreto |
|---|---|---|
| `enactus_prod` | `enactus_prod_app` (dueño) | `enactus/prod/runtime` |
| `enactus_staging` | `enactus_staging_app` (dueño) | `enactus/staging/runtime` |

El aislamiento está **comprobado, no supuesto**: `enactus_prod_app` intentando
conectarse a `enactus_staging` es rechazado, y al revés también.

### Por qué no se llega a ella desde acá

Vive en subredes privadas cuya única ruta no local es el *endpoint* de S3. No
hay internet gateway ni NAT, así que **no se puede abrir un `psql` desde un
portátil** — que es exactamente lo que se buscaba. Para operar sobre ella está
`enactus-db-admin` (más abajo).

### Las cuatro casillas, verificadas contra la instancia

```
publicamente_accesible  false
security groups         solo enactus-rds-sg, que acepta ÚNICAMENTE desde
                        enactus-lambda-sg (referencia al grupo, no un CIDR)
respaldo                7 días · ventana 06:30-07:00 UTC (01:30 en Colombia)
cifrada                 true
rotación del secreto    activa, la gestiona RDS cada 7 días
```

**`rds.force_ssl` probado de verdad.** Dentro de PostgreSQL ese parámetro no se
puede consultar, así que se comprobó por el otro lado — intentando conectarse
sin TLS:

```
con TLS  → TLSv1.3, TLS_AES_256_GCM_SHA384, con validación de CA completa
sin TLS  → no pg_hba.conf entry for host "10.0.1.60" … no encryption
```

La validación de CA no es automática: el *bundle* de RDS viaja dentro de la
Lambda (`infra/lambda-admin/rds-ca.pem`) y se usa con `rejectUnauthorized`.
Conectar con `ssl: 'require'` a secas cifra pero acepta cualquier certificado,
que es no protegerse de lo único de lo que TLS protege.

### La contraseña maestra rota sola cada 7 días

Por eso la aplicación **no la usa**: usa el usuario de su base, cuya contraseña
controlamos nosotros. Si la aplicación leyera la maestra desde una copia, esa
copia vencería antes de la semana siguiente y la API dejaría de conectar sola,
un jueves cualquiera.

La maestra queda para administración, y esas operaciones leen Secrets Manager
fresco en el momento.

---

## Los secretos van en S3, no en Secrets Manager

**Decisión de costo, con el mismo nivel de protección.** La Lambda vive en una
VPC sin NAT. Secrets Manager solo ofrece *endpoint* de tipo **Interface**, que
se cobra por hora: ~US$7 al mes por zona, más de lo que cuesta la propia base.
S3 tiene *endpoint* de tipo **Gateway**, que es **gratuito** y que la VPC ya
necesita.

```
Secrets Manager  (fuente de verdad, la escribe el pipeline)
      │  el pipeline corre FUERA de la VPC y sí la alcanza
      ▼
s3://enactus-secretos-158151706149/{prod,staging}/runtime.json   (SSE-KMS)
      │  Gateway endpoint · sin costo · sin salir a internet
      ▼
Lambda de la API — lee UNA vez por contenedor (src/lib/secretos.ts)
```

Cómo queda protegido, todo comprobado:

- La política del bucket **niega** `s3:GetObject` a todo el mundo salvo al rol
  `enactus-backend-lambda`. Comprobado: `enactus-deploy`, que tiene
  `PowerUserAccess`, recibe **403** al intentar leer.
- El `Deny` alcanza **solo la lectura de objetos**, nunca las operaciones de
  bucket. Un `Deny` más ancho dejaría el bucket inadministrable para siempre.
- `kms:Decrypt` acotado con `kms:ViaService` a S3: la llave no sirve para
  descifrar nada por fuera de este camino.
- **No hace falta endpoint de KMS**: con SSE-KMS descifra S3, no el cliente.

Servicios que la API usa en ejecución y por qué ninguno necesita un endpoint
de pago:

| Servicio | Por qué |
|---|---|
| S3 (secretos) | Gateway endpoint, gratuito |
| S3 (medios) | firmar una URL es cálculo local, sin llamada de red |
| CloudFront | firmar es cálculo local |
| CloudWatch Logs | Lambda escribe por el entorno, no por la ENI de la VPC |
| STS | las credenciales las inyecta el runtime desde el rol |
| RDS | TCP directo dentro de la VPC |

Si alguna vez hace falta un servicio que solo tenga endpoint Interface,
**decidilo antes de crearlo**: casi duplicaría el gasto fijo de la plataforma.

---

## `enactus-db-admin` — operar la base privada

La instancia no se alcanza desde afuera, así que crear bases, migrar y sembrar
pasa por esta función. Está en la VPC, con el mismo *security group* que la
API.

```bash
# El secreto se lee FRESCO en el momento; la función no guarda credenciales.
SEC=$(aws rds describe-db-instances --db-instance-identifier enactus-db \
        --query 'DBInstances[0].MasterUserSecret.SecretArn' --output text)
aws secretsmanager get-secret-value --secret-id "$SEC" --query SecretString --output text > /tmp/.sec

# … armar el payload con host, user, password, database y `statements` …
aws lambda invoke --function-name enactus-db-admin \
  --payload fileb:///tmp/payload.json /tmp/salida.json
```

Detalles que importan:

- Las credenciales llegan **en la invocación**. La función no tiene permiso
  para leer secretos, a propósito: no le hace falta, y así no puede.
- La respuesta **tapa** cualquier literal de contraseña (`PASSWORD '…'` →
  `PASSWORD '«oculta»'`) antes de devolver la sentencia o registrarla.
- `sinTls: true` existe para UNA cosa: comprobar que el servidor rechaza el
  texto plano. No debilita nada — quien decide es el servidor.
- Reempaquetar: `cd backend/infra/lambda-admin && zip -qr admin.zip index.mjs
  rds-ca.pem node_modules && aws lambda update-function-code …`

---

## Certificado TLS

```
ARN     arn:aws:acm:us-east-1:158151706149:certificate/1b73ed7f-e8ac-4ef0-bcb9-f0232fcaa0ea
Región  us-east-1   (obligatorio: CloudFront solo lee certificados de acá)
Nombres eduxaction.com  y  *.eduxaction.com
Emitido 2026-09-01 · vence 2027-03-18 · RSA-2048 · validación DNS
```

Un solo certificado cubre el ápice y todos los subdominios, así que
`api.eduxaction.com`, `staging.eduxaction.com` y `videos.eduxaction.com` no
necesitan uno propio. El comodín **no** cubre dos niveles: `a.b.eduxaction.com`
quedaría afuera.

### Dos cosas que lo rompen en silencio

**1. El registro de validación no se borra nunca.** ACM validó con un CNAME en
la zona:

```
_26dd12426e9217874e7c9a208e5fd299.eduxaction.com.  CNAME
  _80a2aa923ee91c65d19d847a739bdbfc.jkddzztszm.acm-validations.aws.
```

Parece temporal y no lo es: ACM lo vuelve a consultar en cada renovación
automática. Si alguien "limpia" la zona y lo borra, la renovación falla y el
certificado vence sin aviso útil.

**2. Hoy el certificado NO se renueva solo.** `RenewalEligibility` está en
`INELIGIBLE` porque `InUseBy` está vacío: ACM solo renueva los certificados
**asociados a un recurso**. Mientras no se enganche a CloudFront o API Gateway,
vence el 18 de marzo de 2027 y nadie se entera. Al asociarlo pasa a `ELIGIBLE`
solo.

Para comprobarlo en cualquier momento:

```bash
aws acm describe-certificate --region us-east-1 \
  --certificate-arn arn:aws:acm:us-east-1:158151706149:certificate/1b73ed7f-e8ac-4ef0-bcb9-f0232fcaa0ea \
  --query 'Certificate.{estado:Status,renovacion:RenewalEligibility,enUso:InUseBy,vence:NotAfter}'
```

`enUso` vacío después del despliegue significa que el certificado quedó
huérfano: algo se enganchó a otro.

---

## Almacenamiento — `enactus-media-dev`

| | |
|---|---|
| Block Public Access | los cuatro flags en `true` |
| Cifrado | SSE-S3 (AES256) por defecto |
| Versionado | **Enabled** |
| Acceso del backend | usuario IAM `enactus-s3-dev` — ver `backend/infra/` |

El versionado se activó el 1 de septiembre de 2026; **no estaba puesto** aunque
se daba por configurado. Ojo con el costo: las versiones viejas se cobran como
almacenamiento y no caducan solas. Cuando haya volumen real conviene una regla
de ciclo de vida que expire versiones no actuales a los 30–90 días.

---

## Presupuesto y alarmas de costo

Existe **antes** que cualquier recurso facturable, a propósito.

```
Presupuesto  enactus-mensual · US$100/mes · tipo COST
Avisos       gasto real > $20, > $50, > $100  (valor absoluto)
             PRONÓSTICO > 80% del presupuesto (≈ $80)
Destino      sistemas@enactuscolombia.org
```

El aviso por **pronóstico** es el que sirve: los tres por gasto real llegan
cuando la plata ya se gastó; el de pronóstico avisa cuando AWS proyecta que el
mes va a cerrar por encima, con días de margen para apagar algo.

```bash
aws budgets describe-notifications-for-budget \
  --account-id 158151706149 --budget-name enactus-mensual
```

---

## Identidades

Root queda **solo** para lo que exige root: facturación y cierre de cuenta.

| Identidad | Para qué | Credencial |
|---|---|---|
| `enactus-deploy` (usuario) | operar la infraestructura desde la CLI | llave en `~/.aws`, perfil `enactus-deploy` |
| `enactus-github-deploy` (rol) | el pipeline | **ninguna** — OIDC |
| `enactus-s3-dev` (usuario) | el backend en local contra S3 | llave en `backend/.env` |
| root | facturación | sin llave de acceso ✅ |

### El rol de GitHub no tiene llave

```
arn:aws:iam::158151706149:role/enactus-github-deploy
proveedor OIDC: token.actions.githubusercontent.com
```

La confianza está acotada a **ramas y entornos concretos**, no a
`repo:owner/repo:*`:

```
repo:saraisaza/enactus_platform_v4:ref:refs/heads/main
repo:saraisaza/enactus_platform_v4:ref:refs/heads/develop
repo:saraisaza/enactus_platform_v4:environment:staging
repo:saraisaza/enactus_platform_v4:environment:produccion
```

La diferencia importa: con `:*` cualquier workflow del repositorio puede
asumir el rol, incluido el que corre sobre un *pull request* — y un PR lo abre
cualquiera. Acotado a las dos ramas de despliegue, un PR no alcanza el rol
aunque el workflow lo intente.

En GitHub no hay ningún secreto de AWS que guardar: el workflow pide un token
al proveedor OIDC y lo cambia por credenciales temporales.

### `enactus-deploy` tiene `PowerUserAccess`, no administrador

`PowerUserAccess` cubre todos los servicios y **excluye IAM**. Encima lleva una
política propia (`enactus-roles-de-servicio`) que permite crear y pasar roles
**solo** bajo el prefijo `enactus-*` y los roles vinculados a servicios.

Así puede crear el rol de ejecución de la Lambda —que hace falta— pero no
crearse un usuario nuevo ni ampliarse los permisos. Comprobado:

```
$ aws iam create-user --user-name prueba-de-limite --profile enactus-deploy
AccessDenied: not authorized to perform: iam:CreateUser
```

---

## Concurrencia y conexiones

**Sin RDS Proxy.** Cuesta ~US$15/mes, más que la propia instancia
`db.t4g.micro`, y con la concurrencia esperada no aporta.

En su lugar, dos medidas que se complementan:

1. **`postgres.js` con `max: 1` y `prepare: false` en producción**
   (`src/db/connection.ts`). Cada invocación de Lambda es un proceso aislado:
   un pool grande por proceso no aporta nada y sí multiplica las conexiones.
2. **`reserved concurrency` de la Lambda fijada en 40.** Es la válvula. Sin
   ese tope, un pico crea contenedores sin límite y **cada uno abre su
   conexión**; una `db.t4g.micro` aguanta **79** —medido, no estimado— y se
   agota — y cuando se agota
   no falla solo el pico, falla todo, incluido el login de quien ya estaba
   adentro. Con el tope, es imposible por construcción: 40 contenedores × 1
   conexión = 40, algo más de la mitad del techo.

   **Hoy el tope no se puede aplicar**: la cuenta tiene un límite total de 10
   ejecuciones concurrentes y AWS exige dejar 10 sin reservar. Ver
   `BLOQUEOS_INFRA.md`. Mientras tanto ese mismo límite de 10 protege la base
   mejor que el tope de 40 — pero deja producción y staging compitiendo por
   las mismas 10, que es un riesgo distinto.

   El reparto cuando se apruebe la cuota: **40 producción + 5 staging**.
   Staging no necesita capacidad de producción, y 40 + 40 no cabrían: 80
   conexiones contra ~70 útiles.

Los prepared statements se apagan aunque con conexión directa no molesten:
si algún día hay que meter un pooler en modo transacción, se rompen ahí. Vale
más que ese cambio sea de configuración y no de código.

**Si 40 deja de alcanzar** —error `Rate Exceeded` o `429` en la Lambda, o
latencia por espera de concurrencia— la respuesta NO es subir el tope sin más:
subirlo acerca las conexiones al techo de la base. Ahí se reevalúa, en este
orden:

1. Subir a `db.t4g.small` (~US$14 más al mes, duplica memoria y conexiones).
2. Recién entonces, RDS Proxy: mantiene un pool compartido y desacopla la
   concurrencia de la Lambda del número de conexiones.

---

## Cómo se cuenta la IP del cliente

De este número dependen los dos límites de peticiones, y ponerlo mal no rompe
nada visible: **el límite simplemente deja de frenar, en silencio.**

```
TRUSTED_PROXY_HOPS = cuántos proxies de confianza hay DELANTE de la aplicación
```

`0` (el default) significa "no hay proxy": se ignora `x-forwarded-for` entera
y se usa la IP de la conexión, que el cliente no puede falsificar. Es el único
valor seguro cuando no se sabe.

Con **CloudFront → API Gateway → Lambda son 2.** Cada proxy agrega a la
derecha, así que la IP real del cliente queda a `hops` posiciones del final;
todo lo que esté más a la izquierda lo pudo haber escrito el cliente.

Esto existe porque el límite de login era esquivable: la clave salía de
`x-forwarded-for[0]`, y rotando esa cabecera pasaron 60 de 60 intentos de
fuerza bruta contra `admin@enactus.co` sin un solo 429. Ver CRÍTICO 1 en
`REVISION_FINAL.md`.

**Comprobarlo contra el despliegue real, no suponerlo.** Desde una máquina de
la que se conozca la IP pública:

```bash
curl -s https://api.eduxaction.com/health -H 'x-forwarded-for: 1.2.3.4'
# y después, en los logs de la Lambda, mirar qué IP quedó registrada:
#   la tuya  → bien
#   1.2.3.4  → TRUSTED_PROXY_HOPS está de más; el freno no sirve
```

Si el número queda mal, el freno por IP se vuelve decorativo — pero **no queda
la cuenta desprotegida**: el segundo candado del login (20 fallos por correo
cada 15 minutos) no mira la IP y sigue funcionando igual.

---

## Preparar una base de producción

`db:seed` siembra datos de DEMOSTRACIÓN y **está bloqueado en producción**
(igual que `db:reset`). Para una base real:

```bash
npm run seed:prod -- ./admins.json
```

con un archivo que **no se versiona** (está en `.gitignore` y conviene dejarlo
en `chmod 600`):

```json
[
  { "name": "Nombre Real", "email": "persona@enactuscolombia.org",
    "role": "superadmin" },
  { "name": "Otra Persona", "email": "otra@enactuscolombia.org",
    "role": "admin", "password": "la-que-eligieron" }
]
```

- **`role`** es `superadmin` o `admin`; por defecto `superadmin`. La diferencia
  que importa: solo un superadmin puede **restaurar un respaldo** encima de la
  base entera, y solo un superadmin puede crear otro superadmin. Los admin
  hacen el resto del trabajo de administración.
- **`password`** es opcional. Sin ella se genera una al azar de 24 caracteres y
  se imprime **una sola vez**. Con ella, se usa tal cual — con un piso de 12
  caracteres, más alto que los 6 que acepta `POST /users`, porque estas cuentas
  se crean antes de que exista cualquier otro control.

Deja exactamente: los 17 ODS, las 12 competencias, los 6 laboratorios con sus
3 fases vacías y sin plazos, y las cuentas de administración. Nada más — ni
proyectos, ni cursos, ni entregas, ni foro.

Se niega a correr sobre una base que ya tiene usuarios, salvo `--force`. Y
avisa —sin abortar— si dos cuentas comparten contraseña: una clave compartida
borra la diferencia entre esas cuentas, así que una filtración las compromete
todas a la vez y ninguna puede sostener después que no fue ella.

**Borrá el archivo cuando termines.** Una vez sembrada la base, las
contraseñas ya están hasheadas adentro; el archivo solo sigue siendo una copia
en claro esperando a que alguien la encuentre.

Las cuentas quedan **obligadas a cambiar la contraseña al primer ingreso**:
`seed:prod` pone `must_change_password`, y mientras esté puesta la API
responde 403 `password_change_required` a todo salvo `GET /auth/me`,
`POST /auth/change-password` y `POST /auth/logout`. La persona entra con la que
se le entregó, elige la suya, y recién ahí la plataforma le responde.

Eso hace que la copia en claro que usaste para entregarla —el mensaje, el
papel— deje de servir en cuanto la persona entra. Hasta entonces, sirve: por
eso conviene entregarlas por un canal que se pueda borrar y pedir el cambio el
mismo día.

Lo mismo vale para un restablecimiento desde administración
(`PATCH /users/{id}` con `password`): quien lo recibe queda obligado a
cambiarlo.

---

## Respaldo y restauración

```bash
# Descargar
curl -H "authorization: Bearer $TOKEN" https://api.eduxaction.com/admin/backup \
  -o respaldo.json

# Restaurar (solo superadmin, y exige la frase literal)
jq '{version, data, confirm: "REEMPLAZAR TODOS LOS DATOS"}' respaldo.json \
  | curl -X POST https://api.eduxaction.com/admin/restore \
      -H "authorization: Bearer $TOKEN" -H 'content-type: application/json' \
      --data-binary @-
```

**El archivo no lleva credenciales**: `password_hash` y los refresh tokens
quedan fuera a propósito — el respaldo termina en el portátil de alguien y un
hash bcrypt se rompe sin prisa y sin conexión.

Por eso la restauración **conserva los hashes que ya están en la base de
destino** y los vuelve a poner por id. Consecuencia práctica que hay que tener
presente a las 2 de la mañana:

- Restaurar sobre la **misma** base → todo el mundo sigue entrando con su
  contraseña de siempre.
- Restaurar sobre una base **nueva o vacía** → las cuentas se restauran pero
  **nadie puede entrar**: no hay hash de dónde sacarlas. Hay que asignar
  contraseñas nuevas.

Esto se rompió una vez y no se notó porque nadie había probado el ciclo
entero: el `insert` de `users` fallaba siempre y, al ser transaccional, no se
restauraba nada. Cubierto ahora por `tests/backup-restore.test.ts`, que
incluye *"después de restaurar, la gente puede ENTRAR"*.

---

## Rollback de migraciones

`npm run db:rollback` revierte **una** migración: la última aplicada. Ejecuta
`drizzle/down/<tag>.down.sql` dentro de una transacción y recién entonces
borra la fila del registro. Si el reverso falla, no se marca como revertida
nada — comprobado.

Probado de verdad el 2 de septiembre sobre `enactus_test`, no leído:

```
0003 revertida      → la columna desaparece
0003 re-aplicada    → vuelve, con su default
suite completa      → 538 pruebas en verde sobre esa base
```

### Un reverso que falla a propósito, y cómo salir

Intentar bajar más allá de `0002_early_stellaris` da:

```
Falló el rollback: check constraint "lessons_video_type_requires_source"
  of relation "lessons" is violated by some row
```

**No es un bug.** `0002` quitó ese CHECK justamente porque hacía imposible
subir un video propio (hay que crear la lección para poder pedir la URL
firmada, y el CHECK exigía el video ya puesto). Al revertir, el CHECK vuelve —
y si mientras tanto se creó alguna lección de video sin origen, el `ALTER`
falla. Es lo correcto: revertir no puede fingir que esos datos son válidos.

Para salir, a las 2 de la mañana:

```sql
-- 1. Ver cuáles molestan.
select id, title from lessons where type = 'video' and video_type is null;

-- 2. Decidir qué hacer con cada una: completarles el origen, o borrarlas si
--    son borradores a medio construir. NO hay una respuesta única — depende
--    de si alguien estaba subiendo un video cuando se decidió revertir.
```

Y recién entonces volver a correr `db:rollback`. La transacción no deja nada a
medias, así que se puede intentar cuantas veces haga falta.

**Lo que este rollback NO es.** Revierte el ESQUEMA, no el despliegue. El
rollback de la aplicación —volver a la versión anterior de la Lambda— no
existe todavía porque no hay Lambda; queda pendiente junto con el resto de la
infraestructura. Para recuperar DATOS, el camino es el respaldo de arriba, no
esto.

---

## Fechas — cosas que funcionan hoy y fallan solas más adelante

Ninguna avisa antes. Todas se descubren el día que rompen, salvo que alguien
las mire acá.

| Cuándo | Qué pasa | Cómo comprobar que sigue bien |
|---|---|---|
| **10-sep-2026**, y cada 7 días | RDS rota la contraseña maestra | `aws secretsmanager describe-secret --secret-id <arn maestro> --query NextRotationDate` |
| **18-mar-2027** | Vence el certificado de ACM | `aws acm describe-certificate … --query 'Certificate.{s:Status,r:RenewalEligibility,u:InUseBy}'` |
| **antes del 1-oct-2026** | Migrar a IAM Identity Center y borrar las 2 llaves AKIA | `grep -c AKIA ~/.aws/credentials` → 0 |
| **antes de terminar 5B** | Bajar `enactus-deploy` de `PowerUserAccess` a lo que usa | `aws iam list-attached-user-policies --user-name enactus-deploy` |
| **por confirmar** | Fin del plan gratuito de AWS → tarifa completa | Billing → Free Tier, en la consola |
| **sin fecha** | Cuota de concurrencia de Lambda: 10 → 1000 | `aws service-quotas get-service-quota --service-code lambda --quota-code L-B99A9384` |
| **al aprobarse** | Aplicar `reserved concurrency` 40 (prod) y 5 (staging) | ver `BLOQUEOS_INFRA.md` |
| sin fecha fija | Vence el *bundle* de CA de RDS empaquetado en las Lambdas | `openssl crl2pkcs7 -nocrl -certfile backend/infra/lambda-admin/rds-ca.pem \| openssl pkcs7 -print_certs -noout -text \| grep 'Not After'` |

### Dos formas de que el certificado venza sin que nadie se entere

**1. No se renueva si no está asociado a nada.** `RenewalEligibility` está en
`INELIGIBLE` mientras `InUseBy` esté vacío: ACM solo renueva certificados
enganchados a un recurso. Al asociarlo a API Gateway o CloudFront pasa a
`ELIGIBLE` solo.

**2. La renovación depende de un registro que parece basura.** La validación
por DNS no es de una sola vez: ACM vuelve a consultar el CNAME en **cada**
renovación automática.

```
_26dd12426e9217874e7c9a208e5fd299.eduxaction.com.  CNAME
  _80a2aa923ee91c65d19d847a739bdbfc.jkddzztszm.acm-validations.aws.
```

Ese registro parece temporal y no lo es. Si alguien «limpia» la zona y lo
borra —es exactamente lo que parece que sobra—, la renovación falla **en
silencio** y se descubre el día que el certificado expira, con el sitio caído.

```bash
aws route53 list-resource-record-sets --hosted-zone-id Z0527409CO28GN2VRE99 \
  --query "ResourceRecordSets[?Type=='CNAME' && contains(Name,'_')]"
```

Si eso devuelve vacío, la renovación automática ya está rota aunque el
certificado siga vigente.

---

## Pendiente
- **Publicar el trabajo.** `origin` ya apunta a
  `saraisaza/enactus_platform_v4` y el HEAD local está **53 commits adelante,
  0 atrás**: sería un fast-forward limpio, sin `--force`.

  No se hizo `push` todavía a propósito: la Fase 6 pide *branch protection* en
  `main` con PR obligatorio y sin push directo. Subir 53 commits directo a
  `main` sería estrenar la convención rompiéndola. El camino que corresponde:

  ```bash
  git switch -c feature/backend-y-migracion
  git push -u origin feature/backend-y-migracion
  # y abrir el PR contra main
  ```

  Hasta que exista el pipeline, el PR no tiene CI que lo valide — pero deja la
  historia revisable y `main` protegido desde el primer día.

  `v4` es el correcto — su `main` (38 commits, `01f3395`) es **ancestro
  directo** del HEAD local, que tiene esos 38 más 52 nuevos. `v2` tiene 5
  commits y una rama `gh-pages`, y no comparte esa historia.

  ```bash
  git remote set-url origin https://github.com/saraisaza/enactus_platform_v4.git
  git fetch origin
  git merge-base --is-ancestor origin/main HEAD && echo "fast-forward limpio"
  ```

  Nunca se hizo `push`, así que no hay nada publicado en el repositorio
  equivocado.
