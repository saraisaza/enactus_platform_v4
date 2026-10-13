// Moldes de certificado, del lado de la app (etapa 6, parte 2).
//
// - El molde viaja en fracciones de página, y el QR y la firma sin letra.
// - El PDF se arma sobre el fondo del molde, con las letras de la plataforma.
// - En el editor, arrastrar un dato lo mueve, desmarcarlo lo quita, y lo que
//   se guarda es lo que se ve.

import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:provider/provider.dart';

import 'package:enactus_platform/l10n/textos.dart';
import 'package:enactus_platform/models/client.dart';
import 'package:enactus_platform/models/models.dart';
import 'package:enactus_platform/models/molde_certificado.dart';
import 'package:enactus_platform/providers/auth_provider.dart';
import 'package:enactus_platform/providers/data_provider.dart';
import 'package:enactus_platform/services/pdf_service.dart';
import 'package:enactus_platform/utils/app_theme.dart';
import 'package:enactus_platform/views/admin/editor_molde_certificado.dart';

import 'helpers/fake_api.dart';

const _idAndino = '2f8d4b61-9c0a-4e7b-8d12-5a6b7c8d9e02';

/// Un PNG de 1×1: el fondo más chico que se puede dibujar.
final _png = base64Decode(
    'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVR42mNkYPhfDwAChwGA60e6kgAAAABJRU5ErkJggg==');

Map<String, Object?> _moldeJson() => {
      'clientId': _idAndino,
      'backgroundKind': 'png',
      'pageWidth': 842,
      'pageHeight': 595,
      'backgroundS3Key': 'certificate-templates/fondo.png',
      'signatureS3Key': null,
      'backgroundUrl': 'https://s3.prueba/certificate-templates/fondo.png?firma=1',
      'signatureUrl': null,
      'fields': {
        'nombre': {
          'x': 0.1, 'y': 0.4, 'w': 0.8, 'size': 0.06,
          'align': 'center', 'color': '#1F1F1F', 'font': 'display', 'bold': true,
        },
        'curso': {
          'x': 0.1, 'y': 0.55, 'w': 0.8, 'size': 0.035,
          'align': 'center', 'color': '#1F1F1F', 'font': 'sans', 'bold': false,
        },
        'fecha': {
          'x': 0.08, 'y': 0.84, 'w': 0.3, 'size': 0.025,
          'align': 'left', 'color': '#1F1F1F', 'font': 'sans', 'bold': false,
        },
        'qr': {'x': 0.84, 'y': 0.74, 'w': 0.1},
      },
    };

void main() {
  setUpAll(() async {
    await initializeDateFormatting('es');
  });

  group('el molde', () {
    test('ida y vuelta: el QR y la firma viajan sin letra', () {
      final molde = MoldeDeCertificado.fromJson(_moldeJson());
      expect(molde.campos.keys, containsAll(['nombre', 'curso', 'fecha', 'qr']));
      final json = molde.toJson();
      final campos = json['fields'] as Map<String, dynamic>;
      expect(campos['qr'], {'x': 0.84, 'y': 0.74, 'w': 0.1});
      expect((campos['nombre'] as Map)['font'], 'display');
      expect(json.containsKey('backgroundUrl'), isFalse,
          reason: 'los enlaces firmados no se mandan de vuelta');
    });

    test('las posiciones se redondean a una diezmilésima de página', () {
      const c = CampoDelMolde(x: 0.123456789, y: 0.5, w: 0.3);
      expect(c.toJson()['x'], 0.1235);
    });
  });

  testWidgets('el PDF se arma sobre el fondo del molde', (tester) async {
    final molde = MoldeDeCertificado.fromJson(_moldeJson());
    final cert = Certificate(
      id: 'cccccccc-0000-4000-8000-0000000000c1',
      code: 'CUR-2026-1A2B3C4D',
      studentId: 'a',
      laboratoryId: '',
      studentName: 'Ana María Torres',
      laboratoryName: '',
      courseId: 'b',
      courseName: 'Seguridad eléctrica',
      hours: 12,
      issuedAt: DateTime(2026, 10, 12),
    );
    final bytes = await tester.runAsync(() async =>
        (await PdfService.buildCertificate(cert,
                molde: MoldeImpreso(molde: molde, fondo: _png)))
            .save());
    expect(bytes, isNotNull);
    // Una sola página, del tamaño del molde (842×595 pt).
    final texto = latin1.decode(bytes!, allowInvalid: true);
    expect(RegExp(r'/Type\s*/Page[^s]').allMatches(texto).length, 1);
    expect(texto, contains('842'));
  });

  group('el editor', () {
    Future<FakeApi> abrir(WidgetTester tester) async {
      useFakeTokenStorage();
      tester.view.devicePixelRatio = 1.0;
      tester.view.physicalSize = const Size(1440, 1100);
      addTearDown(tester.view.reset);
      final api = FakeApi(routes: {
        '/clients/$_idAndino/certificate-template': {'template': _moldeJson()},
        '/certificate-templates/fondo.png': _png,
        'PUT /clients/$_idAndino/certificate-template': {'template': _moldeJson()},
      });
      final servicio = api.build();
      final data = DataProvider(servicio);
      await tester.pumpWidget(MultiProvider(
        providers: [
          ChangeNotifierProvider<DataProvider>.value(value: data),
          ChangeNotifierProvider<AuthProvider>.value(
              value: AuthProvider(servicio, data)),
        ],
        child: MaterialApp(
          theme: buildAppTheme(),
          home: const EditorDeMolde(
            cliente: Client(id: _idAndino, name: 'Banco Andino'),
          ),
        ),
      ));
      for (var i = 0; i < 6; i++) {
        await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 20)));
        await tester.pump(const Duration(milliseconds: 60));
      }
      return api;
    }

    Future<Map<String, dynamic>> guardar(WidgetTester tester, FakeApi api) async {
      await tester.ensureVisible(find.text(tr.comunGuardar));
      await tester.pump();
      await tester.tap(find.text(tr.comunGuardar));
      for (var i = 0; i < 6; i++) {
        await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 20)));
        await tester.pump(const Duration(milliseconds: 60));
      }
      // El aviso de «guardado» se va solo.
      await tester.pump(const Duration(seconds: 2));
      final i = api.requested.indexOf('PUT /clients/$_idAndino/certificate-template');
      expect(i, isNot(-1), reason: 'pidió: ${api.requested}');
      return api.cuerpos[i]['fields'] as Map<String, dynamic>;
    }

    testWidgets('arrastrar el nombre lo mueve, y se guarda donde quedó',
        (tester) async {
      final api = await abrir(tester);
      expect(find.bySemanticsLabel(tr.moldeLienzo), findsOneWidget);
      // Sin cambios, no hay nada que guardar.
      expect(
          tester.widget<ElevatedButton>(find.ancestor(
              of: find.text(tr.comunGuardar),
              matching: find.byWidgetPredicate((w) => w is ElevatedButton))).onPressed,
          isNull);

      // La caja del nombre sobre el lienzo (el panel también dice «Nombre»).
      final nombre = find.byKey(const ValueKey('caja-nombre'));
      final antes = tester.getTopLeft(nombre);
      await tester.drag(nombre, const Offset(40, -60));
      await tester.pump();
      final despues = tester.getTopLeft(nombre);
      expect(despues.dx, closeTo(antes.dx + 40, 0.5));
      expect(despues.dy, closeTo(antes.dy - 60, 0.5));

      final campos = await guardar(tester, api);
      final x = (campos['nombre'] as Map)['x'] as double;
      final y = (campos['nombre'] as Map)['y'] as double;
      expect(x, greaterThan(0.1));
      expect(y, lessThan(0.4));
      // El resto, como estaba.
      expect(campos['qr'], {'x': 0.84, 'y': 0.74, 'w': 0.1});
    });

    testWidgets('desmarcar la fecha la quita; el nombre no se puede quitar',
        (tester) async {
      final api = await abrir(tester);
      final filaFecha = find.ancestor(
          of: find.text(tr.moldeCampoFecha),
          matching: find.byType(InkWell));
      await tester.tap(find.descendant(of: filaFecha, matching: find.byType(Checkbox)));
      await tester.pump();

      final filaNombre = find.ancestor(
          of: find.text('${tr.moldeCampoNombre} · ${tr.moldeObligatorio}'),
          matching: find.byType(InkWell));
      expect(
          tester.widget<Checkbox>(find.descendant(
              of: filaNombre, matching: find.byType(Checkbox))).onChanged,
          isNull);

      final campos = await guardar(tester, api);
      expect(campos.containsKey('fecha'), isFalse);
      expect(campos.containsKey('nombre'), isTrue);
    });
  });
}
