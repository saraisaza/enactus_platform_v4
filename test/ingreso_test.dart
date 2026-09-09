import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:enactus_platform/utils/constants.dart';

import 'helpers/fake_api.dart';
import 'helpers/portal_harness.dart';

/// Segunda red para F5, la débil de Flutter.
///
/// La auditoría marcó F5 —«la pantalla de ingreso dibuja el formulario»— como
/// débil: al romperla se ponía roja **una sola** prueba, y esa prueba afirma
/// `find.byType(LoginView)`. Es el mismo patrón que los tres huecos originales:
/// **afirma sobre el continente**. Un `LoginView` cuyo botón no envía nada, o
/// que se traga el error del servidor, la sigue cumpliendo.
///
/// Estas entran por el otro lado: miran lo que **sale hacia la API** y lo que
/// pasa cuando el servidor dice que no. No se pueden pasar dibujando.
///
/// Nota de mecánica: acá no se usa `pumpAndSettle`. El logo animado tiene un
/// barrido en bucle de 3600 ms, así que el árbol NUNCA queda quieto y
/// `pumpAndSettle` agota su tiempo. Se avanza con `pump` de duración fija.
void main() {
  setUpAll(cargarFixtures);

  Future<void> asentar(WidgetTester tester) async {
    for (var i = 0; i < 8; i++) {
      await tester.pump(const Duration(milliseconds: 150));
    }
  }

  /// Pulsa «Ingresar» asegurándose de que esté a la vista.
  ///
  /// Sin `ensureVisible` el toque no aterriza: en la ventana de 800x600 de
  /// `flutter_test` el botón queda por debajo del borde, y `tap` sobre algo
  /// fuera de pantalla **no lanza** — solo avisa. La prueba quedaba en rojo
  /// diciendo «pulsar el botón no produjo ninguna petición», que es cierto y
  /// engañoso a la vez: el problema no era el botón.
  Future<void> pulsarIngresar(WidgetTester tester) async {
    final boton = find.text('Ingresar');
    expect(boton, findsOneWidget);
    await tester.ensureVisible(boton);
    await tester.pump();
    await tester.tap(boton);
    await asentar(tester);
  }

  testWidgets('el ingreso envía las credenciales que se escribieron', (tester) async {
    late FakeApi api;
    await montar(tester, appPublica(AppRoutes.login, conApi: (a) {
      api = a;
      a.routes['/auth/login'] = {
        'accessToken': 'token-de-prueba',
        'refreshToken': 'refresh-de-prueba',
        'user': usuarioDe('admin'),
      };
    }));

    final campos = find.byType(TextField);
    expect(campos, findsNWidgets(2),
        reason: 'el formulario de ingreso necesita correo y contraseña');

    await tester.enterText(campos.at(0), 'admin@enactus.co');
    await tester.enterText(campos.at(1), 'Admin123');
    await asentar(tester);

    await pulsarIngresar(tester);

    // 1. Salió la petición, al endpoint y con el método que tocan.
    final indice = api.requested.indexWhere((r) => r.endsWith('/auth/login'));
    expect(indice, isNot(-1),
        reason: 'pulsar el botón no produjo ninguna petición de ingreso: '
            'lo que se pidió fue ${api.requested}');
    expect(api.requested[indice], 'POST /auth/login');

    // 2. Y con lo que la persona escribió. Afirmar solo sobre la ruta dejaría
    //    pasar el fallo del calendario: la petición correcta con el cuerpo
    //    equivocado.
    final cuerpo = api.cuerpos[indice];
    expect(cuerpo['email'], 'admin@enactus.co');
    expect(cuerpo['password'], 'Admin123');
  });

  testWidgets('cuando el servidor rechaza, el mensaje se ve', (tester) async {
    late FakeApi api;
    await montar(tester, appPublica(AppRoutes.login, conApi: (a) {
      api = a;
      // El servidor dice que no. Lo que importa no es el código sino que la
      // persona se entere: un ingreso que falla en silencio se vive como un
      // botón roto, y es exactamente el fallo que tuvo el calendario.
      //
      // La ruta se declara igual aunque vaya a responder 401: el doble exige
      // conocerla, y así el 401 es una decisión de la prueba y no el efecto
      // secundario de una ruta que faltaba.
      a.routes['/auth/login'] = {
        'error': {
          'code': 'unauthorized',
          'message': 'Correo o contraseña incorrectos.',
        },
      };
      a.statuses['/auth/login'] = 401;
    }));

    final campos = find.byType(TextField);
    await tester.enterText(campos.at(0), 'admin@enactus.co');
    await tester.enterText(campos.at(1), 'claveEquivocada');
    await asentar(tester);

    await pulsarIngresar(tester);

    expect(api.requested.any((r) => r.endsWith('/auth/login')), isTrue,
        reason: 'ni siquiera se intentó el ingreso');

    // Sigue en el ingreso —no navegó a ningún portal— y hay un mensaje visible.
    expect(find.byType(TextField), findsNWidgets(2),
        reason: 'salió de la pantalla de ingreso pese a que el ingreso falló');

    final hayMensaje = find.byWidgetPredicate((w) {
      if (w is! Text) return false;
      final t = w.data ?? '';
      return t.toLowerCase().contains('correo') ||
          t.toLowerCase().contains('contraseña') ||
          t.toLowerCase().contains('intento');
    });
    expect(hayMensaje, findsWidgets,
        reason: 'el ingreso falló y no se mostró ningún mensaje: '
            'para quien lo usa, el botón no hizo nada');
  });
}
