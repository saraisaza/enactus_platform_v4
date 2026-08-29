import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../models/models.dart';
import '../../providers/data_provider.dart';
import '../../utils/app_theme.dart';
import '../../utils/constants.dart';
import '../../widgets/app_footer.dart';
import '../../widgets/app_header.dart';
import '../../widgets/common.dart';
import '../student/course_detail_view.dart';
import 'lab_detail_view.dart';
import 'student_detail_view.dart';

/// Perfil de UN usuario, de cualquier rol — el destino real de `/usuarios/:id`
/// (antes esa ruta con nombre no existía; lo más parecido era
/// [StudentDetailView], alcanzable solo con `Navigator.push` y pensada
/// específicamente para estudiantes). Para roles tipo-estudiante delega
/// ahí directo (mismo contenido de siempre, sin duplicar nada); para
/// LXD/Mentor/Asesor/Empresa/Donante arma un resumen con lo que
/// [DataProvider] ya expone para ese rol. Sin restricción por rol de quien
/// mira — mismo criterio ya documentado en [StudentDetailView]: cualquier
/// cuenta con sesión puede ver el perfil de cualquier otra (defensa de
/// interfaz, no seguridad real — ver AUDITORIA_FRONT.md § 1.9).
class UserDetailView extends StatelessWidget {
  final String userId;
  const UserDetailView({super.key, required this.userId});

  @override
  Widget build(BuildContext context) {
    final data = context.watch<DataProvider>();
    final user = data.userById(userId);

    if (user == null) {
      return Scaffold(
        body: Column(
          children: [
            const AppHeader(portalTitle: 'Usuario'),
            const Expanded(
              child: EmptyState(
                  icon: Icons.person_outline,
                  message: 'Este usuario ya no existe o fue eliminado.'),
            ),
          ],
        ),
      );
    }

    if (Roles.isStudentLike(user.role)) {
      return StudentDetailView(studentId: user.id);
    }

    return Scaffold(
      body: Column(
        children: [
          AppHeader(portalTitle: Roles.label(user.role)),
          Expanded(
            child: CustomScrollView(
              slivers: [
                SliverToBoxAdapter(
                  child: Center(
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 860),
                      child: Padding(
                        padding: const EdgeInsets.all(24),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            IconButton(
                              icon: const Icon(Icons.arrow_back),
                              color: AppColors.gold,
                              onPressed: () => Navigator.pop(context),
                            ),
                            const SizedBox(height: 6),
                            _Header(user: user),
                            const SizedBox(height: 22),
                            _RoleBody(user: user),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
                const SliverFillRemaining(
                  hasScrollBody: false,
                  child: Align(alignment: Alignment.bottomCenter, child: AppFooter()),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _Header extends StatelessWidget {
  final AppUser user;
  const _Header({required this.user});

  @override
  Widget build(BuildContext context) {
    final subtitle = user.role == Roles.company
        ? (user.companyName.isEmpty ? null : user.companyName)
        : (user.university.isEmpty ? null : user.university);
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        InitialsAvatar(user.name, large: true, radius: 32),
        const SizedBox(width: 16),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(user.name,
                  style: knockoutHeading(
                      fontSize: 30, fontWeight: AppWeights.display, color: AppColors.textPrimary)),
              if (subtitle != null)
                Text(subtitle,
                    style: const TextStyle(fontSize: 13.5, color: AppColors.textMuted)),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  StatusChip(
                      label: Roles.label(user.role),
                      color: AppColors.gold,
                      icon: Icons.badge_outlined),
                  StatusChip(
                      label: user.email, color: AppColors.textMuted, icon: Icons.mail_outline),
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }
}

/// Resumen específico del rol — solo lectura, con lo que ya expone
/// [DataProvider] para ese rol. Los roles sin nada propio que resumir
/// (Admin, Super Admin) caen al mensaje genérico del final.
class _RoleBody extends StatelessWidget {
  final AppUser user;
  const _RoleBody({required this.user});

  @override
  Widget build(BuildContext context) {
    final data = context.watch<DataProvider>();

    if (user.role == Roles.lxd) {
      final courses = data.courses.where((c) => c.creatorId == user.id).toList();
      final students = data.studentsForCreator(user.id);
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SectionTitle('Cursos creados'),
          if (courses.isEmpty)
            const Text('Aún no ha creado ningún curso.',
                style: TextStyle(fontSize: 13, color: AppColors.textMuted))
          else
            for (final c in courses)
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: HoverCard(
                  onTap: () => Navigator.push(
                      context,
                      MaterialPageRoute(
                          settings: RouteSettings(name: '${AppRoutes.courses}/${c.id}'),
                          builder: (_) => CourseDetailView(courseId: c.id))),
                  child: Row(
                    children: [
                      Expanded(
                          child: Text(c.name,
                              style: const TextStyle(
                                  fontSize: 13.5,
                                  fontWeight: FontWeight.w600,
                                  color: AppColors.textPrimary))),
                      Text('${c.modules.length} módulos · ${c.lessonCount} lecciones',
                          style: const TextStyle(fontSize: 12, color: AppColors.textMuted)),
                    ],
                  ),
                ),
              ),
          const SizedBox(height: 8),
          Text('${students.length} estudiante(s) con acceso a sus cursos.',
              style: const TextStyle(fontSize: 13, color: AppColors.textMuted)),
        ],
      );
    }

    if (user.role == Roles.mentor) {
      final labs = data.labsForMentor(user);
      final students = data.studentsForMentor(user);
      final reviews = data.reviewsCountForMentor(user);
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SectionTitle('Laboratorios asignados'),
          if (labs.isEmpty)
            const Text('Sin laboratorios asignados todavía.',
                style: TextStyle(fontSize: 13, color: AppColors.textMuted))
          else
            for (final lab in labs)
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: HoverCard(
                  onTap: () => Navigator.push(
                      context,
                      MaterialPageRoute(
                          settings: RouteSettings(name: '${AppRoutes.labs}/${lab.id}'),
                          builder: (_) => LabDetailView(labId: lab.id))),
                  child: Row(
                    children: [
                      Container(
                          width: 8,
                          height: 8,
                          decoration: BoxDecoration(
                              color: labColorFor(lab.id), shape: BoxShape.circle)),
                      const SizedBox(width: 10),
                      Expanded(
                          child: Text(lab.name,
                              style: const TextStyle(
                                  fontSize: 13.5,
                                  fontWeight: FontWeight.w600,
                                  color: AppColors.textPrimary))),
                    ],
                  ),
                ),
              ),
          const SizedBox(height: 8),
          Text(
              '${students.length} estudiante(s) a cargo · $reviews entrega(s) revisada(s).',
              style: const TextStyle(fontSize: 13, color: AppColors.textMuted)),
        ],
      );
    }

    if (user.role == Roles.advisor) {
      final students = data.studentsForAdvisor(user);
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SectionTitle('Estudiantes de ${user.university.isEmpty ? "su universidad" : user.university}'),
          if (students.isEmpty)
            const Text('Sin estudiantes registrados todavía.',
                style: TextStyle(fontSize: 13, color: AppColors.textMuted))
          else
            Text('${students.length} estudiante(s).',
                style: const TextStyle(fontSize: 13, color: AppColors.textMuted)),
        ],
      );
    }

    if (user.role == Roles.company) {
      final labs = data.labsForCompany(user.id);
      final lxds = data.lxdsForCompany(user.id);
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SectionTitle('Laboratorios patrocinados'),
          if (labs.isEmpty)
            const Text('Sin laboratorios patrocinados todavía.',
                style: TextStyle(fontSize: 13, color: AppColors.textMuted))
          else
            for (final lab in labs)
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: HoverCard(
                  onTap: () => Navigator.push(
                      context,
                      MaterialPageRoute(
                          settings: RouteSettings(name: '${AppRoutes.labs}/${lab.id}'),
                          builder: (_) => LabDetailView(labId: lab.id))),
                  child: Text(lab.name,
                      style: const TextStyle(
                          fontSize: 13.5, fontWeight: FontWeight.w600, color: AppColors.textPrimary)),
                ),
              ),
          const SizedBox(height: 8),
          Text('${lxds.length} LXD en su equipo.',
              style: const TextStyle(fontSize: 13, color: AppColors.textMuted)),
        ],
      );
    }

    if (user.role == Roles.donor) {
      final students = data.studentsForDonor(user.id);
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SectionTitle('Estudiantes que apoya'),
          if (students.isEmpty)
            const Text('Aún no tiene estudiantes vinculados.',
                style: TextStyle(fontSize: 13, color: AppColors.textMuted))
          else
            for (final s in students)
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: HoverCard(
                  onTap: () => Navigator.push(
                      context,
                      MaterialPageRoute(
                          settings: RouteSettings(name: '${AppRoutes.users}/${s.id}'),
                          builder: (_) => UserDetailView(userId: s.id))),
                  child: Text(s.name,
                      style: const TextStyle(
                          fontSize: 13.5, fontWeight: FontWeight.w600, color: AppColors.textPrimary)),
                ),
              ),
        ],
      );
    }

    return const Text(
        'No hay más información pública para este rol.',
        style: TextStyle(fontSize: 13, color: AppColors.textMuted));
  }
}
