import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../models/models.dart';
import '../../providers/auth_provider.dart';
import '../../providers/data_provider.dart';
import '../../utils/app_theme.dart';
import '../../utils/constants.dart';
import '../../widgets/common.dart';
import '../../widgets/portal_shell.dart';
import 'student_detail_view.dart';

/// BuscaTalento: como un Facebook de talento Enactus para Donantes y
/// Empresas — ven el perfil de los estudiantes Enactus (los de Open
/// Learning no tienen Ruta de Impacto, así que no aplican) y qué
/// objetivos ya cumplieron, para contactarlos por oportunidades futuras.
/// Se muestran primero quienes ya completaron objetivos EMPRESARIALES.
class TalentSearchView extends StatelessWidget {
  const TalentSearchView({super.key});

  @override
  Widget build(BuildContext context) {
    final data = context.watch<DataProvider>();
    final students = data.talentSearchStudents();

    return TabBody(
      title: 'BuscaTalento',
      subtitle:
          'Estudiantes Enactus que ya demostraron sus habilidades en la Ruta de Impacto — contáctalos para oportunidades futuras 💛',
      children: [
        if (students.isEmpty)
          const EmptyState(
              icon: Icons.people_outline,
              message: 'Todavía no hay estudiantes Enactus en la plataforma.')
        else
          ...students.map((s) => Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: _TalentCard(student: s),
              )),
      ],
    );
  }
}

class _TalentCard extends StatelessWidget {
  final AppUser student;
  const _TalentCard({required this.student});

  @override
  Widget build(BuildContext context) {
    final data = context.watch<DataProvider>();
    final group = data.groupById(student.groupId);
    final project = group == null ? null : data.projectById(group.projectId);
    final labs = data.labsForStudent(student);
    final objs = data.completedObjectivesFor(student);
    final progress = data.overallProgress(student);
    final certs = data.certificatesForStudent(student.id).length;
    final topTalent = objs.business > 0;

    return HoverCard(
      padding: const EdgeInsets.all(18),
      onTap: () => Navigator.push(context,
          MaterialPageRoute(builder: (_) => StudentDetailView(studentId: student.id))),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              InitialsAvatar(student.name, large: true),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Wrap(
                      crossAxisAlignment: WrapCrossAlignment.center,
                      spacing: 8,
                      runSpacing: 4,
                      children: [
                        Text(student.name,
                            style: const TextStyle(
                                fontWeight: FontWeight.w700, fontSize: 16)),
                        if (topTalent)
                          const StatusChip(
                              label: 'Objetivos empresariales cumplidos',
                              color: AppColors.gold,
                              icon: Icons.star_outline),
                      ],
                    ),
                    Text('${student.university} · ${student.career}',
                        style: const TextStyle(
                            color: AppColors.textMuted, fontSize: 12.5)),
                    if (project != null)
                      Padding(
                        padding: const EdgeInsets.only(top: 2),
                        child: Text(
                            'Proyecto: ${project.name} · Etapa: ${project.stage}',
                            style: const TextStyle(
                                color: AppColors.textSecondary,
                                fontSize: 12.5)),
                      ),
                  ],
                ),
              ),
              OutlinedButton.icon(
                icon: const Icon(Icons.notifications_active_outlined,
                    size: 16),
                label: const Text('Notificar interés'),
                onPressed: () => _notifyInterest(context, data, student),
              ),
            ],
          ),
          if (student.email.isNotEmpty || student.phone.isNotEmpty) ...[
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: AppColors.surfaceAlt,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Datos de contacto',
                      style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          color: AppColors.textMuted,
                          letterSpacing: 0.4)),
                  const SizedBox(height: 6),
                  if (student.email.isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 2),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(Icons.email_outlined,
                              size: 14, color: AppColors.gold),
                          const SizedBox(width: 6),
                          SelectableText(student.email,
                              style: const TextStyle(fontSize: 12.5)),
                        ],
                      ),
                    ),
                  if (student.phone.isNotEmpty)
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.phone_outlined,
                            size: 14, color: AppColors.gold),
                        const SizedBox(width: 6),
                        SelectableText(student.phone,
                            style: const TextStyle(fontSize: 12.5)),
                      ],
                    ),
                ],
              ),
            ),
          ],
          if (labs.isNotEmpty) ...[
            const SizedBox(height: 10),
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: [
                for (final l in labs)
                  Chip(
                      avatar: const Icon(Icons.science_outlined, size: 14),
                      label: Text(l.name, style: const TextStyle(fontSize: 11))),
              ],
            ),
          ],
          const SizedBox(height: 12),
          Row(
            children: [
              _MiniStat(
                  icon: Icons.business_center_outlined,
                  label: '${objs.business} objetivo(s) empresariales',
                  highlight: objs.business > 0),
              const SizedBox(width: 18),
              _MiniStat(
                  icon: Icons.rocket_launch_outlined,
                  label: '${objs.entrepreneurship} de emprendimiento',
                  highlight: false),
              if (certs > 0) ...[
                const SizedBox(width: 18),
                _MiniStat(
                    icon: Icons.workspace_premium_outlined,
                    label: '$certs certificado(s)',
                    highlight: false),
              ],
            ],
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              const SizedBox(
                  width: 130,
                  child: Text('Avance general',
                      style: TextStyle(
                          fontSize: 12, color: AppColors.textMuted))),
              Expanded(child: ThinProgressBar(value: progress)),
              const SizedBox(width: 8),
              Text('${(progress * 100).round()}%',
                  style: const TextStyle(
                      fontSize: 12, color: AppColors.textMuted)),
            ],
          ),
        ],
      ),
    );
  }

  /// No hay mensajería en la plataforma todavía: esto no abre un
  /// compositor de texto libre, solo confirma y envía una notificación
  /// de plantilla fija — el contacto real ocurre por fuera, con los
  /// datos de contacto que ya se muestran en la tarjeta.
  Future<void> _notifyInterest(
      BuildContext context, DataProvider data, AppUser student) async {
    final me = context.read<AuthProvider>().currentUser!;
    final orgName = me.role == Roles.company ? me.companyName : me.name;

    final confirmed = await confirmDialog(
        context,
        'Notificar interés',
        '¿Avisarle a ${student.name} que $orgName está interesado en su perfil? '
            'Le llega como notificación dentro de la plataforma; para el '
            'contacto real usa los datos de contacto de su tarjeta.');
    if (!confirmed || !context.mounted) return;

    await data.notify(
      student.id,
      '$orgName mostró interés en tu perfil 💼',
      'Vieron tu perfil en BuscaTalento gracias a lo que has cumplido en tu Ruta de Impacto. '
          'Revisa que tu correo y teléfono estén al día en "Mi Perfil" para que puedan contactarte.',
    );
    if (context.mounted) {
      showSuccessCheck(context, 'Notificación enviada ✓');
    }
  }
}

class _MiniStat extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool highlight;
  const _MiniStat(
      {required this.icon, required this.label, required this.highlight});

  @override
  Widget build(BuildContext context) {
    final color = highlight ? AppColors.gold : AppColors.textSecondary;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 15, color: color),
        const SizedBox(width: 5),
        Text(label,
            style: TextStyle(
                fontSize: 12.5,
                color: color,
                fontWeight: highlight ? FontWeight.w700 : FontWeight.w400)),
      ],
    );
  }
}
