import 'package:flutter/material.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:provider/provider.dart';

import 'providers/auth_provider.dart';
import 'providers/data_provider.dart';
import 'services/api_service.dart';
import 'utils/url_strategy.dart';
import 'utils/app_theme.dart';
import 'utils/constants.dart';
import 'views/auth/change_password_view.dart';
import 'views/auth/login_view.dart';
import 'views/admin/admin_portal.dart';
import 'views/advisor/advisor_portal.dart';
import 'views/company/company_portal.dart';
import 'views/donor/donor_portal.dart';
import 'views/mentor/mentor_portal.dart';
import 'views/lxd/lxd_portal.dart';
import 'views/public/landing_view.dart';
import 'views/public/not_found_view.dart';
import 'views/shared/lab_detail_view.dart';
import 'views/shared/user_detail_view.dart';
import 'views/shared/projects_directory_view.dart' show ProjectDetailView;
import 'views/student/course_detail_view.dart';
import 'views/student/student_portal.dart';
import 'widgets/async_states.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Rutas de verdad en la barra de direcciones (`/login`, no `/#/login`).
  // Va ANTES de `runApp`: después ya se leyó la ruta inicial y el cambio no
  // llega a tiempo. Ver `utils/url_strategy.dart`.
  configurarRutas();

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

class EnactusApp extends StatefulWidget {
  final ApiService api;
  final DataProvider data;
  final AuthProvider auth;

  /// Entrar directo a una ruta sin pasar por la pantalla de arranque. Lo usan
  /// las pruebas, y Flutter web lo llena solo cuando alguien abre la app en
  /// una URL profunda (`/admin`, un enlace compartido).
  final String? initialRoute;

  const EnactusApp({
    super.key,
    required this.api,
    required this.data,
    required this.auth,
    this.initialRoute,
  });

  @override
  State<EnactusApp> createState() => _EnactusAppState();
}

class _EnactusAppState extends State<EnactusApp> {
  @override
  void initState() {
    super.initState();
    // La sesión se recupera acá, en la raíz, y NO en la pantalla de arranque.
    //
    // Con `initialRoute` puesto —una URL profunda— `_Bootstrap` nunca se
    // monta: si el `restoreSession` viviera ahí, cualquiera que abriera un
    // enlace directo a su portal se quedaría mirando la ruedita para siempre,
    // porque el guardia de rol espera a que `isRestoring` sea falso y nadie
    // lo cambiaría nunca.
    //
    // Tras el primer frame: `restoreSession` notifica, y notificar durante
    // `initState` dispara el error de "setState during build".
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) widget.auth.restoreSession();
    });
  }

  @override
  Widget build(BuildContext context) {
    final api = widget.api;
    final data = widget.data;
    final auth = widget.auth;
    final initialRoute = widget.initialRoute;

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
        onGenerateRoute: _generateRoute,
      ),
    );
  }

}

/// Todas las rutas con nombre de la app, en un solo lugar.
///
/// Es una función suelta y no un método de `EnactusApp` porque la usan dos
/// navegadores distintos: el de la app y el que arma `_Bootstrap` al entrar
/// con sesión activa.
Route<dynamic> _generateRoute(RouteSettings settings) {
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
      page = const _RoleGuard(role: Roles.lxd, child: LxdPortal());
    case AppRoutes.mentor:
      page = const _RoleGuard(role: Roles.mentor, child: MentorPortal());
    case AppRoutes.admin:
      page = const _RoleGuard(role: Roles.admin, child: AdminPortal());
    case AppRoutes.superAdmin:
      page = const _RoleGuard(
          role: Roles.superAdmin, child: AdminPortal(isSuperAdmin: true));
    case AppRoutes.advisor:
      page = const _RoleGuard(role: Roles.advisor, child: AdvisorPortal());
    case AppRoutes.company:
      page = const _RoleGuard(role: Roles.company, child: CompanyPortal());
    case AppRoutes.donor:
      page = const _RoleGuard(role: Roles.donor, child: DonorPortal());
    case String name when name.startsWith('${AppRoutes.projects}/'):
      page = _AuthGuard(
          child: ProjectDetailView(
              projectId: name.substring('${AppRoutes.projects}/'.length)));
    case String name when name.startsWith('${AppRoutes.courses}/'):
      page = _AuthGuard(
          child: CourseDetailView(
              courseId: name.substring('${AppRoutes.courses}/'.length)));
    case String name when name.startsWith('${AppRoutes.users}/'):
      page = _AuthGuard(
          child: UserDetailView(
              userId: name.substring('${AppRoutes.users}/'.length)));
    case String name when name.startsWith('${AppRoutes.labs}/'):
      page = _AuthGuard(
          child: LabDetailView(
              labId: name.substring('${AppRoutes.labs}/'.length)));
  }
  return MaterialPageRoute(builder: (_) => page, settings: settings);
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

    // Contraseña pendiente de cambio: no hay portal al que ir. El servidor
    // responde 403 a todo lo demás, así que mandarla al portal sería
    // mostrarle una pantalla que no puede cargar nada.
    if (auth.mustChangePassword) return const ChangePasswordView();

    // Con sesión activa, directo a su portal.
    return Navigator(
      onGenerateRoute: (settings) => _generateRoute(
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
    // Ver la nota de `_Bootstrap`: con el cambio pendiente el portal no puede
    // cargar nada.
    if (auth.mustChangePassword) return const ChangePasswordView();
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
    if (auth.mustChangePassword) return const ChangePasswordView();
    return child;
  }
}
