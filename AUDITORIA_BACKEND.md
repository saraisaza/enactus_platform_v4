# Auditoría de backend — Enactus Platform (Fase 0)

**Fecha:** 28 de agosto de 2026 · **Alcance:** solo lectura. No se escribió
código en esta fase.

## Método y honestidad del alcance

Leídos **línea por línea, completos**: `lib/models/models.dart` (1446 l.),
`lib/providers/data_provider.dart` (1205 l.), `lib/providers/auth_provider.dart`,
`lib/services/db_service.dart`, `lib/services/data_store.dart`,
`lib/services/migration_service.dart`, `lib/services/seed_service.dart` (907 l.),
`lib/utils/constants.dart`, `lib/main.dart`, `lib/widgets/app_image.dart`.

Leídos **en las secciones relevantes** (calificación, completitud, entregas,
permisos): `lxd_portal.dart`, `mentor_portal.dart`, `course_detail_view.dart`,
`admin_portal.dart`, `company_portal.dart`, `communication_resources_view.dart`.

Mapeados **por rastreo mecánico de llamadas** (no lectura completa): quién
invoca cada método de escritura de `DataProvider`, en los 52 archivos de
`lib/`. Ese rastreo es la base de la matriz de permisos de la sección C:
cuando una celda dice "no deducible", es porque el código no lo decide en
ningún lado, no porque no se haya mirado.

**Todos los campos de la sección A.1 salen del código real** (`toJson`/
`fromJson` de cada modelo y de los getters sobre `extra`), no de suposiciones
ni de documentación.

---

## Observaciones sobre las decisiones cerradas

Tres cosas que conviene tener en el radar. No cambian ninguna decisión, solo
tienen costo o consecuencia concreta y es más barato saberlo ahora:

1. **Lambda en VPC + RDS privada obliga a resolver la salida a S3 y Secrets
   Manager.** Un NAT Gateway son ~32 USD/mes fijos; un *Gateway endpoint* para
   S3 es gratis y un *Interface endpoint* para Secrets Manager ~7 USD/mes. Se
   decide en la Fase 6, pero conviene presupuestarlo con endpoints, no con NAT.
2. **`db.t4g.micro` tiene ~80-100 conexiones máximas** y Lambda abre una por
   ejecución concurrente. Con picos de concurrencia se agota. Mitigación
   barata: pool de 1 conexión por Lambda + `idle_timeout` corto; si no alcanza,
   RDS Proxy (~15 USD/mes).
3. **Un access token de 12 h sin revocación deja una ventana de 12 h.** Si a un
   usuario se le quita `can_grade` o se le elimina la cuenta, su token sigue
   siendo válido hasta que expire. Dado que `can_grade` es justo el permiso que
   más se va a activar y desactivar, propongo verificar `can_grade` y el estado
   de la cuenta **contra la BD** en el middleware de las rutas sensibles, no
   solo contra el claim del JWT. Es una consulta por request en un puñado de
   endpoints, no en todos.

---

# A. Auditoría del código actual

## A.1 Las 18 cajas de Hive y sus campos reales

`DbService.boxNames` (`db_service.dart:14-33`) declara 18 cajas. **18 cajas no
son 18 entidades** — es el primer hallazgo estructural de esta auditoría:

- **`content` guarda dos documentos sin relación** entre sí: la clave `site`
  (el `SiteContent` del landing) y la clave `migrations` (el registro de
  migraciones aplicadas, escrito por `MigrationService`). En Postgres son dos
  tablas distintas.
- **`session` no es una entidad de dominio**: guarda `{userId, expiresAt}` bajo
  la clave `current`. Desaparece en el backend (la reemplaza el JWT + tabla de
  refresh tokens).
- **`mentor_notes` no tiene clase de modelo**: se escribe como un mapa suelto
  `{studentId, courseId, note}` con clave `'$studentId::$courseId'`
  (`data_provider.dart:1104-1114`).
- **Ocho tipos anidados no tienen caja propia** pero sí necesitan tabla:
  `Phase`, `Objective`, `RutaModule`, `Lesson`, `CourseModule`, `QuizQuestion`,
  `ActivityConfig`, `ForumReply`.

**Conteo real para el esquema: ~35 tablas**, no 18.

---

### 1. `users` → `AppUser`

Columnas de primer nivel: `id`, `name`, `email`, `password` *(texto plano —
ver A.8)*, `role`, `phone`, `cedula`, `extra` (mapa libre).

`extra` es una bolsa sin esquema. Estos son **todos** los campos que el código
lee o escribe de ella, con el getter que los expone:

| Clave en `extra` | Tipo | Rol al que aplica | Getter |
|---|---|---|---|
| `courseIds` | `List<String>` | student/alumni (Open Learning) | `courseIds` |
| `labIds` | `List<String>` | student/alumni (Enactus) | `labIds` |
| `studentType` | `String` (`enactus`\|`open_learning`) | student/alumni | `studentType` (default `enactus`) |
| `canGradeOpenLearning` | `bool` | lxd | default **`true`** |
| `canGradeEnactus` | `bool` | lxd | default **`false`** |
| `reviewCourseIds` | `List<String>` | mentor | `reviewCourseIds` |
| `university` | `String` | student/alumni, advisor | `university` |
| `career` | `String` | student/alumni | `career` |
| `city` | `String` | todos | `city` |
| `groupId` | `String?` | student/alumni | `groupId` |
| `companyId` | `String?` | student/alumni, lxd, mentor | `companyId` |
| `donorId` | `String?` | student/alumni | `donorId` |
| `labId` | `String?` | — | `labId` (getter existe, **sin uso real**) |
| `companyName` | `String` | company | `companyName` |
| `impactCode` | `String` | donor | `impactCode` |
| `avatarBase64` | `String?` | todos | `avatarBase64` → **S3** |
| `joinedAt` | ISO 8601 | todos | `joinedAt` |
| `company`, `position`, `specialty`, `languages`, `availability`, `experience`, `interests` | `String` | lxd, mentor | sin getter — se leen directo de `extra` en el perfil |

**Para el esquema:** todo lo que tiene getter y semántica clara pasa a columna
tipada (o a tabla puente, en el caso de `courseIds`/`labIds`/`reviewCourseIds`).
`extra` JSONB sobrevive solo para los 7 campos de perfil libre de LXD/Mentor,
que son texto sin estructura.

### 2. `projects` → `Project`
`id`, `name`, `description`, `problem`, `solution`, `community`,
`ods` (`List<String>`), `stage` (catálogo `projectStages`, 6 valores),
`impactIndicators`, `expoEnabled` (bool), `createdAt` (`DateTime?`).

### 3. `groups` → `Group`
`id`, `name`, `projectId`, `university`, `advisorId`, `studentIds` (`List<String>`).
→ `studentIds` es la tabla puente `group_members`, **y es donde falta
`role_in_project`** (ver BLOQUEOS.md § 2 del frontend).

### 4. `labs` → `Laboratory`
`id`, `name`, `description`, `objectives` (texto libre), `mentorIds`
(`List<String>` → tabla puente `laboratory_mentors`), `sponsorCompanyId`,
`phases` (`List<Phase>`, **siempre 3**, autogeneradas si vienen vacías).

Compatibilidad viva en `fromJson`: si solo existe `mentorId` (String, legado),
lo envuelve en lista.

**`Phase`** (anidada): `id`, `order`, `title`, `description`, `deadline`
(ISO o vacío), `objectives` (`List<Objective>`), `modules` (`List<RutaModule>`).

**`Objective`** (anidada): `id`, `category` (`Emprendimiento`|`Empresarial`),
`text`, `sourceCourseIds` (`List<String>` → m:n con `courses`).

**`RutaModule`** (anidada): `id`, `order`, `title`, `isMentorshipModule` (bool),
`courseIds` (`List<String>` → m:n con `courses`), `ownLessons` (`List<Lesson>`).

### 5. `courses` → `Course`
`id`, `name`, `subtitle`, `description`, `fullDescription`, `coverImagePath`,
`introVideoPath`, `labId`, `creatorId`, `modules` (`List<CourseModule>`),
`isRutaExpo` (legado), `projectId` (legado), `isOpenLearning`, `level`,
`estimatedHours`, `language`, `status` (`Borrador`|`Publicado`|`Archivado`),
`tags`, `objectives`, `entrepreneurshipObjectives`, `businessObjectives`,
`competencies`, `learningOutcomes`, `prerequisiteCourseIds`, `ods`,
`generatesCertificate`, `certifiedHours`, `openDate`, `closeDate`,
`maxStudents`, `visible`, `sponsorCompanyId`. Derivados: `lessonCount`,
`isPublished`.

Compatibilidad viva: `creatorId` cae a `mentorId` si el registro es anterior al
rename Mentor→LXD.

**`CourseModule`**: `id`, `title`, `lessons`.
**`Lesson`**: `id`, `title`, `type` (`LessonType`: video/pdf/resource/link/quiz/
activity/survey), `resourcePath`, `description`, `durationMin`,
`quiz` (`List<QuizQuestion>`), `activity` (`ActivityConfig?`).
→ `Lesson` la usan **dos padres distintos**: `CourseModule.lessons` y
`RutaModule.ownLessons`. En el esquema hay que decidir entre una tabla `lessons`
con dos FK nullables o dos tablas; recomiendo una sola con
`CHECK (course_module_id IS NOT NULL) <> (ruta_module_id IS NOT NULL)`.

**`QuizQuestion`**: `kind` (`multiple`|`truefalse`|`short`|`fill`|`order`),
`question`, `options`, `answerIndex`, `answerText`. ← **la clave de respuestas.**
**`ActivityConfig`**: `description`, `deadline`, `requiresFile`, `requiresText`,
`maxFiles`, `allowedTypes`, `gradingMode` (`points100`|`passfail`|`review`),
`rubric` (`List<{criterion, points}>`).

### 6. `progress` → `Progress`
Clave compuesta `'$studentId::$courseId'`. Campos: `studentId`, `courseId`,
`completedLessonIds` (`List<String>`), `updatedAt`.
→ En Postgres: `progress(student_id, course_id)` + `progress_lessons`.

### 7. `ruta_progress` → `RutaProgress`
Clave `'$studentId::$labId'`. `studentId`, `labId`,
`completedOwnLessonIds`, `updatedAt`.

### 8. `submissions` → `Submission`
`id`, `courseId`, `rutaModuleId` *(mutuamente excluyentes)*, `studentId`,
`groupId` *(mutuamente excluyentes: individual o grupal)*, `lessonId`
(vacío = entrega libre), `taskName`, `comment`, `filePath` → **S3**,
`grade` (`double?`), `feedback`, `date`.
→ Cuatro campos que son "uno u otro" y hoy se codifican con string vacío.
En Postgres: nullable + `CHECK`.

### 9. `certificates` → `Certificate`
`id`, `code`, `studentId`, `studentName` *(desnormalizado)*, `labId`,
`labName` *(desnormalizado)*, `issuerName` *(desnormalizado — string, no FK)*,
`hours`, `date`. Compatibilidad viva con certificados por curso (`courseId`/
`courseName`/`mentorName`).
→ `issuerName` como string suelto es un problema: `_LxdCertificates` filtra
"los que emití yo" con `c.issuerName == lxd.name`, o sea **por nombre**. Dos
personas homónimas se ven los certificados. En el esquema va `issued_by` FK.

### 10. `expo_checklists` → `ExpoChecklist`
Clave = `groupId`. `items` (`List<{label, done}>`). Legado RUTA NATIONAL EXPO.

### 11. `evidences` → `Evidence`
`id`, `donorId`, `type` (`foto`|`video`|`testimonio`|`reporte`|`historia`),
`title`, `description`, `resourcePath` → **S3**, `date`.
→ **Falta `projectId`** (ver BLOQUEOS.md § 2 del frontend).

### 12. `comm_resources` → `CommunicationResource`
`id`, `title`, `description`, `type` (`archivo`|`enlace`), `fileName`,
`fileBase64` → **S3**, `url`, `uploadedBy`, `date`.

### 13. `notifications` → `AppNotification`
`id`, `userId`, `title`, `body`, `date`, `read`.

### 14. `forum_posts` → `ForumPost`
`id`, `authorId`, `body`, `date`, `category` (`pregunta`|`avance`|`recurso`|
`anuncio`), `replies` (`List<ForumReply>`), `likedBy` (`List<String>`), `pinned`.
**`ForumReply`**: `id`, `authorId`, `body`, `date`.
→ `replies` → tabla `forum_replies`; `likedBy` → tabla `forum_likes`.

### 15. `calendar_events` → `CalendarEvent`
`id`, `title`, `description`, `start`, `type` (`openLearningSync`|`rutaImpacto`|
`mentoria`), `meetLink`, `guests` (texto libre), `courseId`, `labId`.

### 16. `content` → dos documentos
- `site` → `SiteContent`: `heroTitle`, `heroSubtitle`, `bannerText`,
  `aboutText`, `meetingLink`, `statStudents`, `statProjects`, `statLabs`,
  `statUniversities`, `galleryImages` (`List<String>` base64 → **S3**).
- `migrations` → `{done: List<String>}`.

### 17. `session` → `{userId, expiresAt}`. Desaparece en el backend.

### 18. `mentor_notes` → `{studentId, courseId, note}`, clave compuesta.

---

## A.2 Métodos públicos de `DataProvider`, agrupados y clasificados

**Leyenda:**
`CRUD` = endpoint genérico REST ·
`Q` = consulta derivada (se resuelve con filtro/JOIN/`include` en el endpoint de
listado, sin endpoint propio) ·
**`D`** = lógica de dominio, endpoint propio ejecutado en servidor ·
**`D!`** = dominio **y** además hoy es falsificable desde el cliente (ver A.8).

### Usuarios
| Método | Qué hace | Clase |
|---|---|---|
| `users` | todos los usuarios, con `password` y `extra` completos | `Q` |
| `usersByRole(role)` | filtro por rol | `Q` |
| `studentsAndAlumni` | `role in (student, alumni)` | `Q` |
| `userById(id)` | uno | `CRUD` |
| `findByCredentials(email, pwd)` | compara `u.password == password` en claro | **`D!`** → `POST /auth/login` |
| `saveUser(u)` | upsert completo (incluye `can_grade`) | **`D!`** → separar en `POST/PATCH /users` + `PATCH /admin/users/:id/can-grade` |
| `deleteUser(id)` | borrado duro, sin cascada | **`D`** → borrado lógico |

### Proyectos
| Método | Clase |
|---|---|
| `projects`, `projectById`, `saveProject`, `deleteProject` | `CRUD` |
| `projectsForStudents(students)` | proyectos vía el `Group` de cada estudiante, sin duplicados | `Q` (JOIN) |

### Grupos
`groups`, `groupById`, `saveGroup`, `deleteGroup` → `CRUD`.
→ `saveGroup` mueve `studentIds`: en el backend es `PUT /groups/:id/members`,
porque además tendrá que escribir `role_in_project`.

### Laboratorios
`labs`, `labById`, `saveLab`, `deleteLab` → `CRUD`, **pero** `saveLab` hoy
escribe el laboratorio **entero con sus 3 fases, objetivos y módulos anidados**.
Al normalizar, se parte en endpoints por nivel (`/labs/:id/phases/:n/modules`…).

### Cursos
| Método | Clase |
|---|---|
| `courses`, `courseById`, `saveCourse`, `deleteCourse` | `CRUD` (`saveCourse` con el mismo problema de anidamiento que `saveLab`) |
| `coursesByLab(labId)` | `Q` |
| `studentHasCourse(student, course)` | **regla de acceso**: Enactus → automático por `labIds`; Open Learning → solo `courseIds` | **`D`** — decide qué ve cada quien, va en el servidor |
| `coursesForStudent(student)` | aplica la regla anterior | **`D`** |

### Progreso
| Método | Clase |
|---|---|
| `progressFor(sid, cid)` | lee o devuelve vacío | `CRUD` |
| `courseProgress(sid, course)` | `done / lessonCount` | **`D`** (vista/función Postgres) |
| `overallProgress(student)` | promedio sobre sus cursos | **`D`** |
| `toggleLesson(sid, cid, lid)` | **alterna** sin validar nada | **`D!`** → `POST /progress/lessons/:id/toggle` |
| `markLessonComplete(...)` | marca sin alternar (lo usa la calificación) | **`D`** |

### Ruta de Impacto — **el corazón de la lógica de dominio**
| Método | Regla exacta | Clase |
|---|---|---|
| `rutaProgressFor`, `saveRutaProgress` | | `CRUD` |
| `toggleOwnLesson` | alterna una lectura/entrega propia del módulo | **`D!`** |
| `isObjectiveComplete(sid, o)` | `sourceCourseIds` no vacío **y** los 100% completos | **`D`** |
| `isModuleComplete(sid, labId, m)` | `ownLessons` todas marcadas **y** `courseIds` todos al 100%; un módulo vacío **nunca** cuenta | **`D`** |
| `isPhaseComplete(sid, labId, phase)` | ≥1 módulo **y** todos completos | **`D`** |
| `isModuleUnlocked(..., index)` | índice 0 siempre; el resto requiere el anterior completo | **`D`** |
| `isPhaseUnlocked(..., index)` | fase 1 siempre; el resto requiere la anterior completa | **`D`** |
| `isRutaComplete(sid, labId, lab)` | las 3 fases completas | **`D!`** ← requisito del certificado |
| `completedLabsForStudent(sid)` | labs con la Ruta completa | **`D!`** |
| `labModuleProgress(sid, lab)` | `(done, total)` de módulos de todo el lab | **`D`** |
| `labPhaseContentPublished(phase)` | si la fase tiene objetivos o módulos | `Q` |

### Deadlines de fase
| Método | Clase |
|---|---|
| `deadlineWarningWindow` (const, 3 días) | catálogo |
| `phaseDeadlineStatus(sid, labId, phase)` | `none`/`onTrack`/`approaching`/`overdue`; una fase completa nunca está atrasada | **`D`** |
| `checkPhaseDeadlineAlerts()` | recorre todos los labs y notifica a estudiantes en riesgo y a sus mentores; dedup **por título de notificación** | **`D`** → **tarea programada** (EventBridge + Lambda), no una llamada al abrir la app como hoy (`main.dart:46`) |

### Vinculación Curso → Fase → Módulo
| Método | Clase |
|---|---|
| `normalizeMentorshipFlags(phase)` | el último módulo es siempre el de mentoría; se recalcula | **`D`** |
| `importCourseObjectives(phase, course)` | copia los objetivos del curso a la fase, fusionando por texto+categoría | **`D`** |
| `linkCourseToModule(...)` | saca el curso de cualquier otro módulo del lab, lo agrega, importa objetivos, asigna `labId` si faltaba | **`D`** — transacción de varias tablas |
| `unlinkCourseFromModules(labId, cid)` | **sin llamadores en la UI** — código muerto hoy | **`D`** (necesario igual: hoy no hay forma de desvincular) |

### Empresa aliada
`lxdsForCompany`, `coursesForCompany`, `labsForCompany`, `companiesForLab` → `Q`
(cadenas de JOIN). `labsForCompany` mezcla dos criterios: labs con cursos de sus
LXD **más** los marcados a mano con `sponsorCompanyId`.

### Entregas
`submissions`, `submissionsForStudent/ForGroup/ForCourse` → `Q`.
`saveSubmission` → **`D!`**: hoy es un upsert genérico usado tanto por el
estudiante (crear entrega) como por LXD/Mentor (escribir `grade`/`feedback`).
**En el backend son dos endpoints con permisos distintos.**
`deleteSubmission` → `CRUD` (sin llamadores en la UI hoy).

### Certificados
`certificates`, `certificatesForStudent` → `Q`.
`issueRutaCertificate({student, lab, issuerName})` → **`D!`**: genera código
`ENC-<año>-<5 dígitos aleatorios>`, calcula horas con `_rutaHours` (suma las
horas de los cursos únicos de los 3 fases), guarda y notifica. **No verifica que
la Ruta esté completa ni que quien emite tenga permiso** — eso lo hace la
pantalla antes de llamar.

### Resto
| Grupo | Métodos | Clase |
|---|---|---|
| Checklist Expo | `checklistFor`, `saveChecklist` (**sin llamadores**) | `CRUD` |
| Evidencias | `evidences`, `evidencesForDonor`, `saveEvidence`, `deleteEvidence` | `CRUD` + `Q` |
| Recursos com. | `communicationResources` (ordenado por fecha), `save`, `delete` | `CRUD` |
| Notificaciones | `notificationsFor`, `notify`, `markNotificationsRead` | `CRUD` + **`D`** (`notify` lo dispara el dominio, no el cliente) |
| Foro | `canAccessForum` **`D`**; `forumPosts`, `forumPostById` `Q`; `saveForumPost`, `deleteForumPost` `CRUD`; `toggleForumLike`, `addForumReply`, `setForumPinned` **`D`** (leen-modifican-escriben el post entero → condición de carrera en concurrencia real); `activeForumUsersThisWeek`, `mostActiveForumTeams` **`D`** (agregados) |
| Site content | `siteContent`, `saveSiteContent` | `CRUD` (singleton) |
| Consultas cruzadas | `labsForMentor`, `studentsForMentor`, `reviewableCoursesForMentor`, `reviewsCountForMentor`, `mentorsForLab`, `studentsForCreator`, `labsForStudent`, `lxdForLab`, `teamsInLabArea`, `studentsForAdvisor`, `studentsForCompany`, `studentsForDonor`, `studentsInCourse` | `Q` — **son exactamente los filtros de aislamiento que el backend tiene que reimponer** (ver A.8 § 7) |
| Calendario | `calendarEvents`, `save`, `delete` `CRUD`; `openLearningCoursesForCreator` `Q`; `calendarEventsFor(user)` **`D`** — 5 ramas por rol, es una regla de visibilidad |
| BuscaTalento | `completedObjectivesFor(student)`, `talentSearchStudents()` | **`D`** (agregado + ranking) |
| Seguimiento | `courseStats(course)`, `lastActivity(sid, cid)` | **`D`** (agregados) |
| Notas mentor | `mentorNote`, `saveMentorNote` | `CRUD` |
| Métricas | `hoursByCompetency`, `odsCompletionRate`, `sponsoredHoursByCompany` | **`D`** (agregados pesados — hoy iteran todos los cursos × todos los estudiantes en el navegador) |
| Respaldo | `exportBackupJson`, `importBackupJson` | **`D!`** — ver A.8 § 6 |
| Utilidad | `newId(prefix)` = `prefix_<millis>_<rnd 0-9998>` | desaparece: los ids los genera Postgres |

**Total: ~95 miembros públicos.** Tres nunca se llaman desde la UI
(`saveChecklist`, `saveRutaProgress` directo, `unlinkCourseFromModules`).

---

## A.3 `DbService`: métodos y quién los llama

Implementa `DataStore` (`data_store.dart`), un contrato de 6 operaciones.

| Método | Firma | Quién lo llama |
|---|---|---|
| `getAll(box)` | **síncrono** → `List<Map>` | solo `DataProvider` (todos los getters de colección) |
| `get(box, id)` | **síncrono** → `Map?` | `DataProvider` (todos los `*ById`), **y `AuthProvider.tryRestoreSession`** y `MigrationService` |
| `put(box, id, json)` | `Future<void>` | `DataProvider` (todos los `save*`), `AuthProvider.login`, `MigrationService`, `SeedService` |
| `delete(box, id)` | `Future<void>` | `DataProvider` (todos los `delete*`), `AuthProvider.logout`/`tryRestoreSession` |
| `isEmpty` | `bool` (mira solo la caja `users`) | `SeedService.seedIfEmpty` |
| `exportAll()` | `Map` con las 18 cajas | `DataProvider.exportBackupJson` → `admin_backup.dart:112` |
| `importAll(backup)` | `box.clear()` + repoblar, en las 18 cajas | `DataProvider.importBackupJson` → `admin_backup.dart:146` |

**El punto crítico para la Fase 5, ya documentado en `data_store.dart:5-23`:**
`getAll` y `get` son **síncronos** porque Hive es local. Una API no puede
cumplir esa firma honestamente. Las ~40 pantallas leen los getters de
`DataProvider` de forma síncrona dentro de `build()`. O `DataProvider` se
vuelve async y se adapta cada pantalla, o Hive queda como caché. **Esta es la
decisión de mayor impacto de toda la Fase 5** y la abordo en su propio plan,
no aquí.

**Fuera de `DataProvider`, tres consumidores directos de `db`:**
`AuthProvider` (caja `session`), `MigrationService` (cajas `content` y `users`)
y `SeedService` (todas). Los tres desaparecen o cambian de forma en el backend.

---

## A.4 Qué hace hoy `MigrationService`

53 líneas. Un solo mecanismo y una sola migración:

- `runAll()` lee el conjunto de migraciones aplicadas de `content/migrations`
  (`{done: [...]}`) y aplica las que falten. Se invoca en `main.dart:36`,
  **antes** de sembrar o leer cualquier dato.
- La única migración registrada es **`role_mentor_to_lxd_v1`**: recorre
  `users` y a todo registro con `role == 'mentor'` le pone `role: 'lxd'`,
  conservando id, historial, cursos creados y laboratorios. No toca nada más.
- **El guard es lo importante y está bien puesto**: sin el registro en
  `content/migrations`, la migración volvería a convertir en LXD a las cuentas
  de Mentor **nuevas** que el Admin cree después — porque el string `mentor` se
  reutilizó con un significado completamente distinto.

**Para el backend:** esto **no es una migración**. `lxd` y `mentor` son dos
roles distintos que coexisten, y así se definen en el `enum user_role` y en el
seed desde el día uno. `MigrationService` sobrevive en Flutter **solo** para
navegadores que todavía tengan datos legacy en IndexedDB, y se marca para
borrar tras el corte del 1 de octubre.

---

## A.5 Qué genera `SeedService`

`seedIfEmpty()` no hace nada si `db.isEmpty` es falso, salvo `_upgradeDemoCourse()`
(reemplaza `crs_ia_1` por su versión LMS completa **solo si el usuario no lo
personalizó** — detecta "sin tocar" por `subtitle` vacío + `competencies` vacío
+ `!generatesCertificate`).

Con la BD vacía siembra, en este orden:

**Usuarios (16).** 2 superadmin (`sa1`, `sa2`) · 1 admin (`adm1`) · 3 lxd
(`lxd1` Bancolombia/IA, `lxd2` EPM/agua, `lxd3` Bancolombia/impacto) · 1 mentor
(`ment1`) · 1 advisor (`adv1`, Uniandes) · 1 company (`emp1` Bancolombia) ·
1 donor (`don1`, `impactCode ENACTUS-2026-4589`) · 4 student (`est1`-`est4`) ·
1 student Open Learning (`est_ol1`) · 1 alumni (`alum1`).
**Contraseñas en texto plano en el código** (`Super123`, `Admin123`, `Est123`…).

**Laboratorios (6).** `lab_ia` (con Ruta de Impacto real: fase 1 con 2 objetivos
y 2 módulos, uno de ellos el de mentoría; fase 2 y 3 vacías) · `lab_agua` ·
`lab_energia` · `lab_impacto` · `lab_emprendimiento` · `lab_agricultura`
(estos 5 con las 3 fases vacías por defecto).
Dos deadlines pensados como demo: `lab_ia_fase1` vencida (`2026-07-01`) y
`lab_ia_fase2` próxima a vencer (`2026-08-02`).

**Proyectos (2)** `prj1` AquaVida, `prj2` SolAndino. **Grupos (2)** `grp1`
(est1, est2, alum1), `grp2` (est3, est4), ambos con `advisorId: adv1`.
**Checklists Expo (2)**, 7 ítems cada una.

**Cursos (9).** 2 de RUTA NATIONAL EXPO (legado) · `crs_ia_1` (el curso demo
completo: 2 módulos, 6 lecciones, quiz de 4 tipos de pregunta, actividad con
rúbrica de 5 criterios, encuesta, certificado 8 h) · 5 de laboratorio ·
1 Open Learning (`crs_ol_marketing`).

**Actividad de demostración.** 7 filas de `progress` · 3 `submissions` (una
calificada 4.5, una sin calificar, una grupal) · 3 `evidences` para `don1` ·
2 `notifications` · 4 `forum_posts` (uno fijado) · el `SiteContent` por defecto.

**Lo que el seed de la Fase 2 tiene que replicar tal cual** (nada inventado):
los 13 usuarios con sus mismos roles y relaciones, los 6 labs, la Ruta real de
`lab_ia`, los 9 cursos, y la actividad de demostración. **Lo que hay que
agregar** porque el prompt lo pide y hoy no existe: un LXD con `can_grade=true`
y otro con `false` (hoy los 3 LXD usan los defaults implícitos: OL activo,
Enactus desactivado — o sea, hoy **ninguno** puede calificar Enactus ni emitir
certificados), y un estudiante con la Ruta de Impacto parcialmente completa
(hoy `est1` tiene 2 de 3 lecciones de `crs_ia_1`, lo cual deja la fase 1
incompleta y por lo tanto **ninguna** Ruta completa en todo el seed).

---

## A.6 Dónde vive hoy la lógica de completitud

**Toda en el cliente, en `data_provider.dart`**, como funciones puras
recalculadas en cada `build()` de cada pantalla:

```
courseProgress   = |completedLessonIds| / course.lessonCount        (línea 178)
isObjectiveComplete = sourceCourseIds ≠ ∅ ∧ ∀c: courseProgress ≥ 1  (252)
isModuleComplete = (ownLessons ≠ ∅ ∨ courseIds ≠ ∅)
                   ∧ ∀ownLesson ∈ completedOwnLessonIds
                   ∧ ∀courseId: courseProgress ≥ 1                  (265)
isPhaseComplete  = modules ≠ ∅ ∧ ∀m: isModuleComplete               (279)
isRutaComplete   = phases ≠ ∅ ∧ ∀p: isPhaseComplete                 (302)
```

Y el desbloqueo: `isModuleUnlocked` (índice 0 libre, el resto exige el anterior
completo) y `isPhaseUnlocked` (fase 1 libre, el resto exige la anterior).

**Lo que se escribe** es solo el hecho atómico: `Progress.completedLessonIds`
y `RutaProgress.completedOwnLessonIds`. **Nada de completitud se persiste** —
no hay campo `isComplete` en ningún lado. Eso es una decisión de diseño buena y
hay que conservarla: en Postgres son **vistas o funciones**, no columnas
desnormalizadas que se puedan desincronizar.

Tres detalles no obvios que hay que preservar exactamente:
1. **Un módulo sin nada configurado nunca cuenta como completo** — evita que un
   módulo vacío se vea "listo" antes de que el Admin lo configure.
2. **Un objetivo sin `sourceCourseIds` nunca se completa** — no se puede marcar
   a mano.
3. **La completitud se deriva, se recalcula sola.** Si el LXD agrega un curso a
   un módulo, el módulo deja de estar completo automáticamente. → **Pregunta B.1.**

Dos puntos de entrada escriben progreso: `toggleLesson` (el estudiante marca) y
`markLessonComplete` (la calificación de una actividad la completa — a
diferencia del quiz/encuesta, que se autocompletan al responder).

---

## A.7 Dónde vive hoy la lógica de calificación y quién puede calificar

**El permiso.** No es un solo `can_grade`: son **dos**, separados por contexto,
ambos en `AppUser.extra` (`models.dart:69-74`):
- `canGradeOpenLearning` — **default `true`** (el LXD es el docente del curso).
- `canGradeEnactus` — **default `false`**.

Los edita **solo el Admin/Super Admin**, desde `showUserDialog`
(`admin_portal.dart:814-827`, dos `Switch`; se escriben en `extra` en la
línea 933-934). El LXD los ve en su perfil como texto de solo lectura
(`lxd_portal.dart:1072-1074`).

**Quién califica, hoy:**

| Rol | Qué puede hacer | Dónde |
|---|---|---|
| **LXD** | poner **nota + retroalimentación**, solo en cursos que él creó y solo si el permiso del contexto está activo | `_LxdGrading` (`lxd_portal.dart:600-876`) |
| **Mentor** | **solo comentario, sin nota** — explícito en la UI: *"Comentario (sin nota: el Mentor no califica)"* | `_review` (`mentor_portal.dart:351-389`) |
| **LXD** | **emitir certificado** de Ruta de Impacto, solo si `canGradeEnactus` | `_LxdCertificates` (`lxd_portal.dart:883-1022`) |
| Admin / Super Admin | **no califican** — no hay ninguna pantalla de calificación en el portal Admin | — |

**Cómo se aplica el permiso hoy — y por qué no sirve:**

```dart
// lxd_portal.dart:611-615 — filtra la LISTA de entregas visibles
final gradableCourseIds = myCourses
    .where((c) => c.isOpenLearning ? lxd.canGradeOpenLearning
                                   : lxd.canGradeEnactus)
    .map((c) => c.id).toSet();

// lxd_portal.dart:909 — esconde el FORMULARIO de certificados
if (!lxd.canGradeEnactus) StatusChip(label: 'Tu Admin no te ha dado permiso…')
```

Es **filtrado de interfaz**: se decide qué se muestra. `saveSubmission` e
`issueRutaCertificate` no verifican absolutamente nada.

**Los 4 modos de calificación** (`ActivityConfig.gradingMode`, aplicados en
`lxd_portal.dart:838-852`): `passfail` → `grade` 100 o 0 · `review` → `grade`
queda `null` · `points100` → 0-100 · *default* (`scale5`, el implícito de las
entregas sin actividad asociada) → 0-5. **Cuatro escalas distintas conviviendo
en el mismo campo `double? grade`** — el esquema tiene que guardar la escala
junto con el valor, o el número no significa nada por sí solo.

Efecto secundario documentado: al guardar una calificación,
`markLessonComplete` completa la lección de la actividad (`lxd_portal.dart:861`)
y se notifica al estudiante.

---

## A.8 Lógica que hoy está en el cliente y debe moverse al servidor

Ordenado por gravedad.

**1. Contraseñas en texto plano, y en el respaldo descargable.**
`AppUser.password` es un `String` sin hash. `findByCredentials` compara
`u.password == password` (`data_provider.dart:44-52`). El seed las trae
literales. Y `exportBackupJson()` vuelca la caja `users` **entera** — contraseñas
incluidas — a un archivo `.json` que el Admin descarga desde
`admin_backup.dart:112`. → bcrypt en `POST /auth/login`; `password_hash` **nunca**
sale de la BD, ni en el backup.

**2. La clave de respuestas de los quizzes viaja al navegador.**
`QuizQuestion.answerIndex` / `answerText` van dentro del `Course`, y
`_QuizDialogState._correct()` (`course_detail_view.dart:384-403`) califica en el
cliente: aprueba con ≥60% y llama a `onPassed()`. Cualquiera con las
herramientas de desarrollador ve las respuestas antes de contestar. → `POST
/lessons/:id/quiz-attempt` recibe las respuestas, califica en el servidor y
devuelve el puntaje; el `Course` que se sirve a un estudiante **no incluye
`answer_index`/`answer_text`**.

**3. La completitud entera es una función del cliente.** `toggleLesson`
(`data_provider.dart:194`) **alterna sin validar nada**: no comprueba que el
estudiante tenga acceso al curso, que la lección exista, ni que la haya abierto.
Y `isRutaComplete` / `completedLabsForStudent` — el requisito del certificado —
se recalculan en el navegador. → función/vista Postgres + `POST
/progress/lessons/:id/toggle` que devuelve el progreso recalculado.

**4. `can_grade` es solo un filtro de UI.** Ver A.7. → middleware
`requireCanGrade` en `POST /submissions/:id/grade` y en `POST /certificates/ruta`,
verificado contra la BD.

**5. `issueRutaCertificate` no verifica su propio requisito.** No comprueba que
la Ruta esté completa (lo hace la pantalla al armar el desplegable) ni quién
emite (`issuerName` es un **string libre**). → `POST /certificates/ruta` valida
las 3 fases en servidor y toma el emisor del JWT, no del body.

**6. `importBackupJson` reemplaza la base de datos completa.** `db.importAll`
hace `box.clear()` en las 18 cajas y las repuebla desde un archivo que el
usuario elige (`admin_backup.dart:146`); la única validación es que el JSON
tenga una clave `users`. → `POST /admin/restore`: solo superadmin,
transaccional, respaldo automático previo, y registro en `audit_log`.

**7. No existe aislamiento entre usuarios — solo convención de pantalla.**
`DataProvider.users`, `.submissions`, `.certificates` y `.progress` **no filtran
por nadie**. Las pantallas usan `studentsForAdvisor`, `studentsForDonor`,
`studentsForMentor`… por convención. Dos fugas concretas ya visibles:
- `_LxdCertificates` (`lxd_portal.dart:898`) puebla su desplegable con
  `data.studentsAndAlumni` — **todos los estudiantes de la plataforma**, no solo
  los suyos.
- `CourseDetailView(studentId:)` acepta el id de cualquier estudiante.
→ cada endpoint reimpone el filtro; ninguno confía en que el cliente pida lo
correcto.

**8. `_RoleGuard` protege rutas en el cliente.** `main.dart:166-183` compara
`auth.currentUser!.role != role` dentro de un widget. Es defensa de interfaz —
el propio código lo dice. → middleware de rol por ruta, según la matriz C.

**9. Archivos como base64 dentro de los registros.** `avatarBase64`,
`SiteContent.galleryImages` (lista de base64),
`CommunicationResource.fileBase64`. Con esto, `getAll('users')` — que se llama
en cada `build` de cada listado — arrastraría cada avatar completo. → S3 key +
`content_type` + `size_bytes`; el binario nunca en Postgres.

**10. Datos personales sin restricción.** `cedula`, `phone`, `email` y el
`impactCode` del donante viajan en cada `AppUser` a cualquier pantalla. →
serializadores por rol: el DTO de un estudiante visto por un Donante no lleva
cédula ni teléfono.

### Dos bugs latentes encontrados de paso (no son de seguridad, pero el backend los hereda si no se corrigen)

- **Aprobar un quiz dos veces lo des-completa.** `course_detail_view.dart:349`
  pasa `onPassed: onToggle`, y `onToggle` es `toggleLesson` (alterna). Si el
  estudiante vuelve a entrar a un quiz que ya aprobó y lo aprueba de nuevo, la
  lección pasa a **incompleta**. → en el backend, aprobar un quiz es
  `markLessonComplete`, nunca un toggle.
- **`deleteCourse` no tiene cascada y puede bloquear una Ruta entera.**
  Borra la fila y ya: las filas de `progress` quedan huérfanas, y los
  `RutaModule.courseIds` / `Objective.sourceCourseIds` quedan con un id
  colgante. Como `isObjectiveComplete` exige `c != null`, **un curso borrado
  deja el objetivo permanentemente incompleto**, y con él el módulo, la fase y
  la Ruta — para todos los estudiantes de ese laboratorio, en silencio.
  → **Pregunta B.7.**

---

# B. Preguntas de requerimientos

Estas siete definen el modelo de datos y no las puedo asumir. Cada una trae mi
recomendación y el porqué, basados en lo que el código ya hace hoy.

---

### B.1 — Si un LXD agrega un curso nuevo a un módulo que un estudiante ya tenía completo, ¿el módulo vuelve a incompleto? ¿Y si ya se emitió el certificado, se revoca?

**Qué pasa hoy:** el módulo **vuelve a incompleto de inmediato y en silencio**,
porque `isModuleComplete` se recalcula en cada render (`∀courseId: progreso ≥ 1`).
Y en cascada: la fase y la Ruta también. **El certificado, en cambio, no se
toca**: es una fila guardada que nadie vuelve a verificar. O sea, hoy ya conviven
un estudiante "con Ruta incompleta" y su certificado emitido.

**Mi recomendación:**
- **Sí, el módulo vuelve a incompleto.** Es la consecuencia correcta de que la
  completitud sea derivada, y no quiero desnormalizarla para evitar esto: un
  `is_complete` guardado en tabla se desincroniza a la primera.
- **No, el certificado no se revoca. Nunca.** Un certificado dice "esta persona
  completó esto **a fecha del** 12 de agosto", no "esta persona cumple los
  requisitos vigentes hoy". Revocar una credencial que alguien ya puso en su
  hoja de vida por un cambio de contenido posterior es peor que el problema que
  resuelve.
- **En su lugar: congelarlo.** `certificates.requirements_snapshot` (JSONB) con
  los ids de cursos/módulos que se exigían al emitirlo, y
  `laboratories.content_version` que sube con cada cambio estructural. Así el
  certificado es auditable, se sabe contra qué versión se emitió, y se puede
  mostrar "emitido sobre la versión 3 del laboratorio" sin invalidarlo.
- **Y avisar.** Notificación al estudiante ("se agregó contenido nuevo a tu
  Ruta") y al LXD ("N estudiantes que ya habían completado este módulo vuelven
  a tener trabajo pendiente") **antes** de guardar el cambio, no después.

**Lo que necesito que confirmes:** si te sirve "el certificado nunca se revoca,
se congela con su snapshot", o si prefieres que exista un estado
`superseded`/revocado explícito.

---

### B.2 — Si a un usuario le quitan `can_grade`, ¿las calificaciones que ya puso siguen válidas?

**Qué pasa hoy:** siguen ahí sin ninguna marca. El permiso solo filtra qué
entregas ve el LXD de aquí en adelante; las notas ya escritas no se distinguen
en nada.

**Mi recomendación: sí, siguen válidas, y sin marca especial.**
`can_grade` es autorización **para ejecutar la acción en el momento en que se
ejecuta**, no un atributo de la calificación. El paralelo: que a un profesor le
quiten un curso el semestre siguiente no borra las notas del semestre pasado.

Lo que sí hago para que quede auditable, sin invalidar nada:
- `submissions.graded_by` (FK) + `graded_at` — quién y cuándo, siempre.
- El cambio de `can_grade` queda en `audit_log` con valor anterior y nuevo
  (ya está pedido en el prompt), así que siempre se puede reconstruir "esta
  persona sí tenía permiso el día que puso esa nota".

Invalidar retroactivamente tendría un efecto muy feo: quitarle el permiso a
alguien borraría el historial académico de sus estudiantes de un plumazo.

**Lo que necesito que confirmes:** si hay algún caso en el que sí quieras
invalidar — por ejemplo, si se descubre que alguien calificó sin tener el
permiso. En ese caso propondría no borrar, sino marcar la calificación como
`disputed` y exigir que otro con permiso la confirme o la cambie.

---

### B.3 — ¿Un estudiante de Open Learning puede pasar a Enactus? ¿Qué pasa con su progreso previo?

**Qué pasa hoy:** `studentType` es un campo de `extra` que solo escribe el Admin
al crear o editar la cuenta. Cambiarlo es técnicamente posible y nada lo impide
ni lo acompaña. El acceso a cursos cambia por completo con ese campo
(`studentHasCourse`: Open Learning → solo `courseIds` asignados; Enactus →
automático por `labIds`).

**Mi recomendación: sí, es una promoción, no una cuenta nueva.**
- Mismo `user_id`, cambia `student_type` de `open_learning` a `enactus`.
- **Todo el progreso previo se conserva íntegro.** Las filas de `progress` son
  por `(student_id, course_id)` y no dependen de `student_type` para nada —
  técnicamente no hay que hacer nada para conservarlas, y sería un error
  borrarlas.
- Los certificados previos se conservan.
- Lo que gana: `lab_ids` y una Ruta de Impacto que arranca en cero (no hay
  `ruta_progress` anterior que trasladar, porque un OL nunca tuvo).
- **Detalle que me gusta de este diseño:** si uno de los cursos que ya completó
  como Open Learning está vinculado a un módulo de su nueva Ruta, cuenta como
  completo de inmediato, sin hacer nada. Es el comportamiento correcto y sale
  gratis.
- **El sentido inverso (Enactus → Open Learning) lo dejaría bloqueado** salvo
  para superadmin, porque degrada accesos y deja `ruta_progress` colgando.

**Lo que necesito que confirmes:** si el cambio lo hace el Admin a mano (lo que
propongo, con registro en `audit_log`), o si tiene que existir alguna forma de
que el estudiante lo solicite.

---

### B.4 — Cuando un estudiante pasa a alumni, ¿conserva acceso a cursos y certificados?

**Qué pasa hoy:** `Roles.isStudentLike(role)` hace que `alumni` sea **idéntico**
a `student` en todo el código: mismo portal, mismas consultas, mismas pestañas.
Solo cambia la etiqueta visible. El seed lo confirma: `alum1` está en `grp1`
con los mismos laboratorios, cursos y progreso que `est1`.

**Mi recomendación: conserva todo el acceso de lectura, y pierde el de escritura.**
- **Conserva:** sus certificados (obvio, son suyos), sus cursos completados y su
  progreso histórico, su proyecto y equipo, el foro, y la visibilidad en
  BuscaTalento — que es justamente donde un alumni tiene más valor para una
  empresa.
- **Pierde:** completar lecciones nuevas, hacer entregas, avanzar la Ruta de
  Impacto, recibir calificaciones. Un egresado no sigue cursando.

**Ojo, esto sí es un cambio respecto de hoy**, donde un alumni puede hacer todo
lo que hace un estudiante. Por eso lo pregunto en vez de asumirlo: si el alumni
efectivamente sigue formándose en la plataforma (que es una decisión de producto
razonable), entonces lo correcto es dejarlo tal cual está y `alumni` es
puramente una etiqueta.

**Lo que necesito que confirmes:** ¿el alumni sigue estudiando, o su cuenta pasa
a ser un archivo consultable?

---

### B.5 — Las notas de mentor sobre un estudiante, ¿quién las ve? ¿El estudiante mismo?

**Qué pasa hoy:** la caja se llama `mentor_notes`, pero **quien las escribe es
el LXD**, no el Mentor: el único punto de escritura es
`course_tracking_view.dart` (el seguimiento de curso del LXD). El nombre está
mal desde el rename Mentor→LXD. Están indexadas por `(studentId, courseId)` y
hoy no las lee ninguna pantalla del estudiante — pero nada lo impide, es solo
que ninguna las muestra.

**Mi recomendación: privadas para el equipo docente, no visibles para el
estudiante.**
- **Ven:** el LXD creador del curso, los mentores del laboratorio de ese curso,
  y Admin/Super Admin.
- **No ve:** el estudiante, ni el Asesor, ni la Empresa, ni el Donante.
- **Razón:** son observaciones francas de seguimiento ("se está desconectando",
  "necesita apoyo en finanzas"). Si el estudiante las ve, dejan de escribirse
  con franqueza y el campo pierde su función. Para lo que sí debe llegarle al
  estudiante ya existe un canal propio: `Submission.feedback`, que es
  retroalimentación explícita y visible.
- Y renombraría la tabla a `staff_notes`, para que el nombre diga la verdad.

**Lo que necesito que confirmes** — y es la razón de fondo por la que pregunto:
en algunos contextos (universidades, protección de datos personales) el
estudiante tiene derecho a acceder a los registros que existan sobre él.
**No sé si eso aplica a Enactus Colombia y no es algo que pueda deducir del
código.** Si aplica, hay que decidirlo ahora, porque cambia lo que la gente
escribe ahí.

---

### B.6 — ¿Un usuario puede tener más de un rol simultáneamente?

**Qué pasa hoy:** no. `AppUser.role` es un `String` único, `AppRoutes.forRole`
mapea un rol a exactamente un portal, y `_RoleGuard` compara por igualdad. Los
solapamientos reales que ya existen **no se modelan como roles múltiples sino
como relaciones**, y funcionan bien:
- `lxd1` tiene `companyId: emp1` — es un LXD que pertenece a Bancolombia, no un
  usuario "lxd + company".
- Un mentor pertenece a un laboratorio vía `Laboratory.mentorIds`, no vía su
  propio rol.

**Mi recomendación: un solo rol por usuario en la v1.**
- La pregunta que rompe todo con multi-rol es *"¿actuando como cuál?"*. Habría
  que responderla en cada pantalla, en cada endpoint y en el propio JWT. Es un
  cambio de fondo en los 8 portales para un caso que **no ha aparecido**.
- El solapamiento que sí existe ya está bien resuelto con relaciones.
- Con la fecha del 1 de octubre encima, esto es exactamente lo que la sección
  "Prioridad ante falta de tiempo" manda cortar.

**Pero sí dejo la puerta abierta sin costo:** columna `role` como enum ahora, y
`users.id` como FK desde una futura `user_roles` — así, si más adelante hace
falta, se agrega la tabla y `role` pasa a ser "el rol primario / el portal por
defecto", sin migrar nada de lo escrito.

**Lo que necesito que confirmes:** ¿hay hoy alguna persona real que necesite dos
portales? El caso más plausible que se me ocurre es un Asesor que también sea
Mentor de un laboratorio. Si existe, cambia mi recomendación.

---

### B.7 — Al borrar un curso vinculado a módulos con progreso de estudiantes, ¿qué pasa?

**Qué pasa hoy — y esto es un bug latente, no solo una pregunta de diseño:**
`deleteCourse` hace un borrado duro sin ninguna cascada
(`data_provider.dart:164-167`). Consecuencias reales:
- Las filas de `progress` quedan huérfanas para siempre.
- `RutaModule.courseIds` y `Objective.sourceCourseIds` quedan con un id colgante.
- Y como `isObjectiveComplete` exige `c != null`, **el objetivo queda
  permanentemente incompleto**. En cascada: el módulo, la fase y la Ruta entera
  del laboratorio se bloquean **para todos sus estudiantes**, en silencio y sin
  forma de arreglarlo desde la interfaz (`unlinkCourseFromModules` existe pero
  no tiene ningún botón que la llame).

**Mi recomendación: tres niveles según lo que el curso tenga colgando.**

| Situación del curso | Qué hace el endpoint |
|---|---|
| Sin progreso de nadie, sin vínculos a módulos | Borrado lógico (`deleted_at`). Se permite. |
| Con vínculos a módulos **o** con progreso de al menos un estudiante | **`409 Conflict`**, con el detalle de qué lo bloquea: "3 módulos en 2 laboratorios, 14 estudiantes con progreso". La acción ofrecida es **archivar**, no borrar. |
| Archivar (`status = 'Archivado'`) | El curso deja de asignarse a estudiantes nuevos y desaparece de los catálogos, pero **sigue existiendo** para quienes ya tienen progreso, y sus vínculos a módulos siguen siendo válidos. Nadie se bloquea. |

Y un desvinculado explícito (`DELETE /labs/:id/modules/:mid/courses/:cid`,
que es `unlinkCourseFromModules` con un botón de verdad detrás), para que
sacar un curso de una Ruta sea una acción normal en vez de un efecto secundario
de borrarlo.

Borrado físico real: solo superadmin, solo sobre un curso ya archivado y sin
progreso, y con registro en `audit_log`.

**Lo que necesito que confirmes:** si te sirve que "borrar" en la interfaz del
LXD pase a significar **archivar**, y que el borrado de verdad quede reservado
al Super Admin.

---

# C. Matriz de permisos

Derivada del código: qué pantalla llama a qué método de escritura, y qué
consulta alimenta cada listado. **Las celdas marcadas ⚠️ no las puedo deducir**
— o el código no lo decide en ningún lado, o hace algo que parece un descuido y
necesito que lo confirmes.

Leyenda: ✅ permitido · **propio** = solo sus propios registros ·
**ámbito** = solo los de su universidad / empresa / laboratorio / grupo, según el
rol · ❌ negado · ⚠️ requiere tu decisión.

### Usuarios

| Rol | Crear | Leer | Actualizar | Borrar |
|---|---|---|---|---|
| superadmin | ✅ cualquier rol, incluido admin | ✅ todos | ✅ todos | ✅ todos menos superadmin |
| admin | ✅ todos menos admin/superadmin | ✅ todos | ⚠️ **ver nota 1** | ✅ todos menos admin/superadmin |
| advisor | ❌ | ✅ ámbito: su universidad | ❌ | ❌ |
| donor | ❌ | ✅ ámbito: los que apoya · ⚠️ **+ todos los Enactus vía BuscaTalento (nota 2)** | ❌ | ❌ |
| lxd | ❌ | ✅ ámbito: estudiantes de sus cursos · ⚠️ **+ todos, vía el desplegable de certificados (nota 3)** | propio (perfil) | ❌ |
| mentor | ❌ | ✅ ámbito: estudiantes de sus laboratorios | propio (perfil) | ❌ |
| company | ⚠️ **✅ crea cuentas de LXD y Mentor (nota 4)** | ✅ ámbito: patrocinados, su equipo LXD/Mentor · + BuscaTalento | ⚠️ **✅ edita `reviewCourseIds` de sus mentores (nota 4)** | ❌ |
| student / alumni | ❌ | propio + miembros de su grupo/proyecto | propio (perfil) | ❌ |

**Nota 1 —** `_canDelete` (`admin_portal.dart:563`) impide que un admin **borre**
a otro admin, pero **nada impide que lo edite** (cambiarle el correo, la
contraseña o el rol). ¿Es intencional, o el mismo criterio del borrado debe
aplicar a la edición?

**Nota 2 —** `talentSearchStudents()` devuelve **todos** los estudiantes Enactus
de la plataforma, con nombre, universidad, carrera y objetivos completados, a
cualquier Donante o Empresa. Entiendo que es la función de BuscaTalento y que es
deliberado — lo marco porque es la mayor exposición de datos personales del
sistema y quiero que quede confirmada, no asumida.

**Nota 3 —** `_LxdCertificates` (`lxd_portal.dart:898`) puebla su desplegable con
`data.studentsAndAlumni` — todos, no solo los de sus cursos. Esto sí me parece
un descuido: propongo limitarlo a `studentsForCreator(lxd.id)`.

**Nota 4 —** El portal de Empresa **crea usuarios LXD y Mentor**
(`company_portal.dart:794` y `:1012`), **los agrega a `Laboratory.mentorIds`**
(`:1015`) y **les asigna `reviewCourseIds`** (`:1086`). Es bastante poder de
escritura para un rol que por lo demás es de solo lectura. ¿Se mantiene, o la
Empresa solicita y el Admin aprueba?

### `can_grade`

| Rol | Modificar el permiso de otro |
|---|---|
| superadmin, admin | ✅ (coincide con el prompt) |
| todos los demás | ❌ |

Pendiente de tu decisión: **hoy son dos permisos** (`canGradeOpenLearning`,
default `true`; `canGradeEnactus`, default `false`), no uno. El prompt pide un
solo `can_grade BOOLEAN`. **Recomiendo conservar los dos** — la distinción es
real y ya está en uso: en Open Learning el LXD es el docente y califica por
defecto; en Enactus la calificación es un acto institucional que el Admin
habilita caso por caso. Colapsarlos a uno pierde esa distinción y obliga a
elegir un default malo para uno de los dos contextos.

### Proyectos y Grupos

| Rol | Proyectos C/R/U/D | Grupos C/R/U/D |
|---|---|---|
| superadmin, admin | ✅ / ✅ / ✅ / ✅ | ✅ / ✅ / ✅ / ✅ |
| advisor | ⚠️ / ✅ ámbito / ✅ **sí edita** / ❌ | ❌ / ✅ ámbito / ❌ / ❌ |
| lxd, mentor, company, donor | ❌ / ✅ (directorio público) / ❌ / ❌ | ❌ / ✅ ámbito / ❌ / ❌ |
| student, alumni | ❌ / ✅ el suyo + directorio / ❌ / ❌ | ❌ / ✅ el suyo / ❌ / ❌ |

⚠️ El Asesor **edita** proyectos (`advisor_portal.dart` llama a `saveProject`)
pero no hay ningún botón de "nuevo proyecto" en su portal. ¿Debe poder crearlos,
o solo editar los de su universidad?

### Laboratorios y Ruta de Impacto (fases, objetivos, módulos)

| Rol | Crear | Leer | Actualizar | Borrar |
|---|---|---|---|---|
| superadmin, admin | ✅ | ✅ todos | ✅ (incluido el editor de Ruta) | ✅ |
| lxd | ❌ | ✅ los de sus cursos | ✅ **solo vincular/desvincular sus cursos a un módulo** | ❌ |
| mentor | ❌ | ✅ ámbito: los suyos | ❌ | ❌ |
| company | ❌ | ✅ ámbito: los suyos | ⚠️ **✅ agrega mentores (nota 4)** | ❌ |
| student / alumni | ❌ | ✅ los que tiene asignados | ❌ | ❌ |
| advisor | ❌ | ✅ los de sus estudiantes | ❌ | ❌ |
| donor | ❌ | ❌ (su portal no tiene laboratorios) | ❌ | ❌ |

### Cursos, módulos y lecciones

| Rol | Crear | Leer | Actualizar | Borrar |
|---|---|---|---|---|
| superadmin, admin | ✅ | ✅ todos | ✅ todos | ✅ todos |
| lxd | ✅ | ✅ los suyos + los de sus laboratorios | ✅ **solo los que él creó** (`creatorId`) | ✅ los suyos → ver B.7 |
| mentor | ❌ | ✅ los que revisa | ❌ | ❌ |
| student / alumni | ❌ | ✅ solo los que `studentHasCourse` le permite, y **sin las respuestas del quiz** | ❌ | ❌ |
| company | ❌ | ✅ ámbito: los de sus LXD | ❌ | ❌ |
| advisor, donor | ❌ | ⚠️ **no deducible** — ninguna pantalla suya lista cursos hoy | ❌ | ❌ |

### Progreso y Ruta de Impacto del estudiante

| Rol | Crear/Actualizar | Leer |
|---|---|---|
| student / alumni | ✅ **solo el propio** | propio |
| lxd, mentor | ⚠️ **ver nota 5** | ✅ ámbito |
| advisor, company, donor | ❌ | ✅ ámbito (agregado) |
| superadmin, admin | ⚠️ nota 5 | ✅ todos |

**Nota 5 —** Hoy `markLessonComplete` la dispara el LXD **indirectamente**, al
calificar una actividad (`lxd_portal.dart:861`). ¿Debe existir además una forma
**directa** de que un LXD o un Admin marque una lección como completa para un
estudiante (por ejemplo, para corregir un error)? Hoy no existe. Si la quieres,
va con `audit_log`.

### Entregas y calificaciones — **dos operaciones distintas**

| Rol | Crear entrega | Leer | Poner nota | Comentar | Borrar |
|---|---|---|---|---|---|
| student | ✅ propia | propia | ❌ | ❌ | ⚠️ **no deducible** — hoy `deleteSubmission` no la llama nadie |
| alumni | ⚠️ **depende de B.4** | propia | ❌ | ❌ | ⚠️ |
| lxd | ❌ | ✅ entregas de sus cursos | ✅ **solo con `can_grade` del contexto** | ✅ | ❌ |
| mentor | ❌ | ✅ de los cursos que revisa | ❌ **explícitamente no** | ✅ | ❌ |
| superadmin, admin | ❌ | ✅ todas | ⚠️ **no deducible** — hoy no tienen pantalla de calificación. ¿Debe el Admin poder corregir una nota? | ⚠️ | ⚠️ |
| advisor | ❌ | ✅ ámbito (solo lectura de avance) | ❌ | ❌ | ❌ |
| company, donor | ❌ | ❌ | ❌ | ❌ | ❌ |

### Certificados

| Rol | Emitir | Leer | Revocar |
|---|---|---|---|
| lxd | ✅ **solo con `canGradeEnactus`** + Ruta completa validada en servidor | los que emitió | ❌ |
| superadmin, admin | ⚠️ **no deducible** — hoy no tienen la pantalla. ¿Deben poder emitir? | ✅ todos | ⚠️ ver B.1 |
| student / alumni | ❌ | propios | ❌ |
| mentor, advisor | ❌ | ✅ ámbito | ❌ |
| company, donor | ❌ | ✅ ámbito (solo el conteo, en sus métricas) | ❌ |

### Evidencias de donante

| Rol | C | R | U | D |
|---|---|---|---|---|
| superadmin, admin | ✅ | ✅ todas | ✅ | ✅ |
| donor | ❌ | ✅ **solo las suyas** (`donorId`) | ❌ | ❌ |
| todos los demás | ❌ | ❌ | ❌ | ❌ |

Con `project_id` (el campo que falta), la lectura del Donante pasa a ser
"las suyas, con el proyecto asociado". ⚠️ ¿Deben ver las evidencias también la
Empresa o el Asesor del proyecto? Hoy no.

### Recursos de Comunicaciones

| Rol | C | R | U | D |
|---|---|---|---|---|
| superadmin, admin | ✅ | ✅ | ✅ | ✅ |
| advisor, mentor, lxd | ❌ | ✅ (vista de solo lectura, mismo dato) | ❌ | ❌ |
| student, alumni, company, donor | ❌ | ❌ | ❌ | ❌ |

### Calendario

| Rol | Crear | Leer | Actualizar | Borrar |
|---|---|---|---|---|
| superadmin, admin | ✅ cualquier tipo | ✅ todos | ✅ | ✅ |
| lxd | ✅ solo `openLearningSync` de sus cursos | los de sus cursos | ✅ propios | ✅ propios |
| mentor | ✅ solo `rutaImpacto`/`mentoria` de sus labs | los suyos + todos los `rutaImpacto` | ✅ propios | ✅ propios |
| advisor | ❌ | ámbito + todos los `rutaImpacto` | ❌ | ❌ |
| student / alumni | ❌ | `rutaImpacto` si es Enactus · `mentoria` de sus labs · `openLearningSync` de sus cursos | ❌ | ❌ |
| company, donor | ❌ | ❌ (sin pestaña de calendario) | ❌ | ❌ |

### Foro

| Rol | Publicar | Leer | Responder / apoyar | Fijar | Borrar |
|---|---|---|---|---|---|
| superadmin, admin | ✅ | ✅ | ✅ | ✅ | ✅ cualquiera |
| advisor | ✅ | ✅ | ✅ | ❌ | ⚠️ **¿solo lo propio?** no deducible |
| student / alumni **Enactus** | ✅ | ✅ | ✅ | ❌ | ⚠️ **¿solo lo propio?** |
| student **Open Learning** | ❌ | ❌ | ❌ | ❌ | ❌ |
| lxd, mentor, company, donor | ❌ | ❌ | ❌ | ❌ | ❌ |

Regla exacta de acceso: `canAccessForum` (`data_provider.dart:722`).
⚠️ Hoy `deleteForumPost` no distingue autor de moderador. Propongo: el autor
borra lo suyo, Admin/Super Admin borran cualquiera.

### Contenido del sitio, respaldos y almacenamiento

| Rol | Site content | Backup / restore | Métrica de almacenamiento de video |
|---|---|---|---|
| superadmin | ✅ C/R/U | ✅ ambos | ✅ |
| admin | ✅ C/R/U | ⚠️ **hoy sí puede restaurar** — propongo que `restore` quede solo para superadmin | ✅ |
| público (sin sesión) | ✅ solo lectura (el landing) | ❌ | ❌ |
| todos los demás | ❌ | ❌ | ❌ |

### Notas del equipo docente (`mentor_notes` → `staff_notes`)

Depende enteramente de **B.5**. Mi propuesta: escriben LXD creador del curso,
mentores del laboratorio y Admin/Super Admin; leen los mismos; el estudiante
**no**; nadie más.

---

# Resumen de lo que necesito de ti para arrancar la Fase 1

**Las 7 preguntas de la sección B**, que son las que definen el esquema.

**Y 8 confirmaciones puntuales de la matriz C**, que son más rápidas:

1. ¿Un admin puede **editar** a otro admin (hoy no puede borrarlo, pero sí editarlo)?
2. ¿BuscaTalento mostrando **todos** los estudiantes Enactus a cualquier Donante/Empresa es deliberado?
3. ¿La **Empresa** sigue creando cuentas de LXD/Mentor y modificando laboratorios, o pasa a solicitar y el Admin aprueba?
4. ¿El **Asesor** puede crear proyectos, o solo editar los de su universidad?
5. ¿El **Admin** debe poder calificar y emitir certificados? Hoy no tiene ninguna pantalla para eso.
6. ¿Debe existir una forma **directa** de que un LXD/Admin marque una lección como completa para un estudiante (hoy solo pasa como efecto de calificar)?
7. ¿Un estudiante puede **borrar** su propia entrega? Hoy `deleteSubmission` no la llama nadie.
8. ¿Conservamos los **dos** permisos de calificación (`canGradeOpenLearning` / `canGradeEnactus`) o los colapsamos al `can_grade` único que pide el prompt? **Recomiendo conservar los dos.**

No escribo una sola línea de código hasta tener esto.
