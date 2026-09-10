# F0 · Auditoría del sistema de asignaciones

**Hecha el 9 de septiembre de 2026 sobre la rama `develop`.** Cada afirmación
lleva `archivo:línea` y se verificó ejecutando, no leyendo el documento de
requisitos.

---

## Lo primero, porque cambia el plan entero

**El proyecto ya no usa Hive.** El documento de requisitos describe una
arquitectura que dejó de existir:

| El documento dice | La realidad |
|---|---|
| `lib/services/db_service.dart` | **no existe** |
| `lib/services/migration_service.dart` | **no existe** |
| `lib/services/seed_service.dart` | **no existe** |
| «una caja Hive por entidad» | **no hay Hive**: ni en `pubspec.yaml` ni en `lib/` |
| «los datos viven en el navegador de cada usuario» | viven en **PostgreSQL 17 en RDS**, una sola copia compartida |
| «`toJson`/`fromJson` es el contrato para migrar luego a PostgreSQL» | **la migración ya ocurrió** |

Lo que hay hoy en `lib/services/`: `api_service.dart`, `api_errors.dart`,
`token_store.dart`, `pdf_service.dart`, `contact_service.dart` y los cuatro
adaptadores de subida/vídeo. Flutter es un **cliente HTTP**; el dominio vive en
`backend/src/`.

### Qué implica, en concreto

1. **La migración de datos NO es un `MigrationService` en Dart.** Es una
   migración de Drizzle en `backend/drizzle/`, aplicada por
   `enactus-db-tareas`. Eso es una mejora, no un obstáculo: se ejecuta **una
   vez sobre una base compartida** en lugar de en cada navegador, es
   transaccional, y tiene reverso en `backend/drizzle/down/`.
2. **`DbService.importAll` no existe.** El respaldo/restauración es
   `GET /admin/backup` y `POST /admin/restore` (ver «Respaldo y restauración»
   en `RUNBOOK.md`). El punto del requisito —que restaurar un respaldo viejo
   reintroduce el formato antiguo— **sigue siendo válido** y hay que
   resolverlo, pero en el endpoint de restauración, no en Hive.
3. **`InMemoryDbService extends DbService` no se puede escribir**: no hay
   `DbService`. Las pruebas de dominio ya corren contra **PostgreSQL de
   verdad** (`backend/tests/helpers/db.ts`, 579 pruebas). Ahí es donde van las
   pruebas de invariantes, no en `test/` de Flutter.
4. **El seed es `backend/src/db/seed.ts`** (demo) y `seed-prod.ts` (real).

**Esto no invalida el trabajo pedido: invalida dónde se hace.** El modelo está
igual de mal; solo que el sitio a arreglar es el esquema SQL y las rutas, con
el cliente Flutter siguiendo detrás.

---

## Los 9 defectos, verificados uno por uno

| | Defecto | Estado | Dónde |
|---|---|---|---|
| D1 | La universidad no existe como entidad | **CONFIRMADO** | no hay tabla `universities`; es `text()` libre |
| D2 | Visibilidad del asesor por comparación de cadenas | **CONFIRMADO**, pero mudado al backend | `backend/src/routes/users.ts:84` |
| D3 | Dos fuentes de verdad para el asesor | **CONFIRMADO** | `users.university` + `groups.advisorId` |
| D4 | `Group` exige proyecto | **CONFIRMADO** | `backend/src/db/schema/orgs.ts:59-61` |
| D5 | `Group` y `Project` duplicados | **CONFIRMADO** | `orgs.ts:15-36` vs `orgs.ts:55-73` |
| D6 | Doble escritura sin transacción | **YA RESUELTO** | `orgs.ts:85` `group_members` |
| D7 | Todo vive en `extra` sin validación | **YA RESUELTO** | `users.ts:19-28`: `extra` se aplanó en columnas |
| D8 | Permisos dispersos | **PARCIAL** | backend sí tiene; Flutter conserva 19 `isSuperAdmin` |
| D9 | Borrados sin cascada | **MAYORMENTE RESUELTO** | 85 reglas `onDelete` en el esquema |

### D1 — confirmado

No existe tabla `universities`. La universidad es texto libre en dos sitios:

```
backend/src/db/schema/users.ts:48   university: text().notNull().default('')
backend/src/db/schema/orgs.ts:63    university: text().notNull().default('')
```

Hay incluso un índice sobre ella —`users_university_idx`, `users.ts:99`— lo que
significa que la comparación por cadena no solo existe: está **optimizada**,
que es peor. Nadie va a sospechar de una consulta rápida.

### D2 — confirmado, y ya no está donde dice el documento

`studentsForAdvisor` **no existe** en `lib/providers/data_provider.dart`, y
`grep -rn "== advisor.university\|s.university ==" lib/` no devuelve nada. La
regla se mudó al servidor cuando se migró el dominio:

```ts
// backend/src/routes/users.ts:84
if (!user.university) return SIN_UNIVERSIDAD;
return and(alive, eq(users.university, user.university))!;
```

Es exactamente el defecto descrito —un espacio, una tilde o «U. de los Andes»
y el asesor deja de ver a sus estudiantes, sin error visible— solo que ahora
falla para **todos los clientes a la vez**, no solo para quien tenga ese Hive.

El criterio de aceptación de F3 hay que reescribirlo: el `grep` propuesto sobre
`lib/` ya pasa hoy, y pasaría aunque no hiciéramos nada.

### D4 y D5 — confirmados, y son el mismo defecto visto de dos lados

```ts
// backend/src/db/schema/orgs.ts:59
projectId: uuid().notNull().references(() => projects.id, { onDelete: 'restrict' })
```

`notNull` + `restrict`: un equipo **no puede existir sin proyecto**, y un
proyecto con equipo **no se puede borrar**. Mientras tanto `projects`
(`orgs.ts:15-36`) tiene `name`, `description`, `problem`, `solution`,
`community`, `impactIndicators` — y **ni universidad ni integrantes**.

La universidad y el equipo están del lado equivocado, tal cual dice el
documento.

### D6 — ya resuelto, y el comentario del código lo explica

```ts
/**
 * Integrantes de un equipo. Reemplaza a la vez `Group.studentIds` y
 * `AppUser.groupId`, que hoy son la misma relación guardada dos veces y en
 * direcciones opuestas (se pueden desincronizar).
 */
export const groupMembers = pgTable('group_members', …)   // orgs.ts:85
```

La doble escritura se eliminó al migrar. Existen ya las cinco tablas de enlace
que el documento pide como patrón: `student_laboratories`, `student_courses`,
`mentor_review_courses` (`links.ts:66,87,109`), `laboratory_mentors`
(`labs.ts:53`) y `group_members` (`orgs.ts:85`).

**Falta una**: no hay `laboratory_lxds`. La capacidad «el LXD edita solo los
laboratorios donde el Admin lo asignó» **no tiene dónde guardarse**.

### D7 — ya resuelto

`extra` no existe como columna. El comentario de `users.ts:19-28` lo dice:
«Usuarios. Reemplaza `AppUser` + su bolsa `extra`». En `lib/` las únicas
menciones a `extra[...]` son **comentarios históricos** que explican de dónde
venían los datos (`student_portal.dart:245`, `ruta_impacto_view.dart:1356`), no
accesos.

Tampoco queda el legado `extra['labId']` singular.

### D8 — parcial

El backend sí tiene un módulo de permisos: `requireAuth`, `requireRole`,
`requireCanGrade`, `requireEnactus`, `assertSelfOr` en
`backend/src/middleware/auth.ts`, con 79 aplicaciones sobre rutas.

Flutter **no**: quedan **19 `isSuperAdmin`** en 3 archivos —
`lib/main.dart:157`, `lib/views/admin/admin_users.dart` (13) y
`lib/views/admin/admin_portal.dart` (5). No existe `lib/utils/permissions.dart`.

Y la brecha de negocio es real: `lib/views/admin/lab_ruta_editor.dart` (1 225
líneas) vive bajo `views/admin/`, y `lib/views/lxd/lxd_portal.dart` no tiene
pestaña para editar laboratorios.

### D9 — mayormente resuelto

85 reglas `onDelete` declaradas en el esquema. Lo que falta no son las
cascadas: es **el reporte** —no hay `integrityReport()` ni equivalente— y las
reglas de negocio que el documento pide y la base no puede expresar sola
(«bloqueado si tiene estudiantes o cursos», «se ofrece desactivar en su lugar»).

---

## Discrepancias con el documento, para decidir antes de F1

1. **Fases F1–F7 replanteadas.** Tal como están, F1 («caja `universities`»),
   F2 (`MigrationService`) y el criterio de F3 (`grep` sobre `lib/`) no se
   pueden ejecutar. La forma equivalente:

   | Fase | En vez de | Hacer |
   |---|---|---|
   | F1 | modelo Dart + caja Hive | tabla `universities` + `laboratory_lxds` en Drizzle, y los modelos Dart detrás |
   | F2 | `MigrationService.runAll()` | migración Drizzle + reparación en `POST /admin/restore` |
   | F3 | `grep` sobre `lib/` | quitar `eq(users.university, …)` de `backend/src/routes/` |
   | F4 | `permissions.dart` solo | `permissions.dart` en Flutter **y** capacidades en el backend |
   | F7 | `InMemoryDbService` | pruebas en `backend/tests/` contra PostgreSQL real |

2. **`Group` tiene `restrict` sobre `projects`.** Absorberlo en `Project` (F5)
   exige orden: primero mover universidad e integrantes, después soltar la FK.
   No es un `ALTER` suelto.

3. **`University.advisorIds` como lista dentro de la entidad** no encaja con el
   esquema relacional. El equivalente es una tabla `university_advisors`, que
   además da el 1..N en las dos direcciones que pide INV-4 sin ninguna gimnasia.

4. **Falta `laboratory_lxds`**, sin la cual la matriz de permisos (§4, fila
   «Editar definición de laboratorio → LXD solo donde esté en `lxdIds`») no se
   puede implementar.

5. **`AssignmentResult` con mensajes en español** ya tiene precedente: la API
   responde `{error:{code,message}}` con el mensaje listo para mostrar
   (`backend/src/middleware/error.ts`). Conviene reusar ese contrato en lugar
   de inventar uno paralelo en el cliente.

6. **Ya existe `PUT /users/:id/laboratories` y `PUT /users/:id/courses`**
   (`backend/src/routes/assignments.ts`). `assignStudentPlacement` debería
   extender eso, no reemplazarlo.

---

## Inventario de puntos de llamada

Lo que toca universidad, asesor, grupo, proyecto o laboratorio y habrá que
revisar en F3–F6.

### Backend — universidad como cadena

| Archivo:línea | Qué hace |
|---|---|
| `routes/users.ts:84` | **el alcance del asesor**, por igualdad de cadena |
| `routes/orgs.ts:152` | proyecta `u.university` en integrantes de equipo |
| `routes/orgs.ts:170` | `g.university` en el listado de equipos |
| `routes/talent.ts:72,129` | búsqueda de talento por universidad |
| `routes/course-tracking.ts:102,150` | seguimiento de curso |
| `lib/dto.ts:23,50` | expone `university` en `publicUser` y `limitedUser` |

### Backend — esquema

| Archivo:línea | Qué |
|---|---|
| `schema/users.ts:48,99` | columna `university` + su índice |
| `schema/orgs.ts:63` | `groups.university` |
| `schema/orgs.ts:59-61` | `groups.projectId` notNull + restrict (D4) |
| `schema/orgs.ts:64` | `groups.advisorId` (D3) |
| `schema/orgs.ts:85` | `group_members` |
| `schema/labs.ts:53` | `laboratory_mentors` |
| `schema/links.ts:66,87,109` | enlaces de estudiante y mentor |

### Flutter

| Archivo:línea | Qué |
|---|---|
| `views/admin/admin_users.dart` (13 usos) | `isSuperAdmin` a mano |
| `views/admin/admin_portal.dart` (5 usos) | ídem |
| `main.dart:157` | ídem |
| `views/admin/lab_ruta_editor.dart` | editor de Ruta, solo Admin (1 225 líneas) |
| `views/lxd/lxd_portal.dart` | sin pestaña de laboratorios |
| `views/advisor/advisor_portal.dart` | consume el alcance del servidor |
| `providers/data_provider.dart` | 1 910 líneas; sin comparaciones por nombre |

---

## Lo que propongo, y en qué orden

Manteniendo el espíritu del documento —invariantes imposibles de violar, una
sola fuente de verdad por relación, permisos centralizados— pero ejecutándolo
donde vive el dominio hoy:

- **F1** · Migración Drizzle: `universities`, `university_advisors`,
  `laboratory_lxds`; `users.university_id`, `projects.university_id`,
  `project_members`. Sin quitar todavía las columnas viejas.
- **F2** · Migración de datos: normalizar y fusionar variantes, poblar,
  conservar el texto original en una columna `legacy_university_name`. Reporte
  de integridad como endpoint.
- **F3** · Consultas por id. Se quita `eq(users.university, …)`.
- **F4** · Capacidades: `permissions.dart` en Flutter y capacidades en el
  backend; se abre el editor de Ruta a LXD y Admin.
- **F5** · `Group` → `Project`, con checkpoint previo.
- **F6** · UI en cascada, pantalla Asignaciones, portal Asesor.
- **F7** · Cascadas de negocio, seed y pruebas de invariantes.

**Checkpoint: no escribo código hasta que confirme estos seis puntos**, y
sobre todo el primero: que el trabajo va al backend y Flutter va detrás.
