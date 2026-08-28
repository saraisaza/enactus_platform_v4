# Progreso del backend — Enactus Platform

Estado por fase. Nada se marca como hecho sin haber corrido los comandos de
verificación y pegado su salida real.

| Fase | Estado | Cierre |
|---|---|---|
| 0 — Auditoría y requerimientos | ✅ Cerrada | 28 ago 2026 · aprobada |
| 1 — Esquema Postgres | ✅ Cerrada | 28 ago 2026 |
| 2 — Migraciones y seed | ⬜ Pendiente | — |
| 3 — Auth y autorización | ⬜ Pendiente | — |
| 4 — API REST | ⬜ Pendiente | — |
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
