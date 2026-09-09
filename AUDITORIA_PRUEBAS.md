# Auditoría de pruebas — ¿cuáles son reales?

## Estado

| | |
|---|---|
| **Estado** | **ABIERTA** |
| Última actualización | **9 de septiembre de 2026** |
| Cifras al día | backend **575** · Flutter **218** · `typecheck`, `lint` y `flutter analyze` limpios |

Esta página dijo «Cerrada el 2 de septiembre de 2026» durante una semana, y en
esa semana se reabrió **tres veces**. Un documento que anuncia un cierre que no
es cierto es peor que no tenerlo: alguien lo abre, ve la fecha y confía.

La ironía no se nos escapa — **es un caso más del patrón que este mismo
documento nombra**: el continente decía «cerrada», el contenido decía otra
cosa. Por eso ahora hay un criterio escrito, y no una fecha.

### Criterio para cerrarla

Se cierra cuando **las cuatro** se cumplen a la vez. Sin criterio explícito una
auditoría se cierra por cansancio, que es como se cerró la anterior.

| | Condición | Hoy |
|---|---|---|
| 1 | Cero mutaciones falsas | ✅ las 3 cerradas y re-verificadas |
| 2 | Las débiles críticas, con segunda red independiente | ✅ las 5, el 9-sep |
| 2b | Todo guardia de autorización, probado sobre su endpoint **real** | ✅ barrido del 9-sep: 79 aplicaciones |
| 3 | Los cinco puntos ciegos, cada uno con su prueba | ⬜ falta el de contrato cliente↔servidor |
| 4 | Las cifras de arriba coinciden con correr las suites | ✅ comprobado el 9-sep |

Mientras falte cualquiera, el encabezado dice **ABIERTA**.

---

## Registro cronológico

| Fecha | Qué apareció |
|---|---|
| **2-sep-2026** | 17 mutaciones. 14 reales, **3 falsas** (M8, F2, F3), las tres cerradas |
| 2-sep-2026 | Restauración, contraseña pendiente y guardias de Flutter, con el mismo filtro |
| 3-sep-2026 | Asignación de material a un estudiante, con el mismo filtro |
| 3-sep-2026 | **Punto ciego 1**: CORS sin `PUT`. `app.request()` no hace preflight |
| 3-sep-2026 | **Punto ciego 2**: la petición correcta con el cuerpo equivocado (calendario) |
| 3-sep-2026 | **Punto ciego 3**: los fixtures son el caso feliz (portada vacía) |
| **9-sep-2026** | **Punto ciego 4**: un verificador que salía 0 sin comprobar nada |
| 9-sep-2026 | **Punto ciego 5**: el rollback corría, no hacía nada y reportaba éxito |
| 9-sep-2026 | Las 5 débiles, reforzadas por otro camino. M5 resultó tener un hueco |
| 9-sep-2026 | **Barrido de guardias**: 36 de 79 aplicaciones podían quitarse sin que nada se pusiera rojo |

**Ninguno de los cinco puntos ciegos lo podía encontrar una mutación**, y no
por falta de cobertura: en los cinco, el código sobre el que se muta estaba
bien. Ver la sección propia más abajo.

---

Una suite verde no es evidencia de nada por sí sola. Una prueba puede pasar
porque el código está bien, o porque nunca miró lo que dice mirar. La única
forma de distinguirlas es **romper a propósito lo que la prueba afirma
verificar y comprobar que se pone roja**.

Eso es lo que se hizo acá: 17 mutaciones, cada una desactivando una regla
concreta, cada una corriendo la suite **entera** y revirtiéndose después.

## Método

Dos arneses automáticos (`mutar.mjs` y `mutar-flutter.mjs`) que, por cada
mutación: aplican el cambio al archivo real, corren toda la suite, restauran el
archivo en un `finally` —pase lo que pase— y anotan el resultado.

Antes de correr nada se verificó en seco que las 17 mutaciones encontraran su
texto y que el árbol de git quedara limpio después. Sin eso, una mutación que
no se aplica se ve idéntica a una que el código sobrevive.

**Una mutación que solo rompe la compilación no cuenta.** La primera versión de
F1 hacía que Flutter no compilara; se rehízo para que compilara y siguiera
estando rota. Un error del compilador no dice nada sobre las pruebas.

Línea base: **502 pruebas de backend + 124 de Flutter sin `e2e`** (188 con
ellas), todas en verde.

## Resultados

### Backend — 12 mutaciones

| # | Qué dice verificar la prueba | ¿Falla al romperla? | Pruebas rojas | Veredicto |
|---|---|---|---|---|
| M1 | `POST /users` exige rol admin/superadmin/company | Sí | 3 | **real** |
| M2 | un módulo de Ruta está completo solo si **todos** sus cursos lo están | Sí | 14 | **real** |
| M3 | no se emite certificado de Ruta sin las 3 fases completas | Sí | 3 | **real** |
| M4 | `assertCanGrade` exige `can_grade` del registro vivo | Sí | 1 | **real** |
| M5 | `requireCanGrade` frena a un LXD sin permiso | Sí | 1 | **real** |
| M6 | `requireEnactus` bloquea a Open Learning de laboratorios y Ruta | Sí | 11 | **real** |
| M7 | `assertSelfOr` impide leer o tocar datos ajenos | Sí | 4 | **real** |
| M8 | los permisos se leen del registro vivo, no del token | **No** | **0** | **hueco** → cerrado |
| M9 | `PATCH /auth/me` no deja cambiarse el rol a sí mismo | Sí | 1 | **real** |
| M10 | una cuenta empresa solo crea cuentas `lxd` y `mentor` | Sí | 1 | **real** |
| M11 | `verifyAccessToken` valida la firma | Sí | 2 | **real** |
| M12 | `authorizeFileRead` resuelve la key contra la fila que la referencia | Sí | 23 | **real** |

### Flutter — 5 mutaciones

| # | Qué dice verificar la prueba | ¿Falla al romperla? | Pruebas rojas | Veredicto |
|---|---|---|---|---|
| F1 | la barra lateral dibuja una pestaña por cada `PortalTab` | Sí | 10 | **real** |
| F2 | el tablero del estudiante dibuja su contenido | **No** | **0** | **hueco** → cerrado |
| F3 | el encabezado dibuja la sesión | **No** | **0** | **hueco** → cerrado |
| F4 | el reproductor de video dibuja el estado que corresponde | Sí | 6 | **real** |
| F5 | la pantalla de ingreso dibuja el formulario | Sí | 1 | **real** |

**14 de 17 mutaciones detectadas al primer intento. 3 huecos, los tres
cerrados y vueltos a verificar.**

---

## Los tres huecos

### M8 — el token valía como fuente de verdad durante 12 horas

Se le quitó a `requireAuth` el filtro `isNull(users.deletedAt)`: una cuenta
desactivada seguía entrando con normalidad. **Ninguna de las 502 pruebas se
puso roja.**

La regla estaba escrita —en el comentario del propio middleware, que explica
por qué la consulta a la base no es redundante— pero no estaba en ningún
`expect`. Un comentario no es una prueba.

Por qué importa: el access token dura 12 horas. Sin esa verificación,
desactivar a alguien que se fue de la organización no lo saca hasta la mañana
siguiente, y quitarle `can_grade` a un LXD tampoco surte efecto. Los dos
momentos en que se revoca un permiso son justo aquellos en los que hay prisa
por que surta efecto.

**Cerrado** con `describe('los permisos se leen del registro vivo, no del
token')` en `backend/tests/auth.test.ts` — tres casos: cuenta desactivada,
`can_grade` revocado y rol degradado, los tres con el **mismo token ya
emitido**, sin volver a iniciar sesión.

Re-verificado: la mutación M8 ahora deja 1 prueba roja.

### F2 — una pantalla entera podía quedar en blanco

Se reemplazó todo el `build` de `StudentDashboardView` por un `Container()`
vacío. **Las 124 pruebas siguieron en verde.**

La causa es interesante y vale como advertencia general: `portals_render_test`
comprobaba que el armazón estuviera montado, que no apareciera el ingreso y
que no hubiera estado de error. **Una pantalla en blanco cumple las tres.** Las
aserciones eran correctas y aun así el conjunto no cubría el caso más obvio —
que la pestaña dibuje algo.

**Cerrado** con `_dibujoContenido()`, que cuenta los textos del cuerpo de la
pestaña. Para poder mirar solo ese cuerpo —y no el encabezado y el pie, que
aportan varias decenas y taparían el vacío— se agregó la llave
`portal-content` en `PortalShell`.

El umbral salió de medir, no de estimar: recorriendo las **63 pestañas de los
nueve portales**, la más escueta dibuja 9 textos y la más cargada 398. En
blanco son 0. El umbral quedó en 5: lejos del piso real, para que ninguna
pestaña legítima se vuelva intermitente, y lejísimos de cero.

Re-verificado: la mutación F2 ahora deja 8 pruebas rojas.

### F3 — el encabezado, igual

Mismo experimento sobre `AppHeader`: `build` devolviendo `Container()`, las 124
pruebas en verde. Y el encabezado lo heredan los ocho portales y las pantallas
de autoría, así que quedarse en blanco es una caída visible en toda la
plataforma.

**Cerrado** con una prueba por rol que exige que el encabezado muestre el
nombre de la persona y su rol. Se afirma sobre eso y no sobre el logo a
propósito: un `find.byType(AnimatedLogo)` seguiría pasando si el logo se
dibujara y el resto de la fila no.

Re-verificado: la mutación F3 ahora deja 9 pruebas rojas.

---

## Lo que el ejercicio dice de la suite

Las mutaciones que **más** pruebas rompieron son las de aislamiento de datos:
M12 (acceso a archivos, 23 rojas), M2 (completitud, 14) y M6 (Open Learning,
11). Ahí la cobertura es densa y redundante — varias pruebas independientes
miran la misma regla desde ángulos distintos, que es exactamente lo que se
quiere en las reglas que más caro salen si fallan.

Las que rompieron **una sola** prueba son reglas que penden de un hilo: son
correctas y están cubiertas, pero por un único caso. Si alguien borra esa
prueba, la regla queda sin red y nada avisa. No es un defecto, es información
para saber dónde una sola edición descuidada sale cara.

Son **cinco**: M4, M5, M9, M10 y **F5**. La primera versión de esta lista decía
cuatro y dejaba fuera a F5, que también rompió una sola. El descuido importaba:
quien usara esa lista para decidir dónde reforzar se habría saltado la pantalla
de ingreso, que no es un sitio menor — es la puerta.

**Las cinco quedaron reforzadas el 9 de septiembre de 2026**, cada una por un
camino distinto del que ya existía. Copiar la aserción habría dado dos pruebas
que fallan por lo mismo, y eso no es una segunda red: es la misma red dibujada
dos veces.

| Regla | Lo que ya existía | Por dónde entra la segunda | Dónde |
|---|---|---|---|
| M4/M5 `can_grade` | el middleware sobre una ruta **sintética** | el endpoint **real**, y que no quede nota escrita | `backend/tests/reglas-criticas.test.ts` |
| M9 no cambiarse el rol | la respuesta de `PATCH /auth/me` | la **fila en la base** y la autoridad efectiva | ídem |
| M10 empresa solo lxd/mentor | el código de estado | que **no quede cuenta creada** | ídem |
| F5 la pantalla de ingreso | `find.byType(LoginView)` | lo que **sale hacia la API**, y qué pasa al ser rechazada | `test/ingreso_test.dart` |

### M5 no era solo débil: tenía un hueco

Al escribir su segunda red apareció algo que la clasificación no decía. La
prueba de M5 monta una ruta de mentira —`test.post('/calificar', requireAuth,
requireCanGrade, …)`— para ejercitar el middleware aislado. Eso demuestra que
el middleware funciona; **no** que esté enganchado a
`POST /submissions/:id/grade`.

Comprobado quitando `requireCanGrade` de la ruta real:

```
prueba nueva (endpoint real)    ROJA
tests/auth.test.ts              39 verdes
```

Es decir: cualquiera podía desenganchar el guardia del endpoint de calificar y
la suite entera seguía en verde. Es el patrón del continente otra vez, en su
forma más cara — una prueba de autorización que no toca la ruta que autoriza.

Y el patrón de los tres huecos es el mismo en los tres: **la prueba afirmaba
sobre el continente y no sobre el contenido.** "El armazón está montado", "no
hay error", "la consulta se hizo". Las tres afirmaciones eran ciertas y las
tres seguían siendo ciertas con la funcionalidad rota.

## Cómo repetirlo

Los arneses viven en el directorio de trabajo de la sesión, no en el
repositorio: son herramienta de auditoría, no de CI. Para volver a correrlos
hace falta recrearlos. Lo que **sí** queda en el repositorio son las pruebas
que cierran los tres huecos, y esas corren con `npm test` y `flutter test`
como cualquier otra.

Conviene repetir la auditoría cuando se toque autorización, completitud o el
armazón de los portales — que son las tres áreas donde una mutación silenciosa
pasa desapercibida más fácil.

## Estado al cerrar la primera ronda (2-sep), conservado como registro

```
backend   538 pruebas · typecheck limpio · lint limpio
Flutter   204 pruebas · flutter analyze sin issues
```

Al 3 de septiembre: **557 de backend y 203 de Flutter**. Las cifras vigentes
están al final, en «Cifras, y cómo comprobarlas» — estas quedan como registro
de aquel día, no como el estado de hoy.

**Actualización del 2 de septiembre.** Todo lo que se agregó después de esta
auditoría pasó por el mismo filtro antes de darse por bueno: se rompió a
propósito y se comprobó que alguna prueba se pusiera roja.

| Qué se rompió | Pruebas rojas |
|---|---|
| la restauración deja de reponer los hashes | 1 |
| `requireAuth` deja de bloquear con la contraseña pendiente | 3 |
| los guardias de Flutter dejan pasar con la contraseña pendiente | 13 |

**Actualización del 3 de septiembre.** Se agregó la asignación de material a un
estudiante, con el mismo filtro: desactivar la comprobación de tipo de cuenta
deja 2 pruebas rojas, y hacer que la asignación de cursos no inserte nada —un
`200` que no cambia nada— deja 3.

## Los cinco puntos ciegos: afirmar sobre el continente, no sobre el contenido

Los cinco son la misma familia y se leen juntos. En ninguno faltaba cobertura:
**el código sobre el que una mutación habría mutado estaba bien.** Lo que
fallaba estaba en otro sitio — entre capas, en el cliente, en los datos de
prueba, o en el propio verificador.

| # | Qué pasaba | La prueba que lo atrapa |
|---|---|---|
| 1 | CORS sin `PUT`: `app.request()` no hace preflight | `backend/tests/cors.test.ts` ✅ |
| 2 | La petición correcta con el cuerpo equivocado | `test/calendario_test.dart` + `FakeApi.cuerpos` — **parcial** ⬜ |
| 3 | Los fixtures son el caso feliz | `test/portada_vacia_test.dart` — **parcial** ⬜ |
| 4 | Un verificador que salía 0 sin comprobar nada | `backend/tests/verificadores.test.ts` ✅ |
| 5 | El rollback corría, no hacía nada y daba éxito | ídem, + paso del pipeline ✅ |

Los dos marcados **parcial** tienen prueba para el caso concreto que apareció,
no para la clase entera. Falta:

- **(2)** una prueba de contrato que compare los campos que el **cliente
  Flutter envía** contra los que el servidor acepta, en vez de un caso por
  incidente. Hoy la suite del servidor mide lo que ella misma manda, que es
  circular.
- **(3)** casos con los opcionales vacíos y nulos de forma sistemática, no solo
  en la portada.

### Punto ciego 1 — CORS

Al probar la pantalla nueva en un navegador de verdad apareció un fallo que
llevaba desde el principio y que **la suite no podía ver por cómo está
construida**, no por lo que le falte cubrir: `allowMethods` de CORS no incluía
`PUT`.

Las pruebas de backend usan `app.request()`, que invoca el handler
directamente y **no hace preflight**. Los catorce endpoints `PUT` de la
aplicación respondían 200 en verde mientras el navegador los bloqueaba antes
de enviarlos. Ninguna mutación sobre el código de los handlers lo habría
detectado: el código de los handlers estaba bien.

La lección no es "faltaba una prueba" sino **dónde mirar**: una suite que
llama al handler por dentro no ejerce la capa que hay entre el navegador y el
handler. `tests/cors.test.ts` la cubre ahora comparando la lista declarada
contra los métodos que el router registra de verdad — quitar `PUT` deja 3 de
sus 4 pruebas rojas.

Vale como recordatorio general para esta suite: **lo que `app.request()` se
salta —preflight, redirecciones del borde, caché de CloudFront, cabeceras que
agrega API Gateway— no lo cubre ninguna prueba de backend, por muchas que
sean.**

### Punto ciego 2 — la petición correcta con el cuerpo equivocado

El calendario no dejaba guardar ningún evento, y la causa es de la misma
familia. Las pruebas de backend de `/calendar-events` pasaban **solo el campo
que su tipo de evento usa** —una sesión Open Learning con su `courseId`, una
mentoría con su `laboratoryId`— y nunca la forma real del cuerpo que manda la
aplicación, que envía **los dos siempre**, con `''` en el que no aplica.

El servidor valida ambos como uuid opcional, así que respondía 400 «Invalid
UUID». Las pruebas escribían un cuerpo *correcto*; el cliente escribía otro. La
suite del servidor no puede encontrar eso: mide lo que ella misma envía.

Tampoco lo veía nadie desde el cliente, porque el diálogo no capturaba la
excepción: se perdía en el `Future` del botón y el botón parecía no hacer nada.
Un tercer fallo se escondía debajo: al editar se llamaba a POST y no a PATCH,
así que cuando llegara a guardar habría duplicado el evento.

Lo que se agregó para que no vuelva a pasar:

- `FakeApi.cuerpos` guarda el cuerpo de cada petición, no solo método y ruta.
  Afirmar solo sobre la ruta deja pasar justo esta clase de error.
- `test/calendario_test.dart` comprueba el cuerpo que sale de verdad, que el
  error se ve cuando el servidor rechaza, y que editar hace PATCH.
- En `entities.test.ts`, dos casos con la forma real del cuerpo: un evento de
  Ruta con los dos ids en `null`, y el rechazo explícito de la cadena vacía.

**La regla que sale de los dos hallazgos: una prueba que construye el cuerpo
—o la petición— por su cuenta solo prueba el servidor. Que el cliente hable el
mismo idioma hay que probarlo aparte, con el cuerpo que el cliente arma.**

### Punto ciego 3 — los fixtures son el caso feliz

En la portada aparecía una tarjeta vacía suelta entre los contadores y los
laboratorios. Era el bloque "Sobre nosotros": la `Column` de la portada centra
y ese contenedor no fijaba ancho, así que sin texto no desaparecía — se
encogía a su propio relleno y quedaba una caja con fondo y nada dentro.

El banner de arriba, en el mismo archivo, sí tenía su `if (isNotEmpty)`. Al
bloque de "Sobre nosotros" simplemente le faltaba.

Por qué no lo vio ninguna prueba: `test/fixtures/api_payloads.json` es una
captura del sembrado, con **todos** los campos de `/site-content` llenos. Las
pruebas de la portada montaban siempre esa versión, que es justo la que no
tiene el problema. Una instalación recién montada tiene esos textos en blanco
hasta que alguien los escriba, y ese estado no lo recorría nadie.

`appPublica` acepta ahora reemplazar `/site-content`, y
`test/portada_vacia_test.dart` monta la portada con los textos vacíos.

**Los fixtures capturados son datos realistas, no datos completos: describen
una instalación con contenido, nunca una recién montada, ni una a la que le
falte un campo. Lo que el sembrado siempre llena, la suite nunca lo prueba
vacío.**

---

### Punto ciego 4 — un verificador que salía 0 sin comprobar nada

**9 de septiembre de 2026.** `backend/scripts/verificar-rollback.mjs` decidía
si lo estaban ejecutando como programa comparando `import.meta.url` contra
`` `file://${process.argv[1]}` ``. Este proyecto vive en `…/ENACTUS V4/…`, con
un espacio, que `import.meta.url` codifica como `%20`. La comparación fallaba
siempre, el bloque principal no corría, y el script **salía 0 sin comprobar
nada**.

Se descubrió por casualidad: al probarlo contra los dos entornos, uno sano y
otro roto, **los dos dieron 0**. Un solo entorno no lo habría revelado.

Lo grave no es el `%20`. Es que un verificador roto **se ve idéntico a un
sistema sano**: los dos salen 0 y no dicen nada. Es el único tipo de código
donde un fallo silencioso no tiene ningún síntoma hasta el incidente.

### Punto ciego 5 — el rollback corría, no hacía nada y reportaba éxito

**9 de septiembre de 2026.** El rollback consiste en mover el alias `vivo` a la
versión anterior. Eso solo cambia algo si API Gateway está integrado **contra
el alias**. En producción apuntaba a la función sin cualificar, así que el
tráfico entraba por `$LATEST`: mover el alias no cambiaba nada, y el paso de
rollback del pipeline habría corrido, no habría surtido efecto y habría
terminado en verde.

Un mecanismo de seguridad que se ejecuta, no hace nada y da éxito es peor que
no tenerlo: se descubre que no existía **durante** el incidente.

---

## REGLA PERMANENTE · Ningún verificador sin su meta-prueba

De los puntos ciegos 4 y 5 sale la única regla de este documento que es
generalizable, y por eso va aparte:

> **Un script que verifica cosas tiene que estar verificado.** Ningún script de
> verificación se acepta sin una meta-prueba que rompa a propósito lo que
> comprueba y confirme que **sale distinto de 0**.

No basta con probar el camino feliz. Lo que hay que probar es que el script
**falla cuando debe**, incluyendo el caso de **no poder comprobar**: si el
`aws` no responde y el script sale 0, no saber si hay red de seguridad se
confunde con tenerla.

Implementado en `backend/tests/verificadores.test.ts`: 10 casos que anteponen
al `PATH` un `aws` de mentira para montar cada escenario sin tocar AWS.

| Cubre | Sale |
|---|---|
| todo conectado | 0 |
| API Gateway no entra por el alias (**el fallo real**) | 1 |
| no existe el alias | 1 |
| el alias apunta a `$LATEST` | 1 |
| **no se puede consultar a AWS** | 1 |
| solo hay una versión publicada | 0, con aviso |

La regresión del `%20` queda cubierta sin hacer nada especial: las pruebas
invocan los scripts **por su ruta real**, que ya tiene el espacio. Comprobado
reintroduciendo el fallo a propósito — pone rojas las 6 de rollback.

**Al agregar un verificador nuevo, se agrega su bloque acá.** Un verificador
sin meta-prueba no está terminado, está escrito.

---

## Cifras, y cómo comprobarlas

```
backend   575 pruebas · 28 archivos · typecheck limpio · lint limpio
Flutter   218 pruebas · flutter analyze sin issues
```

```bash
cd backend && npm test && npm run typecheck && npm run lint
cd .. && flutter test && flutter analyze
```

Si estos números no coinciden con lo que sale de esos comandos, **la
discrepancia es el hallazgo**: significa que alguien agregó o quitó pruebas sin
pasar por acá, y la condición 4 del criterio de cierre deja de cumplirse.

---

## El barrido de guardias — 9 de septiembre de 2026

M5 no era un caso aislado. Su forma —una prueba que monta el middleware sobre
una ruta de mentira— es un patrón, así que se barrió entero: **cada aplicación
de un guardia de autorización se quitó de su ruta, una por una, corriendo la
suite completa entre cada mutación.**

79 aplicaciones reales (las líneas de `import` no cuentan: quitarlas solo rompe
la compilación, y un error del compilador no dice nada sobre la suite).

### El resultado

```
79 aplicaciones de guardia
36 podían quitarse sin que NINGUNA prueba se pusiera roja
```

| Guardia | Total | Cubiertas | Sin cubrir |
|---|---|---|---|
| `requireRole` | 42 | 12 | **30** |
| `requireAuth` | 31 | 26 | 5 |
| `requireCanGrade` | 2 | 1 | 1 |
| `requireEnactus` | 4 | 4 | 0 |

Entre los descubiertos: `DELETE /users/:id`, `PATCH /users/:id`,
`DELETE /courses/:id`, `POST /courses/:id/publish` y **toda la autoría de
lecciones** —vídeo, quiz, recursos, actividad—. Cualquiera podía quitarles el
guardia de rol y la suite entera seguía en verde.

`requireEnactus` fue el único con cobertura completa: sus 4 aplicaciones están
probadas contra el endpoint real, porque `isolation.test.ts` se escribió así
desde el principio.

### Cómo se cerró: un barrido, no 36 pruebas

`backend/tests/guardias-en-rutas-reales.test.ts` recorre `app.routes` y exige,
para cada endpoint:

1. **sin token** → nada responde 2xx, salvo una lista explícita de públicas;
2. **como estudiante** → todo lo que no esté en `ESTUDIANTE_PUEDE` responde
   **exactamente 401 o 403**.

Escribir 36 pruebas a mano habría cubierto lo de hoy y nada más. Un barrido
sobre las rutas registradas cubre también **lo que se agregue mañana**: un
endpoint nuevo entra cubierto sin que nadie se acuerde de cubrirlo, que es la
única forma de que no se olvide.

`ESTUDIANTE_PUEDE` es, de paso, la definición operativa de qué alcanza un
estudiante. Si esa lista crece sin que nadie lo discuta, el alcance creció sin
que nadie lo discuta.

### El detalle que casi lo deja a medias

La primera versión aceptaba **cualquier 4xx** como «el guardia corrió y la
validación se quejó después». Al re-verificar contra los 36 huecos, solo cerró
19. El motivo: al quitar el guardia, el cuerpo `{}` falla la validación y
devuelve **400**, indistinguible de lo anterior.

Se apretó a **exactamente 401 o 403**, y ahí el orden lo vuelve tajante: el
guardia es middleware, así que corre **antes** de validar. Con guardia → 403.
Sin guardia → 400 o 404. Cerró 31.

También apareció que el comodín `GET /lessons/…` de la lista de permitidos
dejaba pasar `GET /lessons/:id/quiz`, que devuelve el cuestionario **con las
respuestas** y por eso es de `CONTENT_ROLES`. Un comodín ancho en una lista de
permitidos es justo el error que la prueba busca en el código.

### Los 5 que siguen «sin detectar», y por qué no son huecos

| Aplicación | Por qué la mutación no rompe nada |
|---|---|
| 4 × `requireAuth` en `.use('*', …)` | `currentUser()` lanza si no hay sesión, así que la ruta **falla cerrada** igual. Se pierde el 401 limpio: pasa a ser un **500**, que ensucia la tasa de 5xx sobre la que van las alarmas |
| `requireCanGrade` en `POST /certificates/ruta` | El handler llama `assertCanGrade(user, false)` en su **primera línea**. El guardia de ruta es redundante |

**No son cobertura que falte: son defensa repetida.** Se comprobó uno por uno,
no se dedujo. Se dejan como están —redundar en autorización es barato— pero
queda escrito que si alguien «limpia» el `requireAuth` de esas cuatro líneas, lo
que aparece no es un agujero sino un 500 en vez de un 401.

---

## REGLA PERMANENTE · Ninguna prueba de middleware sobre una ruta sintética

Junto a la del verificador, la segunda regla que sale de todo esto:

> **Una prueba de middleware no cuenta si corre sobre una ruta de mentira.**
> Montar `test.post('/calificar', requireAuth, requireCanGrade, …)` demuestra
> que el middleware **funciona**; no demuestra que esté **puesto** donde hace
> falta. Toda prueba de autorización tiene que ejercitar el **endpoint real**.

Es la regla más cara del documento: ignorarla dejó 36 guardias sin red durante
todo el proyecto, y ninguna de las 557 pruebas de entonces lo notó.
