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
aws lambda put-function-concurrency --function-name enactus-api-staging --reserved-concurrent-executions 5
aws service-quotas get-service-quota --service-code lambda --quota-code L-B99A9384 --query 'Quota.Value'
```

**No se cierra esta entrada hasta que esos tres comandos den 40, 5 y 1000.**

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
