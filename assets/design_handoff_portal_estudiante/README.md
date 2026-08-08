# Handoff: Rediseño del Portal Estudiante — Enactus Colombia

## Resumen

Rediseño de cinco pantallas del portal estudiantil de Enactus Colombia (`lib/views/student/student_portal.dart` y `lib/views/shared/projects_directory_view.dart`): **Dashboard, Calendario, Mis Cursos, Ruta de Impacto y Directorio de Proyectos**, más el marco compartido (header, barra lateral y pie).

El objetivo fue subir la densidad visual y la legibilidad sin salirse de la marca: pasar de tarjetas grises apiladas con un único acento amarillo a un sistema donde **el color proviene del dato** — el ODS del proyecto, el laboratorio del curso — y donde el avance se lee de un vistazo.

## Sobre los archivos de este paquete

`Portal Estudiante.dc.html` es una **referencia de diseño construida en HTML**: un prototipo navegable que muestra la apariencia y el comportamiento buscados. **No es código para copiar a producción.**

La app real es **Flutter (Dart)**. La tarea es **recrear estas pantallas en Flutter**, usando los patrones, widgets y utilidades que ya existen en el repositorio — no portar el HTML ni introducir un motor de vistas nuevo.

Antes de escribir código, lee:

- `lib/views/student/student_portal.dart` — Dashboard, Calendario, Mis Cursos, Certificados y Perfil
- `lib/views/student/ruta_impacto_view.dart` — Ruta de Impacto y Laboratorios
- `lib/views/shared/projects_directory_view.dart` — Directorio de Proyectos
- `lib/widgets/portal_shell.dart` — el marco con las pestañas laterales
- `lib/widgets/common.dart`, `lib/widgets/charts.dart`, `lib/widgets/calendar_view.dart` — widgets reutilizables ya existentes (`TabBody`, `HoverCard`, `EmptyState`, `ProgressRing`, `ThinProgressBar`, `Entrance`, `SimpleBarChart`)
- `lib/utils/app_theme.dart` y `lib/utils/constants.dart` — tokens y constantes actuales
- `lib/models/models.dart` y `lib/services/seed_service.dart` — modelos y datos reales

Los tokens de este documento deben **añadirse a `app_theme.dart`** (o mapearse a los que ya existan allí), no incrustarse literalmente en cada widget. Los widgets compartidos (`HoverCard`, `ThinProgressBar`, `EmptyState`) deben **evolucionar** para adoptar el nuevo estilo, no duplicarse.

## Fidelidad

**Alta fidelidad.** Colores, tipografía, espaciado, radios e interacciones son finales.

## Marco compartido

Columna vertical de altura completa:

1. **Barra de bandera** — 4 px de alto, tres franjas horizontales iguales: `#FCD116`, `#003893`, `#CE1126`.
2. **Header** — `padding: 14px 32px`, fondo `#0D0F11`, borde inferior 1 px `#24282D`, fila con `gap: 22px`.
3. **Cuerpo** — barra lateral de 230 px + área de contenido (`padding: 34px 40px 60px`, columna con `gap: 26px`).

El header y la barra lateral **permanecen oscuros en ambos temas**, porque el logotipo de Enactus es blanco. Solo el área de contenido cambia con el tema.

### Header (izquierda a derecha)

| Componente | Especificación |
| --- | --- |
| Logo | `assets/media/mainlogo.png`, alto 52 px |
| Badge "Portal Estudiante" | fondo `#2D3E50`, texto `#F4C430`, `padding: 9px 18px`, radio 10 px, 14 px, peso 600 |
| *(espaciador flexible)* | |
| Buscador | 320×44 px, fondo `#1A1D21`, borde 1 px `#33383F`, radio 10 px, `padding: 0 14px`, `gap: 10px`. Ícono `search` 20 px `#8A9099`; input 14 px `#F5F5F2`. El placeholder cambia por pantalla: "Buscar curso o laboratorio" en Mis Cursos, "Buscar proyecto, comunidad u ODS" en el Directorio, "Buscar en el portal" en el resto |
| Botón de tema | 44×44 px, radio 10 px, fondo `#1A1D21`, borde 1 px `#33383F`, ícono 21 px `#B8BCBF`. Hover: borde y color → `#F4C430`. Ícono `light_mode` en tema oscuro, `dark_mode` en claro |
| Campana | ícono `notifications` 22 px `#B8BCBF`, con punto de 8 px `#CE1126` (borde 2 px `#0D0F11`) arriba a la derecha cuando hay notificaciones sin leer |
| Avatar + identidad | círculo 42 px `#F4C430`, inicial `#1A1400` 17 px peso 700; nombre 14 px peso 600 `#F5F5F2`, rol 12.5 px `#8A9099` |

### Barra lateral

- Ancho 230 px, fondo `#2D3E50`, `padding: 16px 0`, `gap: 2px`.
- **Ítem inactivo**: `padding: 12px`, `margin: 2px 8px`, radio 8 px, borde izquierdo 3 px transparente, color `#C3C9D0`, ícono 21 px, etiqueta 13.5 px, `gap: 12px`.
- **Hover**: fondo `rgba(255,255,255,.06)`.
- **Activo**: borde izquierdo 3 px `#F4C430`, fondo `rgba(244,196,48,.12)`, texto `#F4C430`, peso 600.
- Al fondo, separado por una línea `rgba(255,255,255,.09)` con `padding-top: 14px` y `margin: 8px 16px 0`: la universidad y el equipo del estudiante en 11.5 px `#8FA0B2`, `line-height: 1.5`.

Ítems (los mismos que ya construye `StudentPortal`, respetando que un estudiante de Open Learning no ve Laboratorios, Ruta de Impacto, Directorio ni Foro):

`dashboard` Dashboard · `calendar_month` Calendario · `school` Mis Cursos · `science` Laboratorios · `emoji_events` Ruta de Impacto · `explore` Directorio de Proyectos · `forum` Foro · `workspace_premium` Certificados · `person` Mi Perfil

### Encabezado de pantalla (patrón repetido en las cinco)

- **Etiqueta superior**: punto de 7 px `#4C9F38` con animación `glow` + texto contextual en 12 px, `letter-spacing: .16em`, mayúsculas, peso 600, `--text3`, `gap: 9px`.
- **Título**: Knockout 58 px, `line-height: .94`, `letter-spacing: .045em`, mayúsculas, `--gold-ink`.
- **Bajada**: 15.5 px, `--text2`, `max-width: 52ch`, `text-wrap: pretty`, `margin-top: 12px`.

### Pie de página

`margin-top: 18px`, `padding-top: 22px`, borde superior 1 px `--border`, fila con `space-between` y wrap, `gap: 24px`.

- Izquierda: barra de bandera **vertical** de 4 px de ancho y 22 px de alto (radio 2 px) + "Entidad sin ánimo de lucro. Fundada en 2021. Bogotá D. C., Colombia." en 12.5 px `--text3`.
- Derecha: enlaces 12.5 px `--text3`, hover `--gold-ink`, `gap: 18px`: Facebook (`https://www.facebook.com/enactuscolombia/`), Instagram (`https://www.instagram.com/enactuscolombia/`), LinkedIn (`http://linkedin.com/company/enactuscolombia/`).

---

## Pantalla 1 — Dashboard

**Propósito.** El estudiante ve de un vistazo su avance, qué debe hacer a continuación y cómo va su proyecto.

**Encabezado.** Etiqueta con la semana en curso. Título: "Hola, <primer nombre>". Bajada: "Proyecto <nombre> · Etapa <etapa> · <universidad>", o "Aún no tienes proyecto asignado".

**Tarjeta de progreso general** (a la derecha del encabezado): `padding: 20px 26px`, fondo `--surface`, borde 1 px `--border`, radio 16 px, fila con `gap: 20px`.

- Anillo de 96 px hecho con `conic-gradient(#F4C430 0 <pct>%, var(--surface2) <pct>% 100%)`, con un círculo interior a `inset: 10px` del color `--surface`; en el centro, el porcentaje en Knockout 30 px.
- Al lado: "Progreso general" 13 px `--text3`; "<hechas> de <total> lecciones" 15 px peso 600 `--text`; "<n> cursos activos · <n> laboratorios" 12.5 px `--text3`.

El porcentaje es **lecciones completadas sobre lecciones totales de todos los cursos**, no el promedio de porcentajes.

**Cuerpo — grilla de dos columnas `minmax(0,1.55fr) / minmax(0,1fr)`, `gap: 20px`, alineadas arriba.**

### Columna izquierda

**a) "Continúa donde ibas"** — tarjeta con radio 18 px, borde 1 px `--border`, animación `fadeUp`.

- Cabecera `padding: 26px 28px` con fondo del **color del laboratorio del curso** + patrón `repeating-linear-gradient(115deg, rgba(255,255,255,.14) 0 2px, transparent 2px 13px)`. Dentro: rótulo "CONTINÚA DONDE IBAS" 12 px `letter-spacing: .16em` `rgba(255,255,255,.85)` peso 600; nombre del curso en Knockout 38 px mayúsculas blanco; laboratorio en 13.5 px `rgba(255,255,255,.88)`.
- Cuerpo `padding: 20px 28px 24px`, fila con `gap: 24px`: barra de progreso (alto 7 px, radio 4 px, fondo `--surface2`, relleno del color del laboratorio) con leyendas "Siguiente: <lección>" y "<hechas> de <total>" en 12.5 px `--text3`; y botón **Continuar** (`padding: 13px 22px`, radio 10 px, fondo `#F4C430`, texto `#1A1400`, peso 600, ícono `play_arrow` 19 px; hover `#FFD700` + sombra `0 8px 22px rgba(244,196,48,.28)` + `translateY(-1px)`).

**b) "Progreso por curso"** — tarjeta `padding: 24px 26px`, radio 18 px. Título en Knockout 24 px mayúsculas. Una fila por curso, `gap: 16px`: nombre 14 px con elipsis + "hechas/total" 12.5 px `--text3`, y barra de 7 px del color del laboratorio.

Reemplaza el `SimpleBarChart` actual: barras horizontales con el nombre completo del curso legible, en vez de barras verticales con el nombre truncado a dos palabras.

### Columna derecha

**c) "Pendientes"** — tarjeta `padding: 22px 24px`, radio 18 px. Cada ítem: `padding: 13px 14px`, radio 11 px, fondo `--surface2`, **borde izquierdo 3 px del color de su urgencia**, ícono 19 px, título 13.5 px `--text`, meta 12 px `--text3`, `gap: 12px`.

Prioridad y color: entrega vencida `#CE1126` (`warning`) → mentoría por confirmar `#F4C430` (`diversity_3`) → curso a continuar, color del laboratorio (`play_circle`) → entregable de equipo `#8A9099` (`description`). Máximo 6.

**d) "Actividad reciente"** — última entrega calificada: cuadro de 56 px radio 14 px fondo `--gold-soft` con la nota en Knockout 26 px `--gold-ink`; al lado el nombre de la tarea 13.5 px peso 600 y "Calificado el <fecha> · <docente>" 12 px `--text3`. Debajo, separado por línea `--border`, la retroalimentación entre comillas en 13 px `line-height: 1.55` `--text2`.

**e) "Tu proyecto"** — rótulo "TU PROYECTO" 12 px mayúsculas `--text3`; nombre en Knockout 30 px; el **riel de 6 etapas** (mismo componente del Directorio, ver Pantalla 5) con la etapa actual en el color del ODS principal; leyendas "Etapa N de 6 · <etapa>" y "Sigue: <siguiente>"; y los indicadores de impacto del proyecto en 13 px `--text2`.

---

## Pantalla 2 — Calendario

**Propósito.** Ver las sesiones sincrónicas de los cursos y los eventos de la Ruta de Impacto.

**Encabezado.** Etiqueta con el mes y año. Título "Calendario". Bajada: "Sesiones sincrónicas de tus cursos y eventos de tu Ruta de Impacto."

**Leyenda** (a la derecha del encabezado): una entrada por tipo de evento, cuadrito de 10 px radio 3 px + etiqueta 12.5 px `--text2`, `gap: 18px`.

**Grilla de dos columnas `minmax(0,2.1fr) / minmax(0,1fr)`, `gap: 22px`.**

**a) Mes** — tarjeta `padding: 22px 24px 24px`, radio 18 px.

- Cabecera de días: grilla de 7 columnas, `gap: 8px`, etiquetas 11.5 px `letter-spacing: .14em` mayúsculas peso 600 `--text3`, centradas. **La semana empieza en lunes.**
- Celdas: grilla de 7 columnas, `gap: 8px`, `min-height: 96px`, radio 11 px, `padding: 9px 9px 8px`, fondo `--surface2`. Los días de relleno del mes anterior/siguiente van transparentes y vacíos.
- Número del día alineado a la derecha: cuadro de 22 px radio 7 px, 12 px `--text3`. **Hoy**: celda con fondo `--gold-soft` y borde 1 px `--gold-ink`; número con fondo `--gold-ink`, texto `--bg`, peso 700.
- Eventos: chips de `padding: 4px 7px`, radio 6 px, 10.5 px, `line-height: 1.3`, texto blanco, fondo del color del tipo, con elipsis. Máximo 2 visibles por celda.

**b) "Próximos eventos"** — tarjeta `padding: 22px 24px`, radio 18 px, título Knockout 24 px. Cada entrada, `gap: 14px`: bloque de fecha de 52 px (`padding: 8px 0`, radio 11 px, fondo `--surface2`) con el día en Knockout 22 px del color del tipo y el día de la semana en 10.5 px `letter-spacing: .1em` mayúsculas `--text3`; al lado, el título 13.5 px y "<hora> · <persona>" 12 px `--text3`.

**Origen de los eventos.** Deben salir de `calendarEventsFor(student)`. En el prototipo se construyeron a partir de: los `deadline` de las fases de la Ruta de Impacto (reales) y los campos `availability` de los LXD del estudiante (reales: Carlos Rodríguez "Martes y jueves 6-8 pm", Sofía Ramírez "Miércoles 4-6 pm"). **Confirma con el equipo si esa es la fuente correcta** antes de implementarlo así.

---

## Pantalla 3 — Mis Cursos

**Propósito.** Ver y retomar los cursos asignados.

**Encabezado.** Etiqueta con los laboratorios del estudiante. Título "Mis Cursos". Bajada: "Cursos de laboratorio asignados por tu administrador, más la ruta de preparación de tu equipo para National Expo."

A diferencia de la implementación actual, esta pantalla **sí incluye el curso `isRutaExpo`**, con el color amarillo de marca y el ícono `emoji_events`, porque es el trabajo real del equipo. Si se decide mantenerlo fuera, quítalo del filtro y no de la maqueta.

**Grilla** responsiva: `minmax(392px, 1fr)` con auto-fill, `gap: 20px`.

**Tarjeta**: fondo `--surface`, borde 1 px `--border`, radio 18 px, contenido recortado, columna flexible.
Transición `transform .2s, border-color .2s, box-shadow .2s`. **Hover**: `translateY(-5px)`, sombra `--shadow`, borde del color del laboratorio. **Entrada**: `fadeUp` 450 ms escalonada 55 ms por índice.

- **Cabecera** `padding: 20px 22px 18px`, fondo del color del laboratorio + el patrón de rayas de 115°. Dentro, fila con `gap: 14px`: cuadro de 40 px radio 11 px `rgba(10,12,14,.42)` con el ícono del curso 22 px blanco; al lado, nombre en Knockout 27 px `line-height: 1.02` `letter-spacing: .04em` mayúsculas blanco, y laboratorio 12.5 px `rgba(255,255,255,.88)`.
- **Cuerpo** `padding: 18px 22px 20px`, columna con `gap: 14px`: descripción 14 px `line-height: 1.5` `--text2`; fila de metadatos; espaciador flexible; progreso; pie.
- **Metadatos** (chips con wrap, `gap: 7px`): `padding: 5px 11px`, radio 8 px, fondo `--surface2`, borde 1 px `--border`, 11.5 px `--text2`, con ícono de 14 px `--text3`. Se muestran solo los que existan: `view_module` módulos · `play_lesson` lecciones · `signal_cellular_alt` nivel · `schedule` horas estimadas · `workspace_premium` "Certificado" si `generatesCertificate`.
- **Progreso**: leyendas "<hechas> de <total> lecciones" y el porcentaje en 12 px `--text3`; barra de 7 px radio 4 px, fondo `--surface2`, relleno del color del laboratorio.
- **Pie**: separado por línea 1 px `--border` con `padding-top: 14px`. Izquierda: "Docente: <nombre>" (o "Trabajo en equipo" para la Ruta Expo) 12.5 px `--text3` con elipsis. Derecha: botón **Continuar** / **Comenzar** — `padding: 9px 16px`, radio 9 px, fondo `--gold-soft`, texto `--gold-ink` 13 px peso 600, con `arrow_forward` 17 px.

Los detalles que hoy aparecen solo en hover (docente, duración, botón) **quedan siempre visibles**: información básica no debería requerir descubrimiento.

---

## Pantalla 4 — Ruta de Impacto

**Propósito.** Ver las fases del laboratorio, sus objetivos y módulos, y lo que falta para National Expo.

**Encabezado.** Etiqueta con equipo y universidad. Título "Ruta de Impacto". Bajada: "Las fases de tu laboratorio, sus objetivos y lo que falta para llegar a National Expo."

**Selector de laboratorio** — un chip por laboratorio del estudiante: `padding: 11px 18px`, radio 999 px, 13.5 px peso 500, `gap: 10px`, con un cuadrito de 9 px radio 3 px del color del laboratorio. Inactivo: fondo `--surface`, texto `--text2`, borde `--border`. Activo: fondo `--gold-soft`, texto `--gold-ink`, borde `--gold-ink`. Hover `translateY(-1px)`.

**Grilla de dos columnas `minmax(0,1.6fr) / minmax(0,1fr)`, `gap: 22px`.**

### a) Camino de fases (columna izquierda)

Cada fase es una fila con `gap: 20px`:

- **Riel** de 46 px de ancho: círculo de 46 px con el número de fase en Knockout 22 px, y debajo una línea vertical de 2 px `--border` que se estira hasta la siguiente fase.
  - Fase activa: fondo y borde del color del laboratorio, número blanco.
  - Resto: fondo `--surface`, borde 2 px `--border`, número `--text3`.
- **Tarjeta** (`padding: 20px 22px`, radio 16 px, fondo `--surface`, borde 1 px — del color del laboratorio si es la fase activa, si no `--border`), con `padding-bottom: 22px` en la fila:
  - Título en Knockout 27 px mayúsculas + **chip de estado** a la derecha: `padding: 6px 12px`, radio 999 px, 11.5 px peso 600, con ícono de 14 px.
    - Vencida: fondo `rgba(206,17,38,.16)`, texto `#FF8A9B`, ícono `warning`.
    - En curso: fondo `--gold-soft`, texto `--gold-ink`, ícono `play_circle`.
    - Sin abrir: fondo `--surface2`, texto `--text3`, ícono `lock`.
  - Descripción 13.5 px `line-height: 1.5` `--text2`.
  - **Objetivos** (si los hay): rótulo "OBJETIVOS" 11.5 px `letter-spacing: .14em` mayúsculas `--text3` peso 600; cada objetivo con ícono 17 px (`check_circle` `#4C9F38` si está cumplido, `radio_button_unchecked` `--text3` si no), texto 13.5 px `--text2` y la categoría del objetivo en 11.5 px `--text3` debajo.
  - **Módulos** (si los hay): filas de `padding: 12px 14px`, radio 11 px, fondo `--surface2`, `gap: 12px`. Cuadro de 30 px radio 9 px con el ícono del módulo (`menu_book` para módulo de contenido, `diversity_3` para módulo de mentoría) — completo: fondo `rgba(76,159,56,.16)` ícono `#4C9F38`; pendiente: fondo `--gold-soft` ícono `--gold-ink`. Título 13.5 px con elipsis, meta 11.5 px `--text3`, y el estado a la derecha en 12 px peso 600.
  - **Fecha de entrega** (si la hay): separada por línea `--border` con `padding-top: 14px`, ícono `event` 17 px + "Entrega: <fecha>" en 12.5 px `--text3`, o "Entrega vencida: <fecha>" en `#FF8A9B`.

### b) Tarjeta National Expo (columna derecha)

- Cabecera `padding: 22px 24px` con fondo `#F4C430` + patrón de rayas `rgba(255,255,255,.2)`. Rótulo "META DEL AÑO" 11.5 px `letter-spacing: .16em` `rgba(26,20,0,.7)` peso 700; título "National Expo" en Knockout 32 px `#1A1400`.
- Cuerpo `padding: 20px 24px 24px`: "Checklist del equipo" 12.5 px `--text3` + contador "<hechos>/7" en Knockout 22 px `--gold-ink`; barra de 7 px radio 4 px con relleno `#F4C430`; y los 7 ítems con ícono 19 px (`check_circle` `#4C9F38` o `radio_button_unchecked` `--text3`) y texto 13 px (`--text2` si está hecho, `--text3` si no), `gap: 10px`.

Los ítems son los del `ExpoChecklist` sembrado por grupo.

---

## Pantalla 5 — Directorio de Proyectos

**Propósito.** Explorar todos los proyectos activos de la red, filtrar por etapa y buscar.

**Encabezado.** Etiqueta "COMUNIDAD ENACTUS COLOMBIA". Título "Directorio de Proyectos". Bajada: "Todos los proyectos activos de la red. Filtra por etapa, explora los ODS que atienden y descubre qué está construyendo el resto de los equipos."

**Barra de estadísticas** (grilla de 4 columnas iguales, `gap: 12px`, ancho mínimo 440 px): tarjeta con fondo `--surface`, borde 1 px `--border`, radio 14 px, `padding: 16px 18px`; número en Knockout 40 px (`--gold-ink` la primera, `--text` las demás); etiqueta 12.5 px `--text3`.

Las cuatro métricas se **calculan de los datos**: proyectos activos · universidades distintas · ODS distintos · proyectos en etapa "National Expo". Al montar, los cuatro números suben de 0 a su valor en 900 ms con easing *ease-out cubic* (`1 - (1-t)³`).

**Filtros de etapa** — chips con wrap, `gap: 9px`: `padding: 10px 16px`, radio 999 px, 13.5 px peso 500, transición `all .16s`, hover `translateY(-1px)`. Inactivo: fondo `--surface`, texto `--text2`, borde `--border`. Activo: fondo `--gold-soft`, texto `--gold-ink`, borde `--gold-ink`. Cada chip lleva un contador: `min-width: 22px`, `padding: 1px 7px`, radio 999 px, 11.5 px peso 700 — inactivo fondo `--surface2` texto `--text3`, activo fondo `--gold-ink` texto `--bg`. El contador es sobre el total, no sobre el resultado filtrado.

Etapas, en orden: **Ideación · Validación · Prototipo · Piloto · Escalamiento · National Expo**

**Grilla de tarjetas**: `minmax(348px, 1fr)` con auto-fill, `gap: 20px`. Tarjeta con fondo `--surface`, borde 1 px `--border`, radio 18 px, contenido recortado. Transición y hover iguales a los de Mis Cursos (elevación, sombra, borde del color del ODS). Entrada `fadeUp` escalonada 55 ms.

- **Portada de 104 px**: fondo del color del **ODS principal**; encima el patrón de rayas de 115°; encima un velo `linear-gradient(180deg, transparent 40%, var(--veil) 100%)`; el número del ODS en Knockout 82 px `rgba(255,255,255,.32)` anclado a `right: 14px; bottom: -16px` (recortado por el borde); y la píldora de etapa arriba a la izquierda (`left: 16px; top: 16px`): ícono `flag` 15 px + texto 12 px peso 600 blanco, `padding: 6px 12px 6px 9px`, radio 999 px, fondo `rgba(10,12,14,.55)`, `backdrop-filter: blur(6px)`.
- **Cuerpo** `padding: 18px 20px 20px`, `gap: 13px`: nombre en Knockout 29 px mayúsculas; descripción 14 px `line-height: 1.5` `--text2`.
- **Riel de 6 etapas**: seis segmentos iguales, `gap: 4px`, alto 5 px, radio 3 px — superadas `--gold-soft`, actual el color del ODS, futuras `--border`. Debajo, 11.5 px `--text3`: "Etapa N de 6" y "Sigue: <siguiente>" (o "Etapa final").
- **Comunidad**: ícono `location_on` 17 px `--text3` + texto 13 px `--text2`.
- **Etiquetas de ODS**: `padding: 5px 11px 5px 8px`, radio 8 px, fondo `--surface2`, borde 1 px `--border`, 11.5 px `--text2`, con cuadrito de 9 px radio 2 px del color oficial del ODS. Texto completo: "ODS 6: Agua limpia y saneamiento".
- **Pie**, tras un separador de 1 px: ícono `groups` 17 px + "<equipo> · <universidad> · <n> estudiantes" 12.5 px `--text3` con elipsis; y a la derecha un cuadro de 32 px radio 9 px fondo `--gold-soft` con `arrow_forward` 18 px `--gold-ink`.

---

## Estados vacíos

Un único componente, con contenido distinto por pantalla. Caja centrada: `padding: 70px 24px`, fondo `--surface`, borde **punteado** 1 px `--border`, radio 20 px, `gap: 16px`.

- Ícono: caja de 76 px radio 22 px fondo `--gold-soft`, glifo 36 px `--gold-ink`.
- Título: Knockout 38 px mayúsculas `--text`.
- Texto: 15 px `line-height: 1.55` `--text2`, `max-width: 46ch`.
- Dos botones (`padding: 14px 24px`, radio 10 px, 14 px peso 600, ícono 19 px, `gap: 9px`): primario amarillo `#F4C430`/`#1A1400` con la acción de recuperación, y secundario transparente con borde `--gold-ink` ("Escribir a mi administrador").

| Pantalla | Ícono | Título | Texto | Acción primaria |
| --- | --- | --- | --- | --- |
| Dashboard | `school` | Todo por empezar | "Aún no tienes cursos asignados. Cuando tu administrador te asigne uno, tu progreso aparecerá aquí." | Actualizar |
| Mis Cursos (sin cursos) | `school` | Sin cursos asignados | "Aún no tienes cursos asignados por tu administrador." | Limpiar búsqueda |
| Mis Cursos (búsqueda vacía) | `school` | Sin cursos asignados | "Ningún curso coincide con tu búsqueda. Prueba con otro término." | Limpiar búsqueda |
| Ruta de Impacto | `route` | Laboratorio sin fases | "El <laboratorio> todavía no ha publicado sus fases. Tu LXD las abrirá cuando el contenido esté listo." | Ver otro laboratorio |
| Calendario | `event_busy` | Agenda despejada | "No tienes sesiones ni entregas programadas este mes." | Actualizar |
| Directorio (sin proyectos) | `lightbulb` | Aún no hay proyectos aquí | "Todavía no se ha publicado ningún proyecto en la comunidad. Cuando tu equipo registre el suyo, aparecerá aquí para toda la red." | Ver todas las etapas |
| Directorio (filtro vacío) | `lightbulb` | Aún no hay proyectos aquí | "Ningún proyecto coincide con este filtro. Prueba con otra etapa o limpia la búsqueda." | Ver todas las etapas |

## Interacciones y comportamiento

| Interacción | Comportamiento |
| --- | --- |
| Barra lateral | Cambia de pantalla; el ítem activo se marca con el borde izquierdo amarillo. |
| Chip de etapa (Directorio) | Filtra la grilla. "Todas las etapas" limpia el filtro. Solo uno activo. |
| Chip de laboratorio (Ruta) | Cambia el conjunto de fases mostrado. |
| Buscador | Filtra en vivo, sin debounce, sobre la pantalla actual. Directorio: nombre + descripción + comunidad + etapa + ODS. Mis Cursos: nombre + laboratorio + descripción + docente. Coincidencia por substring, sin distinguir mayúsculas. |
| Hover en tarjeta | `translateY(-5px)`, sombra `--shadow` y borde teñido del color del ODS o del laboratorio. |
| Click en tarjeta | Navega al detalle (rutas existentes: `CourseDetailView`, detalle de proyecto). |
| Botón de tema | Alterna claro/oscuro solo en el área de contenido. |
| Montaje | Contadores animan 0 → valor (900 ms, ease-out cubic); tarjetas y fases entran escalonadas (55 ms y 70 ms por índice). |

## Estado

- `screen` — pantalla activa.
- `stage` — etapa filtrada en el Directorio; `'todas'` por defecto.
- `lab` — laboratorio activo en la Ruta de Impacto; el primero del estudiante por defecto.
- `query` — texto del buscador.
- `theme` — `dark` | `light`; oscuro por defecto.

Todo lo demás se deriva de `DataProvider` (`coursesForStudent`, `courseProgress`, `overallProgress`, `calendarEventsFor`, `projectById`, `groupById`) con sus estados de carga y error según el patrón que ya use el repo.

## Tokens de diseño

### Colores de marca (constantes en ambos temas)

| Token | Valor |
| --- | --- |
| Amarillo Enactus | `#F4C430` |
| Amarillo hover | `#FFD700` |
| Tinta sobre amarillo | `#1A1400` |
| Azul marino (sidebar / badge) | `#2D3E50` |
| Fondo del header | `#0D0F11` |
| Borde del header | `#24282D` |
| Texto del sidebar | `#C3C9D0` |
| Texto secundario del sidebar | `#8FA0B2` |
| Éxito | `#4C9F38` |
| Alerta / vencido | `#CE1126` (texto sobre oscuro: `#FF8A9B`) |
| Bandera de Colombia | `#FCD116`, `#003893`, `#CE1126` |

### Tokens por tema (solo afectan al área de contenido)

| Token | Oscuro | Claro |
| --- | --- | --- |
| `--bg` | `#111315` | `#F2F2EC` |
| `--surface` | `#1A1D21` | `#FFFFFF` |
| `--surface2` | `#22262B` | `#F0F0E9` |
| `--border` | `#33383F` | `#DEDED4` |
| `--text` | `#F5F5F2` | `#15181B` |
| `--text2` | `#B8BCBF` | `#4C525A` |
| `--text3` | `#8A9099` | `#787F88` |
| `--gold-ink` | `#F4C430` | `#8A6A00` |
| `--gold-soft` | `rgba(244,196,48,.14)` | `rgba(244,196,48,.24)` |
| `--shadow` | `0 18px 40px rgba(0,0,0,.5)` | `0 16px 36px rgba(20,25,35,.14)` |
| `--veil` | `rgba(0,0,0,.28)` | `rgba(0,0,0,.22)` |

En tema claro el amarillo se oscurece a `#8A6A00` para el texto — `#F4C430` sobre blanco no alcanza contraste AA.

### Colores oficiales de los ODS

```
1 #E5243B   2 #DDA63A   3 #4C9F38   4 #C5192D   5 #FF3A21   6 #26BDE2
7 #FCC30B   8 #A21942   9 #FD6925  10 #DD1367  11 #FD9D24  12 #BF8B2E
13 #3F7E44  14 #0A97D9  15 #56C02B  16 #00689D  17 #19486A
```

### Color por laboratorio

Derivado de la paleta ODS, para que cada laboratorio sea reconocible a lo largo del portal. **Esta asignación la propuso el diseño; confírmala con el equipo de Enactus.**

| Laboratorio | Color |
| --- | --- |
| IA y Tecnología | `#FD6925` (ODS 9) |
| Agua | `#26BDE2` (ODS 6) |
| Energía | `#FCC30B` (ODS 7) |
| Impacto | `#DD1367` (ODS 10) |
| Emprendimiento | `#A21942` (ODS 8) |
| Agricultura | `#56C02B` (ODS 15) |
| Ruta National Expo | `#F4C430` (amarillo de marca) |

### Tipografía

| Uso | Fuente | Tamaño | Detalle |
| --- | --- | --- | --- |
| Título de pantalla | Knockout 92 | 58 px | `line-height: .94`, `letter-spacing: .045em`, mayúsculas |
| Marca de agua del ODS | Knockout 92 | 82 px | `rgba(255,255,255,.32)` |
| Cifras de estadística | Knockout 92 | 40 px | `line-height: 1`, `letter-spacing: .03em` |
| Título de estado vacío | Knockout 92 | 38 px | `letter-spacing: .045em`, mayúsculas |
| Curso destacado | Knockout 92 | 38 px | mayúsculas |
| National Expo | Knockout 92 | 32 px | mayúsculas |
| Proyecto (tarjeta lateral) | Knockout 92 | 30 px | mayúsculas |
| Porcentaje del anillo | Knockout 92 | 30 px | |
| Nombre de proyecto | Knockout 92 | 29 px | `line-height: 1`, `letter-spacing: .045em`, mayúsculas |
| Nombre de curso / fase | Knockout 92 | 27 px | mayúsculas |
| Título de sección | Knockout 92 | 24 px | `letter-spacing: .045em`, mayúsculas |
| Nota, día del calendario | Knockout 92 | 22–26 px | |
| Bajada | Space Grotesk | 15.5 px | |
| Cuerpo de tarjeta | Space Grotesk | 14 px | `line-height: 1.5` |
| Nav, chips, listas | Space Grotesk | 13.5 px | |
| Metadatos, pie | Space Grotesk | 12.5 px | |
| Etiquetas de ODS, rieles | Space Grotesk | 11.5 px | |
| Rótulo superior | Space Grotesk | 12 px | `letter-spacing: .16em`, mayúsculas, peso 600 |
| Chip de evento | Space Grotesk | 10.5 px | `line-height: 1.3` |

### Escala de espaciado

`4 · 7 · 9 · 12 · 13 · 14 · 16 · 18 · 20 · 22 · 26 · 32 · 34 · 40 px`

### Radios

`2 px` (cuadrito de ODS) · `3 px` (segmento del riel) · `6 px` (chip de evento) · `7 px` (número del día) · `8 px` (nav, etiqueta de ODS) · `9 px` (botón de flecha, ícono de módulo) · `10 px` (buscador, botones) · `11 px` (celda del calendario, pendiente, ícono de curso) · `14 px` (tarjeta de estadística, nota) · `16 px` (tarjeta de progreso, fase) · `18 px` (tarjeta de contenido) · `20 px` (estado vacío) · `22 px` (caja de ícono) · `999 px` (chips y píldoras)

### Animaciones

| Nombre | Especificación |
| --- | --- |
| `fadeUp` | opacidad 0→1 + `translateY(14px)`→0, 450 ms; escalonada 55 ms (tarjetas) o 70 ms (fases) |
| `glow` | pulso de sombra `0 0 0 0 rgba(244,196,48,.55)` → `0 0 0 5px rgba(244,196,48,0)`, 2.4 s en bucle |
| Conteo | 0 → valor en 900 ms, ease-out cubic |
| Hover de tarjeta | `transform`, `border-color`, `box-shadow` a 200 ms `ease` |
| Hover de chip / botón | `all` a 160 ms / 150 ms `ease` |

El repo ya tiene `Entrance` para la entrada escalonada y `HoverBuilder` para los estados de hover: reúsalos.

## Recursos

Ya presentes en el repositorio, bajo `assets/media/`:

- `Knockout-92.otf` — titulares
- `SpaceGrotesk-Variable.ttf` — texto
- `mainlogo.png` — logotipo

Iconografía: **Material Symbols Rounded** (en Flutter, los `Icons` redondeados equivalentes). Glifos usados: `search`, `light_mode`, `dark_mode`, `notifications`, `dashboard`, `calendar_month`, `school`, `science`, `emoji_events`, `explore`, `forum`, `workspace_premium`, `person`, `flag`, `location_on`, `groups`, `arrow_forward`, `lightbulb`, `restart_alt`, `mail`, `play_arrow`, `play_circle`, `play_lesson`, `view_module`, `signal_cellular_alt`, `schedule`, `smart_toy`, `insights`, `menu_book`, `diversity_3`, `description`, `warning`, `lock`, `check_circle`, `radio_button_unchecked`, `event`, `event_busy`, `route`, `design_services`.

**No se usan imágenes de curso ni de proyecto.** Las portadas son color plano + patrón de rayas + marca de agua, precisamente para no depender de fotografías que los equipos aún no han subido.

## Archivos de este paquete

- `Portal Estudiante.dc.html` — el prototipo navegable. Ábrelo en un navegador y usa la barra lateral para recorrer las cinco pantallas.
- `support.js`, `assets/media/*` — archivos de apoyo para que el prototipo abra sin conexión.

## Datos

Los datos del prototipo salen de `seed_service.dart`: **Sara Nieto** (est1, Universidad de los Andes, Equipo AquaVida), sus cursos `crs_ia_1`, `crs_impacto_1` y `crs_expo_p1` con su progreso real, las fases de `lab_ia`, el `ExpoChecklist` de `grp1`, la entrega calificada `sub1` y los proyectos `prj1` y `prj2`.

**Lo que no es real y no debe llevarse a producción:**

- Los cinco proyectos extra del Directorio (Manglar Vivo, Raíz Café, Semilla Digital, Tejido Wayúu, Cosecha Urbana) — relleno para mostrar la variedad de colores de ODS y de etapas.
- Los horarios del calendario, derivados de los campos `availability` de los LXD.
- La asignación de color por laboratorio.
