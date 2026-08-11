# Handoff: Mapa de estudiantes — portales de Empresa y Donante

## Resumen

Nueva visualización para los portales de **Empresa** y **Donante**: un mapa de Colombia que muestra de dónde son los estudiantes registrados en la red, con un panel lateral que los ordena por ciudad.

Responde una pregunta que hoy el portal de aliados no responde: *¿dónde está la gente que estamos apoyando?* Un donante quiere ver su huella geográfica, no solo un total.

## Sobre los archivos de este paquete

`Mapa de Estudiantes.html` es una **referencia de diseño construida en HTML**, y a la vez la fuente de la geometría. **No es código para copiar a producción** — la app real es Flutter (Dart).

Ábrelo en un navegador antes de escribir código: prueba el cambio de alcance ("Toda la red" / "Los que patrocino"), pasa el mouse por los puntos y por las filas del listado, y cambia el tema.

Antes de implementar, lee:

- `lib/views/donor/donor_portal.dart` — portal del donante
- `lib/views/company/` — portal de la empresa
- `lib/providers/data_provider.dart` — de dónde saldrán los estudiantes y su filtrado por patrocinador
- `lib/models/models.dart` — el modelo de estudiante (campo `university`)
- `lib/utils/app_theme.dart` — tokens de color y tipografía

## Fidelidad

**Alta fidelidad.** Colores, tipografía, tamaños e interacciones son finales.

---

## Bloqueante antes de empezar: no hay dato de ciudad

El modelo de estudiante hoy solo guarda `university` (un string libre: "Universidad de los Andes", "Universidad Nacional"). **No hay ciudad ni departamento**, así que el mapa no se puede alimentar con los datos actuales.

Hay dos caminos. **Pregúntame cuál antes de implementar:**

1. **Tabla de universidad → ciudad** en el código o en configuración. Ventaja: no toca el perfil ni pide nada al estudiante, y una universidad tiene una sede principal conocida. Desventaja: hay que mantenerla, y las universidades con varias sedes quedan agrupadas en una.
2. **Campo de ciudad en el perfil del estudiante**, elegido de una lista cerrada de municipios. Ventaja: es el dato real y soporta sedes regionales y estudio a distancia. Desventaja: exige migración y llenar los perfiles existentes.

Cualquiera de los dos necesita además **coordenadas por ciudad** (latitud y longitud) para poder ubicar el punto. Van en la misma tabla; el prototipo trae 19 ciudades con sus coordenadas reales, reutilizables tal cual.

Sin resolver esto, el mapa no tiene qué mostrar. Es la primera tarea, no un detalle de implementación.

---

## Geometría: úsala, no la dibujes

**Nunca dibujes a mano el contorno de Colombia.** Una silueta dibujada a ojo siempre sale mal y la gente lo nota.

Este paquete incluye `colombia-110m.json`: la geometría real de Colombia, extraída de **Natural Earth 110m** (dominio público, vía `world-atlas@2.0.2`) y reducida a un `Feature` de GeoJSON con un solo polígono de 100 coordenadas — 1.7 KB. Cópialo a `assets/` y cárgalo desde ahí.

Dos razones para tenerlo local en vez de descargarlo en tiempo de ejecución:

- El mapa dibuja el contorno de su propio país; no debería depender de que un CDN responda.
- En el prototipo, los scripts de las librerías de mapas bloqueaban el evento `load` de la página, y cuando esa conexión se demoraba **nada se pintaba nunca**. Con la geometría local no hay dependencia externa: el archivo final no carga ni un script de terceros.

### Proyección

**Mercator esférica**, ajustada a la caja del mapa con 40 px de margen. Las fórmulas, para no dejarlo a interpretación:

```
x = lon · π/180
y = ln( tan( π/4 + lat·π/360 ) )
```

Luego se calculan los límites del polígono en ese espacio, se toma `k = min((ancho − 2·margen)/(x₁ − x₀), (alto − 2·margen)/(y₁ − y₀))` y se centra. El eje Y se **invierte** al pasar a pantalla (latitud mayor = Y menor).

En Flutter esto es un puñado de líneas sobre un `CustomPainter`; no hace falta un paquete de mapas. La latitud se recorta a ±85° para evitar el infinito de Mercator (irrelevante para Colombia, pero deja la función reutilizable).

La resolución 110m es deliberadamente gruesa: a este tamaño de tarjeta se lee perfecto y pesa casi nada. Si algún día se quiere más detalle, la fuente equivalente es `countries-50m.json` del mismo paquete.

---

## Estructura de la pantalla

Columna con `padding: 34px 40px 56px`, `gap: 26px`, ancho máximo 1560 px centrado.

### a) Encabezado

Mismo patrón que el resto del portal: punto verde `#4C9F38` con pulso + rótulo 12 px `letter-spacing: .16em` mayúsculas `--text3`; título en **Knockout 58 px** mayúsculas `--gold-ink`; bajada 15.5 px `--text2` `max-width: 56ch`.

- Título: "Estudiantes en el país"
- Bajada: "Dónde están los estudiantes registrados en Enactus Colombia. Cada punto es una ciudad con al menos una universidad activa en la red."
- El rótulo **cambia con el alcance**: "Red nacional · actualizado hoy" o "Estudiantes que patrocina tu organización".

### b) Cifras

Grilla de 4 columnas iguales, `gap: 12px`. Tarjeta: fondo `--surface`, borde 1 px `--border`, radio 14 px, `padding: 16px 18px`; número en **Knockout 40 px** (la primera en `--gold-ink`, las demás en `--text`); etiqueta 12.5 px `--text3`.

**Estudiantes registrados · Ciudades · Universidades · Departamentos** — las cuatro calculadas del conjunto visible, nunca codificadas. Al montar, suben de 0 a su valor en 800 ms con easing *ease-out cubic* (`1 − (1−t)³`).

### c) Controles

- **Alcance** (segmentado en píldora): "Toda la red" / "Los que patrocino". Contenedor `padding: 4px`, radio 999 px, fondo `--surface`, borde 1 px `--border`; botones `padding: 9px 17px`, radio 999 px, 13.5 px. Activo: fondo `--gold-soft`, texto `--gold-ink`, peso 600.
- **Tema** a la derecha: botón fantasma `padding: 11px 17px`, radio 10 px, borde 1 px `--border`, ícono 18 px. Hover: borde y texto `--gold-ink`.

### d) Mapa y listado

Grilla `minmax(0,1.62fr) / minmax(0,1fr)`, `gap: 20px`, alineadas arriba. Por debajo de 1080 px pasa a una columna y el mapa baja de 620 px a 520 px de alto.

**Mapa** — tarjeta radio 18 px, contenido recortado, área de 620 px de alto.

- Silueta: relleno `--surface2` (`#EDEDE3` en tema claro), borde 1.2 px `--border`.
- **Puntos**: por cada ciudad, un halo (radio del núcleo × 1.9, opacidad .16) y un núcleo con borde 1.3 px `#0D0F11` (1.6 px blanco en tema claro).
- **Radio por raíz cuadrada**, no por diámetro: `r = max(3.5, √(v/vₘₐₓ) · 26)`. Escalar el diámetro exagera las ciudades grandes; el área debe ser proporcional al valor.
- **Etiqueta** de ciudad solo si `v ≥ vₘₐₓ · 0.35` (en la práctica las cuatro mayores). 11 px peso 600 `--text2`, a 8 px por encima del punto, centrada, con contorno de 3.5 px del color del mapa y `paint-order: stroke` para que se lea sobre los puntos. Con el umbral más bajo las etiquetas se chocaban en el corredor andino.
- Hover: el punto se resalta con borde 2 px `--text`, los demás bajan a opacidad .25, y aparece el tooltip.

**Listado** — tarjeta `padding: 22px 24px`. Título "Ciudades" en Knockout 24 px mayúsculas; subtítulo 12.5 px `--text3` que cambia con el alcance. Filas de `padding: 9px 10px`, radio 10 px, `gap: 12px`, con scroll a partir de 470 px:

- Rango en 11.5 px `--text3`, ancho 22 px, alineado a la derecha.
- "Ciudad · Departamento" en 13.5 px con elipsis, sobre una barra de 5 px radio 3 px (fondo `--surface2`, relleno del **color de su nivel**, transición de ancho 300 ms).
- Valor a la derecha en **Knockout 19 px** `--text2`, ancho mínimo 30 px.
- Hover: fondo `--surface2` y resalta el punto correspondiente en el mapa.

Debajo, una nota en caja `--surface2` radio 12 px con ícono `info`: "Un estudiante cuenta en la ciudad de su universidad. Los que estudian a distancia se agrupan en la sede principal." **Ajusta este texto a la regla que se elija arriba** — si el dato pasa a ser un campo del perfil, la nota cambia.

### e) Tooltip

`padding: 11px 14px`, radio 11 px, fondo `rgba(10,12,14,.92)`, borde 1 px `rgba(255,255,255,.12)`, `backdrop-filter: blur(8px)`, ancho mínimo 172 px, anclado sobre el punto (`translate(-50%, -118%)`).

- Punto de 9 px del color del nivel + nombre de la ciudad en Knockout 21 px mayúsculas blanco.
- Departamento en 11.5 px `rgba(255,255,255,.6)`.
- Cifra en Knockout 26 px del color del nivel + "estudiantes" (o "estudiantes que patrocinas" en el alcance del aliado) en 12 px.
- Tras una línea divisoria, las universidades de esa ciudad separadas por punto medio, en 11.5 px `rgba(255,255,255,.66)`.

### f) Leyenda

Abajo a la izquierda del mapa (`left: 22px; bottom: 20px`), fondo `rgba(10,12,14,.72)` con `blur(8px)`, radio 12 px, `padding: 13px 15px`.

- Rótulo "ESTUDIANTES POR CIUDAD" 10.5 px `letter-spacing: .14em`.
- Tres círculos de referencia (10 %, 45 % y 100 % del máximo) con su valor debajo, cada uno del color de su nivel.
- Tras una línea divisoria, la clave de color: un punto de 10 px por nivel con su etiqueta en 11 px.

### g) Pie

Barra vertical de la bandera (4 × 22 px, radio 2 px) + "Portal de aliados · Enactus Colombia" a la izquierda; "Geometría: Natural Earth (dominio público)" a la derecha. Ambos 12.5 px `--text3`. **La atribución de Natural Earth se queda**: es la fuente del dato.

---

## Color: la paleta de la bandera

Los puntos y las barras se colorean por **tamaño de la comunidad**, con los tres colores de la bandera de Colombia:

| Nivel | Color | Etiqueta |
| --- | --- | --- |
| 40 estudiantes o más | `#CE1126` (rojo) | "40 o más estudiantes" |
| Entre 12 y 39 | `#FCD116` (amarillo) | "Entre 12 y 39" |
| Menos de 12 | `#2F6BE0` (azul) | "Menos de 12" |

El azul es **el de la bandera aclarado a propósito**. El original `#003893` sobre el fondo oscuro `#1A1D21` queda casi negro y los puntos pequeños desaparecen. Mantén `#2F6BE0` o ajústalo, pero no vuelvas al `#003893` sin comprobar el contraste en tema oscuro.

Los umbrales (40 y 12) están calibrados para el reparto actual: da tres grupos parejos. **Si el conjunto de datos real cambia mucho de escala, recalcúlalos** — con umbrales fijos sobre otra distribución podrías terminar con todos los puntos del mismo color. Considérala una escala con cortes por cuantiles si la distribución se mueve.

### Tokens por tema

| Token | Oscuro | Claro |
| --- | --- | --- |
| `--bg` | `#111315` | `#F2F2EC` |
| `--surface` | `#1A1D21` | `#FFFFFF` |
| `--surface2` (relleno del mapa) | `#22262B` | `#EDEDE3` |
| `--border` | `#33383F` | `#DEDED4` |
| `--text` | `#F5F5F2` | `#15181B` |
| `--text2` | `#B8BCBF` | `#4C525A` |
| `--text3` | `#8A9099` | `#787F88` |
| `--gold-ink` | `#F4C430` | `#8A6A00` |
| `--gold-soft` | `rgba(244,196,48,.14)` | `rgba(244,196,48,.24)` |

Son los mismos del resto del portal: tómalos de `app_theme.dart`, no los redefinas aquí.

### Tipografía

| Uso | Fuente | Tamaño |
| --- | --- | --- |
| Título | Knockout 92 | 58 px, `letter-spacing: .045em`, mayúsculas |
| Cifras | Knockout 92 | 40 px |
| Ciudad en el tooltip | Knockout 92 | 21 px |
| Cifra del tooltip | Knockout 92 | 26 px |
| Título del listado | Knockout 92 | 24 px |
| Valor de cada fila | Knockout 92 | 19 px |
| Bajada | Space Grotesk | 15.5 px |
| Filas, controles | Space Grotesk | 13.5 px |
| Metadatos, nota, pie | Space Grotesk | 12.5 px |
| Etiquetas del mapa | Space Grotesk | 11 px, peso 600 |
| Leyenda | Space Grotesk | 10.5–11 px |

---

## Comportamiento

| Interacción | Comportamiento |
| --- | --- |
| Alcance | Recalcula **todo**: cifras, puntos, niveles de color, leyenda y listado. En "Los que patrocino" las ciudades sin estudiantes patrocinados desaparecen del mapa y del listado. |
| Hover en punto | Tooltip con el detalle; los demás puntos bajan a opacidad .25. |
| Hover en fila | Resalta el punto correspondiente en el mapa (el vínculo va en los dos sentidos). |
| Click en punto o fila | **Sin definir en el prototipo.** Lo natural es abrir la lista de estudiantes o de proyectos de esa ciudad — dime si lo quieres y lo diseñamos. |
| Tema | Alterna claro/oscuro. |
| Cambio de tamaño | Recalcula la proyección; el observador de tamaño va con `debounce` de 140 ms. |
| Montaje | Las cifras animan de 0 a su valor en 800 ms. |

### Estado

- `scope` — `all` | `mine`; `all` por defecto.
- `theme` — oscuro por defecto.

Todo lo demás se deriva de los datos.

### Alcance del aliado

"Los que patrocino" debe filtrar por el vínculo real que ya existe en el modelo: `companyId` para el portal de Empresa y `donorId` para el de Donante. En el portal de un aliado, **considera que el alcance por defecto sea "Los que patrocino"** y que "Toda la red" sea el contexto secundario: es su información más relevante. En el prototipo el orden está al revés; decídelo con el equipo.

### Estados vacíos

- **Un aliado sin estudiantes patrocinados** — mensaje en el área del mapa explicando que aún no hay estudiantes vinculados a su aporte, con acción para contactar al administrador. No dejes el mapa en blanco.
- **Sin geometría o error de datos** — mensaje dentro de la tarjeta del mapa; las cifras y el listado se pintan igual, porque no dependen de la geometría. Que un fallo del mapa no se lleve la pantalla completa.

---

## Recursos

- `colombia-110m.json` — geometría de Colombia (Natural Earth 110m, dominio público). Cópiala a `assets/`.
- Tipografías ya en el repo: `assets/media/Knockout-92.otf`, `assets/media/SpaceGrotesk-Variable.ttf`.
- Iconografía: **Material Symbols Rounded**. Glifos usados: `info`, `light_mode`, `dark_mode`, `public`, `public_off`.

## Datos

**Las 19 ciudades del prototipo con sus coordenadas son reales y reutilizables.** Los conteos de estudiantes son inventados: 432 en total, repartidos de forma plausible, y un subconjunto arbitrario marcado como "patrocinado" para poder mostrar el segundo alcance. Nada de eso va a producción.

La lista de universidades por ciudad también es de ejemplo, aunque las instituciones existen. Reemplázala con las universidades reales de la red.
