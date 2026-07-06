import 'package:flutter/material.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:provider/provider.dart';

import 'providers/auth_provider.dart';
import 'providers/data_provider.dart';
import 'services/db_service.dart';
import 'services/seed_service.dart';
import 'utils/app_theme.dart';
import 'utils/constants.dart';
import 'views/admin/admin_portal.dart';
import 'views/advisor/advisor_portal.dart';
import 'views/auth/login_view.dart';
import 'views/company/company_portal.dart';
import 'views/donor/donor_portal.dart';
import 'views/mentor/mentor_portal.dart';
import 'views/public/landing_view.dart';
import 'views/public/not_found_view.dart';
import 'views/student/student_portal.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await initializeDateFormatting('es');
  await DbService.init();
  final db = DbService();
  await SeedService(db).seedIfEmpty();
  final data = DataProvider(db);
  final auth = AuthProvider(data);
  // Restaura la sesión guardada: al recargar la página el usuario vuelve
  // directo a su portal (hasta que la sesión expire o cierre sesión).
  final restored = auth.tryRestoreSession();
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
    final user = context.watch<AuthProvider>().currentUser;
    if (user == null || user.role != role) {
      return const LoginView();
    }
    return child;
  }
}
