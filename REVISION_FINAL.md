# Revisión previa al lanzamiento — Enactus Platform

**2 de septiembre de 2026.** Lanzamiento previsto: 1 de octubre de 2026.

Cada afirmación de este documento se sostiene con un comando ejecutado y su
salida. Donde no pude ejecutar, lo digo — no lo doy por bueno.

---

## Veredicto

# NO está lista para producción.

Y no por ninguno de los hallazgos de código. Esos se encontraron y se
arreglaron. Es por algo más simple:

**La plataforma no está desplegada en ningún lado.** No hay RDS, no hay
Lambda, no hay API Gateway, no hay CloudFront, no hay VPC, no hay Secrets
Manager. Verificado por CLI, no supuesto:

```
$ aws rds describe-db-instances        →  []
$ aws lambda list-functions            →  []
$ aws apigatewayv2 get-apis            →  []
$ aws cloudfront list-distributions    →  None
$ aws secretsmanager list-secrets      →  []
$ aws ec2 describe-vpc-endpoints       →  (vacío)
```

Lo que existe es el dominio, el certificado, el bucket, el presupuesto y las
identidades. La aplicación corre en `localhost`.

Esto vuelve **no evaluables** —no "aprobados con reparos", sino imposibles de
mirar— tres bloques enteros del pedido: la auditoría adversarial contra
staging (se hizo contra la API real corriendo en local, que es el mismo
código, pero no es lo mismo), el bloque de infraestructura, y el ensayo de
go-live completo. No se puede hacer un simulacro de despliegue de algo que
nunca se desplegó.

**Lo que sí está listo es el código.** 538 pruebas de backend y 204 de Flutter
en verde, `typecheck`, `lint` y `flutter analyze` limpios, seis hallazgos
reales cerrados y verificados, y la única casilla abierta que estaba en mi
mano —el cambio obligatorio de contraseña— cerrada también. Es una base
sólida. Le falta el suelo debajo.

---

## Hallazgos

### CRÍTICO 1 — El límite de intentos de login era esquivable con una cabecera

**Cómo se reprodujo.** Contra la API corriendo, fuerza bruta contra una cuenta
conocida cambiando una cabecera en cada intento:

```bash
for i in $(seq 1 60); do
  curl -s -o /dev/null -w "%{http_code}" -X POST localhost:3000/auth/login \
    -H 'content-type: application/json' \
    -H "x-forwarded-for: 10.0.$((i/256)).$((i%256))" \
    -d '{"email":"admin@enactus.co","password":"incorrecta"}'
done
```

**Resultado: 60 aceptados, 0 frenados.** Con la IP fija, el freno aparecía al
intento 11. Rotándola, nunca.

La causa: la clave era `login:${ip}:${correo}` y la IP salía de
`x-forwarded-for[0]` — la primera entrada de una cabecera que escribe el
cliente. Y detrás de CloudFront no mejora: los proxies **agregan a la
derecha**, así que la primera entrada sigue siendo la del atacante.

Lo peor no es el bug, es que las pruebas lo tapaban: comprobaban que IPs
distintas tuvieran cupos distintos — exactamente el mecanismo que el atacante
usa.

**Cómo se arregló.** Dos candados, porque uno solo no alcanza:

1. `src/lib/client-ip.ts` — la IP sale de la **conexión** (el socket en
   `node-server`, `requestContext.http.sourceIp` en Lambda), no de la
   cabecera. Con proxies delante se lee `x-forwarded-for` pero **desde la
   derecha**, saltando los `TRUSTED_PROXY_HOPS` declarados. El default es `0`
   = ignorar la cabecera, el único valor seguro cuando no se sabe.
2. Un segundo candado en `/auth/login`: **20 fallos por correo cada 15
   minutos, sin mirar la IP**. Sobrevive aunque alguien rote IPs de verdad
   (proxies alquilados, que son baratos) o aunque `TRUSTED_PROXY_HOPS` quede
   mal puesto el día del despliegue. Solo cuenta fallos, y entrar bien lo
   borra, para que no se vuelva un candado contra los propios usuarios.

**Verificación.** Mismo ataque, misma API: **10 aceptados, 50 frenados.**

**Prueba que ahora lo cubre.** `tests/hardening.test.ts` — "rotar
x-forwarded-for NO abre la fuerza bruta contra una cuenta", más
`tests/client-ip.test.ts` (10 casos sobre de dónde sale la IP).

**Costo que hay que decir en voz alta:** alguien puede quemarle los 20 fallos
a una cuenta conocida y dejar a esa persona sin entrar por 15 minutos. Es un
bloqueo dirigido, acotado y sin pérdida de datos. Al lado de "fuerza bruta
ilimitada contra el admin", se elige este.

---

### CRÍTICO 2 — `db:seed` podía contaminar la base de producción

**Cómo se encontró.** Revisando el Bloque 4: `db:reset` se niega a correr en
producción; `db:seed` no lo hacía.

Y `db:seed` no siembra "datos de prueba de más": siembra estudiantes
inventados, entregas, evidencias, publicaciones de foro y **diez cuentas con
contraseñas de ejemplo** (`Admin123`, `Super123`, `Est123`). Contra una base
con estudiantes reales, eso es contaminación de datos personales más diez
cuentas de contraseña conocida y públicas en el repositorio.

Entre una cosa y la otra había un `NODE_ENV` mal puesto en una terminal.

**Cómo se arregló.** Guardia en `src/db/seed.ts`, igual que el de `reset.ts`.

**Verificación.**

```
$ NODE_ENV=production npm run db:seed
Falló el seed: db:seed siembra datos de DEMOSTRACIÓN y está bloqueado en producción.
```

---

### CRÍTICO 3 — El respaldo no se podía restaurar. Nunca había funcionado

**Cómo se reprodujo.** Ejecutando el ciclo entero en vez de solo descargar el
archivo: respaldar → borrar datos → restaurar.

```
$ curl -X POST localhost:3000/admin/restore ... → 500
Failed query: insert into "users" (...) values (...)
```

El respaldo excluye `password_hash` a propósito y **con razón**: el archivo
termina en el portátil de alguien, y un hash bcrypt se rompe sin prisa y sin
conexión. Pero la columna es `not null`, así que el `insert` de `users`
fallaba siempre. Y como todo va en una transacción, **no se restauraba nada**.

El botón "Restaurar desde archivo" lleva puesto en la pantalla de Admin desde
el principio y nunca funcionó.

Las pruebas que había miraban el respaldo — que se descargue, que no lleve
credenciales. Ninguna cerraba el círculo.

**Cómo se arregló.** Sin meter las credenciales en el archivo: antes de
borrar, se guardan los hashes que ya están en esa base y se vuelven a poner
por id. Para una cuenta que está en el respaldo pero ya no en la base, un hash
derivado de bytes aleatorios: la cuenta queda restaurada y visible para
administración, pero no se entra a ella hasta que le asignen contraseña.

**Segundo bug en el mismo camino:** las columnas `jsonb` (`profile`) volvían
del `select` como objetos de JavaScript, y el driver las mandaba con
`String(...)` — llegaban a PostgreSQL como el literal `[object Object]`.

**Verificación.** 16 usuarios, 9 cursos, 3 entregas, 14 lecciones marcadas y 4
publicaciones destruidas y devueltas exactas. Los cuatro roles entran después.
Cero `profile` corruptos.

**Prueba que ahora lo cubre.** `tests/backup-restore.test.ts`, 6 casos,
incluido *"después de restaurar, la gente puede ENTRAR"* — que es lo que uno
necesita a las 2 de la mañana. Comprobado que detecta el bug: revirtiendo el
arreglo, la del ciclo completo se pone roja.

---

### ALTO 1 — El límite general dejaba sin entrar a un campus entero

**Cómo se encontró.** Cuatro pruebas de contrato del cliente Flutter estaban
en rojo con `too_many_requests`. No era una prueba mal escrita.

**Cómo se midió.** Un proxy contador delante de la API mientras corría la
suite: **169 peticiones para 9 portales ≈ 19 por carga de portal.**

Con el límite en 300/min por IP, eso son ~15 personas por minuto y por IP. Los
usuarios de esta plataforma son estudiantes en universidades, y **una sala de
cómputo entera sale por una sola IP pública**. Una clase de 30 entrando a la
vez agotaba el cupo del edificio — y el 429 les caía **también en el login**.
Caída total para gente legítima, provocada por nosotros.

**Cómo se arregló.** 1200/min: ~60 cargas de portal por minuto y por IP, que
cubre un campus, y sigue cortando en seco a un raspador (que hace miles por
minuto, no cientos). El de login no se tocó — ese sigue estricto y ahora, además,
no es esquivable.

**Prueba.** `tests/hardening.test.ts` — "una carga de portal completa NO se
topa con el límite", anclada al número medido y a la constante real de
`app.ts`, no a una copia que se desincronice.

---

### MEDIO 1 — Tres invariantes que ninguna prueba cuidaba

De 17 mutaciones (romper a propósito lo que cada prueba dice verificar), 14 se
detectaron a la primera. Tres no. El detalle completo está en
[AUDITORIA_PRUEBAS.md](AUDITORIA_PRUEBAS.md); en resumen:

| | Qué se rompió | Pruebas rojas |
|---|---|---|
| **M8** | `requireAuth` deja de mirar si la cuenta fue desactivada | **0 de 502** |
| **F2** | `StudentDashboardView` devuelve un `Container()` vacío | **0 de 124** |
| **F3** | `AppHeader` devuelve un `Container()` vacío | **0 de 124** |

**M8** importa concretamente: el access token dura 12 horas. Sin esa
verificación, desactivar a alguien que se fue de la organización no lo sacaba
hasta la mañana siguiente, y quitarle `can_grade` a un LXD tampoco surtía
efecto. Los dos momentos en que se revoca un permiso son justo aquellos en los
que hay prisa por que surta efecto. **El código estaba bien; lo que no había
era nada que lo protegiera.**

**F2 y F3** comparten causa, y es una advertencia general: las pruebas
afirmaban **sobre el continente y no sobre el contenido**. "El armazón está
montado", "no apareció el ingreso", "no hay estado de error" — las tres son
ciertas con la pantalla completamente en blanco.

Los tres cerrados y re-verificados contra su propia mutación (M8 deja 1 roja,
F2 deja 8, F3 deja 9).

---

### BAJO 1 — Un JSON mal armado se contaba como caída del servidor

`POST` con cuerpo inválido devolvía **500 `internal_error`**. No filtra nada,
pero miente sobre de quién es la culpa: ensucia la tasa de 5xx —la señal sobre
la que se van a montar las alarmas— y una alarma que suena por el JSON mal
armado de un cliente enseña a ignorarla.

Ahora **400 `invalid_json`**. Verificado contra el servidor en modo
producción. Cubierto en `tests/hardening.test.ts`.

---

## Lo que se probó y estaba bien

52 intentos adversariales contra la API real. Todo esto se **ejecutó**:

**Escalada de privilegios.** `role` y `canGradeEnactus` en `PATCH /auth/me` se
descartan (zod los tira antes de llegar a la base) — comprobado leyendo el
registro después. Ningún rol crea cuentas por encima del suyo. Una cuenta
empresa crea `lxd` y `mentor` y recibe 403 en `admin` y `superadmin`. LXD,
mentor, asesor, donante, estudiante y alumni reciben 403 en `POST /users`.

**Aislamiento entre inquilinos.** El seed traía **una** empresa y **un**
mentor, así que el cruce no se podía probar: no había a dónde cruzarse. Creé
la empresa B con su propia gente y lo probé. Intersección **vacía**. Cambiar
el id en la URL da 404 en las cuatro direcciones. Las empresas ni siquiera ven
los correos de su propia gente.

**Falsificación de lógica.** Un estudiante no emite su certificado (403). Un
LXD sin `can_grade` tampoco (403). Un admin con la Ruta incompleta recibe 409.
El `studentId` del cuerpo en el *toggle* de lección **se ignora**: est1
mandando `studentId=est3` desmarcó **la suya** (7 → 6) y est3 quedó intacto en
3 — verificado en la base, no en la respuesta.

**Autenticación.** Firma cambiada → 401. `alg:none` haciéndose pasar por
superadmin → 401. Token bien formado firmado con otro secreto → 401. Refresh
token reusado → 401. Sin token → 401.

**Open Learning.** 403 en `/laboratories`, `/projects`, `/groups`,
`/forum-posts`, `/phases` y en su propia `ruta-progress`. **403, no lista
vacía** — que era el criterio.

**Archivos.** Un estudiante recibe 403 en los cinco propósitos de subida que
no le tocan y pasa a la firma en los dos que sí. Una key que ninguna fila
referencia da **404, no 403** (un 403 confirmaría que el objeto existe). Los
videos se rechazan con 400 en la URL firmada de S3.

**Secretos.** Historial completo de git sin una sola credencial (ni `AKIA`, ni
`BEGIN PRIVATE KEY`, ni asignación con valor real). Ningún `.env` o `.pem`
versionado. El bundle de Flutter Web compilado en release lleva **solo**
`API_BASE_URL` — es el único `String.fromEnvironment` de todo el código, y las
8 apariciones de "password" en el JS son nombres de campo y pistas de
autocompletado, no valores. Los errores en modo producción no filtran SQL,
nombres de tabla ni rastros de pila.

---

## Casillas abiertas

### No se pudieron verificar porque no existe la infraestructura

| Casilla | Por qué |
|---|---|
| RDS no accesible públicamente | no hay RDS |
| SG de RDS solo desde el SG de Lambda | no hay ninguno de los dos |
| `rds.force_ssl = 1` | ídem |
| Backups automáticos con retención de 7 días | ídem |
| Rotación de secretos | Secrets Manager vacío |
| `reserved concurrency` de Lambda en 40 | no hay Lambda |
| Retención de logs de CloudWatch | no hay grupos de logs |
| Video de CloudFront sin firma da 403 | no hay distribución |
| URL firmada expirada da 403 | ídem |
| Ensayo de go-live completo (Bloque 5) | no hay staging |

La firma de CloudFront **sí** está implementada y verificada
(`tests/video-playback.test.ts` genera un par RSA por corrida y comprueba la
firma con `createVerify('RSA-SHA1')`). Lo que falta es la distribución contra
la cual probarla de punta a punta.

### Verificadas y en orden

```
MFA en root                        ✅ AccountMFAEnabled = 1
Llaves de acceso de root           ✅ 0
S3 sin acceso público              ✅ los 4 flags en true
S3 versionado                      ✅ Enabled
S3 cifrado                         ✅ AES256
Budgets                            ✅ $20, $50, $100 + pronóstico al 80%
Certificado ACM                    ✅ ISSUED, eduxaction.com + *.eduxaction.com
Rol OIDC de GitHub                 ✅ enactus-github-deploy, sin llave
NAT Gateway                        ✅ ninguno (trivial: no hay VPC)
CORS restringido, sin comodines    ✅ verificado con origen ajeno y legítimo
HSTS, CSP, nosniff, X-Frame DENY   ✅ verificados en modo producción
```

### Abiertas con trabajo pendiente

**1. `seed:prod` existe ahora, pero le faltan las identidades reales.**
No existía; lo escriba (`npm run seed:prod -- ./admins.json`). Deja
exactamente los catálogos, los 6 laboratorios con fases vacías y sin plazos, y
los super admins — nada más. Las contraseñas las genera al azar (24
caracteres) y las imprime una sola vez. Se niega a correr sobre una base que ya
tiene gente. 7 pruebas, casi todas sobre lo que **no** debe quedar.

**Necesito de usted:** los nombres y correos reales de los super admins. No los
invento y no los pongo en el repositorio.

**2. ~~No existe el cambio de contraseña obligatorio al primer ingreso.~~**
**CERRADA el 2 de septiembre.** Ver "Cambio obligatorio de contraseña" abajo.

**3. `TRUSTED_PROXY_HOPS` hay que fijarlo el día del despliegue.**
Con CloudFront → API Gateway → Lambda son 2. Si queda mal puesto, el primer
candado del login deja de frenar **en silencio** — por eso existe el segundo,
que no depende de él. Va al RUNBOOK con cómo comprobarlo contra el despliegue
real en vez de suponerlo.

**4. Dos llaves de acceso de larga vida siguen vivas**, y está bien que sea
así, pero conviene decirlo en vez de marcar la casilla: `enactus-s3-dev` (en
`backend/.env`) y `enactus-deploy` (en `~/.aws`). Ninguna está en el
repositorio ni en los secretos de GitHub; el pipeline usa OIDC sin llave. No
pude enumerarlas por CLI porque `enactus-deploy` tiene `PowerUserAccess`, que
excluye IAM — que es exactamente el límite que le pusimos, funcionando.

**5. Cuatro reglas penden de una sola prueba cada una** (M4, M5, M9, M10 en la
auditoría de pruebas). Son correctas y están cubiertas, pero por un único
caso: si alguien borra esa prueba, la regla queda sin red y nada avisa. No es
un defecto, es dónde una edición descuidada sale cara.

**6. Los borrados no eliminan el archivo de S3.** Borrar una evidencia o un
recurso quita la fila y deja el objeto en el bucket para siempre. No queda
accesible —`authorizeFileRead` resuelve la key contra la fila y sin fila
responde 404— pero sigue almacenado. Para la evidencia de un donante,
"borrado" en la pantalla debería significar borrado.

---

## Qué sigue

Antes del 1 de octubre, en este orden:

1. **Levantar la infraestructura.** Es el camino crítico entero y no empezó.
   RDS con las cuatro casillas de seguridad puestas al crearla (subred
   privada, SG solo desde el de Lambda, rotación del secreto, `force_ssl`) —
   ponerlas después es otro trabajo distinto y peor.
2. **Staging antes que producción**, que es su propia regla.
3. **`seed:prod` con los admins reales**, y la decisión sobre el cambio
   obligatorio de contraseña.
4. **Ensayo de go-live** siguiendo el RUNBOOK tal como está escrito, con
   rollback de verdad. Recién ahí se puede decir que está probado.

El congelamiento de código, el etiquetado de la versión de lanzamiento y la
confirmación del rollback probado tienen que esperar a ese ensayo: etiquetar
hoy sería poner una etiqueta sobre algo que nunca corrió fuera de esta
máquina.

---

## Estado al cerrar

```
backend   538 pruebas · typecheck limpio · lint limpio
Flutter   204 pruebas · flutter analyze sin issues
```

Hallazgos: **3 críticos, 1 alto, 1 medio, 1 bajo — los seis cerrados y
verificados con la prueba que los detectó.**

---

## Cambio obligatorio de contraseña

Era la casilla abierta 2 y quedó cerrada. Vale la pena decir qué faltaba,
porque era más que un campo: **la plataforma no tenía forma de que alguien
cambiara su propia contraseña.** Sabía restablecer la de otro
(`PATCH /users/{id}`, solo administración) y nada más — así que "cambiala al
entrar" era una instrucción imposible de cumplir.

Lo que hay ahora:

- **`users.must_change_password`** (migración `0003`), con `default false`:
  aplicarla no echa de la plataforma a quien ya eligió su contraseña.
- **`POST /auth/change-password`**, que pide la contraseña actual —un access
  token robado dura 12 horas y no puede alcanzar para apropiarse de una
  cuenta—, rechaza repetir la misma, cierra todas las sesiones anteriores y
  emite un par nuevo.
- **El bloqueo vive en `requireAuth`**, no en la pantalla. Mientras la bandera
  esté puesta, toda la API responde **403 `password_change_required`** salvo
  `GET /auth/me`, `POST /auth/change-password` y `POST /auth/logout`. Si
  viviera en el cliente sería un cartel que se cierra con la X: la API
  seguiría aceptando todo con la contraseña entregada, y la copia que se usó
  para entregarla —un mensaje, un papel, un historial de chat— seguiría
  sirviendo.
- **La bandera se pone sola** en los dos únicos casos en que alguien recibe una
  contraseña que no eligió: las cuentas que crea `seed:prod` y los
  restablecimientos de administración.
- **Una pantalla en Flutter** que aparece desde los tres guardias de sesión.
  Sin botón de "más tarde" —no hay más tarde— pero con salida para cerrar
  sesión, para que nadie quede encerrado.

Verificado de punta a punta contra la API real, con una cuenta desechable:
entra con la entregada → la plataforma le responde 403 → no puede repetir la
misma ni inventar la actual → cambia → la plataforma le responde → la sesión
anterior queda cerrada → la contraseña entregada ya no sirve. Y el detalle que
más dice que el bloqueo es real: **ni el superadmin puede crear una cuenta
antes de cambiar la suya.**

21 pruebas nuevas (13 de backend, 16 de Flutter, con solapamiento de nombre).
Comprobado por mutación que las detectan: quitando el bloqueo del servidor
caen 3 pruebas de backend, y quitándolo de los guardias caen 13 de Flutter.
