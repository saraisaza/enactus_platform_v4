# Infraestructura de AWS

Los archivos de esta carpeta son **configuración, no secretos**. Ninguna llave,
ningún token.

Los secretos van en dos lugares distintos, y conviene no mezclarlos:

- **Los que la aplicación lee** (`JWT_SECRET`, `CLOUDFRONT_PRIVATE_KEY`) — en
  `backend/.env` en local, en Secrets Manager en AWS.
- **Las credenciales de AWS** — en `backend/.env` en local y **en ningún lado**
  en AWS: las inyecta el runtime de Lambda desde el rol de ejecución. Ver
  "La Lambda SÍ tiene `AWS_ACCESS_KEY_ID` en su entorno", más abajo.

---

## `s3-policy.json` — el usuario IAM del backend

Política acotada al bucket `enactus-media-dev`, para reemplazar la llave de
root que se venía usando.

El par de ARN está bien puesto, que es donde falla casi siempre: las acciones
sobre **objetos** van contra `arn:aws:s3:::enactus-media-dev/*` y las que son
sobre el **bucket** contra `arn:aws:s3:::enactus-media-dev`, sin la barra. Con
un solo ARN para las dos, `ListBucket` no funciona nunca.

### Qué usa el código, hoy

`src/lib/s3.ts` firma; `src/lib/media-storage.ts` (el video subido de las
lecciones) además **llama** a S3:

| Acción | Para qué |
|---|---|
| `s3:PutObject` | firmar la URL de subida (`POST /files/upload-url`, la portada del video); abrir y cerrar la subida por partes del video (`CreateMultipartUpload`, `CompleteMultipartUpload`) y firmar cada parte (`UploadPart`) |
| `s3:GetObject` | firmar la URL de lectura (`POST /files/download-url`); mirar el tamaño del video ya cerrado (`HeadObject`) |
| `s3:ListMultipartUploadParts` | preguntarle a S3 qué partes llegaron, en vez de creerle al navegador (`ListParts`) |
| `s3:AbortMultipartUpload` | cancelar una subida, para que sus partes no queden cobrando |
| `s3:DeleteObject` | borrar el video y la portada que se reemplazaron, o los de una lección borrada (`DeleteObjects`) |
| `s3:ListBucket` | que `HeadObject` de una key que no existe dé 404 y no 403 |

El archivo **nunca pasa por la API**: el navegador hace `PUT` directo contra la
URL firmada. API Gateway corta el payload en 10 MB y un video lo revienta.

### Lo que la política concede de más, y por qué está bien dejarlo

- **`s3:ListBucket`** — nada lista el bucket, pero conviene tenerlo igual: sin
  este permiso, un `GET` sobre una key que no existe devuelve **403
  AccessDenied** en vez de **404 NoSuchKey**. Con las URLs firmadas que se le
  entregan al navegador, eso convierte "esa imagen no está" en "no tiene
  permiso", que es una pista falsa cada vez que haya que depurar algo.

- **`s3:DeleteObject`** — se usa solo para los videos de las lecciones (ver
  «Video subido»). Para todo lo demás sigue el hueco de la aplicación, no de
  la política: **los borrados solo eliminan la fila de la base**. Borrar una
  evidencia, una imagen de la galería o un recurso deja el archivo en el bucket
  para siempre. No queda accesible —`authorizeFileRead` resuelve la key contra
  la fila que la referencia, y sin fila responde 404— pero sigue almacenado, y
  "borrado" en la pantalla no significa borrado de verdad. Para una evidencia
  de un donante eso importa. El permiso conviene dejarlo puesto para poder
  cerrar ese hueco sin volver a tocar IAM.

- **`s3:ListBucketMultipartUploads`** — nada lista las subidas a medias: las
  que nadie termina las descarta el ciclo de vida (`s3-lifecycle.json`). Es
  inofensivo.

Firmar una URL es un cálculo local y el permiso se evalúa recién cuando
alguien la usa; las llamadas de `media-storage.ts`, en cambio, fallan en el
acto si falta el permiso (503 `storage_unavailable`, con el `AccessDenied` de
S3 en el log).

### Se puede acotar más

Si se quiere apretar el alcance, las keys que genera el backend viven en nueve
prefijos conocidos (`src/routes/files.ts` y `src/lib/s3.ts`):

```
avatars/  covers/  evidences/  lesson-resources/  lessons/
site-gallery/  submissions/  communication-resources/  course-intros/
```

Restringir `Resource` a esos prefijos es más estricto, pero hay que acordarse
de agregarlo acá cada vez que aparezca uno nuevo — y si se olvida, el fallo
aparece recién en producción al subir. El backend ya valida la key antes de
firmar, así que el prefijo es una segunda defensa, no la única.

### Cómo se aplica

El mismo documento de política se usa de dos formas distintas según dónde
corra el backend. **Solo una de las dos tiene llave.**

**En local — usuario IAM con llave:**

```bash
aws iam create-user --user-name enactus-backend-dev
aws iam put-user-policy \
  --user-name enactus-backend-dev \
  --policy-name enactus-media-dev-s3 \
  --policy-document file://backend/infra/s3-policy.json
aws iam create-access-key --user-name enactus-backend-dev
```

La llave que devuelve el último comando va a `backend/.env`
(`AWS_ACCESS_KEY_ID` / `AWS_SECRET_ACCESS_KEY`). **Nunca al repositorio.**

**En AWS — el mismo JSON, pero sobre el ROL de ejecución de la Lambda:**

```bash
aws iam put-role-policy \
  --role-name enactus-backend-lambda \
  --policy-name enactus-media-dev-s3 \
  --policy-document file://backend/infra/s3-policy.json
```

Acá no se crea ninguna llave y **no se guarda ninguna en Secrets Manager**.
Secrets Manager es para `JWT_SECRET` y `CLOUDFRONT_PRIVATE_KEY`, que sí son
secretos que la aplicación necesita leer; las credenciales de AWS no.

#### La Lambda SÍ tiene `AWS_ACCESS_KEY_ID` en su entorno

Vale la pena decirlo explícito, porque "usa un rol" se lee fácil como "no tiene
credenciales" — y de ahí a ponérselas a mano hay un paso.

El runtime de Lambda inyecta `AWS_ACCESS_KEY_ID`, `AWS_SECRET_ACCESS_KEY` y
`AWS_SESSION_TOKEN` en cada invocación, derivadas del rol de ejecución. Son
**temporales y se rotan solas**, y el SDK las toma del entorno sin que haya que
configurar nada.

Lo que **no** se puede hacer es declararlas como variables de entorno propias
de la función: Lambda reserva esos tres nombres y rechaza el deploy. Y aunque
se pudiera, meter ahí la llave larga del usuario de desarrollo cambiaría una
credencial temporal y rotada por una permanente — al revés de lo que se busca.

Después, y esto es la mitad que importa:

```bash
aws iam list-access-keys --user-name <root-o-el-usuario-viejo>
aws iam delete-access-key --access-key-id <la-vieja>
```

Crear el usuario acotado no reduce nada mientras la llave vieja siga viva.

---

## `s3-cors.json` — qué páginas pueden subir al bucket

El navegador hace el `PUT` **directo** contra `enactus-media-dev`, desde otro
origen que la página. Antes de mandar el archivo hace un *preflight*
(`OPTIONS`), y si el bucket no lista ese origen S3 responde 403 y el archivo
no sale nunca. En la pantalla se ve como "se interrumpió la conexión"; en la
API no queda **nada**, porque la petición nunca llegó.

Hasta el 3 de octubre de 2026 el bucket solo aceptaba `http://localhost:8080`:
en local todo subía, y desde `eduxaction.com` no subía ningún archivo.

El pipeline **no** aplica este archivo — el rol de GitHub no tiene
`s3:PutBucketCORS`, a propósito. Se aplica a mano, con `enactus-deploy`:

```bash
aws s3api put-bucket-cors --bucket enactus-media-dev \
  --cors-configuration file://backend/infra/s3-cors.json \
  --profile enactus-deploy
```

`put-bucket-cors` **reemplaza** la configuración entera: lo que no esté en el
archivo deja de valer. Por eso `localhost:8080` sigue en la lista.

Para comprobarlo (no hace falta credencial; el preflight es anónimo):

```bash
curl -s -o /dev/null -w '%{http_code}\n' -X OPTIONS \
  https://enactus-media-dev.s3.us-east-1.amazonaws.com/lesson-resources/x.png \
  -H 'Origin: https://eduxaction.com' \
  -H 'Access-Control-Request-Method: PUT' \
  -H 'Access-Control-Request-Headers: content-type'
```

Tiene que dar `200`. Un `403` es que el origen no está en la lista.

Un dominio nuevo para el frontend se agrega acá **y** se vuelve a aplicar;
`tests/s3-firma.test.ts` exige que los tres dominios actuales estén.

---

## Video subido

El LXD sube el video de una lección desde el navegador, en partes de 8 MiB, y
la API arma el archivo en S3. **Es la primera vez que la Lambda llama a S3
de medios**: hasta acá solo firmaba URLs, que es un cálculo local. Eso trae
cinco cosas que el pipeline no puede poner —su rol no tiene permiso, a
propósito— y que se aplican a mano:

```bash
backend/infra/video-subido.sh             # revisa, y dice qué falta
backend/infra/video-subido.sh --aplicar   # además aplica lo que falte
```

Usa el perfil `enactus-deploy` (u otro con `AWS_PROFILE=...`). Todo es
aditivo: no quita ningún permiso, origen, regla ni fuente que ya esté, y se
puede correr las veces que haga falta. Se aplica **antes** de aprobar el
despliegue a producción: nada de esto le cambia nada al código de hoy.

| # | Qué | Archivo | Si falta |
|---|---|---|---|
| 1 | Permisos del rol `enactus-backend-lambda` sobre `lessons/*` | `iam/lambda-video-subido.json` | La subida llega al 100 % y «Guardar» falla con 503: sin `s3:ListMultipartUploadParts` la API no puede confirmar las partes |
| 2 | CORS del bucket | `s3-cors.json` | Ninguna parte sale del navegador (403 en el preflight) |
| 3 | Ciclo de vida del bucket | `s3-lifecycle.json` | Funciona igual, pero lo cancelado y lo borrado se sigue cobrando |
| 4 | Política del endpoint de S3 de la VPC | — (solo se revisa) | Cada llamada de la Lambda a S3 da `AccessDenied` |
| 5 | CSP del frontend, en las dos políticas de cabeceras | `scripts/csp-video.mjs` | El reproductor, la portada y la vista previa no cargan |

**1. Permisos.** Va como una política **aparte** (`enactus-video-subido`) en
vez de reemplazar `enactus-media-dev-s3`: `put-role-policy` reemplaza la
política del mismo nombre entera, y si la que está puesta tuviera algo que no
está en `s3-policy.json` (el bucket de secretos, por ejemplo) se perdería y la
API dejaría de arrancar. Sumar una política nueva no puede quitar nada.
`s3-policy.json` también se actualizó, para el día que se reaplique completa.

**2. CORS.** `s3-cors.json` (ver arriba) ya alcanza: las partes del video van
con un `PUT` sin cabeceras y la portada con `content-type`. El script prueba
los dos preflights desde los tres dominios.

**3. Ciclo de vida.** Dos reglas:

- `subidas-por-partes-sin-terminar`: S3 descarta, a los 7 días, una subida por
  partes que nadie cerró ni canceló (la pestaña que se cerró a mitad). Siete y
  no uno, para que el LXD pueda retomar después de un fin de semana.
- `videos-de-lecciones-borrados`: el bucket tiene **versionado**, así que
  borrar un objeto solo le pone una marca encima y la versión vieja se sigue
  cobrando. Esta regla elimina las versiones viejas de `lessons/` a los 30
  días. Es también la ventana para recuperar un video borrado por error.

`put-bucket-lifecycle-configuration` reemplaza todas las reglas: el script lee
las que haya y agrega las que falten, por ID, sin tocar las demás.

**4. El endpoint.** La Lambda no tiene salida a internet y llega a S3 solo por
`vpce-01fd4eef0b54f6287`. Con la política por defecto (todo S3) no hay nada
que hacer. Si alguna vez se acotó al bucket de secretos, hay que agregar una
declaración para `arn:aws:s3:::enactus-media-dev` y `.../*`; el script avisa
pero no la toca, porque una política de endpoint mal puesta corta también la
lectura de los secretos, y con eso la API entera.

**5. La CSP.** Lo que pide el navegador, en `enactus-web-seguridad` y en
`enactus-web-staging-seguridad` (las dos usan el mismo CDN de video):

```
media-src  … https://videos.eduxaction.com blob:
img-src    … https://videos.eduxaction.com
```

`media-src` es para el `<video>` del reproductor y, con `blob:`, para la vista
previa del editor y la portada automática, que salen del archivo local. Si
`media-src` no existe, el script la crea copiando lo de `default-src` primero,
para que lo que hoy pasa por herencia siga pasando. `connect-src` ya tiene el
bucket (las subidas de siempre lo usan); el script igual lo revisa. Se niega a
dejar la CSP por encima de los 1783 caracteres que acepta CloudFront.

### Los archivos que se borran

Reemplazar el video o la portada, pasar la lección a YouTube, borrar la
lección o su módulo: en todos los casos un *trigger* de la base anota las keys
viejas en `storage_pending_deletes`, en la misma transacción. Con el cambio
ya confirmado, la API las borra de S3 (`services/storage-cleanup.ts`), y antes
vuelve a mirar que ninguna lección ni curso las use. Si S3 falla, el pedido
no falla: las keys quedan anotadas con el error y se reintentan en el
siguiente cambio de video. Solo se anotan keys de `lessons/`: las del *seed*
las comparten staging y producción.

```sql
select key, reason, attempts, last_error from storage_pending_deletes;
```

**Staging y producción comparten el bucket.** Las keys de video llevan el id
de la lección y un UUID, así que no chocan; pero si alguna vez se copiaran
lecciones de producción a staging, borrar una en staging borraría el video de
producción. No copiar lecciones entre entornos mientras compartan bucket.

---

## Lo que NO cubre este archivo

**La distribución de CloudFront.** El video propio se sirve por CDN y nunca por
URL firmada de S3 — es una decisión de costo: la salida de S3 se cobra desde el
primer byte y CloudFront trae 1 TB al mes. `POST /files/download-url` rechaza
con 400 cualquier key de video, y `GET /lessons/:id/video-url` firma la URL de
CloudFront.

Para que CloudFront pueda leer del bucket hace falta un **bucket policy**, que
es otro objeto distinto de esta política de usuario: concede `s3:GetObject` al
servicio `cloudfront.amazonaws.com`, acotado con `AWS:SourceArn` a la
distribución. Con Origin Access Control, el bucket sigue con Block Public
Access activo y solo CloudFront entra.

Mientras la distribución no exista, `GET /lessons/:id/video-url` responde
**503 `cdn_not_configured`** diciendo qué variable falta
(`CLOUDFRONT_DOMAIN`, `CLOUDFRONT_KEY_PAIR_ID`, `CLOUDFRONT_PRIVATE_KEY`). La
firma ya está implementada y verificada con `openssl`; lo único que falta es la
infraestructura.
