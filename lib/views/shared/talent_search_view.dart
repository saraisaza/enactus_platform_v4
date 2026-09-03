import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../models/models.dart';
import '../../providers/data_provider.dart';
import '../../services/api_errors.dart';
import '../../utils/app_theme.dart';
import '../../widgets/async_states.dart';
import '../../widgets/common.dart';
import '../../widgets/portal_shell.dart';
import 'user_detail_view.dart';

/// BuscaTalento: el directorio de talento eduXaction para Donantes y Empresas.
///
/// Es el **único** listado de personas cuyo alcance es más ancho que el resto:
/// acá los dos roles ven a todos los estudiantes eduXaction, no solo a los
/// suyos, porque la pantalla existe para descubrir a alguien que todavía no
/// conocen. Por eso viene de su propio endpoint (`/talent`) y no de un filtro
/// de `/users`: un filtro que ensancha el alcance es justo lo que después
/// nadie recuerda que existe.
///
/// **Muestra el perfil profesional, no los datos de contacto.** Ni correo, ni
/// teléfono, ni cédula. Para hablarles está el botón de contacto, que manda un
/// aviso a la bandeja de la persona dentro de la plataforma y no entrega el
/// correo de nadie.
class TalentSearchView extends StatelessWidget {
  const TalentSearchView({super.key});

  @override
  Widget build(BuildContext context) {
    final data = context.watch<DataProvider>();

    return TabBody(
      title: 'BuscaTalento',
      subtitle: 'Estudiantes eduXaction que ya demostraron sus habilidades en '
          'la Ruta de Impacto — contáctalos para oportunidades futuras 💛',
      children: [
        data.talent.when(
          loading: () => const CardListSkeleton(count: 4, height: 140),
          error: (e) => ErrorState(e),
          data: (perfiles) => perfiles.isEmpty
              ? const EmptyState(
                  icon: Icons.people_outline,
                  message:
                      'Todavía no hay estudiantes eduXaction en la plataforma.')
              : Column(
                  children: [
                    for (final p in perfiles)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 12),
                        child: _TalentCard(profile: p),
                      ),
                  ],
                ),
        ),
      ],
    );
  }
}

class _TalentCard extends StatelessWidget {
  final TalentProfile profile;
  const _TalentCard({required this.profile});

  @override
  Widget build(BuildContext context) {
    return HoverCard(
      onTap: () => Navigator.push(
        context,
        MaterialPageRoute(
            builder: (_) => UserDetailView(userId: profile.id)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              InitialsAvatar(profile.name, radius: 20),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(profile.name,
                        style: const TextStyle(
                            fontWeight: FontWeight.w700, fontSize: 15),
                        overflow: TextOverflow.ellipsis),
                    Text(
                      [
                        if (profile.career.isNotEmpty) profile.career,
                        if (profile.university.isNotEmpty) profile.university,
                        if (profile.city.isNotEmpty) profile.city,
                      ].join(' · '),
                      style: const TextStyle(
                          fontSize: 12.5, color: AppColors.textMuted),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
              if (profile.isTopTalent)
                const StatusChip(
                    label: 'Top talento',
                    color: AppColors.gold,
                    icon: Icons.star_outline),
            ],
          ),
          const SizedBox(height: 12),
          // `Wrap` y no `Row`: con tres o cuatro cifras y un nombre de
          // proyecto largo, una fila desborda en pantallas angostas.
          Wrap(
            spacing: 14,
            runSpacing: 8,
            children: [
              _MiniStat(
                icon: Icons.trending_up,
                label: '${(profile.progress.ratio * 100).round()}% de avance',
              ),
              _MiniStat(
                icon: Icons.flag_outlined,
                label: '${profile.objectivesEntrepreneurship} objetivos de '
                    'emprendimiento',
              ),
              _MiniStat(
                icon: Icons.business_center_outlined,
                label:
                    '${profile.objectivesBusiness} objetivos empresariales',
              ),
              if (profile.certificates > 0)
                _MiniStat(
                  icon: Icons.workspace_premium_outlined,
                  label: '${profile.certificates} certificados',
                ),
            ],
          ),
          if (profile.team != null || profile.laboratories.isNotEmpty) ...[
            const SizedBox(height: 10),
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: [
                if (profile.team != null)
                  StatusChip(
                      label: profile.team!.projectName,
                      color: AppColors.textSecondary,
                      icon: Icons.lightbulb_outline),
                for (final lab in profile.laboratories)
                  StatusChip(
                      label: lab.name,
                      color: AppColors.textSecondary,
                      icon: Icons.science_outlined),
              ],
            ),
          ],
          const SizedBox(height: 12),
          Align(
            alignment: Alignment.centerLeft,
            child: OutlinedButton.icon(
              icon: const Icon(Icons.send_outlined, size: 16),
              label: const Text('Contactar'),
              onPressed: () => _contactar(context),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _contactar(BuildContext context) => showDialog<void>(
        context: context,
        barrierDismissible: false,
        builder: (_) => _ContactDialog(profile: profile),
      );
}

class _MiniStat extends StatelessWidget {
  final IconData icon;
  final String label;

  const _MiniStat({required this.icon, required this.label});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 14, color: AppColors.gold),
        const SizedBox(width: 5),
        Text(label,
            style: const TextStyle(
                fontSize: 12, color: AppColors.textSecondary)),
      ],
    );
  }
}

/// Manda un aviso a la bandeja de la persona.
///
/// No entrega el correo de nadie: es la razón por la que esta pantalla puede
/// mostrar perfiles sin mostrar datos de contacto.
class _ContactDialog extends StatefulWidget {
  final TalentProfile profile;
  const _ContactDialog({required this.profile});

  @override
  State<_ContactDialog> createState() => _ContactDialogState();
}

class _ContactDialogState extends State<_ContactDialog> {
  final _title = TextEditingController(text: 'Una oportunidad para usted');
  final _body = TextEditingController();
  bool _saving = false;
  ApiException? _error;

  @override
  void dispose() {
    _title.dispose();
    _body.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (_title.text.trim().isEmpty) {
      setState(() =>
          _error = const ValidationError('El aviso necesita un título.'));
      return;
    }
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      await context.read<DataProvider>().notify(
            [widget.profile.id],
            title: _title.text.trim(),
            body: _body.text.trim(),
          );
      if (!mounted) return;
      Navigator.pop(context);
      showSuccessCheck(context, 'Mensaje enviado ✓');
    } on ApiException catch (e) {
      if (mounted) {
        setState(() {
          _saving = false;
          _error = e;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return AdaptiveFormShell(
      title: 'Contactar a ${widget.profile.name}',
      maxWidth: 460,
      saving: _saving,
      saveLabel: 'Enviar',
      onCancel: () => Navigator.pop(context),
      onSave: _save,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (_error != null) ...[
            ErrorBanner(_error!),
            const SizedBox(height: 12),
          ],
          const Text(
            'El mensaje llega a su bandeja dentro de la plataforma. No se '
            'entrega ningún dato de contacto.',
            style: TextStyle(fontSize: 12.5, color: AppColors.textMuted),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _title,
            enabled: !_saving,
            decoration: const InputDecoration(labelText: 'Asunto'),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _body,
            enabled: !_saving,
            maxLines: 4,
            decoration: const InputDecoration(labelText: 'Mensaje'),
          ),
        ],
      ),
    );
  }
}
