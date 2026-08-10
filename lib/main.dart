import 'dart:async';

import 'package:flutter/material.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:provider/provider.dart';

import 'providers/auth_provider.dart';
import 'providers/data_provider.dart';
import 'services/db_service.dart';
import 'services/migration_service.dart';
import 'services/seed_service.dart';
import 'utils/app_theme.dart';
import 'utils/constants.dart';
import 'views/admin/admin_portal.dart';
import 'views/advisor/advisor_portal.dart';
import 'views/auth/login_view.dart';
import 'views/company/company_portal.dart';
import 'views/donor/donor_portal.dart';
import 'views/lxd/lxd_portal.dart';
import 'views/mentor/mentor_portal.dart';
import 'views/public/landing_view.dart';
import 'views/public/not_found_view.dart';
import 'views/student/student_portal.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await initializeDateFormatting('es');
  await DbService.init();
  final db = DbService();
  // Migra datos de versiones anteriores (p. ej. rol Mentor→LXD) antes de
  // sembrar o leer cualquier dato.
  await MigrationService(db).runAll();
  await SeedService(db).seedIfEmpty();
  final data = DataProvider(db);
  final auth = AuthProvider(data);
  // Restaura la sesión guardada: al recargar la página el usuario vuelve
  // directo a su portal (hasta que la sesión expire o cierre sesión).
  final restored = auth.tryRestoreSession();
  // No hay tareas programadas en un servidor (todo vive en Hive local):
  // se revisan los deadlines de fase cada vez que arranca la app. No se
  // espera a que termine para no retrasar el primer render.
  unawaited(data.checkPhaseDeadlineAlerts());
  runApp(EnactusApp(
    data: data,
    auth: auth,
    initialRoute: restored == null
        ? AppRoutes.landing
        : AppRoutes.forRole(restored.role),
  ));
}

class EnactusApp extends StatelessWidget {
  final DataProvider data;
  final AuthProvider auth;
  final String initialRoute;
  const EnactusApp(
      {super.key,
      required this.data,
      required this.auth,
      required this.initialRoute});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider.value(value: data),
        ChangeNotifierProvider.value(value: auth),
      ],
      child: MaterialApp(
        title: 'Enactus Colombia',
        debugShowCheckedModeBanner: false,
        theme: buildAppTheme(),
        initialRoute: initialRoute,
        onGenerateRoute: _onGenerateRoute,
      ),
    );
  }

  Route<dynamic> _onGenerateRoute(RouteSettings settings) {
    // Ruta desconocida → página 404 con el logo institucional
    Widget page = const NotFoundView();
    switch (settings.name) {
      case AppRoutes.landing:
        page = const LandingView();
      case AppRoutes.login:
        page = const LoginView();
      case AppRoutes.student:
        page = const _RoleGuard(role: Roles.student, child: StudentPortal());
      case AppRoutes.alumni:
        // Mismo portal que un estudiante, sin ninguna diferencia de
        // acceso: ver Roles.isStudentLike.
        page = const _RoleGuard(role: Roles.alumni, child: StudentPortal());
      // Detalle de laboratorio con URL real (para que el botón atrás del
      // navegador funcione): mismo StudentPortal, con la pestaña
      // "Laboratorios" resaltada y su contenido reemplazado.
      case String name when name.startsWith('${AppRoutes.student}/lab/'):
        page = _RoleGuard(
            role: Roles.student,
            child: StudentPortal(
                openLabId: name.substring('${AppRoutes.student}/lab/'.length)));
      case String name when name.startsWith('${AppRoutes.alumni}/lab/'):
        page = _RoleGuard(
            role: Roles.alumni,
            child: StudentPortal(
                openLabId: name.substring('${AppRoutes.alumni}/lab/'.length)));
      // "Todos los laboratorios" desde el detalle: no se puede confiar en
      // Navigator.canPop (Flutter web mantiene una entrada de historial
      // "de más" incluso en la ruta inicial, así que canPop puede dar true
      // sin que haya nada real que hacer pop) — por eso el botón siempre
      // navega aquí de forma explícita en vez de intentar pop().
      case '${AppRoutes.student}/laboratorios':
        page = const _RoleGuard(
            role: Roles.student, child: StudentPortal(initialTabLabel: 'Laboratorios'));
      case '${AppRoutes.alumni}/laboratorios':
        page = const _RoleGuard(
            role: Roles.alumni, child: StudentPortal(initialTabLabel: 'Laboratorios'));
      case AppRoutes.lxd:
        page = const _RoleGuard(role: Roles.lxd, child: LxdPortal());
      case AppRoutes.mentor:
        page = const _RoleGuard(role: Roles.mentor, child: MentorPortal());
      case AppRoutes.admin:
        page = const _RoleGuard(role: Roles.admin, child: AdminPortal());
      case AppRoutes.superAdmin:
        page = const _RoleGuard(
            role: Roles.superAdmin,
            child: AdminPortal(isSuperAdmin: true));
      case AppRoutes.advisor:
        page = const _RoleGuard(role: Roles.advisor, child: AdvisorPortal());
      case AppRoutes.company:
        page = const _RoleGuard(role: Roles.company, child: CompanyPortal());
      case AppRoutes.donor:
        page = const _RoleGuard(role: Roles.donor, child: DonorPortal());
    }
    return MaterialPageRoute(builder: (_) => page, settings: settings);
  }
}

/// Protege las rutas de los portales: exige sesión activa con el rol correcto.
class _RoleGuard extends StatelessWidget {
  final String role;
  final Widget child;
  const _RoleGuard({required this.role, required this.child});

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();
    // isLoggedIn (no solo currentUser != null) es la señal correcta: tras
    // logout, currentUser se queda con el último usuario a propósito (ver
    // AuthProvider.logout) para no crashear pantallas que se están
    // cerrando, así que aquí hay que exigir isLoggedIn explícitamente.
    if (!auth.isLoggedIn || auth.currentUser!.role != role) {
      return const LoginView();
    }
    return child;
  }
}
