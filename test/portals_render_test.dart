// Los ocho portales se DIBUJAN, en tres anchos y en todas sus pestañas.
//
// Compilar no prueba que una pantalla funcione: un `Row` que desborda, una
// lista sin acotar o un `Column` sin `Expanded` son fallos de EJECUCIÓN. Esta
// suite monta el portal de cada rol y exige que Flutter no lance ninguna
// excepción — que es exactamente lo que veía quien abría la app.
//
// **Por qué contra la API falsa y no contra el backend real**: dentro de
// `testWidgets` el tiempo es falso, así que una petición real nunca completa;
// la prueba se cuelga o deja temporizadores vivos y falla por eso, no por la
// pantalla. Las formas de los datos las verifica `e2e_provider_contract_test`
// contra el servidor de verdad; acá lo que se prueba es la maquetación.
//
// Y se prueba en TRES anchos, no en uno. El desbordamiento de 559px del pie de
// página no aparecía en escritorio ancho: solo por debajo de ~900px. Un único
// tamaño deja pasar justo la clase de error que esta suite existe para
// atrapar.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:enactus_platform/main.dart';
import 'package:enactus_platform/providers/auth_provider.dart';
import 'package:enactus_platform/providers/data_provider.dart';
import 'package:enactus_platform/models/models.dart';
import 'package:enactus_platform/utils/constants.dart';

import 'helpers/fake_api.dart';

/// Una página vacía con la forma que devuelve la API.
Map<String, Object?> _page(List<Object?> data) => {
      'data': data,
      'page': 1,
      'pageSize': 100,
      'total': data.length,
      'totalPages': 1,
    };

Map<String, Object?> _usuario(String role) => {
      'id': 'u1',
      'name': 'Persona de Prueba',
      'email': 'prueba@enactus.co',
      'role': role,
      'studentType': Roles.isStudentLike(role) ? StudentType.enactus : null,
      'phone': '3001112233',
      'cedula': '',
      'city': 'Bogotá',
      'university': 'Universidad de los Andes',
      'career': 'Ingeniería',
      'companyName': role == Roles.company ? 'Empresa Aliada' : '',
      'impactCode': role == Roles.donor ? 'ENACTUS-2026-1000' : null,
      'canGradeOpenLearning': true,
      'canGradeEnactus': false,
      'profile': const <String, Object?>{},
    };

/// Todo lo que un portal puede pedir. Lo que no esté acá cae al `fallback`.
///
/// Se devuelven listas VACÍAS a propósito: una pantalla vacía es el caso más
/// difícil de dibujar bien —no hay contenido que empuje el layout a un tamaño
/// razonable— y es el que más suele romperse.
FakeApi _fake(String role) => FakeApi(
      routes: {
        '/auth/me': _usuario(role),
        '/site-content': {
          'heroTitle': 'eduXaction Colombia',
          'heroSubtitle': 'Formamos líderes',
          'bannerText': '',
          'aboutText': 'Sobre nosotros',
          'meetingLink': '',
          'statStudents': 120,
          'statProjects': 8,
          'statLabs': 6,
          'statUniversities': 12,
          'laboratories': const [],
          'galleryImages': const [],
          'gallery': const [],
        },
        '/catalogs': {
          'competencies': const [
            {'code': 'leadership', 'name': 'Liderazgo'},
          ],
          'ods': const [
            {'code': 'ods_4', 'number': 4, 'title': 'Educación de calidad'},
          ],
        },
        '/admin/metrics': {
          'counts': const {
            'students': 5,
            'alumni': 1,
            'mentors': 2,
            'lxds': 3,
            'advisors': 1,
            'companies': 1,
            'donors': 1,
            'projects': 2,
            'groups': 2,
            'courses': 9,
            'laboratories': 6,
            'certificates': 0,
            'universities': 2,
            'submissionsPending': 2,
          },
          'hoursByCompetency': const [
            {'code': 'leadership', 'name': 'Liderazgo', 'hours': 10.5},
          ],
          'odsCompletionRate': const [
            {
              'code': 'ods_4',
              'number': 4,
              'title': 'Educación de calidad',
              'rate': 0.5,
              'completed': 1,
              'total': 2,
            },
          ],
          'sponsoredHoursByCompany': const [
            {'companyId': 'c1', 'companyName': 'Empresa Aliada', 'hours': 12.0},
          ],
        },
        '/forum-posts/stats': const {
          'totalPosts': 0,
          'totalReplies': 0,
          'activeTeams': <Object?>[],
        },
      },
      // Cualquier otra ruta responde una página vacía. Enumerar las cincuenta
      // que puede pedir un portal solo agregaría ruido a una prueba que mide
      // maquetación, no payloads.
      fallback: (path) => _page(const []),
    );

Widget _app(String role) {
  final api = _fake(role).build();
  final data = DataProvider(api);
  final auth = AuthProvider(api, data);
  // Se marca la sesión sin pasar por el ingreso: lo que se prueba es el
  // portal, no el login. Sin esto el guardia de rol redirige y la prueba
  // verificaría la pantalla de ingreso creyendo que verifica el portal.
  auth.debugSetSession(_usuario(role));

  return EnactusApp(
    api: api,
    data: data,
    auth: auth,
    initialRoute: AppRoutes.forRole(role),
  );
}

/// Monta, deja pasar unos frames y devuelve las excepciones que lanzó Flutter.
Future<List<String>> _montar(WidgetTester tester, Widget app) async {
  final excepciones = <String>[];
  final anterior = FlutterError.onError;
  FlutterError.onError = (details) => excepciones.add(
      '${details.exception}\n${details.context}\n'
      '${details.informationCollector?.call().take(4).join('\n') ?? ''}');
  try {
    await tester.pumpWidget(app);
    for (var i = 0; i < 6; i++) {
      await tester.pump(const Duration(milliseconds: 120));
    }
  } finally {
    FlutterError.onError = anterior;
  }
  return excepciones;
}

const _roles = [
  Roles.superAdmin,
  Roles.admin,
  Roles.lxd,
  Roles.mentor,
  Roles.advisor,
  Roles.company,
  Roles.donor,
  Roles.student,
  Roles.alumni,
];

void main() {
  // Lo mismo que hace `main()` antes de `runApp`. Sin esto, cualquier pantalla
  // que formatee una fecha revienta — y el fallo diría "locale no
  // inicializado", no "la pantalla está rota".
  setUpAll(() => initializeDateFormatting('es'));

  setUp(() => SharedPreferences.setMockInitialValues({}));

  for (final (etiqueta, tamano) in const [
    ('teléfono', Size(390, 844)),
    ('tablet', Size(768, 1024)),
    ('escritorio', Size(1440, 900)),
  ]) {
    for (final role in _roles) {
      testWidgets('${Roles.label(role)} en $etiqueta: su portal se dibuja',
          (tester) async {
        await tester.binding.setSurfaceSize(tamano);
        addTearDown(() => tester.binding.setSurfaceSize(null));

        final excepciones = await _montar(tester, _app(role));

        expect(excepciones, isEmpty,
            reason: 'El portal de ${Roles.label(role)} a '
                '${tamano.width.round()}px lanzó:\n${excepciones.join('\n')}');
      });
    }
  }

  /// Recorre TODAS las pestañas, no solo la primera.
  ///
  /// Un portal que abre bien puede tener rota su cuarta pestaña, y montar solo
  /// la inicial no lo vería nunca. Se hace en escritorio porque ahí la barra
  /// lateral muestra los rótulos y se puede tocar cada uno por su nombre.
  for (final role in _roles) {
    testWidgets('${Roles.label(role)}: TODAS sus pestañas se dibujan',
        (tester) async {
      await tester.binding.setSurfaceSize(const Size(1440, 900));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      await _montar(tester, _app(role));

      final barra = find.byType(ListView);
      if (barra.evaluate().isEmpty) return; // portal sin barra lateral

      final rotulos = tester
          .widgetList<Text>(
              find.descendant(of: barra.first, matching: find.byType(Text)))
          .map((t) => t.data)
          .whereType<String>()
          .toList();
      expect(rotulos, isNotEmpty,
          reason: 'No se encontró la barra lateral de ${Roles.label(role)}');

      final rotos = <String>[];
      for (final rotulo in rotulos) {
        final anterior = FlutterError.onError;
        FlutterError.onError = (d) => rotos.add('[$rotulo] ${d.exception}\n'
            '${d.context}\n'
            '${d.informationCollector?.call().take(4).join('\n') ?? ''}');
        try {
          final destino = find.text(rotulo);
          if (destino.evaluate().isEmpty) continue;
          await tester.tap(destino.first, warnIfMissed: false);
          for (var i = 0; i < 5; i++) {
            await tester.pump(const Duration(milliseconds: 120));
          }
        } finally {
          FlutterError.onError = anterior;
        }
      }

      expect(rotos, isEmpty,
          reason: 'Pestañas rotas en ${Roles.label(role)}:\n'
              '${rotos.join('\n')}');
    });
  }
}
