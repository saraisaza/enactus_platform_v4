# Logo eduXaction — reglas nuevas

El wordmark sigue siendo tipográfico: **Manrope 700**, `letter-spacing: -0.025em`,
"edu" + "X" + "action". Lo que cambia es la X.

| | Antes | Ahora |
| --- | --- | --- |
| Color de la X | naranja #FA6A1E fijo, "nunca cambia de tono" | **blanco #FFFFFF** |
| Halo (`::before`) | naranja difuso | blanco difuso, `blur(.22em)` |
| Destello (`::after`) | crema #FFF4EA | **ámbar #FFC107** |
| Duración del barrido | 2.9 s | **3.6 s** |
| Cuadrado `.exa-mark` | fondo #0B0B0D, radio 25% | igual |

La X blanca sola no mostraba la animación (destello blanco sobre blanco): el
efecto "diamante" viene de que el barrido sea ámbar sobre la X blanca. El color
del destello ahora es la variable `--exa-shine` en `eduxaction-logo.css` (antes
estaba fijo en el gradiente).

## Uso

```html
<link rel="stylesheet" href="eduxaction-logo.css">
<span class="exa-logo" style="--exa-size: 34px; --exa-accent: #FFFFFF; --exa-shine: #FFC107; --exa-sweep: 3.6s">edu<span class="exa-x">X</span>action</span>
```

En Flutter esto vive en `lib/widgets/animated_logo.dart`:

- `_Wordmark`: "edu"/"action" en blanco (sin cambios).
- `_SweepingX`: `baseStyle.color` pasa de `AppColors.gold` a `Colors.white`; la
  `Shadow` del halo pasa a `Colors.white.withValues(alpha: .75)`.
- El `ShaderMask` del barrido cambia sus tres `colors` de `#FFF4EA` a
  `Color(0x00FFC107)` / `Color(0xF2FFC107)` / `Color(0x00FFC107)`, y el
  `AnimationController` de 2900 ms a 3600 ms.
- Hay que borrar el comentario de la regla "la X siempre en AppColors.gold — la X
  nunca cambia de tono, ni siquiera en hover, por regla de marca": esa regla queda
  reemplazada por la de esta tabla.
- El `assert(!compact || height >= 32)` y el resto del comportamiento (zoom,
  inclinación y resplandor en hover) se conservan; el resplandor de hover pasa de
  `gold.withValues(alpha: .35)` a `Colors.white.withValues(alpha: .28)`.
- `prefers-reduced-motion` / `disableAnimations` siguen apagando el barrido.
