import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../models/models.dart';
import '../../models/progress.dart';
import '../../providers/data_provider.dart';
import '../../services/api_errors.dart';
import '../../utils/app_theme.dart';
import '../../utils/constants.dart';
import '../../widgets/app_header.dart';
import '../../widgets/async_states.dart';
import '../../widgets/common.dart';
import '../student/course_detail_view.dart';
import 'lab_detail_view.dart';

/// Perfil de una persona, de cualquier rol — el destino de `/usuarios/:id`.
///
/// Antes eran dos pantallas: esta y `StudentDetailView`, que esta delegaba.
/// Se unieron porque la separación ya no significa nada: **quién puede ver
/// qué lo decide el servidor**, no el archivo. Un mentor que abre a alguien
/// fuera de su alcance recibe 404 acá, no una pantalla vacía; antes cualquier
/// cuenta con sesión veía el perfil de cualquier otra, porque el navegador
/// tenía la tabla entera de usuarios.
///
/// Los datos de contacto también los decide el servidor: quien administra o
/// acompaña a esa persona recibe correo y teléfono; el resto, una ficha
/// recortada. Acá simplemente no se dibuja lo que no llegó.
class UserDetailView extends StatelessWidget {
  final String userId;
  const UserDetailView({super.key, required this.userId});

  @override
  Widget build(BuildContext context) {
    final data = context.watch<DataProvider>();

    return Scaffold(
      body: Column(
        children: [
          const AppHeader(portalTitle: 'Perfil'),
          Expanded(
            child: data.userById(userId).when(
                  loading: () => const Center(child: BrandLoader()),
                  // Un 404 acá es una persona fuera de su alcance: el servidor
                  // no confirma que exista.
                  error: (e) => ErrorState(e),
                  data: (user) => _Body(user: user),
                ),
          ),
        ],
      ),
    );
  }
}

class _Body extends StatelessWidget {
  final AppUser user;
  const _Body({required this.user});

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 900),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _Header(user: user),
              const SizedBox(height: 20),
              if (Roles.isStudentLike(user.role))
                _StudentBody(user: user)
              else
                _StaffBody(user: user),
            ],
          ),
        ),
      ),
    );
  }
}

class _Header extends StatelessWidget {
  final AppUser user;
  const _Header({required this.user});

  @override
  Widget build(BuildContext context) {
    return HoverCard(
      padding: const EdgeInsets.all(20),
      child: Wrap(
        spacing: 16,
        runSpacing: 12,
        crossAxisAlignment: WrapCrossAlignment.center,
        children: [
          InitialsAvatar(user.name, large: true, radius: 34),
          ConstrainedBox(
            constraints: const BoxConstraints(minWidth: 200, maxWidth: 520),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(user.name,
                    style: const TextStyle(
                        fontSize: 22, fontWeight: FontWeight.w700)),
                const SizedBox(height: 4),
                Wrap(
                  spacing: 8,
                  runSpacing: 6,
                  children: [
                    StatusChip(
                        label: Roles.label(user.role),
                        color: AppColors.gold,
                        icon: Icons.badge_outlined),
                    if (Roles.isStudentLike(user.role))
                      StatusChip(
                          label: StudentType.label(user.studentType),
                          color: AppColors.textSecondary,
                          icon: Icons.school_outlined),
                  ],
                ),
                const SizedBox(height: 8),
                // Solo se dibuja lo que llegó: el servidor recorta el correo y
                // el teléfono para quien no acompaña a esta persona.
                for (final dato in [
                  if (user.email.isNotEmpty) (Icons.mail_outline, user.email),
                  if (user.phone.isNotEmpty) (Icons.phone_outlined, user.phone),
                  if (user.university.isNotEmpty)
                    (Icons.account_balance_outlined, user.university),
                  if (user.career.isNotEmpty)
                    (Icons.menu_book_outlined, user.career),
                  if (user.city.isNotEmpty)
                    (Icons.place_outlined, user.city),
                ])
                  Padding(
                    padding: const EdgeInsets.only(bottom: 3),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(dato.$1, size: 14, color: AppColors.textMuted),
                        const SizedBox(width: 6),
                        Flexible(
                          child: Text(dato.$2,
                              style: const TextStyle(
                                  fontSize: 13,
                                  color: AppColors.textSecondary),
                              overflow: TextOverflow.ellipsis),
                        ),
                      ],
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Equipo, laboratorios, cursos y certificados de un estudiante.
class _StudentBody extends StatelessWidget {
  final AppUser user;
  const _StudentBody({required this.user});

  @override
  Widget build(BuildContext context) {
    final data = context.watch<DataProvider>();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (user.team != null) ...[
          const SectionTitle('Equipo y proyecto'),
          HoverCard(
            child: Row(
              children: [
                const Icon(Icons.groups_outlined, color: AppColors.gold),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(user.team!.projectName,
                          style:
                              const TextStyle(fontWeight: FontWeight.w700)),
                      Text(
                        '${user.team!.groupName} · '
                        '${ProjectMemberRole.label(user.team!.roleInProject)}',
                        style: const TextStyle(
                            fontSize: 12.5, color: AppColors.textMuted),
                      ),
                    ],
                  ),
                ),
                StatusChip(
                    label: user.team!.stageLabel,
                    color: AppColors.gold,
                    icon: Icons.timeline_outlined),
              ],
            ),
          ),
        ],
        const SectionTitle('Avance en la Ruta de Impacto'),
        // El avance de OTRA persona sale de su propio endpoint: el servidor
        // comprueba que quien mira pueda verlo. Un estudiante que intente
        // leer el de otro recibe 403.
        _RutaProgress(studentId: user.id),
        const SectionTitle('Certificados'),
        data.certificates.when(
          loading: () => const CardListSkeleton(count: 1, height: 56),
          error: (e) => ErrorBanner(e),
          data: (certs) {
            final suyos =
                certs.where((c) => c.studentId == user.id).toList();
            if (suyos.isEmpty) {
              return const Text('Todavía sin certificados.',
                  style:
                      TextStyle(fontSize: 13, color: AppColors.textMuted));
            }
            return Column(
              children: [
                for (final c in suyos)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: HoverCard(
                      child: Row(
                        children: [
                          const Icon(Icons.workspace_premium_outlined,
                              color: AppColors.gold, size: 20),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Text(c.laboratoryName,
                                style: const TextStyle(fontSize: 13.5)),
                          ),
                          Text('${c.hours} h',
                              style: const TextStyle(
                                  fontSize: 12, color: AppColors.textMuted)),
                        ],
                      ),
                    ),
                  ),
              ],
            );
          },
        ),
      ],
    );
  }
}

class _RutaProgress extends StatelessWidget {
  final String studentId;
  const _RutaProgress({required this.studentId});

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<RutaProgress>(
      // Es un `Future` y no un getter del provider a propósito: el avance de
      // otra persona se pide una vez al abrir su perfil, no se cachea por id
      // como el propio.
      future: context.read<DataProvider>().rutaProgressOf(studentId),
      builder: (context, snapshot) {
        final error = snapshot.error;
        if (error != null) {
          // Un 403 acá es la respuesta correcta, no una falla: el avance de
          // otra persona lo autoriza el servidor, no esta pantalla.
          return ErrorBanner(error is ApiException
              ? error
              : const ServerError(500));
        }
        final progress = snapshot.data;
        if (progress == null) {
          return const CardListSkeleton(count: 2, height: 64);
        }
        if (progress.laboratories.isEmpty) {
          return const Text('Sin laboratorios asignados.',
              style: TextStyle(fontSize: 13, color: AppColors.textMuted));
        }
        return Column(
          children: [
            for (final lab in progress.laboratories)
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: HoverCard(
                  onTap: () => Navigator.push(
                    context,
                    MaterialPageRoute(
                      settings: RouteSettings(
                          name: '${AppRoutes.labs}/${lab.laboratoryId}'),
                      builder: (_) =>
                          LabDetailView(labId: lab.laboratoryId),
                    ),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          const Icon(Icons.science_outlined,
                              color: AppColors.gold, size: 18),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(lab.laboratoryName,
                                style: const TextStyle(
                                    fontWeight: FontWeight.w600,
                                    fontSize: 13.5)),
                          ),
                          Text('${(lab.ratio * 100).round()}%',
                              style: const TextStyle(
                                  fontSize: 12, color: AppColors.gold)),
                        ],
                      ),
                      const SizedBox(height: 6),
                      ThinProgressBar(value: lab.ratio),
                    ],
                  ),
                ),
              ),
          ],
        );
      },
    );
  }
}

/// Resumen de LXD, Mentor, Asesor, Empresa o Donante.
class _StaffBody extends StatelessWidget {
  final AppUser user;
  const _StaffBody({required this.user});

  @override
  Widget build(BuildContext context) {
    final data = context.watch<DataProvider>();

    return switch (user.role) {
      Roles.lxd => _LxdBody(user: user),
      Roles.mentor => _MentorBody(user: user),
      Roles.company => _SimpleBody(
          titulo: 'Empresa',
          lineas: [
            if (user.companyName.isNotEmpty) user.companyName,
            'Sus LXD y mentores aparecen en su propio portal.',
          ],
        ),
      Roles.donor => _SimpleBody(
          titulo: 'Donante',
          lineas: [
            if ((user.impactCode ?? '').isNotEmpty)
              'Código de impacto: ${user.impactCode}',
            'Sus estudiantes y evidencias aparecen en su propio portal.',
          ],
        ),
      Roles.advisor => _SimpleBody(
          titulo: 'Asesor académico',
          lineas: [
            if (user.university.isNotEmpty)
              'Acompaña a los equipos de ${user.university}.',
          ],
        ),
      _ => data.courses.when(
          loading: () => const CardListSkeleton(count: 1, height: 56),
          error: (e) => ErrorBanner(e),
          data: (_) => const SizedBox.shrink(),
        ),
    };
  }
}

class _SimpleBody extends StatelessWidget {
  final String titulo;
  final List<String> lineas;

  const _SimpleBody({required this.titulo, required this.lineas});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SectionTitle(titulo),
        for (final l in lineas)
          Padding(
            padding: const EdgeInsets.only(bottom: 4),
            child: Text(l,
                style: const TextStyle(
                    fontSize: 13, color: AppColors.textSecondary)),
          ),
      ],
    );
  }
}

class _LxdBody extends StatelessWidget {
  final AppUser user;
  const _LxdBody({required this.user});

  @override
  Widget build(BuildContext context) {
    final data = context.watch<DataProvider>();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SectionTitle('Cursos creados'),
        data.courses.when(
          loading: () => const CardListSkeleton(count: 2, height: 56),
          error: (e) => ErrorBanner(e),
          data: (courses) {
            final suyos =
                courses.where((c) => c.creatorId == user.id).toList();
            if (suyos.isEmpty) {
              return const Text('Aún no ha creado ningún curso.',
                  style:
                      TextStyle(fontSize: 13, color: AppColors.textMuted));
            }
            return Column(
              children: [
                for (final c in suyos)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: HoverCard(
                      onTap: () => Navigator.push(
                        context,
                        MaterialPageRoute(
                          settings: RouteSettings(
                              name: '${AppRoutes.courses}/${c.id}'),
                          builder: (_) => CourseDetailView(courseId: c.id),
                        ),
                      ),
                      child: Row(
                        children: [
                          Expanded(
                            child: Text(c.name,
                                style: const TextStyle(
                                    fontSize: 13.5,
                                    fontWeight: FontWeight.w600),
                                overflow: TextOverflow.ellipsis),
                          ),
                          StatusChip(
                              label: c.statusLabel,
                              color: c.isPublished
                                  ? AppColors.statusGood
                                  : AppColors.gold,
                              icon: Icons.circle_outlined),
                        ],
                      ),
                    ),
                  ),
              ],
            );
          },
        ),
        const SizedBox(height: 10),
        Text(
          'Califica en: ${[
            if (user.canGradeOpenLearning) 'Open Learning',
            if (user.canGradeEnactus) 'eduXaction',
          ].join(', ').ifEmpty('ningún contexto')}',
          style: const TextStyle(fontSize: 13, color: AppColors.textMuted),
        ),
      ],
    );
  }
}

class _MentorBody extends StatelessWidget {
  final AppUser user;
  const _MentorBody({required this.user});

  @override
  Widget build(BuildContext context) {
    final data = context.watch<DataProvider>();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SectionTitle('Laboratorios que acompaña'),
        data.laboratories.when(
          loading: () => const CardListSkeleton(count: 2, height: 56),
          error: (e) => ErrorBanner(e),
          data: (labs) {
            // Los mentores vienen resueltos DENTRO del laboratorio: el
            // servidor los trae con el detalle en vez de obligar a listar
            // todos los usuarios y cruzarlos acá.
            final suyos = labs
                .where((l) => l.mentors.any((m) => m.id == user.id))
                .toList();
            if (suyos.isEmpty) {
              return const Text('Todavía sin laboratorio asignado.',
                  style:
                      TextStyle(fontSize: 13, color: AppColors.textMuted));
            }
            return Column(
              children: [
                for (final lab in suyos)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: HoverCard(
                      onTap: () => Navigator.push(
                        context,
                        MaterialPageRoute(
                          settings: RouteSettings(
                              name: '${AppRoutes.labs}/${lab.id}'),
                          builder: (_) => LabDetailView(labId: lab.id),
                        ),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.science_outlined,
                              color: AppColors.gold, size: 18),
                          const SizedBox(width: 10),
                          Expanded(child: Text(lab.name)),
                          Text('${lab.studentsAssigned} estudiantes',
                              style: const TextStyle(
                                  fontSize: 12, color: AppColors.textMuted)),
                        ],
                      ),
                    ),
                  ),
              ],
            );
          },
        ),
        if (user.reviewsCount != null) ...[
          const SizedBox(height: 10),
          Text('${user.reviewsCount} entregas revisadas.',
              style: const TextStyle(
                  fontSize: 13, color: AppColors.textMuted)),
        ],
      ],
    );
  }
}

extension _IfEmpty on String {
  String ifEmpty(String fallback) => isEmpty ? fallback : this;
}
