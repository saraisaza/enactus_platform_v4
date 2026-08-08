# Handoff: Rediseño del Directorio de Proyectos — Enactus Colombia

## Resumen

Rediseño completo de la pantalla **Directorio de Proyectos** del portal estudiantil de Enactus Colombia (`lib/views/shared/projects_directory_view.dart`). La pantalla lista todos los proyectos activos de la red nacional; el estudiante los filtra por etapa, los busca por texto y explora qué ODS atiende cada uno.

El objetivo del rediseño fue subir la densidad visual y la legibilidad sin salirse de la marca: pasar de filas grises apiladas con un único acento amarillo a una grilla de tarjetas donde **el color proviene del dato** (el ODS principal de cada proyecto) y el avance se lee de un vistazo.

## Sobre los archivos de este paquete

`Directorio de Proyectos.dc.html` es una **referencia de diseño construida en HTML**: un prototipo que muestra la apariencia y el comportamiento buscados. **No es código para copiar a producción.**

La app real es **Flutter (Dart)**. La tarea es **recrear este diseño en Flutter**, usando los patrones, widgets y utilidades que ya existen en el repositorio — no portar el HTML ni introducir un motor de vistas nuevo.

Antes de escribir código, lee:

- `lib/views/shared/projects_directory_view.dart` — la pantalla actual que se reemplaza
- `lib/utils/app_theme.dart` — tokens de color, tipografía y tema existentes
- `lib/utils/constants.dart` — constantes de marca y espaciado
- `lib/models/models.dart` — el modelo `Project` y sus campos reales
- `lib/services/seed_service.dart` — los datos sembrados actuales

Los tokens de este documento deben **añadirse a `app_theme.dart`** (o mapearse a los que ya existan allí), no incrustarse literalmente en el widget.

## Fidelidad

**Alta fidelidad.** Colores, tipografía, espaciado, radios e interacciones son finales. Reprodúcelos con precisión usando los widgets y el tema del proyecto.

## Pantalla

### Nombre
Directorio de Proyectos

### Propósito
El estudiante explora todos los proyectos activos de la red Enactus Colombia, filtra por etapa del proyecto, busca por texto libre y entra al detalle de un proyecto.

### Layout general

Columna vertical de altura completa:

1. **Barra de bandera** — 4 px de alto, tres franjas horizontales de igual ancho: `#FCD116`, `#003893`, `#CE1126`.
2. **Header** — alto fijo por contenido, `padding: 14px 32px`, fondo `#0D0F11`, borde inferior 1 px `#24282D`, elementos en fila con `gap: 22px`.
3. **Cuerpo** — fila de dos columnas que ocupa el resto del alto:
   - **Sidebar** — 230 px de ancho fijo.
   - **Main** — resto del ancho, `padding: 34px 40px 60px`, columna con `gap: 26px`.

El header y el sidebar **permanecen oscuros en ambos temas** (claro y oscuro), porque el logotipo de Enactus es blanco. Solo el área `main` cambia con el tema.

### Header — componentes (izquierda a derecha)

| Componente | Especificación |
| --- | --- |
| Logo | `assets/media/mainlogo.png`, alto 52 px, ancho automático |
| Badge "Portal Estudiante" | fondo `#2D3E50`, texto `#F4C430`, `padding: 9px 18px`, radio 10 px, 14 px, peso 600, `letter-spacing: .01em` |
| *(espaciador flexible)* | |
| Buscador | ancho 320 px, alto 44 px, fondo `#1A1D21`, borde 1 px `#33383F`, radio 10 px, `padding: 0 14px`, `gap: 10px`. Ícono `search` 20 px `#8A9099`. Input 14 px `#F5F5F2`, sin borde ni outline. Placeholder `#8A9099`: "Buscar proyecto, comunidad u ODS" |
| Botón de tema | 44×44 px, radio 10 px, fondo `#1A1D21`, borde 1 px `#33383F`, ícono 21 px `#B8BCBF`. Hover: borde y color → `#F4C430`. Ícono `light_mode` en tema oscuro, `dark_mode` en tema claro |
| Campana | ícono `notifications` 22 px `#B8BCBF` |
| Avatar + identidad | círculo 42 px, fondo `#F4C430`, inicial `#1A1400` 17 px peso 700. Al lado: nombre 14 px peso 600 `#F5F5F2`, rol 12.5 px `#8A9099`, `line-height: 1.25`, `gap: 10px` |

### Sidebar

- Ancho 230 px, fondo `#2D3E50`, `padding: 16px 0`, `gap: 2px` entre ítems.
- **Ítem inactivo**: `padding: 12px`, `margin: 2px 8px`, radio 8 px, borde izquierdo 3 px transparente, color `#C3C9D0`, ícono 21 px, etiqueta 13.5 px, `gap: 12px`.
- **Hover**: fondo `rgba(255,255,255,.05)`, borde izquierdo `rgba(244,196,48,.55)`, texto `#FFFFFF`.
- **Activo**: borde izquierdo 3 px `#F4C430`, fondo `rgba(244,196,48,.12)`, texto `#F4C430`, peso 600.

Ítems, en orden, con su ícono de Material Symbols Rounded:

`dashboard` Dashboard · `calendar_month` Calendario · `school` Mis Cursos · `science` Laboratorios · `emoji_events` Ruta de Impacto · **`explore` Directorio de Proyectos (activo)** · `forum` Foro · `workspace_premium` Certificados · `person` Mi Perfil

### Encabezado de la página

Fila con `justify-content: space-between`, `align-items: flex-end`, `gap: 32px`, con wrap.

**Bloque izquierdo** (mínimo 320 px):

- Etiqueta superior: punto de 7 px `#4C9F38` con animación `glow` (pulso de sombra de 2.4 s en bucle) + texto "COMUNIDAD ENACTUS COLOMBIA" en 12 px, `letter-spacing: .16em`, mayúsculas, peso 600, color `--text3`. `gap: 9px`.
- Título: **Knockout**, 58 px, `line-height: .94`, `letter-spacing: .045em`, mayúsculas, color `--gold-ink`. Texto: "Directorio de Proyectos".
- Bajada: 15.5 px, color `--text2`, `max-width: 52ch`, `text-wrap: pretty`, `margin-top: 12px`. Texto: "Todos los proyectos activos de la red. Filtra por etapa, explora los ODS que atienden y descubre qué está construyendo el resto de los equipos."

**Bloque derecho — 4 tarjetas de estadística** (grilla de 4 columnas iguales, `gap: 12px`, ancho mínimo 440 px):

- Tarjeta: fondo `--surface`, borde 1 px `--border`, radio 14 px, `padding: 16px 18px`.
- Número: **Knockout** 40 px, `line-height: 1`, `letter-spacing: .03em`. La primera en `--gold-ink`, las otras tres en `--text`.
- Etiqueta: 12.5 px, `--text3`, `margin-top: 6px`.

Las cuatro métricas se **calculan de los datos, no se codifican**:

| Etiqueta | Cálculo |
| --- | --- |
| Proyectos activos | total de proyectos |
| Universidades | universidades distintas entre los proyectos |
| ODS cubiertos | ODS distintos entre todos los proyectos |
| En National Expo | proyectos cuya etapa es "National Expo" |

**Animación de conteo**: al montar la pantalla los cuatro números suben de 0 a su valor final en 900 ms con easing *ease-out cubic* (`1 - (1-t)³`).

### Filtros de etapa

Fila con wrap, `gap: 9px`. Un chip por etapa más "Todas las etapas" al inicio.

- Chip: `padding: 10px 16px`, radio completo (999 px), 13.5 px, peso 500, transición `all .16s ease`, hover `translateY(-1px)`.
- **Inactivo**: fondo `--surface`, texto `--text2`, borde 1 px `--border`.
- **Activo**: fondo `--gold-soft`, texto `--gold-ink`, borde 1 px `--gold-ink`.
- **Contador** dentro del chip: `min-width: 22px`, `padding: 1px 7px`, radio 999 px, 11.5 px, peso 700. Inactivo: fondo `--surface2`, texto `--text3`. Activo: fondo `--gold-ink`, texto `--bg`.

Cada contador muestra cuántos proyectos hay en esa etapa **sobre el total**, no sobre el resultado filtrado.

Las seis etapas, en orden: **Ideación · Validación · Prototipo · Piloto · Escalamiento · National Expo**

### Grilla de tarjetas de proyecto

Grilla responsiva: columnas de `minmax(348px, 1fr)` con auto-fill, `gap: 20px`.

**Contenedor de tarjeta**: fondo `--surface`, borde 1 px `--border`, radio 18 px, contenido recortado, cursor pointer.
Transición `transform .2s ease, border-color .2s ease, box-shadow .2s ease`.
**Hover**: `translateY(-5px)`, sombra `--shadow`, borde del color del ODS principal.
**Entrada**: animación `fadeUp` (opacidad 0→1, `translateY(14px)`→0) de 450 ms, con retardo escalonado de **55 ms × índice**.

**Portada — 104 px de alto:**

- Fondo: color del **ODS principal** del proyecto (el primero de su lista).
- Encima, patrón de rayas: `repeating-linear-gradient(115deg, rgba(255,255,255,.14) 0 2px, transparent 2px 13px)`.
- Encima, velo inferior: `linear-gradient(180deg, transparent 40%, var(--veil) 100%)`.
- Número del ODS en marca de agua: **Knockout** 82 px, `rgba(255,255,255,.32)`, anclado abajo a la derecha (`right: 14px; bottom: -16px`), recortado por el borde.
- Píldora de etapa arriba a la izquierda (`left: 16px; top: 16px`): ícono `flag` 15 px + texto 12 px peso 600 blanco, `padding: 6px 12px 6px 9px`, radio 999 px, fondo `rgba(10,12,14,.55)`, `backdrop-filter: blur(6px)`.

**Cuerpo — `padding: 18px 20px 20px`, columna con `gap: 13px`:**

1. **Nombre**: Knockout 29 px, `line-height: 1`, `letter-spacing: .045em`, mayúsculas, `--text`.
2. **Descripción**: 14 px, `line-height: 1.5`, `--text2`, `text-wrap: pretty`, `margin-top: 9px`.
3. **Riel de etapas** — seis segmentos iguales, `gap: 4px`, cada uno de 5 px de alto y radio 3 px:
   - etapas ya superadas → `--gold-soft`
   - etapa actual → color del ODS principal
   - etapas futuras → `--border`
   Debajo, fila 11.5 px `--text3` con `space-between`: izquierda "Etapa N de 6"; derecha "Sigue: <nombre de la siguiente etapa>", o "Etapa final" si ya está en National Expo. `margin-top: 7px`.
4. **Comunidad**: ícono `location_on` 17 px `--text3` + texto 13 px `--text2`, `gap: 8px`.
5. **Etiquetas de ODS** — una por ODS del proyecto, con wrap y `gap: 7px`: `padding: 5px 11px 5px 8px`, radio 8 px, fondo `--surface2`, borde 1 px `--border`, texto 11.5 px `--text2`, precedido de un cuadrito de 9 px con radio 2 px del color oficial de ese ODS. Formato del texto: "ODS 6: Agua limpia y saneamiento".
6. **Separador**: línea de 1 px `--border`.
7. **Pie de tarjeta** — fila con `space-between`:
   - Izquierda: ícono `groups` 17 px `--text3` + texto 12.5 px `--text3` con elipsis en una sola línea. Formato: "Equipo AquaVida · Universidad de los Andes · 2 estudiantes".
   - Derecha: cuadro de 32 px, radio 9 px, fondo `--gold-soft`, ícono `arrow_forward` 18 px `--gold-ink`.

### Estado vacío

Se muestra cuando el filtro y la búsqueda no arrojan resultados **o** cuando no hay ningún proyecto publicado.

Caja centrada: `padding: 70px 24px`, fondo `--surface`, borde **punteado** 1 px `--border`, radio 20 px, columna centrada con `gap: 16px`.

- Ícono: caja de 76 px, radio 22 px, fondo `--gold-soft`, glifo `lightbulb` 36 px `--gold-ink`.
- Título: Knockout 38 px, `letter-spacing: .045em`, mayúsculas, `--text`. Texto: "Aún no hay proyectos aquí".
- Texto: 15 px, `line-height: 1.55`, `--text2`, `max-width: 46ch`, `text-wrap: pretty`. **Dos variantes:**
  - Sin ningún proyecto: "Todavía no se ha publicado ningún proyecto en la comunidad. Cuando tu equipo registre el suyo, aparecerá aquí para toda la red."
  - Filtro sin resultados: "Ningún proyecto coincide con este filtro. Prueba con otra etapa o limpia la búsqueda."
- Botones (fila con wrap, `gap: 12px`, `margin-top: 6px`), ambos `padding: 14px 24px`, radio 10 px, 14 px, peso 600, ícono 19 px, `gap: 9px`, transición `all .15s ease`:
  - **Primario** "Ver todas las etapas" (ícono `restart_alt`): fondo `#F4C430`, texto `#1A1400`. Hover: `#FFD700`, sombra `0 8px 22px rgba(244,196,48,.28)`, `translateY(-1px)`. Acción: limpia etapa y búsqueda.
  - **Secundario** "Proponer un proyecto" (ícono `add`): transparente, borde 1 px `--gold-ink`, texto `--gold-ink`. Hover: fondo `--gold-soft`.

### Pie de página

`margin-top: 18px`, `padding-top: 22px`, borde superior 1 px `--border`, fila con `space-between` y wrap, `gap: 24px`.

- Izquierda: barra de bandera **vertical** de 4 px de ancho y 22 px de alto (mismas tres franjas, radio 2 px) + texto 12.5 px `--text3`: "Entidad sin ánimo de lucro. Fundada en 2021. Bogotá D. C., Colombia."
- Derecha: enlaces 12.5 px `--text3`, hover `--gold-ink`, `gap: 18px`:
  - Facebook → `https://www.facebook.com/enactuscolombia/`
  - Instagram → `https://www.instagram.com/enactuscolombia/`
  - LinkedIn → `http://linkedin.com/company/enactuscolombia/`

## Interacciones y comportamiento

| Interacción | Comportamiento |
| --- | --- |
| Click en chip de etapa | Filtra la grilla a esa etapa. "Todas las etapas" limpia el filtro. Solo una etapa activa a la vez. |
| Escribir en el buscador | Filtra en vivo, sin debounce. Coincidencia por substring, sin distinguir mayúsculas, sobre: nombre + descripción + comunidad + etapa + etiquetas de ODS concatenados. |
| Filtro + búsqueda | Se aplican en cadena: primero la etapa, luego el texto. |
| Hover en tarjeta | Elevación, sombra y borde teñido del color del ODS. |
| Click en tarjeta | Navega al detalle del proyecto (ruta existente en la app). |
| Botón de tema | Alterna claro/oscuro solo en el área `main`. |
| "Ver todas las etapas" | Restablece etapa a "todas" y vacía la búsqueda. |
| Montaje de la pantalla | Contadores animan 0 → valor (900 ms, ease-out cubic); las tarjetas entran escalonadas a 55 ms por índice. |

## Estado

- `stage: String` — etapa seleccionada; `'todas'` por defecto.
- `query: String` — texto del buscador; vacío por defecto.
- `theme: 'dark' | 'light'` — oscuro por defecto.
- `counters: {proyectos, universidades, ods, expo}` — valores intermedios de la animación de conteo.

Los proyectos se leen del servicio de datos existente. En el prototipo están en memoria; en la app deben venir de `seed_service` / del backend, con estados de carga y error según el patrón que ya use el repo.

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
| Bandera de Colombia | `#FCD116`, `#003893`, `#CE1126` |

### Tokens por tema (solo afectan al área `main`)

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

En tema claro el amarillo se oscurece a `#8A6A00` para el texto — el `#F4C430` sobre blanco no alcanza contraste AA.

### Colores oficiales de los ODS

Usados en portadas de tarjeta, cuadritos de etiqueta y el segmento de etapa actual:

```
1 #E5243B   2 #DDA63A   3 #4C9F38   4 #C5192D   5 #FF3A21   6 #26BDE2
7 #FCC30B   8 #A21942   9 #FD6925  10 #DD1367  11 #FD9D24  12 #BF8B2E
13 #3F7E44  14 #0A97D9  15 #56C02B  16 #00689D  17 #19486A
```

### Tipografía

| Uso | Fuente | Tamaño | Detalle |
| --- | --- | --- | --- |
| Título de página | Knockout 92 | 58 px | `line-height: .94`, `letter-spacing: .045em`, mayúsculas |
| Cifras de estadística | Knockout 92 | 40 px | `line-height: 1`, `letter-spacing: .03em` |
| Título de estado vacío | Knockout 92 | 38 px | `letter-spacing: .045em`, mayúsculas |
| Nombre de proyecto | Knockout 92 | 29 px | `line-height: 1`, `letter-spacing: .045em`, mayúsculas |
| Marca de agua del ODS | Knockout 92 | 82 px | `rgba(255,255,255,.32)` |
| Bajada | Space Grotesk | 15.5 px | |
| Cuerpo de tarjeta | Space Grotesk | 14 px | `line-height: 1.5` |
| Etiquetas de nav / chips | Space Grotesk | 13.5 px | |
| Metadatos, pie | Space Grotesk | 12.5 px | |
| Etiquetas de ODS, riel | Space Grotesk | 11.5 px | |
| Etiqueta superior | Space Grotesk | 12 px | `letter-spacing: .16em`, mayúsculas, peso 600 |

### Escala de espaciado

`4 · 7 · 9 · 12 · 13 · 16 · 18 · 20 · 22 · 26 · 32 · 34 · 40 px`

### Radios

`2 px` (cuadrito de ODS) · `3 px` (segmento del riel) · `8 px` (ítem de nav, etiqueta de ODS) · `9 px` (botón de flecha) · `10 px` (buscador, botones) · `14 px` (tarjeta de estadística) · `18 px` (tarjeta de proyecto) · `20 px` (estado vacío) · `22 px` (caja de ícono) · `999 px` (chips y píldoras)

### Animaciones

| Nombre | Especificación |
| --- | --- |
| `fadeUp` | opacidad 0→1 + `translateY(14px)`→0, 450 ms, escalonada 55 ms por tarjeta |
| `glow` | pulso de sombra `0 0 0 0 rgba(244,196,48,.55)` → `0 0 0 5px rgba(244,196,48,0)`, 2.4 s en bucle |
| Conteo | 0 → valor en 900 ms, ease-out cubic |
| Hover de tarjeta | `transform`, `border-color`, `box-shadow` a 200 ms `ease` |
| Hover de chip / botón | `all` a 160 ms / 150 ms `ease` |

## Recursos

Todos ya presentes en el repositorio, bajo `assets/media/`:

- `Knockout-92.otf` — tipografía de titulares de la marca
- `SpaceGrotesk-Variable.ttf` — tipografía de texto
- `mainlogo.png` — logotipo de Enactus Colombia

Iconografía: **Material Symbols Rounded** (en Flutter, los `Icons` redondeados equivalentes). Glifos usados: `search`, `light_mode`, `dark_mode`, `notifications`, `dashboard`, `calendar_month`, `school`, `science`, `emoji_events`, `explore`, `forum`, `workspace_premium`, `person`, `flag`, `location_on`, `groups`, `arrow_forward`, `lightbulb`, `restart_alt`, `add`.

**No se usan imágenes de proyecto.** Las portadas son color plano del ODS + patrón de rayas + número en marca de agua, precisamente para no depender de fotografías que los equipos aún no han subido.

## Archivos de este paquete

- `Directorio de Proyectos.dc.html` — el prototipo de referencia. Ábrelo en un navegador para ver el comportamiento real (filtros, búsqueda, cambio de tema, animaciones).
- `support.js`, `assets/media/*` — archivos de apoyo para que el prototipo abra sin conexión.

## Datos

Solo **AquaVida** y **SolAndino** provienen de los datos sembrados reales del repo. Los otros cinco proyectos del prototipo son **ejemplos inventados** para mostrar la variedad de colores de ODS y de etapas. No los lleves a producción.
