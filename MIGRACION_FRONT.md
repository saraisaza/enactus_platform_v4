# Migración del frontend a la API (Fase 5)

Estado al cierre del portal Estudiante.

| | |
|---|---|
| `flutter analyze` | **0 issues** |
| `flutter test` | **179/179** |
| `flutter build web --release` | ✅ |
| Backend | **476/476**, `typecheck` y `lint` limpios |
| Recorrido real contra el backend vivo | ✅ contrato + flujos de punta a punta |

---

## Qué cambió de fondo

La app leía Hive de forma **síncrona**: cualquier pantalla podía preguntar
cualquier cosa y recibir la respuesta en el mismo `build()`. Con una API eso
deja de ser cierto, y el cambio no es cosmético — toca las tres capas.

### 1. Los getters siguen siendo síncronos, pero devuelven estado

`DataProvider.courses` no devuelve `List<Course>` ni `Future<List<Course>>`,
sino `AsyncValue<List<Course>>`. Un `Future` habría obligado a un
`FutureBuilder` en cada `build()`, y un `FutureBuilder` se vuelve a disparar en
cada reconstrucción salvo que se cachee el future a mano: con ~300 puntos de
lectura, son 300 oportunidades de meter un bucle de peticiones.

Es **un solo patrón**, sin variantes:

```dart
data.courses.when(
  loading: () => const CardListSkeleton(),
  error: (e) => ErrorState(e, onRetry: data.reloadCourses),
  data: (courses) => CourseGrid(courses),
)
```

Las tres ramas son obligatorias. No se puede olvidar el error.

### 2. La completitud se fue del cliente

Desbloqueo de fases, módulos completos, objetivos cumplidos, estado de cada
fecha límite: todo eso se calculaba en el navegador, en cada `build()`. Ahora
lo resuelve PostgreSQL —las mismas vistas que deciden si se puede emitir un
certificado— y la pantalla solo elige cómo decirlo.

No es solo higiene: la tarjeta de una fase y el riel de fases de al lado
calculaban lo mismo por separado y **podían contradecirse**.

### 3. El cliente no persiste nada

Hive se fue entero. Lo único que sobrevive a una recarga son los dos tokens, en
`shared_preferences`. No hay dos fuentes de verdad.

---

## Endpoints que hubo que construir

Ninguno existía al empezar. Cada uno apareció porque una pantalla lo
necesitaba, y se documentan acá porque marcan dónde la API estaba incompleta:

| Endpoint | Por qué |
|---|---|
| `GET /site-content` | La portada es pública y no había forma de traer su contenido |
| `GET /forum-posts/stats` | Los agregados del foro recorrían todos los posts y usuarios en memoria |
| `GET /auth/me` con `team` y `sponsorName` | El equipo salía de `extra['groupId']`; el patrocinador no se podía mostrar |
| `PATCH /auth/me` | No había forma de editar el propio perfil |
| `GET /courses` con `laboratoryName`, `creatorName`, `include=progress` | La grilla habría hecho **tres peticiones por tarjeta** |
| `POST /files/download-url` | Sin esto el cliente guarda keys de S3 pero **no puede mostrar nada** |
| `POST /lessons/:id/quiz-attempt` | El quiz se calificaba en el navegador, con la clave de respuestas dentro |
| `GET /laboratories/:id` con mentores, LXD y agregado | La pantalla listaba TODOS los usuarios para saber quién era mentor |
| `GET /laboratories?scope=all` | "Otros laboratorios de la red" no tenía de dónde salir |
| `GET /groups/:id` con checklist | La tabla existía desde la Fase 1; ningún endpoint la exponía |
| `GET /projects?include=teams` | El directorio cruzaba todos los equipos de la plataforma en el navegador |
| `/students/:id/ruta-progress` con descripción de fase y lecturas propias | El módulo no tenía cómo listar su contenido |

---

## Lo que la migración **corrigió**, no solo trasladó

Son cambios de comportamiento, no de forma. Cada uno era un problema real que
Hive escondía porque el navegador tenía todos los datos de todo el mundo.

1. **El quiz se calificaba en el cliente.** El curso viajaba al navegador con
   `answerIndex` y `answerText` dentro: cualquiera podía leer las respuestas
   desde las herramientas de desarrollo, y la nota que el cliente reportaba se
   guardaba sin verificar. Ahora la clave no sale de la base.

2. **El buscador del encabezado enumeraba a toda la plataforma** con
   universidad y carrera, desde cualquier rol. Acotado a cursos y proyectos.

3. **El detalle de proyecto mostraba el avance de cada integrante.** Leer la
   Ruta de otra persona exige ser su mentor, asesor o admin — el servidor
   responde 403. Se quitó.

4. **`PATCH /auth/me` no acepta `role`, `studentType` ni `canGrade*`.** Si los
   aceptara, cualquiera se ascendería mandando un campo de más.

5. **Un `catch` del foro** mostraba *"No se pudo publicar"* para cualquier
   fallo. Ahora muestra el motivo: "sin conexión" y "tu cuenta es de Open
   Learning" piden cosas distintas de quien lo lee.

---

## Bugs que encontraron las pruebas (no la compilación)

Todos habrían llegado a producción con `flutter build` en verde.

1. **`projectStages` tenía las etiquetas en español** (`'Ideación'`) y se
   comparaba contra `Project.stage`, que ahora es el identificador de la API
   (`'ideation'`). El filtro por etapa no habría encontrado **nunca** nada y el
   riel se habría quedado siempre en la primera fase. Sin fallar ni avisar.

2. **`odsNumberFrom` esperaba `'ODS 6: Agua limpia…'`** y la API manda
   `'ods_6'`. Todos los acentos por ODS habrían caído al dorado por defecto.

3. **La sesión no se restauraba en enlaces profundos.** `restoreSession()`
   vivía en la pantalla de arranque, que **no se monta** cuando Flutter web
   entra por una URL directa (`/admin`, un enlace compartido). El guardia de
   rol espera a que `isRestoring` sea falso y nadie lo cambiaba: la ruedita
   giraba para siempre.

4. **El registrante de plugins estaba desactualizado en la caché de build**, y
   `shared_preferences` no quedaba registrado: la app arrancaba y fallaba al
   leer la sesión. Un `flutter clean` lo arregla, pero se hizo además que
   `TokenStore` **degrade a "sin sesión guardada"** en vez de lanzar — el caso
   real es una ventana privada o un navegador con los datos de sitio
   bloqueados.

5. **`CardSkeleton` desbordaba** con alturas chicas. Un esqueleto roto es peor
   que no poner ninguno.

6. **`POST /auth/login` devolvía el usuario sin equipo.** Recién entrada la
   persona a su portal, el perfil se veía sin equipo ni proyecto hasta que algo
   volviera a pedir `/auth/me`. Lo detectó la prueba de punta a punta.

7. **Una firma de S3 fallida salía como 500.** Con credenciales vencidas —el
   caso normal de una sesión SSO— quien lo recibía no podía distinguir "el
   servidor está roto" de "el almacenamiento no está disponible". Ahora es un
   503 `storage_unavailable`.

---

## Cómo se verifica

```bash
# Backend
cd backend && npm run typecheck && npm run lint && npm test

# Cliente
flutter analyze && flutter test

# Recorrido contra el backend real (se salta solo si está apagado)
cd backend && npm run db:reset && npm run dev
flutter test -t e2e
```

Las pruebas de widget (`test/navigation_test.dart`) corren contra un cliente
HTTP falso con payloads de la **forma real** de la API, así que ejercitan el
`ApiService` de verdad: si el backend cambia de forma, fallan por la misma
razón por la que fallaría la app.

### `e2e_provider_contract_test.dart` — por qué existe

Toca **cada** lectura del provider con **cada uno** de los nueve roles y exige
que ninguna responda error. Una lista vacía está bien —eso es alcance, y es lo
correcto para muchos roles—; un 400 no.

Existe por dos errores del mismo tipo que ninguna otra prueba veía: `users()` y
`calendarEvents` pedían `pageSize: 200` cuando el tope del servidor es 100, así
que respondían 400 **siempre**. Compilaba, el análisis estático no decía nada,
y las pruebas del backend pasaban porque nunca mandaban ese número. Quedaban
sin datos el buscador del encabezado, el selector de patrocinador y el
calendario de los cuatro portales que lo muestran.

La forma de que no vuelva a pasar no es acordarse.

---

## Estado por portal

| Portal | Estado |
|---|---|
| Público (portada, ingreso) | ✅ Migrado |
| **Estudiante / Alumni** | ✅ **Migrado y verificado de punta a punta** |
| **LXD** | ✅ **Migrado y verificado de punta a punta** (incluye el constructor de cursos y de lecciones) |
| **Admin / Super Admin** | ✅ **Migrado** |
| **Mentor** | ✅ **Migrado** |
| **Asesor** | ✅ **Migrado** |
| **Empresa** | ✅ **Migrado** |
| **Donante** | ✅ **Migrado** |

Ya no queda ningún portal diferido: `migration_pending/` desapareció.

Dos pantallas del original no se migraron porque **dejaron de existir**, no
porque falten: `StudentDetailView` se fusionó con el perfil de persona (la
separación ya no significaba nada — quién ve qué lo decide el servidor), y
`LabProgressView` y el diálogo de vincular a la Ruta quedaron dentro del
perfil y del editor de Ruta respectivamente.

---

## Lo que falta

- **Nada de la migración.** Los ocho portales están en `lib/` y se dibujan.
- **Reproducción de video: cerrada** — ver la sección propia más abajo.
- **Barra de progreso de subida: parcial.** Ver "Lo que quedó a medias".
- **Pasada de tipografía: inventario hecho, migración no.** Ver "Lo que quedó a
  medias".
- Fase 6: infraestructura, la distribución de CloudFront, RDS a subred privada,
  OIDC.

---

## Reproducción de video ✅

Los dos orígenes, cada uno como corresponde:

| Origen | Cómo se reproduce |
|---|---|
| `external` | `<iframe>` de `youtube-nocookie.com` / `player.vimeo.com` en el navegador; fuera del navegador se abre en la app del sistema |
| `uploaded` | `GET /lessons/:id/video-url` → URL firmada de CloudFront (5 min) → `<video>` HTML5 |

**`video_source_io` / `video_source_web` estaban huérfanos.** Nadie los
importaba y seguían apuntando a `course_resources/`, la carpeta local de la era
Hive. Se extendieron en vez de reemplazarlos: la mitad que de verdad cambia
entre plataformas es el iframe —solo existe en el navegador— así que el par
sigue teniendo razón de ser, ahora con `createSignedVideoController(url)` y
`buildEmbeddedVideo(embedUrl)`.

**El enlace que la gente pega no se puede embeber.** `youtube.com/watch?v=…`
responde `X-Frame-Options` y el iframe queda gris, sin ningún error. Por eso
`embedUrlFor()` convierte a la URL de *embed* y devuelve `null` para lo que no
reconoce, en cuyo caso se ofrece abrir el enlace afuera — nunca se embebe a
ciegas. Es la función con más casos raros del reproductor y la que falla en
silencio, así que tiene 19 pruebas propias (watch, youtu.be, shorts, embed,
móvil, con parámetros, Vimeo con y sin canal, y seis formas de basura).

**Se usa `youtube-nocookie.com`**: no deja cookies de seguimiento hasta que
alguien da play.

### Un error que se estaba tragando la API

`ServerError` fijaba `code: 'internal_error'` y **descartaba el código del
servidor**. El backend distingue a propósito sus 503 —`cdn_not_configured`,
`storage_not_configured`, `storage_unavailable`— y dice *qué* falta; el cliente
lo aplastaba todo en "El servidor tuvo un problema. Probá de nuevo".

La pantalla no podía diferenciar "esto no está configurado en este entorno"
(reintentar no sirve nunca) de "se cayó un momento" (reintentar sí sirve), que
es exactamente para lo que existen los errores tipados. Ahora el `code` viaja
hasta la pantalla, y el reproductor **no ofrece reintentar** ante un 503 de
configuración: mandar a alguien a apretar un botón que no puede funcionar es
peor que no ofrecerlo.

### Verificado contra el servidor real

Con el backend local (sin CloudFront), `e2e_provider_contract_test` exige que
el error llegue como `cdn_not_configured` con el mensaje que nombra la
variable — no como `internal_error`. Antes del arreglo esa prueba fallaba.

Y con un backend levantado con una llave de firma temporal (fuera del repo), el
cliente recibe la URL firmada de verdad:

```
BASE = http://localhost:3099
URL FIRMADA -> https://videos.enactus.co/lab_impacto/curso_medicion_impacto/
               leccion_1.mp4?Expires=1788277118&Signature=ehDhfj3X…&
               Key-Pair-Id=KTESTLOCAL01
```

**Lo que NO está verificado**: que el `<video>` y el `<iframe>` pinten de
verdad. `video_player` necesita el plugin de la plataforma, que en
`flutter test` no existe, y montar un doble probaría el doble. Para el video
propio hace falta además la distribución de CloudFront, que todavía no existe:
la URL está bien firmada pero apunta a un dominio que no responde. Queda
anotado como pendiente de comprobación en navegador, no dado por hecho.

---

## Barra de progreso de la subida ✅

`onProgress` avanzaba en dos tramos —0 al empezar, 1 al terminar— porque
`package:http` no expone el avance de envío. Con el tope de 500 MB que acepta
la API, eso son varios minutos de barra congelada en 0: indistinguible de una
subida colgada.

Ahora informa por bytes, con el mismo patrón io/web que el video:

- **Navegador** (`upload_web.dart`): `XMLHttpRequest.upload.onprogress`. El
  `BrowserClient` de `package:http` usa `fetch`, que no informa progreso de
  envío en ningún navegador — por eso hay que bajar a XHR.
- **Escritorio** (`upload_io.dart`): `StreamedRequest` emitiendo el cuerpo en
  trozos de 64 KB.

**El 100% se emite al confirmar, no con el último trozo.** El progreso dice que
los bytes salieron, no que S3 los aceptó: la subida todavía puede fallar con la
firma vencida. La mitad io lo hacía mal —emitía `1.0` dos veces— y lo encontró
la prueba que compara las dos mitades.

Las pruebas levantan un servidor HTTP real y verifican que el archivo llegue
entero y byte a byte, que el progreso sea monótono y dentro de `[0,1]`, y que
un 403 llegue como `ServerError` mientras que un puerto muerto llegue como
`NetworkError` — distinguirlos importa, porque reintentar sirve para uno y no
para el otro.

### Y una prueba que salía a internet

Las dos pruebas de subida de `api_service_test.dart` usaban un `MockClient`
apuntando a `bucket.s3.amazonaws.com`. Al dejar la subida de pasar por el
cliente inyectado, el mock dejó de interceptar: una falló, y **la otra siguió
"pasando" porque salía a internet de verdad** y S3 respondía 403 a un pedido
sin firma. Una prueba unitaria que depende de la conexión y de un tercero no
prueba lo que dice probar. Ahora las dos van contra un servidor local.

---

## Tipografía: Knockout 92 y Space Grotesk NO se distribuyen

El handoff especifica Knockout 92 (display) y Space Grotesk (UI) pantalla por
pantalla, y en algún momento los archivos estuvieron en el repositorio. **Ya no
están, y no deben volver**: se eliminaron a propósito.

El motivo es de licencia, no de diseño. Knockout es una tipografía comercial de
Hoefler&Co y un build web publica el archivo como descarga abierta para
cualquiera que abra la página — embeberla sin licencia de webfont es
distribuirla.

| Rol | Fuente que se distribuye | Licencia |
|---|---|---|
| Display (títulos) | **Oswald** | OFL |
| Interfaz (todo lo demás) | **DM Sans** | OFL |
| Wordmark "eduXaction" | Manrope | OFL |

Se eliminaron las seis copias que quedaban: `assets/media/knockout/`,
`assets/media/space_grotesk/` y las cuatro dentro de
`assets/design_handoff_*/assets/media/`. Nada en `lib/` las nombra: los
identificadores pasaron de `knockoutHeading` / `knockoutTracking` /
`kKnockoutTrackingRatio` a `displayHeading` / `displayTracking` /
`kDisplayTrackingRatio`, para que ninguna API pública se llame como una fuente
que no se puede usar.

Los valores del tema están **afinados a Oswald**, no al handoff:

- **Peso `w700`.** El diseño pide SemiBold (600) pero `assets/media/oswald/`
  solo trae Light/Regular/Bold. Se usa el peso real más cercano en vez de dejar
  que Flutter sintetice un 600 falso, que engorda los trazos por software.
- **Tracking `0.014em`, no el `0.045em` del handoff.** Ese 0.045 está medido
  sobre Knockout; Oswald es más angosta y de altura-x más alta, y con 0.045 las
  mayúsculas quedan sueltas.

Los dos valores viven en un solo lugar (`AppFonts` y `kDisplayTrackingRatio`):
si algún día se compra la licencia, cambiarlos alcanza para toda la app.

### Colores fuera del tema

De los 10 `Color(0x…)` sueltos, **7 son legítimos**: los tres colores por tipo
de evento del calendario y los degradados del logo animado no son tokens de
marca reutilizables, son valores de un dibujo puntual. Los otros 3 sí
duplicaban tokens y ahora salen de `AppColors` (`animated_logo`,
`calendar_view`) o se expresan como lo que son (`colombia_map`: blanco al 86%,
no un hex opaco).

### Lo que queda inventariado, y por qué NO se migró

| Qué | Cuántos |
|---|---|
| `fontSize:` inline | 589 |
| `EdgeInsets` con números crudos | 345 |
| `BorderRadius.circular(N)` | ~150, con 9 valores distintos |

Son 589 puntos de cambio visual en ocho portales para un beneficio de
indirección, no de consistencia: los valores ya están concentrados en cuatro
tamaños (12, 12.5, 13, 13.5). Cambiarlos es exactamente lo que el pedido acota
con "no rediseñes nada". El inventario queda acá para decidirlo con números.

### El bug que quedó al descubierto por el camino

Al intentar el cambio de fuentes apareció un defecto que no dependía de cuáles
fueran, y que sigue corregido: **el texto de los botones se pintaba con la
fuente del sistema**, distinta en cada navegador. La causa: el `textStyle`
de un `ButtonStyle` **reemplaza** el estilo del botón en vez de fusionarse con
el `textTheme`, y el del tema no declaraba familia. Así que la etiqueta de cada
botón elevado de la plataforma se pintaba con lo que trajera el navegador —
distinto en cada uno.

No era el único: **ocho `TextStyle` del tema no declaraban familia** — botones,
tooltips, etiquetas y placeholders de los campos, encabezado y celdas de las
tablas, snackbars y chips. Los botones eran solo los que se veían en pantalla.
Todos corregidos.

Esto no lo detecta nada de lo que había: ni `flutter analyze`, ni el build, ni
las pruebas de maquetación. Un texto con la fuente equivocada ocupa un ancho
parecido y no desborda.

### `typography_test.dart` — cómo se comprueba ahora

Monta los nueve portales, recorre las once pestañas del Admin, y además la
portada y el ingreso (que no son portales y quedaban fuera). En cada pantalla
recorre el árbol ya renderizado y lee la familia **resuelta** de cada texto —
el `TextSpan` del `RichText`, después de mezclarse con el `DefaultTextStyle`.
Eso es literalmente lo que se pinta.

Falla si aparece cualquier familia que no sea Oswald, DM Sans, Manrope (solo el
wordmark, por reglas de marca) o las de íconos. **Y falla igual si no hay
familia**: heredar la del sistema es tan malo como la equivocada, solo que más
difícil de ver.

Además fija por escrito qué fuentes se distribuyen, así que si alguien vuelve a
agregar Knockout o Space Grotesk, falla en una línea en vez de descubrirse en
una revisión de licencias.

### Verificado

El bundle carga `Oswald`, `DMSans` y `Manrope`, y **ningún** archivo de
Knockout o Space Grotesk queda en `build/web`. Todo el texto de los nueve
portales, las once pestañas del Admin, la portada y el ingreso usa una de esas
tres. Y los portales se dibujan en tres anchos sin desbordamientos.

---

## Cómo se prueba que una pantalla se dibuja (y las tres veces que no se probó)

`test/portals_render_test.dart` monta el portal de los nueve roles en tres
anchos y recorre TODAS sus pestañas: 36 casos. Compilar no prueba que una
pantalla funcione — un `Row` que desborda es un fallo de ejecución.

La suite **pasó en verde tres veces sin probar nada**. Vale la pena dejar
escrito cómo, porque las tres formas son fáciles de repetir:

1. **`setSurfaceSize` fija píxeles físicos.** En `flutter_test` el
   `devicePixelRatio` es 3.0, así que "1440×900" eran **480×300 lógicos**,
   "768" eran 256 y "390" eran 130. Los tres anchos caían en `compact` y el
   caso de escritorio —la barra lateral de 230px con texto— no se ejecutó
   nunca. Se arregla fijando `devicePixelRatio = 1.0` y `physicalSize`.
2. **La sesión se borraba en el primer frame.** `EnactusApp.initState` llama
   `restoreSession()` tras el primer frame; sin token guardado eso hace
   `_setUser(null)` y el guardia de rol muestra el ingreso. Las 36 pruebas
   verificaban `LoginView`. Se arregla sembrando el token —que además
   ejercita el camino real de restauración— en vez de un atajo de pruebas:
   `debugSetSession` se eliminó de `AuthProvider`.
3. **El recorrido de pestañas hacía `return` si no encontraba la barra.** Y no
   la encontraba, por (1). Nueve pruebas verdes que no tocaban ninguna
   pestaña. Un `return` silencioso convierte "no pude probar" en "probé y está
   bien": ahora cualquier ausencia es `fail`.

De ahí que las afirmaciones sean explícitas —el portal está montado, el
ingreso NO está, ninguna pestaña quedó en estado de error—: sin ellas, "no
lanzó excepciones" también lo cumple una pantalla que nunca llegó a existir.

### Los payloads no se inventan: se capturan

`tool/capturar_payloads.py` graba las respuestas reales del backend sembrado
en `test/fixtures/api_payloads.json`, con la cuenta que de verdad puede ver
cada cosa. Una pantalla puede dibujarse perfecto con datos imaginarios y
romperse con los de verdad.

La API falsa **no tiene comodín**: una ruta sin fixture hace fallar la prueba
diciendo cuál falta. Antes respondía una página vacía para todo, y las
respuestas que no son páginas —la Ruta de Impacto, las métricas— reventaban en
su `fromJson`; la pantalla se dibujaba en **estado de error** y la prueba lo
contaba como éxito. También se reproducen los fallos reales tal cual: hoy
`/files/download-url` responde 503 porque S3 no está configurado en este
entorno, y así se guarda — fingir un 200 probaría una pantalla que nadie ve.

### Lo que apareció al mirar de verdad

| Dónde | Qué |
|---|---|
| `CardSkeleton` | Desbordaba toda tarjeta baja. El borde de 1px de un `BoxDecoration` mete su grosor hacia adentro: el hueco real es 34 menos, no 32 — y el título de 18px no cabía con `height: 44`. Se veía justo mientras alguien esperaba. |
| `StatusChip` | La etiqueta pedía su ancho natural dentro de un `Wrap`; un rótulo largo en una tarjeta angosta desbordaba. |
| `StageRail` | Las dos leyendas ("Etapa 2 de 6" / "Sigue: Validación") sin flex, en una tarjeta de grilla más estrecha que su suma. |
| **Los 23 desplegables** | Sin `isExpanded`, un `DropdownButtonFormField` se dimensiona al ítem **más ancho de su lista**, no al ancho que se le dio: un nombre largo de estudiante desbordaba el campo por 87px. Con nombres cortos no se ve; aparece con los reales. |

### El otro hueco: las lecturas por id

`e2e_provider_contract_test` solo tocaba los getters **sin** id, y eso dejaba
fuera justo las pantallas de detalle: la Ruta de Impacto, el avance en un
curso, el perfil de una persona, un laboratorio, un proyecto, un equipo. Se
notó cuando `RutaProgress.fromJson` reventó con un `type 'Null' is not a
subtype of type 'String'` sin que ninguna prueba fallara. Ahora se prueban
contra el servidor real, con ids tomados de los listados —no inventados: un id
inventado daría 404 y la prueba pasaría sin ejercitar ningún parseo.

### Una intermitencia real, no un capricho del corredor

`flutter test` corre las suites e2e **en paralelo contra una sola base**, así
que otra suite puede crear o borrar un curso entre dos peticiones de esta. El
conteo de cursos comparaba un número con una página leída en otro instante y
fallaba sin que nada estuviera roto. Ahora la página va encerrada entre dos
conteos: uno de los dos abarca cualquier escritura ajena, y el invariante
—que el conteo no salga de `pagina.length`— sigue en pie.

### Pendiente de seguridad, fuera del código

Las credenciales de AWS en uso son **temporales y ya vencieron una vez a mitad
de sesión**. Antes de desplegar hace falta un usuario IAM con permisos
acotados al bucket, y borrar la llave de root.
