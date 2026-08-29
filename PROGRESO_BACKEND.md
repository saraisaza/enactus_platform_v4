# Progreso del backend — Enactus Platform

Estado por fase. Nada se marca como hecho sin haber corrido los comandos de
verificación y pegado su salida real.

| Fase | Estado | Cierre |
|---|---|---|
| 0 — Auditoría y requerimientos | ✅ Cerrada | 28 ago 2026 · aprobada |
| 1 — Esquema Postgres | ✅ Cerrada | 28 ago 2026 |
| 2 — Migraciones y seed | ✅ Cerrada | 28 ago 2026 |
| 3 — Auth y autorización | ✅ Cerrada | 28 ago 2026 |
| 4 — API REST | ✅ Cerrada | 28 ago 2026 · 4 grupos + OpenAPI |
| 5 — Cliente Flutter | ⬜ Pendiente | — |
| 6 — Infraestructura y CI/CD | ⬜ Pendiente | — |

---

## Fase 0 — Auditoría y requerimientos ✅

**Entregable:** [AUDITORIA_BACKEND.md](AUDITORIA_BACKEND.md) — las 18 cajas de
Hive con sus campos reales, los ~95 métodos públicos de `DataProvider`
clasificados, `DbService`/`MigrationService`/`SeedService`, dónde vive hoy la
completitud y la calificación, las 10 cosas que deben moverse al servidor por
seguridad, las 7 preguntas de requerimientos y la matriz de permisos.

**Hallazgo estructural:** 18 cajas ≠ 18 entidades. `content` guarda dos
documentos sin relación, `session` desaparece con el JWT, `mentor_notes` no
tiene clase de modelo, y 8 tipos anidados (`Phase`, `Objective`, `RutaModule`,
`Lesson`, `CourseModule`, `QuizQuestion`, `ActivityConfig`, `ForumReply`) no
tienen caja propia pero sí necesitan tabla.

**Decisiones confirmadas** (secciones B y C de la auditoría): el certificado no
se revoca nunca, se congela con snapshot · las calificaciones sobreviven a que
le quiten `can_grade` a quien las puso · Open Learning → Enactus es una
promoción que conserva todo el progreso · el alumni conserva lectura y pierde
escritura · las notas del equipo docente no las ve el estudiante · un solo rol
por usuario en la v1 · borrar un curso con progreso pasa a ser archivar · se
conservan los **dos** permisos de calificación, no uno.

---

## Fase 1 — Esquema Postgres ✅

### Qué cambió

Se creó `backend/` como paquete separado (Node + TypeScript + Hono + Drizzle),
con el esquema completo y la lógica de completitud como vistas de PostgreSQL.

**52 tablas · 16 enums · 7 vistas · 85 claves ajenas · 23 CHECK · 150 índices
· 2 funciones · 1 trigger.**

Lo que dejó de estar anidado y pasó a tabla propia, como pedía el requisito:

| Antes (Hive, anidado) | Ahora (tabla) |
|---|---|
| `ForumPost.replies`, `.likedBy` | `forum_replies`, `forum_likes` |
| `Course.modules[].lessons[]` | `course_modules`, `lessons` |
| `Laboratory.phases[]` | `phases`, `objectives`, `ruta_modules` |
| `Group.studentIds` **+** `AppUser.groupId` | `group_members` (una sola relación, no dos) |
| `AppUser.extra['labIds'/'courseIds'/'reviewCourseIds']` | `student_laboratories`, `student_courses`, `mentor_review_courses` |
| `Lesson.quiz[]`, `.activity` | `quiz_questions`, `quiz_question_options`, `lesson_activities`, `activity_rubric_items` |
| `Progress.completedLessonIds` | `progress_lessons` |
| `ExpoChecklist.items` | `expo_checklist_items` |
| `SiteContent.galleryImages` (base64) | `site_gallery_images` (keys de S3) |
| Listas de texto (`ods`, `tags`, `competencies`, …) | `project_ods`, `course_ods`, `course_tags`, `course_competencies`, … |

**JSONB solo donde el dato es genuinamente variable:** `users.profile` (los 7
campos de perfil libre de LXD/Mentor), `quiz_attempts.answers` (su forma
depende del tipo de pregunta), `certificates.requirements_snapshot`,
`audit_log.old_value`/`new_value`. En ningún otro lado.

### Las dos brechas de modelo del frontend, cerradas desde el diseño

- **`group_members.role_in_project`** — enum `project_member_role` (leader,
  research, finance, communications, design, operations, member). Era lo que
  faltaba para la pantalla de detalle de proyecto (BLOQUEOS.md § 2).
- **`evidences.project_id`** — FK nulable a `projects`, indexada. Sin esto el
  portal de Donante no puede decir a qué proyecto pertenece una evidencia.

### Archivos: se acabó el base64

Nueve columnas pasaron de "blob dentro del registro" a key de S3 + metadata:
`users.avatar_s3_key`, `courses.cover_s3_key`, `courses.intro_video_s3_key`,
`lessons.resource_s3_key`, `lessons.video_s3_key`, `submission_files.s3_key`,
`evidences.s3_key`, `communication_resources.s3_key`,
`site_gallery_images.s3_key`.

### Video: los dos orígenes, con la restricción en la base

`lessons` lleva las seis columnas pedidas (`video_type`, `video_url`,
`video_s3_key`, `video_size_bytes`, `video_duration_sec`, `video_mime_type`) y
tres CHECK que las hacen coherentes. `courses` lleva las mismas con prefijo
`intro_video_`, para que un LXD pueda subir su intro y no solo pegar un enlace.

`video_size_bytes` está en las dos tablas, así que la métrica de almacenamiento
total de video para el endpoint de admin es una suma directa.

**Una desviación deliberada:** el prompt pedía `video_type NOT NULL`, pero una
lección de tipo `pdf`, `quiz` o `activity` no tiene video ninguno. La columna
quedó nulable **y** el CHECK exige lo mismo que se pedía —"exactamente uno de
`video_url`/`video_s3_key` según `video_type`"— más una regla extra
(`lessons_video_type_requires_source`) que obliga a que una lección de tipo
`video` sí tenga origen. Es la misma garantía sin inventar un `video_type` para
lecciones que no son video. Probado en `tests/schema-constraints.test.ts`.

> **Actualización (Fase 4, migración 0002):** esa regla extra se quitó de la
> base. Hacía imposible el flujo de subida de archivos propios y se movió a
> `POST /courses/:id/publish`. `lessons_video_source` —la coherencia entre
> `video_type` y su origen— sigue vigente. Ver la sección de la Fase 4.

### Completitud: en la base, no en el cliente

`drizzle/0001_completeness.sql` traduce a vistas las líneas 178-311 de
`data_provider.dart`:

| Vista | Regla |
|---|---|
| `student_course_access` | `studentHasCourse`: Enactus automático por laboratorio, Open Learning solo asignados |
| `course_progress` | curso completo ⇔ todas sus lecciones completas |
| `objective_completion` | objetivo completo ⇔ TODOS sus cursos vinculados al 100% |
| `ruta_module_completion` | módulo completo ⇔ todas sus lecturas propias **y** todos sus cursos |
| `phase_completion` | fase completa ⇔ ≥1 módulo y todos completos |
| `ruta_completion` | Ruta completa ⇔ todas las fases completas |
| `phase_unlocked` | fase 1 siempre; el resto exige la anterior completa |

Más `can_issue_ruta_certificate(student, lab)` y el trigger
`certificates_require_complete_ruta`, que **rechaza en la base** un certificado
sin la Ruta completa. Hoy `issueRutaCertificate` no comprueba su propio
requisito: lo hace la pantalla al armar el desplegable.

Las tres reglas no obvias se conservaron y tienen prueba propia: un módulo sin
nada configurado nunca cuenta como completo; un objetivo sin cursos vinculados
nunca se completa; y la completitud se **deriva** — agregar una lección revierte
sola el curso, el módulo, la fase y la Ruta, sin tocar ninguna columna.

### Otras decisiones del esquema

- **`submissions.grading_mode` junto a la nota.** Hoy conviven cuatro escalas
  (`points100`, `passfail`, `review`, `scale5`) en el mismo `double? grade` y el
  número por sí solo no significa nada: 100 es "aprobado" en una y "nota
  perfecta" en otra. Un CHECK exige que toda nota traiga escala, autor y fecha.
- **`certificates.issuer_id` es FK real.** Hoy `issuerName` es un string libre y
  `_LxdCertificates` filtra "los que emití yo" comparando por **nombre**.
- **Unicidad de correo insensible a mayúsculas** (índice funcional sobre
  `lower(email)`), que es como ya compara `findByCredentials`.
- **Borrado lógico** (`deleted_at`) en las 10 tablas que hoy tienen un `delete*`
  en `DataProvider`.
- **`laboratories.content_version`** sube con cada cambio estructural de la
  Ruta; el certificado guarda contra qué versión se emitió (decisión B.1).

### Un bug encontrado y corregido durante la fase

El conversor a `snake_case` de Drizzle parte los nombres en los dígitos:
`videoS3Key` generaba la columna **`video_s_3_key`**, no `video_s3_key`. Afectaba
a las 9 columnas de S3. Se detectó porque el test de restricciones falló con
*"column video_s3_key does not exist"* — no por leer el SQL. Corregido dándole
nombre explícito a cada una y regenerando la migración.

### Dependencias, y por qué cada una

| Paquete | Por qué |
|---|---|
| `hono` | decidido |
| `drizzle-orm`, `drizzle-kit` | decidido |
| `zod` | decidido (validación) |
| `postgres` (postgres.js) | en vez de `pg`: pesa mucho menos en el bundle de Lambda y permite apagar prepared statements si más adelante entra RDS Proxy en modo transacción |
| `jose` | JWT sin dependencias, en vez de `jsonwebtoken` (que arrastra varias y no soporta Web Crypto) |
| dev: `tsx`, `vitest`, `eslint`, `typescript-eslint`, `dotenv` | herramientas, no van al bundle |

**`drizzle-orm` se subió de `^0.44.6` a `^0.45.2`** durante la fase: `npm audit`
reportó una vulnerabilidad **alta** en la primera, y está en dependencias de
producción. Tras la subida, `npm audit --omit=dev` → **0 vulnerabilidades**, y
el SQL generado no cambió.

Quedan 4 vulnerabilidades **moderadas** solo en dependencias de desarrollo
(`esbuild <=0.24.2`, vía `@esbuild-kit`, que es un camino viejo de `drizzle-kit`).
Afectan al servidor de desarrollo de esbuild, no a nada que se despliegue.
Se revisan en la Fase 6.

### Cómo correrlo en local

```bash
# PostgreSQL 16 (macOS)
brew install postgresql@16 && brew services start postgresql@16
createdb enactus_dev && createdb enactus_test

cd backend
cp .env.example .env        # completar DATABASE_URL y JWT_SECRET
npm install
npm run db:migrate
```

### Verificación — salida real

```
$ npm run typecheck
> tsc --noEmit
                                        (sin errores)

$ npm run lint
> eslint .
                                        (sin errores)

$ npm test
 ✓ tests/completeness.test.ts        (16 tests)
 ✓ tests/schema-constraints.test.ts  (13 tests)
 Test Files  2 passed (2)
      Tests  29 passed (29)

$ npm run db:migrate ; npm run db:rollback ; npm run db:rollback ; npm run db:migrate
inicio:    tablas=0  vistas=0  enums=0   triggers=0
migrate:   tablas=52 vistas=7  enums=16  triggers=1
rollback1: tablas=52 vistas=0  enums=16  triggers=0
rollback2: tablas=0  vistas=0  enums=0   triggers=0
migrate:   tablas=52 vistas=7  enums=16  triggers=1
```

El ciclo cierra exacto: la base vuelve al estado inicial y la re-aplicación
reconstruye todo. `drizzle-kit` genera solo el "up", así que **cada migración
tiene su reverso escrito a mano** en `drizzle/down/<tag>.down.sql`, y
`db:rollback` lo aplica dentro de una transacción — si el reverso falla, no se
marca nada como revertido.

### Lo que quedó pendiente o requiere tu decisión

1. **Node 22, no 20.** La máquina tiene Node 22.23 (LTS actual). El paquete
   declara `engines: >=20` y funciona en ambos. Si el runtime de Lambda tiene
   que ser `nodejs20.x` exacto, decilo antes de la Fase 6.
2. **`project_member_role` es un enum de 7 valores** (leader, research, finance,
   communications, design, operations, member). El pedido decía "líder,
   investigación, finanzas, comunicaciones, etc." — el "etc." lo cubrí con
   `member` genérico. Si hay roles concretos que faltan, agregarlos ahora es
   una línea; después es una migración.
3. **Los enums guardan slugs en inglés** (`ideation`, `published`,
   `entrepreneurship`…), no el texto en español que hoy vive en Hive
   (`'Ideación'`, `'Publicado'`, `'Emprendimiento'`). La etiqueta la pone el
   cliente, como ya hace `Roles.label()`. Guardar el español ataría el dato al
   idioma de la interfaz.
4. **`quiz_attempts` es una tabla nueva** que hoy no tiene equivalente: el quiz
   se califica en el navegador y no queda registro de nada. Aparece acá porque
   la Fase 4 la necesita para calificar en el servidor.
5. **Sin verificar contra RDS real.** Todo se probó contra PostgreSQL 16.15
   local. Las migraciones deberían aplicar igual en RDS, pero no lo puedo
   afirmar hasta correrlas allá — queda como primera tarea de la Fase 6.

---

## Fase 2 — Migraciones y seed ✅

### Qué cambió

`src/db/seed.ts` replica `lib/services/seed_service.dart`: **16 usuarios**
(los 9 roles), 6 laboratorios con la Ruta real de `lab_ia`, 2 proyectos, 2
equipos con checklist Expo, 9 cursos con 25 lecciones, el quiz de 4 tipos de
pregunta, la actividad con rúbrica de 5 criterios, la encuesta, y la actividad
de demostración (progreso, 3 entregas, 3 evidencias, 2 notificaciones, 4
publicaciones de foro, contenido del sitio).

**Ids determinísticos.** `seedId('est1')` deriva un UUID v5 estable de la clave
que la entidad tenía en Hive (`src/db/seed-ids.ts`). `db:reset` dos veces da
exactamente los mismos ids, así que una URL o un test escrito ayer sigue
valiendo hoy, y las pruebas apuntan a las entidades por su nombre de siempre.

**Contraseñas con bcrypt** (`bcryptjs`, cost 10). Las credenciales son las
mismas del seed de Flutter porque son de demostración, pero ahora se guardan
hasheadas: hay un test que confirma que el hash no es el texto plano y que
`verifyPassword` acepta la correcta y rechaza otra.

### Los tres agregados que pedía la fase

El seed de Flutter no los tiene, y se armaron con entidades que ya existen —
no con datos inventados:

1. **`lxd1` con `can_grade_enactus = true`** y `lxd2` con los dos permisos en
   `false`. Hace falta decirlo: hoy en la app **ningún** LXD puede calificar
   Enactus ni emitir certificados, porque los tres usan el default implícito.
2. **`est1` con la Ruta parcialmente completa**: termina el curso `crs_ia_1`
   entero y la lectura propia del módulo 1 → ese módulo queda completo y el de
   mentoría pendiente, así que la fase 1 sigue incompleta (1/2 módulos). Es el
   estado que permite probar tanto el rechazo como la emisión del certificado.
3. **`alum1` conserva el avance original** (2 de 6 lecciones), para tener un
   segundo estudiante en el mismo laboratorio con menos avance.

### Dos huecos del seed original que hubo que resolver

- **La nota 4.5 de `sub1` no decía en qué escala estaba ni quién la puso.** El
  CHECK `submissions_grade_has_scale_and_author` no la deja entrar así. Se
  reconstruyó como `scale5` (entrega libre, sin actividad asociada) calificada
  por `lxd1`, el LXD dueño del curso — el único que podía haberla puesto.
- **Las evidencias no tenían proyecto.** Ahora `ev1` y `ev3`, que hablan
  explícitamente de AquaVida, apuntan a `prj1`; `ev2` es un reporte trimestral
  general y queda sin proyecto (la columna es nulable a propósito).

### Cómo correrlo en local

```bash
cd backend
npm run db:reset     # borra, migra y siembra
npm run db:seed      # solo siembra (sobre un esquema ya migrado)
```

`db:reset` se niega a correr con `NODE_ENV=production`.

### Verificación — salida real

```
$ npm run db:reset
Reiniciando postgres://***@localhost:5432/enactus_dev…
Esquema recreado. Sembrando…
Base lista.

$ psql "$DATABASE_URL" -c "SELECT role, count(*) FROM users GROUP BY role;"
    role    | count
------------+-------
 superadmin |     2
 admin      |     1
 advisor    |     1
 donor      |     1
 lxd        |     3
 mentor     |     1
 company    |     1
 student    |     5
 alumni     |     1
(9 rows)          ← los 9 roles presentes

$ npm test
 ✓ tests/completeness.test.ts        (16 tests)
 ✓ tests/schema-constraints.test.ts  (13 tests)
 ✓ tests/seed.test.ts                (14 tests)
 Test Files  3 passed (3)
      Tests  43 passed (43)
```

Los tests de completitud corren contra el seed y confirman el estado parcial:
fase 1 en 1/2 módulos, curso `crs_ia_1` al 100% para `est1` y al 33% para
`alum1`, Ruta incompleta.

### Pendiente

- La auditoría decía "13 usuarios" en su resumen del seed; el desglose que la
  acompañaba sumaba 16, que es lo correcto. Corregido en AUDITORIA_BACKEND.md.

---

## Fase 3 — Auth y autorización ✅

### Endpoints

| Método | Ruta | Qué hace |
|---|---|---|
| POST | `/auth/login` | correo + contraseña → access (12 h) + refresh |
| POST | `/auth/refresh` | rota el refresh y emite un par nuevo |
| POST | `/auth/logout` | revoca el refresh; siempre 204 |
| GET | `/auth/me` | usuario de la sesión |
| GET | `/health` | sin sesión |

### Decisiones que importan

**El access token dura 12 h, igual que la sesión de Flutter** hoy
(`AuthProvider.sessionDuration`), para que el cambio de backend no cambie el
comportamiento que la gente ya conoce.

**`requireAuth` carga el usuario de la base en cada petición**, no solo
verifica la firma. No es redundante: con un token de 12 h, sin esa consulta
una cuenta eliminada —o alguien a quien le acaban de quitar `can_grade`—
seguiría teniendo acceso hasta que el token venciera. **Los permisos se leen
del registro vivo, nunca del claim.** Es la respuesta a la observación 3 de la
auditoría.

**Refresh con rotación y detección de reuso.** Cada uso emite un par nuevo y
marca el anterior como reemplazado. Si llega un refresh **ya revocado**, se
interpreta como token robado y se revocan **todas** las sesiones de esa
persona. Hay un test que lo comprueba: se rota el token de una sesión, se
reusa el viejo, y la *otra* sesión —que no tenía nada que ver— también queda
cerrada.

**El refresh se guarda hasheado (SHA-256), nunca en claro.** Filtrar la tabla
`refresh_tokens` no permite iniciar sesión con ella. Hay un test que busca el
token literal en la tabla y confirma que no está.

**Login que no delata cuentas.** Mismo mensaje y mismo tiempo de respuesta
exista o no el correo — si no, el endpoint es un enumerador de usuarios. Con
un correo inexistente se compara igual contra un hash falso para no acortar la
respuesta.

**`assertCanGrade` distingue los dos contextos.** Open Learning y Enactus por
separado, contra el registro vivo. Admin y superadmin califican sin pasar por
el permiso (decisión C.5), y queda en `audit_log`.

**`requireEnactus` devuelve 403, no una respuesta vacía.** Una respuesta vacía
haría ver un bug de permisos como si fuera "no hay datos".

### Rate limiting — con una limitación que hay que decir

`/auth/login` acepta 10 intentos por **IP + correo** cada 5 minutos. Se agrupa
por los dos para frenar a quien prueba contraseñas contra una cuenta conocida
sin bloquear a toda una universidad que sale por la misma IP.

**El contador vive en memoria del proceso.** En Lambda cada instancia tiene la
suya, así que con N instancias vivas el límite efectivo es N veces el
configurado: esto frena un ataque ingenuo desde una IP, **no uno distribuido**.
El límite de verdad va en API Gateway (throttling) o WAF — anotado para la
Fase 6. Se implementó igual porque es la diferencia entre "cualquiera puede
probar mil contraseñas por segundo" y "no puede".

### Formato de error, único en toda la API

```json
{ "error": { "code": "forbidden", "message": "…", "details": … } }
```

`code` es el identificador estable que el cliente Flutter va a mirar; `message`
es para la persona. Un error inesperado se registra entero en el log del
servidor y al cliente le llega un mensaje genérico — nunca un detalle interno
de PostgreSQL.

### Verificación — salida real

```
$ npm run typecheck   → limpio
$ npm run lint        → limpio
$ npm test
 ✓ tests/auth.test.ts               (36 tests)
 ✓ tests/seed.test.ts               (14 tests)
 ✓ tests/completeness.test.ts       (16 tests)
 ✓ tests/schema-constraints.test.ts (13 tests)
 Test Files  4 passed (4)
      Tests  79 passed (79)
```

Y contra el servidor corriendo (`npm run dev`):

```
GET  /health                       → {"status":"ok",…}
POST /auth/login  (correcta)       → accessToken + refreshToken + user
POST /auth/login  (incorrecta)     → HTTP 401
GET  /auth/me     (con token)      → el usuario, SIN passwordHash
GET  /auth/me     (sin token)      → HTTP 401
GET  /no-existe                    → {"error":{"code":"not_found",…}}
```

El `exp` del token emitido es exactamente `iat + 43200` (12 h).

### Cobertura de los tests pedidos

| Pedido | Dónde |
|---|---|
| Login correcto e incorrecto | ✅ `auth.test.ts` |
| Token expirado → 401 | ✅ (se firma uno vencido con `signAccessTokenWithExpiry`) |
| Refresh rota el anterior | ✅ + detección de reuso |
| Cada rol contra endpoint protegido | ✅ los 9 roles contra `requireRole` |
| `can_grade = false` → 403 | ✅ con `lxd2` del seed |
| Un estudiante no lee datos de otro | ✅ `assertSelfOr` por HTTP |

Los tres últimos se ejercitan sobre rutas de prueba que montan los middlewares
reales, porque los endpoints de negocio llegan en la Fase 4. Cuando existan,
las mismas guardias se prueban sobre ellos.

---

## Fase 4 — API REST ✅

### Grupo 1 — CRUD de cursos, módulos y lecciones ✅

| Método | Ruta | Quién |
|---|---|---|
| GET | `/courses` | todos (alcance por rol) |
| GET | `/courses/:id` | todos (alcance por rol) |
| POST | `/courses` | lxd, admin, superadmin |
| PATCH | `/courses/:id` | su creador o admin |
| POST | `/courses/:id/publish` | su creador o admin |
| POST | `/courses/:id/archive` | su creador o admin |
| DELETE | `/courses/:id` | su creador o admin (lógico, con reglas) |
| POST | `/courses/:id/modules` | su creador o admin |
| PUT | `/courses/:id/modules/order` | su creador o admin |
| PATCH · DELETE | `/modules/:id` | su creador o admin |
| POST | `/modules/:id/lessons` | su creador o admin |
| PUT | `/modules/:id/lessons/order` | su creador o admin |
| PATCH · DELETE | `/lessons/:id` | su creador o admin |
| POST | `/lessons/:id/video-upload-url` | lxd, admin |
| POST | `/lessons/:id/video` | lxd, admin (confirma la subida) |
| POST | `/lessons/:id/video-external` | lxd, admin |

**El alcance de lectura es del servidor, no de la pantalla.**
`visibleCoursesFilter` traduce a SQL lo que hoy las vistas de Flutter hacen por
convención: el estudiante solo ve lo publicado y visible de sus laboratorios;
el LXD ve además sus propios borradores; el mentor lo que revisa; la empresa lo
de sus LXD; el asesor lo de los laboratorios de sus estudiantes; el donante,
nada. Pedir un id fuera del alcance devuelve **404, no 403**: un 403 ya
confirmaría que ese curso existe.

**Reordenamiento en un solo endpoint, no un PATCH por elemento.** Con
`unique(course_id, order_index)`, intercambiar dos módulos uno por uno falla en
el primer paso. Se hace en una transacción y en dos pasadas (primero índices
negativos, después los definitivos). Si la lista no incluye exactamente los
módulos del curso, responde 409 en vez de dejar el orden a medias.

**Borrado con la regla B.7.** Un curso con progreso de estudiantes o vinculado a
módulos de la Ruta devuelve **409** con el detalle de qué lo bloquea y sugiere
`POST /courses/:id/archive`. Sin eso, borrar un curso deja el objetivo
—y con él el módulo, la fase y la Ruta entera— bloqueado en silencio para todos
los estudiantes del laboratorio. Cuando sí se puede borrar, es lógico.

### Cambio de decisión respecto de la Fase 1 (migración 0002)

Se quitó el CHECK `lessons_video_type_requires_source`. **Hacía imposible el
flujo de subida**: el navegador necesita una lección existente para pedir la URL
firmada, pero la lección no se podía crear sin la key de S3, y la key no existe
hasta pedir la URL. La regla se movió a `POST /courses/:id/publish` — una
lección a medio construir puede estar vacía, un curso publicado no.

No se relajó nada más: `lessons_video_source` sigue vigente, así que la base
sigue impidiendo los dos orígenes a la vez o un origen que no corresponda al
`video_type`.

### Subida de video

Tres pasos, con el archivo **nunca** pasando por la API (API Gateway corta en
10 MB):

1. `POST /lessons/:id/video-upload-url` → valida **antes de firmar** (mp4/webm,
   ≤ 500 MB, rol con permiso de contenido) y devuelve la URL firmada.
2. El navegador hace `PUT` directo a S3.
3. `POST /lessons/:id/video` confirma; la key tiene que empezar por
   `lessons/<id>/`, para que nadie apunte su lección a un archivo ajeno.

**Sin S3 configurado responde 503 `storage_not_configured` diciendo qué falta**,
en vez de devolver una URL falsa que reventaría recién al subir.

### Un error que encontré y corregí en esta fase

Al escribir la migración 0002 a mano, el *snapshot* de Drizzle quedó
desactualizado y `db:generate` produjo una `0003` que volvía a borrar el mismo
CHECK — pero sin `IF EXISTS`. Sobre una base limpia eso abortaba la migración
entera con `42704` y dejaba **0 tablas**. Lo detectó el ciclo de verificación,
no la lectura del código. Se rehicieron ambas migraciones para que el snapshot
coincida con el esquema; ahora `db:generate` dice "No schema changes".

Un test de la Fase 1 quedó obsoleto por el cambio de 0002 (afirmaba que la base
rechaza una lección de video sin origen). **No se borró**: se reescribió para
afirmar el comportamiento nuevo y apunta a dónde vive ahora la regla.

### Verificación — salida real

```
$ npm run typecheck → limpio     $ npm run lint → limpio

$ npm test
 ✓ tests/schema-constraints.test.ts (14)   ✓ tests/auth.test.ts        (36)
 ✓ tests/courses.test.ts            (29)   ✓ tests/seed.test.ts        (14)
 ✓ tests/completeness.test.ts       (16)
 Test Files  5 passed (5)      Tests  109 passed (109)

$ db:migrate → rollback ×3 → migrate
inicio:    tablas=0  vistas=0  checks=0
migrate:   tablas=52 vistas=7  checks=22
rollback1: tablas=52 vistas=7  checks=23   ← 0002 restaura el CHECK
rollback2: tablas=52 vistas=0  checks=23
rollback3: tablas=0  vistas=0  checks=0
migrate:   tablas=52 vistas=7  checks=22
```

Y contra el servidor corriendo, con `curl`:

```
estudiante crea curso            → HTTP 403
LXD crea curso                   → 201, status=draft, creator=lxd1
publicar sin lecciones           → HTTP 409
lección + video externo          → videoType=external, videoS3Key=null
publicar ahora                   → HTTP 200
content-type video/quicktime     → HTTP 400
archivo de 600 MB                → HTTP 413
borrar curso con progreso        → 409 {rutaModules:1, objectives:2, …}
listado del estudiante           → solo los 2 cursos de sus laboratorios
```


### Grupo 2 — Completitud en el servidor ✅

| Método | Ruta |
|---|---|
| POST | `/progress/lessons/:lessonId/toggle` |
| GET | `/students/:id/ruta-progress` |
| GET | `/students/:id/course-progress/:courseId` |
| GET | `/students/:id/certificate-eligibility/:laboratoryId` |
| POST | `/certificates/ruta` |
| GET | `/certificates` |

**Este es el grupo donde la lógica deja de vivir en el navegador.** Ninguna
regla se recalcula acá: todo sale de las vistas de `0001_completeness.sql`, y
los servicios solo arman la forma que el cliente necesita.

**El toggle devuelve todo el efecto en una sola respuesta** — progreso del
curso, del módulo, de la fase y de la Ruta, más `certificateAvailable`. El
cliente no hace ninguna llamada adicional para saber en qué quedó. Y como un
mismo curso puede estar en la Ruta de varios laboratorios, `rutaImpact` es una
lista, no un objeto.

**Solo el propio estudiante escribe progreso.** El endpoint ni siquiera acepta
un `studentId`: opera siempre sobre la sesión. No existe "marcar completa a
otro" (decisión C.6) — sería una forma de fabricar progreso. La única vía
indirecta legítima es calificar una actividad, que completa su lección.

**Doble candado en el certificado**: el endpoint valida las 3 fases y responde
409 con el detalle de qué falta; el trigger de la base lo hace cumplir igual.
Si mañana aparece otra vía de escritura, el requisito sigue en pie.

### Grupo 3 — Aislamiento Enactus vs Open Learning ✅

No es una preferencia de interfaz. `requireEnactus` protege `/laboratories`,
`/projects`, `/groups`, `/forum-posts` y la Ruta de Impacto **enteros**, y
responde **403, nunca una lista vacía**: una lista vacía haría ver un bug de
permisos como si fuera "todavía no hay datos".

El tipo de estudiante sale **siempre** del registro del usuario. Hay un test
que manda `studentType: 'enactus'` y `role: 'admin'` en el cuerpo de la
petición para confirmar que el servidor los ignora.

Verificado además que manipular el id de la URL no da datos ajenos, que el
listado de cursos de un Open Learning no incluye ninguno de laboratorio, y que
su calendario no muestra eventos de Ruta ni de mentoría.

### Grupo 4 — Resto de entidades ✅

`/projects` · `/groups` (+ `PUT /groups/:id/members` con el rol de cada
integrante) · `/evidences` · `/calendar-events` · `/communication-resources` ·
`/notifications` · `/forum-posts` (+ respuestas, apoyos, fijar) ·
`/submissions` (+ `grade`, + `review`) · `/files/upload-url` ·
`/admin/users/:id/can-grade` · `/admin/backup` · `/admin/restore` ·
`/admin/storage/video`.

Cuatro cosas que vale la pena señalar:

- **Calificar y revisar son endpoints distintos.** El LXD pone nota (con
  `can_grade` **en el contexto del curso**, que sale del curso y no del
  cuerpo); el Mentor comenta y su endpoint no toca `grade` bajo ninguna
  circunstancia. Hoy en Flutter los dos usan el mismo `saveSubmission`.
- **El respaldo ya no lleva credenciales.** Se excluyen el hash de contraseña
  y las sesiones abiertas. Hoy `exportBackupJson()` vuelca la caja `users`
  entera, con contraseñas en texto plano, a un archivo descargable.
- **Restaurar quedó reservado al superadmin**, transaccional y con
  confirmación literal. Hoy cualquier Admin puede reemplazar la base entera
  desde un archivo elegido a mano.
- **El apoyo del foro es un INSERT o un DELETE.** Hoy es leer-modificar-
  escribir el post entero, que con dos personas dando like a la vez pierde uno.

### OpenAPI

`backend/openapi.yaml` — 3.1, todos los endpoints, con las reglas de negocio
explicadas donde importan (por qué 404 y no 403, por qué el reordenamiento es
un solo endpoint, por qué el video no pasa por la API).

**Y hay un test que lo mantiene honesto**: `tests/openapi.test.ts` compara el
documento contra las rutas realmente registradas en Hono y falla si aparece un
endpoint sin documentar, uno documentado que no existe, o un `$ref` roto. Sin
eso, una especificación envejece en silencio y termina mintiendo.

### Dos errores encontrados por los tests, no por leer el código

1. **500 en `GET /forum-posts`.** Mezclé una condición de Drizzle
   (`isNull(forumPosts.deletedAt)` → `"forum_posts"."deleted_at"`) dentro de
   una consulta cruda donde la tabla está aliasada como `p`. Compilaba, pasaba
   el lint, y reventaba en ejecución.
2. **Falso positivo revelador en el respaldo.** El test buscaba la cadena
   `password_hash` en la respuesta y la encontró — pero en mi propia nota
   explicativa dentro del JSON, no en un dato. Se cambió la nota y **se
   reforzó el test**: ahora verifica que no viaje ningún hash de bcrypt y que
   ninguna fila de usuario traiga esa clave.

### Verificación — salida real

```
$ npm run typecheck → limpio     $ npm run lint → limpio

$ npm test
 ✓ auth (36)   ✓ courses (29)      ✓ isolation (27)   ✓ entities (25)
 ✓ completeness-api (16)  ✓ completeness (16)  ✓ seed (14)
 ✓ schema-constraints (14)  ✓ flows (9)  ✓ openapi (3)
 Test Files  10 passed (10)      Tests  189 passed (189)

$ migrate → rollback ×3 → reset
migrate:   tablas=52 vistas=7
rollback3: tablas=0  vistas=0
reset:     tablas=52 vistas=7
db:generate → "No schema changes"
```

Contra el servidor corriendo:

```
Ruta de Impacto (estudiante)  → 2 laboratorios, fase 1 en 1/2 módulos,
                                 desbloqueo correcto, deadline=overdue
Open Learning → /laboratories, /projects, /groups, /forum-posts,
                /students/:id/ruta-progress   →  403 en los cinco
Enactus → la misma ruta                        →  200
POST /certificates/ruta sin completar          →  409 · 0/3 fases · faltan 3
GET  /admin/backup      → 16 usuarios, sin ningún "$2b$", 22 columnas
GET  /admin/storage/video → 14 lecciones con video
```

### Subida de archivos: verificada de punta a punta contra AWS real ✅

Bucket `enactus-media-dev` (us-east-1), creado con acceso público bloqueado y
CORS para `localhost:8080`, `localhost:3000` y `saraisaza.github.io` — sin ese
CORS el `PUT` del navegador falla con un error de red que no dice nada útil.

Los tres pasos, con un archivo real de 1 MB:

```
paso 1  POST /lessons/:id/video-upload-url
        → key=lessons/<id>/<uuid>.mp4 · expira en 900s
        → host=enactus-media-dev.s3.us-east-1.amazonaws.com
paso 2  PUT directo del cliente a esa URL          → HTTP 200
        head-object en el bucket                    → 1048576 bytes
paso 3  POST /lessons/:id/video (confirmación)
        → videoType=uploaded · videoSizeBytes=1048576

y las validaciones siguen activas:
        content-type video/quicktime → 400
        archivo de 600 MB            → 413
```

El objeto de prueba se borró del bucket al terminar.

Los tests que antes daban por sentado el 503 ahora **afirman las dos ramas
explícitamente**: con bucket configurado exigen una URL firmada de verdad
(`X-Amz-Signature` presente, `X-Amz-Expires=900`, key bajo `lessons/<id>/`);
sin bucket, exigen que el 503 diga qué falta. La suite no depende de si quien
la corre tiene AWS.

### Lo que sigue sin verificar

**Las URLs firmadas de CloudFront** para *servir* el video. El esquema y los
endpoints ya distinguen `external` de `uploaded`, y la subida funciona, pero
generar la URL de reproducción necesita una distribución de CloudFront con su
key group — va en la Fase 6.

Hasta entonces el video propio está guardado y es recuperable con credenciales,
pero no hay forma de reproducirlo desde el cliente.
