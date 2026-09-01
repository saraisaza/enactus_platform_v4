# Infraestructura de AWS

Los archivos de esta carpeta son **configuración, no secretos**. Ninguna llave,
ningún token: las credenciales viven en `backend/.env` (que está en
`.gitignore`) y, en producción, en Secrets Manager.

---

## `s3-policy.json` — el usuario IAM del backend

Política acotada al bucket `enactus-media-dev`, para reemplazar la llave de
root que se venía usando.

El par de ARN está bien puesto, que es donde falla casi siempre: las acciones
sobre **objetos** van contra `arn:aws:s3:::enactus-media-dev/*` y las que son
sobre el **bucket** contra `arn:aws:s3:::enactus-media-dev`, sin la barra. Con
un solo ARN para las dos, `ListBucket` no funciona nunca.

### Qué usa el código, hoy

El backend solo llama a dos comandos del SDK (`src/lib/s3.ts`):

| Acción | Para qué |
|---|---|
| `s3:PutObject` | firmar la URL de subida (`POST /files/upload-url`, `POST /lessons/:id/video-upload-url`) |
| `s3:GetObject` | firmar la URL de lectura (`POST /files/download-url`) |

El archivo **nunca pasa por la API**: el navegador hace `PUT` directo contra la
URL firmada. API Gateway corta el payload en 10 MB y un video lo revienta.

### Lo que la política concede de más, y por qué está bien dejarlo

- **`s3:ListBucket`** — nada lista el bucket, pero conviene tenerlo igual: sin
  este permiso, un `GET` sobre una key que no existe devuelve **403
  AccessDenied** en vez de **404 NoSuchKey**. Con las URLs firmadas que se le
  entregan al navegador, eso convierte "esa imagen no está" en "no tenés
  permiso", que es una pista falsa cada vez que haya que depurar algo.

- **`s3:DeleteObject`** — hoy no se usa, y eso es un hueco de la aplicación, no
  de la política: **los borrados solo eliminan la fila de la base**. Borrar una
  evidencia, una imagen de la galería o un recurso deja el archivo en el bucket
  para siempre. No queda accesible —`authorizeFileRead` resuelve la key contra
  la fila que la referencia, y sin fila responde 404— pero sigue almacenado, y
  "borrado" en la pantalla no significa borrado de verdad. Para una evidencia
  de un donante eso importa. El permiso conviene dejarlo puesto para poder
  cerrar ese hueco sin volver a tocar IAM.

- **`s3:AbortMultipartUpload` y `s3:ListBucketMultipartUploads`** — el
  navegador sube con un solo `PUT` firmado, no en partes. El tope de un `PUT`
  simple en S3 son 5 GB y la app corta en 500 MB, así que multipart no se usa.
  Son inofensivos y quedan si en algún momento se sube en partes.

No falta ningún permiso: firmar una URL es un cálculo local, y el permiso se
evalúa recién cuando alguien la usa.

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

```bash
aws iam create-user --user-name enactus-backend-dev
aws iam put-user-policy \
  --user-name enactus-backend-dev \
  --policy-name enactus-media-dev-s3 \
  --policy-document file://backend/infra/s3-policy.json
aws iam create-access-key --user-name enactus-backend-dev
```

La llave que devuelve el último comando va a `backend/.env`
(`AWS_ACCESS_KEY_ID` / `AWS_SECRET_ACCESS_KEY`) en local y a Secrets Manager en
AWS. **Nunca al repositorio.**

Después, y esto es la mitad que importa:

```bash
aws iam list-access-keys --user-name <root-o-el-usuario-viejo>
aws iam delete-access-key --access-key-id <la-vieja>
```

Crear el usuario acotado no reduce nada mientras la llave vieja siga viva.

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
