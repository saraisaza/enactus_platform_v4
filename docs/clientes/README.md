# Clientes con marca propia

Cada cliente de la plataforma —una empresa, y también Enactus, que es el
cliente con laboratorios y Ruta de Impacto— puede tener su logo y su paleta.
Quien inicia sesión ve la plataforma con la marca de su cliente: el logo de
eduXaction siempre, el del cliente al lado, y los acentos en sus colores. La
tipografía y la estructura siguen siendo las de eduXaction.

El trabajo va por etapas, cada una probada en staging antes de la siguiente:

1. **Tema cambiable sin cambio visible** — hecha (esta guía).
2. Clientes en el panel de admin: nombre, logo, colores, vista previa.
3. Asignar cuentas a un cliente y aplicar su marca al iniciar sesión.
4. Portal del Manager / Supervisor.
5. Blindaje (aislamiento entre clientes) y producción.
6. Certificados con molde, para toda la plataforma.

## Cómo funciona el color

Todo color de marca sale de `Marca.instancia.paleta` (`lib/utils/marca.dart`):

| Se lee como | Es | Con eduXaction |
|---|---|---|
| `AppColors.gold` | `primario`: botones, íconos activos, foco, acentos | `#FFC107` |
| `AppColors.goldBright` | `primarioBrillante`: el botón con el mouse encima | `#FFCF3D` |
| `AppColors.ink` | `sobrePrimario`: texto e íconos encima del acento | `#21120A` |
| `ContentColors.dark.goldInk` | `tintaSobreOscuro`: la marca como texto en oscuro | `#FFC107` |
| `ContentColors.light.goldInk` | `tintaSobreClaro`: la marca como texto en claro | `#8A6A00` |
| `ContentColors.*.goldSoft` | fondo suave de marca | ámbar al 16 % / 24 % |

`Marca.instancia.aplicar(paleta)` repinta toda la app al instante, sin perder
lo que la persona tenía abierto; `restablecer()` vuelve a eduXaction.

La paleta de un cliente se arma con `PaletaMarca.desde(primario:, secundario:)`.
Los rellenos usan el color exacto que eligió el cliente; los usos como texto se
aclaran u oscurecen lo justo para llegar a 4.5:1 (AA de WCAG) sobre los fondos
de la plataforma. `test/marca_test.dart` lo exige sobre 666 tonos.

### Reglas

- **Un color de marca nunca va dentro de `const`.** Ya no es una constante; el
  compilador lo rechaza. Tampoco como valor por defecto de un parámetro: se
  deja `Color? color` y se resuelve al dibujar (`color ?? AppColors.gold`).
- **No guardar un color de marca en una variable `static final` ni en el
  estado de una pantalla**: se calcularía una vez y no seguiría a la marca.
- **El logo de eduXaction usa `AppColors.ambarEduXaction`**, que es fijo. El
  logo nunca toma el color de un cliente.
- **Los colores de dato no siguen a la marca**: gráficos, ODS, laboratorios y
  estados. `inkSobre` usa `AppColors.tintaOscura`, no `ink`.
- Los certificados PDF tienen su propia copia del ámbar (`PdfColor` no acepta
  un `Color`); se resuelven en la etapa 6.

## Comprobar que nada cambió de aspecto

`test/capturas/capturas_test.dart` toma 92 imágenes (cada pestaña de los nueve
portales en escritorio, cada portal en teléfono, las páginas públicas y el
modo claro del estudiante) y las compara píxel a píxel:

```
# en el código de partida
flutter test test/capturas --run-skipped --update-goldens
# con el cambio
flutter test test/capturas --run-skipped
```

Las imágenes dependen de cómo dibuja las letras cada sistema, así que no se
guardan en el repositorio ni corren en CI. Se comprobó que la comparación es
estable (cero diferencias sin cambios) y sensible (mover el ámbar de `#FFC107`
a `#FFC108` hace fallar las 92).
