
## Correr en local contra S3

El backend firma URLs de S3 para subir y descargar archivos. Firmar necesita
credenciales de AWS, pero **no van en `backend/.env`**: el SDK las toma de
`~/.aws/credentials` por la cadena de credenciales por defecto.

```bash
AWS_PROFILE=enactus-dev npm run dev
```

Sin el perfil, cualquier endpoint que firme una URL responde:

```json
{"error":{"code":"storage_unavailable","message":"No pudimos preparar el archivo: el almacenamiento no está disponible."}}
```

**Eso no es un fallo del código.** Es que no hay con qué firmar. El resto de
la API funciona igual, así que es fácil confundirlo con un bug del endpoint.

`backend/.env.example` no lleva campos `AWS_ACCESS_KEY_ID` /
`AWS_SECRET_ACCESS_KEY` a propósito: un campo vacío en un archivo de ejemplo
invita a rellenarlo, y de ahí a que una llave termine versionada hay poco
trecho.
