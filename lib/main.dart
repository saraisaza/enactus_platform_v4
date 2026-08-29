import 'package:flutter/material.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:provider/provider.dart';

import 'providers/auth_provider.dart';
import 'providers/data_provider.dart';
import 'services/api_service.dart';
import 'utils/app_theme.dart';
import 'utils/constants.dart';
import 'views/auth/login_view.dart';
import 'views/public/landing_view.dart';
import 'views/public/not_found_view.dart';
import 'views/public/pending_portal_view.dart';
import 'views/shared/lab_detail_view.dart';
import 'views/shared/projects_directory_view.dart' show ProjectDetailView;
import 'views/student/course_detail_view.dart';
import 'views/student/student_portal.dart';
import 'widgets/async_states.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await initializeDateFormatting('es');

  // Ya no hay base local que abrir, ni migraciones, ni seed: los datos viven
  // en la API. El arranque es inmediato y la sesión se restaura en segundo
  // plano (ver `_Bootstrap`), para no dejar la pantalla en blanco mientras
  // se comprueba el token guardado.
  final api = ApiService();
  final data = DataProvider(api);
  final auth = AuthProvider(api, data);

  runApp(EnactusApp(api: api, data: data, auth: auth));
}

class EnactusApp extends StatelessWidget {
  final ApiService api;
  final DataProvider data;
  final AuthProvider auth;

  /// Solo para pruebas: entrar directo a una ruta sin pasar por el arranque.
  final String? initialRoute;

  const EnactusApp({
    super.key,
    required this.api,
    required this.data,
    required this.auth,
    this.initialRoute,
  });

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        Provider<ApiService>.value(value: api),
        ChangeNotifierProvider.value(value: data),
        ChangeNotifierProvider.value(value: auth),
      ],
      child: MaterialApp(
        title: 'eduXaction Colombia',
        debugShowCheckedModeBanner: false,
        theme: buildAppTheme(),
        home: initialRoute == null ? const _Bootstrap() : null,
        initialRoute: initialRoute,
        onGenerateRoute: _onGenerateRoute,
      ),
    );
  }

  static Route<dynamic> _onGenerateRoute(RouteSettings settings) {
    Widget page = const NotFoundView();
    switch (settings.name) {
      case AppRoutes.landing:
        page = const LandingView();
      case AppRoutes.login:
        page = const LoginView();
      case AppRoutes.student:
        page = const _RoleGuard(role: Roles.student, child: StudentPortal());
      case AppRoutes.alumni:
        page = const _RoleGuard(role: Roles.alumni, child: StudentPortal());
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
      case '${AppRoutes.student}/laboratorios':
        page = const _RoleGuard(
            role: Roles.student,
            child: StudentPortal(initialTabLabel: 'Laboratorios'));
      case '${AppRoutes.alumni}/laboratorios':
        page = const _RoleGuard(
            role: Roles.alumni,
            child: StudentPortal(initialTabLabel: 'Laboratorios'));
      case AppRoutes.lxd:
        page = const _RoleGuard(
            role: Roles.lxd, child: PendingPortalView(portalName: 'Portal LXD'));
      case AppRoutes.mentor:
        page = const _RoleGuard(
            role: Roles.mentor,
            child: PendingPortalView(portalName: 'Portal Mentor'));
      case AppRoutes.admin:
        page = const _RoleGuard(
            role: Roles.admin,
            child: PendingPortalView(portalName: 'Portal Admin'));
      case AppRoutes.superAdmin:
        page = const _RoleGuard(
            role: Roles.superAdmin,
            child: PendingPortalView(portalName: 'Portal Super Admin'));
      case AppRoutes.advisor:
        page = const _RoleGuard(
            role: Roles.advisor,
            child: PendingPortalView(portalName: 'Portal Asesor Académico'));
      case AppRoutes.company:
        page = const _RoleGuard(
            role: Roles.company,
            child: PendingPortalView(portalName: 'Portal Empresa'));
      case AppRoutes.donor:
        page = const _RoleGuard(
            role: Roles.donor,
            child: PendingPortalView(portalName: 'Portal Donante'));
      case String name when name.startsWith('${AppRoutes.projects}/'):
        page = _AuthGuard(
            child: ProjectDetailView(
                projectId: name.substring('${AppRoutes.projects}/'.length)));
      case String name when name.startsWith('${AppRoutes.courses}/'):
        page = _AuthGuard(
            child: CourseDetailView(
                courseId: name.substring('${AppRoutes.courses}/'.length)));
      // `/usuarios/:id` queda pendiente: el perfil de OTRA persona necesita
      // un `GET /users/:id` que la API todavía no expone, y su vista es de
      // personal (Mentor, Asesor, LXD, Admin), no del portal Estudiante.
      case String name when name.startsWith('${AppRoutes.users}/'):
        page = const _AuthGuard(
            child: PendingPortalView(portalName: 'Perfil de usuario'));
      case String name when name.startsWith('${AppRoutes.labs}/'):
        page = _AuthGuard(
            child: LabDetailView(
                labId: name.substring('${AppRoutes.labs}/'.length)));
    }
    return MaterialPageRoute(builder: (_) => page, settings: settings);
  }
}

/// Pantalla de arranque: restaura la sesión guardada y decide a dónde entrar.
///
/// Antes esto se resolvía antes de `runApp`, porque leer Hive era instantáneo.
/// Ahora es una llamada de red, así que hay que mostrar algo mientras tanto —
/// y manejar que falle.
class _Bootstrap extends StatefulWidget {
  const _Bootstrap();

  @override
  State<_Bootstrap> createState() => _BootstrapState();
}

class _BootstrapState extends State<_Bootstrap> {
  @override
  void initState() {
    super.initState();
    // Tras el primer frame: `restoreSession` notifica, y notificar durante
    // `initState` dispara el error de "setState during build".
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) context.read<AuthProvider>().restoreSession();
    });
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();

    if (auth.isRestoring) {
      return const Scaffold(
        backgroundColor: AppColors.background,
        body: Center(child: BrandLoader(message: 'Abriendo tu sesión…')),
      );
    }

    final user = auth.currentUser;
    if (user == null) return const LandingView();

    // Con sesión activa, directo a su portal.
    return Navigator(
      onGenerateRoute: (settings) => EnactusApp._onGenerateRoute(
        settings.name == null || settings.name == '/'
            ? RouteSettings(name: AppRoutes.forRole(user.role))
            : settings,
      ),
    );
  }
}

/// Exige sesión activa con el rol correcto.
///
/// Sigue siendo defensa de interfaz, no seguridad: la de verdad está en el
/// servidor, que responde 403 aunque alguien llame el endpoint a mano.
class _RoleGuard extends StatelessWidget {
  final String role;
  final Widget child;
  const _RoleGuard({required this.role, required this.child});

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();
    if (auth.isRestoring) {
      return const Scaffold(
        backgroundColor: AppColors.background,
        body: Center(child: BrandLoader()),
      );
    }
    final user = auth.currentUser;
    if (user == null || user.role != role) return const LoginView();
    return child;
  }
}

/// Igual que [_RoleGuard] pero sin exigir un rol: para rutas de detalle
/// alcanzables desde varios portales.
class _AuthGuard extends StatelessWidget {
  final Widget child;
  const _AuthGuard({required this.child});

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();
    if (auth.isRestoring) {
      return const Scaffold(
        backgroundColor: AppColors.background,
        body: Center(child: BrandLoader()),
      );
    }
    if (!auth.isLoggedIn) return const LoginView();
    return child;
  }
}
