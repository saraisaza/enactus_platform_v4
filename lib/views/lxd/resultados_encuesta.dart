import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../l10n/textos.dart';
import '../../models/encuesta.dart';
import '../../models/models.dart';
import '../../providers/data_provider.dart';
import '../../services/api_errors.dart';
import '../../utils/app_theme.dart';
import '../../utils/formatos.dart';
import '../../widgets/async_states.dart';
import '../../widgets/common.dart';

/// Los resultados de una encuesta, para quien diseña el curso.
///
/// Juntos y sin nombres: cuántos eligieron cada opción, cómo se repartió la
/// calificación y los comentarios.
Future<void> showSurveyResults(BuildContext context, Lesson lesson) =>
    showAdaptiveFormDialog<void>(
      context: context,
      title: tr.encuestaResultadosDe(lesson.title),
      maxWidth: 560,
      contentBuilder: (_) => ResultadosDeEncuestaView(lessonId: lesson.id),
      actionsBuilder: (ctx) => [
        TextButton(
          onPressed: () => Navigator.pop(ctx),
          child: Text(tr.comunCerrar),
        ),
      ],
    );

class ResultadosDeEncuestaView extends StatefulWidget {
  final String lessonId;
  const ResultadosDeEncuestaView({super.key, required this.lessonId});

  @override
  State<ResultadosDeEncuestaView> createState() =>
      _ResultadosDeEncuestaViewState();
}

class _ResultadosDeEncuestaViewState extends State<ResultadosDeEncuestaView> {
  ResultadosDeEncuesta? _resultados;
  ApiException? _error;

  @override
  void initState() {
    super.initState();
    _cargar();
  }

  Future<void> _cargar() async {
    setState(() => _error = null);
    try {
      final r =
          await context.read<DataProvider>().surveyResults(widget.lessonId);
      if (mounted) setState(() => _resultados = r);
    } on ApiException catch (e) {
      if (mounted) setState(() => _error = e);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_error != null) {
      return ErrorState(_error!, compact: true, onRetry: _cargar);
    }
    final r = _resultados;
    if (r == null) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 24),
        child: Center(child: BrandLoader()),
      );
    }
    final tenue = TextStyle(fontSize: 12, color: AppColors.textMuted);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(Icons.groups_outlined, size: 18, color: AppColors.gold),
            const SizedBox(width: 8),
            Text(tr.encuestaRespondieron(r.respuestas),
                style: const TextStyle(fontWeight: FontWeight.w700)),
          ],
        ),
        const SizedBox(height: 6),
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Icon(Icons.lock_outline, size: 14, color: AppColors.textMuted),
            const SizedBox(width: 6),
            Expanded(child: Text(tr.encuestaAnonima, style: tenue)),
          ],
        ),
        const SizedBox(height: 16),
        if (r.respuestas == 0)
          Text(tr.encuestaNadieRespondio, style: tenue)
        else
          for (final (i, p) in r.preguntas.indexed) ...[
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              margin: const EdgeInsets.only(bottom: 10),
              decoration: BoxDecoration(
                color: AppColors.surfaceAlt,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: AppColors.border),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('${i + 1}. ${p.question}',
                      style: const TextStyle(fontWeight: FontWeight.w600)),
                  const SizedBox(height: 10),
                  ..._detalle(p, tenue),
                ],
              ),
            ),
          ],
      ],
    );
  }

  List<Widget> _detalle(ResultadoDePregunta p, TextStyle tenue) {
    switch (p.kind) {
      case 'multiple':
        return [
          for (final (o, opcion) in p.options.indexed)
            _barra(opcion, o < p.counts.length ? p.counts[o] : 0, p.total),
        ];
      case 'scale':
        final extremo1 = p.options.isNotEmpty ? p.options[0].trim() : '';
        final extremo5 = p.options.length > 1 ? p.options[1].trim() : '';
        return [
          if (p.average != null)
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Text(tr.encuestaPromedio(decimal(p.average!)),
                  style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                      color: AppColors.gold)),
            ),
          for (var n = 1; n <= 5; n++)
            _barra(
              switch (n) {
                1 when extremo1.isNotEmpty => '1 · $extremo1',
                5 when extremo5.isNotEmpty => '5 · $extremo5',
                _ => '$n',
              },
              n <= p.counts.length ? p.counts[n - 1] : 0,
              p.total,
            ),
        ];
      default:
        if (p.comments.isEmpty) return [Text(tr.encuestaSinComentarios, style: tenue)];
        return [
          for (final c in p.comments)
            Container(
              width: double.infinity,
              margin: const EdgeInsets.only(bottom: 6),
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
              decoration: BoxDecoration(
                color: AppColors.background,
                borderRadius: BorderRadius.circular(8),
                border: Border(
                    left: BorderSide(color: AppColors.gold, width: 3)),
              ),
              child: Text(c, style: const TextStyle(fontSize: 13)),
            ),
        ];
    }
  }

  /// Una opción (o un número de la calificación): cuántos y qué parte del
  /// total.
  Widget _barra(String etiqueta, int cuantos, int total) {
    final parte = total == 0 ? 0.0 : cuantos / total;
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(etiqueta, style: const TextStyle(fontSize: 13)),
              ),
              const SizedBox(width: 8),
              Text('${entero(cuantos)} · ${entero(parte * 100)} %',
                  style: TextStyle(
                      fontSize: 12.5, color: AppColors.textSecondary)),
            ],
          ),
          const SizedBox(height: 4),
          // No `ThinProgressBar`: mide su ancho con un LayoutBuilder, y el
          // diálogo necesita medir su contenido antes de dibujarlo.
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: parte,
              minHeight: 6,
              backgroundColor: AppColors.background,
              valueColor: AlwaysStoppedAnimation(AppColors.gold),
            ),
          ),
        ],
      ),
    );
  }
}
