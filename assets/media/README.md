# eduXaction - paquete de logotipo

Variante elegida: **barrido de luz** (la X naranja con halo y un destello que la recorre en bucle).

## Archivos

| Archivo | Uso |
| --- | --- |
| eduxaction-logo.css | Logotipo y icono animados en CSS. Es el archivo principal. |
| eduxaction-logo.html | Snippets listos para copiar y pegar. |
| eduxaction-mark-animado.svg | Icono animado autonomo (sirve dentro de <img>). |
| eduxaction-x.svg | X estatica, fondo transparente. |
| favicon.svg | Favicon vectorial (tile oscuro). |
| favicon-32.png, favicon-192.png, favicon-512.png | Favicons PNG. |
| apple-touch-icon.png | Icono 180x180 para iOS. |

## Instalacion

1. Copia la carpeta a `/assets` de tu sitio.
2. En el `<head>`: `<link rel="stylesheet" href="/assets/eduxaction-logo.css">`
3. Donde quieras el logo:
   `<span class="exa-logo" role="img" aria-label="eduXaction">edu<span class="exa-x">X</span>action</span>`

El CSS importa Manrope desde Google Fonts. Si ya cargas Manrope (700 y 800), borra la linea `@import` del inicio.

## Personalizacion

Todo se controla con variables CSS, en el elemento o en `:root`:

- `--exa-size`: tamano del texto / lado del icono. Por defecto 64px.
- `--exa-accent`: color de la X. Por defecto #FA6A1E (el acento anterior), pero
  la marca vigente la pide en **#FFFFFF**: la app y el splash lo pasan explicito.
- `--exa-glow`: intensidad del brillo, 0 a 2. Por defecto 1. Sobre fondo claro usa 0.4 o menos.
- `--exa-shine`: color del destello que recorre la X. Por defecto #FFF4EA; la
  marca vigente usa el ambar **#FFC107**, que es lo que da el efecto diamante
  sobre la X blanca.
- `--exa-sweep`: duracion del destello. Por defecto 2.9s; la marca vigente usa 3.6s.

Ejemplo: `<span class="exa-logo" style="--exa-size:40px; --exa-glow:.7">...</span>`

## Notas

- La animacion se desactiva sola si el usuario tiene "reducir movimiento" activado en su sistema.
- El logo es texto real: se selecciona, se busca y escala sin perder nitidez. El `aria-label` mantiene la lectura correcta en lectores de pantalla.
- Fondo recomendado: #35343A (pagina) a #0B0B0D (negro de los degradados).
  Sobre blanco usa la clase `exa-logo--on-light`.
- Espacio libre alrededor del logo: como minimo el alto de la X.
