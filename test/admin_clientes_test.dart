// El panel de clientes: formulario, colores, vista previa y análisis del logo.
//
// Lo que se fija acá es lo que quien administra no ve a simple vista:
// - qué cuerpo exacto llega al servidor (un color mal formateado, o un
//   secundario sin primario, guardaría una marca que la app no sabe pintar);
// - que la vista previa y el informe usan los colores que se están eligiendo,
//   y no los de la marca activa (la de eduXaction, la del admin);
// - que el logo se analiza mirando el archivo: PNG de verdad, medidas, y si
//   desaparecería sobre el encabezado gris.

import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

import 'package:enactus_platform/l10n/textos.dart';
import 'package:enactus_platform/models/client.dart';
import 'package:enactus_platform/providers/data_provider.dart';
import 'package:enactus_platform/utils/analisis_logo.dart';
import 'package:enactus_platform/utils/app_theme.dart';
import 'package:enactus_platform/utils/formatos.dart';
import 'package:enactus_platform/utils/marca.dart';
import 'package:enactus_platform/views/admin/admin_clients.dart';
import 'package:enactus_platform/widgets/vista_previa_marca.dart';

import 'helpers/fake_api.dart';

const _idAndino = '2f8d4b61-9c0a-4e7b-8d12-5a6b7c8d9e02';

const _andino = Client(
  id: _idAndino,
  name: 'Banco Andino',
  primaryColor: '#1A73E8',
  secondaryColor: '#0B5394',
);

Map<String, Object?> _clienteJson(String nombre, {String? primario}) => {
      'id': _idAndino,
      'name': nombre,
      'primaryColor': primario,
      'secondaryColor': null,
      'logoLightPlate': false,
      'hasLaboratories': false,
      'active': true,
    };

FakeApi _api() => FakeApi(routes: {
      '/clients': {'data': <Object>[]},
      'POST /clients': _clienteJson('Banco Norte', primario: '#1A73E8'),
      '/clients/$_idAndino': _clienteJson('Banco Andino', primario: '#1A73E8'),
    });

Future<void> _montar(WidgetTester tester, FakeApi api, {Client? original}) async {
  tester.view.devicePixelRatio = 1.0;
  tester.view.physicalSize = const Size(1280, 1000);
  addTearDown(tester.view.reset);
  final data = DataProvider(api.build());
  // El proveedor va POR ENCIMA de `MaterialApp`, como en la app: el diálogo
  // se abre en otra ruta y no vería uno puesto dentro de `home`.
  await tester.pumpWidget(ChangeNotifierProvider<DataProvider>.value(
    value: data,
    child: MaterialApp(
      theme: buildAppTheme(),
      home: Scaffold(
        body: Builder(
          builder: (context) => Center(
            child: ElevatedButton(
              onPressed: () => mostrarEditorDeCliente(context, original),
              child: const Text('abrir'),
            ),
          ),
        ),
      ),
    ),
  ));
  await tester.tap(find.text('abrir'));
  await tester.pumpAndSettle();
}

/// Deja terminar los pedidos de la API falsa (son `Future` de verdad).
Future<void> _pasos(WidgetTester tester) async {
  await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 30)));
  for (var i = 0; i < 4; i++) {
    await tester.pump(const Duration(milliseconds: 80));
  }
}

Finder _campo(String etiqueta) =>
    find.widgetWithText(TextField, etiqueta);

/// La franja de arriba de la vista previa: se pinta con el primario.
List<Color> _franjasDeLaVistaPrevia(WidgetTester tester) => tester
    .widgetList<Container>(find.descendant(
        of: find.byType(VistaPreviaMarca), matching: find.byType(Container)))
    .where((c) => c.constraints?.maxHeight == 3)
    .map((c) => c.color!)
    .toList();

/// Un PNG de verdad: un rectángulo de [color] en el centro y, alrededor,
/// transparente (o blanco, con [conFondo]).
Future<Uint8List> _png(int ancho, int alto, Color color, {bool conFondo = false}) async {
  final grabadora = ui.PictureRecorder();
  final lienzo = Canvas(grabadora);
  if (conFondo) {
    lienzo.drawRect(Rect.fromLTWH(0, 0, ancho.toDouble(), alto.toDouble()),
        Paint()..color = const Color(0xFFFFFFFF));
  }
  lienzo.drawRect(
      Rect.fromLTWH(ancho * 0.1, alto * 0.2, ancho * 0.8, alto * 0.6),
      Paint()..color = color);
  final imagen = await grabadora.endRecording().toImage(ancho, alto);
  final datos = await imagen.toByteData(format: ui.ImageByteFormat.png);
  return datos!.buffer.asUint8List();
}

void main() {
  tearDown(Marca.instancia.restablecer);

  group('el formulario', () {
    testWidgets('sin nombre no guarda, y no le pide nada al servidor',
        (tester) async {
      final api = _api();
      await _montar(tester, api);
      await tester.tap(find.text(tr.comunGuardar));
      await tester.pump();
      expect(find.text(tr.clientesNombreFalta), findsOneWidget);
      expect(api.requested.where((r) => r.startsWith('POST')), isEmpty);
    });

    testWidgets(
        'un color escrito como sea llega como #RRGGBB, y la vista previa lo usa',
        (tester) async {
      final api = _api();
      await _montar(tester, api);

      await tester.enterText(_campo(tr.clientesNombre), 'Banco Norte');
      await tester.enterText(_campo(tr.clientesColorPrimario), '1a73e8');
      await tester.pump();

      // La vista previa pinta con el color elegido, aunque la marca activa
      // (la del admin) siga siendo la de eduXaction.
      expect(AppColors.gold, const Color(0xFFFFC107));
      expect(_franjasDeLaVistaPrevia(tester), everyElement(const Color(0xFF1A73E8)));

      // El informe dice a qué color se aclaró el texto, y es el que calcula
      // la paleta: no un número escrito en la prueba. Se compara la frase
      // ENTERA: con los datos en otro orden decía «su color daba #629FEF:1».
      final p = PaletaMarca.desde(primario: const Color(0xFF1A73E8));
      final frase = tr.clientesInformeOscuroAjustado(
        decimal(contraste(p.primario, PaletaMarca.fondoOscuroMasClaro), 2),
        hexDe(p.tintaSobreOscuro),
        decimal(contraste(p.tintaSobreOscuro, PaletaMarca.fondoOscuroMasClaro), 2),
      );
      expect(find.text(frase), findsOneWidget);
      expect(frase, contains('2,74:1'));
      expect(frase, contains('${hexDe(p.tintaSobreOscuro)} (4,5'));

      await tester.tap(find.text(tr.comunGuardar));
      await _pasos(tester);

      final i = api.requested.indexOf('POST /clients');
      expect(i, isNot(-1), reason: 'pidió: ${api.requested}');
      expect(api.cuerpos[i], {
        'name': 'Banco Norte',
        'primaryColor': '#1A73E8',
        'secondaryColor': null,
        'logoLightPlate': false,
      });
    });

    testWidgets('un primario muy oscuro: el texto se lee, pero se avisa que el botón se funde',
        (tester) async {
      await _montar(tester, _api());
      await tester.enterText(_campo(tr.clientesColorPrimario), '#0B2D5B');
      await tester.pump();
      expect(find.textContaining(tr.clientesInformeBotonSeFunde('').split('(').first),
          findsOneWidget);
      // Con el azul medio del ejemplo, en cambio, no hay aviso.
      await tester.enterText(_campo(tr.clientesColorPrimario), '#1A73E8');
      await tester.pump();
      expect(find.textContaining(tr.clientesInformeBotonSeFunde('').split('(').first),
          findsNothing);
    });

    testWidgets('un código que no es hexadecimal se señala y no cambia el color',
        (tester) async {
      await _montar(tester, _api());
      await tester.enterText(_campo(tr.clientesColorPrimario), 'azul');
      await tester.pump();
      expect(find.text(tr.clientesColorInvalido), findsOneWidget);
      // Sin primario válido, la vista previa sigue con el ámbar de eduXaction.
      expect(_franjasDeLaVistaPrevia(tester), everyElement(const Color(0xFFFFC107)));
    });

    testWidgets('sin primario, el secundario no se puede elegir', (tester) async {
      await _montar(tester, _api());
      final secundario = tester.widget<TextField>(_campo(tr.clientesColorSecundario));
      expect(secundario.enabled, isFalse);
    });

    testWidgets('editar: quitar el secundario lo manda en null, y el resto igual',
        (tester) async {
      final api = _api();
      await _montar(tester, api, original: _andino);
      expect(find.text('#0B5394'), findsOneWidget);

      await tester.tap(find.byTooltip(
          tr.clientesQuitarColor(tr.clientesColorSecundario.toLowerCase())));
      await tester.pump();
      await tester.tap(find.text(tr.comunGuardar));
      await _pasos(tester);

      final i = api.requested.indexOf('PATCH /clients/$_idAndino');
      expect(i, isNot(-1), reason: 'pidió: ${api.requested}');
      expect(api.cuerpos[i], {
        'name': 'Banco Andino',
        'primaryColor': '#1A73E8',
        'secondaryColor': null,
        'logoLightPlate': false,
      });
      // Sin logo nuevo ni quitado, el logo no viaja: no se toca.
      expect(api.cuerpos[i].containsKey('logoS3Key'), isFalse);
    });
  });

  group('el análisis del logo', () {
    testWidgets('un logo oscuro con transparencia pide la placa clara',
        (tester) async {
      final a = await tester.runAsync(
          () async => analizarLogo(await _png(600, 200, const Color(0xFF111111))));
      expect(a!.sirve, isTrue);
      expect([a.ancho, a.alto], [600, 200]);
      expect(a.tieneTransparencia, isTrue);
      expect(a.necesitaPlaca, isTrue);
    });

    testWidgets('uno blanco se ve solo sobre el gris', (tester) async {
      final a = await tester.runAsync(
          () async => analizarLogo(await _png(600, 200, const Color(0xFFFFFFFF))));
      expect(a!.necesitaPlaca, isFalse);
    });

    testWidgets('uno con fondo propio no necesita placa, pero se avisa',
        (tester) async {
      final a = await tester.runAsync(() async => analizarLogo(
          await _png(600, 200, const Color(0xFF111111), conFondo: true)));
      expect(a!.tieneTransparencia, isFalse);
      expect(a.necesitaPlaca, isFalse);
    });

    testWidgets('uno diminuto se rechaza antes de subirlo', (tester) async {
      final a = await tester.runAsync(
          () async => analizarLogo(await _png(120, 60, const Color(0xFF111111))));
      expect(a!.sirve, isFalse);
      expect(a.error, tr.clientesLogoChico(120, 60, minLadoMayorLogo));
    });

    test('lo que no es PNG se rechaza aunque se llame .png', () async {
      final jpg = Uint8List.fromList([0xFF, 0xD8, 0xFF, 0xE0, ...List.filled(60, 0)]);
      expect((await analizarLogo(jpg)).error, tr.clientesLogoNoPng);
    });

    test('más de 1 MB se rechaza sin decodificarlo', () async {
      final pesado = Uint8List(maxBytesLogo + 1);
      expect((await analizarLogo(pesado)).sirve, isFalse);
    });
  });

  test('el color guardado se lee y se escribe igual que en el servidor', () {
    expect(colorDesdeHex('#1a73e8'), const Color(0xFF1A73E8));
    expect(colorDesdeHex('1A73E8'), const Color(0xFF1A73E8));
    expect(colorDesdeHex('#12345'), isNull);
    expect(colorDesdeHex('azul'), isNull);
    expect(hexDe(const Color(0xFF0B5394)), '#0B5394');
    // Sin primario, la paleta es la de eduXaction aunque haya secundario.
    expect(paletaDeColores(null, '#0B5394'), PaletaMarca.eduXaction);
  });
}
