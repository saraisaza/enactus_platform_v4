import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../models/models.dart';
import '../../providers/data_provider.dart';
import '../../services/api_errors.dart';
import '../../utils/app_theme.dart';
import '../../utils/constants.dart';
import '../../widgets/async_states.dart';
import '../../widgets/common.dart';

/// Moderación del foro: reportar, bloquear y la cola del equipo.
///
/// App Store (guía 1.2) no publica una app donde las personas publican si no
/// trae las cuatro cosas: filtrar lo ofensivo (lo hace el servidor), reportar,
/// bloquear y un equipo que atienda los reportes. Las tres últimas viven acá.

/// Motivos que se ofrecen al reportar. Se guardan tal cual en el reporte, que
/// es lo que lee el equipo.
const motivosDeReporte = [
  'Es ofensivo o irrespetuoso',
  'Es acoso o intimidación',
  'Discrimina a alguien',
  'Es spam o publicidad',
  'Comparte datos personales',
  'Otro motivo',
];

/// A quién se puede bloquear: a nadie del equipo que modera (sus anuncios son
/// del foro entero; lo suyo se reporta como lo de cualquiera), ni a uno mismo.
/// El servidor aplica la misma regla.
bool sePuedeBloquear({
  required String autorId,
  required String autorRol,
  required String miId,
}) =>
    autorId.isNotEmpty &&
    autorId != miId &&
    autorRol != Roles.admin &&
    autorRol != Roles.superAdmin;

/// Reportar una publicación o, con [replyId], una respuesta.
///
/// Si [autorBloqueable], ofrece bloquear también a quien la escribió: quien
/// reporta algo suele no querer seguir viéndolo.
Future<void> mostrarReportar(
  BuildContext context, {
  required String postId,
  String? replyId,
  required String autorId,
  required String autorNombre,
  required bool autorBloqueable,
}) async {
  final resultado = await showDialog<_Reporte>(
    context: context,
    builder: (_) => _ReportarDialog(
      esRespuesta: replyId != null,
      autorNombre: autorNombre,
      autorBloqueable: autorBloqueable,
    ),
  );
  if (resultado == null || !context.mounted) return;

  final data = context.read<DataProvider>();
  try {
    final nuevo = await data.reportForumContent(postId,
        replyId: replyId, reason: resultado.motivo);
    if (resultado.bloquear) await data.blockForumUser(autorId);
    if (!context.mounted) return;
    showAppSnack(
      context,
      nuevo
          ? 'Gracias. El equipo de Enactus revisará este contenido.'
          : 'Ya lo había reportado; el equipo lo tiene en su lista.',
    );
  } on ApiException catch (e) {
    if (context.mounted) showAppSnack(context, e.message, error: true);
  }
}

class _Reporte {
  final String motivo;
  final bool bloquear;
  const _Reporte(this.motivo, this.bloquear);
}

class _ReportarDialog extends StatefulWidget {
  final bool esRespuesta;
  final String autorNombre;
  final bool autorBloqueable;

  const _ReportarDialog({
    required this.esRespuesta,
    required this.autorNombre,
    required this.autorBloqueable,
  });

  @override
  State<_ReportarDialog> createState() => _ReportarDialogState();
}

class _ReportarDialogState extends State<_ReportarDialog> {
  String? _motivo;
  bool _bloquear = false;

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(
        widget.esRespuesta ? 'Reportar respuesta' : 'Reportar publicación',
        style: const TextStyle(fontSize: 18),
      ),
      contentPadding: const EdgeInsets.fromLTRB(8, 16, 8, 0),
      content: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 420),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Padding(
                padding: EdgeInsets.symmetric(horizontal: 16),
                child: Text(
                  '¿Por qué lo reporta? Solo el equipo de Enactus verá quién '
                  'lo reportó.',
                  style: TextStyle(color: AppColors.textMuted, height: 1.4),
                ),
              ),
              const SizedBox(height: 4),
              for (final motivo in motivosDeReporte)
                RadioListTile<String>(
                  dense: true,
                  title: Text(motivo),
                  value: motivo,
                  // ignore: deprecated_member_use
                  groupValue: _motivo,
                  activeColor: AppColors.gold,
                  // ignore: deprecated_member_use
                  onChanged: (v) => setState(() => _motivo = v),
                ),
              if (widget.autorBloqueable)
                CheckboxListTile(
                  dense: true,
                  value: _bloquear,
                  activeColor: AppColors.gold,
                  controlAffinity: ListTileControlAffinity.leading,
                  title: Text('Bloquear también a ${widget.autorNombre}'),
                  subtitle: const Text('Dejará de ver lo que publica.'),
                  onChanged: (v) => setState(() => _bloquear = v ?? false),
                ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancelar'),
        ),
        ElevatedButton(
          onPressed: _motivo == null
              ? null
              : () => Navigator.pop(context, _Reporte(_motivo!, _bloquear)),
          child: const Text('Reportar'),
        ),
      ],
    );
  }
}

/// Bloquear a alguien, con confirmación.
Future<void> confirmarBloqueo(
  BuildContext context, {
  required String autorId,
  required String autorNombre,
}) async {
  final data = context.read<DataProvider>();
  if (!await confirmDialog(
    context,
    'Bloquear a $autorNombre',
    'Dejará de ver lo que $autorNombre publica y responde en el foro. No se '
        'le avisará. Puede desbloquearle cuando quiera desde «Personas '
        'bloqueadas», en las normas del foro.',
  )) {
    return;
  }
  try {
    await data.blockForumUser(autorId);
    if (context.mounted) showAppSnack(context, 'Bloqueó a $autorNombre.');
  } on ApiException catch (e) {
    if (context.mounted) showAppSnack(context, e.message, error: true);
  }
}

/// La lista de personas bloqueadas, para desbloquear.
Future<void> mostrarPersonasBloqueadas(BuildContext context) {
  return showDialog<void>(
    context: context,
    builder: (ctx) => AlertDialog(
      title: const Text('Personas bloqueadas', style: TextStyle(fontSize: 18)),
      content: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 420, minWidth: 260),
        child: Consumer<DataProvider>(
          builder: (context, data, _) => data.forumBlocks.when(
            loading: () => const Padding(
              padding: EdgeInsets.all(24),
              child: Center(child: CircularProgressIndicator()),
            ),
            error: (e) =>
                ErrorState(e, compact: true, onRetry: data.reloadForumBlocks),
            data: (bloqueos) => bloqueos.isEmpty
                ? const Text('No ha bloqueado a nadie.',
                    style: TextStyle(color: AppColors.textMuted))
                : SingleChildScrollView(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        for (final b in bloqueos)
                          ListTile(
                            contentPadding: EdgeInsets.zero,
                            title: Text(b.name),
                            trailing: TextButton(
                              onPressed: () async {
                                try {
                                  await data.unblockForumUser(b.userId);
                                } on ApiException catch (e) {
                                  if (context.mounted) {
                                    showAppSnack(context, e.message,
                                        error: true);
                                  }
                                }
                              },
                              child: const Text('Desbloquear'),
                            ),
                          ),
                      ],
                    ),
                  ),
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(ctx),
          child: const Text('Cerrar'),
        ),
      ],
    ),
  );
}

// ---------------------------------------------------------------------------
// La cola del equipo
// ---------------------------------------------------------------------------

/// Reportes sin atender. Solo Admin y Super Admin llegan acá.
class ForoReportesView extends StatelessWidget {
  const ForoReportesView({super.key});

  static Future<void> abrir(BuildContext context) {
    return Navigator.of(context, rootNavigator: true).push(
      MaterialPageRoute<void>(builder: (_) => const ForoReportesView()),
    );
  }

  @override
  Widget build(BuildContext context) {
    final data = context.watch<DataProvider>();
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.background,
        title: const Text('Reportes del foro', style: TextStyle(fontSize: 17)),
      ),
      body: SafeArea(
        top: false,
        child: data.forumReports.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (e) => ErrorState(e, onRetry: data.reloadForumReports),
          data: (reportes) => RefreshIndicator.adaptive(
            onRefresh: data.reloadForumReports,
            child: reportes.isEmpty
                ? ListView(
                    physics: const AlwaysScrollableScrollPhysics(),
                    padding: const EdgeInsets.all(24),
                    children: const [
                      SizedBox(height: 40),
                      Icon(Icons.verified_user_outlined,
                          size: 40, color: AppColors.textMuted),
                      SizedBox(height: 12),
                      Text('No hay reportes pendientes.',
                          textAlign: TextAlign.center,
                          style: TextStyle(color: AppColors.textMuted)),
                    ],
                  )
                : ListView.separated(
                    physics: const AlwaysScrollableScrollPhysics(),
                    padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
                    itemCount: reportes.length,
                    separatorBuilder: (_, _) => const SizedBox(height: 12),
                    itemBuilder: (context, i) =>
                        _TarjetaDeReporte(reporte: reportes[i]),
                  ),
          ),
        ),
      ),
    );
  }
}

class _TarjetaDeReporte extends StatefulWidget {
  final ForumReport reporte;
  const _TarjetaDeReporte({required this.reporte});

  @override
  State<_TarjetaDeReporte> createState() => _TarjetaDeReporteState();
}

class _TarjetaDeReporteState extends State<_TarjetaDeReporte> {
  bool _trabajando = false;

  Future<void> _resolver({required bool quitar}) async {
    final r = widget.reporte;
    if (quitar &&
        !r.contentRemoved &&
        !await confirmDialog(
          context,
          r.isReply ? 'Quitar respuesta' : 'Quitar publicación',
          'Se quitará del foro para todas las personas. No se puede deshacer.',
        )) {
      return;
    }
    if (!mounted) return;
    setState(() => _trabajando = true);
    try {
      await context
          .read<DataProvider>()
          .resolveForumReport(r.id, remove: quitar);
    } on ApiException catch (e) {
      if (mounted) showAppSnack(context, e.message, error: true);
    } finally {
      if (mounted) setState(() => _trabajando = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final r = widget.reporte;
    final fecha = MaterialLocalizations.of(context).formatShortDate(r.createdAt);
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surfaceAlt,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Wrap(
            spacing: 8,
            runSpacing: 6,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              Text(r.isReply ? 'RESPUESTA' : 'PUBLICACIÓN',
                  style: const TextStyle(
                      fontSize: 11,
                      letterSpacing: 1,
                      fontWeight: FontWeight.w700,
                      color: AppColors.gold)),
              if (r.contentRemoved)
                const Text('· ya no se ve en el foro',
                    style:
                        TextStyle(fontSize: 12, color: AppColors.textMuted)),
            ],
          ),
          const SizedBox(height: 8),
          Text(r.reason.isEmpty ? 'Sin motivo' : r.reason,
              style: const TextStyle(fontWeight: FontWeight.w700)),
          const SizedBox(height: 2),
          Text('Reportó ${r.reporterName} · $fecha',
              style: const TextStyle(fontSize: 12, color: AppColors.textMuted)),
          const SizedBox(height: 12),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: AppColors.background,
              borderRadius: BorderRadius.circular(10),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(r.authorName,
                    style: const TextStyle(
                        fontSize: 12.5, fontWeight: FontWeight.w600)),
                const SizedBox(height: 4),
                Text(r.body, style: const TextStyle(height: 1.45)),
              ],
            ),
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            alignment: WrapAlignment.end,
            children: [
              OutlinedButton(
                onPressed: _trabajando ? null : () => _resolver(quitar: false),
                child: Text(r.contentRemoved ? 'Cerrar reporte' : 'Dejarlo'),
              ),
              if (!r.contentRemoved)
                ElevatedButton(
                  onPressed: _trabajando ? null : () => _resolver(quitar: true),
                  child: const Text('Quitar del foro'),
                ),
            ],
          ),
        ],
      ),
    );
  }
}
