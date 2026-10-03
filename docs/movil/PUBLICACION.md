# Publicar eduXaction en App Store y Google Play

Guía paso a paso, en orden. Cada sección dice **quién** la hace: el **equipo**
(Enactus Colombia: cuentas, textos, decisiones) o la persona **técnica** (quien
compila y despliega). La lista corta para marcar está en
[`CHECKLIST.md`](CHECKLIST.md); los datos y la privacidad, en
[`DATOS_Y_PRIVACIDAD.md`](DATOS_Y_PRIVACIDAD.md).

Datos fijos de la app:

| | |
|---|---|
| Nombre | eduXaction |
| Identificador (Android e iOS) | `com.eduxaction.app`, **no se puede cambiar después de publicar** |
| Dispositivos | teléfonos Android; iPhone y iPad |
| Versiones mínimas | Android 7 (API 24); iOS 13 |
| Idioma | español |
| Precio | gratis, sin compras dentro de la app |
| Países recomendados para empezar | solo Colombia (ver «Por qué solo Colombia») |

---

## 1. Cuentas de desarrollador (equipo)

Las dos tiendas piden publicar **a nombre de la organización**, no de una
persona: así la app no depende de la cuenta de nadie, y en Google Play una
cuenta de organización se salta la prueba obligatoria de 14 días.

### Apple Developer Program

1. Pedir el **número D-U-N-S** de la entidad (gratis, en
   [dnb.com](https://www.dnb.com/duns-number/get-a-duns.html); tarda de 1 a 5
   días hábiles, a veces más en Colombia). Apple no deja inscribir una
   organización sin él.
2. Inscribirse en [developer.apple.com/programs](https://developer.apple.com/programs/enroll/)
   con un Apple ID de la organización (no personal), como **Organization**.
   Cuesta **USD 99 al año**. Las entidades sin ánimo de lucro pueden pedir la
   exención de la cuota; no está claro que aplique a Colombia, pero pedirla no
   cuesta nada.
3. En App Store Connect, invitar como usuarios a quienes vayan a probar con
   TestFlight y a quien compile.

### Google Play Console

1. Crear la cuenta en [play.google.com/console](https://play.google.com/console/signup)
   como **Organización**, con el D-U-N-S. Pago único de **USD 25**. Google
   verifica la identidad de la organización; puede tardar unos días.
2. Las cuentas **personales** creadas después de noviembre de 2023 tienen que
   hacer una prueba cerrada con al menos **12 personas durante 14 días
   seguidos** antes de poder publicar. Las de organización, no. Otra razón para
   usar la de organización.

### Por qué solo Colombia

Publicar en la Unión Europea obliga a declararse «comerciante» ante la Ley de
Servicios Digitales (DSA), con dirección y teléfono públicos en la ficha. La
app es para la red de Enactus Colombia: publicarla solo en Colombia evita ese
trámite. Se puede ampliar después.

---

## 2. Lo que tiene que estar listo ANTES de enviar la app (técnico)

La app nueva usa funciones del servidor que **todavía no están en
producción**. Si se envía a revisión antes, el revisor de Apple toca «Eliminar
mi cuenta» o «Reportar» y la app falla: rechazo seguro.

Orden de despliegue:

1. **Servidor y web.** Los despliega GitHub al subir a `main`
   (`.github/workflows/desplegar.yml`): pruebas, migración
   `0009_moderacion_foro` (dos tablas nuevas, puramente aditiva), API y web en
   staging con pruebas de humo, y luego **espera la aprobación** en GitHub ›
   Actions antes de hacer lo mismo en producción.
2. **Comprobar en producción** las rutas nuevas: eliminación de cuenta, cola de
   eliminaciones, reportes y bloqueos del foro.
3. **Publicar las páginas** `privacidad.html` y `eliminar-cuenta.html` (y
   `soporte.html`) una vez aprobadas: van en `web/` y salen con el despliegue
   de la web (`tool/desplegar_web.sh`). Ver
   [`DATOS_Y_PRIVACIDAD.md`](DATOS_Y_PRIVACIDAD.md#cómo-publicar-las-dos-páginas-cuando-estén-aprobadas).
4. **Crear las cuentas de revisión** (sección 6).

Comprobación rápida, ya en producción: entrar con una cuenta de revisión,
abrir Mi cuenta y ver «Eliminar mi cuenta»; abrir
`https://eduxaction.com/privacidad.html` desde el teléfono.

---

## 3. Preparar la computadora que compila (técnico)

Hace falta un Mac (iOS no se compila en otro sistema) con unos **25 GB
libres**. Hoy el Mac del proyecto tiene 7–8 GB: no alcanza.

1. **Xcode 26** o posterior, desde la App Store del Mac. Desde el 28 de abril
   de 2026 Apple solo acepta apps compiladas con el SDK de iOS 26. Abrirlo una
   vez, aceptar la licencia e instalar el componente **iOS 26** (Xcode ›
   Settings › Components).
2. **Android Studio** (trae el SDK de Android y Java). Al abrirlo, instalar el
   SDK que proponga. Después, en la terminal:
   ```
   flutter doctor --android-licenses
   flutter doctor
   ```
   `flutter doctor` tiene que mostrar en verde Flutter, Android toolchain y
   Xcode.
3. Clonar el repositorio y, en la carpeta del proyecto, `flutter pub get`.

---

## 4. Llave de firma de Android (técnico, una sola vez)

Google Play identifica a la app por la llave con que se firma. Se usa **Play
App Signing**: Google guarda la llave definitiva y nosotros solo una **llave
de subida**. Si la llave de subida se pierde, Google permite cambiarla; aun
así, guárdela bien.

1. Crear la llave (Java viene con Android Studio):
   ```
   "/Applications/Android Studio.app/Contents/jbr/Contents/Home/bin/keytool" \
     -genkey -v -keystore ~/eduxaction-subida.jks \
     -keyalg RSA -keysize 2048 -validity 10000 -alias subida
   ```
   Pide una contraseña y unos datos (nombre de la organización, ciudad, país
   `CO`).
2. Crear el archivo `android/key.properties` con:
   ```
   storePassword=<la contraseña>
   keyPassword=<la contraseña>
   keyAlias=subida
   storeFile=/Users/<usuario>/eduxaction-subida.jks
   ```
3. **Ni el `.jks` ni `key.properties` entran al repositorio** (`.gitignore` ya
   los excluye). Guarde una copia del `.jks` y de la contraseña en el gestor
   de contraseñas de la organización.

En iOS no hay que crear nada a mano: Xcode firma solo con la cuenta del equipo
(Runner › Signing & Capabilities › Team, con «Automatically manage signing»).

---

## 5. Compilar (técnico)

```
CORREO_SOPORTE=<correo de soporte> tool/build_movil.sh android <número>
CORREO_SOPORTE=<correo de soporte> tool/build_movil.sh ios <número>
```

- `<número>` es el número de compilación: **1** la primera vez, y cada subida
  siguiente uno mayor (2, 3…), en cada tienda. Si se repite, la tienda la
  rechaza.
- La versión que ve la gente (`1.0.0`) está en `pubspec.yaml`, antes del `+`.
  Se sube cuando cambia algo visible: `1.0.1` para arreglos, `1.1.0` para
  funciones nuevas.
- El script apunta la app a `https://api.eduxaction.com`, la ofusca y deja los
  símbolos en `build/simbolos/`. Guarde esa carpeta con cada versión: sin
  ella, los reportes de fallos de las tiendas son ilegibles.

Resultado: `build/app/outputs/bundle/release/app-release.aab` (Android) y
`build/ios/ipa/*.ipa` (iOS).

### Íconos y pantalla de arranque

Ya están generados a partir del logo. Si cambia el logo:
`python3 tool/generar_iconos.py`. Los íconos para las fichas quedan en
`docs/movil/tienda/` (`icono-google-play-512.png`, `icono-1024.png`).

### Videos en WebM

iPhone y iPad no reproducen WebM. El servidor ya solo acepta MP4 para videos
nuevos; un WebM subido antes se convierte así y se vuelve a subir:

```
ffmpeg -i video.webm -c:v libx264 -preset medium -crf 23 \
  -c:a aac -b:a 128k -movflags +faststart video.mp4
```

---

## 6. Cuentas de revisión (equipo)

La app no se usa sin iniciar sesión, así que **las dos tiendas exigen una
cuenta para revisarla**, que no venza y que muestre la app con contenido.

Crear en producción, desde el panel de administración › Usuarios › Nuevo
usuario, cuatro cuentas de **Estudiante Enactus**, asignadas a un laboratorio
con cursos y Ruta de Impacto, y con una universidad:

| Cuenta | Para |
|---|---|
| `revision.apple@<dominio de la organización>` | Revisión de Apple |
| `revision.apple.2@<dominio>` | Que Apple pruebe «Eliminar mi cuenta» sin borrar la principal |
| `revision.google@<dominio>` | Revisión de Google |
| `revision.google.2@<dominio>` | Igual que la de Apple |

Contraseñas largas, guardadas en el gestor de la organización. El correo no
tiene que existir: solo se usa para entrar. Después de cada revisión,
comprobar que siguen activas; si un revisor eliminó una, crear otra.

---

## 7. Fichas de las tiendas (equipo)

### Textos (borrador)

- **Nombre:** eduXaction
- **Subtítulo (Apple, 30 caracteres):** Formación Enactus Colombia
- **Descripción corta (Google, 80 caracteres):** La plataforma de formación de
  la red Enactus Colombia: cursos, Ruta y comunidad.
- **Descripción larga:**
  > eduXaction es la plataforma de formación de Enactus Colombia. Si usted es
  > estudiante de la red, aquí encuentra sus cursos, avanza en la Ruta de
  > Impacto con su equipo, entrega sus actividades, recibe la retroalimentación
  > de sus mentores y descarga sus certificados. En el foro de la comunidad
  > puede preguntar, compartir avances y conocer lo que hacen otros equipos de
  > todo el país.
  >
  > La app es para personas con una cuenta de la red Enactus Colombia: la crea
  > el equipo de Enactus o la organización que le invitó.
- **Palabras clave (Apple, 100 caracteres):**
  `enactus,emprendimiento,cursos,universidad,impacto social,formación,mentoría`
- **Categoría:** Educación.
- **URL de privacidad:** `https://eduxaction.com/privacidad.html`
- **URL de soporte (Apple):** `https://eduxaction.com/soporte.html`
- **URL para eliminar la cuenta (Google):**
  `https://eduxaction.com/eliminar-cuenta.html`

### Capturas de pantalla

Tomarlas con una cuenta de revisión, en el simulador o un teléfono real, de:
inicio del estudiante, un curso, una lección con video, la Ruta de Impacto,
el foro y un certificado.

| Tienda | Tamaño |
|---|---|
| App Store, iPhone | 6,9" (1320 × 2868), de 3 a 10 capturas |
| App Store, iPad | 13" (2064 × 2752), de 3 a 10 capturas |
| Google Play, teléfono | de 2 a 8 capturas, vertical (p. ej. 1080 × 1920) |
| Google Play, gráfico destacado | 1024 × 500, obligatorio |

### Privacidad

Las respuestas de los formularios (etiquetas de App Store y Seguridad de los
datos de Google Play) están en la tabla de
[`DATOS_Y_PRIVACIDAD.md`](DATOS_Y_PRIVACIDAD.md#1-qué-datos-recoge-la-app).
Resumen: no hay rastreo ni publicidad; los datos van ligados a la cuenta y se
usan solo para el funcionamiento de la app; viajan cifrados; la persona puede
borrarlos.

### Clasificación por edad

- **Apple** (cuestionario nuevo de 2025): responder «sí» a contenido generado
  por las personas (el foro); no hay chat privado, compras, juegos de azar,
  contenido sexual ni violento. El resultado esperado es **13+**.
- **Google** (cuestionario IARC): categoría «Educación»; «las personas pueden
  interactuar» = sí (foro); «comparte la ubicación» = no.
- **Público objetivo en Google Play:** 18 años o más, salvo que haya
  participantes menores de edad (ver la decisión pendiente en
  `DATOS_Y_PRIVACIDAD.md`). Si los hay, la ficha entra en las reglas de
  familias de Google, que piden más.

### Pagos

La app **no cobra nada**: no hay venta de cursos ni donaciones en el código.
Si algún día se agregan: Apple exige su sistema de compras para vender
cursos, y las donaciones solo pueden ir con un enlace a Safari; Google exige
Play Billing para cursos y prohíbe usarlo para donaciones.

---

## 8. Probar en iPhone con TestFlight (equipo y técnico)

TestFlight es la forma de Apple de instalar versiones de prueba antes de
publicar.

1. **Registrar el identificador** (técnico): en
   [developer.apple.com](https://developer.apple.com/account/resources/identifiers/list),
   Identifiers › + › App IDs › `com.eduxaction.app`.
2. **Crear la app** en [App Store Connect](https://appstoreconnect.apple.com)
   › Apps › + › Nueva app: plataforma iOS, nombre eduXaction, idioma
   principal **Español (México)** (es el español latinoamericano de la tienda),
   identificador `com.eduxaction.app`, SKU `eduxaction-ios`.
3. **Compilar y subir** (técnico): `tool/build_movil.sh ios 1`, y subir el
   `.ipa` con la app **Transporter** (gratis en la App Store del Mac).
4. Esperar a que diga «Listo para probar» (de 15 a 30 minutos). No pregunta
   por cifrado: `Info.plist` ya declara que la app solo usa HTTPS.
5. **Prueba interna** (sin revisión de Apple): TestFlight › Pruebas internas ›
   + › agregar a las personas del equipo que ya son usuarios de App Store
   Connect (hasta 100). Les llega un correo; instalan la app **TestFlight** y
   desde ahí, eduXaction.
6. **Prueba externa** (opcional, hasta 10 000 personas por correo o enlace
   público): la primera versión pasa por una revisión corta de Apple (alrededor
   de un día). Pide «Qué probar», un correo de contacto y la cuenta de
   revisión.

Qué probar: la lista de la sección 10.

---

## 9. Probar en Android con la prueba cerrada de Google Play (equipo y técnico)

1. **Crear la app** en Play Console › Crear app: nombre eduXaction, idioma
   **Español (Latinoamérica) – es-419**, app, gratuita.
2. **Contenido de la app** (Play Console › Política › Contenido de la app),
   todo obligatorio antes de publicar:
   - Política de privacidad: la URL de la sección 7.
   - **Acceso a la app:** «Todas o algunas funciones están restringidas» →
     cuenta y contraseña de `revision.google@…`, con la instrucción «Inicie
     sesión con estos datos».
   - Anuncios: no.
   - Clasificación de contenido: el cuestionario de la sección 7.
   - Público objetivo: ver sección 7.
   - Seguridad de los datos: la tabla de `DATOS_Y_PRIVACIDAD.md`.
   - Eliminación de cuenta: sí, desde la app, y la URL de `eliminar-cuenta`.
   - App de noticias, de gobierno, financiera, de salud: no.
3. **Prueba interna** (la más rápida, sin revisión): Prueba › Prueba interna ›
   Crear versión › subir el `.aab` (técnico: `tool/build_movil.sh android 1`).
   Aceptar **Play App Signing** cuando lo proponga. En Testers, crear una lista
   con los correos de Gmail de las personas del equipo (hasta 100) y
   compartirles el **enlace de participación**: lo abren en el teléfono,
   aceptan, y la instalan desde Google Play.
4. **Prueba cerrada**: igual, en Prueba › Prueba cerrada. Con cuenta de
   organización no hay mínimo de personas ni de días; con cuenta personal,
   12 personas durante 14 días seguidos antes de poder pasar a producción.
5. **Producción:** Producción › Crear versión, con el mismo `.aab` ya probado;
   en Países, solo **Colombia**. Google la revisa (de unas horas a varios días
   la primera vez).

---

## 10. Qué probar antes de enviar a revisión (equipo)

En un iPhone y en un Android reales, con una cuenta de revisión:

- [ ] Abre con la pantalla oscura del logo, sin destello blanco.
- [ ] Entrar, cerrar la app, volver a abrirla: sigue la sesión.
- [ ] Sin internet: muestra «Sin conexión» con Reintentar, no una pantalla
      vacía.
- [ ] El botón atrás de Android y el gesto de iOS vuelven atrás; desde el
      inicio, atrás sale de la app.
- [ ] Nada queda debajo del notch ni de la barra de gestos.
- [ ] Una lección con video: se ve, gira a horizontal y la pantalla no se
      apaga mientras reproduce.
- [ ] Un PDF se abre dentro de la app, con Compartir.
- [ ] Entregar una actividad con una foto de la cámara.
- [ ] Foro: publicar (pide aceptar las normas la primera vez), responder,
      reportar y bloquear a alguien.
- [ ] Mi cuenta › Política de privacidad abre la página.
- [ ] Mi cuenta › Acerca de eduXaction muestra el correo de soporte.
- [ ] Mi cuenta › Eliminar mi cuenta, con la cuenta `.2`: pide la
      contraseña, confirma y vuelve al ingreso. La solicitud aparece en
      Administración › Usuarios.
- [ ] En una tableta o iPad, la navegación lateral y nada desbordado.

---

## 11. Enviar a revisión (equipo)

### Apple

App Store Connect › la app › versión 1.0 › completar ficha, capturas y
privacidad › elegir la compilación probada en TestFlight › **Información para
la revisión**: la cuenta `revision.apple@…` y estas notas (en inglés, que es
lo que lee el revisor):

> eduXaction is the learning platform of Enactus Colombia, a non-profit
> network of university students. Accounts are created by the organization;
> there is no public sign-up. Please sign in with the demo account above.
>
> Account deletion: Account menu (top-right avatar) › "Eliminar mi cuenta".
> To test it without losing access, please use the second account:
> revision.apple.2@… / <password>.
>
> User-generated content (Guideline 1.2): the community forum ("Foro") has a
> profanity filter, "Reportar" (report) and "Bloquear" (block user) in the
> ⋮ menu of every post and reply, community guidelines that users accept
> before posting, and a moderation queue for administrators, who are notified
> of every report and review them within 24 hours. Contact: <support email>.

Si Apple rechaza, responde en el Centro de resoluciones con la guía exacta;
se corrige y se vuelve a enviar con un número de compilación mayor.

### Google

Play Console › Producción › Enviar versión a revisión, con todo el «Contenido
de la app» en verde.

---

## 12. Después de publicar

- **Cada actualización:** subir el número de compilación y, si cambia algo
  visible, la versión; compilar, probar en TestFlight y en la prueba interna, y
  enviar. Las dos tiendas aceptan publicación gradual.
- **Requisitos con fecha:**
  - Google sube cada año el `targetSdk` mínimo (hoy 36, desde el 31 de agosto
    de 2026). Se resuelve actualizando Flutter.
  - Apple exige el SDK nuevo cada abril: Xcode al día.
  - Desde abril de 2027 Google pedirá «restaurar credenciales» al cambiar de
    teléfono (Credential Manager).
- **Moderación y eliminación de cuentas:** los compromisos del equipo están en
  [`DATOS_Y_PRIVACIDAD.md`](DATOS_Y_PRIVACIDAD.md).
- **Reportes de fallos:** las dos consolas muestran los fallos de la app. Para
  leerlos hacen falta los símbolos de `build/simbolos/` de esa versión. Si se
  quiere más detalle, se puede agregar Sentry (tiene plan gratuito); no está
  incluido.
