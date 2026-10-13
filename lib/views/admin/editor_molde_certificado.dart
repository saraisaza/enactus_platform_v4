import 'dart:ui' as ui;

import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:printing/printing.dart';
import 'package:provider/provider.dart';

import '../../l10n/textos.dart';
import '../../models/client.dart';
import '../../models/models.dart';
import '../../models/molde_certificado.dart';
import '../../providers/data_provider.dart';
import '../../services/api_errors.dart';
import '../../services/pdf_service.dart';
import '../../utils/app_theme.dart';
import '../../utils/formatos.dart';
import '../../widgets/app_header.dart';
import '../../widgets/async_states.dart';
import '../../widgets/common.dart';
import '../../widgets/selector_color.dart';
import '../../widgets/visor_pdf.dart';

/// El editor del molde de certificado de un cliente; sin cliente, el de
/// eduXaction (el de quien no tiene cliente y el de los clientes sin molde).
Future<void> mostrarEditorDeMolde(BuildContext context, Client? cliente) =>
    Navigator.of(context).push(MaterialPageRoute<void>(
        builder: (_) => EditorDeMolde(cliente: cliente)));

const _maxBytesFondo = 8 * 1024 * 1024;
const _maxBytesFirma = 1024 * 1024;

/// Cómo se llama cada dato en pantalla.
String _nombreDelCampo(String campo) => switch (campo) {
      'nombre' => tr.moldeCampoNombre,
      'curso' => tr.moldeCampoCurso,
      'fecha' => tr.moldeCampoFecha,
      'horas' => tr.moldeCampoHoras,
      'codigo' => tr.moldeCampoCodigo,
      'qr' => tr.moldeCampoQr,
      'firma' => tr.moldeCampoFirma,
      _ => campo,
    };

/// Los datos de ejemplo con que se ve el molde mientras se arma.
Certificate _certificadoDeEjemplo() => Certificate(
      id: '00000000-0000-4000-8000-000000000000',
      code: 'CUR-2026-1A2B3C4D',
      studentId: '',
      laboratoryId: '',
      studentName: tr.moldePersonaEjemplo,
      laboratoryName: '',
      courseId: 'ejemplo',
      courseName: tr.moldeCursoEjemplo,
      issuerName: '',
      hours: 20,
      issuedAt: DateTime.now(),
    );

class EditorDeMolde extends StatefulWidget {
  final Client? cliente;
  const EditorDeMolde({super.key, this.cliente});

  @override
  State<EditorDeMolde> createState() => _EditorDeMoldeState();
}

class _EditorDeMoldeState extends State<EditorDeMolde> {
  bool _cargando = true;
  ApiException? _errorCarga;
  ApiException? _error;

  /// El molde como está en el editor (guardado o no).
  MoldeDeCertificado? _molde;
  bool _existeGuardado = false;

  /// El fondo como imagen, para verlo: si era un PDF, ya convertido.
  Uint8List? _fondoVista;

  /// El archivo elegido y todavía no subido, con su tipo.
  Uint8List? _fondoNuevo;
  String? _tipoNuevo;

  Uint8List? _firmaVista;
  Uint8List? _firmaNueva;
  bool _firmaQuitada = false;

  String _seleccionado = 'nombre';
  bool _guardando = false;
  bool _cambios = false;

  String get _owner => widget.cliente?.id ?? 'eduxaction';
  String get _nombreDelDueno => widget.cliente?.name ?? 'eduXaction';

  @override
  void initState() {
    super.initState();
    _cargar();
  }

  Future<void> _cargar() async {
    setState(() {
      _cargando = true;
      _errorCarga = null;
    });
    final data = context.read<DataProvider>();
    try {
      final molde = await data.moldeDeCliente(_owner);
      Uint8List? fondo;
      Uint8List? firma;
      if (molde != null) {
        final impreso = await PdfService.imprimible(data, molde);
        fondo = impreso?.fondo;
        firma = impreso?.firma;
      }
      if (!mounted) return;
      setState(() {
        _molde = molde;
        _existeGuardado = molde != null;
        _fondoVista = fondo;
        _firmaVista = firma;
        _cargando = false;
      });
    } on ApiException catch (e) {
      if (mounted) {
        setState(() {
          _cargando = false;
          _errorCarga = e;
        });
      }
    }
  }

  void _marcar(VoidCallback cambio) => setState(() {
        cambio();
        _cambios = true;
      });

  Future<void> _elegirFondo() async {
    final resultado = await FilePicker.pickFiles(
      type: FileType.custom,
      allowedExtensions: const ['pdf', 'png', 'jpg', 'jpeg'],
      withData: kIsWeb,
    );
    final archivo = resultado?.files.singleOrNull;
    if (archivo == null || !mounted) return;
    if (archivo.size > _maxBytesFondo) {
      showAppSnack(context,
          tr.moldePesado(decimal(archivo.size / 1024 / 1024), 8),
          error: true);
      return;
    }
    final bytes = archivo.bytes ?? await archivo.xFile.readAsBytes();
    final extension = (archivo.extension ?? '').toLowerCase();
    try {
      final double ancho;
      final double alto;
      final Uint8List vista;
      final String tipo;
      if (extension == 'pdf') {
        final r = await PdfService.rasterizar(bytes);
        (vista, ancho, alto, tipo) = (r.imagen, r.ancho, r.alto, 'application/pdf');
      } else {
        final codec = await ui.instantiateImageCodec(bytes);
        final imagen = (await codec.getNextFrame()).image;
        // Una imagen no tiene tamaño de página: se le da el ancho de un A4
        // horizontal y la proporción de la imagen.
        (vista, ancho, alto) = (bytes, 842.0, 842.0 * imagen.height / imagen.width);
        tipo = extension == 'png' ? 'image/png' : 'image/jpeg';
      }
      if (!mounted) return;
      _marcar(() {
        _fondoNuevo = bytes;
        _tipoNuevo = tipo;
        _fondoVista = vista;
        _molde = (_molde ??
                MoldeDeCertificado(
                  clientId: widget.cliente?.id,
                  backgroundKind: 'png',
                  pageWidth: ancho,
                  pageHeight: alto,
                  campos: MoldeDeCertificado.camposPorOmision(),
                  backgroundS3Key: '',
                ))
            .copyWith(pageWidth: ancho, pageHeight: alto);
      });
    } catch (_) {
      if (mounted) showAppSnack(context, tr.moldeNoSeLee, error: true);
    }
  }

  Future<void> _elegirFirma() async {
    final resultado = await FilePicker.pickFiles(
      type: FileType.custom,
      allowedExtensions: const ['png'],
      withData: kIsWeb,
    );
    final archivo = resultado?.files.singleOrNull;
    if (archivo == null || !mounted) return;
    if (archivo.size > _maxBytesFirma) {
      showAppSnack(context,
          tr.moldePesado(decimal(archivo.size / 1024 / 1024), 1),
          error: true);
      return;
    }
    final bytes = archivo.bytes ?? await archivo.xFile.readAsBytes();
    if (!mounted) return;
    _marcar(() {
      _firmaNueva = bytes;
      _firmaVista = bytes;
      _firmaQuitada = false;
      // Si la firma no tenía lugar, se le da el de por omisión.
      final campos = Map.of(_molde!.campos);
      campos['firma'] ??= MoldeDeCertificado.camposPorOmision()['firma']!;
      _molde = _molde!.copyWith(campos: campos);
    });
  }

  void _quitarFirma() => _marcar(() {
        _firmaNueva = null;
        _firmaVista = null;
        _firmaQuitada = true;
      });

  void _cambiarCampo(String campo, CampoDelMolde valor) => _marcar(() {
        _molde = _molde!.copyWith(campos: {..._molde!.campos, campo: valor});
      });

  /// Mueve un dato [delta] píxeles sobre un lienzo de tamaño [lienzo].
  void _moverCampo(String campo, Offset delta, Size lienzo) {
    final v = _molde!.campos[campo];
    if (v == null) return;
    _cambiarCampo(
        campo,
        v.copyWith(
          x: (v.x + delta.dx / lienzo.width).clamp(0.0, 1 - v.w),
          y: (v.y + delta.dy / lienzo.height).clamp(0.0, 0.98),
        ));
  }

  /// Ensancha (o angosta) un dato [dx] píxeles.
  void _ensancharCampo(String campo, double dx, Size lienzo) {
    final v = _molde!.campos[campo];
    if (v == null) return;
    _cambiarCampo(
        campo, v.copyWith(w: (v.w + dx / lienzo.width).clamp(0.04, 1 - v.x)));
  }

  void _alternarCampo(String campo, bool visible) => _marcar(() {
        final campos = Map.of(_molde!.campos);
        if (visible) {
          campos[campo] = MoldeDeCertificado.camposPorOmision()[campo]!;
          _seleccionado = campo;
        } else {
          campos.remove(campo);
          if (_seleccionado == campo) _seleccionado = 'nombre';
        }
        _molde = _molde!.copyWith(campos: campos);
      });

  MoldeImpreso? get _impreso => _molde == null || _fondoVista == null
      ? null
      : MoldeImpreso(
          molde: _molde!,
          fondo: _fondoVista!,
          firma: _firmaQuitada ? null : _firmaVista,
        );

  Future<void> _vistaPrevia() async {
    final impreso = _impreso;
    if (impreso == null) return;
    Future<Uint8List> cargar() async =>
        (await PdfService.buildCertificate(_certificadoDeEjemplo(),
                molde: impreso))
            .save();
    if (kIsWeb) {
      await Printing.layoutPdf(
          name: tr.moldeArchivoDePrueba, onLayout: (_) => cargar());
      return;
    }
    await Navigator.of(context).push(MaterialPageRoute<void>(
      builder: (_) => VisorPdf(
        titulo: tr.moldeVistaPrevia,
        nombreArchivo: tr.moldeArchivoDePrueba,
        cargar: cargar,
      ),
    ));
  }

  Future<void> _guardar() async {
    final molde = _molde;
    if (molde == null) return;
    setState(() {
      _guardando = true;
      _error = null;
    });
    final data = context.read<DataProvider>();
    try {
      var fondo = molde.backgroundS3Key;
      if (_fondoNuevo != null) {
        fondo = await data.subirArchivoDeMolde(_fondoNuevo!,
            uso: 'background', contentType: _tipoNuevo!);
      }
      String? firma = _firmaQuitada ? null : molde.signatureS3Key;
      if (_firmaNueva != null) {
        firma = await data.subirArchivoDeMolde(_firmaNueva!,
            uso: 'signature', contentType: 'image/png');
      }
      final guardado = await data.guardarMolde(
        _owner,
        molde.copyWith(backgroundS3Key: fondo, signatureS3Key: () => firma),
      );
      if (!mounted) return;
      setState(() {
        _molde = guardado;
        _existeGuardado = true;
        _fondoNuevo = null;
        _firmaNueva = null;
        _firmaQuitada = false;
        _guardando = false;
        _cambios = false;
      });
      showSuccessCheck(context, tr.comunGuardado);
    } on ApiException catch (e) {
      if (mounted) {
        setState(() {
          _guardando = false;
          _error = e;
        });
      }
    }
  }

  Future<void> _quitarMolde() async {
    final ok = await confirmDialog(context, tr.moldeQuitarTitulo,
        tr.moldeQuitarTexto(_nombreDelDueno));
    if (!ok || !mounted) return;
    try {
      await context.read<DataProvider>().quitarMolde(_owner);
      if (mounted) Navigator.of(context).pop();
    } on ApiException catch (e) {
      if (mounted) setState(() => _error = e);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Column(
        children: [
          AppHeader(portalTitle: tr.moldeTitulo(_nombreDelDueno)),
          Expanded(
            child: _cargando
                ? const Center(child: BrandLoader())
                : _errorCarga != null
                    ? ErrorState(_errorCarga!, onRetry: _cargar)
                    : _cuerpo(context),
          ),
        ],
      ),
    );
  }

  Widget _cuerpo(BuildContext context) {
    final ancho = MediaQuery.sizeOf(context).width;
    final ladoALado = ancho >= 1000;
    final molde = _molde;

    final lienzo = molde == null || _fondoVista == null
        ? _SinMolde(alSubir: _guardando ? null : _elegirFondo)
        : _Lienzo(
            molde: molde,
            fondo: _fondoVista!,
            firma: _firmaQuitada ? null : _firmaVista,
            seleccionado: _seleccionado,
            alSeleccionar: (c) => setState(() => _seleccionado = c),
            alMover: _moverCampo,
            alEnsanchar: _ensancharCampo,
          );

    final panel = molde == null
        ? const SizedBox.shrink()
        : _Panel(
            molde: molde,
            seleccionado: _seleccionado,
            tieneFirma: !_firmaQuitada && _firmaVista != null,
            habilitado: !_guardando,
            alSeleccionar: (c) => setState(() => _seleccionado = c),
            alCambiar: _cambiarCampo,
            alAlternar: _alternarCampo,
            alCambiarFondo: _elegirFondo,
            alElegirFirma: _elegirFirma,
            alQuitarFirma: _quitarFirma,
          );

    final acciones = Wrap(
      spacing: 10,
      runSpacing: 10,
      alignment: WrapAlignment.end,
      children: [
        if (_existeGuardado)
          TextButton.icon(
            icon: const Icon(Icons.delete_outline, size: 18),
            label: Text(tr.moldeQuitar),
            onPressed: _guardando ? null : _quitarMolde,
          ),
        OutlinedButton.icon(
          icon: const Icon(Icons.picture_as_pdf_outlined, size: 18),
          label: Text(tr.moldeVistaPrevia),
          onPressed: _impreso == null || _guardando ? null : _vistaPrevia,
        ),
        ElevatedButton.icon(
          icon: const Icon(Icons.save_outlined, size: 18),
          label: Text(_guardando ? tr.comunGuardando : tr.comunGuardar),
          onPressed: molde == null || _guardando || !_cambios ? null : _guardar,
        ),
      ],
    );

    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 1400),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(tr.moldeExplicacion(_nombreDelDueno),
                  style: const TextStyle(
                      fontSize: 13.5, color: AppColors.textSecondary)),
              const SizedBox(height: 14),
              if (_error != null) ...[
                ErrorBanner(_error!),
                const SizedBox(height: 12),
              ],
              if (ladoALado)
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(child: lienzo),
                    const SizedBox(width: 20),
                    SizedBox(width: 340, child: panel),
                  ],
                )
              else ...[
                lienzo,
                const SizedBox(height: 16),
                panel,
              ],
              const SizedBox(height: 18),
              acciones,
            ],
          ),
        ),
      ),
    );
  }
}

/// Antes de subir un molde: qué se pide y el botón para elegirlo.
class _SinMolde extends StatelessWidget {
  final VoidCallback? alSubir;
  const _SinMolde({required this.alSubir});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(32),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        children: [
          Icon(Icons.workspace_premium_outlined,
              size: 42, color: AppColors.gold),
          const SizedBox(height: 12),
          Text(tr.moldeSinMolde,
              textAlign: TextAlign.center,
              style: const TextStyle(
                  fontSize: 16,
                  fontWeight: AppWeights.uiSemibold,
                  color: AppColors.textPrimary)),
          const SizedBox(height: 6),
          Text(tr.moldeSinMoldeTexto,
              textAlign: TextAlign.center,
              style: const TextStyle(
                  fontSize: 13, color: AppColors.textSecondary)),
          const SizedBox(height: 16),
          ElevatedButton.icon(
            icon: const Icon(Icons.upload_file, size: 18),
            label: Text(tr.moldeSubir),
            onPressed: alSubir,
          ),
        ],
      ),
    );
  }
}

/// El molde con sus datos encima: cada caja se arrastra a su lugar y se
/// ensancha desde su borde derecho.
class _Lienzo extends StatelessWidget {
  final MoldeDeCertificado molde;
  final Uint8List fondo;
  final Uint8List? firma;
  final String seleccionado;
  final ValueChanged<String> alSeleccionar;
  final void Function(String campo, Offset delta, Size lienzo) alMover;
  final void Function(String campo, double dx, Size lienzo) alEnsanchar;

  const _Lienzo({
    required this.molde,
    required this.fondo,
    required this.firma,
    required this.seleccionado,
    required this.alSeleccionar,
    required this.alMover,
    required this.alEnsanchar,
  });

  @override
  Widget build(BuildContext context) {
    final textos = PdfService.textosDe(_certificadoDeEjemplo());
    return LayoutBuilder(builder: (context, limites) {
      final ancho = limites.maxWidth;
      final alto = ancho * molde.pageHeight / molde.pageWidth;
      return Semantics(
        label: tr.moldeLienzo,
        container: true,
        explicitChildNodes: true,
        child: SizedBox(
          width: ancho,
          height: alto,
          child: Stack(
            children: [
              Positioned.fill(child: Image.memory(fondo, fit: BoxFit.fill)),
              for (final e in molde.campos.entries)
                _Caja(
                  key: ValueKey('caja-${e.key}'),
                  campo: e.key,
                  valor: e.value,
                  texto: textos[e.key],
                  firma: firma,
                  anchoLienzo: ancho,
                  altoLienzo: alto,
                  seleccionada: e.key == seleccionado,
                  alSeleccionar: () => alSeleccionar(e.key),
                  alMover: (d) => alMover(e.key, d, Size(ancho, alto)),
                  alEnsanchar: (dx) => alEnsanchar(e.key, dx, Size(ancho, alto)),
                ),
            ],
          ),
        ),
      );
    });
  }
}

class _Caja extends StatelessWidget {
  final String campo;
  final CampoDelMolde valor;
  final String? texto;
  final Uint8List? firma;
  final double anchoLienzo;
  final double altoLienzo;
  final bool seleccionada;
  final VoidCallback alSeleccionar;
  final ValueChanged<Offset> alMover;
  final ValueChanged<double> alEnsanchar;

  const _Caja({
    super.key,
    required this.campo,
    required this.valor,
    required this.texto,
    required this.firma,
    required this.anchoLienzo,
    required this.altoLienzo,
    required this.seleccionada,
    required this.alSeleccionar,
    required this.alMover,
    required this.alEnsanchar,
  });

  /// Tocar una caja es agarrarla: el gesto es suyo desde el primer contacto.
  /// Con un reconocedor de arrastre común, en una pantalla táctil la página
  /// (que se desplaza) se quedaba con todo movimiento vertical y la caja solo
  /// se movía de lado.
  Widget _agarrable({required Widget child, required ValueChanged<Offset> alArrastrar}) =>
      RawGestureDetector(
        gestures: {
          ImmediateMultiDragGestureRecognizer:
              GestureRecognizerFactoryWithHandlers<
                  ImmediateMultiDragGestureRecognizer>(
            ImmediateMultiDragGestureRecognizer.new,
            (r) => r.onStart = (_) {
              alSeleccionar();
              return _Arrastre(alArrastrar);
            },
          ),
        },
        child: child,
      );

  @override
  Widget build(BuildContext context) {
    final ancho = valor.w * anchoLienzo;
    final Widget contenido;
    if (campo == 'qr') {
      contenido = Container(
        width: ancho,
        height: ancho,
        color: Colors.white,
        child: Icon(Icons.qr_code_2, size: ancho * 0.9, color: Colors.black),
      );
    } else if (campo == 'firma') {
      contenido = firma == null
          ? Container(
              height: ancho * 0.35,
              alignment: Alignment.center,
              color: Colors.white.withValues(alpha: 0.6),
              child: Text(_nombreDelCampo('firma'),
                  style: const TextStyle(fontSize: 11, color: Colors.black)),
            )
          : Image.memory(firma!, width: ancho, fit: BoxFit.contain);
    } else {
      contenido = Text(
        texto ?? '',
        textAlign: switch (valor.align) {
          'left' => TextAlign.left,
          'right' => TextAlign.right,
          _ => TextAlign.center,
        },
        style: TextStyle(
          fontFamily: valor.font == 'display' ? AppFonts.display : AppFonts.ui,
          fontWeight: valor.bold ? FontWeight.w700 : FontWeight.w400,
          fontSize: valor.size * altoLienzo,
          height: 1.15,
          color: colorDesdeHex(valor.color) ?? Colors.black,
        ),
      );
    }

    return Positioned(
      left: valor.x * anchoLienzo,
      top: valor.y * altoLienzo,
      width: ancho,
      child: _agarrable(
        alArrastrar: alMover,
        child: Semantics(
          label: _nombreDelCampo(campo),
          container: true,
          child: Stack(
            clipBehavior: Clip.none,
            // El marco ocupa todo el ancho de la caja: así se ve dónde cae el
            // texto centrado o alineado a un lado, igual que en el PDF.
            fit: StackFit.passthrough,
            children: [
              Container(
                decoration: BoxDecoration(
                  border: Border.all(
                    color: seleccionada
                        ? AppColors.relleno
                        : Colors.black.withValues(alpha: 0.35),
                    width: seleccionada ? 2 : 1,
                  ),
                ),
                child: contenido,
              ),
              // El tirador para ensancharla.
              Positioned(
                right: -7,
                top: 0,
                bottom: 0,
                child: _agarrable(
                  alArrastrar: (d) => alEnsanchar(d.dx),
                  child: MouseRegion(
                    cursor: SystemMouseCursors.resizeLeftRight,
                    child: Center(
                      child: Container(
                        width: 12,
                        height: 22,
                        decoration: BoxDecoration(
                          color: seleccionada
                              ? AppColors.relleno
                              : Colors.black.withValues(alpha: 0.35),
                          borderRadius: BorderRadius.circular(3),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Un arrastre en curso: le pasa cada desplazamiento a quien mueve la caja.
class _Arrastre extends Drag {
  final ValueChanged<Offset> alArrastrar;
  _Arrastre(this.alArrastrar);

  @override
  void update(DragUpdateDetails details) => alArrastrar(details.delta);
}

/// Los archivos, qué datos lleva el certificado y cómo se ve el elegido.
class _Panel extends StatelessWidget {
  final MoldeDeCertificado molde;
  final String seleccionado;
  final bool tieneFirma;
  final bool habilitado;
  final ValueChanged<String> alSeleccionar;
  final void Function(String campo, CampoDelMolde valor) alCambiar;
  final void Function(String campo, bool visible) alAlternar;
  final VoidCallback alCambiarFondo;
  final VoidCallback alElegirFirma;
  final VoidCallback alQuitarFirma;

  const _Panel({
    required this.molde,
    required this.seleccionado,
    required this.tieneFirma,
    required this.habilitado,
    required this.alSeleccionar,
    required this.alCambiar,
    required this.alAlternar,
    required this.alCambiarFondo,
    required this.alElegirFirma,
    required this.alQuitarFirma,
  });

  @override
  Widget build(BuildContext context) {
    final valor = molde.campos[seleccionado];
    final esImagen = MoldeDeCertificado.camposDeImagen.contains(seleccionado);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            OutlinedButton.icon(
              icon: const Icon(Icons.upload_file, size: 16),
              label: Text(tr.moldeCambiar),
              onPressed: habilitado ? alCambiarFondo : null,
            ),
            OutlinedButton.icon(
              icon: const Icon(Icons.draw_outlined, size: 16),
              label: Text(tieneFirma ? tr.moldeCambiarFirma : tr.moldeSubirFirma),
              onPressed: habilitado ? alElegirFirma : null,
            ),
            if (tieneFirma)
              TextButton(
                onPressed: habilitado ? alQuitarFirma : null,
                child: Text(tr.moldeQuitarFirma),
              ),
          ],
        ),
        const SizedBox(height: 16),
        Text(tr.moldeDatos,
            style: const TextStyle(
                fontWeight: AppWeights.uiSemibold,
                color: AppColors.textPrimary)),
        const SizedBox(height: 4),
        Text(tr.moldeDatosAyuda,
            style: const TextStyle(fontSize: 12, color: AppColors.textMuted)),
        const SizedBox(height: 6),
        for (final campo in [
          ...MoldeDeCertificado.camposDeTexto,
          ...MoldeDeCertificado.camposDeImagen,
        ])
          _FilaDeCampo(
            campo: campo,
            visible: molde.campos.containsKey(campo),
            obligatorio: MoldeDeCertificado.obligatorios.contains(campo),
            seleccionado: campo == seleccionado,
            habilitado: habilitado,
            alSeleccionar: () => alSeleccionar(campo),
            alAlternar: (v) => alAlternar(campo, v),
          ),
        if (valor != null) ...[
          const Divider(height: 28),
          Text(_nombreDelCampo(seleccionado),
              style: const TextStyle(
                  fontWeight: AppWeights.uiSemibold,
                  color: AppColors.textPrimary)),
          const SizedBox(height: 8),
          _Deslizador(
            etiqueta: tr.moldeAncho,
            valor: valor.w,
            min: 0.04,
            max: 1,
            alCambiar: habilitado
                ? (v) => alCambiar(seleccionado,
                    valor.copyWith(w: v.clamp(0.04, 1 - valor.x)))
                : null,
          ),
          if (!esImagen) ...[
            _Deslizador(
              etiqueta: tr.moldeTamano,
              valor: valor.size,
              min: 0.01,
              max: 0.12,
              alCambiar: habilitado
                  ? (v) => alCambiar(seleccionado, valor.copyWith(size: v))
                  : null,
            ),
            const SizedBox(height: 6),
            SegmentedButton<String>(
              segments: [
                ButtonSegment(
                    value: 'left',
                    icon: const Icon(Icons.format_align_left, size: 18),
                    tooltip: tr.moldeAlinearIzquierda),
                ButtonSegment(
                    value: 'center',
                    icon: const Icon(Icons.format_align_center, size: 18),
                    tooltip: tr.moldeAlinearCentro),
                ButtonSegment(
                    value: 'right',
                    icon: const Icon(Icons.format_align_right, size: 18),
                    tooltip: tr.moldeAlinearDerecha),
              ],
              selected: {valor.align},
              onSelectionChanged: habilitado
                  ? (s) => alCambiar(seleccionado, valor.copyWith(align: s.first))
                  : null,
            ),
            const SizedBox(height: 10),
            SegmentedButton<String>(
              segments: [
                ButtonSegment(value: 'display', label: Text(tr.moldeLetraTitulo)),
                ButtonSegment(value: 'sans', label: Text(tr.moldeLetraTexto)),
              ],
              selected: {valor.font},
              onSelectionChanged: habilitado
                  ? (s) => alCambiar(seleccionado, valor.copyWith(font: s.first))
                  : null,
            ),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: Text(tr.moldeNegrita, style: const TextStyle(fontSize: 14)),
              value: valor.bold,
              activeThumbColor: AppColors.gold,
              onChanged: habilitado
                  ? (v) => alCambiar(seleccionado, valor.copyWith(bold: v))
                  : null,
            ),
            CampoDeColor(
              key: ValueKey('color-$seleccionado'),
              etiqueta: tr.moldeColor,
              valor: colorDesdeHex(valor.color),
              habilitado: habilitado,
              alCambiar: (c) {
                if (c != null) {
                  alCambiar(seleccionado, valor.copyWith(color: hexDe(c)));
                }
              },
            ),
          ],
        ],
      ],
    );
  }
}

class _FilaDeCampo extends StatelessWidget {
  final String campo;
  final bool visible;
  final bool obligatorio;
  final bool seleccionado;
  final bool habilitado;
  final VoidCallback alSeleccionar;
  final ValueChanged<bool> alAlternar;

  const _FilaDeCampo({
    required this.campo,
    required this.visible,
    required this.obligatorio,
    required this.seleccionado,
    required this.habilitado,
    required this.alSeleccionar,
    required this.alAlternar,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: seleccionado ? AppColors.surfaceAlt : Colors.transparent,
      borderRadius: BorderRadius.circular(8),
      child: InkWell(
        borderRadius: BorderRadius.circular(8),
        onTap: visible ? alSeleccionar : null,
        child: Row(
          children: [
            Checkbox(
              value: visible,
              activeColor: AppColors.relleno,
              onChanged: obligatorio || !habilitado
                  ? null
                  : (v) => alAlternar(v ?? false),
            ),
            Expanded(
              child: Text(
                obligatorio
                    ? '${_nombreDelCampo(campo)} · ${tr.moldeObligatorio}'
                    : _nombreDelCampo(campo),
                style: TextStyle(
                    fontSize: 13.5,
                    color: visible
                        ? AppColors.textPrimary
                        : AppColors.textMuted),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Deslizador extends StatelessWidget {
  final String etiqueta;
  final double valor;
  final double min;
  final double max;
  final ValueChanged<double>? alCambiar;

  const _Deslizador({
    required this.etiqueta,
    required this.valor,
    required this.min,
    required this.max,
    required this.alCambiar,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        SizedBox(
          width: 80,
          child: Text(etiqueta,
              style: const TextStyle(fontSize: 13, color: AppColors.textSecondary)),
        ),
        Expanded(
          child: Slider(
            value: valor.clamp(min, max),
            min: min,
            max: max,
            label: etiqueta,
            onChanged: alCambiar,
          ),
        ),
      ],
    );
  }
}
