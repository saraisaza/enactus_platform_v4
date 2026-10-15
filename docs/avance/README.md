# Avance en orden y sin marcar a mano

Pedido de Sara del 2026-10-14, tras la prueba beta de Open Learning: una
estudiante marcaba lecciones como completas tocando el círculo —en el teléfono
desde la primera parte del módulo, en el computador desde la segunda— sin ver
el video ni leer el material, y pasaba a las siguientes.

Desde la migración `0020_avance_en_orden`, en toda la plataforma (cursos de
Open Learning, cursos de laboratorio y lecturas y entregas de la Ruta):

## 1. Nada se marca a mano

El círculo de cada lección es solo un indicador: ✓ completada, ○ la que le
toca, 🔒 todavía no. `POST /progress/lessons/:id/complete` es el único camino,
y el servidor decide (`backend/src/services/avance-de-leccion.ts`). No existe
«desmarcar». `POST …/toggle` queda como nombre viejo de `complete`, para la
app que alguien tenga abierta durante un despliegue.

## 2. Cada lección, con su prueba

| Lección | Se completa cuando… | Lo comprueba |
|---|---|---|
| Video de YouTube o subido | se VIO el 90%, en tramos reproducidos | el servidor, con los tramos que manda el reproductor |
| Quiz | se aprueba (60%) | el servidor, que pone la nota |
| Encuesta | se responde | el servidor |
| Actividad de un curso | su entrega se califica **aprobada** (60/100, 3/5, «aprobado»; en «solo revisión», al revisarla) | el servidor, al calificar |
| Entrega de la Ruta | se entrega (con texto o archivo) | el servidor, al recibirla |
| PDF | se llega a la última página | la app (el servidor no ve el material) |
| Imagen, archivo, enlace, video de Vimeo | se abre (o se descarga, si no se puede mostrar) | la app |

**El video.** Cada guardado trae la posición y el tramo reproducido desde el
anterior. Un salto cierra el tramo: lo saltado no suma. Y un tramo nunca vale
más que el tiempo real transcurrido (a 2×, lo más rápido de YouTube, con 10%
de margen; máximo 2 minutos por guardado). Ver un video de diez minutos lleva,
como mínimo, más de cuatro.

**La actividad de un curso.** Entregarla no la completa: la lección siguiente
espera a que la califiquen aprobada. Una nota que no aprueba no la completa
—la persona vuelve a entregar— y nunca des-completa lo ya completado.

## 3. En orden

Una lección se abre cuando todas las anteriores del curso —las de los
módulos anteriores incluidas— están completas. El orden es módulo por módulo y
lección por lección (`order_index`, y el `id` para desempatar). En la Ruta,
además, el módulo tiene que estar desbloqueado (fase anterior completa y
módulo anterior completo, como ya lo dibujaba la pantalla).

Lo ya completado se puede repasar siempre (volver a ver el video, repetir el
quiz). Quien mira el curso de un estudiante desde el equipo ve los candados de
esa persona, pero puede abrir el material para revisarlo.

`GET /students/:id/course-progress/:courseId` trae `nextLessonId`: una
lección está abierta si ya está completa o si es esa. Las respuestas de
completar traen el `nextLessonId` nuevo.

## 4. Igual en el teléfono y en el computador

El avance vive en el servidor: lo que se hace en un dispositivo es lo que lee
el otro. Lo que podía no coincidir era la app, que se quedaba con lo que ya
había traído hasta salir por más de cinco minutos (reporte de un estudiante,
2026-10-15). Ahora (`DataProvider._alDia` y `main.dart`):

- Al volver a la app —o a la ventana del navegador— después de más de 5
  segundos, el avance que está en pantalla se vuelve a preguntar.
- El avance traído hace más de 30 segundos (`vigenciaDelAvance`) se vuelve a
  preguntar la próxima vez que una pantalla lo muestra: cursos, el de cada
  curso, la Ruta y los certificados.
- Antes de decir «bloqueada» (un curso o la Ruta) se le pregunta al servidor:
  la anterior se pudo completar en el otro dispositivo hace un instante.
- Un video retoma donde quedó en cualquier dispositivo: si lo que hay venció,
  se pregunta antes de abrirlo (como mucho 2 segundos de espera).
- Estas consultas no cambian la pantalla mientras van, y si fallan (sin
  señal) se queda lo que había, sin cartel de error. Completar una lección
  mientras va una consulta no se deshace cuando llega la respuesta vieja.
- La API responde `Cache-Control: no-store`: ningún navegador guarda una
  respuesta.
- El servidor toma la fila del video al guardarlo: dos dispositivos guardando
  a la vez leen uno lo del otro. Lo visto nunca supera el tiempo real, aunque
  haya dos pantallas abiertas.

## Lo que NO se tocó

- Los avances que ya existían. No hay forma de saber qué se marcó a mano y qué
  se hizo de verdad, así que lo completado sigue completado. Un video a medias
  empieza sin tramos vistos: hay que verlo para completarlo.
- Los cursos de un laboratorio se pueden abrir desde la lista de cursos aunque
  su módulo de la Ruta esté bloqueado. Bloquearlos por la Ruta es una decisión
  pendiente (ver el resumen del 2026-10-14).

## Pruebas

- Servidor: `backend/tests/avance-en-orden.test.ts` (y el ayudante
  `tests/helpers/avance.ts`, que completa lecciones como lo haría una persona).
- App: `test/avance_en_orden_test.dart` (grupo «el teléfono y el
  computador»), `test/volver_a_la_app_test.dart`, y el seguidor del video en
  `test/youtube_test.dart`.
