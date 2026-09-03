# Auditoría de pruebas — ¿cuáles son reales?

**Cerrada el 2 de septiembre de 2026.**

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

Las que rompieron **una sola** prueba —M4, M5, M9, M10— son reglas que penden
de un hilo: son correctas y están cubiertas, pero por un único caso. Si alguien
borra esa prueba, la regla queda sin red y nada avisa. No es un defecto, es
información para saber dónde una sola edición descuidada sale cara.

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

## Estado al cerrar

```
backend   538 pruebas · typecheck limpio · lint limpio
Flutter   204 pruebas · flutter analyze sin issues
```

**Actualización del 2 de septiembre.** Todo lo que se agregó después de esta
auditoría pasó por el mismo filtro antes de darse por bueno: se rompió a
propósito y se comprobó que alguna prueba se pusiera roja.

| Qué se rompió | Pruebas rojas |
|---|---|
| la restauración deja de reponer los hashes | 1 |
| `requireAuth` deja de bloquear con la contraseña pendiente | 3 |
| los guardias de Flutter dejan pasar con la contraseña pendiente | 13 |
