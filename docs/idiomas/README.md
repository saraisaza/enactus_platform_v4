# La plataforma en español e inglés

La interfaz completa está en los dos idiomas. Quien la usa elige en el
desplegable «Español / English» de la barra superior y todo cambia en el acto,
sin recargar. Lo que escriben las personas (nombres, cursos, lecciones, foro,
proyectos) **no** se traduce: se muestra tal como se escribió.

## Cómo se elige el idioma

1. Si la persona ya eligió uno en el selector, ese. Se guarda en el
   dispositivo (en la web, `localStorage`), con o sin sesión iniciada.
2. Si nunca eligió, el idioma del navegador o del teléfono: inglés si el
   **primero** de su lista es inglés; español en cualquier otro caso (francés,
   portugués…).

Código: `lib/l10n/idioma.dart`.

## Dónde viven los textos

| Qué | Dónde |
|---|---|
| Textos de la app (≈1.450) | `lib/l10n/app_es.arb` y `lib/l10n/app_en.arb` |
| Código generado a partir de esos archivos | `lib/l10n/app_localizations*.dart` (no se edita a mano) |
| ODS y competencias, traducidos por su código | `lib/l10n/catalogos.dart` |
| Fechas y números según el idioma | `lib/utils/formatos.dart` |
| Mensajes de error del servidor (≈180) | `backend/src/i18n/mensajes.ts` |
| Textos de la portada en inglés | Panel de administración › Contenido página › «Textos en inglés» |

`textos_es_en.csv` y `mensajes_servidor_es_en.csv` (en esta carpeta) son las
mismas listas en forma de planilla, para que alguien revise el inglés sin
abrir el código. Se regeneran con los comandos del final.

## Cómo agregar un texto nuevo a la app

1. Escribir la clave en **los dos** archivos:

   ```json
   // app_es.arb
   "cursoArchivado": "El curso quedó archivado.",
   // app_en.arb
   "cursoArchivado": "The course has been archived.",
   ```

   Con partes que cambian, se declaran en el español:

   ```json
   "cursoInscritos": "{cantidad, plural, =1{1 inscrito} other{{cantidad} inscritos}}",
   "@cursoInscritos": { "placeholders": { "cantidad": { "type": "int" } } },
   ```

2. Usarla en el código: `Text(tr.cursoArchivado)` o
   `tr.cursoInscritos(curso.inscritos)`. `tr` viene de `lib/l10n/textos.dart`.
3. `flutter gen-l10n` (o cualquier `flutter run`, `test` o `build`) regenera
   el código.

Reglas que vigila `test/idiomas_test.dart`:

- Las mismas claves en los dos archivos, ninguna vacía, con las mismas partes
  variables.
- El español en **usted**: nunca tú ni vos.
- **Ningún texto en español escrito directamente en `lib/`.** Si de verdad no
  es interfaz (un nombre propio, un código de la API), se agrega a
  `_permitidos` en esa prueba, con el motivo.
- Los nueve portales se recorren enteros en inglés: ninguna pestaña puede
  mostrar un texto de la interfaz en español ni desbordarse a 360 px.

## Fechas y números

Se usan las funciones de `lib/utils/formatos.dart` (`fechaCorta`,
`fechaHora`, `decimal`, `entero`…), no `DateFormat` directo. En español se
conservan los formatos de siempre («5 oct 2026», «3:00 p. m.»); en inglés, el
orden propio del idioma («Oct 5, 2026»). Los decimales llevan coma en español
(«4,5») y punto en inglés («4.5»). Los formatos técnicos (`yyyy-MM-dd` para la
API, el nombre de un archivo) no cambian con el idioma.

## El servidor

La app manda `Accept-Language: es` o `en` en cada pedido. El servidor traduce
**solo sus propios mensajes** (errores y avisos) con el catálogo de
`backend/src/i18n/mensajes.ts`, cuya clave es el mensaje en español tal como
está en el código. Sin cabecera responde en español, como siempre.

Para un error nuevo: escribirlo en español donde se lanza y sumar su par en
`mensajes.ts`. `backend/tests/idiomas.test.ts` lee todo el código del servidor
y falla si un mensaje no tiene traducción, o si en el catálogo sobra uno que
ya no se usa.

### Avisos (notificaciones)

Un aviso lo genera el servidor u otra persona, y lo lee alguien que puede
tener la interfaz en otro idioma. Por eso se guarda con su **tipo** y sus
datos (`notifications.kind` y `params`, migración `0012_idiomas`) además del
texto en español: la app de quien lo lee arma el texto en su idioma. Los
avisos anteriores a esta migración, y los que escribe una persona (los de
BuscaTalento), se muestran tal cual.

Los motivos de reporte del foro se guardan siempre en español —es lo que lee
el equipo de moderación— y cada persona los ve en su idioma.

## Teléfonos

- iPhone: `Info.plist` declara `es` y `en` en `CFBundleLocalizations`. Sin
  `en`, iOS le informa a la app que el teléfono está en español aunque esté
  en inglés. Los avisos de permisos (cámara, fotos, micrófono) en inglés están
  en `ios/Runner/en.lproj/InfoPlist.strings`.
- Android: no necesita nada aparte.

## Regenerar las planillas de revisión

```bash
python3 - <<'PY'
import csv, json, os, re
es = json.load(open('lib/l10n/app_es.arb')); en = json.load(open('lib/l10n/app_en.arb'))
with open('docs/idiomas/textos_es_en.csv', 'w', newline='', encoding='utf-8') as f:
    w = csv.writer(f); w.writerow(['clave', 'español', 'inglés'])
    for k, v in es.items():
        if not k.startswith('@'): w.writerow([k, v, en[k]])
PY
```
