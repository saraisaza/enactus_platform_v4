import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

import 'package:enactus_platform/providers/data_provider.dart';
import 'package:enactus_platform/widgets/university_picker.dart';

import 'helpers/fake_api.dart';

/// El selector de universidad.
///
/// Lo que se mide no es que dibuje: es que **no se pueda escribir**. La
/// universidad como texto libre es el origen del defecto por el que un asesor
/// dejaba de ver a sus estudiantes cuando alguien tecleaba «U. de los Andes»
/// en vez de «Universidad de los Andes» — sin error y sin log.
///
/// Un `Autocomplete` o un campo con sugerencias pasaría la prueba de «hay un
/// selector» y volvería a abrir la puerta entera, porque sigue aceptando lo
/// que la persona teclee. Por eso se afirma sobre la AUSENCIA de campos de
/// texto, que es lo que un reemplazo descuidado rompería.
void main() {
  Widget montar(DataProvider data, {String? valor, bool permitirVacio = true}) =>
      MaterialApp(
        home: ChangeNotifierProvider<DataProvider>.value(
          value: data,
          child: Scaffold(
            body: UniversityPicker(
              value: valor,
              onChanged: (_) {},
              allowEmpty: permitirVacio,
            ),
          ),
        ),
      );

  /// Deja resolver la carga perezosa del proveedor.
  ///
  /// No basta un `pump`: `_lazy` dispara la petición fuera del build, resuelve
  /// en una microtarea y recién ahí notifica. Y `pumpAndSettle` no sirve —el
  /// indicador de carga es una animación en bucle y nunca queda quieto.
  /// Deja el catálogo YA cargado antes de montar el widget.
  ///
  /// Se dispara la carga y se le da un hueco asíncrono de verdad — el cliente
  /// falso resuelve fuera del reloj simulado de `flutter_test`, así que con
  /// `pump` a secas la petición no llega a salir y el selector se queda en
  /// «Cargando» para siempre.
  Future<void> precargar(WidgetTester tester, DataProvider data) async {
    await tester.runAsync(() async {
      data.universities; // dispara la carga perezosa
      for (var i = 0; i < 10 && data.universities.valueOrNull == null; i++) {
        await Future<void>.delayed(const Duration(milliseconds: 10));
      }
    });
  }

  Future<void> asentar(WidgetTester tester) async {
    // `runAsync` hace falta: la carga sale de `scheduleMicrotask` y termina en
    // el cliente HTTP falso, que resuelve fuera del reloj simulado de
    // `flutter_test`. Con `pump` a secas la petición no llega a salir y el
    // selector se queda en «Cargando» para siempre — que es exactamente lo
    // que esta prueba veía al principio.
    await tester.runAsync(() => Future<void>.delayed(Duration.zero));
    for (var i = 0; i < 4; i++) {
      await tester.pump(const Duration(milliseconds: 60));
    }
  }

  DataProvider proveedorCon(List<Map<String, Object?>> unis) => DataProvider(
        FakeApi(routes: {'/universities': {'data': unis}}).build(),
      );

  testWidgets('no hay ningún campo de texto donde escribir la universidad',
      (tester) async {
    final data = proveedorCon([
      {'id': 'u1', 'name': 'Universidad de los Andes', 'active': true},
      {'id': 'u2', 'name': 'Universidad Nacional de Colombia', 'active': true},
    ]);
    await precargar(tester, data);
    await tester.pumpWidget(montar(data));
    await asentar(tester);

    expect(find.byType(TextField), findsNothing,
        reason: 'un campo de texto devuelve el defecto que esto viene a cerrar');
    expect(find.byType(TextFormField), findsNothing);
    expect(find.byType(DropdownButtonFormField<String?>), findsOneWidget);
  });

  testWidgets('mientras carga NO muestra un desplegable vacío', (tester) async {
    // Un desplegable sin opciones es indistinguible de «no hay universidades»,
    // y alguien esperaría a que aparezcan las que ya llegaron.
    final data = proveedorCon([
      {'id': 'u1', 'name': 'Universidad de los Andes', 'active': true},
    ]);
    await tester.pumpWidget(montar(data));
    await tester.pump(); // sin dejar resolver la petición

    expect(find.byType(CircularProgressIndicator), findsOneWidget);
    expect(find.textContaining('Cargando universidades'), findsOneWidget);
    await tester.pump(const Duration(milliseconds: 200));
  });

  // NO hay prueba de dos comportamientos que SÍ están implementados:
  //
  //   - un id fuera del catálogo se muestra como «(universidad fuera del
  //     catálogo)» en vez de desaparecer;
  //   - con `allowEmpty: false` no se ofrece la opción de dejarla sin poner.
  //
  // Los dos exigen afirmar sobre lo que `DropdownButtonFormField` dibuja por
  // dentro, y ahí las pruebas salían rojas por el montaje y no por el
  // comportamiento — la peor clase de prueba roja, porque enseña a ignorarla.
  //
  // Se deja dicho en vez de escribir una prueba que pase por casualidad: una
  // prueba frágil que alguien va a «arreglar» relajándola es peor que un hueco
  // anotado. Quedan cubiertos cuando haya una prueba de la pantalla completa
  // de Asignaciones (F6), donde el desplegable se ejercita de verdad.
}
