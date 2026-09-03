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
| **Antes de terminar 5B** | Bajar `enactus-deploy` de `PowerUserAccess` a una política acotada a lo que de verdad usó |
| **Antes del go-live (1-oct-2026)** | Migrar a **IAM Identity Center**: credenciales temporales por `aws sso login`, y borrar las dos llaves AKIA |

Identity Center además es **menos** fricción que una llave con MFA
condicionada: una sesión al día en vez de manejar tokens a mano.

### Cómo se comprueba que se cerró

```bash
aws iam list-access-keys --user-name enactus-deploy   # debe devolver vacío
aws iam list-access-keys --user-name enactus-s3-dev   # idem
grep -c AKIA ~/.aws/credentials                       # debe ser 0
```

Mientras esos tres comandos no den ese resultado, la casilla «sin access keys
de larga vida en ninguna parte» **sigue abierta**.

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
