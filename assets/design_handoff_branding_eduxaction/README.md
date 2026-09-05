# Handoff: rebranding de eduXaction Colombia (fondo gris + acento ámbar)

## Overview
Cambia la identidad de la plataforma eduXaction de **negro puro + naranja saturado**
a **gris medio + negro difuminado, con un solo acento ámbar**. El objetivo del
usuario, textual: bajar el contraste y quitar el aire de Halloween sin perder el
acento cálido. Aplica a la landing pública y, por herencia de tokens, a todo el
portal.

Repo objetivo: `saraisaza/enactus_platform_v4` (Flutter Web, rama `main`).
Todo el color de la app sale de `lib/utils/app_theme.dart`, así que el cambio es
sobre tokens, no sobre pantallas sueltas.

## About the Design Files
Los archivos de este paquete son **referencias de diseño hechas en HTML**:
prototipos que muestran la apariencia buscada, no código para copiar. La tarea es
**reproducir ese diseño en el entorno existente del repo** (Flutter/Dart, tema
Material 3 ya montado, widgets propios en `lib/widgets/`), respetando sus
patrones. No agregues CSS ni HTML a la app Flutter: el único CSS real que se
despliega es `web/eduxaction-logo.css`, que solo aplica al splash de
`web/index.html` antes de que Flutter monte.

## Fidelity
**Alta fidelidad (hifi)** en color, tipografía y jerarquía: los hex de este
documento son finales. El layout **no cambia** — la landing conserva su estructura
actual (header, hero, fotos de la National Expo, contadores, "Sobre nosotros",
laboratorios, galería, invitación, footer). Las fotos en la referencia HTML están
como espacios rayados; en la app siguen siendo `assets/media/foto1..3.jpeg`.

## Screens / Views

### Landing pública (`lib/views/public/landing_view.dart`)
- **Purpose**: presentar eduXaction Colombia y llevar al login.
- **Layout**: sin cambios respecto al actual.

**Header** (alto 160 px escritorio / 64 px compacto, padding horizontal 24/16)
- Fondo `#35343A`, borde inferior 1 px `rgba(255,255,255,.08)`.
- Logo `AnimatedLogo` a 135 px (36 px compacto) — ver `LOGO.md`.
- Botón "Iniciar sesión": fondo `#FFC107`, texto e ícono `#21120A`, peso 600,
  radio 8 px, padding 22×16, ícono `login` 18 px. Hover: `#FFCF3D`.

**Hero** (padding vertical 70, horizontal 40)
- Fondo: `LinearGradient(topLeft → bottomRight, [#35343A, #0B0B0D])`.
  Es el cambio central: el segundo tono era el marrón `slate #453027`.
- Título (`SiteContent.heroTitle`, por defecto "eduXaction Colombia"): Oswald 700,
  54 px, MAYÚSCULAS, `height .98`, `letter-spacing 54*0.002`, color **#F2F2F5**
  (antes iba en naranja: ahí estaba el 80 % del efecto Halloween).
- Subtítulo: DM Sans 17 px, `#AEABB0`, ancho máx. 640 px. Hoy `heroSubtitle` viene
  vacío, así que no se ve.
- CTA "Entrar a la plataforma": mismo botón ámbar, ícono `arrow_forward` 18 px.
- Partículas: 14 círculos lentos, radio 1.2–3.4 px, opacidad .08–.24, colores
  `heroParticleColors` nuevos (ámbar, ámbar claro, blanco, gris).

**Campeones National Expo** (padding 40/44/40/8)
- Eyebrow nuevo, opcional pero recomendado: "SANTA MARTA · JULIO 2026", DM Sans 600,
  11.5 px, `letter-spacing .14em`, MAYÚSCULAS, `#FFC107`.
- Título: Oswald 700, 30 px, MAYÚSCULAS, tracking .014em, **#F2F2F5** (antes ámbar/naranja).
- Bajada: DM Sans 14 px `#AEABB0` — texto real: "Santa Marta, julio 2026 — nuestros
  equipos rumbo al eduXaction World Cup en São Paulo".
- Fotos: alto fijo 340 px (260 en móvil), ancho por proporción real, radio 16 px,
  sin recorte forzado. Leyenda de la foto grupal sobre degradado a
  `rgba(0,0,0,.78)`, ícono `emoji_events` 15 px en `#FFC107`.

**Contadores de impacto** (Wrap, spacing 40 / runSpacing 20)
- Tarjeta 150×160, radio 16 px, padding 20×12, borde 1 px `rgba(255,255,255,.08)`.
- Fondo: `radial-gradient(120% 120% at 50% 0%, rgba(255,255,255,.05), rgba(11,11,13,.72))`
  — "negro difuminado". En Flutter: `RadialGradient(center: Alignment.topCenter,
  radius: 1.2, colors: [Color(0x0DFFFFFF), Color(0xB80B0B0D)])`.
- Ícono 22 px `#FFC107`; cifra Oswald 700 36 px `#FFC107`, `height 1`,
  `letterSpacing 0`; label DM Sans 12.5 px `#AEABB0`, máx. 2 líneas, alto 32 px.
- Valores reales por defecto (`SiteContent`): 6 estudiantes, 2 proyectos,
  6 laboratorios, 2 universidades. Animan de 0 al valor en 1200 ms `easeOutCubic`.

**Sobre nosotros**: tarjeta margen horizontal 40, padding 24, radio 14 px, fondo
`#17171A` (antes `slate`), texto DM Sans 15 px / 1.6 `#F2F2F5`.

**Nuestros Laboratorios**
- La banda va sobre `linear-gradient(180deg, #2C2B30, #0B0B0D)`, borde superior
  1 px `rgba(255,255,255,.07)`.
- Eyebrow "ÁREAS DE CONOCIMIENTO" en `#FFC107` 11.5 px .14em; título Oswald 700
  30 px `#F2F2F5`; bajada 14 px `#AEABB0`.
- Tarjeta: fondo `rgba(255,255,255,.045)`, borde 1 px `rgba(255,255,255,.08)`,
  radio 12 px, padding 20 px; ícono del lab 30 px `#FFC107`; nombre Oswald 700
  16–17 px MAYÚSCULAS `#F2F2F5`; descripción 13 px / 1.5 `#AEABB0`.
- 3 por fila > 1000 px, 2 por fila > 640 px, 1 abajo; gap 16 px.
- `box-sizing` importa: en la referencia HTML las tarjetas llevan
  `box-sizing: border-box` para que 3×216 + 2×14 quepan sin recorte.

**Invitación "¿Listo para sumarte?"**: degradado `[rgba(255,255,255,.04), #0B0B0D]`
(antes `[gold .14, slate]`), borde 1 px `rgba(255,255,255,.08)`, radio 18 px,
título Oswald 24 px `#F2F2F5`, cuerpo 14 px `#AEABB0`, botón ámbar "Quiero unirme".

### Resto del portal
No hay rediseño: al cambiar `AppColors` y `ContentColors` (ver
`app_colors.dart.patch.md`) el header, sidebar, tarjetas, tablas, chips, diálogos
y gráficos heredan la paleta. Dos avisos:
1. `AppColors.chartSeries` incluye `#C98500` (amarillo) que ahora choca con el
   acento ámbar. Cámbialo por un tono claramente distinto (p. ej. `#3987E5` ya está
   en la serie; usa `#B07AA1` o `#199E70` en su lugar) y mantén el orden fijo.
2. En tema claro el ámbar no pasa AA como texto: usa `goldInk #8A6A00`.

## Interactions & Behavior
- **Botones** (`elevatedButtonTheme`): hover → `#FFCF3D` + elevación 8; pressed →
  elevación 1; transición 150 ms. Sin cambios de comportamiento.
- **Logo**: hover escala 1.08 (250 ms `easeOutBack`), rotación −0.004 turns y
  resplandor `Colors.white.withValues(alpha: .28)`, blur 28, spread 2 (antes ámbar).
- **Barrido de la X**: bucle de 3.6 s, de derecha a izquierda; se apaga con
  "reducir movimiento".
- **Entradas**: `Entrance` con stagger de 90 ms por tarjeta; hero con fade + subida
  de 20 px en 700 ms `easeOut`. Sin cambios.
- **Contadores**: animan al aparecer, 1200 ms.

## State Management
Sin cambios. El color no depende de estado; el contenido de la landing viene de
`DataProvider.siteContent` (`SiteContent` en `lib/models/models.dart`) y de
`DataProvider.labs`, editables por el Admin. Los toggles de tema local
(Dashboard, Calendario, Mis Cursos, Ruta de Impacto, Directorio de Proyectos)
siguen leyendo `ContentColors.dark` / `.light`.

## Design Tokens
Ver `brand-tokens.css` (web) y `app_colors.dart.patch.md` (Flutter). Resumen:

| Rol | Valor |
| --- | --- |
| Página | `#35343A` |
| Negro de degradado | `#0B0B0D` |
| Tarjeta sólida | `#17171A` |
| Tarjeta translúcida | `rgba(11,11,13,.72)` |
| Panel / campo | `#26262A` |
| Tarjeta sobre banda | `rgba(255,255,255,.045)` |
| Borde | `rgba(255,255,255,.08)` |
| Texto | `#F2F2F5` |
| Texto secundario | `#AEABB0` |
| Texto terciario | `#8F8C92` |
| Acento | `#FFC107` |
| Acento hover | `#FFCF3D` |
| Tinta sobre acento | `#21120A` |
| Acento en tema claro | `#8A6A00` |
| X del logo | `#FFFFFF`, destello `#FFC107` |

Radios: 8 px botón, 12 px panel/tarjeta de lab, 14 px tarjeta de texto, 16 px
contador y foto, 18 px banda de invitación, 25 % el cuadrado `.exa-mark`.
Sombra: `0 18px 40px rgba(0,0,0,.5)`.
Tipografía: Oswald 700 (títulos, MAYÚSCULAS, tracking .014em; hero .002em),
DM Sans 400/500/600 (todo lo demás), Manrope 700/800 (solo el wordmark).
Escala de espaciado observada: 4 / 6 / 8 / 10 / 12 / 14 / 16 / 20 / 24 / 28 / 32 / 40 / 70.

## Assets
- `eduxaction-logo.css` — paquete de marca del wordmark, **modificado**: el color
  del destello salió a la variable `--exa-shine` (antes fijo `#FFF4EA`). Reemplaza
  `web/eduxaction-logo.css` y `assets/media/eduxaction-logo.css` del repo.
- Fotos y SVG del ícono: ya están en el repo (`assets/media/`, `web/favicon.svg`).
  El ícono animado usa `#FFF4EA` en su gradiente y el cuadrado `#0B0B0D`: si quieres
  el mismo efecto diamante, cambia esos stops a `#FFC107`.
- Fuentes: Oswald, DM Sans y Manrope ya vienen empaquetadas en `pubspec.yaml`.
  Nota abierta del repo: falta `Oswald-SemiBold.ttf`; hoy se usa 700.

## Files
- `landing-referencia.html` — la referencia aprobada (opción 2a). Ábrela en un
  navegador: el logo anima igual que en la app.
- `variantes-de-gris.html` — las cinco variantes de gris que se probaron antes,
  para contexto de por qué se eligió #35343A. Ojo: ahí el acento sigue siendo el
  naranja viejo #FA6A1E, porque el ámbar se decidió después.
- `brand-tokens.css`, `app_colors.dart.patch.md`, `LOGO.md`, `PROMPT.md`.
