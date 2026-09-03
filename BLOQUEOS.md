# Bloqueos y pendientes — Fase 1 (navegación funcional)

No hubo ningún caso de "3 intentos fallidos sobre el mismo error" (el único
bug real que se corrigió en el camino — el `shortcuts:` faltante en
`KeyboardHoverBuilder`, ver AUDITORIA_FRONT.md § "Estado de ejecución" —
se encontró y arregló en el primer intento de verificación real). Este
archivo documenta, en cambio, lo que quedó **deliberadamente fuera de
alcance** o **sin verificar**, para que no se lea como "terminado" por
omisión.

## 1. Decisión de alcance: `StatTile` (contadores agregados) no se hizo clickeable

**Dónde:** Admin Dashboard (8), Admin "Datos y respaldos" (4), Asesor
Dashboard (4), Empresa "Dashboard de Impacto" (7) — 23 instancias
confirmadas por lectura directa, más 9 en `lxd/course_tracking_view.dart`
que ni siquiera se llegaron a auditar en profundidad.

**Por qué no se tocó:** el criterio de "tarjeta terminada" pedido dice
"navega a una ruta CON PARÁMETRO DE ID". Un `StatTile` como "45
estudiantes" no representa una sola entidad con un id — representa un
conteo agregado. Lo más parecido a "hacerlo navegable" sería que
disparara un cambio de PESTAÑA dentro del mismo portal (p. ej. "45
estudiantes" → pestaña Usuarios), pero `StatTile`/`HoverCard` no tienen
ninguna forma de comunicarse con `PortalShell` (el widget que sabe cuál
pestaña está activa) sin agregar un callback que atraviese varias capas de
widgets — es un cambio de arquitectura del shell compartido por los 8
portales, no una corrección de navegación puntual.

**Qué necesito de usted para desbloquear esto:** confirmar si quiere que
`StatTile` acepte un `onTap` opcional y que cada dashboard lo use para
cambiar de pestaña (yo propondría el mecanismo concreto una vez que
confirmes que sí lo quiere), o si preferís dejarlo así (son contadores
informativos, no tarjetas de exploración).

## 2. Dos brechas de modelo de datos, no de pantalla

- **`Group` no guarda el rol de cada integrante dentro del proyecto** — el
  pedido de `/proyectos/:id` incluye "rol dentro del proyecto (desde el
  Group asociado)" pero `Group.studentIds` es solo una lista de ids, sin
  rol. Mostrar esto requiere ampliar el modelo (`Map<String,String>
  memberRoles` o similar) — es un cambio de forma del JSON en Hive, no de
  `DbService` en sí, pero preferí no tocar `models.dart` con ese alcance
  sin luz verde explícita.
- **`Evidence` no tiene `projectId`** — el pedido de `/proyectos/:id`
  incluye "evidencias asociadas, si el rol tiene permiso"; hoy `Evidence`
  solo se relaciona con `donorId`, no hay forma de saber qué evidencias
  pertenecen a qué proyecto sin adivinar.

**Qué necesito de usted:** confirmar si quiere que amplíe estos dos modelos
en un commit aparte (frontend puro, no toca `DbService` ni el contrato
`DataStore`) antes de que empiece el backend, o si se deja para más
adelante.

## 3. Archivos no verificados en profundidad (quedaron fuera del recorrido real)

- `lib/views/lxd/lesson_editor.dart` — nunca se abrió en el navegador
  durante esta fase (sí compiló siempre, sí pasó `flutter analyze`, pero
  no se probó en vivo).
- `lib/views/admin/lab_ruta_editor.dart` — mismo caso: compila, pero no se
  ejercitó con clics reales.
- `lib/views/lxd/course_editor_view.dart` y
  `lib/views/lxd/course_tracking_view.dart` **sí** se verificaron en vivo
  (durante el ciclo de LXD, con datos reales) — se aclara para no
  confundirlos con los dos de arriba.

**Por qué:** son constructores/editores, no pantallas de exploración por
tarjetas (el foco explícito de este pedido). No encontré nada roto en
ellos durante la Fase 0, pero tampoco los certifico como "verificados en
vivo" — si quiere que se recorran igual, decímelo y los agrego a un ciclo
propio.

## 4. Detalles menores encontrados y reportados, no corregidos (fuera del alcance reportado)

- **`AppFooter` desborda en pantallas angostas** (confirmado con un test
  automatizado a 800px de ancho — ver `test/navigation_test.dart`, tuve
  que agrandar la superficie del test a 1440px para evitarlo). Es un
  problema de layout responsive preexistente, no de navegación — lo dejo
  señalado, no lo corregí porque no es lo que pediste en este prompt.
- **`CourseDetailView` sin `studentId`, con un rol no-estudiante mirando
  contenido** (p. ej. Empresa entrando a un curso desde "Contenido del
  laboratorio"): la barra de progreso muestra 0% y el botón de completar
  lección queda habilitado — no es el bug 1.2 (no hay ningún estudiante
  real cuya identidad se esté confundiendo), pero técnicamente un rol
  no-estudiante podría marcar una lección como completada para sí mismo,
  sin que eso tenga ningún efecto real visible en ningún lado. Bloquear
  esto exigiría restringir "completar lección" a roles tipo-estudiante en
  general, algo más amplio que el bug puntual que reportó la auditoría.
- **`_DonorEvidences`, `_showEvidenceDetail` (Admin) y
  `_showResourceDetail` (Recursos de Comunicaciones)** siguen abriendo un
  diálogo en vez de navegar a una ruta con ID — technically no cumplen el
  criterio "navega a una ruta, no a un modal genérico", pero ninguno de
  los tres corresponde a las 4 pantallas de detalle pedidas explícitamente
  (Proyecto/Curso/Laboratorio/Usuario), así que los dejé con prioridad
  baja.

## 5. Lo que SÍ quedó completo y verificado (no repetido acá — ver AUDITORIA_FRONT.md)

Los 8 portales cerraron su ciclo completo (implementar → analyze → test →
build --release → verificación funcional en vivo con Chrome headless +
CDP → auditoría actualizada → commit). El detalle punto por punto está en
`AUDITORIA_FRONT.md`, sección "Estado de ejecución".
