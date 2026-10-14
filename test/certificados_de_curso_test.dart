// Certificados de curso, del lado de la app (etapa 6, parte 1).
//
// - El certificado de un curso se describe como de curso, no como de la Ruta.
// - Su PDF dice «completó el curso» y lleva el QR de la verificación.
// - La página pública de verificación, sin sesión: válido, o no encontrado.
// - El aviso de un certificado de curso se lee en el idioma de quien lo recibe.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';

import 'package:enactus_platform/l10n/textos.dart';
import 'package:enactus_platform/models/models.dart';
import 'package:enactus_platform/services/pdf_service.dart';
import 'package:enactus_platform/utils/constants.dart';

import 'helpers/portal_harness.dart';

const _id = 'cccccccc-0000-4000-8000-0000000000c1';

Certificate _deCurso() => Certificate.fromJson({
      'id': _id,
      'code': 'CUR-2026-1A2B3C4D',
      'studentId': 'aaaaaaaa-0000-4000-8000-000000000001',
      'laboratoryId': null,
      'courseId': 'bbbbbbbb-0000-4000-8000-000000000001',
      'studentNameSnapshot': 'Ana Torres',
      'laboratoryNameSnapshot': null,
      'courseNameSnapshot': 'Seguridad eléctrica',
      'issuerNameSnapshot': 'Nelson Electric',
      'hours': 12,
      'issuedAt': '2026-10-12T15:00:00.000Z',
    });

void main() {
  setUpAll(() async {
    await initializeDateFormatting('es');
    await initializeDateFormatting('en');
    cargarFixtures();
  });
  tearDown(() => Idioma.instancia.cambiar('es'));

  group('el certificado de un curso', () {
    test('se describe como de curso', () {
      final c = _deCurso();
      expect(c.esDeCurso, isTrue);
      expect(c.titulo, 'Seguridad eléctrica');
      expect(c.descripcion, tr.certificadoCursoDe('Seguridad eléctrica'));
    });

    test('el QR lleva a la verificación pública de ESE certificado', () {
      // Sin `#`: la web usa rutas de verdad. Con `#`, la app abría la portada.
      expect(EnlacesWeb.verificarCertificado(_id),
          'https://eduxaction.com/verificar/$_id');
    });

    test('un QR viejo, con #, todavía lleva a su verificación', () {
      expect(
          EnlacesWeb.rutaDeQrViejo(
              Uri.parse('https://eduxaction.com/#/verificar/$_id')),
          '/verificar/$_id');
      expect(EnlacesWeb.rutaDeQrViejo(Uri.parse('https://eduxaction.com/login')),
          isNull);
      expect(
          EnlacesWeb.rutaDeQrViejo(Uri.parse('https://eduxaction.com/#/admin')),
          isNull);
    });

    test('su PDF se arma', () async {
      final doc = await PdfService.buildCertificate(_deCurso());
      final bytes = await doc.save();
      expect(bytes.length, greaterThan(1000));
    });
  });

  group('la página de verificación', () {
    testWidgets('un certificado que existe: válido, con lo que dice',
        (tester) async {
      fijarTamano(tester, const Size(1280, 900));
      await montar(
        tester,
        appPublica('${AppRoutes.verificar}/$_id', conApi: (api) {
          api.routes['/certificate-verification/$_id'] = {
            'code': 'CUR-2026-1A2B3C4D',
            'studentName': 'Ana Torres',
            'kind': 'course',
            'title': 'Seguridad eléctrica',
            'hours': 12,
            'issuer': 'Nelson Electric',
            'issuedAt': '2026-10-12T15:00:00.000Z',
          };
        }),
      );
      expect(find.text(tr.verificarValido), findsOneWidget);
      expect(find.text('Ana Torres'), findsOneWidget);
      expect(find.text(tr.verificarCompletoCurso('Seguridad eléctrica')),
          findsOneWidget);
      expect(find.text('Nelson Electric'), findsOneWidget);
      expect(find.text('CUR-2026-1A2B3C4D'), findsOneWidget);
    });

    testWidgets('uno que no existe: lo dice, sin culpar a nadie',
        (tester) async {
      fijarTamano(tester, const Size(1280, 900));
      await montar(
        tester,
        appPublica('${AppRoutes.verificar}/$_id',
            conApi: (api) => api.notFound.add('/certificate-verification/$_id')),
      );
      expect(find.text(tr.verificarNoEncontrado), findsOneWidget);
      expect(find.text(tr.verificarValido), findsNothing);
    });
  });

  test('el aviso de un certificado de curso, en inglés', () async {
    await Idioma.instancia.cambiar('en');
    final aviso = AppNotification.fromJson({
      'id': 'dddddddd-0000-4000-8000-0000000000d1',
      'userId': 'aaaaaaaa-0000-4000-8000-000000000001',
      'title': 'Nuevo certificado',
      'body': 'Recibió el certificado del curso Seguridad eléctrica.',
      'kind': 'certificado_curso',
      'params': {'curso': 'Seguridad eléctrica'},
      'read': false,
      'createdAt': '2026-10-12T15:00:00.000Z',
    });
    expect(aviso.tituloVisible, 'New certificate');
    expect(aviso.cuerpoVisible,
        'You received the certificate for completing the course Seguridad eléctrica.');
  });
}
