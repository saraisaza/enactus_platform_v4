# Portal LXD — migrado, a la espera del constructor de cursos

`lxd_portal.dart` **ya está migrado** contra la API: sus siete pestañas leen
`AsyncValue`, el alcance lo decide el servidor y no queda nada de Hive.

No está en `lib/` por una sola razón: importa `CourseEditorView`, que todavía
no se migró. Ponerlo antes obligaría a comentar ese botón o a dejar un import
roto, y las dos cosas son peores que tenerlo acá con el motivo escrito.

**Para activarlo**: migrar `course_editor_view.dart` y `lesson_editor.dart`
(siguen en `migration_pending/views/lxd/`), mover este archivo a
`lib/views/lxd/` y apuntar la ruta `/lxd` de `main.dart` a `LxdPortal`.

Lo que ya está en `lib/` y funcionando:

- `lib/views/lxd/course_tracking_view.dart` — seguimiento de un curso.

Endpoints que ya existen para lo que falta:

- `POST /courses`, `PATCH /courses/:id`, `POST /courses/:id/publish`,
  `POST /courses/:id/archive`, `DELETE /courses/:id`
- `POST /courses/:id/modules`, `PUT /courses/:id/modules/order`,
  `PATCH /modules/:id`, `DELETE /modules/:id`
- `POST /modules/:id/lessons`, `PUT /modules/:id/lessons/order`,
  `PATCH /lessons/:id`, `DELETE /lessons/:id`
- `POST /lessons/:id/video-upload-url`, `POST /lessons/:id/video`,
  `POST /lessons/:id/video-external`

Lo que **falta construir** en la API para el constructor:

- `PUT /lessons/:id/quiz` — reemplazar las preguntas con su clave de
  respuestas (solo quien edita el curso; la clave nunca sale en una lectura).
- `PUT /lessons/:id/activity` — configuración de la actividad y su rúbrica.
- `PUT /courses/:id/meta` — etiquetas, objetivos, competencias y ODS, que el
  editor edita como un solo formulario.
