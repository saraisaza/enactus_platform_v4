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

   El reparto cuando se apruebe la cuota: **40 producción + 10 staging**.
   Staging no necesita capacidad de producción, y 40 + 40 no cabrían: 80
   conexiones contra ~76 útiles.

3. **`CONNECTION LIMIT` por rol en la propia base.** Aplicado el 6 de
   septiembre de 2026, y es la única de las tres medidas que **funciona hoy**:
   no depende de una cuota de AWS ni de que el código se comporte.

   | Rol | Límite | Por qué ese número |
   |---|---|---|
   | `enactus_prod_app` | 45 | 40 de concurrencia objetivo + margen para el solape de contenedores tibios, que sostienen la conexión hasta 20 s (`idle_timeout`) después de terminar |
   | `enactus_staging_app` | 15 | 10 de concurrencia objetivo + margen |
   | `enactus_admin` | 8 | Cuenta de emergencia. Ver la advertencia de abajo |

   Suman 68 contra las 76 disponibles, así que **staging no puede dejar sin
   conexiones a producción por construcción**, haga lo que haga: es
   PostgreSQL quien rechaza, no una convención que alguien pueda saltarse.

   ```bash
   # Comprobar el estado actual
   #   (por enactus-db-admin; la base no se alcanza desde afuera)
   select rolname, rolconnlimit from pg_roles where rolname like 'enactus%';
   ```

   **Cuidado con `enactus_admin`.** Es el usuario maestro de RDS y **no es
   superusuario** (`rolsuper = false`), así que el límite SÍ se le aplica y
   las 3 conexiones de `superuser_reserved_connections` **no lo protegen**:
   esas son de `rdsadmin`, que es de AWS. Si ocho sesiones administrativas
   quedaran colgadas, se pierde el acceso de emergencia a la base — y sin
   poder entrar tampoco se puede subir el límite. Por eso son 8 y no los 5
   del plan original. Para salir de ahí:

   ```sql
   -- Desde otra sesion que si haya entrado, o esperando al idle_timeout:
   select pid, usename, state, query_start from pg_stat_activity
    where usename = 'enactus_admin' order by query_start;
   select pg_terminate_backend(<pid>);
   ```

   ### Comprobado, no supuesto

   El 6 de septiembre de 2026 se bajó el límite de staging a 3 a propósito
   —para poder alcanzarlo, ya que el tope de 10 concurrentes de la cuenta
   impide abrir 20 conexiones a la vez— y se lanzaron 8 conexiones
   simultáneas con ese rol:

   ```
   lanzadas=8  abrieron=3  rechazadas=5
     rechazo: too many connections for role "enactus_staging_app"
   ```

   Durante esa saturación, producción respondió **200 en las 14 peticiones**,
   con latencia estable en ~0.30 s. Después se devolvió el límite a 15.

   Lo que esto prueba y lo que no: prueba que PostgreSQL **aplica**
   `rolconnlimit` y que el rechazo cae del lado de staging. No prueba el
   número 15 en concreto — la aplicación del límite es uniforme, no depende
   del valor.

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

## CORS: la lista de métodos tiene que seguir a la API

`allowMethods` en `src/app.ts` enumera los métodos que el navegador puede
usar. Estuvo sin `PUT` desde el principio y **ninguna de las 550 pruebas del
backend lo tocó.**

El motivo de que se escapara vale más que el fallo en sí: las pruebas de
servidor usan `app.request()`, que llama al handler directamente y **no hace
preflight**. Un `PUT` respondía 200 impecable en la suite mientras el navegador
lo bloqueaba antes de enviarlo. El síntoma en el cliente era `Failed to fetch`
y en los logs del servidor **nada**, porque la petición nunca llegó — la peor
combinación posible para diagnosticar.

Alcance real mientras estuvo mal: los catorce endpoints `PUT` que llama la
aplicación. Entre ellos, asignar estudiantes y mentores a un laboratorio,
reordenar módulos y lecciones, guardar un quiz o una actividad, editar los
miembros de un equipo y vincular cursos a la Ruta.

`tests/cors.test.ts` compara ahora la lista declarada contra los métodos que el
router registra de verdad, así que agregar un endpoint con un método nuevo sin
permitirlo rompe la suite. Para comprobarlo a mano contra el despliegue real:

```bash
curl -s -i -X OPTIONS https://api.eduxaction.com/users/x/courses \
  -H 'Origin: https://eduxaction.com' \
  -H 'Access-Control-Request-Method: PUT' | grep -i allow-
```

Tiene que responder `204` y listar `PUT` en `access-control-allow-methods`.

---

## Asignar material a un estudiante

Dos vías, **excluyentes según el tipo de cuenta** — lo decide la vista
`student_course_access`, no la pantalla:

| Tipo de cuenta | Qué recibe | Endpoint |
|---|---|---|
| eduXaction (`enactus`) | Laboratorios; el acceso a sus cursos viene incluido | `PUT /users/{id}/laboratories` |
| Open Learning | Cursos, uno por uno. Es su **única** vía de acceso | `PUT /users/{id}/courses` |

Pedir la vía que no corresponde responde `409` con el motivo, no un `200` que
no cambia nada: la vista de acceso ni siquiera mira la otra tabla, así que
guardarlo dejaría una asignación sin efecto que nadie vuelve a revisar.

En la interfaz: **Portal Admin → Usuarios → botón de asignar en la fila de la
persona**. Aparece solo en filas de estudiantes y egresados. La otra dirección
—desde el laboratorio hacia varias personas a la vez— sigue en
**Laboratorios → editar → Estudiantes**, y sirve para matricular un grupo
entero de una vez.

`PUT /users/{id}/courses` acepta cursos en borrador o no visibles, para dejar
la matrícula lista antes de publicar, y devuelve `notReady` con esos cursos.
La pantalla lo avisa: una asignación que se guarda y no se ve, sin aviso, se da
por hecha.

Las dos escrituras son **reemplazo de la lista completa**, no alta y baja de a
uno, y quedan en `audit_log` con el conjunto anterior y el nuevo:

```sql
select created_at, action, old_value, new_value
  from audit_log
 where entity_id = '<id del estudiante>'
   and action in ('student.laboratories', 'student.courses')
 order by created_at desc;
```

Quitar un laboratorio le quita el acceso a sus cursos. **El avance no se
borra**: las filas de `progress` quedan, y vuelve a verlo tal cual si se le
reasigna.

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

**No hay cambio obligatorio de contraseña al primer ingreso.** Existió —
`must_change_password`, con su endpoint, su pantalla y el bloqueo en
`requireAuth`— y se quitó por decisión de producto el 3 de septiembre de
2026: la cuenta se crea con una contraseña y esa es la que se usa, sin paso
intermedio. La columna se eliminó de la base (migración `0004`), no quedó
deshabilitada.

Esto vuelve a poner el peso entero en cómo se entrega la contraseña: la copia
en claro que se usó para entregarla —el mensaje, el papel— **sigue sirviendo
para siempre**, no solo hasta el primer ingreso. Entregarla por un canal que
se pueda borrar importa más que antes, no menos.

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

## Restaurar la base desde un snapshot

Esto **recupera la instancia entera** (las dos bases, el esquema, los datos y
—a diferencia del respaldo en JSON— **las contraseñas**). Es el camino cuando
la instancia se perdió o se corrompió. Para recuperar solo datos de la
aplicación, sigue estando el respaldo de más arriba.

### RTO medido: 10 minutos y 8 segundos

Medido de punta a punta el **6 de septiembre de 2026**, no estimado:

| Momento | Hora (UTC) | Desde el inicio |
|---|---|---|
| Se emite el comando de restauración | 02:05:50 | — |
| «Restored from snapshot» | 02:08:55 | 3 min 05 s |
| Se aplica el *parameter group* y reinicia | 02:12:47 | 6 min 57 s |
| **Primera consulta de datos que responde** | **02:15:58** | **10 min 08 s** |

Ese último número es el RTO: no sirve que la consola diga `available` si
todavía no se pueden leer datos.

**Lo que el RTO no incluye** y hay que sumarle en un incidente real: apuntar la
aplicación a la instancia nueva (cambiar `DATABASE_URL` en
`s3://enactus-secretos-158151706149/<entorno>/runtime.json` y esperar a que los
contenedores tibios de Lambda se renueven), más el tiempo humano de decidir
que hay que restaurar. **Cuente 20–25 minutos hasta volver a estar en el aire**,
no 10.

### El procedimiento, para las 2 de la mañana

```bash
export AWS_PROFILE=enactus-deploy

# 1. ¿Cuál es el snapshot más reciente? Se toman a diario, 06:30-07:00 UTC.
aws rds describe-db-snapshots --db-instance-identifier enactus-db \
  --snapshot-type automated \
  --query 'reverse(sort_by(DBSnapshots,&SnapshotCreateTime))[:3].{Id:DBSnapshotIdentifier,T:SnapshotCreateTime,S:Status}' \
  --output table

# 2. Restaurar. El nombre del snapshot va COMPLETO, con el prefijo `rds:`.
#    Los cuatro parametros de red no son opcionales: sin ellos la instancia
#    nace en la VPC por defecto, publica, y la Lambda no la alcanza.
aws rds restore-db-instance-from-db-snapshot \
  --db-instance-identifier enactus-db-restaurada \
  --db-snapshot-identifier "rds:enactus-db-AAAA-MM-DD-06-38" \
  --db-instance-class db.t4g.micro \
  --db-subnet-group-name enactus-privadas \
  --vpc-security-group-ids sg-0769694d207422246 \
  --db-parameter-group-name enactus-pg17 \
  --no-publicly-accessible --no-multi-az

# 3. Esperar. Tarda ~10 minutos; el comando devuelve solo cuando termina.
aws rds wait db-instance-available --db-instance-identifier enactus-db-restaurada

# 4. El endpoint nuevo.
aws rds describe-db-instances --db-instance-identifier enactus-db-restaurada \
  --query 'DBInstances[0].Endpoint.Address' --output text
```

**Las credenciales son las mismas del original**: el snapshot se las lleva. No
hay que crear usuarios ni volver a otorgar permisos.

### Comprobar que lo restaurado sirve, antes de apuntarle la aplicación

Un `available` no dice nada sobre los datos. Se consulta con
`enactus-db-admin` cambiándole el `host` al endpoint nuevo:

```sql
-- 1. Censo de TODAS las tablas en una sola fila, para comparar de un vistazo.
select json_object_agg(tabla, filas order by tabla)::text from (
  select t.table_name as tabla,
         (xpath('/row/c/text()', xc))[1]::text::bigint as filas
  from information_schema.tables t,
       lateral query_to_xml(format('select count(*) as c from %I.%I',
                            t.table_schema, t.table_name), false, true, '') as xc
  where t.table_schema='public' and t.table_type='BASE TABLE') s;

-- 2. Las 7 vistas tienen que EXISTIR y RESPONDER. Existir no basta: una vista
--    con una tabla rota abajo aparece en pg_views y revienta al consultarla.
select count(*) from pg_views where schemaname='public';   -- debe dar 7
select count(*) from course_progress;         select count(*) from objective_completion;
select count(*) from phase_completion;        select count(*) from phase_unlocked;
select count(*) from ruta_completion;         select count(*) from ruta_module_completion;
select count(*) from student_course_access;

-- 3. Que la gente pueda ENTRAR. Esta es la diferencia con el respaldo JSON,
--    que NO lleva los hashes: acá si van.
select count(*) from users where password_hash like '$2%';

-- 4. Las dos bases viajan en el snapshot, no solo una.
select datname from pg_database where datname like 'enactus%';
```

Resultado del ensayo del 6 de septiembre de 2026: **52 tablas, cero
diferencias** contra producción; las 7 vistas respondieron; 8 de 8 usuarios
con hash bcrypt válido; `enactus_prod` y `enactus_staging` restauradas ambas.

### Borrar la instancia de prueba

Si fue un ensayo y no un incidente, **la instancia se cobra por hora mientras
exista**. Se borra y se comprueba que ya no está:

```bash
aws rds delete-db-instance --db-instance-identifier enactus-db-restaurada \
  --skip-final-snapshot --delete-automated-backups

# La comprobacion es que este comando FALLE con DBInstanceNotFound:
aws rds describe-db-instances --db-instance-identifier enactus-db-restaurada
```

Ojo con `--skip-final-snapshot`: en una instancia de ensayo es lo correcto; si
alguna vez se corre contra una instancia con datos que importan, se pierde lo
que no esté en un snapshot anterior.

---

## Despliegue y rollback

### Cómo está armado

`main` → producción · `develop` → staging · el resto solo pasa por CI.

```
verificar (typecheck, lint, 550+ pruebas contra PostgreSQL 17 de verdad)
  → construir (api.zip, tareas.zip y DOS frontends, uno por entorno)
  → staging: migrar → publicar API → publicar frontend → humo
  → APROBACIÓN MANUAL          (solo desde main)
  → producción: migrar → publicar API → publicar frontend → humo
  → si el humo falla: rollback automático
```

El frontend se compila **dos veces** porque `API_BASE_URL` entra por
`--dart-define`, es decir en tiempo de compilación. Un solo artefacto no puede
servir a los dos entornos: apuntaría siempre a la misma API.

### El rollback: mover un alias

API Gateway **no** apunta a la función, apunta al alias `vivo`. Desplegar
publica una versión nueva y mueve el alias; volver atrás es moverlo de vuelta.

```bash
# A donde apunta ahora, y que versiones hay para volver
aws lambda get-alias --function-name enactus-api-prod --name vivo \
  --query FunctionVersion --output text
aws lambda list-versions-by-function --function-name enactus-api-prod \
  --query 'Versions[].{V:Version,D:Description,F:LastModified}' --output table

# Volver
aws lambda update-alias --function-name enactus-api-prod --name vivo \
  --function-version <N>
curl -s https://api.eduxaction.com/health
```

**Medido: 1.5 segundos**, de mover el alias a que `/health` volviera a 200.
Ensayado de verdad en staging el 6 de septiembre de 2026: se desplegó una
versión con `/health` devolviendo 500 a propósito, las pruebas de humo la
detectaron, y el rollback la deshizo.

### Lo que el rollback NO deshace

Esto es lo importante, y es mejor leerlo ahora que a las 2 de la mañana.

| | ¿Vuelve atrás? |
|---|---|
| Código de la API | **Sí**, en 1.5 s |
| Migración de esquema | **No automáticamente** |
| Frontend en S3 | **No** |
| Datos escritos por la versión mala | **No** |

**La migración.** El pipeline migra **antes** de publicar el código nuevo, a
propósito: así, entre los dos pasos, el código VIEJO corre contra el esquema
NUEVO. Eso obliga a que toda migración sea compatible hacia atrás y es lo que
hace que el rollback de código funcione — el código viejo al que se vuelve
sigue encontrando el esquema que necesita.

Agregar tablas, columnas anulables o índices es seguro. **Renombrar o borrar
una columna no lo es**: rompe el código viejo, y entonces el rollback no
sirve. Un cambio así se hace en dos despliegues (agregar lo nuevo y escribir
en ambos; en el siguiente, borrar lo viejo), nunca en uno.

Si aun así hay que revertir un esquema, `npm run db:rollback` revierte **una**
migración, la última, y puede negarse legítimamente si los datos ya no son
válidos para el esquema anterior — ver «Rollback de migraciones» más abajo.

**El frontend.** Volver atrás es volver a publicar el artefacto anterior:

```bash
gh run download <id-de-la-corrida-buena> -n artefactos   # o compilar el commit bueno
tool/desplegar_web.sh enactus-web-158151706149 E1KLNF0TNH6TPX
```

Mientras tanto conviven un frontend nuevo y una API vieja. Es tolerable un
rato —la API vieja responde 404 a lo que no conoce— pero no es un estado en
el que quedarse.

---

## Staging

| | Producción | Staging |
|---|---|---|
| Frontend | `eduxaction.com`, `www` | `staging.eduxaction.com` |
| API | `api.eduxaction.com` | `staging-api.eduxaction.com` |
| Lambda | `enactus-api-prod` | `enactus-api-staging` |
| Bucket web | `enactus-web-158151706149` | `enactus-web-staging-158151706149` |
| CloudFront | `E1KLNF0TNH6TPX` | `EEVHZXN8CN0MA` |
| Base | `enactus_prod` | `enactus_staging` |
| Usuario de base | `enactus_prod_app` (45 conexiones) | `enactus_staging_app` (15) |
| Secreto | `enactus/prod/runtime` | `enactus/staging/runtime` |
| Cabeceras | `enactus-web-seguridad` | `enactus-web-staging-seguridad` |
| Datos | reales (`seed:prod`) | demostración (`seed:demo`) |

**Esas son todas las diferencias**: dominios, secretos, datos y el tope de
conexiones. Misma región, misma VPC, mismas subredes, mismo *security group*,
mismo runtime, misma memoria, mismo timeout, mismas cabeceras de seguridad
salvo el origen que permite la CSP. Si algún día divergen en otra cosa, lo
que staging pruebe deja de significar algo sobre producción.

### La CSP no es la misma, y tiene que no serlo

`connect-src` de producción permite `https://api.eduxaction.com`; la de
staging, `https://staging-api.eduxaction.com`. Si se copiara la de producción
tal cual, el frontend de staging cargaría bien y **fallaría en silencio** al
primer intento de hablar con su API — que es exactamente el fallo de CSP que
costó una tarde entera en septiembre (ver `BLOQUEOS_INFRA.md`). Por eso las
pruebas de humo comprueban que la CSP del frontend permite el origen de SU
API, no una lista fija.

### Staging no debe ser público

Tres capas, porque fallan distinto:

1. `X-Robots-Tag: noindex, nofollow, noarchive` en la política de cabeceras de
   CloudFront — se pierde si alguien sirviera el bucket por otro camino.
2. `<meta name="robots">` en el HTML — se pierde si un buscador solo mira
   cabeceras.
3. `robots.txt` con `Disallow: /`.

Y una franja fija abajo: **ENTORNO DE PRUEBAS — DATOS DE DEMOSTRACIÓN**. Va
inyectada en el HTML por `tool/desplegar_staging.sh`, no en Flutter, para que
aparezca desde el primer byte incluso mientras la aplicación carga, y con
`pointer-events: none` para no tapar nada. Sin la franja, una captura de
staging y una de producción son indistinguibles.

Producción no enlaza a staging por ningún lado — comprobado sobre lo que
CloudFront sirve de verdad, no sobre el build local:

```bash
curl -s https://eduxaction.com/ | grep -c staging              # 0
curl -s https://eduxaction.com/main.dart.js | grep -c staging  # 0
```

### Publicar staging a mano

```bash
tool/desplegar_staging.sh          # compila, inyecta noindex y franja, sube
node backend/scripts/smoke.mjs \
  --api https://staging-api.eduxaction.com \
  --web https://staging.eduxaction.com --demo si
```

---

## Pruebas de humo

`backend/scripts/smoke.mjs` corre **contra un entorno ya desplegado**. No
sustituye a la suite de `vitest`: aquella prueba el código, esta prueba el
despliegue —que la Lambda arrancó, que alcanza la base, que CloudFront sirve,
que los permisos siguen puestos—. Fallan por motivos distintos.

Sale con código 1 si algo falla, y **ese código es el que dispara el
rollback**.

Comprueba: `/health`; que el frontend carga y trae el bundle de Flutter; que
una ruta de cliente (`/login`) no da 404; que llegan las cabeceras de
seguridad y que la CSP permite el origen de su propia API; que un video sin
firmar da 403; que CORS rechaza un origen ajeno y acepta el propio **con
`PUT` entre los métodos** (el fallo que estuvo meses sin verse); ingreso por
cada rol; que un estudiante Enactus abre su Ruta de Impacto; que un Open
Learning recibe 403 ahí mismo; que un LXD lista sus cursos; y que un token
inventado no entra.

**Las credenciales de demostración solo existen en staging.** En producción
esas pruebas se **saltan anunciándolo** si no hay `SMOKE_CUENTAS`; saltarlas
en silencio daría verde sin haber probado nada. Para cubrirlas en producción
hace falta una cuenta dedicada de solo lectura en `SMOKE_CUENTAS`
(secreto de GitHub), que **todavía no existe**.

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

## Observabilidad

### Retención de logs: 7 días

Aplicada el 6 de septiembre de 2026 a los **seis** grupos. Antes estaban
todos en `None`, que significa *para siempre*: CloudWatch crece sin techo y
cobra en silencio — sin alarma, sin aviso, hasta que aparece en la factura.

```bash
aws logs describe-log-groups \
  --query 'logGroups[].{N:logGroupName,R:retentionInDays}' --output table
```

Si alguna fila vuelve a decir `None`, es un grupo nuevo: los grupos que crea
Lambda sola nacen sin retención. **Todo servicio nuevo hay que anotarlo acá.**

```bash
aws logs put-retention-policy --log-group-name <grupo> --retention-in-days 7
```

`/aws/lambda/enactus-prueba-lectura` es huérfano —de una función que ya no
existe— y se le puso retención en vez de borrarlo: así caduca solo.

### Alarmas

Notifican al tema SNS `enactus-alarmas`.

| Alarma | Métrica | Salta cuando | Por qué ese umbral |
|---|---|---|---|
| `enactus-prod-5xx` | `AWS/ApiGateway` `5xx` (Sum) | > 5 en 5 min | Con este tráfico, 5 errores de servidor en cinco minutos ya es anormal |
| `enactus-prod-latencia-p99` | `Latency` (p99) | > 3 s, 2 periodos | Se mira p99 y no el promedio: **el promedio esconde justo a quien lo está pasando mal** |
| `enactus-rds-cpu` | `CPUUtilization` | > 80%, 15 min | Sostenido, no un pico de vacuum |
| `enactus-rds-conexiones` | `DatabaseConnections` (Max) | > 55 en 5 min | **La más importante.** 55 de 79; deja 24 de margen para reaccionar |

La de conexiones importa más que las otras porque staging y producción
comparten la instancia. Los `CONNECTION LIMIT` por rol hacen imposible que
staging agote a producción, pero **no** que producción se agote sola: esta
alarma es la que avisa de eso.

```bash
aws cloudwatch describe-alarms \
  --query 'MetricAlarms[].{N:AlarmName,E:StateValue}' --output table
```

### Falta: nadie está suscrito al tema

**Las cuatro alarmas están armadas y no le avisan a nadie todavía.** Una
alarma sin suscriptor cambia de color en una consola que nadie mira.

```bash
aws sns subscribe --topic-arn arn:aws:sns:us-east-1:158151706149:enactus-alarmas \
  --protocol email --notification-endpoint sistemas@enactuscolombia.org
```

Ese comando **envía un correo de confirmación** a esa dirección, y la
suscripción no queda activa hasta que alguien haga clic. Se dejó sin ejecutar
a propósito: es un buzón compartido de la organización. Comprobar después:

```bash
aws sns list-subscriptions-by-topic \
  --topic-arn arn:aws:sns:us-east-1:158151706149:enactus-alarmas \
  --query 'Subscriptions[].{P:Protocol,E:Endpoint,A:SubscriptionArn}' --output table
```

Si `SubscriptionArn` dice `PendingConfirmation`, el clic no se dio.

---

## CI/CD — lo que falta hacer en GitHub

La parte de AWS está puesta: el proveedor OIDC, el rol
`enactus-github-deploy` con su política, y los dos *workflows*. **La parte de
GitHub no se puede configurar por línea de comandos desde acá** (no hay `gh`
ni token), y sin ella el pipeline no se detiene donde debe.

### 1. La rama `develop`

```bash
git checkout -b develop && git push -u origin develop
```

### 2. Environments — de acá sale la aprobación manual

`Settings → Environments`:

| Environment | Ajuste |
|---|---|
| `staging` | Sin revisores. Se despliega solo. |
| `produccion` | **Required reviewers**: al menos una persona.<br>**Deployment branches**: `Selected branches` → solo `main`. |

**Sin los *required reviewers* de `produccion`, el pipeline NO se detiene y
producción se despliega sola.** El *workflow* declara `environment: produccion`
y espera ahí, pero solo si el environment tiene revisores configurados. Es el
único punto del plan que no se puede verificar desde el repositorio.

### 3. Branch protection en `main` y en `develop`

`Settings → Branches → Add rule`, para cada una:

- Require a pull request before merging
- Require status checks to pass → `Backend — typecheck, lint y pruebas` y
  `Frontend — analyze, pruebas y compilación`
- Require branches to be up to date before merging
- **Do not allow bypassing the above settings** (si no, quien tenga permiso de
  administración se la salta sin querer)
- Allow force pushes: **no** · Allow deletions: **no**

### 4. Comprobar que quedó

| Qué | Cómo se comprueba |
|---|---|
| `develop` despliega solo a staging | Push a `develop` → el job `produccion` aparece como *skipped* |
| Un PR con CI en rojo no se fusiona | Abrir un PR con una prueba rota → el botón de *merge* queda bloqueado |
| Un push directo a `main` se rechaza | `git push origin main` → `protected branch hook declined` |
| Producción exige aprobación | Push a `main` → el job `produccion` queda en *Waiting* |

### El rol de despliegue no usa llaves

La condición de confianza ya limita a este repositorio y a estas dos ramas:

```
repo:saraisaza/enactus_platform_v4:ref:refs/heads/main
repo:saraisaza/enactus_platform_v4:ref:refs/heads/develop
repo:saraisaza/enactus_platform_v4:environment:staging
repo:saraisaza/enactus_platform_v4:environment:produccion
```

No hace falta ningún secreto de AWS en GitHub. Si alguna vez aparece un
`AWS_ACCESS_KEY_ID` en `Settings → Secrets`, sobra: hay que borrarlo.

Permisos del rol (`backend/infra/iam/github-deploy.json`), acotados a lo que
el pipeline usa de verdad y a los recursos concretos, no a `*`: publicar
código y mover el alias de las dos Lambdas de API, actualizar e invocar
`enactus-db-tareas` para migrar, escribir en los dos buckets de web, invalidar
las dos distribuciones, y `sts:GetCallerIdentity`.

`lambda:UpdateFunctionCode` sobre `enactus-db-tareas` no es de más: **los
`.sql` de las migraciones viajan dentro de su propio paquete**. Con permiso
solo para invocarla, una migración nueva no se ejecutaría jamás — y el
pipeline daría verde.

---

## Fechas — cosas que funcionan hoy y fallan solas más adelante

Ninguna avisa antes. Todas se descubren el día que rompen, salvo que alguien
las mire acá.

| Cuándo | Qué pasa | Cómo comprobar que sigue bien |
|---|---|---|
| **10-sep-2026**, y cada 7 días | RDS rota la contraseña maestra | `aws secretsmanager describe-secret --secret-id <arn maestro> --query NextRotationDate` |
| **18-mar-2027** | Vence el certificado de ACM (hoy `ISSUED`, `ELIGIBLE`, en uso por **6** recursos) | `aws acm describe-certificate … --query 'Certificate.{s:Status,r:RenewalEligibility,u:InUseBy}'` |
| **antes del 1-oct-2026** | Migrar a IAM Identity Center y borrar las 2 llaves AKIA | `grep -c AKIA ~/.aws/credentials` → 0 |
| **antes de terminar 5B** | Bajar `enactus-deploy` de `PowerUserAccess` a lo que usa | `aws iam list-attached-user-policies --user-name enactus-deploy` |
| **ya pasó** | La cuenta **ya está en Paid Plan**, activa, con **US$157.67 de crédito** restante. No es una fecha futura: es el estado de hoy, comprobado el 6-sep-2026 | `aws freetier get-account-plan-state` |
| **cuando se agote el crédito** | Empieza a cobrarse de verdad. A ~US$18/mes, los 157.67 dan para unos **8-9 meses** — hasta ~mayo de 2027 | `aws freetier get-account-plan-state --query accountPlanRemainingCredits` |
| **sin fecha** | Cuota de concurrencia de Lambda: 10 → 1000. Solicitud `e13d20d68bef41fa…` en `CASE_OPENED` desde el 2-sep-2026 | `aws service-quotas list-requested-service-quota-change-history --service-code lambda` |
| **al aprobarse** | Aplicar `reserved concurrency` 40 (prod) y 10 (staging) | ver `BLOQUEOS_INFRA.md` |
| **2-dic-2062** | Vence el certificado más próximo del *bundle* de CA de RDS. Comprobado: no es un riesgo de esta década, pero el bundle se reemplaza igual si AWS publica uno nuevo | `openssl crl2pkcs7 -nocrl -certfile backend/infra/lambda-admin/rds-ca.pem \| openssl pkcs7 -print_certs -noout -text \| grep 'Not After'` |
| **cada despliegue** | Confirmar que nadie está suscrito al tema de alarmas es fácil de olvidar | `aws sns list-subscriptions-by-topic --topic-arn arn:aws:sns:us-east-1:158151706149:enactus-alarmas` |

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
