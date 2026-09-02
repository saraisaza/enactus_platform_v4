# Runbook de infraestructura — Enactus Platform

Qué hay desplegado, cómo se opera y cómo se recupera. **Se escribe a medida que
las cosas existen de verdad**: cada sección afirma solo lo que se verificó
contra AWS, no lo que está planeado.

Cuenta: `158151706149` · Región principal: `us-east-1`

---

## Estado real de la infraestructura

Relevado con `aws` CLI el 1 de septiembre de 2026.

| Recurso | Estado |
|---|---|
| Zona Route 53 `eduxaction.com` | ✅ `Z0527409CO28GN2VRE99` |
| Certificado ACM | ✅ emitido — ver abajo |
| Bucket S3 `enactus-media-dev` | ✅ privado, cifrado, versionado |
| Usuario IAM `enactus-s3-dev` | ✅ acotado al bucket |
| Llave de acceso de root | ✅ **borrada** (`AccountAccessKeysPresent = 0`) |
| MFA en root | ❌ **sin activar** |
| RDS | ❌ **no existe** — 0 instancias en 6 regiones, 0 snapshots |
| Secrets Manager | ❌ vacío |
| Lambda / API Gateway / CloudFront | ❌ no existen |
| Alarmas de AWS Budgets | ❌ ninguna |
| Roles IAM | ❌ ninguno (no hay rol de ejecución ni de OIDC) |

Es decir: **la plataforma todavía no está desplegada en ningún entorno.** Lo
que existe es el dominio, el certificado y el almacenamiento.

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
   conexión**; una `db.t4g.micro` aguanta ~100 y se agota — y cuando se agota
   no falla solo el pico, falla todo, incluido el login de quien ya estaba
   adentro. Con el tope, es imposible por construcción: 40 contenedores × 1
   conexión = 40, menos de la mitad del techo.

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

## Pendiente

- **MFA en root.** Solo lo puede activar una persona.
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
