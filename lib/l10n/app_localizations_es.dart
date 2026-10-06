// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Spanish Castilian (`es`).
class AppLocalizationsEs extends AppLocalizations {
  AppLocalizationsEs([String locale = 'es']) : super(locale);

  @override
  String get idiomaEspanol => 'Español';

  @override
  String get idiomaIngles => 'English';

  @override
  String get idiomaSelector => 'Idioma';

  @override
  String get arranqueSinServidor =>
      'Esta compilación no tiene configurada la dirección del servidor. Compílela con tool/build_movil.sh.';

  @override
  String get arranqueAbriendoSesion => 'Abriendo su sesión…';

  @override
  String get ingresoCredencialesIncorrectas =>
      'Correo o contraseña incorrectos.';

  @override
  String get ingresoBienvenida => 'Bienvenido de nuevo';

  @override
  String get ingresoSubtitulo =>
      'Ingrese con la cuenta creada por su administrador';

  @override
  String get ingresoCorreo => 'Correo electrónico';

  @override
  String get ingresoContrasena => 'Contraseña';

  @override
  String get ingresoMostrarContrasena => 'Mostrar contraseña';

  @override
  String get ingresoOcultarContrasena => 'Ocultar contraseña';

  @override
  String get ingresoIngresar => 'Ingresar';

  @override
  String get ingresoVolverAlInicio => '← Volver al inicio';

  @override
  String get comunPoliticaPrivacidad => 'Política de privacidad';

  @override
  String get noEncontradaTitulo => 'Página no encontrada';

  @override
  String get noEncontradaTexto => 'La página que busca no existe o fue movida.';

  @override
  String get comunVolverAlInicio => 'Volver al inicio';

  @override
  String get sinConexionTitulo => 'Sin conexión';

  @override
  String get sinConexionTexto =>
      'No pudimos comunicarnos con eduXaction para abrir su sesión. Revise su conexión a internet e intente de nuevo: su sesión sigue guardada.';

  @override
  String get sinConexionComprobando => 'Comprobando su sesión…';

  @override
  String get comunReintentar => 'Reintentar';

  @override
  String get sinConexionOtraCuenta => 'Entrar con otra cuenta';

  @override
  String get pendienteTitulo => 'Disponible próximamente';

  @override
  String get pendienteTexto =>
      'Estamos conectando este portal con el nuevo sistema. Preferimos tenerlo bien hecho antes que a medias: mientras tanto, no verá información que pueda estar desactualizada.';

  @override
  String pendienteSesionActiva(Object nombre, Object rol) {
    return 'Su sesión sigue activa como $nombre · $rol';
  }

  @override
  String get comunIrAlInicio => 'Ir al inicio';

  @override
  String get comunCerrarSesion => 'Cerrar sesión';
}
