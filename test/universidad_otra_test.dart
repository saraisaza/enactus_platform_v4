// «Otra (¿cuál?)» en el desplegable de universidad.
//
// Que nadie se quede sin poder inscribirse, SIN volver al texto libre: lo que
// se escribe en «Otra» se vuelve una universidad del catálogo
// (`POST /universities`) y la persona se guarda con el id de esa fila, nunca
// con el texto. Se afirma sobre lo que la app ENVÍA, en ese orden.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

import 'package:enactus_platform/providers/data_provider.dart';
import 'package:enactus_platform/utils/constants.dart';
import 'package:enactus_platform/views/admin/admin_users.dart';
import 'package:enactus_platform/widgets/university_picker.dart';

import 'helpers/fake_api.dart';

const _nueva = 'Institución Universitaria de Prueba';
// Ids con forma de uuid: los cuerpos que la app manda quedan grabados en el
// contrato, y el servidor rechaza un id que no la tenga.
const _andes = 'dddddddd-0000-4000-8000-0000000000a1';
const _idNueva = 'dddddddd-0000-4000-8000-0000000000b1';

FakeApi _api() => FakeApi(routes: {
      '/universities': {
        'data': [
          {'id': _andes, 'name': 'Universidad de los Andes', 'active': true},
        ],
      },
      'POST /universities': {
        'id': _idNueva,
        'name': _nueva,
        'active': true,
        'existente': false,
      },
      '/users': {
        'id': 'dddddddd-0000-4000-8000-0000000000c1',
        'name': 'Estudiante Nueva',
        'email': 'nueva@prueba.co',
        'role': Roles.student,
        'studentType': 'enactus',
        'universityId': _idNueva,
        'university': _nueva,
      },
    });

Future<void> _precargar(WidgetTester tester, DataProvider data) async {
  await tester.runAsync(() async {
    data.universities;
    for (var i = 0; i < 20 && data.universities.valueOrNull == null; i++) {
      await Future<void>.delayed(const Duration(milliseconds: 10));
    }
  });
}

Future<void> _pasos(WidgetTester tester) async {
  await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 20)));
  for (var i = 0; i < 4; i++) {
    await tester.pump(const Duration(milliseconds: 80));
  }
}

void main() {
  testWidgets('sin «Otra», el desplegable sigue sin campo de texto',
      (tester) async {
    final data = DataProvider(_api().build());
    await _precargar(tester, data);
    final otra = TextEditingController();
    addTearDown(otra.dispose);
    await tester.pumpWidget(MaterialApp(
      home: ChangeNotifierProvider<DataProvider>.value(
        value: data,
        child: Scaffold(
          body: UniversityPicker(
            value: _andes,
            onChanged: (_) {},
            otraController: otra,
          ),
        ),
      ),
    ));
    await _pasos(tester);
    // Ofrecer «Otra» no abre un campo: solo aparece si se elige.
    expect(find.byType(TextField), findsNothing);
  });

  testWidgets(
      'eligiendo «Otra» se escribe la institución, se agrega al catálogo y la '
      'persona queda con su id', (tester) async {
    useFakeTokenStorage();
    tester.view.devicePixelRatio = 1.0;
    tester.view.physicalSize = const Size(1280, 1000);
    addTearDown(tester.view.reset);

    final fake = _api();
    final data = DataProvider(fake.build());
    await _precargar(tester, data);
    var guardado = false;
    // El proveedor va POR ENCIMA de la app, como en `EnactusApp`: el
    // formulario es un diálogo y vive en el navegador raíz.
    await tester.pumpWidget(ChangeNotifierProvider<DataProvider>.value(
      value: data,
      child: MaterialApp(
        home: Scaffold(
          body: Builder(
            builder: (context) => TextButton(
              onPressed: () async => guardado = await showUserDialog(
                context,
                creatableRoles: const [Roles.student],
                isSuperAdmin: false,
              ),
              child: const Text('abrir'),
            ),
          ),
        ),
      ),
    ));
    await tester.tap(find.text('abrir'));
    await _pasos(tester);

    await tester.enterText(
        find.widgetWithText(TextField, 'Nombre completo'), 'Estudiante Nueva');
    await tester.enterText(
        find.widgetWithText(TextField, 'Correo electrónico'), 'nueva@prueba.co');
    await tester.enterText(
        find.widgetWithText(TextField, 'Contraseña'), 'Clave123');

    // El desplegable de universidad, y su última opción.
    final desplegable = find.byType(DropdownButtonFormField<String?>);
    await tester.ensureVisible(desplegable);
    await tester.pump();
    await tester.tap(desplegable);
    await _pasos(tester);
    await tester.tap(find.text('Otra (¿cuál?)').last);
    await _pasos(tester);

    final cual = find.widgetWithText(TextField, '¿Cuál institución?');
    expect(cual, findsOneWidget);
    await tester.enterText(cual, '  $_nueva ');
    await tester.pump();

    await tester.tap(find.widgetWithText(ElevatedButton, 'Guardar'));
    await _pasos(tester);
    await _pasos(tester);

    final crear = fake.requested.indexOf('POST /universities');
    final alta = fake.requested.indexOf('POST /users');
    expect(crear, isNot(-1), reason: '«Otra» no agregó la institución.');
    expect(fake.cuerpos[crear], {'name': _nueva});
    expect(alta, greaterThan(crear),
        reason: 'La persona se guardó antes de tener su universidad.');
    expect(fake.cuerpos[alta]['universityId'], _idNueva,
        reason: 'La persona no quedó con el id de la institución nueva.');
    expect(fake.cuerpos[alta].values, isNot(contains(UniversityPicker.otra)));
    expect(guardado, isTrue);
  });
}
