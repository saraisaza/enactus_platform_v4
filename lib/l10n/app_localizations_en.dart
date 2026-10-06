// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for English (`en`).
class AppLocalizationsEn extends AppLocalizations {
  AppLocalizationsEn([String locale = 'en']) : super(locale);

  @override
  String get idiomaEspanol => 'Español';

  @override
  String get idiomaIngles => 'English';

  @override
  String get idiomaSelector => 'Language';

  @override
  String get arranqueSinServidor =>
      'This build has no server address configured. Build it with tool/build_movil.sh.';

  @override
  String get arranqueAbriendoSesion => 'Opening your session…';

  @override
  String get ingresoCredencialesIncorrectas => 'Incorrect email or password.';

  @override
  String get ingresoBienvenida => 'Welcome back';

  @override
  String get ingresoSubtitulo =>
      'Sign in with the account your administrator created for you';

  @override
  String get ingresoCorreo => 'Email';

  @override
  String get ingresoContrasena => 'Password';

  @override
  String get ingresoMostrarContrasena => 'Show password';

  @override
  String get ingresoOcultarContrasena => 'Hide password';

  @override
  String get ingresoIngresar => 'Sign in';

  @override
  String get ingresoVolverAlInicio => '← Back to home';

  @override
  String get comunPoliticaPrivacidad => 'Privacy policy';

  @override
  String get noEncontradaTitulo => 'Page not found';

  @override
  String get noEncontradaTexto =>
      'The page you are looking for does not exist or has been moved.';

  @override
  String get comunVolverAlInicio => 'Back to home';

  @override
  String get sinConexionTitulo => 'No connection';

  @override
  String get sinConexionTexto =>
      'We couldn\'t reach eduXaction to open your session. Check your internet connection and try again: your session is still saved.';

  @override
  String get sinConexionComprobando => 'Checking your session…';

  @override
  String get comunReintentar => 'Try again';

  @override
  String get sinConexionOtraCuenta => 'Sign in with another account';

  @override
  String get pendienteTitulo => 'Coming soon';

  @override
  String get pendienteTexto =>
      'We are connecting this portal to the new system. We would rather get it right than do it halfway: in the meantime, you will not see information that might be out of date.';

  @override
  String pendienteSesionActiva(Object nombre, Object rol) {
    return 'Your session is still active as $nombre · $rol';
  }

  @override
  String get comunIrAlInicio => 'Go to home';

  @override
  String get comunCerrarSesion => 'Sign out';
}
