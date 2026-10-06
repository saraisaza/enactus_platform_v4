import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/intl.dart' as intl;

import 'app_localizations_en.dart';
import 'app_localizations_es.dart';

// ignore_for_file: type=lint

/// Callers can lookup localized strings with an instance of AppLocalizations
/// returned by `AppLocalizations.of(context)`.
///
/// Applications need to include `AppLocalizations.delegate()` in their app's
/// `localizationDelegates` list, and the locales they support in the app's
/// `supportedLocales` list. For example:
///
/// ```dart
/// import 'l10n/app_localizations.dart';
///
/// return MaterialApp(
///   localizationsDelegates: AppLocalizations.localizationsDelegates,
///   supportedLocales: AppLocalizations.supportedLocales,
///   home: MyApplicationHome(),
/// );
/// ```
///
/// ## Update pubspec.yaml
///
/// Please make sure to update your pubspec.yaml to include the following
/// packages:
///
/// ```yaml
/// dependencies:
///   # Internationalization support.
///   flutter_localizations:
///     sdk: flutter
///   intl: any # Use the pinned version from flutter_localizations
///
///   # Rest of dependencies
/// ```
///
/// ## iOS Applications
///
/// iOS applications define key application metadata, including supported
/// locales, in an Info.plist file that is built into the application bundle.
/// To configure the locales supported by your app, you’ll need to edit this
/// file.
///
/// First, open your project’s ios/Runner.xcworkspace Xcode workspace file.
/// Then, in the Project Navigator, open the Info.plist file under the Runner
/// project’s Runner folder.
///
/// Next, select the Information Property List item, select Add Item from the
/// Editor menu, then select Localizations from the pop-up menu.
///
/// Select and expand the newly-created Localizations item then, for each
/// locale your application supports, add a new item and select the locale
/// you wish to add from the pop-up menu in the Value field. This list should
/// be consistent with the languages listed in the AppLocalizations.supportedLocales
/// property.
abstract class AppLocalizations {
  AppLocalizations(String locale)
    : localeName = intl.Intl.canonicalizedLocale(locale.toString());

  final String localeName;

  static AppLocalizations of(BuildContext context) {
    return Localizations.of<AppLocalizations>(context, AppLocalizations)!;
  }

  static const LocalizationsDelegate<AppLocalizations> delegate =
      _AppLocalizationsDelegate();

  /// A list of this localizations delegate along with the default localizations
  /// delegates.
  ///
  /// Returns a list of localizations delegates containing this delegate along with
  /// GlobalMaterialLocalizations.delegate, GlobalCupertinoLocalizations.delegate,
  /// and GlobalWidgetsLocalizations.delegate.
  ///
  /// Additional delegates can be added by appending to this list in
  /// MaterialApp. This list does not have to be used at all if a custom list
  /// of delegates is preferred or required.
  static const List<LocalizationsDelegate<dynamic>> localizationsDelegates =
      <LocalizationsDelegate<dynamic>>[
        delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
      ];

  /// A list of this localizations delegate's supported locales.
  static const List<Locale> supportedLocales = <Locale>[
    Locale('en'),
    Locale('es'),
  ];

  /// Nombre del idioma en el selector. Va siempre en su propio idioma.
  ///
  /// In es, this message translates to:
  /// **'Español'**
  String get idiomaEspanol;

  /// Nombre del idioma en el selector. Va siempre en su propio idioma.
  ///
  /// In es, this message translates to:
  /// **'English'**
  String get idiomaIngles;

  /// Etiqueta para lectores de pantalla del selector de idioma.
  ///
  /// In es, this message translates to:
  /// **'Idioma'**
  String get idiomaSelector;

  /// No description provided for @arranqueSinServidor.
  ///
  /// In es, this message translates to:
  /// **'Esta compilación no tiene configurada la dirección del servidor. Compílela con tool/build_movil.sh.'**
  String get arranqueSinServidor;

  /// No description provided for @arranqueAbriendoSesion.
  ///
  /// In es, this message translates to:
  /// **'Abriendo su sesión…'**
  String get arranqueAbriendoSesion;

  /// No description provided for @ingresoCredencialesIncorrectas.
  ///
  /// In es, this message translates to:
  /// **'Correo o contraseña incorrectos.'**
  String get ingresoCredencialesIncorrectas;

  /// No description provided for @ingresoBienvenida.
  ///
  /// In es, this message translates to:
  /// **'Bienvenido de nuevo'**
  String get ingresoBienvenida;

  /// No description provided for @ingresoSubtitulo.
  ///
  /// In es, this message translates to:
  /// **'Ingrese con la cuenta creada por su administrador'**
  String get ingresoSubtitulo;

  /// No description provided for @ingresoCorreo.
  ///
  /// In es, this message translates to:
  /// **'Correo electrónico'**
  String get ingresoCorreo;

  /// No description provided for @ingresoContrasena.
  ///
  /// In es, this message translates to:
  /// **'Contraseña'**
  String get ingresoContrasena;

  /// No description provided for @ingresoMostrarContrasena.
  ///
  /// In es, this message translates to:
  /// **'Mostrar contraseña'**
  String get ingresoMostrarContrasena;

  /// No description provided for @ingresoOcultarContrasena.
  ///
  /// In es, this message translates to:
  /// **'Ocultar contraseña'**
  String get ingresoOcultarContrasena;

  /// No description provided for @ingresoIngresar.
  ///
  /// In es, this message translates to:
  /// **'Ingresar'**
  String get ingresoIngresar;

  /// No description provided for @ingresoVolverAlInicio.
  ///
  /// In es, this message translates to:
  /// **'← Volver al inicio'**
  String get ingresoVolverAlInicio;

  /// No description provided for @comunPoliticaPrivacidad.
  ///
  /// In es, this message translates to:
  /// **'Política de privacidad'**
  String get comunPoliticaPrivacidad;

  /// No description provided for @noEncontradaTitulo.
  ///
  /// In es, this message translates to:
  /// **'Página no encontrada'**
  String get noEncontradaTitulo;

  /// No description provided for @noEncontradaTexto.
  ///
  /// In es, this message translates to:
  /// **'La página que busca no existe o fue movida.'**
  String get noEncontradaTexto;

  /// No description provided for @comunVolverAlInicio.
  ///
  /// In es, this message translates to:
  /// **'Volver al inicio'**
  String get comunVolverAlInicio;

  /// No description provided for @sinConexionTitulo.
  ///
  /// In es, this message translates to:
  /// **'Sin conexión'**
  String get sinConexionTitulo;

  /// No description provided for @sinConexionTexto.
  ///
  /// In es, this message translates to:
  /// **'No pudimos comunicarnos con eduXaction para abrir su sesión. Revise su conexión a internet e intente de nuevo: su sesión sigue guardada.'**
  String get sinConexionTexto;

  /// No description provided for @sinConexionComprobando.
  ///
  /// In es, this message translates to:
  /// **'Comprobando su sesión…'**
  String get sinConexionComprobando;

  /// No description provided for @comunReintentar.
  ///
  /// In es, this message translates to:
  /// **'Reintentar'**
  String get comunReintentar;

  /// No description provided for @sinConexionOtraCuenta.
  ///
  /// In es, this message translates to:
  /// **'Entrar con otra cuenta'**
  String get sinConexionOtraCuenta;

  /// No description provided for @pendienteTitulo.
  ///
  /// In es, this message translates to:
  /// **'Disponible próximamente'**
  String get pendienteTitulo;

  /// No description provided for @pendienteTexto.
  ///
  /// In es, this message translates to:
  /// **'Estamos conectando este portal con el nuevo sistema. Preferimos tenerlo bien hecho antes que a medias: mientras tanto, no verá información que pueda estar desactualizada.'**
  String get pendienteTexto;

  /// No description provided for @pendienteSesionActiva.
  ///
  /// In es, this message translates to:
  /// **'Su sesión sigue activa como {nombre} · {rol}'**
  String pendienteSesionActiva(Object nombre, Object rol);

  /// No description provided for @comunIrAlInicio.
  ///
  /// In es, this message translates to:
  /// **'Ir al inicio'**
  String get comunIrAlInicio;

  /// No description provided for @comunCerrarSesion.
  ///
  /// In es, this message translates to:
  /// **'Cerrar sesión'**
  String get comunCerrarSesion;
}

class _AppLocalizationsDelegate
    extends LocalizationsDelegate<AppLocalizations> {
  const _AppLocalizationsDelegate();

  @override
  Future<AppLocalizations> load(Locale locale) {
    return SynchronousFuture<AppLocalizations>(lookupAppLocalizations(locale));
  }

  @override
  bool isSupported(Locale locale) =>
      <String>['en', 'es'].contains(locale.languageCode);

  @override
  bool shouldReload(_AppLocalizationsDelegate old) => false;
}

AppLocalizations lookupAppLocalizations(Locale locale) {
  // Lookup logic when only language code is specified.
  switch (locale.languageCode) {
    case 'en':
      return AppLocalizationsEn();
    case 'es':
      return AppLocalizationsEs();
  }

  throw FlutterError(
    'AppLocalizations.delegate failed to load unsupported locale "$locale". This is likely '
    'an issue with the localizations generation tool. Please file an issue '
    'on GitHub with a reproducible sample app and the gen-l10n configuration '
    'that was used.',
  );
}
