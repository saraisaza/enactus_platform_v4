# Datos y privacidad de eduXaction (app móvil)

Lo que la app recoge, cómo se borra y cómo se modera el foro. Sirve para tres
cosas: llenar los formularios de privacidad de App Store Connect y de Google
Play, aprobar los textos legales, y saber qué hacer cuando alguien pide borrar
su cuenta.

Si la app empieza a recoger un dato nuevo, hay que actualizar a la vez este
documento, `ios/Runner/PrivacyInfo.xcprivacy`, las etiquetas de privacidad de
App Store Connect, el formulario de Seguridad de los datos de Google Play y la
política de privacidad.

---

## 1. Qué datos recoge la app

No hay publicidad, analítica ni SDK de rastreo. Nada se vende ni se comparte
con terceros para publicidad. Todos los datos van ligados a la cuenta de la
persona.

| Dato | Dónde vive | Para qué | App Store (tipo) | Google Play (tipo) |
|---|---|---|---|---|
| Nombre | `users.name` | Cuenta, certificados | Contact Info › Name | Personal info › Name |
| Correo | `users.email` | Inicio de sesión | Contact Info › Email Address | Personal info › Email address |
| Teléfono | `users.phone` | Perfil | Contact Info › Phone Number | Personal info › Phone number |
| Id de la cuenta | `users.id` | Funcionamiento | Identifiers › User ID | Personal info › User IDs |
| Cédula, ciudad, universidad, carrera | `users.*` | Programa y certificados | Other Data Types | Personal info › Other info |
| Foto de perfil, evidencias, adjuntos | S3 (`avatars/`, `evidences/`, `submissions/`) | Perfil, entregas | User Content › Photos or Videos | Photos and videos › Photos |
| Publicaciones del foro, entregas, respuestas | Base de datos | Foro, calificación | User Content › Other User Content | App activity › Other user-generated content |
| Avance en cursos y lecciones | `progress*` | Mostrar el avance | Usage Data › Product Interaction | App activity › App interactions |
| IP de acciones sensibles | `audit_log.ip` | Seguridad | (no se declara: no sale del servidor ni se liga a perfiles) | — |

En todas: **propósito = funcionamiento de la app**; **ligado a la identidad =
sí**; **usado para rastreo = no**. En Google Play: los datos **se cifran en
tránsito** (HTTPS) y **la persona puede pedir que se borren** (sí, desde la app
y desde la web).

En el teléfono, la sesión vive en el almacenamiento seguro del sistema (Llavero
en iOS, Keystore en Android), no en preferencias en texto plano.

Terceros que procesan datos: **Amazon Web Services** (alojamiento, base de
datos y archivos, en EE. UU., como encargado) y, solo al reproducir un video
de una lección alojado allí, **YouTube o Vimeo**.

---

## 2. Eliminación de cuenta

Lo exigen App Store (guía 5.1.1(v)) y Google Play (en la app **y** en una
página web que funcione sin la app).

### Cómo la pide la persona

- **En la app o en la web:** Mi cuenta (la foto o la inicial, arriba a la
  derecha) › **Eliminar mi cuenta** › contraseña. Disponible para todos los
  roles.
- **Sin poder entrar:** escribiendo al correo de soporte desde el correo de su
  cuenta (lo explica `eliminar-cuenta.html`).

### Qué pasa en el servidor

1. `POST /auth/me/deletion-request` con la contraseña. La cuenta queda
   desactivada **en el acto**: borrado lógico, todas sus sesiones revocadas, y
   la solicitud anotada en `audit_log` (`user.deletion_requested`).
2. La solicitud aparece en el panel de administración, pestaña **Usuarios**,
   en el recuadro «solicitudes de eliminación de cuenta», con los días que
   quedan del plazo.
3. Alguien del equipo toca **Borrar datos** (`POST /users/:id/purge`). Eso:
   - deja la cuenta como «Cuenta eliminada», con un correo inventado e
     inservible y una contraseña con la que nadie puede entrar;
   - borra teléfono, cédula, ciudad, carrera, foto y perfil;
   - borra la **foto de perfil del bucket** de S3;
   - cambia el nombre impreso en sus certificados por «Cuenta eliminada»;
   - borra las notas del equipo sobre esa persona, sus notificaciones, sus
     sesiones y sus bloqueos en el foro;
   - lo anota en `audit_log` (`user.purged`), y la solicitud sale de la cola.

### Lo que se conserva, y por qué

- **Publicaciones del foro y entregas**, a nombre de «Cuenta eliminada»: son
  parte del trabajo de un equipo. Si la persona pide expresamente que se
  borren, se borran a mano.
- **Adjuntos de las entregas** en S3, por la misma razón.
- **El registro de auditoría**: dice que la cuenta existió y se borró, sin
  datos personales.

### Compromiso del equipo

- Revisar la cola **al menos una vez por semana** y borrar los datos dentro de
  los **30 días** prometidos. La cola marca en rojo las que vencieron.
- Si «Borrar datos» no pudo borrar la foto en S3 (por ejemplo, porque S3 no
  respondió), la clave queda anotada en `audit_log` (`newValue.avatarPendiente`
  de la acción `user.purged`) y hay que borrarla a mano:
  `aws s3 rm s3://<bucket>/<clave>`.
- Responder por correo a quien lo pidió por correo, confirmando que terminó.

---

## 3. Moderación del foro

App Store (guía 1.2) no publica una app donde las personas publican sin estas
cuatro cosas. Todas existen:

| Exige | Cómo está resuelto |
|---|---|
| Filtrar lo ofensivo **antes** de publicarlo | El servidor rechaza publicaciones y respuestas con insultos o expresiones de odio de una lista corta (`backend/src/lib/moderacion.ts`). |
| Reportar contenido | Menú ⋮ de cada publicación y respuesta › **Reportar**, con el motivo. |
| Bloquear a quien abusa | Menú ⋮ › **Bloquear a…**: deja de ver lo que esa persona publica. Se deshace en «Personas bloqueadas». Al equipo que modera no se le puede bloquear. |
| Contacto publicado | Mi cuenta › Acerca de eduXaction › Escríbanos (el correo se pasa al compilar). |

Además, antes de su primera publicación cada persona **acepta las normas de la
comunidad**, que dejan claro que no se tolera el contenido ofensivo ni el
abuso (lo que Apple pide como «términos de uso»).

### Compromiso del equipo

- Cada reporte nuevo genera una notificación para todos los administradores.
- Revisar los reportes **en menos de 24 horas** (es lo que Apple considera
  «a tiempo»). En el foro, un administrador ve el aviso «Hay N reportes sin
  atender» › **Revisar**.
- **Quitar del foro** borra el contenido y cierra todos los reportes de lo
  mismo; **Dejarlo** los cierra sin tocarlo. Queda en `audit_log`.
- Si alguien insiste en publicar contenido abusivo, se desactiva su cuenta
  desde Usuarios.

---

## 4. Textos que debe aprobar Enactus Colombia

Ninguno está publicado. Los borradores tienen entre [corchetes] los datos que
solo la organización conoce.

| Texto | Archivo | Falta |
|---|---|---|
| Política de privacidad | `docs/movil/paginas-web/privacidad.html` | Nombre legal, NIT, dirección, teléfono, correo, área responsable, fecha, plazo de las copias de seguridad, si hay participantes menores de edad. |
| Eliminar su cuenta | `docs/movil/paginas-web/eliminar-cuenta.html` | Correo de soporte. |
| Normas de la comunidad | `lib/widgets/normas_comunidad.dart` | Revisión del texto. |
| Avisos al eliminar la cuenta | `lib/widgets/cuenta.dart` | Revisión del texto (plazo de 30 días, qué se conserva). |

Decisiones de fondo que el texto da por tomadas, para confirmarlas:

1. **Plazo de 30 días** para borrar los datos.
2. **Los certificados dejan de mostrar el nombre** al borrar los datos. La
   alternativa —conservarlo para que un certificado siga siendo verificable—
   también es defendible, pero entonces hay que decirlo en la política.
3. **El foro y las entregas se conservan** sin nombre.

### Cómo publicar las dos páginas cuando estén aprobadas

1. Completar los corchetes y quitar el recuadro «BORRADOR» y la línea
   `<meta name="robots" content="noindex">`.
2. Mover los dos archivos a la carpeta `web/` del proyecto.
3. Compilar y desplegar la web como siempre (`tool/desplegar_web.sh`). Quedan
   en `https://eduxaction.com/privacidad.html` y
   `https://eduxaction.com/eliminar-cuenta.html`, que son las direcciones que
   ya usa la app (`lib/utils/constants.dart`, `LegalLinks`).

Tienen que vivir en `web/` y no subirse a mano al bucket: el despliegue de la
web sincroniza con `--delete`, y borraría cualquier archivo que no esté en
`build/web`.

Las páginas no llevan JavaScript a propósito: la política de seguridad (CSP)
del sitio solo deja correr los scripts de Flutter.

---

## 5. Lo que queda pendiente

- **Correo de soporte.** Sin él, la app no muestra la fila de contacto y la
  página de eliminación queda incompleta. Se pasa al compilar:
  `--dart-define=CORREO_SOPORTE=...` (lo hace `tool/build_movil.sh`).
- **Enlace a la política en la web.** La app la enlaza en el ingreso y en Mi
  cuenta. En la web todavía no, porque el texto no está aprobado; cuando lo
  esté, conviene agregarla al pie de página.
- **Formulario «Contáctenos» de la portada:** está en modo demostración, no
  envía nada y aun así dice «Mensaje enviado». No afecta a la app, pero
  contradice lo que la política promete sobre contacto.
