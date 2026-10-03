# Lista para publicar eduXaction

Marque cada punto al terminarlo. El detalle de cada uno está en
[`PUBLICACION.md`](PUBLICACION.md) (número de sección entre paréntesis).

## Ya hecho en el código

- [x] App Android e iOS (identificador `com.eduxaction.app`), iPhone y iPad.
- [x] Navegación de teléfono: barra inferior, botón atrás, notch y barra de
      gestos; sin desbordes a 360 dp (con pruebas).
- [x] Sesión guardada en el almacenamiento seguro del teléfono.
- [x] Sin conexión: pantalla con Reintentar; al volver a la app se actualiza.
- [x] Video a pantalla completa con giro; PDF dentro de la app; fotos desde la
      cámara.
- [x] Eliminar la cuenta desde la app, cola de solicitudes para el equipo y
      borrado de datos (App Store 5.1.1(v), Google Play).
- [x] Foro: filtro de lenguaje, reportar, bloquear, normas aceptadas antes de
      publicar y cola de reportes (App Store 1.2).
- [x] Política de privacidad enlazada en el ingreso y en Mi cuenta.
- [x] Manifiesto de privacidad de iOS y textos de permisos en español.
- [x] Íconos y pantalla de arranque con la marca.
- [x] Script de compilación para las tiendas (`tool/build_movil.sh`).
- [x] La web sigue compilando igual.

## Decisiones y textos (equipo)

- [ ] Correo de soporte (lo usan la app, la ficha y las tres páginas).
- [ ] Aprobar la política de privacidad y completar sus [corchetes].
- [ ] Aprobar «Eliminar su cuenta», «Soporte» y las normas de la comunidad.
- [ ] Confirmar: plazo de 30 días, certificados sin nombre tras el borrado, y
      si hay participantes menores de edad.
- [ ] Quién revisa los reportes del foro (menos de 24 h) y la cola de
      eliminaciones (dentro de 30 días).

## Cuentas (equipo) (1)

- [ ] Número D-U-N-S de la entidad.
- [ ] Apple Developer Program como organización (USD 99/año; pedir exención).
- [ ] Google Play Console como organización (USD 25, una vez).

## Servidor y web (técnico) (2)

- [ ] Servidor y web en producción (migración `0009_moderacion_foro`, API y
      web; los despliega GitHub al subir a `main`, con aprobación manual).
- [ ] Páginas aprobadas movidas a `web/` y web desplegada.
- [ ] Cuentas de revisión creadas en producción (6).

## Computadora y firma (técnico) (3, 4)

- [ ] ~25 GB libres en el Mac.
- [ ] Xcode 26 con el componente iOS 26.
- [ ] Android Studio, licencias aceptadas, `flutter doctor` en verde.
- [ ] Llave de subida de Android creada y respaldada; `android/key.properties`.

## Fichas (equipo) (7)

- [ ] Textos, categoría y URLs.
- [ ] Capturas de iPhone, iPad y Android; gráfico destacado de Google.
- [ ] Formularios de privacidad (tabla de `DATOS_Y_PRIVACIDAD.md`).
- [ ] Clasificación por edad y público objetivo.

## Pruebas (8, 9, 10)

- [ ] Versión en TestFlight, probada por el equipo.
- [ ] Versión en la prueba interna de Google Play, probada por el equipo.
- [ ] Lista de la sección 10 completa en un iPhone y un Android reales.

## Envío (11)

- [ ] Apple: compilación elegida, cuenta de revisión y notas.
- [ ] Google: contenido de la app en verde, producción solo en Colombia.
