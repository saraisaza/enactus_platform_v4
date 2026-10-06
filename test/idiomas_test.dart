// La app en español e inglés.
//
// Cuatro preguntas, cada una con su grupo:
//
// 1. ¿Los dos archivos de textos dicen lo mismo? Las mismas claves, ninguna
//    vacía, y las mismas partes variables (`{nombre}`) en los dos idiomas.
// 2. ¿Quedó texto de interfaz escrito directamente en el código? Se lee todo
//    `lib/` y se buscan textos en español fuera de los archivos de textos.
// 3. ¿El idioma se elige, se cambia y se recuerda como se pidió? La primera
//    vez el del navegador (inglés si es inglés, español si no), el selector
//    cambia todo sin recargar y la elección queda guardada.
// 4. ¿Cada portal, entero, sale en inglés? Se recorren todas las pestañas de
//    los nueve portales con la interfaz en inglés y ningún texto de la
//    interfaz puede quedar en español.

import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:enactus_platform/l10n/idioma.dart';
import 'package:enactus_platform/models/models.dart';
import 'package:enactus_platform/utils/constants.dart';
import 'package:enactus_platform/utils/formatos.dart';
import 'package:enactus_platform/widgets/portal_shell.dart';
import 'package:enactus_platform/widgets/selector_idioma.dart';

import 'helpers/portal_harness.dart';

Map<String, dynamic> _arb(String idioma) =>
    jsonDecode(File('lib/l10n/app_$idioma.arb').readAsStringSync())
        as Map<String, dynamic>;

/// Los nombres de las partes variables de un mensaje (también las de un
/// plural: `{cantidad, plural, …}`).
Set<String> _partes(String mensaje) =>
    RegExp(r'\{(\w+)[},]').allMatches(mensaje).map((m) => m[1]!).toSet();

Map<String, String> _textos(Map<String, dynamic> arb) => {
      for (final e in arb.entries)
        if (!e.key.startsWith('@')) e.key: e.value as String,
    };

void main() {
  group('los archivos de textos', () {
    final es = _textos(_arb('es'));
    final en = _textos(_arb('en'));

    test('tienen las mismas claves', () {
      expect(es.keys.toSet().difference(en.keys.toSet()), isEmpty,
          reason: 'Claves sin traducción al inglés');
      expect(en.keys.toSet().difference(es.keys.toSet()), isEmpty,
          reason: 'Claves en inglés que no existen en español');
      expect(es.length, greaterThan(1400));
    });

    test('ningún texto está vacío', () {
      expect(es.entries.where((e) => e.value.trim().isEmpty).map((e) => e.key),
          isEmpty);
      expect(en.entries.where((e) => e.value.trim().isEmpty).map((e) => e.key),
          isEmpty);
    });

    test('cada traducción tiene las mismas partes variables', () {
      final distintas = [
        for (final k in es.keys)
          if (_partes(es[k]!).difference(_partes(en[k]!)).isNotEmpty ||
              _partes(en[k]!).difference(_partes(es[k]!)).isNotEmpty)
            '$k: «${es[k]}» / «${en[k]}»',
      ];
      expect(distintas, isEmpty);
    });

    test('el español es formal: usted, nunca tú ni vos', () {
      // Las formas que ya se colaron una vez (ver el historial del proyecto).
      final tuteo = RegExp(
          r'\b(puedes|tienes|quieres|debes|eres|estás|tú|tu|tus|te|ti|contigo|'
          r'podés|tenés|querés|sos|vos|Iniciá|Elegí|Esperá|Revisá|Indicá)\b');
      final malos = [
        for (final e in es.entries)
          if (tuteo.hasMatch(e.value)) '${e.key}: «${e.value}»',
      ];
      expect(malos, isEmpty);
    });
  });

  group('sin textos sueltos en el código', () {
    test('no queda texto de interfaz en español fuera de lib/l10n', () {
      final hallazgos = <String>[];
      for (final f in Directory('lib').listSync(recursive: true)) {
        if (f is! File || !f.path.endsWith('.dart')) continue;
        final rutaArchivo = f.path.replaceAll(Platform.pathSeparator, '/');
        if (rutaArchivo.startsWith('lib/l10n/') ||
            _archivosPermitidos.contains(rutaArchivo)) {
          continue;
        }
        final lineas = f.readAsLinesSync();
        for (var i = 0; i < lineas.length; i++) {
          final linea = lineas[i];
          final limpia = linea.trimLeft();
          if (limpia.startsWith('//') ||
              limpia.startsWith('import ') ||
              limpia.startsWith('export ') ||
              limpia.startsWith('part ')) {
            continue;
          }
          if (_contextoPermitido.any(linea.contains)) continue;
          for (final m in _literal.allMatches(linea)) {
            final texto = m[2]!;
            if (!_pareceEspanol(texto)) continue;
            final ruta = f.path.replaceAll(Platform.pathSeparator, '/');
            if (_permitidos.contains('$ruta|$texto')) continue;
            hallazgos.add('$ruta:${i + 1}  «$texto»');
          }
        }
      }
      expect(hallazgos, isEmpty,
          reason: 'Hay textos escritos directamente en el código. Muévalos a '
              'lib/l10n/app_es.arb y app_en.arb y use `tr.<clave>`. Si de '
              'verdad no son interfaz (un nombre propio, un código), agréguelos '
              'a `_permitidos` en esta prueba con el motivo.');
    });
  });

  group('elegir el idioma', () {
    setUp(() => SharedPreferences.setMockInitialValues({}));
    tearDown(Idioma.instancia.restablecer);

    test('la primera vez manda el idioma del navegador o del teléfono', () {
      expect(Idioma.delSistema(const [Locale('en', 'US')]), 'en');
      expect(Idioma.delSistema(const [Locale('en', 'GB'), Locale('es')]), 'en');
      expect(Idioma.delSistema(const [Locale('es', 'CO')]), 'es');
      // Ni español ni inglés: español, aunque el inglés venga después.
      expect(Idioma.delSistema(const [Locale('fr', 'FR'), Locale('en')]), 'es');
      expect(Idioma.delSistema(const [Locale('pt', 'BR')]), 'es');
      expect(Idioma.delSistema(const []), 'es');
    });

    testWidgets('sin elección guardada, arranca en el del sistema',
        (tester) async {
      tester.platformDispatcher.localesTestValue = const [Locale('en', 'US')];
      addTearDown(tester.platformDispatcher.clearLocalesTestValue);
      await Idioma.instancia.cargar();
      expect(Idioma.instancia.codigo, 'en');
    });

    testWidgets('lo elegido gana sobre el navegador al volver a entrar',
        (tester) async {
      tester.platformDispatcher.localesTestValue = const [Locale('en', 'US')];
      addTearDown(tester.platformDispatcher.clearLocalesTestValue);
      SharedPreferences.setMockInitialValues({Idioma.claveGuardada: 'es'});
      await Idioma.instancia.cargar();
      expect(Idioma.instancia.codigo, 'es');
    });

    testWidgets('cambiar guarda la elección', (tester) async {
      await Idioma.instancia.cambiar('en');
      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getString(Idioma.claveGuardada), 'en');
    });

    test('las fechas y los números siguen al idioma', () async {
      TestWidgetsFlutterBinding.ensureInitialized();
      await initializeDateFormatting('es');
      await initializeDateFormatting('en');
      final d = DateTime(2026, 10, 5, 15);
      expect(fechaCorta(d), '5 oct 2026');
      // intl separa con espacios finos (U+202F): se comparan como espacios.
      String sinFinos(String s) => s.replaceAll(RegExp(r'[\u00A0\u202F]'), ' ');
      expect(sinFinos(hora(d)), '3:00 p. m.');
      expect(decimal(4.5), '4,5');
      expect(entero(1234), '1.234');
      await Idioma.instancia.cambiar('en');
      expect(fechaCorta(d), 'Oct 5, 2026');
      expect(sinFinos(hora(d)), '3:00 PM');
      expect(decimal(4.5), '4.5');
      expect(entero(1234), '1,234');
      expect(diasDeLaSemana().first, 'MON');
    });

    test('un aviso con tipo se lee en el idioma de quien lo recibe', () async {
      TestWidgetsFlutterBinding.ensureInitialized();
      final aviso = AppNotification.fromJson({
        'id': 'n1',
        'title': 'Entrega calificada',
        'body': '"Informe" tiene nueva retroalimentación.',
        'kind': 'entrega_calificada',
        'params': {'tarea': 'Informe'},
        'createdAt': '2026-10-05T00:00:00Z',
      });
      expect(aviso.tituloVisible, 'Entrega calificada');
      await Idioma.instancia.cambiar('en');
      expect(aviso.tituloVisible, 'Submission graded');
      expect(aviso.cuerpoVisible, '"Informe" has new feedback.');

      // Un aviso viejo, o uno que escribió una persona, sale tal cual.
      final libre = AppNotification.fromJson({
        'id': 'n2',
        'title': 'Una oportunidad',
        'body': 'Hola',
        'createdAt': '2026-10-05T00:00:00Z',
      });
      expect(libre.tituloVisible, 'Una oportunidad');
    });

    test('la portada usa el texto en inglés solo si el equipo lo escribió',
        () async {
      TestWidgetsFlutterBinding.ensureInitialized();
      const portada = SiteContent(
        heroSubtitle: 'Formamos líderes',
        heroSubtitleEn: 'We develop leaders',
        aboutText: 'Sobre nosotros',
      );
      expect(portada.subtituloVisible, 'Formamos líderes');
      await Idioma.instancia.cambiar('en');
      expect(portada.subtituloVisible, 'We develop leaders');
      // Sin versión en inglés, el de español: mejor que un hueco.
      expect(portada.acercaVisible, 'Sobre nosotros');
    });
  });

  group('el selector en pantalla', () {
    setUpAll(() async {
      await initializeDateFormatting('es');
      await initializeDateFormatting('en');
      cargarFixtures();
    });
    tearDown(Idioma.instancia.restablecer);

    testWidgets('cambia toda la pantalla al instante, sin recargar',
        (tester) async {
      fijarTamano(tester, const Size(1440, 900));
      final excepciones = await montar(tester, appPublica(AppRoutes.login));
      expect(excepciones, isEmpty);
      const subtituloEs = 'Ingrese con la cuenta creada por su administrador';
      const subtituloEn = 'Sign in with the account your administrator created for you';
      expect(find.text('BIENVENIDO DE NUEVO'), findsOneWidget);
      expect(find.text(subtituloEs), findsOneWidget);

      // Algo escrito a medias en el formulario no se pierde al cambiar.
      await tester.enterText(find.byType(TextField).first, 'ana@test.co');

      await tester.tap(find.byKey(SelectorIdioma.clave));
      await tester.pumpAndSettle();
      await tester.tap(find.text('English').last);
      await tester.pumpAndSettle();

      expect(find.text('WELCOME BACK'), findsOneWidget);
      expect(find.text(subtituloEn), findsOneWidget);
      expect(find.text(subtituloEs), findsNothing);
      expect(find.text('Ingresar'), findsNothing);
      expect(find.text('ana@test.co'), findsOneWidget);
      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getString(Idioma.claveGuardada), 'en');

      // Y de vuelta.
      await tester.tap(find.byKey(SelectorIdioma.clave));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Español').last);
      await tester.pumpAndSettle();
      expect(find.text(subtituloEs), findsOneWidget);
    });

    testWidgets('está en el encabezado de los portales', (tester) async {
      conSesionGuardada();
      fijarTamano(tester, const Size(390, 844));
      await montar(tester, appDe(Roles.student));
      expect(find.byKey(SelectorIdioma.clave), findsOneWidget);
    });
  });

  group('cada portal, en inglés', () {
    // Textos de la interfaz en español que no son iguales en inglés: si
    // alguno aparece con la interfaz en inglés, quedó sin traducir.
    final es = _textos(_arb('es'));
    final en = _textos(_arb('en'));
    final soloEspanol = {
      for (final k in es.keys)
        if (!es[k]!.contains('{') &&
            es[k] != en[k] &&
            es[k]!.trim().length > 3)
          es[k]!.trim(),
    }..removeAll(_datosDeUsuario());

    setUpAll(() async {
      await initializeDateFormatting('es');
      await initializeDateFormatting('en');
      cargarFixtures();
    });
    setUp(conSesionGuardada);
    tearDown(Idioma.instancia.restablecer);

    List<String> textosEnPantalla(WidgetTester tester) => tester
        .widgetList<Text>(find.byType(Text))
        .map((t) => t.data ?? t.textSpan?.toPlainText() ?? '')
        .map((s) => s.trim())
        .where((s) => s.isNotEmpty)
        .toList();

    for (final role in rolesDePortal) {
      testWidgets('${Roles.label(role)}: todas sus pestañas, sin español',
          (tester) async {
        await Idioma.instancia.cambiar('en');
        fijarTamano(tester, const Size(1440, 900));
        final excepciones = await montar(tester, appDe(role));
        expect(excepciones, isEmpty,
            reason: 'En inglés, al montar:\n${excepciones.join('\n')}');
        expect(find.byType(PortalShell), findsOneWidget);

        final barra = find.descendant(
            of: find.byType(PortalShell), matching: find.byType(ListView));
        final rotulos = rotulosDeBarraLateral(tester, barra);
        expect(rotulos.length, greaterThan(1));

        final enEspanol = <String>{};
        final rotos = <String>[];
        for (final rotulo in rotulos) {
          final anterior = FlutterError.onError;
          FlutterError.onError =
              (d) => rotos.add('[$rotulo] ${d.exception}\n${d.context}');
          try {
            await tester.tap(
                find.descendant(of: barra.first, matching: find.text(rotulo)).first,
                warnIfMissed: false);
            for (var i = 0; i < 6; i++) {
              await tester.pump(const Duration(milliseconds: 120));
            }
          } finally {
            FlutterError.onError = anterior;
          }
          for (final t in textosEnPantalla(tester)) {
            if (soloEspanol.contains(t)) enEspanol.add('[$rotulo] «$t»');
          }
        }
        expect(rotos, isEmpty, reason: rotos.join('\n'));
        expect(enEspanol, isEmpty,
            reason: 'Con la interfaz en inglés quedaron textos en español');
      });

      testWidgets('${Roles.label(role)}: en el teléfono, en inglés, sin desbordes',
          (tester) async {
        await Idioma.instancia.cambiar('en');
        fijarTamano(tester, const Size(360, 780));
        final excepciones = await montar(tester, appDe(role));
        expect(excepciones, isEmpty,
            reason: 'En inglés a 360 px:\n${excepciones.join('\n')}');
      });
    }

    testWidgets('la portada y el ingreso, en inglés', (tester) async {
      await Idioma.instancia.cambiar('en');
      for (final ruta in [AppRoutes.landing, AppRoutes.login]) {
        for (final tamano in const [Size(1440, 900), Size(360, 780)]) {
          fijarTamano(tester, tamano);
          final excepciones = await montar(tester, appPublica(ruta));
          expect(excepciones, isEmpty, reason: '$ruta a ${tamano.width}px');
          final enEspanol = textosEnPantalla(tester).where(soloEspanol.contains);
          expect(enEspanol, isEmpty, reason: '$ruta a ${tamano.width}px');
        }
      }
    });
  });
}

/// Lo que escriben las personas en los payloads de prueba (la especialidad de
/// un LXD, la descripción de un proyecto): eso NO se traduce, así que puede
/// coincidir con un texto de la interfaz sin ser un error.
Set<String> _datosDeUsuario() {
  const claves = {
    'specialty', 'position', 'experience', 'interests', 'languages',
    'availability', 'career', 'city', 'university', 'companyName',
    'description', 'problem', 'solution', 'community', 'indicators', 'title',
    'body', 'taskName', 'feedback', 'groupName', 'projectName', 'bio',
  };
  final out = <String>{};
  void recorrer(Object? v, [String? clave]) {
    if (v is Map) {
      v.forEach((k, x) => recorrer(x, '$k'));
    } else if (v is List) {
      for (final x in v) {
        recorrer(x, clave);
      }
    } else if (v is String && claves.contains(clave)) {
      out.add(v.trim());
    }
  }

  recorrer(jsonDecode(File('test/fixtures/api_payloads.json').readAsStringSync()));
  return out;
}

/// Un literal de una sola línea: `'…'` o `"…"`.
final _literal = RegExp(r'''(['"])((?:(?!\1)[^\\\n]|\\.)*)\1''');

/// Líneas donde un texto en español es legítimo: registros para quien
/// programa, claves de widgets y mensajes de errores internos que nunca ve una
/// persona.
const _contextoPermitido = [
  'debugPrint(',
  'print(',
  'Key(',
  'debugLabel',
  'Expando',
  'assert(',
  'StateError(',
  'ArgumentError(',
  'UnsupportedError(',
  'RegExp(',
  'throw Exception(',
];

final _vocabulario = () {
  final es = _textos(_arb('es'));
  final en = _textos(_arb('en'));
  final enPalabras = {
    for (final v in en.values)
      for (final w in RegExp(r'[A-Za-zÀ-ÿ]{3,}').allMatches(v)) w[0]!.toLowerCase(),
  };
  return {
    for (final v in es.values)
      for (final w in RegExp(r'[A-Za-zÀ-ÿ]{3,}').allMatches(v))
        if (!enPalabras.contains(w[0]!.toLowerCase())) w[0]!.toLowerCase(),
  };
}();

const _palabrasFuncion = {
  'de', 'la', 'el', 'los', 'las', 'un', 'una', 'para', 'con', 'que', 'por',
  'sin', 'del', 'al', 'su', 'sus', 'se', 'es', 'hay', 'más', 'este', 'esta',
  'no', 'y', 'o', 'en', 'lo', 'le',
};

bool _pareceEspanol(String texto) {
  // Las interpolaciones no son texto.
  final sinCodigo = texto
      .replaceAll(RegExp(r'\$\{[^}]*\}'), ' ')
      .replaceAll(RegExp(r'\$\w+'), ' ');
  if (!RegExp(r'[A-Za-zÀ-ÿ]{2,}').hasMatch(sinCodigo)) return false;
  if (RegExp(r'[áéíóúñ¿¡ÁÉÍÓÚÑ]').hasMatch(sinCodigo)) return true;
  final palabras = RegExp(r'[A-Za-zÀ-ÿ]+')
      .allMatches(sinCodigo)
      .map((m) => m[0]!)
      .toList();
  if (palabras.length >= 2 &&
      palabras.any((p) => _palabrasFuncion.contains(p.toLowerCase()))) {
    return true;
  }
  // Una palabra suelta de la interfaz («Guardar», «EQUIPO»), no un
  // identificador en minúsculas («todas», «fijar»), que es código.
  return palabras.length == 1 &&
      palabras.first != palabras.first.toLowerCase() &&
      _vocabulario.contains(palabras.first.toLowerCase());
}

/// Archivos que no tienen texto de interfaz aunque tengan español adentro.
const _archivosPermitidos = <String>{
  // Los patrones de fecha de cada idioma ("d 'de' MMMM"): son formato, no
  // texto; el inglés tiene los suyos al lado.
  'lib/utils/formatos.dart',
  // Nombres propios de ciudades y departamentos de Colombia.
  'lib/utils/colombia_cities.dart',
  // Tablas para quitar tildes al buscar en el glosario.
  'lib/models/glossary.dart',
};

/// Textos en español que se quedan en el código a propósito, con su motivo.
/// `archivo|texto`.
const _permitidos = <String>{
  // El abecedario del glosario: los términos son de los cursos (en español).
  'lib/widgets/glosario.dart|ABCDEFGHIJKLMNÑOPQRSTUVWXYZ',
  // Segunda línea de un `debugPrint` y mensaje de un `assert`: para quien
  // programa, nunca en pantalla.
  'lib/services/token_store.dart|La sesión durará solo mientras la app siga abierta.',
  'lib/widgets/animated_logo.dart|AnimatedLogo(compact: true) por debajo de 32px viola la regla de marca — usa favicon-*.png o eduxaction-x.svg en su lugar.',
  // Datos, no interfaz: etiquetas libres que se guardan tal cual en la base.
  'lib/utils/constants.dart|Finanzas',
  'lib/utils/constants.dart|Innovación',
  'lib/utils/constants.dart|Liderazgo',
  'lib/utils/constants.dart|Sostenibilidad',
  'lib/utils/constants.dart|Tecnología',
  'lib/utils/constants.dart|Comunidad',
  'lib/utils/constants.dart|Marketing',
};
