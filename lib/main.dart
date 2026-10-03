import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import 'providers/auth_provider.dart';
import 'providers/data_provider.dart';
import 'services/api_service.dart';
import 'utils/url_strategy.dart';
import 'utils/app_theme.dart';
import 'utils/constants.dart';
import 'utils/orientacion.dart';
import 'views/auth/login_view.dart';
import 'views/admin/admin_portal.dart';
import 'views/advisor/advisor_portal.dart';
import 'views/company/company_portal.dart';
import 'views/donor/donor_portal.dart';
import 'views/mentor/mentor_portal.dart';
import 'views/lxd/lxd_portal.dart';
import 'views/public/landing_view.dart';
import 'views/public/not_found_view.dart';
import 'views/public/sin_conexion_view.dart';
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
  // Toda fecha sin idioma explícito sale en español. Había una veintena de
  // `DateFormat('d MMM yyyy')` sin `'es'` que mostraban "30 Sep 2026" y
  // "10:00 AM" en medio de una interfaz en español.
  Intl.defaultLocale = 'es';

  // Una versión de tienda móvil compilada sin `--dart-define=API_BASE_URL`
  // apuntaría a `http://localhost:3000`: abriría vacía, sin explicar por qué,
  // y así llegaría al revisor de la tienda. Mejor detenerse con un mensaje.
  // La web no entra acá: el CI siempre la compila con su URL https.
  if (kReleaseMode && !kIsWeb && !ApiService.baseUrl.startsWith('https://')) {
    runApp(const _ConfiguracionIncompleta());
    return;
  }

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
  late final AppLifecycleListener _ciclo;
  DateTime? _ocultaDesde;

  @override
  void initState() {
    super.initState();
    _ciclo = AppLifecycleListener(
      onHide: () => _ocultaDesde = DateTime.now(),
      onShow: _alVolver,
    );
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
      // Vertical en teléfonos, libre en tablets. Recién después del primer
      // frame: antes, en Android el tamaño de la pantalla puede ser cero.
      fijarOrientacionDeLaApp();
    });
  }

  @override
  void dispose() {
    _ciclo.dispose();
    super.dispose();
  }

  /// La app vuelve a primer plano (o la pestaña vuelve a verse, en la web).
  ///
  /// - Si al abrir no hubo conexión, reintenta sola: la persona no tiene que
  ///   adivinar que debe tocar "Reintentar" cuando vuelve la señal.
  /// - Si estuvo un rato largo afuera, lo que ve puede estar viejo (notas,
  ///   eventos, el foro). Un cambio rápido de app no recarga nada.
  void _alVolver() {
    final auth = widget.auth;
    final desde = _ocultaDesde;
    _ocultaDesde = null;
    if (auth.isRestoring) return;
    if (auth.isOffline) {
      auth.restoreSession();
      return;
    }
    if (auth.isLoggedIn &&
        desde != null &&
        DateTime.now().difference(desde) > const Duration(minutes: 5)) {
      widget.data.refreshAll();
      auth.refresh();
    }
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
        // Los textos propios de Material (selector de fecha y hora, menú de
        // copiar y pegar, "Atrás") en español de Colombia.
        locale: const Locale('es', 'CO'),
        supportedLocales: const [Locale('es', 'CO'), Locale('es')],
        localizationsDelegates: GlobalMaterialLocalizations.delegates,
        // Hora y batería en claro sobre el gris de la marca en todas las
        // pantallas (el encabezado y el video también lo fijan). Sin esto,
        // en un iPhone en modo claro salían oscuras sobre fondo oscuro.
        builder: (context, child) => AnnotatedRegion<SystemUiOverlayStyle>(
          value: SystemUiOverlayStyle.light,
          child: child ?? const SizedBox.shrink(),
        ),
        home: initialRoute == null ? const _Bootstrap() : null,
        initialRoute: initialRoute,
        onGenerateRoute: _generateRoute,
      ),
    );
  }

}

/// Lo que ve una versión de tienda compilada sin la URL https de la API.
///
/// Nunca debería llegar a nadie: `tool/build_movil.sh` siempre pasa la URL.
/// Existe para que el error se note en la primera prueba y no en la revisión.
class _ConfiguracionIncompleta extends StatelessWidget {
  const _ConfiguracionIncompleta();

  @override
  Widget build(BuildContext context) {
    return const MaterialApp(
      debugShowCheckedModeBanner: false,
      home: Scaffold(
        body: SafeArea(
          child: Padding(
            padding: EdgeInsets.all(24),
            child: Center(
              child: Text(
                'Esta compilación no tiene configurada la dirección del '
                'servidor. Compílela con tool/build_movil.sh.',
                textAlign: TextAlign.center,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Qué muestra la raíz "/": en la web, la portada; en la app instalada, el
/// ingreso o el portal de quien tenga sesión.
///
/// Es una variable y no `kIsWeb` a secas solo para que las pruebas —que corren
/// fuera del navegador, como la app— puedan seguir probando la portada, que
/// sigue existiendo en eduxaction.com.
@visibleForTesting
bool raizEsPortada = kIsWeb;

/// Todas las rutas con nombre de la app, en un solo lugar.
///
/// Es una función suelta y no un método de `EnactusApp` porque la usan dos
/// navegadores distintos: el de la app y el que arma `_Bootstrap` al entrar
/// con sesión activa.
Route<dynamic> _generateRoute(RouteSettings settings) {
  Widget page = const NotFoundView();
  switch (settings.name) {
    case AppRoutes.landing:
      // En la app, "/" —el logo, cerrar sesión, "Volver al inicio"— lleva al
      // ingreso o al portal de quien tenga sesión, nunca a la portada de
      // marketing de la web.
      page = raizEsPortada ? const LandingView() : const _Bootstrap();
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
  final _portal = GlobalKey<NavigatorState>();

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();

    if (auth.isRestoring) {
      return const Scaffold(
        backgroundColor: AppColors.background,
        body: Center(child: BrandLoader(message: 'Abriendo su sesión…')),
      );
    }

    // Hay sesión guardada pero no se pudo comprobar: no es "sin sesión".
    if (auth.isOffline) return const SinConexionView();

    final user = auth.currentUser;
    // En el teléfono se entra directo al ingreso: la portada es el sitio de
    // presentación de la web, y abrir la app en una página de marketing es lo
    // que App Store describe como "un sitio web empaquetado" (guía 4.2).
    if (user == null) {
      return raizEsPortada ? const LandingView() : const LoginView();
    }

    // Con sesión activa, directo a su portal, en un Navigator propio.
    //
    // El botón atrás de Android le habla al Navigator RAÍZ, que acá tiene una
    // sola ruta: sin [NavigatorPopHandler], "atrás" con un detalle abierto
    // —o con el menú abierto— cerraba la app en vez de volver. El manejador
    // le pasa el gesto a este Navigator. En la web no se intercepta: el botón
    // del navegador sigue como siempre.
    return NavigatorPopHandler<Object?>(
      enabled: !kIsWeb,
      onPopWithResult: (_) => _portal.currentState?.maybePop(),
      child: Navigator(
        key: _portal,
        onGenerateRoute: (settings) => _generateRoute(
          settings.name == null || settings.name == '/'
              ? RouteSettings(name: AppRoutes.forRole(user.role))
              : settings,
        ),
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
    if (auth.isOffline) return const SinConexionView();
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
    if (auth.isOffline) return const SinConexionView();
    if (!auth.isLoggedIn) return const LoginView();
    return child;
  }
}
