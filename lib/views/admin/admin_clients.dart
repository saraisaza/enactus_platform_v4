import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../l10n/textos.dart';
import '../../models/client.dart';
import '../../providers/data_provider.dart';
import '../../services/api_errors.dart';
import '../../utils/analisis_logo.dart';
import '../../utils/app_theme.dart';
import '../../utils/formatos.dart';
import '../../widgets/async_states.dart';
import '../../widgets/common.dart';
import '../../widgets/logo_de_cliente.dart';
import '../../widgets/portal_shell.dart';
import '../../widgets/selector_color.dart';
import '../../widgets/vista_previa_marca.dart';

/// Los clientes de la plataforma —Enactus y las empresas— y su marca.
///
/// Acá se crean, se les pone logo y colores con vista previa, se editan y se
/// desactivan. Asignarles cuentas llega en la etapa siguiente; por ahora nada
/// de lo que se haga acá cambia lo que ve nadie más que quien administra.
class AdminClients extends StatelessWidget {
  const AdminClients({super.key});

  @override
  Widget build(BuildContext context) {
    final data = context.watch<DataProvider>();
    return TabBody(
      title: tr.clientesTitulo,
      subtitle: tr.clientesSubtitulo,
      actions: [
        ElevatedButton.icon(
          icon: const Icon(Icons.add, size: 18),
          label: Text(tr.clientesNuevo),
          onPressed: () => mostrarEditorDeCliente(context, null),
        ),
      ],
      children: [
        data.clients.when(
          loading: () => const CardListSkeleton(count: 3, height: 96),
          error: (e) => ErrorState(e, onRetry: data.reloadClients),
          data: (clientes) => clientes.isEmpty
              ? EmptyState(
                  icon: Icons.storefront_outlined,
                  message: tr.clientesVacio)
              : Column(
                  children: [
                    for (final cliente in clientes)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 10),
                        child: _TarjetaDeCliente(cliente: cliente),
                      ),
                  ],
                ),
        ),
      ],
    );
  }
}

class _TarjetaDeCliente extends StatelessWidget {
  final Client cliente;
  const _TarjetaDeCliente({required this.cliente});

  Future<void> _cambiarEstado(BuildContext context) async {
    final desactivar = cliente.active;
    if (desactivar &&
        !await confirmDialog(context, tr.clientesDesactivarTitulo,
            tr.clientesDesactivarMensaje(cliente.name))) {
      return;
    }
    if (!context.mounted) return;
    try {
      await context
          .read<DataProvider>()
          .updateClient(cliente.id, {'active': !desactivar});
      if (context.mounted) {
        showAppSnack(
            context,
            desactivar
                ? tr.clientesDesactivado(cliente.name)
                : tr.clientesReactivado(cliente.name));
      }
    } on ApiException catch (e) {
      if (context.mounted) showAppSnack(context, e.message, error: true);
    }
  }

  @override
  Widget build(BuildContext context) {
    final primario = colorDesdeHex(cliente.primaryColor);
    final secundario = colorDesdeHex(cliente.secondaryColor);
    final logoUrl = cliente.logoUrl;

    final datos = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(cliente.name,
            style: const TextStyle(
                fontSize: 16,
                fontWeight: AppWeights.uiSemibold,
                color: AppColors.textPrimary)),
        const SizedBox(height: 6),
        Wrap(
          spacing: 6,
          runSpacing: 6,
          children: [
            if (cliente.hasLaboratories)
              StatusChip(
                  label: tr.clientesEtiquetaLaboratorios,
                  color: AppColors.textSecondary,
                  icon: Icons.science_outlined),
            if (!cliente.active)
              StatusChip(
                  label: tr.clientesEtiquetaDesactivado,
                  color: AppColors.statusCritical,
                  icon: Icons.block),
            if (primario == null)
              StatusChip(
                  label: tr.clientesColoresEduxaction,
                  color: AppColors.textSecondary,
                  icon: Icons.palette_outlined)
            else ...[
              _Muestra(color: primario, etiqueta: tr.clientesPrimario),
              if (secundario != null)
                _Muestra(color: secundario, etiqueta: tr.clientesSecundario),
            ],
          ],
        ),
      ],
    );

    final acciones = Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        OutlinedButton.icon(
          icon: const Icon(Icons.edit_outlined, size: 16),
          label: Text(tr.comunEditar),
          onPressed: () => mostrarEditorDeCliente(context, cliente),
        ),
        // Enactus no se apaga desde acá: dejaría sin acceso a toda su red.
        if (!cliente.hasLaboratories)
          TextButton.icon(
            icon: Icon(
                cliente.active ? Icons.block : Icons.check_circle_outline,
                size: 16),
            label: Text(cliente.active
                ? tr.clientesDesactivar
                : tr.clientesReactivar),
            onPressed: () => _cambiarEstado(context),
          ),
      ],
    );

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.border),
      ),
      child: LayoutBuilder(builder: (context, limites) {
        final logo = _CajaDeLogo(
          url: logoUrl,
          nombre: cliente.name,
          placaClara: cliente.logoLightPlate,
        );
        if (limites.maxWidth < 560) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              logo,
              const SizedBox(height: 10),
              datos,
              const SizedBox(height: 10),
              acciones,
            ],
          );
        }
        return Row(
          children: [
            logo,
            const SizedBox(width: 16),
            Expanded(child: datos),
            const SizedBox(width: 12),
            acciones,
          ],
        );
      }),
    );
  }
}

/// El logo del cliente como se verá en el encabezado: sobre el mismo gris.
class _CajaDeLogo extends StatelessWidget {
  final String? url;
  final String nombre;
  final bool placaClara;
  const _CajaDeLogo(
      {required this.url, required this.nombre, required this.placaClara});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 140,
      height: 64,
      alignment: Alignment.center,
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: AppColors.background,
        borderRadius: BorderRadius.circular(8),
      ),
      child: url == null
          ? Text(tr.clientesSinLogo,
              textAlign: TextAlign.center,
              style: const TextStyle(color: AppColors.textMuted, fontSize: 12))
          : LogoDeCliente(
              imagen: NetworkImage(url!),
              nombre: nombre,
              placaClara: placaClara,
              altoMaximo: 44,
              anchoMaximo: 120,
            ),
    );
  }
}

class _Muestra extends StatelessWidget {
  final Color color;
  final String etiqueta;
  const _Muestra({required this.color, required this.etiqueta});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 16,
          height: 16,
          decoration: BoxDecoration(
            color: color,
            borderRadius: BorderRadius.circular(4),
            border: Border.all(color: AppColors.border),
          ),
        ),
        const SizedBox(width: 5),
        // `Flexible`: vive en un `Wrap`, que le ofrece a lo sumo su propio
        // ancho. A 360 dp con letra grande, la etiqueta entera no cabía.
        Flexible(
          child: Text('$etiqueta ${hexDe(color)}',
              style: const TextStyle(
                  color: AppColors.textSecondary,
                  fontSize: 12,
                  fontFeatures: [FontFeature.tabularFigures()])),
        ),
      ],
    );
  }
}

/// Abre el formulario de un cliente ([original] `null` = nuevo).
Future<void> mostrarEditorDeCliente(BuildContext context, Client? original) =>
    showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (_) => EditorDeCliente(original: original),
    );

/// Formulario de un cliente: nombre, logo, colores, vista previa e informe de
/// contraste.
class EditorDeCliente extends StatefulWidget {
  final Client? original;
  const EditorDeCliente({super.key, this.original});

  @override
  State<EditorDeCliente> createState() => _EditorDeClienteState();
}

class _EditorDeClienteState extends State<EditorDeCliente> {
  late final _nombre = TextEditingController(text: widget.original?.name ?? '');
  late Color? _primario = colorDesdeHex(widget.original?.primaryColor);
  late Color? _secundario = colorDesdeHex(widget.original?.secondaryColor);
  late bool _placaClara = widget.original?.logoLightPlate ?? false;

  /// El logo nuevo elegido en este formulario, todavía sin subir.
  Uint8List? _logoNuevo;
  AnalisisDeLogo? _analisis;

  /// `true` si se quitó el logo que ya tenía.
  bool _logoQuitado = false;

  bool _analizando = false;
  bool _guardando = false;
  double? _progreso;
  ApiException? _error;
  String? _errorNombre;
  bool _cambios = false;

  bool get _esNuevo => widget.original == null;

  ImageProvider? get _logoVisible {
    if (_logoNuevo != null) return MemoryImage(_logoNuevo!);
    final url = widget.original?.logoUrl;
    if (_logoQuitado || url == null) return null;
    return NetworkImage(url);
  }

  @override
  void dispose() {
    _nombre.dispose();
    super.dispose();
  }

  void _marcar(VoidCallback cambio) => setState(() {
        cambio();
        _cambios = true;
      });

  Future<void> _elegirLogo() async {
    final resultado = await FilePicker.pickFiles(
      type: FileType.custom,
      allowedExtensions: const ['png'],
      // En la web los bytes llegan con la selección; en el teléfono se leen
      // después de mirar el tamaño, para no cargar un archivo enorme.
      withData: kIsWeb,
    );
    final archivo = resultado?.files.singleOrNull;
    if (archivo == null || !mounted) return;
    if (archivo.size > maxBytesLogo) {
      setState(() => _analisis = null);
      showAppSnack(
          context, tr.clientesLogoPesado(decimal(archivo.size / 1024 / 1024)),
          error: true);
      return;
    }
    setState(() => _analizando = true);
    final bytes = archivo.bytes ?? await archivo.xFile.readAsBytes();
    final analisis = await analizarLogo(bytes);
    if (!mounted) return;
    _marcar(() {
      _analizando = false;
      _analisis = analisis;
      if (analisis.sirve) {
        _logoNuevo = bytes;
        _logoQuitado = false;
        // La placa se propone según el logo; quien administra decide.
        _placaClara = analisis.necesitaPlaca;
      }
    });
  }

  Future<void> _guardar() async {
    final nombre = _nombre.text.trim();
    if (nombre.length < 2) {
      setState(() => _errorNombre = tr.clientesNombreFalta);
      return;
    }
    setState(() {
      _guardando = true;
      _error = null;
      _errorNombre = null;
    });
    final data = context.read<DataProvider>();
    try {
      String? keyNueva;
      if (_logoNuevo != null) {
        keyNueva = await data.uploadClientLogo(_logoNuevo!, onProgress: (p) {
          if (mounted) setState(() => _progreso = p);
        });
      }
      final campos = <String, dynamic>{
        'name': nombre,
        'primaryColor': _primario == null ? null : hexDe(_primario!),
        // Sin primario no hay secundario: acompaña a un primario propio.
        'secondaryColor':
            _primario == null || _secundario == null ? null : hexDe(_secundario!),
        'logoLightPlate': _placaClara,
        if (keyNueva != null)
          'logoS3Key': keyNueva
        else if (_logoQuitado)
          'logoS3Key': null,
      };
      if (_esNuevo) {
        await data.createClient(campos);
      } else {
        await data.updateClient(widget.original!.id, campos);
      }
      if (!mounted) return;
      Navigator.pop(context);
      showAppSnack(context, tr.clientesGuardado(nombre));
    } on ApiException catch (e) {
      if (mounted) {
        setState(() {
          _guardando = false;
          _progreso = null;
          _error = e;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    // Formulario y vista previa lado a lado si la pantalla da para el diálogo
    // entero (1080 + márgenes). Se mira la pantalla y no el espacio del
    // diálogo: el diálogo mide su contenido antes de dibujarlo, y un
    // `LayoutBuilder` no admite esa medida.
    final ladoALado = MediaQuery.sizeOf(context).width >= 1200;
    final paleta = paletaDeColores(
      _primario == null ? null : hexDe(_primario!),
      _secundario == null ? null : hexDe(_secundario!),
    );
    final logo = _logoVisible;
    final nombre =
        _nombre.text.trim().isEmpty ? tr.clientesNombreProvisional : _nombre.text.trim();

    final formulario = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        if (_error != null) ErrorBanner(_error!),
        // Aire para la etiqueta flotante: sin él, el borde de arriba del
        // área con desplazamiento la corta contra el título del diálogo.
        const SizedBox(height: 8),
        TextField(
          controller: _nombre,
          enabled: !_guardando,
          onChanged: (_) => _marcar(() => _errorNombre = null),
          decoration: InputDecoration(
            labelText: tr.clientesNombre,
            errorText: _errorNombre,
          ),
        ),
        const SizedBox(height: 18),
        Text(tr.clientesLogo,
            style: const TextStyle(
                color: AppColors.textPrimary,
                fontWeight: AppWeights.uiSemibold)),
        const SizedBox(height: 4),
        Text(tr.clientesLogoAyuda,
            style: const TextStyle(color: AppColors.textMuted, fontSize: 12)),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            OutlinedButton.icon(
              icon: const Icon(Icons.upload_outlined, size: 16),
              label: Text(logo == null ? tr.clientesSubirLogo : tr.clientesReemplazarLogo),
              onPressed: _guardando || _analizando ? null : _elegirLogo,
            ),
            if (logo != null)
              TextButton.icon(
                icon: const Icon(Icons.delete_outline, size: 16),
                label: Text(tr.clientesQuitarLogo),
                onPressed: _guardando
                    ? null
                    : () => _marcar(() {
                          _logoNuevo = null;
                          _analisis = null;
                          _logoQuitado = true;
                          _placaClara = false;
                        }),
              ),
            if (_analizando)
              const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(strokeWidth: 2)),
          ],
        ),
        if (_analisis case final a?) ...[
          const SizedBox(height: 8),
          if (!a.sirve)
            _Nota(texto: a.error!, aviso: true)
          else ...[
            _Nota(texto: tr.clientesLogoMedidas(a.ancho, a.alto), aviso: false),
            if (!a.tieneTransparencia)
              _Nota(texto: tr.clientesLogoSinTransparencia, aviso: true),
            if (a.necesitaPlaca)
              _Nota(texto: tr.clientesLogoOscuro, aviso: true),
          ],
        ],
        if (logo != null)
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            value: _placaClara,
            onChanged:
                _guardando ? null : (v) => _marcar(() => _placaClara = v),
            title: Text(tr.clientesPlacaClara,
                style: const TextStyle(fontSize: 14)),
            subtitle: Text(tr.clientesPlacaClaraAyuda,
                style: const TextStyle(fontSize: 12)),
          ),
        const SizedBox(height: 14),
        CampoDeColor(
          etiqueta: tr.clientesColorPrimario,
          ayuda: tr.clientesColorPrimarioAyuda,
          valor: _primario,
          permiteVaciar: true,
          textoVacio: tr.clientesColorPrimarioVacio,
          habilitado: !_guardando,
          alCambiar: (c) => _marcar(() => _primario = c),
        ),
        const SizedBox(height: 18),
        CampoDeColor(
          etiqueta: tr.clientesColorSecundario,
          ayuda: tr.clientesColorSecundarioAyuda,
          valor: _secundario,
          permiteVaciar: true,
          textoVacio: tr.clientesColorSecundarioVacio,
          habilitado: !_guardando && _primario != null,
          alCambiar: (c) => _marcar(() => _secundario = c),
        ),
        if (_progreso != null) ...[
          const SizedBox(height: 12),
          Text(tr.clientesSubiendoLogo,
              style: const TextStyle(color: AppColors.textSecondary, fontSize: 12)),
          const SizedBox(height: 4),
          LinearProgressIndicator(value: _progreso),
        ],
      ],
    );

    final vista = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(tr.clientesVistaPrevia,
            style: const TextStyle(
                color: AppColors.textPrimary,
                fontWeight: AppWeights.uiSemibold)),
        const SizedBox(height: 8),
        VistaPreviaMarca(
          paleta: paleta,
          nombre: nombre,
          logo: logo,
          placaClara: _placaClara,
          ladoALado: ladoALado,
        ),
        const SizedBox(height: 14),
        Text(tr.clientesLegibilidad,
            style: const TextStyle(
                color: AppColors.textPrimary,
                fontWeight: AppWeights.uiSemibold)),
        const SizedBox(height: 8),
        InformeDeContraste(paleta: paleta),
      ],
    );

    return AdaptiveFormShell(
      title: _esNuevo
          ? tr.clientesNuevo
          : tr.clientesEditar(widget.original!.name),
      maxWidth: 1080,
      saving: _guardando,
      dirty: _cambios,
      onCancel: () => Navigator.pop(context),
      onSave: _analizando ? null : _guardar,
      child: ladoALado
          ? Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SizedBox(width: 340, child: formulario),
                const SizedBox(width: 24),
                SizedBox(width: 668, child: vista),
              ],
            )
          : Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [formulario, const SizedBox(height: 20), vista],
            ),
    );
  }
}

class _Nota extends StatelessWidget {
  final String texto;
  final bool aviso;
  const _Nota({required this.texto, required this.aviso});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(aviso ? Icons.info_outline : Icons.check_circle_outline,
              size: 16,
              color: aviso ? AppColors.statusWarning : AppColors.statusGood),
          const SizedBox(width: 6),
          Expanded(
            child: Text(texto,
                style: const TextStyle(
                    color: AppColors.textSecondary, fontSize: 12.5)),
          ),
        ],
      ),
    );
  }
}
