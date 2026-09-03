// La pantalla de cambio obligatorio de contraseña.
//
// Lo que se prueba no es que se dibuje bonita, es que **no se pueda esquivar**.
// El servidor responde 403 `password_change_required` a casi todo mientras la
// bandera esté puesta, así que un portal mostrado en ese estado sería una
// pantalla que no puede cargar nada — y la persona no tendría cómo salir de
// ahí.
//
// La contracara importa igual: quien NO tiene la obligación pendiente no puede
// terminar en esta pantalla, porque eso sería un portal secuestrado.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';

import 'package:enactus_platform/utils/constants.dart';
import 'package:enactus_platform/views/auth/change_password_view.dart';
import 'package:enactus_platform/views/auth/login_view.dart';
import 'package:enactus_platform/widgets/portal_shell.dart';

import 'helpers/portal_harness.dart';

void main() {
  setUpAll(() async {
    await initializeDateFormatting('es');
    cargarFixtures();
  });

  setUp(conSesionGuardada);

  testWidgets('con la obligación pendiente NO se ve el portal', (tester) async {
    fijarTamano(tester, const Size(1440, 900));
    final excepciones = await montar(tester, appDe(Roles.admin, pendiente: true));

    expect(find.byType(ChangePasswordView), findsOneWidget,
        reason: 'La persona tiene que ver la pantalla de cambio.');
    expect(find.byType(PortalShell), findsNothing,
        reason: 'El portal no puede aparecer: la API responde 403 a todo y la '
            'pantalla quedaría vacía sin explicar por qué.');
    expect(excepciones, isEmpty, reason: excepciones.join('\n'));
  });

  testWidgets('sin la obligación, el portal se ve normal', (tester) async {
    // La contracara: si la pantalla apareciera igual, sería un portal
    // secuestrado.
    fijarTamano(tester, const Size(1440, 900));
    await montar(tester, appDe(Roles.admin));

    expect(find.byType(ChangePasswordView), findsNothing);
    expect(find.byType(PortalShell), findsOneWidget);
  });

  // El bloqueo vive en `requireAuth`, así que alcanza a cualquiera. Si la
  // pantalla solo apareciera para algunos, el resto entraría a un portal mudo.
  //
  // Un `testWidgets` por rol y no un bucle dentro de uno: montar varias apps
  // en la misma prueba arrastra el estado de la anterior —la sesión se
  // restaura una sola vez, tras el primer frame— y la segunda falla por eso y
  // no por lo que se quiere medir.
  for (final rol in rolesDePortal) {
    testWidgets('a ${Roles.label(rol)} también le aparece', (tester) async {
      fijarTamano(tester, const Size(1440, 900));
      await montar(tester, appDe(rol, pendiente: true));
      expect(find.byType(ChangePasswordView), findsOneWidget,
          reason: 'A ${Roles.label(rol)} no le apareció la pantalla.');
      expect(find.byType(PortalShell), findsNothing,
          reason: 'A ${Roles.label(rol)} se le dibujó el portal igual.');
    });
  }

  testWidgets('no deja enviar hasta que los tres campos estén bien',
      (tester) async {
    fijarTamano(tester, const Size(1440, 900));
    await montar(tester, appDe(Roles.admin, pendiente: true));

    ElevatedButton boton() => tester.widget<ElevatedButton>(
        find.widgetWithText(ElevatedButton, 'Guardar y continuar'));

    expect(boton().onPressed, isNull, reason: 'Con todo vacío no se envía.');

    final campos = find.byType(TextField);
    expect(campos, findsNWidgets(3));

    await tester.enterText(campos.at(0), 'ClaveActual2026\$');
    await tester.enterText(campos.at(1), 'corta');
    await tester.pump();
    expect(boton().onPressed, isNull,
        reason: 'Menos de 12 caracteres no se envía.');

    await tester.enterText(campos.at(1), 'ClaveNuevaLarga2026\$');
    await tester.enterText(campos.at(2), 'OtraDistinta2026\$');
    await tester.pump();
    expect(boton().onPressed, isNull,
        reason: 'Si las dos nuevas no coinciden, no se envía.');

    await tester.enterText(campos.at(2), 'ClaveNuevaLarga2026\$');
    await tester.pump();
    expect(boton().onPressed, isNotNull,
        reason: 'Con los tres campos correctos, sí se envía.');
  });

  testWidgets('no acepta repetir la contraseña actual', (tester) async {
    // Si no, la obligación se cumple escribiendo la que ya tenía.
    fijarTamano(tester, const Size(1440, 900));
    await montar(tester, appDe(Roles.admin, pendiente: true));

    final campos = find.byType(TextField);
    await tester.enterText(campos.at(0), 'LaMismaDeSiempre2026\$');
    await tester.enterText(campos.at(1), 'LaMismaDeSiempre2026\$');
    await tester.enterText(campos.at(2), 'LaMismaDeSiempre2026\$');
    await tester.pump();

    expect(
        tester
            .widget<ElevatedButton>(
                find.widgetWithText(ElevatedButton, 'Guardar y continuar'))
            .onPressed,
        isNull);
  });

  testWidgets('hay salida: se puede cerrar sesión', (tester) async {
    // Sin esto, quien no quiera cambiarla ahora queda encerrado en una
    // pantalla sin salida.
    fijarTamano(tester, const Size(1440, 900));
    await montar(tester, appDe(Roles.admin, pendiente: true));

    final salir = find.widgetWithText(TextButton, 'Cerrar sesión');
    expect(salir, findsOneWidget);

    await tester.tap(salir);
    for (var i = 0; i < 8; i++) {
      await tester.pump(const Duration(milliseconds: 120));
    }
    expect(find.byType(ChangePasswordView), findsNothing);
  });

  testWidgets('NO ofrece "más tarde"', (tester) async {
    // No hay más tarde: la API no responde nada hasta el cambio. Un botón que
    // prometiera posponerlo llevaría a un portal mudo.
    fijarTamano(tester, const Size(1440, 900));
    await montar(tester, appDe(Roles.admin, pendiente: true));

    for (final texto in ['Más tarde', 'Mas tarde', 'Omitir', 'Saltar', 'Ahora no']) {
      expect(find.text(texto), findsNothing,
          reason: 'Aparece "$texto": no hay forma de posponerlo.');
    }
  });

  testWidgets('el ingreso sigue funcionando sin obligación', (tester) async {
    // Que la pantalla nueva no se haya metido en el camino de quien entra
    // normalmente.
    fijarTamano(tester, const Size(1440, 900));
    await montar(tester, appPublica(AppRoutes.login));
    expect(find.byType(LoginView), findsOneWidget);
    expect(find.byType(ChangePasswordView), findsNothing);
  });
}
