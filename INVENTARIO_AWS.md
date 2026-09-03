# Inventario AWS — Enactus Platform

**Levantado con `aws` CLI el 2 de septiembre de 2026.** Cada fila se verificó
ejecutando el comando que la acompaña, no leyendo la consola.

Cuenta `158151706149` · Región principal `us-east-1` · Perfil `enactus-deploy`

---

## Red

| | |
|---|---|
| VPC | `vpc-02ddd68f6a114ce46` — `enactus-vpc`, `10.0.0.0/16` |
| Subredes | `subnet-03fa7c1f7ddbca617` (us-east-1a, `10.0.1.0/24`)<br>`subnet-0a9067deec995fcd9` (us-east-1b, `10.0.2.0/24`) |
| ¿Asignan IP pública? | **No**, las dos |
| Internet gateways | **0** |
| NAT gateways | **0** |
| Única ruta no local | `vpce-01fd4eef0b54f6287` — endpoint **Gateway** de S3 (sin costo) |

```bash
aws ec2 describe-route-tables --filters Name=vpc-id,Values=vpc-02ddd68f6a114ce46 \
  --query 'RouteTables[].Routes[?GatewayId!=`local`]'
```

### Security groups

| Grupo | Entrada | Salida |
|---|---|---|
| `enactus-rds-sg` | TCP 5432 **solo desde `enactus-lambda-sg`** (referencia al grupo, no un CIDR) | ninguna |
| `enactus-lambda-sg` | ninguna | abierta (necesita alcanzar RDS y el endpoint) |
| `default` de la VPC | **ninguna** — se cerró el 2-sep | **ninguna** |

El grupo por defecto venía abierto hacia sí mismo y con salida a `0.0.0.0/0`.
No lo usa nada (0 interfaces), pero cualquier recurso que cayera ahí por
descuido habría hablado con todo. Ahora no habla con nada.

---

## Base de datos

```
enactus-db.cop602mo6lg7.us-east-1.rds.amazonaws.com:5432
PostgreSQL 17.11 · db.t4g.micro · 20 GB gp3 · us-east-1a · available
```

| | |
|---|---|
| Accesible públicamente | **No** |
| Cifrada | Sí |
| Respaldos | 7 días · ventana 06:30–07:00 UTC (01:30 en Colombia) |
| `rds.force_ssl` | **1** — probado rechazando una conexión sin TLS |
| Protección de borrado | Activada |
| Secreto maestro | gestionado por RDS · **rota cada 7 días** |

| Base | Usuario propietario | Secreto |
|---|---|---|
| `enactus_prod` | `enactus_prod_app` | `enactus/prod/runtime` |
| `enactus_staging` | `enactus_staging_app` | `enactus/staging/runtime` |

Aislamiento comprobado en las dos direcciones: cada usuario es rechazado en la
base del otro.

---

## Secretos

```
Secrets Manager (fuente de verdad)  →  el pipeline copia  →  S3 cifrado (lo lee la Lambda)
```

| | |
|---|---|
| Bucket | `enactus-secretos-158151706149` |
| Cifrado | SSE-KMS con `alias/enactus-secretos` |
| Objetos | `prod/runtime.json`, `staging/runtime.json` |
| Quién puede leer | **solo** el rol `enactus-backend-lambda` |
| Comprobado | `enactus-deploy`, con `PowerUserAccess`, recibe **403** |

Secretos en Secrets Manager: `enactus/prod/runtime`, `enactus/staging/runtime`,
más el maestro que gestiona RDS.

---

## Cómputo

| Recurso | Estado |
|---|---|
| Lambda `enactus-db-admin` | Active · `nodejs22.x` · en la VPC · `enactus-lambda-sg` |
| Lambda de la API | ❌ no existe todavía |
| API Gateway | ❌ no existe |
| CloudFront | ❌ no existe |

---

## Dominio y certificado

| | |
|---|---|
| Zona Route 53 | `eduxaction.com.` — `Z0527409CO28GN2VRE99` · **3 registros** (NS, SOA y el CNAME de validación) |
| Certificado ACM | `eduxaction.com` + `*.eduxaction.com` · `ISSUED` · vence **18-mar-2027** |
| `InUse` | **false** — nada lo usa todavía |
| `RenewalEligibility` | **INELIGIBLE** — ACM solo renueva certificados asociados a un recurso |

Los 3 registros confirman que **nada apunta a ningún sitio**: no hay `A` para
el ápice, ni para `www`, ni para `api`.

---

## Almacenamiento

| Bucket | Para qué |
|---|---|
| `enactus-media-dev` | archivos de la plataforma · privado · SSE-S3 · versionado |
| `enactus-secretos-158151706149` | configuración de ejecución · SSE-KMS |
| Bucket del frontend | ❌ no existe |

---

## Identidades

| | |
|---|---|
| MFA en root | ✅ activado |
| Llaves de acceso de root | ✅ 0 |
| Usuarios IAM | `enactus-deploy`, `enactus-s3-dev` |
| Roles | `enactus-github-deploy` (OIDC, sin llave), `enactus-backend-lambda`, `enactus-db-admin` |

### Discrepancia con lo que dice el prompt

El prompt afirma «sin llaves de larga vida». **No es exacto**, y conviene que
quede escrito:

```
llaves AKIA en ~/.aws/credentials:  2   (perfiles enactus-dev y enactus-deploy)
llaves AKIA en backend/.env:        0
```

Existen dos llaves de larga vida, en el portátil. Lo que **sí** es cierto —y es
lo que importa— es que **no hay ninguna en el repositorio ni en los secretos de
GitHub**: el pipeline usa OIDC y credenciales temporales.

Nota aparte: `backend/.env` ya no tiene credenciales de AWS, así que en local
la firma de URLs de S3 responde `503 storage_unavailable`. No es un fallo del
código; es que no hay con qué firmar.

---

## Costo mensual

| Concepto | US$/mes |
|---|---|
| RDS `db.t4g.micro` | ~11.70 |
| 20 GB gp3 | ~2.30 |
| Llave KMS | 1.00 |
| Secrets Manager (3 secretos) | 1.20 |
| Zona Route 53 | 0.50 |
| S3 (medios + secretos) | ~0.10 |
| Endpoint Gateway de S3 | **0** |
| **Total** | **~16.80** |

Avisos de presupuesto configurados: gasto real > $20, > $50, > $100, y
pronóstico > 80% de $100.
