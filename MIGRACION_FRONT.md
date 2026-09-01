# Migración del frontend a la API (Fase 5)

Estado al cierre del portal Estudiante.

| | |
|---|---|
| `flutter analyze` | **0 issues** |
| `flutter test` | **133/133** (tres corridas seguidas, sin intermitencias) |
| `flutter build web --release` | ✅ |
| Backend | **453/453**, `typecheck` y `lint` limpios |
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

- **Reproducción de video**: un enlace externo ya se abre; un video propio dice
  claramente que necesita la distribución de CloudFront (Fase 6) en vez de
  quedarse cargando.
- Pasada de tipografía y consistencia, cuando todos los portales estén en
  verde.
- Fase 6: infraestructura, CloudFront con URLs firmadas, RDS a subred privada,
  OIDC.

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
