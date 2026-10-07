// Las cuentas de un cliente, del lado de la app (etapa 3).
//
// - Al entrar, la plataforma toma la marca del cliente de ESA cuenta; al
//   salir, vuelve la de eduXaction.
// - Si el cliente se desactiva con la sesión abierta, la sesión se cierra y
//   la pantalla de ingreso dice por qué — no queda cada pantalla diciendo «no
//   tiene permiso».
// - El encabezado muestra el logo del cliente junto al de eduXaction.
// - En el panel, «Empresa» es una cuenta de Open Learning de una empresa: el
//   formulario exige la empresa y manda lo que el servidor espera.

import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:provider/provider.dart';

import 'package:enactus_platform/l10n/textos.dart';
import 'package:enactus_platform/providers/auth_provider.dart';
import 'package:enactus_platform/providers/data_provider.dart';
import 'package:enactus_platform/services/api_service.dart';
import 'package:enactus_platform/utils/app_theme.dart';
import 'package:enactus_platform/utils/constants.dart';
import 'package:enactus_platform/utils/marca.dart';
import 'package:enactus_platform/views/admin/admin_users.dart';
import 'package:enactus_platform/widgets/app_header.dart';
import 'package:enactus_platform/widgets/logo_de_cliente.dart';

import 'helpers/fake_api.dart';
import 'helpers/portal_harness.dart';

const _azul = Color(0xFF1A73E8);
const _idAndino = '2f8d4b61-9c0a-4e7b-8d12-5a6b7c8d9e02';

Map<String, Object?> _deAndino({String? logoUrl}) => {
      'studentType': 'open_learning',
      'clientId': _idAndino,
      'client': {
        'id': _idAndino,
        'name': 'Banco Andino',
        'logoUrl': logoUrl,
        'logoWidth': logoUrl == null ? null : 440,
        'logoHeight': logoUrl == null ? null : 120,
        'logoLightPlate': false,
        'primaryColor': '#1A73E8',
        'secondaryColor': '#0B5394',
        'hasLaboratories': false,
      },
    };

void main() {
  setUpAll(() async {
    await initializeDateFormatting('es');
    cargarFixtures();
  });
  setUp(conSesionGuardada);
  tearDown(() {
    Marca.instancia.restablecer();
    imagenDeLogo = NetworkImage.new;
  });

  group('la marca al entrar y al salir', () {
    testWidgets('una cuenta de empresa entra con su marca, y al salir vuelve eduXaction',
        (tester) async {
      fijarTamano(tester, const Size(1440, 900));
      await montar(tester, appDe(Roles.student, cambios: _deAndino()));
      expect(AppColors.relleno, _azul);
      expect(AppColors.gold, Marca.instancia.paleta.tintaSobreOscuro);

      final auth = Provider.of<AuthProvider>(
          tester.element(find.byType(AppHeader)), listen: false);
      await tester.runAsync(auth.logout);
      await tester.pump();
      expect(AppColors.relleno, const Color(0xFFFFC107));
    });

    testWidgets('una cuenta de Enactus, sin marca propia, se ve como siempre',
        (tester) async {
      fijarTamano(tester, const Size(1440, 900));
      await montar(tester, appDe(Roles.student));
      expect(Marca.instancia.paleta, PaletaMarca.eduXaction);
    });

    testWidgets('el encabezado muestra el logo del cliente junto al de eduXaction',
        (tester) async {
      fijarTamano(tester, const Size(1440, 900));
      imagenDeLogo = (_) => MemoryImage(_pngTransparente);
      await montar(tester,
          appDe(Roles.student, cambios: _deAndino(logoUrl: 'https://logos.prueba/a.png')));
      expect(
        find.descendant(of: find.byType(AppHeader), matching: find.byType(LogoDeCliente)),
        findsOneWidget,
      );
      expect(find.bySemanticsLabel(tr.clientesLogoDe('Banco Andino')), findsOneWidget);
    });

    testWidgets('sin logo de cliente, el encabezado es el de siempre', (tester) async {
      fijarTamano(tester, const Size(1440, 900));
      await montar(tester, appDe(Roles.student, cambios: _deAndino()));
      expect(find.byType(LogoDeCliente), findsNothing);
    });
  });

  group('un cliente desactivado', () {
    test('cierra la sesión y deja el motivo para la pantalla de ingreso', () async {
      const motivo =
          'El acceso de Banco Andino a la plataforma está desactivado.';
      useFakeTokenStorage();
      var pedidos = 0;
      final api = ApiService(
        client: MockClient((pedido) async {
          pedidos++;
          return http.Response(
            jsonEncode({
              'error': {'code': 'client_inactive', 'message': motivo},
            }),
            403,
            headers: {'content-type': 'application/json; charset=utf-8'},
          );
        }),
      );
      final auth = AuthProvider(api, DataProvider(api));
      await api.tokens.save(accessToken: 'a', refreshToken: 'r');

      await expectLater(api.get('/courses'), throwsA(isA<Object>()));
      expect(pedidos, 1);
      expect(auth.currentUser, isNull);
      expect(auth.avisoDeSesion, motivo);
      expect(await api.tokens.readAccess(), isNull,
          reason: 'sin los tokens, la próxima vez no intenta entrar con la sesión vieja');
    });
  });

  group('el formulario de cuentas', () {
    Future<FakeApi> abrirFormulario(WidgetTester tester) async {
      tester.view.devicePixelRatio = 1.0;
      tester.view.physicalSize = const Size(1280, 1400);
      addTearDown(tester.view.reset);
      final api = FakeApi(routes: {
        '/clients': {
          'data': [
            {'id': 'enactus', 'name': 'Enactus', 'hasLaboratories': true, 'active': true},
            {'id': _idAndino, 'name': 'Banco Andino', 'hasLaboratories': false, 'active': true},
          ],
        },
        '/universities': {'data': <Object>[]},
        '/users': {
          'id': 'dddddddd-0000-4000-8000-0000000000c9',
          'name': 'Ana',
          'email': 'ana@bancoandino.co',
          'role': 'student',
          'studentType': 'open_learning',
          'clientId': _idAndino,
        },
      }, fallback: (_) => {'data': <Object>[]});
      final data = DataProvider(api.build());
      await tester.pumpWidget(ChangeNotifierProvider<DataProvider>.value(
        value: data,
        child: MaterialApp(
          theme: buildAppTheme(),
          home: Scaffold(
            body: Builder(
              builder: (context) => Center(
                child: ElevatedButton(
                  onPressed: () => showUserDialog(context,
                      creatableRoles: const [Roles.student, Roles.lxd],
                      isSuperAdmin: false),
                  child: const Text('abrir'),
                ),
              ),
            ),
          ),
        ),
      ));
      await tester.tap(find.text('abrir'));
      await tester.pumpAndSettle();
      return api;
    }

    Future<void> pasos(WidgetTester tester) async {
      await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 30)));
      for (var i = 0; i < 4; i++) {
        await tester.pump(const Duration(milliseconds: 80));
      }
    }

    testWidgets('«Empresa» exige la empresa, y guarda Open Learning con su cliente',
        (tester) async {
      final api = await abrirFormulario(tester);
      await tester.enterText(
          find.widgetWithText(TextField, tr.usuariosNombreCompleto), 'Ana');
      await tester.enterText(find.widgetWithText(TextField, tr.ingresoCorreo),
          'ana@bancoandino.co');
      await tester.enterText(
          find.widgetWithText(TextField, tr.ingresoContrasena), 'Clave123');

      await tester.tap(find.text(StudentTypeLabels.eduXaction).last);
      await tester.pumpAndSettle();
      await tester.tap(find.text(tr.usuariosTipoEmpresa).last);
      await pasos(tester);

      // Sin elegir la empresa, no guarda.
      await tester.tap(find.text(tr.comunGuardar));
      await tester.pump();
      expect(find.text(tr.usuariosEligaEmpresa), findsOneWidget);
      expect(api.requested.where((r) => r == 'POST /users'), isEmpty);

      await tester.tap(find.text(tr.usuariosEmpresaCliente));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Banco Andino').last);
      await tester.pumpAndSettle();
      await tester.tap(find.text(tr.comunGuardar));
      await pasos(tester);

      final i = api.requested.indexOf('POST /users');
      expect(i, isNot(-1), reason: 'pidió: ${api.requested}');
      expect(api.cuerpos[i]['studentType'], 'open_learning');
      expect(api.cuerpos[i]['clientId'], _idAndino);
      // Enactus no se ofrece: sus cuentas llegan a él solas.
      expect(find.text('Enactus'), findsNothing);
    });
  });
}

/// Etiquetas de tipo, tal como las muestra el desplegable.
abstract final class StudentTypeLabels {
  static const eduXaction = 'eduXaction';
}

/// Un PNG de 1×1 transparente: lo mínimo para que el encabezado tenga una
/// imagen que dibujar.
final _pngTransparente = base64Decode(
    'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVR42mNkYPhfDwAChwGA60e6kgAAAABJRU5ErkJggg==');
