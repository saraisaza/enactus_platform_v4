# Auditoría de navegación y funcionalidad — Enactus Platform (Frontend)

**Fecha:** 2026-08-28 · **Fase:** 1 en curso (aprobada por el usuario) · **Alcance:** 8 portales, `lib/` completo (~25.000 líneas)

## Estado de ejecución (Fase 1)

| Portal | Estado | Commit |
|---|---|---|
| **Estudiante** | ✅ Ciclo cerrado en verde — ver detalle abajo | `f8e3dce` |
| **LXD** | ✅ Ciclo cerrado en verde — ver detalle abajo | `431c67a` |
| **Admin** | ✅ Ciclo cerrado en verde — ver detalle abajo | `34f600b` |
| **Mentor** | ✅ Ciclo cerrado en verde — ver detalle abajo | `f1edbeb` |
| **Asesor Académico** | ✅ Ciclo cerrado en verde — ver detalle abajo | `04e27c2` |
| **Empresa** | ✅ Ciclo cerrado en verde — ver detalle abajo | `57f4cb4` |
| **Donante** | ✅ Ciclo cerrado en verde — ver detalle abajo | (pendiente de commit en este mismo cambio) |
| Público / Auth | No empezado | — |

### Portal Estudiante — completado

Cambios de infraestructura compartida (usados por Estudiante ahora; el resto de portales los heredan automáticamente al llegar su turno):

- **`lib/widgets/common.dart`**: `HoverCard` reescrito sobre un nuevo `KeyboardHoverBuilder` — antes usaba `GestureDetector` suelto (sin foco de teclado, ver hallazgo 1.1); ahora envuelve en `FocusableActionDetector` con `shortcuts: {Enter, Espacio} → ActivateIntent` + `Semantics(button: true)`. **Nota de verificación real**: la primera versión solo tenía `actions:` sin `shortcuts:` — compilaba y el foco SE VEÍA (confirmado con capturas paso a paso), pero Enter no activaba nada. Se detectó probando de verdad (Tab×5 + Enter, revisando la URL resultante) y se corrigió agregando `shortcuts: <ShortcutActivator, Intent>{SingleActivator(LogicalKeyboardKey.enter): ActivateIntent(), ...}` — sin ese paso habría quedado reportado como "listo" sin estarlo.
- **`lib/views/student/course_detail_view.dart`**: corregido el bug 1.2 (`CourseDetailView` mostraba el progreso de quien tiene sesión abierta, no el del estudiante que se quería ver). Ahora acepta `studentId` opcional; si viene y no es el usuario actual, entra en modo de solo lectura (banner visible, botón de completar lección deshabilitado, quiz/encuesta/actividad bloqueados con aviso en vez de abrir el diálogo).
- **`lib/utils/constants.dart` + `lib/main.dart`**: 2 rutas nuevas con nombre — `/usuarios/:id` → `UserDetailView` (nuevo, `lib/views/shared/user_detail_view.dart`) y `/laboratorios/:id` → `LabDetailView` (nuevo, `lib/views/shared/lab_detail_view.dart`). Cierran el hallazgo 1.5.
- **`UserDetailView`**: delega a `StudentDetailView` para roles tipo-estudiante; arma un resumen propio (cursos creados, laboratorios asignados, estudiantes a cargo, etc.) para LXD/Mentor/Asesor/Empresa/Donante usando los métodos que ya existían en `DataProvider`.
- **`LabDetailView`**: si quien mira es un estudiante con ese laboratorio asignado, muestra su propio avance por fase (igual que `LabDetailBody`); si no, muestra el avance agregado del grupo (`X/Y estudiantes completaron cada fase`) — cumple "progreso del estudiante o del grupo según el rol".
- **`lib/views/student/ruta_impacto_view.dart`**: `_OtherLabCard` ahora navega a `/laboratorios/:id` (antes MUERTA); `_LabLxdCard` ("Tu LXD") ahora navega a `/usuarios/:id` (antes MUERTA); ambas migradas a `KeyboardHoverBuilder`.
- **`lib/views/shared/projects_directory_view.dart`**: `_MemberRow` (fila de integrante en `/proyectos/:id`) ahora navega a `/usuarios/:id` al hacer clic en el nombre/avatar (antes solo navegaba el chip de laboratorio).
- **`lib/views/shared/student_detail_view.dart`**: el push a `CourseDetailView` ahora pasa `studentId` (fix del bug 1.2 en su único punto de reproducción confirmado).
- Cards con `MouseRegion`+`GestureDetector` suelto (sin `HoverCard`) migradas a `KeyboardHoverBuilder` en `student_dashboard_view.dart` (`_CourseProgressCard`, `_PendingCard`, `_RecentActivityCard`, `_ProjectCard`), `student_portal.dart` (`_ProjectCard` de Mi Perfil) y `student_courses_view.dart` (`_CourseCard`).

**Verificación ejecutada (no solo "debería funcionar"):**
- `flutter analyze`: 19 issues, mismo baseline preexistente, 0 nuevos (verificado 3 veces durante el ciclo, incluida una vez que sí encontró un error real de paréntesis que se corrigió antes de seguir).
- `flutter test`: 2/2 verde.
- `flutter build web --release`: compila sin errores.
- **Verificación funcional real vía Chrome headless + CDP** (login real con cuentas del seed, clics reales, navegación real):
  - `/laboratorios/:id` con datos reales (agregado: "0/1 completaron" por fase) y con id inexistente (`Este laboratorio ya no existe.`, sin crash) — en escritorio, tablet (700px) y móvil (375px), sin overflow.
  - `/usuarios/:id` con un LXD real (cursos creados, conteo de estudiantes) y con id inexistente (`Este usuario ya no existe o fue eliminado.`, sin crash).
  - Bug 1.2 reproducido ANTES del fix (progreso ajeno) y confirmado corregido DESPUÉS: login como Mentor → perfil de su estudiante Sara Nieto → clic en su curso → banner "Estás viendo el progreso de Sara Nieto — modo de solo lectura", barra en 33% (el real de ella, no 0%), intento de abrir el quiz bloqueado con aviso.
  - Accesibilidad de teclado confirmada de punta a punta: capturas paso a paso mostrando el anillo de foco moviéndose con Tab hasta una tarjeta real, y `Enter` navegando a `/cursos/crs_ia_1` (URL verificada, no solo visual).
  - `/proyectos/:id` → clic en un integrante del equipo → `/usuarios/:id` con su perfil real.
  - Consola del navegador: 0 excepciones/errores (`window.onerror`, `unhandledrejection` y `console.error` interceptados antes de cargar Flutter, revisados tras cada navegación) en las ~10 rutas recorridas.

**No verificado todavía / fuera de este ciclo** (quedan explícitamente para cuando les toque turno, no se tocaron sus archivos):
- Los 8 sitios `StudentDetailView` push-only en **otros** portales (Asesor, Admin, Mentor, BuscaTalento, LXD, Donante, Empresa×2) — seguirán funcionando (no se rompió nada), pero no se migraron a la ruta con nombre `/usuarios/:id` porque están en archivos de otros portales.
- Widget tests (pantallas de detalle renderizan con datos válidos / muestran error con ID inválido / navegación desde tarjeta) — no se agregaron todavía; quedan pendientes, ver sección de Tests más abajo antes del cierre general.

### Portal LXD — completado

Mucho más liviano que Estudiante: `lxd_portal.dart` no tenía ningún patrón
`GestureDetector`/`MouseRegion` suelto (todo pasa por `HoverCard`), así que
la accesibilidad de teclado ya quedó resuelta gratis con el fix compartido
del portal Estudiante — no hubo que tocar nada para eso acá.

- **`lib/views/lxd/lxd_portal.dart`**: la fila de estudiante en la `DataTable`
  de "Mis Estudiantes" (`onSelectChanged`) pasó de `StudentDetailView`
  push-only a `/usuarios/:id` (misma corrección que en Estudiante — cierra
  el hallazgo de "PARCIAL: sin ruta con nombre" de la tabla 3.2).
- El resto de "Mis Estudiantes", "Proyectos" (`ProjectSummaryCard`),
  "Calificaciones", "Certificaciones" y "Mi Perfil" ya estaban bien: son
  paneles de acción real (calificar, emitir certificado) o formularios, no
  tarjetas que debieran navegar a una entidad — no se tocaron.
- **Verificado en profundidad lo que la Fase 0 había dejado "no verificado"**:
  los botones "Constructor" (`CourseEditorView`) y "Seguimiento"
  (`CourseTrackingView`) de cada curso en "Mis Cursos" — confirmado en vivo
  que ambos cargan el curso real (formulario prellenado con sus datos, y
  tabla de seguimiento con estudiantes/progreso/notas reales), no son
  pantallas rotas ni vacías.

**Verificación ejecutada:** `flutter analyze` (19 issues, mismo baseline),
`flutter test` (2/2), `flutter build web --release` (compila). En vivo:
login real como LXD, clic en fila de estudiante → `/usuarios/alum1` con
perfil real, clic en "Constructor" → formulario del curso real, clic en
"Seguimiento" → tabla de estudiantes con progreso/notas reales y gráficos.
0 excepciones de consola.

### Portal Admin — completado

Tampoco tenía `GestureDetector`/`MouseRegion` sueltos fuera de `HoverCard`
(el único, en `admin_portal.dart:1175`, es el botón de quitar una imagen de
la galería del editor de contenido — una acción, no una tarjeta de
navegación, se dejó tal cual). Accesibilidad de teclado ya resuelta por el
fix compartido.

- **`lib/views/admin/admin_management.dart`**: la tarjeta de estudiante en
  "Asignaciones" pasó de `StudentDetailView` push-only a `/usuarios/:id`
  (mismo patrón que Estudiante/LXD). El botón "Asignar" (que abre el
  diálogo real de edición) no se tocó — sigue siendo la acción correcta
  para asignar laboratorios/cursos/patrocinador.
- **Verificado, no modificado** (ya estaban bien): "Usuarios" y "Grupos"
  navegan a un diálogo de edición al hacer clic — apropiado para Admin,
  que gestiona esas entidades en vez de solo verlas (mismo criterio que
  "Asignar"). "Laboratorios" abre `LabRutaEditorView(labId)` real (edición,
  no `/laboratorios/:id` — decisión correcta: Admin necesita EDITAR la Ruta
  de Impacto, no verla de solo lectura). "Cursos" → `_AdminCourseCard` con
  "Constructor"/"Seguimiento" verificados con datos reales.
- **Dashboard General** (8 `StatTile`) y **Datos y respaldos** (4
  `StatTile`) — decisión de alcance: se dejan como contadores agregados no
  clickeables. Son cifras de conteo ("45 estudiantes", "12 proyectos"), no
  una entidad con un solo ID al que navegar — el criterio de "tarjeta
  terminada" pedido (navega a una ruta CON parámetro de ID) no aplica
  literalmente a un contador. Convertirlos en accionables requeriría que
  `StatTile` supiera cambiar de pestaña dentro de `PortalShell` (un cambio
  de arquitectura del shell compartido por los 8 portales, no una
  corrección de navegación puntual) — lo señalo para que decidas si lo
  quieres como alcance nuevo, no lo hice por mi cuenta.

**Verificación ejecutada:** `flutter analyze` (19 issues, mismo baseline),
`flutter test` (2/2), `flutter build web --release` (compila). En vivo:
login real como Admin, clic en tarjeta de estudiante en Asignaciones →
`/usuarios/alum1` con perfil real (el botón "Asignar" de al lado se dejó
sin tocar, confirmado que sigue abriendo su diálogo). 0 excepciones de
consola.

### Portal Mentor — completado

Mismo patrón que LXD/Admin: un único punto de corrección.

- **`lib/views/mentor/mentor_portal.dart`**: la fila de estudiante en "Mis
  Laboratorios" (`_LabStudents`) pasó de `StudentDetailView` push-only a
  `/usuarios/:id`. Resto de pestañas (Proyectos, Calendario, Entregas, Mi
  Perfil) ya estaban OK, sin cambios.

**Verificación ejecutada:** `flutter analyze` (19 issues, baseline),
`flutter test` (2/2), `flutter build web --release` (compila). En vivo:
login real como Mentor → "Mis Laboratorios" → clic en estudiante →
`/usuarios/alum1` con perfil real. 0 excepciones de consola.

### Portal Asesor Académico — completado

Mismo patrón: un único punto de corrección.

- **`lib/views/advisor/advisor_portal.dart`**: `_StudentRow` en "Seguimiento
  Estudiantes" pasó de `StudentDetailView` push-only a `/usuarios/:id`.
  StatTiles del Dashboard (4) quedan como contadores agregados, misma
  decisión de alcance que en Admin. Resto de pestañas ya estaban OK.

**Verificación ejecutada:** `flutter analyze` (19 issues, baseline),
`flutter test` (2/2), `flutter build web --release` (compila). En vivo:
login real como Asesor → "Seguimiento Estudiantes" → clic en estudiante →
`/usuarios/alum1` con perfil real. 0 excepciones de consola.

### Portal Empresa — completado

El portal con más tarjetas MUERTAS reales de toda la auditoría (1.4) — 6
puntos corregidos, todos en `lib/views/company/company_portal.dart`:

- "Mis Laboratorios" → "Contenido del laboratorio": cada curso ahora
  navega a `/cursos/:id` (antes sin `onTap` en absoluto).
- "Mis Laboratorios" → "Participantes y su avance": pasó de
  `StudentDetailView` push-only a `/usuarios/:id`.
- "Mis Laboratorios" → "Mentores y su labor": cada mentor ahora navega a
  `/usuarios/:id` (antes sin `onTap`).
- "Estudiantes Patrocinados" (`_CompanyStudents`): pasó de
  `StudentDetailView` push-only a `/usuarios/:id`.
- "Mi Equipo LXD" (pestaña completa): cada LXD ahora navega a
  `/usuarios/:id` (antes sin `onTap` en ninguna fila).
- "Mi Equipo Mentor" (pestaña completa): cada mentor ahora navega a
  `/usuarios/:id` (antes sin `onTap` en ninguna fila). El botón "Asignar
  cursos" de al lado (acción de edición real) no se tocó.

Sin `GestureDetector`/`MouseRegion` sueltos — accesibilidad de teclado ya
resuelta por el fix compartido.

**Nota verificada, no corregida:** al abrir un curso desde este portal
(rol no-estudiante, sin `studentId`), la barra de progreso muestra 0% y el
botón de completar lección queda habilitado — mismo comportamiento que
tenía la pantalla para cualquier rol no-estudiante que llegara a
`/cursos/:id` sin pasar `studentId` (Admin, LXD, etc.), de antes de este
trabajo. No es el bug 1.2 (que era mostrar el progreso de la persona
EQUIVOCADA) — acá simplemente no hay ningún estudiante real involucrado,
así que no hay identidad que confundir. Lo señalo por transparencia, no lo
amplié a "bloquear completar lecciones para todo rol no-estudiante" porque
no estaba en el alcance de lo reportado en la Fase 0.

**Verificación ejecutada:** `flutter analyze` (19 issues, baseline),
`flutter test` (2/2), `flutter build web --release` (compila). En vivo:
login real como Empresa (Bancolombia), recorridas las 6 correcciones una
por una — cada clic confirmado con la URL resultante real (`/cursos/crs_ia_1`,
`/usuarios/lxd1`, `/usuarios/ment1`, `/usuarios/alum1`). 0 excepciones de
consola en las ~8 rutas recorridas.

### Portal Donante — completado

- **`lib/views/donor/donor_portal.dart`**: `_StudentProfileCard` (Mi
  Impacto) pasó de `StudentDetailView` push-only a `/usuarios/:id`.
  `_DonorEvidences` (tarjetas "Ver historia →") migrado de
  `HoverBuilder`+`GestureDetector` suelto a `KeyboardHoverBuilder` — cierra
  también la accesibilidad de teclado para esta pantalla puntual (el resto
  del portal ya la tenía gratis por usar `HoverCard`). El diálogo de
  historia se sigue abriendo igual, verificado en vivo.

**Verificación ejecutada:** `flutter analyze` (19 issues, baseline),
`flutter test` (2/2), `flutter build web --release` (compila). En vivo:
login real como Donante → "Mi Impacto" → clic en estudiante apoyado →
`/usuarios/alum1` con perfil real; "Evidencias" → clic en "La historia de
Sara" → diálogo abre con el contenido real, sin romper nada. 0 excepciones
de consola.

## 0. Metodología (léela antes que la tabla)

No todos los archivos recibieron el mismo nivel de escrutinio — lo digo explícito porque la regla de oro del proyecto es no reportar "listo" sin haberlo verificado:

- **Lectura completa, línea por línea:** `main.dart`, `constants.dart` (AppRoutes/Roles), `data_provider.dart` (todo el API de consultas), `models.dart` (entidades completas), `common.dart` (widgets compartidos: `HoverCard`, `StatTile`, `EmptyState`, diálogos), y las pantallas centrales del portal Estudiante (`student_dashboard_view.dart`, `student_courses_view.dart`, `student_portal.dart`), `student_detail_view.dart`, `lab_progress_view.dart`, `projects_directory_view.dart` (incluida `ProjectDetailView` completa), `course_detail_view.dart` (estructura y el bug reportado en 1.2).
- **Lectura dirigida (mapa de clases + secciones específicas leídas enteras):** `ruta_impacto_view.dart` (2291 líneas — se leyeron las secciones con tarjetas: `_OtherLabCard`, `_LabLxdCard`, `_ExpoCard`, y se mapeó el resto por clase), `lxd_portal.dart`, `mentor_portal.dart`, `advisor_portal.dart`, `company_portal.dart` (incluida `_CompanyLabSection`, `_CompanyLxdTeam`, `_CompanyMentorTeam` completas), `donor_portal.dart`, `admin_portal.dart` (Dashboard completo), `admin_management.dart`, `students_map_view.dart` (`_CityRow`), `forum_view.dart`, `talent_search_view.dart`, `communication_resources_view.dart`.
- **Solo mapeado por grep (clases + `onTap`/`Navigator`/`StatTile`), sin lectura profunda de la lógica interna:** `admin_backup.dart` (confirmado el patrón StatTile), `lab_ruta_editor.dart`, `course_editor_view.dart`, `course_tracking_view.dart`, `lesson_editor.dart` — son constructores/editores (Admin y LXD armando contenido), no pantallas de navegación por tarjetas, que es el foco de este pedido. Recomiendo una pasada dedicada a estos 4 archivos en Fase 1 antes de tocarlos, no asumas que están bien por no aparecer aquí como ROTO.
- **No pude ejecutar `flutter run -d chrome` interactivo en este entorno** (Fase 0 es de solo lectura, sin verificación en vivo) — todo lo de abajo es análisis estático de código, trazando cada `onTap`/`Navigator.push`/`Navigator.pushNamed` hasta su destino real y comprobando que ese destino llama a `DataProvider` con un ID real. La verificación EN VIVO (login real, clic real, redimensionar) es exactamente lo que pide el protocolo de Fase 1 en adelante — no está hecha todavía y no la doy por hecha.

---

## 1. Hallazgos transversales (aplican a casi toda la app — léelos antes de la tabla, evitan que la tabla se vea repetitiva)

### 1.1 — Ningún elemento clickeable de la plataforma es accesible por teclado hoy (confirmado, no una muestra)

> **Estado: causa raíz corregida en `HoverCard`/`KeyboardHoverBuilder` (Fase 1, portal Estudiante).** El fix vive en `common.dart`, así que todo lo que ya usa `HoverCard` en cualquier portal queda accesible por teclado automáticamente sin tocar esos archivos — falta migrar los sitios que usan `GestureDetector` suelto (no `HoverCard`) en LXD/Admin/Mentor/Asesor/Empresa/Donante, uno por uno cuando les toque turno. Ver el detalle de la verificación (incluido un bug real que se encontró y corrigió: `shortcuts:` faltante) en "Estado de ejecución" al inicio del documento.
Grep exhaustivo en `lib/views/` + `lib/widgets/`: **cero** usos de `Focus`, `FocusableActionDetector`, `Shortcuts` o `CallbackShortcuts`. **Un solo** uso de `InkWell` en toda la app (`student_portal.dart`); el resto de las ~90 tarjetas/filas clickeables usan `GestureDetector`+`MouseRegion` (el patrón de `HoverCard` en `common.dart`, copiado en casi todas las tarjetas). `GestureDetector` no participa del orden de foco de Flutter ni activa con Enter/Space — Tab nunca llega a estas tarjetas. Esto afecta **absolutamente todas** las filas "OK" de la tabla de abajo: navegan bien con mouse, ninguna es alcanzable con teclado. Es el criterio #9 de "tarjeta terminada" y hoy lo incumple el 100% de la app, no una lista de casos puntuales.
**Causa raíz única, arreglo único:** el lugar correcto para resolver esto es `HoverCard` en `common.dart` (que ya envuelve casi todo) — envolverlo en `FocusableActionDetector` (foco + `Enter`/`Space` → `onTap`) arregla la mayoría de los casos de un solo golpe. Los sitios que usan `GestureDetector` suelto en vez de `HoverCard` (varios de los listados en 1.3) necesitan el mismo tratamiento repetido a mano.

### 1.2 — Bug confirmado: `CourseDetailView` no verifica de quién es el progreso que muestra

> **Estado: corregido y verificado en vivo (Fase 1, portal Estudiante).** Ver "Estado de ejecución" al inicio.
`lib/views/student/course_detail_view.dart:26`: `final student = context.watch<AuthProvider>().currentUser!;` — la pantalla SIEMPRE calcula el progreso/las lecciones completadas del **usuario que tiene la sesión abierta**, nunca del estudiante cuyo curso se quiso ver. La ruta `/cursos/:id` es alcanzable por cualquier rol logueado (`_AuthGuard` en `main.dart:143-146`, sin `_RoleGuard`), y en concreto **sí se llega ahí desde fuera del portal Estudiante**: `student_detail_view.dart:281` empuja a `CourseDetailView` cuando un LXD/Mentor/Asesor/Empresa/Donante/Admin abre el perfil de un estudiante y hace clic en uno de sus cursos.
**Repro:** login como Mentor → abrir cualquier estudiante desde "Mis Laboratorios" → clic en uno de sus cursos → la pantalla muestra "0 de N lecciones" (el progreso del Mentor, que nunca tomó el curso) en vez del progreso real del estudiante, y el botón de marcar lección como completada escribiría un `Progress` fantasma bajo el id del Mentor.
Clasificado como **ROTA** en la tabla (no PARCIAL): el contenido que muestra es activamente incorrecto, no solo incompleto.

### 1.3 — `StatTile` (el widget de tarjeta-métrica más usado de la app) no tiene ni puede tener `onTap`
`lib/widgets/common.dart:191-241`: el constructor de `StatTile` no declara ningún parámetro de callback — es estructuralmente imposible que navegue a ningún lado, sin importar qué tan "clickeable" se vea (tiene hover-glow vía `HoverCard` interno, lo que visualmente SUGIERE interactividad que no existe). 34 instancias en 6 archivos:

| Archivo | Instancias | Tab/contexto |
|---|---|---|
| `admin/admin_portal.dart` | 8 | Dashboard General |
| `lxd/course_tracking_view.dart` | 9 | Seguimiento de un curso |
| `company/company_portal.dart` | 7 | Dashboard de Impacto |
| `advisor/advisor_portal.dart` | 4 | Dashboard |
| `admin/admin_backup.dart` | 4 | Datos y respaldos |
| `shared/lab_progress_view.dart` | 2 | Detalle de progreso de lab |

Casi todas estas cifras tienen un destino obvio y ya construido en la app (Estudiantes → lista/tabla de usuarios filtrada; Proyectos → Directorio de Proyectos; Cursos → lista de cursos; Certificados → no hay pantalla de "todos los certificados" hoy, ver 1.6; Laboratorios → no hay `/laboratorios/:id` general, ver 1.5). Es el hallazgo que más directamente explica la queja original ("tarjetas decorativas que se ven bien pero no navegan").

### 1.4 — Patrón repetido: tarjetas de "equipo/roster" que muestran a una persona real pero no enlazan a su perfil
Mismo patrón, confirmado por lectura completa en 4 lugares distintos (no es un caso aislado):
- `student/ruta_impacto_view.dart` `_LabLxdCard` (tarjeta "Tu LXD" en el detalle de laboratorio del estudiante) — nombre, avatar, disponibilidad, correo — sin `onTap`.
- `company/company_portal.dart` `_CompanyLabSection`, fila de cada mentor bajo "Mentores y su labor" (línea 549) — sin `onTap`.
- `company/company_portal.dart` `_CompanyLxdTeam` (pestaña completa "Mi Equipo LXD") — cada fila sin `onTap`.
- `company/company_portal.dart` `_CompanyMentorTeam` (pestaña completa "Mi Equipo Mentor") — cada fila sin `onTap`.
También en `company_portal.dart` `_CompanyLabSection`, la lista "Contenido del laboratorio" (línea 426) muestra cada curso del lab sin enlazar a `CourseDetailView`, mientras que 2 tarjetas más abajo en la MISMA pantalla ("Participantes y su avance") sí navegan correctamente — inconsistencia dentro del mismo archivo, no todo el archivo está roto por igual.
**Causa de fondo, no solo "faltó el onTap":** hoy no existe ninguna pantalla de perfil genérica para LXD/Mentor (`StudentDetailView` es, por nombre y por las secciones que renderiza — cursos, laboratorios propios, certificados — específica de un estudiante). Ver 1.5.

### 1.5 — Dos de las 4 pantallas de detalle pedidas NO tienen ruta general hoy

> **Estado: ambas rutas creadas y verificadas en vivo (Fase 1, portal Estudiante)** — `/usuarios/:id` → `UserDetailView`, `/laboratorios/:id` → `LabDetailView`. Ver "Estado de ejecución" al inicio.
- **`/usuarios/:id` no existe.** Lo más parecido es `StudentDetailView` (`shared/student_detail_view.dart`) — bien construida (carga por `userById(studentId)`, tiene estado de error real si el id no existe), pero (a) solo se llega por `Navigator.push`, nunca por una URL con nombre registrada en `main.dart`, y (b) está diseñada específicamente para el perfil de un estudiante (muestra cursos/labs/certificados) — abrirla con el id de un LXD o Mentor no crashea pero tampoco muestra nada útil de ese rol (ver 1.4).
- **`/laboratorios/:id` no existe como ruta general.** Lo que hay: `LabDetailBody` (dentro de `ruta_impacto_view.dart`) — completa y correcta, pero vive empotrada en el shell del portal Estudiante vía `contentOverride` y siempre asume "el laboratorio del estudiante actual" (usa `AuthProvider.currentUser` igual que el bug de 1.2, mismo patrón de riesgo si algún día se reutiliza fuera del portal Estudiante); y `LabProgressView` (`shared/lab_progress_view.dart`) — requiere `studentId` **y** `labId` juntos (progreso de un estudiante puntual en un lab), no sirve como vista general del laboratorio en sí (fases/módulos/cursos, sin atarlo a un estudiante) para que Admin/LXD/Mentor/Empresa la abran desde una tarjeta de "Laboratorios" sin partir de un estudiante.

Ambas registradas como **rutas huérfanas de facto**: existen implementaciones de calidad para la mayor parte del contenido pedido, pero ninguna es una ruta con nombre alcanzable con un id solo, así que no cumplen el criterio "navega a una ruta con parámetro de ID" tal cual se pidió.

### 1.6 — Datos hardcodeados: no se encontró ninguno
Grep de `TODO|FIXME|hardcode|placeholder|dummy|fake|mock` en toda `lib/views/`+`lib/widgets/`: sin resultados reales (los matches fueron todos falsos positivos: la palabra española "todos", o `placeholderBuilder`/`_placeholder()` que son estados de carga legítimos de imágenes/video, no datos falsos). Todo lo que audité línea por línea consulta `DataProvider` de verdad. Esto es una fortaleza real de la base existente — no es una queja de la auditoría.

### 1.7 — Brecha de modelo (no de UI): "rol dentro del proyecto" no existe en los datos
El pedido de `/proyectos/:id` incluye "Integrantes: nombre, foto, rol dentro del proyecto (desde el Group asociado)". `Group` (`models.dart:223-257`) solo tiene `studentIds: List<String>` — ningún campo de rol por integrante. Mostrar esto en Fase 1 requiere ampliar el modelo `Group` (agregar, p. ej., `Map<String, String> memberRoles` o una lista de objetos), lo cual es un cambio de forma de datos (JSON en Hive), no de `DbService` en sí — technically permitido por el alcance ("no se cambia DbService"), pero lo marco explícito porque es un cambio de modelo, no solo de pantalla.

### 1.8 — Brecha de modelo: `Evidence` no tiene `projectId`
El pedido de `/proyectos/:id` incluye "Evidencias asociadas, si el rol tiene permiso". `Evidence` (`models.dart:1055-1091`) solo tiene `donorId` — está atada a qué donante la subió, no a qué proyecto retrata. Con el modelo actual no hay forma de saber qué evidencias "pertenecen" a un proyecto sin adivinar. Mismo comentario que 1.7: es una decisión de modelo para Fase 1, no soluble solo con UI.

### 1.9 — Permisos: el patrón dominante es "sin restricción, por diseño documentado" — solo 1 pantalla tiene un bug real de rol
La mayoría de las pantallas de detalle compartidas (`StudentDetailView`, `ProjectDetailView`, `LabProgressView`) **no** filtran por rol — y en los 3 casos hay un comentario en el código que documenta que es intencional ("para que otro rol... vea su información real"). Es una decisión de producto ya tomada, no un descuido — la dejo así en la tabla (OK en cuanto a permisos) salvo el caso de 1.2, que sí es un bug real (no de permisos sino de identidad: usa el usuario equivocado).

---

## 2. Inventario de rutas

### 2.1 Declaradas en `AppRoutes` (`utils/constants.dart`) y su alcanzabilidad real

| Ruta | ¿Alcanzable desde la UI? | Notas |
|---|---|---|
| `/` (landing) | Sí | Pública |
| `/login` | Sí | Desde landing y desde cualquier `_RoleGuard` sin sesión |
| `/student` | Sí | Login con rol `student` |
| `/alumni` | Sí | Login con rol `alumni` |
| `/lxd` | Sí | Login con rol `lxd` |
| `/mentor` | Sí | Login con rol `mentor` |
| `/admin` | Sí | Login con rol `admin` |
| `/superadmin` | Sí | Login con rol `superadmin` (hay 2 cuentas seed) — **no es huérfana**, aunque no la vi enlazada desde ningún botón visible aparte del login |
| `/advisor` | Sí | Login con rol `advisor` |
| `/company` | Sí | Login con rol `company` |
| `/donor` | Sí | Login con rol `donor` |
| `/proyectos` (base) | — | Nunca se usa sola, solo `/proyectos/:id` (patrón `startsWith`) |
| `/cursos` (base) | — | Ídem, solo `/cursos/:id` |

### 2.2 Patrones dinámicos reales en `_onGenerateRoute` (no son constantes en `AppRoutes`, viven como `String name when name.startsWith(...)` en `main.dart`)

| Patrón | Alcanzable | Notas |
|---|---|---|
| `/student/lab/:id`, `/alumni/lab/:id` | Sí | Desde tarjetas de laboratorio del portal Estudiante |
| `/student/laboratorios`, `/alumni/laboratorios` | Sí | Botón "Todos los laboratorios" desde un detalle |
| `/proyectos/:id` | Sí | Desde ~7 sitios distintos (Admin, Estudiante, LXD/Mentor vía `ProjectSummaryCard`) |
| `/cursos/:id` | Sí | Desde ~7 sitios — ver bug 1.2 |

### 2.3 Rutas requeridas por este pedido que NO existen todavía

| Ruta pedida | Estado |
|---|---|
| `/usuarios/:id` | **No existe.** Ver 1.5. |
| `/laboratorios/:id` | **No existe como ruta general.** Ver 1.5. |

### 2.4 Pantallas que reciben un ID pero no cargan la entidad
**Ninguna encontrada.** Todo lugar que recibe un id (`courseId`, `projectId`, `studentId`, `labId`) sí llama al método correspondiente de `DataProvider` (`courseById`, `projectById`, `userById`, `labById`) y tiene una rama para "no existe" (`EmptyState` o texto de error) — confirmado en `ProjectDetailView`, `StudentDetailView`, `LabProgressView`, `CourseDetailView`. La única falla real de "carga la entidad equivocada" es el bug de identidad de 1.2, que es distinto a "no carga nada".

---

## 3. Tabla de tarjetas y elementos clickeables por portal

Leyenda: **OK** = navega y el destino muestra datos reales · **MUERTA** = sin acción de clic · **ROTA** = navega pero el destino falla/está vacío/muestra datos incorrectos · **PARCIAL** = navega pero incompleta (faltan datos, o usa modal en vez de ruta con ID).

### 3.1 Portal Estudiante

| Pestaña | Componente | ¿Navega? | ¿A dónde? | ¿Destino con datos reales? | Estado |
|---|---|---|---|---|---|
| Dashboard | `_ContinueCard` (curso a continuar) | Sí | `/cursos/:id` | Sí | OK |
| Dashboard | `_CourseProgressCard`, fila por curso | Sí | `/cursos/:id` | Sí | OK |
| Dashboard | `_PendingCard`, ítem "Fase vencida" / "Confirmar mentoría" | Sí | `/{rol}/lab/:id` | Sí | OK |
| Dashboard | `_PendingCard`, ítem "Continuar curso" | Sí | `/cursos/:id` | Sí | OK |
| Dashboard | `_PendingCard`, ítem checklist Expo | Sí | Diálogo (no ruta) | Sí, de solo lectura — **intencional**, documentado en código: no existe pantalla de edición del checklist en toda la app | PARCIAL (a propósito) |
| Dashboard | `_RecentActivityCard` (última entrega calificada) | Sí | `/cursos/:id` | Sí | OK |
| Dashboard | `_ProjectCard` ("Tu proyecto") | Sí | `/proyectos/:id` | Sí | OK |
| Mis Cursos | Cada `_CourseCard` (grilla completa) | Sí | `/cursos/:id` | Sí | OK |
| Mi Perfil | `_ProjectCard` (perfil) | Sí | `/proyectos/:id` | Sí | OK |
| Mi Perfil | `_ProfileStatCard` ×4 (cursos/lecciones/labs/certificados) | No | — | — | MUERTA (informativas por diseño — no son entidades con detalle propio, salvo que se decida enlazar "Certificados" a Mis Certificados) |
| Mi Perfil | `_CertificatesCard` | Acción (descargar/ver PDF) | — | Sí | OK (no requiere ruta, son acciones reales) |
| Certificados | Cada certificado | Acción (descargar/ver PDF) | — | Sí | OK |
| Laboratorios | `_LabCard` (grilla principal) | Sí | `/{rol}/lab/:id` | Sí | OK |
| Laboratorios | `_OtherLabCard` ("Otros laboratorios de la red") | Sí ✅ *(corregido)* | `/laboratorios/:id` (nuevo) | Sí, avance agregado del grupo | **OK** — verificado en vivo, 3 breakpoints |
| Detalle de laboratorio | Fila de cada curso del módulo | Sí | `/cursos/:id` | Sí | OK |
| Detalle de laboratorio | `_LabLxdCard` ("Tu LXD") | Sí ✅ *(corregido)* | `/usuarios/:id` (nuevo) | Sí, perfil real del LXD | **OK** — verificado en vivo |
| Detalle de laboratorio | Botón "Unirse a la reunión" (módulo de mentoría) | Acción (abre link externo) | — | Sí | OK |
| Ruta de Impacto (shortcut) | Selector de laboratorio (chips) | Sí (cambia estado local) | — | Sí | OK |
| Ruta de Impacto | Fila de módulo (`_ModuleSummaryRow`) | Sí (si desbloqueado) | `ModuleDetailScreen` | Sí | OK |
| Ruta de Impacto | `_ExpoCard` (checklist) | No | — | — | MUERTA a propósito, mismo caso documentado que arriba |
| Módulo | Fila de curso vinculado | Sí | `/cursos/:id` | Sí | OK |
| Módulo | Fila de entrega/lectura propia | Sí | Diálogo de entrega | Sí | OK (acción real, no requiere ID-route) |
| Directorio de Proyectos | Cada `_ProjectCard` de la grilla | Sí | `/proyectos/:id` | Sí | OK |
| `/proyectos/:id` | Cada integrante del equipo (nombre/avatar) | Sí ✅ *(corregido)* | `/usuarios/:id` (nuevo) | Sí, perfil real | **OK** — verificado en vivo (Mateo Ruiz → su perfil completo) |
| `/proyectos/:id` | Chip de laboratorio de un integrante | Sí | `LabProgressView(studentId, labId)` push-only | Sí | PARCIAL (sin ruta con nombre — no se tocó, es progreso de UN estudiante puntual, distinto de `/laboratorios/:id`) |
| `/cursos/:id` | Toda la pantalla | — | — | Corregida (ver 1.2) | **OK** ✅ *(corregido)* — verificado en vivo: banner de solo lectura, progreso real del estudiante correcto, quiz/actividad bloqueados |
| Foro | Cada post: like, responder, fijar (mod), borrar (mod) | Acción | — | Sí | OK |

### 3.2 Portal LXD

| Pestaña | Componente | ¿Navega? | ¿A dónde? | ¿Destino con datos reales? | Estado |
|---|---|---|---|---|---|
| Mis Estudiantes | Fila de la `DataTable` | Sí ✅ *(corregido)* | `/usuarios/:id` | Sí | **OK** |
| Proyectos | `ProjectSummaryCard` | Sí | `/proyectos/:id` | Sí | OK |
| Mis Cursos | `_CourseAdminCard`, botón "Constructor" | Sí | `CourseEditorView(courseId)` | Sí ✅ *(verificado en vivo)* | **OK** |
| Mis Cursos | `_CourseAdminCard`, botón "Seguimiento" | Sí | `CourseTrackingView(courseId)` | Sí ✅ *(verificado en vivo)* | **OK** |
| Mis Cursos | `_CourseAdminCard`, botón "Vincular a Ruta de Impacto" | Diálogo | — | Sí | OK |
| Calendario | Eventos Open Learning | Acción (CRUD inline) | — | Sí | OK |
| Calificaciones | Tarjeta de entrega + botón "Calificar/Editar" | Diálogo (acción real) | — | Sí | OK |
| Certificaciones | Formulario de emisión + lista de emitidos | — | — | Sí | OK (no son entidades navegables) |
| Mi Perfil | Tarjeta de datos propios | — | — | Sí | OK (perfil propio, sin necesidad de navegar) |

### 3.3 Portal Admin

| Pestaña | Componente | ¿Navega? | ¿A dónde? | ¿Destino con datos reales? | Estado |
|---|---|---|---|---|---|
| Dashboard | 8× `StatTile` (Estudiantes/Proyectos/Equipos/Cursos/Certificados/Universidades/Mentores/Laboratorios) | No (decisión de alcance) | — | — | Contadores agregados, no entidades — ver nota de alcance arriba |
| Dashboard | Gráficos (usuarios por rol, proyectos por etapa) | No | — | Sí, son gráficos, no tarjetas de entidad | OK (no aplica navegación) |
| Usuarios | Fila de usuario | Sí | Diálogo de edición (`showUserDialog`) | Sí | OK (gestión CRUD, apropiado para Admin) |
| Proyectos | Cada tarjeta de proyecto | Sí | `/proyectos/:id` | Sí | OK |
| Grupos | Tarjeta de grupo | Sí | Diálogo de edición (`_editGroup`) | Sí | OK (es gestión CRUD, no vista de detalle — apropiado para Admin) |
| Asignaciones | Tarjeta de estudiante | Sí ✅ *(corregido)* | `/usuarios/:id` | Sí | **OK** — botón "Asignar" (edición) verificado aparte, intacto |
| Laboratorios | Tarjeta de laboratorio | Sí | `LabRutaEditorView(labId)` (edición real) | Sí | OK (Admin edita la Ruta de Impacto, no la ve de solo lectura — decisión correcta) |
| Cursos | `_AdminCourseCard`, "Constructor"/"Seguimiento" | Sí | `CourseEditorView`/`CourseTrackingView` | Sí ✅ *(verificado en vivo desde LXD, mismo componente)* | **OK** |
| Evidencias donantes | Tarjeta de evidencia | Sí | Diálogo (`_showEvidenceDetail`) | Sí | PARCIAL (modal, no ruta — Evidence no tiene ruta propia pedida, prioridad baja) |
| Datos y respaldos | 4× `StatTile` | No (decisión de alcance) | — | — | Contadores agregados — ver nota arriba |
| Contenido página, Recursos Comunicaciones | Editores de contenido, no pantallas de tarjetas | — | — | — | Fuera de alcance de "navegación por tarjetas" |

### 3.4 Portal Mentor

| Pestaña | Componente | ¿Navega? | ¿A dónde? | ¿Destino con datos reales? | Estado |
|---|---|---|---|---|---|
| Proyectos | `ProjectSummaryCard` | Sí | `/proyectos/:id` | Sí | OK |
| Mis Laboratorios | Fila de estudiante (`_LabStudents`) | Sí ✅ *(corregido)* | `/usuarios/:id` | Sí | **OK** |
| Calendario | Eventos | Acción | — | Sí | OK |
| Entregas | Tarjeta de entrega | Botón "Comentar/Editar" (diálogo) | — | Sí | OK (acción real, no necesita ruta) |
| Mi Perfil | — | — | — | Sí, de solo lectura | OK |

### 3.5 Portal Asesor Académico

| Pestaña | Componente | ¿Navega? | ¿A dónde? | ¿Destino con datos reales? | Estado |
|---|---|---|---|---|---|
| Dashboard | 4× `StatTile` | No (decisión de alcance) | — | — | Contadores agregados — ver nota en tabla 3.3 |
| Mis Estudiantes | `_StudentRow` | Sí ✅ *(corregido)* | `/usuarios/:id` | Sí | **OK** |
| Proyectos | Tarjeta de proyecto | Sí | `/proyectos/:id` | Sí | OK |
| Calendario | Eventos | Acción | — | Sí | OK |

### 3.6 Portal Empresa

| Pestaña | Componente | ¿Navega? | ¿A dónde? | ¿Destino con datos reales? | Estado |
|---|---|---|---|---|---|
| Proyectos | Tarjeta de proyecto | Sí | `/proyectos/:id` | Sí | OK |
| Dashboard de Impacto | 7× `StatTile` | No (decisión de alcance) | — | — | Contadores agregados — ver nota en tabla 3.3 |
| Laboratorios | Banner "horas patrocinadas" | No | — | Sí, informativo | OK (no es una entidad) |
| Laboratorios | Tarjeta "Objetivos" del lab | No | — | Sí, informativo | OK (no es una entidad con detalle propio) |
| Laboratorios | "Contenido del laboratorio", fila de curso | Sí ✅ *(corregido)* | `/cursos/:id` | Sí | **OK** |
| Laboratorios | "Objetivos de la Ruta de Impacto", tarjeta de fase | No | — | Sí, informativo con contador real | OK |
| Laboratorios | "Participantes y su avance", fila de estudiante | Sí ✅ *(corregido)* | `/usuarios/:id` | Sí | **OK** |
| Laboratorios | "Mentores y su labor", fila de mentor | Sí ✅ *(corregido)* | `/usuarios/:id` | Sí | **OK** |
| Patrocinados | Fila de estudiante | Sí ✅ *(corregido)* | `/usuarios/:id` | Sí | **OK** |
| Mi Equipo LXD | Cada LXD | Sí ✅ *(corregido)* | `/usuarios/:id` | Sí | **OK** |
| Mi Equipo Mentor | Cada Mentor | Sí ✅ *(corregido)* | `/usuarios/:id` | Sí | **OK** |

### 3.7 Portal Donante

| Pestaña | Componente | ¿Navega? | ¿A dónde? | ¿Destino con datos reales? | Estado |
|---|---|---|---|---|---|
| Dashboard | Banner de código de impacto | No | — | Sí, informativo | OK (no es una entidad) |
| Dashboard | `_StudentProfileCard` (estudiantes apoyados) | Sí ✅ *(corregido)* | `/usuarios/:id` | Sí | **OK** |
| Evidencias | Tarjeta de evidencia | Sí | `_showStory` (diálogo) | Sí | PARCIAL (modal, no ruta — prioridad baja, Evidence no tiene ruta propia pedida); teclado ✅ *(corregido)* |

### 3.8 Público / Auth

| Pantalla | Componente | ¿Navega? | ¿A dónde? | ¿Destino con datos reales? | Estado |
|---|---|---|---|---|---|
| Landing | Botones "Iniciar sesión" / "Entrar a la plataforma" | Sí | `/login` | Sí | OK |
| Landing | Tarjetas de "Nuestros Laboratorios" | No | — | — | OK — es contenido público sin sesión, no hay `/laboratorios/:id` público que mostrar todavía (razonable dejarlo así) |
| Login | Formulario | Sí | Portal según rol | Sí | OK |
| 404 | Botón volver | Sí | `/` | Sí | OK |

---

## 4. Resumen cuantitativo

- **Tarjetas/filas MUERTAS confirmadas por lectura directa (no estimadas):** 8 (Admin Dashboard) + 4 (Admin Backup) + 4 (Asesor Dashboard) + 7 (Empresa Dashboard) = 23 `StatTile` sin posibilidad de `onTap`, **más** 8 tarjetas de tipo "roster sin enlace a perfil" (`_OtherLabCard`, `_LabLxdCard`, Empresa "Contenido del laboratorio", Empresa "Mentores y su labor", Empresa "Mi Equipo LXD", Empresa "Mi Equipo Mentor" — cuenta por sección, no por fila individual) = **~31 puntos muertos confirmados**, sin contar `course_tracking_view.dart` (9 `StatTile` más, no auditado en profundidad pero con el mismo problema estructural garantizado).
- **1 bug ROTO confirmado y reproducible:** `CourseDetailView` usa la identidad equivocada cuando se llega desde el perfil de otro estudiante (1.2).
- **2 rutas pedidas que no existen:** `/usuarios/:id`, `/laboratorios/:id` (1.5).
- **~10 navegaciones PARCIALES:** funcionan y muestran datos reales, pero van a `StudentDetailView`/`LabProgressView` por `Navigator.push` sin ruta con nombre (no cumplen literalmente "navega a una ruta con parámetro de ID" del criterio de tarjeta terminada).
- **2 brechas de modelo de datos** (no de UI): `Group` sin rol por integrante (1.7), `Evidence` sin `projectId` (1.8).
- **1 hallazgo transversal de accesibilidad:** 0% de las tarjetas de la app son operables por teclado (1.1).
- **0 datos hardcodeados encontrados** (1.6) — la disciplina de "todo sale de `DataProvider`" ya está bien establecida en el código existente.
- **Archivos no auditados en profundidad** (por ser constructores/editores, no pantallas de tarjetas): `lab_ruta_editor.dart`, `course_editor_view.dart`, `course_tracking_view.dart`, `lesson_editor.dart`, y las pestañas de Admin "Asignaciones", "Cursos", "Contenido página", "Recursos Comunicaciones", "Usuarios" (tabla de usuarios), y "Calificaciones"/"Certificaciones" del LXD.

---

## 5. Qué pediría revisar antes de aprobar Fase 1

1. **Confirmar el orden de arreglo dentro de cada portal** implícito en el protocolo (Estudiante → LXD → Admin → Mentor → Asesor → Empresa → Donante → Público): dentro de Estudiante, ¿el bug de `CourseDetailView` (1.2) se arregla primero por ser el único ROTO real, antes que las tarjetas MUERTAS del resto de portales?
2. **Decidir el alcance de `/usuarios/:id`**: ¿generalizar `StudentDetailView` para que sirva también a LXD/Mentor (con sus propias secciones), o construir una pantalla nueva por rol? Afecta directamente a 1.4 (8 tarjetas MUERTAS dependen de esta decisión).
3. **Decidir el alcance de `/laboratorios/:id`**: ¿una vista nueva de laboratorio "puro" (sin atarlo a un estudiante), o generalizar `LabDetailBody`/`LabProgressView`?
4. **Confirmar si toca el modelo de datos** para 1.7 (rol por integrante) y 1.8 (`projectId` en Evidence), dado que el prompt dice "no se toca el backend ni `DbService`" — technically el cambio de forma del JSON en Hive no es `DbService`, pero quiero luz verde explícita antes de tocar `models.dart`.
5. Los 5 archivos "no auditados en profundidad" (sección 4) — ¿los reviso a fondo ahora, antes de aprobar, o quedan para revisarse al llegar a su portal en el bucle de Fase 1?

Quedo a la espera de tu aprobación antes de escribir cualquier código.
