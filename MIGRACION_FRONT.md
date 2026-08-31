# Migración del frontend a la API (Fase 5)

Estado al cierre del portal Estudiante.

| | |
|---|---|
| `flutter analyze` | **0 errores, 0 warnings** (16 infos de estilo previos) |
| `flutter test` | **55/55** |
| `flutter build web --release` | ✅ |
| Backend | **240/240** |
| Recorrido real contra el backend vivo | ✅ 12 pruebas de punta a punta |

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
| Admin | ⏳ Diferido — la API ya está lista (ver abajo) |
| Mentor | ⏳ Diferido |
| Asesor | ⏳ Diferido |
| Empresa | ⏳ Diferido |
| Donante | ⏳ Diferido |

Los portales diferidos muestran una pantalla honesta de "disponible
próximamente" (`lib/views/public/pending_portal_view.dart`) en vez de datos
desactualizados. **Una función que no está es honesta; una que muestra datos
viejos, no.**

`migration_pending/` conserva los archivos con su código original y un README
que explica por qué no se parchearon para que compilaran.

---

## Lo que falta

- Los cinco portales diferidos, en orden: Admin → Mentor → Asesor → Empresa
  → Donante. **El servidor está terminado**: se auditaron los 75 métodos del
  provider que esos portales usan y los 75 tienen endpoint. Lo que falta de
  cada uno es la pantalla, no la API.

  Lo último que se construyó para cerrarlo: `/admin/metrics` (horas por
  competencia, cobertura de ODS, horas patrocinadas), `/talent`
  (BuscaTalento), `POST /notifications` (avisos), `include=reviews` en
  `/users`, autoría de laboratorios con su Ruta de Impacto, y el alta acotada
  de LXD/mentor desde una cuenta de empresa.
- **Reproducción de video**: un enlace externo ya se abre; un video propio dice
  claramente que necesita la distribución de CloudFront (Fase 6) en vez de
  quedarse cargando.
- Pasada de tipografía y consistencia, cuando todos los portales estén en
  verde.
- Fase 6: infraestructura, CloudFront con URLs firmadas, RDS a subred privada,
  OIDC.

### Pendiente de seguridad, fuera del código

Las credenciales de AWS en uso son **temporales y ya vencieron una vez a mitad
de sesión**. Antes de desplegar hace falta un usuario IAM con permisos
acotados al bucket, y borrar la llave de root.
