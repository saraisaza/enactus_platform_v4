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

  /// No description provided for @etapaValidacion.
  ///
  /// In es, this message translates to:
  /// **'Validación'**
  String get etapaValidacion;

  /// No description provided for @etapaPrototipo.
  ///
  /// In es, this message translates to:
  /// **'Prototipo'**
  String get etapaPrototipo;

  /// No description provided for @etapaPiloto.
  ///
  /// In es, this message translates to:
  /// **'Piloto'**
  String get etapaPiloto;

  /// No description provided for @etapaEscalamiento.
  ///
  /// In es, this message translates to:
  /// **'Escalamiento'**
  String get etapaEscalamiento;

  /// No description provided for @etapaIdeacion.
  ///
  /// In es, this message translates to:
  /// **'Ideación'**
  String get etapaIdeacion;

  /// No description provided for @rolLider.
  ///
  /// In es, this message translates to:
  /// **'Líder'**
  String get rolLider;

  /// No description provided for @rolInvestigacion.
  ///
  /// In es, this message translates to:
  /// **'Investigación'**
  String get rolInvestigacion;

  /// No description provided for @rolFinanzas.
  ///
  /// In es, this message translates to:
  /// **'Finanzas'**
  String get rolFinanzas;

  /// No description provided for @rolComunicaciones.
  ///
  /// In es, this message translates to:
  /// **'Comunicaciones'**
  String get rolComunicaciones;

  /// No description provided for @rolDiseno.
  ///
  /// In es, this message translates to:
  /// **'Diseño'**
  String get rolDiseno;

  /// No description provided for @rolOperaciones.
  ///
  /// In es, this message translates to:
  /// **'Operaciones'**
  String get rolOperaciones;

  /// No description provided for @rolIntegrante.
  ///
  /// In es, this message translates to:
  /// **'Integrante'**
  String get rolIntegrante;

  /// No description provided for @categoriaEmpresarial.
  ///
  /// In es, this message translates to:
  /// **'Empresarial'**
  String get categoriaEmpresarial;

  /// No description provided for @categoriaEmprendimiento.
  ///
  /// In es, this message translates to:
  /// **'Emprendimiento'**
  String get categoriaEmprendimiento;

  /// No description provided for @nivelIntermedio.
  ///
  /// In es, this message translates to:
  /// **'Intermedio'**
  String get nivelIntermedio;

  /// No description provided for @nivelAvanzado.
  ///
  /// In es, this message translates to:
  /// **'Avanzado'**
  String get nivelAvanzado;

  /// No description provided for @nivelBasico.
  ///
  /// In es, this message translates to:
  /// **'Básico'**
  String get nivelBasico;

  /// No description provided for @estadoPublicado.
  ///
  /// In es, this message translates to:
  /// **'Publicado'**
  String get estadoPublicado;

  /// No description provided for @estadoArchivado.
  ///
  /// In es, this message translates to:
  /// **'Archivado'**
  String get estadoArchivado;

  /// No description provided for @estadoBorrador.
  ///
  /// In es, this message translates to:
  /// **'Borrador'**
  String get estadoBorrador;

  /// No description provided for @odsEtiqueta.
  ///
  /// In es, this message translates to:
  /// **'ODS {numero}: {titulo}'**
  String odsEtiqueta(Object numero, Object titulo);

  /// No description provided for @idiomaCursoIngles.
  ///
  /// In es, this message translates to:
  /// **'Inglés'**
  String get idiomaCursoIngles;

  /// No description provided for @idiomaCursoPortugues.
  ///
  /// In es, this message translates to:
  /// **'Portugués'**
  String get idiomaCursoPortugues;

  /// No description provided for @idiomaCursoEspanol.
  ///
  /// In es, this message translates to:
  /// **'Español'**
  String get idiomaCursoEspanol;

  /// No description provided for @tipoArchivoVideo.
  ///
  /// In es, this message translates to:
  /// **'Video'**
  String get tipoArchivoVideo;

  /// No description provided for @tipoArchivoDocumento.
  ///
  /// In es, this message translates to:
  /// **'Documento'**
  String get tipoArchivoDocumento;

  /// No description provided for @tipoArchivoImagen.
  ///
  /// In es, this message translates to:
  /// **'Imagen'**
  String get tipoArchivoImagen;

  /// No description provided for @calificacionAprobadoReprobado.
  ///
  /// In es, this message translates to:
  /// **'Aprobado / Reprobado'**
  String get calificacionAprobadoReprobado;

  /// No description provided for @calificacionSoloRevision.
  ///
  /// In es, this message translates to:
  /// **'Solo revisión'**
  String get calificacionSoloRevision;

  /// No description provided for @calificacionEscala5.
  ///
  /// In es, this message translates to:
  /// **'Escala 0-5'**
  String get calificacionEscala5;

  /// No description provided for @calificacionPuntaje100.
  ///
  /// In es, this message translates to:
  /// **'Puntaje 0-100'**
  String get calificacionPuntaje100;

  /// No description provided for @calificacionPendiente.
  ///
  /// In es, this message translates to:
  /// **'Pendiente'**
  String get calificacionPendiente;

  /// No description provided for @calificacionAprobado.
  ///
  /// In es, this message translates to:
  /// **'Aprobado'**
  String get calificacionAprobado;

  /// No description provided for @calificacionReprobado.
  ///
  /// In es, this message translates to:
  /// **'Reprobado'**
  String get calificacionReprobado;

  /// No description provided for @calificacionRevisado.
  ///
  /// In es, this message translates to:
  /// **'Revisado'**
  String get calificacionRevisado;

  /// No description provided for @entregaGrupal.
  ///
  /// In es, this message translates to:
  /// **'Entrega grupal'**
  String get entregaGrupal;

  /// No description provided for @evidenciaFoto.
  ///
  /// In es, this message translates to:
  /// **'Foto'**
  String get evidenciaFoto;

  /// No description provided for @evidenciaTestimonio.
  ///
  /// In es, this message translates to:
  /// **'Testimonio'**
  String get evidenciaTestimonio;

  /// No description provided for @evidenciaReporte.
  ///
  /// In es, this message translates to:
  /// **'Reporte'**
  String get evidenciaReporte;

  /// No description provided for @evidenciaHistoria.
  ///
  /// In es, this message translates to:
  /// **'Historia'**
  String get evidenciaHistoria;

  /// No description provided for @foroCategoriaAvance.
  ///
  /// In es, this message translates to:
  /// **'Avance'**
  String get foroCategoriaAvance;

  /// No description provided for @foroCategoriaRecurso.
  ///
  /// In es, this message translates to:
  /// **'Recurso'**
  String get foroCategoriaRecurso;

  /// No description provided for @foroCategoriaAnuncio.
  ///
  /// In es, this message translates to:
  /// **'Anuncio'**
  String get foroCategoriaAnuncio;

  /// No description provided for @foroCategoriaPregunta.
  ///
  /// In es, this message translates to:
  /// **'Pregunta'**
  String get foroCategoriaPregunta;

  /// No description provided for @eventoSesionOpenLearning.
  ///
  /// In es, this message translates to:
  /// **'Sesión Open Learning'**
  String get eventoSesionOpenLearning;

  /// No description provided for @rutaDeImpacto.
  ///
  /// In es, this message translates to:
  /// **'Ruta de Impacto'**
  String get rutaDeImpacto;

  /// No description provided for @eventoMentoria.
  ///
  /// In es, this message translates to:
  /// **'Mentoría'**
  String get eventoMentoria;

  /// No description provided for @ods1.
  ///
  /// In es, this message translates to:
  /// **'Fin de la pobreza'**
  String get ods1;

  /// No description provided for @ods2.
  ///
  /// In es, this message translates to:
  /// **'Hambre cero'**
  String get ods2;

  /// No description provided for @ods3.
  ///
  /// In es, this message translates to:
  /// **'Salud y bienestar'**
  String get ods3;

  /// No description provided for @ods4.
  ///
  /// In es, this message translates to:
  /// **'Educación de calidad'**
  String get ods4;

  /// No description provided for @ods5.
  ///
  /// In es, this message translates to:
  /// **'Igualdad de género'**
  String get ods5;

  /// No description provided for @ods6.
  ///
  /// In es, this message translates to:
  /// **'Agua limpia y saneamiento'**
  String get ods6;

  /// No description provided for @ods7.
  ///
  /// In es, this message translates to:
  /// **'Energía asequible y no contaminante'**
  String get ods7;

  /// No description provided for @ods8.
  ///
  /// In es, this message translates to:
  /// **'Trabajo decente y crecimiento económico'**
  String get ods8;

  /// No description provided for @ods9.
  ///
  /// In es, this message translates to:
  /// **'Industria, innovación e infraestructura'**
  String get ods9;

  /// No description provided for @ods10.
  ///
  /// In es, this message translates to:
  /// **'Reducción de las desigualdades'**
  String get ods10;

  /// No description provided for @ods11.
  ///
  /// In es, this message translates to:
  /// **'Ciudades y comunidades sostenibles'**
  String get ods11;

  /// No description provided for @ods12.
  ///
  /// In es, this message translates to:
  /// **'Producción y consumo responsables'**
  String get ods12;

  /// No description provided for @ods13.
  ///
  /// In es, this message translates to:
  /// **'Acción por el clima'**
  String get ods13;

  /// No description provided for @ods14.
  ///
  /// In es, this message translates to:
  /// **'Vida submarina'**
  String get ods14;

  /// No description provided for @ods15.
  ///
  /// In es, this message translates to:
  /// **'Vida de ecosistemas terrestres'**
  String get ods15;

  /// No description provided for @ods16.
  ///
  /// In es, this message translates to:
  /// **'Paz, justicia e instituciones sólidas'**
  String get ods16;

  /// No description provided for @ods17.
  ///
  /// In es, this message translates to:
  /// **'Alianzas para lograr los objetivos'**
  String get ods17;

  /// No description provided for @competenciaLeadership.
  ///
  /// In es, this message translates to:
  /// **'Liderazgo'**
  String get competenciaLeadership;

  /// No description provided for @competenciaInnovation.
  ///
  /// In es, this message translates to:
  /// **'Innovación'**
  String get competenciaInnovation;

  /// No description provided for @competenciaEntrepreneurship.
  ///
  /// In es, this message translates to:
  /// **'Emprendimiento'**
  String get competenciaEntrepreneurship;

  /// No description provided for @competenciaFinance.
  ///
  /// In es, this message translates to:
  /// **'Finanzas'**
  String get competenciaFinance;

  /// No description provided for @competenciaCommunication.
  ///
  /// In es, this message translates to:
  /// **'Comunicación'**
  String get competenciaCommunication;

  /// No description provided for @competenciaPitch.
  ///
  /// In es, this message translates to:
  /// **'Pitch'**
  String get competenciaPitch;

  /// No description provided for @competenciaSustainability.
  ///
  /// In es, this message translates to:
  /// **'Sostenibilidad'**
  String get competenciaSustainability;

  /// No description provided for @competenciaArtificialIntelligence.
  ///
  /// In es, this message translates to:
  /// **'Inteligencia Artificial'**
  String get competenciaArtificialIntelligence;

  /// No description provided for @competenciaTeamwork.
  ///
  /// In es, this message translates to:
  /// **'Trabajo en equipo'**
  String get competenciaTeamwork;

  /// No description provided for @competenciaUserCenteredDesign.
  ///
  /// In es, this message translates to:
  /// **'Diseño Centrado en el Usuario'**
  String get competenciaUserCenteredDesign;

  /// No description provided for @competenciaProjectManagement.
  ///
  /// In es, this message translates to:
  /// **'Gestión de Proyectos'**
  String get competenciaProjectManagement;

  /// No description provided for @competenciaImpactMeasurement.
  ///
  /// In es, this message translates to:
  /// **'Medición de Impacto'**
  String get competenciaImpactMeasurement;

  /// No description provided for @errorSubidaFallo.
  ///
  /// In es, this message translates to:
  /// **'No se pudo subir el archivo ({status}). Si el problema persiste, avise al equipo técnico.'**
  String errorSubidaFallo(Object status);

  /// No description provided for @errorSubidaLenta.
  ///
  /// In es, this message translates to:
  /// **'La subida tardó demasiado. Intente con una conexión más estable.'**
  String get errorSubidaLenta;

  /// No description provided for @errorServidorLento.
  ///
  /// In es, this message translates to:
  /// **'El servidor tardó demasiado en responder.'**
  String get errorServidorLento;

  /// No description provided for @errorRespuestaInesperadaServidor.
  ///
  /// In es, this message translates to:
  /// **'El servidor devolvió una respuesta inesperada.'**
  String get errorRespuestaInesperadaServidor;

  /// No description provided for @errorDatosNoValidos.
  ///
  /// In es, this message translates to:
  /// **'Los datos enviados no son válidos.'**
  String get errorDatosNoValidos;

  /// No description provided for @errorSesionExpirada.
  ///
  /// In es, this message translates to:
  /// **'Su sesión expiró. Inicie sesión de nuevo.'**
  String get errorSesionExpirada;

  /// No description provided for @errorSinPermiso.
  ///
  /// In es, this message translates to:
  /// **'No tiene permiso para ver esto.'**
  String get errorSinPermiso;

  /// No description provided for @errorNoEncontrado.
  ///
  /// In es, this message translates to:
  /// **'No encontramos lo que busca.'**
  String get errorNoEncontrado;

  /// No description provided for @errorOperacionNoPosible.
  ///
  /// In es, this message translates to:
  /// **'La operación no se puede hacer en este momento.'**
  String get errorOperacionNoPosible;

  /// No description provided for @errorArchivoGrande.
  ///
  /// In es, this message translates to:
  /// **'El archivo es demasiado grande.'**
  String get errorArchivoGrande;

  /// No description provided for @errorDemasiadosIntentos.
  ///
  /// In es, this message translates to:
  /// **'Demasiados intentos. Espere un momento.'**
  String get errorDemasiadosIntentos;

  /// No description provided for @errorServidorIntente.
  ///
  /// In es, this message translates to:
  /// **'El servidor tuvo un problema. Intente de nuevo.'**
  String get errorServidorIntente;

  /// No description provided for @errorRespuestaInesperada.
  ///
  /// In es, this message translates to:
  /// **'Respuesta inesperada del servidor.'**
  String get errorRespuestaInesperada;

  /// No description provided for @certificadoTitulo.
  ///
  /// In es, this message translates to:
  /// **'CERTIFICADO DE FINALIZACIÓN'**
  String get certificadoTitulo;

  /// No description provided for @certificadoSeCertifica.
  ///
  /// In es, this message translates to:
  /// **'Se certifica que'**
  String get certificadoSeCertifica;

  /// No description provided for @certificadoCompleto.
  ///
  /// In es, this message translates to:
  /// **'completó la Ruta de Impacto del laboratorio'**
  String get certificadoCompleto;

  /// No description provided for @certificadoIntensidad.
  ///
  /// In es, this message translates to:
  /// **'Intensidad: {horas} horas certificadas'**
  String certificadoIntensidad(Object horas);

  /// No description provided for @certificadoEmitidoPor.
  ///
  /// In es, this message translates to:
  /// **'Emitido por'**
  String get certificadoEmitidoPor;

  /// No description provided for @certificadoFechaEmision.
  ///
  /// In es, this message translates to:
  /// **'Fecha de emisión'**
  String get certificadoFechaEmision;

  /// No description provided for @certificadoCodigo.
  ///
  /// In es, this message translates to:
  /// **'Código de verificación: {codigo}'**
  String certificadoCodigo(Object codigo);

  /// No description provided for @certificadoPie.
  ///
  /// In es, this message translates to:
  /// **'eduXaction Colombia · Entidad sin ánimo de lucro · Bogotá D. C.'**
  String get certificadoPie;

  /// No description provided for @certificadoTituloVisor.
  ///
  /// In es, this message translates to:
  /// **'Certificado · {laboratorio}'**
  String certificadoTituloVisor(Object laboratorio);

  /// No description provided for @certificadoArchivo.
  ///
  /// In es, this message translates to:
  /// **'certificado_{codigo}.pdf'**
  String certificadoArchivo(Object codigo);

  /// No description provided for @errorSubidaInterrumpida.
  ///
  /// In es, this message translates to:
  /// **'No se pudo subir el archivo: la conexión se interrumpió.'**
  String get errorSubidaInterrumpida;

  /// No description provided for @errorSubidaTardo.
  ///
  /// In es, this message translates to:
  /// **'La subida tardó demasiado.'**
  String get errorSubidaTardo;

  /// No description provided for @errorSubidaCancelada.
  ///
  /// In es, this message translates to:
  /// **'La subida se canceló.'**
  String get errorSubidaCancelada;

  /// No description provided for @errorVideoConexionNoResponde.
  ///
  /// In es, this message translates to:
  /// **'La conexión dejó de responder mientras subía el video.'**
  String get errorVideoConexionNoResponde;

  /// No description provided for @errorVideoConexionCortada.
  ///
  /// In es, this message translates to:
  /// **'Se cortó la conexión mientras subía el video.'**
  String get errorVideoConexionCortada;

  /// No description provided for @videoNavegadorNoAbre.
  ///
  /// In es, this message translates to:
  /// **'Este navegador no pudo abrir el video. Puede estar dañado; vuelva a exportarlo como MP4 (H.264 con audio AAC).'**
  String get videoNavegadorNoAbre;

  /// No description provided for @videoPortadaPesada.
  ///
  /// In es, this message translates to:
  /// **'La portada pesa {peso} y el máximo es 5 MB.'**
  String videoPortadaPesada(Object peso);

  /// No description provided for @videoParteRechazada.
  ///
  /// In es, this message translates to:
  /// **'El almacenamiento rechazó una parte del video ({status}).'**
  String videoParteRechazada(Object status);

  /// No description provided for @mp4SoloMp4.
  ///
  /// In es, this message translates to:
  /// **'Solo se aceptan videos MP4 (H.264 con audio AAC).'**
  String get mp4SoloMp4;

  /// No description provided for @mp4SoloMp4Ext.
  ///
  /// In es, this message translates to:
  /// **'Solo se aceptan videos MP4 (H.264 con audio AAC); este archivo es .{ext}. Expórtelo como MP4 y vuelva a intentar.'**
  String mp4SoloMp4Ext(Object ext);

  /// No description provided for @mp4Vacio.
  ///
  /// In es, this message translates to:
  /// **'El archivo está vacío.'**
  String get mp4Vacio;

  /// No description provided for @mp4Pesado.
  ///
  /// In es, this message translates to:
  /// **'El video pesa {peso} y el máximo es 500 MB. Comprímalo (por ejemplo con HandBrake, ajuste «Fast 1080p30») y vuelva a intentar.'**
  String mp4Pesado(Object peso);

  /// No description provided for @mp4Danado.
  ///
  /// In es, this message translates to:
  /// **'No se pudo leer el MP4: el archivo está incompleto o dañado. Vuelva a exportarlo.'**
  String get mp4Danado;

  /// No description provided for @mp4NoEsMp4.
  ///
  /// In es, this message translates to:
  /// **'Este archivo no es un MP4 aunque se llame así. Expórtelo como MP4 (H.264 con audio AAC).'**
  String get mp4NoEsMp4;

  /// No description provided for @mp4SinIndice.
  ///
  /// In es, this message translates to:
  /// **'No se pudo leer el MP4: le falta el índice del video, así que está incompleto o dañado. Vuelva a exportarlo.'**
  String get mp4SinIndice;

  /// No description provided for @mp4SoloAudio.
  ///
  /// In es, this message translates to:
  /// **'Este archivo no tiene imagen: parece ser solo audio.'**
  String get mp4SoloAudio;

  /// No description provided for @mp4Drm.
  ///
  /// In es, this message translates to:
  /// **'Este video está protegido contra copia (DRM) y no se puede reproducir en la plataforma.'**
  String get mp4Drm;

  /// No description provided for @mp4Hevc.
  ///
  /// In es, this message translates to:
  /// **'Este MP4 está en H.265 (HEVC), el formato con el que graba el iPhone, y muchos navegadores no lo reproducen. Expórtelo en H.264: en el iPhone, Ajustes › Cámara › Formatos › «Más compatible»; en la computadora, con HandBrake y el ajuste «Fast 1080p30».'**
  String get mp4Hevc;

  /// No description provided for @mp4Mpeg4Parte2.
  ///
  /// In es, this message translates to:
  /// **'MPEG-4 Parte 2'**
  String get mp4Mpeg4Parte2;

  /// No description provided for @mp4FormatoVideo.
  ///
  /// In es, this message translates to:
  /// **'Este MP4 usa el formato de video {nombre}, que no todos los navegadores reproducen. Expórtelo en H.264 con audio AAC.'**
  String mp4FormatoVideo(Object nombre);

  /// No description provided for @mp4PcmSinComprimir.
  ///
  /// In es, this message translates to:
  /// **'PCM sin comprimir'**
  String get mp4PcmSinComprimir;

  /// No description provided for @mp4FormatoAudio.
  ///
  /// In es, this message translates to:
  /// **'El audio de este MP4 está en {nombre}, y no todos los navegadores lo reproducen. Expórtelo con audio AAC.'**
  String mp4FormatoAudio(Object nombre);

  /// No description provided for @errorSinSesion.
  ///
  /// In es, this message translates to:
  /// **'No hay una sesión activa.'**
  String get errorSinSesion;

  /// No description provided for @errorRespuestaInesperadaRecibida.
  ///
  /// In es, this message translates to:
  /// **'Recibimos una respuesta inesperada del servidor.'**
  String get errorRespuestaInesperadaRecibida;

  /// No description provided for @rolSuperAdmin.
  ///
  /// In es, this message translates to:
  /// **'Super Admin'**
  String get rolSuperAdmin;

  /// No description provided for @rolAdministrador.
  ///
  /// In es, this message translates to:
  /// **'Administrador'**
  String get rolAdministrador;

  /// No description provided for @rolEstudiante.
  ///
  /// In es, this message translates to:
  /// **'Estudiante'**
  String get rolEstudiante;

  /// No description provided for @rolAlumni.
  ///
  /// In es, this message translates to:
  /// **'Alumni'**
  String get rolAlumni;

  /// No description provided for @rolMentor.
  ///
  /// In es, this message translates to:
  /// **'Mentor'**
  String get rolMentor;

  /// No description provided for @rolAsesorAcademico.
  ///
  /// In es, this message translates to:
  /// **'Asesor Académico'**
  String get rolAsesorAcademico;

  /// No description provided for @rolEmpresa.
  ///
  /// In es, this message translates to:
  /// **'Empresa'**
  String get rolEmpresa;

  /// No description provided for @rolDonante.
  ///
  /// In es, this message translates to:
  /// **'Donante'**
  String get rolDonante;

  /// No description provided for @pieInstitucional.
  ///
  /// In es, this message translates to:
  /// **'Entidad sin ánimo de lucro. Fundada en 2021. Bogotá D. C., Colombia.'**
  String get pieInstitucional;

  /// No description provided for @youtubeNoEsVideo.
  ///
  /// In es, this message translates to:
  /// **'Ese enlace es de YouTube, pero no de un video (parece un canal o una lista). Abra el video y copie su enlace.'**
  String get youtubeNoEsVideo;

  /// No description provided for @youtubePegueEnlace.
  ///
  /// In es, this message translates to:
  /// **'Pegue el enlace de un video de YouTube, por ejemplo https://www.youtube.com/watch?v=… o https://youtu.be/…'**
  String get youtubePegueEnlace;

  /// No description provided for @errorSinConexion.
  ///
  /// In es, this message translates to:
  /// **'No pudimos conectar con el servidor. Revise su conexión.'**
  String get errorSinConexion;

  /// No description provided for @errorServidorMomento.
  ///
  /// In es, this message translates to:
  /// **'El servidor tuvo un problema. Intente de nuevo en un momento.'**
  String get errorServidorMomento;

  /// No description provided for @pieLema.
  ///
  /// In es, this message translates to:
  /// **'Formamos líderes que transforman comunidades 💛'**
  String get pieLema;

  /// No description provided for @pieDerechos.
  ///
  /// In es, this message translates to:
  /// **'© {anio} eduXaction Colombia — Todos los derechos reservados'**
  String pieDerechos(Object anio);

  /// No description provided for @pieHechoEn.
  ///
  /// In es, this message translates to:
  /// **'Hecho con 💛 en Bogotá'**
  String get pieHechoEn;

  /// No description provided for @comunMenu.
  ///
  /// In es, this message translates to:
  /// **'Menú'**
  String get comunMenu;

  /// No description provided for @comunBuscar.
  ///
  /// In es, this message translates to:
  /// **'Buscar'**
  String get comunBuscar;

  /// No description provided for @busquedaTipoCurso.
  ///
  /// In es, this message translates to:
  /// **'Curso'**
  String get busquedaTipoCurso;

  /// No description provided for @busquedaTipoProyecto.
  ///
  /// In es, this message translates to:
  /// **'Proyecto'**
  String get busquedaTipoProyecto;

  /// No description provided for @busquedaEtapa.
  ///
  /// In es, this message translates to:
  /// **'Etapa: {etapa}'**
  String busquedaEtapa(Object etapa);

  /// No description provided for @comunCerrar.
  ///
  /// In es, this message translates to:
  /// **'Cerrar'**
  String get comunCerrar;

  /// No description provided for @busquedaPista.
  ///
  /// In es, this message translates to:
  /// **'Buscar estudiantes, cursos, proyectos…'**
  String get busquedaPista;

  /// No description provided for @busquedaEscriba.
  ///
  /// In es, this message translates to:
  /// **'Escriba para buscar'**
  String get busquedaEscriba;

  /// No description provided for @comunSinResultados.
  ///
  /// In es, this message translates to:
  /// **'Sin resultados'**
  String get comunSinResultados;

  /// No description provided for @cuentaMiCuenta.
  ///
  /// In es, this message translates to:
  /// **'Mi cuenta'**
  String get cuentaMiCuenta;

  /// No description provided for @cuentaMiPerfil.
  ///
  /// In es, this message translates to:
  /// **'Mi perfil'**
  String get cuentaMiPerfil;

  /// No description provided for @cuentaAcerca.
  ///
  /// In es, this message translates to:
  /// **'Acerca de eduXaction'**
  String get cuentaAcerca;

  /// No description provided for @cuentaEliminar.
  ///
  /// In es, this message translates to:
  /// **'Eliminar mi cuenta'**
  String get cuentaEliminar;

  /// No description provided for @notificacionesTitulo.
  ///
  /// In es, this message translates to:
  /// **'Notificaciones'**
  String get notificacionesTitulo;

  /// No description provided for @notificacionesVacio.
  ///
  /// In es, this message translates to:
  /// **'Sin notificaciones'**
  String get notificacionesVacio;

  /// No description provided for @contactoEnviado.
  ///
  /// In es, this message translates to:
  /// **'¡Mensaje enviado! Nos pondremos en contacto pronto.'**
  String get contactoEnviado;

  /// No description provided for @contactoError.
  ///
  /// In es, this message translates to:
  /// **'No pudimos enviar su mensaje. Intente de nuevo en un momento.'**
  String get contactoError;

  /// No description provided for @contactoTitulo.
  ///
  /// In es, this message translates to:
  /// **'Contáctenos'**
  String get contactoTitulo;

  /// No description provided for @contactoTexto.
  ///
  /// In es, this message translates to:
  /// **'Cuéntenos quién es y qué le gustaría hacer con nosotros.'**
  String get contactoTexto;

  /// No description provided for @comunNombre.
  ///
  /// In es, this message translates to:
  /// **'Nombre'**
  String get comunNombre;

  /// No description provided for @comunRequerido.
  ///
  /// In es, this message translates to:
  /// **'Requerido'**
  String get comunRequerido;

  /// No description provided for @comunCorreoInvalido.
  ///
  /// In es, this message translates to:
  /// **'Correo inválido'**
  String get comunCorreoInvalido;

  /// No description provided for @contactoMensaje.
  ///
  /// In es, this message translates to:
  /// **'Mensaje'**
  String get contactoMensaje;

  /// No description provided for @contactoMensajePista.
  ///
  /// In es, this message translates to:
  /// **'¿Cómo quiere sumarse? (estudiante, mentor, empresa, donante...)'**
  String get contactoMensajePista;

  /// No description provided for @comunCancelar.
  ///
  /// In es, this message translates to:
  /// **'Cancelar'**
  String get comunCancelar;

  /// No description provided for @comunEnviando.
  ///
  /// In es, this message translates to:
  /// **'Enviando…'**
  String get comunEnviando;

  /// No description provided for @contactoEnviar.
  ///
  /// In es, this message translates to:
  /// **'Enviar mensaje'**
  String get contactoEnviar;

  /// No description provided for @cuentaPrivacidadError.
  ///
  /// In es, this message translates to:
  /// **'No pudimos abrir la política de privacidad. Revise su conexión e intente de nuevo.'**
  String get cuentaPrivacidadError;

  /// No description provided for @cuentaEscribaContrasena.
  ///
  /// In es, this message translates to:
  /// **'Escriba su contraseña para confirmar.'**
  String get cuentaEscribaContrasena;

  /// No description provided for @cuentaSolicitudRecibida.
  ///
  /// In es, this message translates to:
  /// **'Solicitud recibida'**
  String get cuentaSolicitudRecibida;

  /// No description provided for @cuentaDesactivada.
  ///
  /// In es, this message translates to:
  /// **'Su cuenta quedó desactivada y se cerró la sesión en todos sus dispositivos. En un plazo máximo de {dias} días borraremos sus datos personales.'**
  String cuentaDesactivada(Object dias);

  /// No description provided for @comunEntendido.
  ///
  /// In es, this message translates to:
  /// **'Entendido'**
  String get comunEntendido;

  /// No description provided for @cuentaEliminando.
  ///
  /// In es, this message translates to:
  /// **'Eliminando…'**
  String get cuentaEliminando;

  /// No description provided for @cuentaQuePasa.
  ///
  /// In es, this message translates to:
  /// **'Esto es lo que pasa si elimina su cuenta:'**
  String get cuentaQuePasa;

  /// No description provided for @cuentaPunto1.
  ///
  /// In es, this message translates to:
  /// **'Deja de funcionar de inmediato y se cierra la sesión en todos sus dispositivos.'**
  String get cuentaPunto1;

  /// No description provided for @cuentaPunto2.
  ///
  /// In es, this message translates to:
  /// **'En un plazo máximo de 30 días borramos sus datos personales: nombre, correo, teléfono, cédula, ciudad, foto y perfil.'**
  String get cuentaPunto2;

  /// No description provided for @cuentaPunto3.
  ///
  /// In es, this message translates to:
  /// **'Lo que publicó en el foro y sus entregas se conservan a nombre de «Cuenta eliminada», para no borrar el trabajo de su equipo.'**
  String get cuentaPunto3;

  /// No description provided for @cuentaPunto4.
  ///
  /// In es, this message translates to:
  /// **'Si tiene certificados, descárguelos antes: al borrar sus datos dejan de mostrar su nombre.'**
  String get cuentaPunto4;

  /// No description provided for @cuentaParaConfirmar.
  ///
  /// In es, this message translates to:
  /// **'Para confirmar que es usted.'**
  String get cuentaParaConfirmar;

  /// No description provided for @cuentaAcercaTexto.
  ///
  /// In es, this message translates to:
  /// **'Formamos líderes que transforman comunidades 💛\n{pie}'**
  String cuentaAcercaTexto(Object pie);

  /// No description provided for @cuentaNormas.
  ///
  /// In es, this message translates to:
  /// **'Normas de la comunidad'**
  String get cuentaNormas;

  /// No description provided for @cuentaEscribanos.
  ///
  /// In es, this message translates to:
  /// **'Escríbanos'**
  String get cuentaEscribanos;

  /// No description provided for @cuentaLicencias.
  ///
  /// In es, this message translates to:
  /// **'Licencias de software'**
  String get cuentaLicencias;

  /// No description provided for @cuentaDerechos.
  ///
  /// In es, this message translates to:
  /// **'© {anio} eduXaction Colombia — Todos los derechos reservados\nHecho con 💛 en Bogotá'**
  String cuentaDerechos(Object anio);

  /// No description provided for @portalMas.
  ///
  /// In es, this message translates to:
  /// **'Más'**
  String get portalMas;

  /// No description provided for @portalMasOpciones.
  ///
  /// In es, this message translates to:
  /// **'Más opciones'**
  String get portalMasOpciones;

  /// No description provided for @etapaDeTotal.
  ///
  /// In es, this message translates to:
  /// **'Etapa {actual} de {total}'**
  String etapaDeTotal(Object actual, Object total);

  /// No description provided for @etapaFinal.
  ///
  /// In es, this message translates to:
  /// **'Etapa final'**
  String get etapaFinal;

  /// No description provided for @etapaSigue.
  ///
  /// In es, this message translates to:
  /// **'Sigue: {etapa}'**
  String etapaSigue(Object etapa);

  /// No description provided for @universidadCargando.
  ///
  /// In es, this message translates to:
  /// **'Cargando universidades…'**
  String get universidadCargando;

  /// No description provided for @universidadFueraCatalogo.
  ///
  /// In es, this message translates to:
  /// **'(universidad fuera del catálogo)'**
  String get universidadFueraCatalogo;

  /// No description provided for @universidadOtra.
  ///
  /// In es, this message translates to:
  /// **'Otra (¿cuál?)'**
  String get universidadOtra;

  /// No description provided for @universidadCual.
  ///
  /// In es, this message translates to:
  /// **'¿Cuál institución?'**
  String get universidadCual;

  /// No description provided for @universidadCualAyuda.
  ///
  /// In es, this message translates to:
  /// **'El nombre oficial completo. Queda en la lista para las próximas inscripciones.'**
  String get universidadCualAyuda;

  /// No description provided for @mapaNoCarga.
  ///
  /// In es, this message translates to:
  /// **'No se pudo cargar el mapa'**
  String get mapaNoCarga;

  /// No description provided for @mapaCifras.
  ///
  /// In es, this message translates to:
  /// **'Las cifras y el listado siguen disponibles a la derecha.'**
  String get mapaCifras;

  /// No description provided for @mapaEstudiantesPorCiudad.
  ///
  /// In es, this message translates to:
  /// **'ESTUDIANTES POR CIUDAD'**
  String get mapaEstudiantesPorCiudad;

  /// No description provided for @perfilRol.
  ///
  /// In es, this message translates to:
  /// **'Rol: {rol}'**
  String perfilRol(Object rol);

  /// No description provided for @perfilCorreo.
  ///
  /// In es, this message translates to:
  /// **'Correo: {correo}'**
  String perfilCorreo(Object correo);

  /// No description provided for @perfilTelefono.
  ///
  /// In es, this message translates to:
  /// **'Teléfono: {telefono}'**
  String perfilTelefono(Object telefono);

  /// No description provided for @perfilUniversidad.
  ///
  /// In es, this message translates to:
  /// **'Universidad: {universidad}'**
  String perfilUniversidad(Object universidad);

  /// No description provided for @universidadEtiqueta.
  ///
  /// In es, this message translates to:
  /// **'Universidad'**
  String get universidadEtiqueta;

  /// No description provided for @universidadNinguna.
  ///
  /// In es, this message translates to:
  /// **'Sin universidad'**
  String get universidadNinguna;

  /// No description provided for @comunConfirmar.
  ///
  /// In es, this message translates to:
  /// **'Confirmar'**
  String get comunConfirmar;

  /// No description provided for @comunNoSeDeshace.
  ///
  /// In es, this message translates to:
  /// **'Esta acción no se puede deshacer.'**
  String get comunNoSeDeshace;

  /// No description provided for @comunEscribaParaConfirmar.
  ///
  /// In es, this message translates to:
  /// **'Escriba {palabra} para confirmar'**
  String comunEscribaParaConfirmar(Object palabra);

  /// No description provided for @comunEliminarDefinitivamente.
  ///
  /// In es, this message translates to:
  /// **'Eliminar definitivamente'**
  String get comunEliminarDefinitivamente;

  /// No description provided for @formularioDescartarTitulo.
  ///
  /// In es, this message translates to:
  /// **'Descartar cambios'**
  String get formularioDescartarTitulo;

  /// No description provided for @formularioDescartarTexto.
  ///
  /// In es, this message translates to:
  /// **'Lo que escribió en este formulario no se ha guardado. ¿Desea salir de todas formas?'**
  String get formularioDescartarTexto;

  /// No description provided for @escritorioTitulo.
  ///
  /// In es, this message translates to:
  /// **'Mejor desde un computador'**
  String get escritorioTitulo;

  /// No description provided for @escritorioTexto.
  ///
  /// In es, this message translates to:
  /// **'Desde el teléfono, {herramienta} es difícil de usar y es fácil equivocarse: tiene listas para ordenar, tablas y formularios largos. Le recomendamos abrirlo en eduxaction.com desde un computador.'**
  String escritorioTexto(Object herramienta);

  /// No description provided for @escritorioContinuar.
  ///
  /// In es, this message translates to:
  /// **'Continuar de todas formas'**
  String get escritorioContinuar;

  /// No description provided for @eventoSesionSincronica.
  ///
  /// In es, this message translates to:
  /// **'Sesión sincrónica'**
  String get eventoSesionSincronica;

  /// No description provided for @eventoRutaImpacto.
  ///
  /// In es, this message translates to:
  /// **'Evento Ruta de Impacto'**
  String get eventoRutaImpacto;

  /// No description provided for @calendarioMesAnterior.
  ///
  /// In es, this message translates to:
  /// **'Mes anterior'**
  String get calendarioMesAnterior;

  /// No description provided for @calendarioMesSiguiente.
  ///
  /// In es, this message translates to:
  /// **'Mes siguiente'**
  String get calendarioMesSiguiente;

  /// No description provided for @calendarioAgregarEvento.
  ///
  /// In es, this message translates to:
  /// **'Agregar evento'**
  String get calendarioAgregarEvento;

  /// No description provided for @calendarioSinEventosDia.
  ///
  /// In es, this message translates to:
  /// **'No hay eventos este día.'**
  String get calendarioSinEventosDia;

  /// No description provided for @calendarioUnirse.
  ///
  /// In es, this message translates to:
  /// **'Unirse a la reunión'**
  String get calendarioUnirse;

  /// No description provided for @comunEditar.
  ///
  /// In es, this message translates to:
  /// **'Editar'**
  String get comunEditar;

  /// No description provided for @comunEliminar.
  ///
  /// In es, this message translates to:
  /// **'Eliminar'**
  String get comunEliminar;

  /// No description provided for @calendarioEliminarEvento.
  ///
  /// In es, this message translates to:
  /// **'Eliminar evento'**
  String get calendarioEliminarEvento;

  /// No description provided for @calendarioEliminarConfirmar.
  ///
  /// In es, this message translates to:
  /// **'¿Eliminar \"{titulo}\"? Esta acción no se puede deshacer.'**
  String calendarioEliminarConfirmar(Object titulo);

  /// No description provided for @calendarioEditarEvento.
  ///
  /// In es, this message translates to:
  /// **'Editar evento'**
  String get calendarioEditarEvento;

  /// No description provided for @comunTitulo.
  ///
  /// In es, this message translates to:
  /// **'Título'**
  String get comunTitulo;

  /// No description provided for @calendarioTipoEvento.
  ///
  /// In es, this message translates to:
  /// **'Tipo de evento'**
  String get calendarioTipoEvento;

  /// No description provided for @calendarioSinCursosOL.
  ///
  /// In es, this message translates to:
  /// **'Todavía no tiene cursos de Open Learning propios. Cree uno en \"Mis Cursos\" antes de agendar una sesión.'**
  String get calendarioSinCursosOL;

  /// No description provided for @calendarioSinLaboratorios.
  ///
  /// In es, this message translates to:
  /// **'Todavía no tiene laboratorios asignados, así que no hay a quién agendarle una mentoría.'**
  String get calendarioSinLaboratorios;

  /// No description provided for @comunLaboratorio.
  ///
  /// In es, this message translates to:
  /// **'Laboratorio'**
  String get comunLaboratorio;

  /// No description provided for @calendarioEventoGlobal.
  ///
  /// In es, this message translates to:
  /// **'Evento global: lo verán todos los estudiantes y alumni eduXaction de la plataforma, sin importar su laboratorio.'**
  String get calendarioEventoGlobal;

  /// No description provided for @calendarioLinkReunion.
  ///
  /// In es, this message translates to:
  /// **'Link de la reunión'**
  String get calendarioLinkReunion;

  /// No description provided for @calendarioInvitados.
  ///
  /// In es, this message translates to:
  /// **'Invitados (opcional)'**
  String get calendarioInvitados;

  /// No description provided for @calendarioInvitadosPista.
  ///
  /// In es, this message translates to:
  /// **'Ej: María Pérez (Bancolombia)'**
  String get calendarioInvitadosPista;

  /// No description provided for @comunDescripcionOpcional.
  ///
  /// In es, this message translates to:
  /// **'Descripción (opcional)'**
  String get comunDescripcionOpcional;

  /// No description provided for @calendarioRepetir.
  ///
  /// In es, this message translates to:
  /// **'Repetir cada 15 días'**
  String get calendarioRepetir;

  /// No description provided for @calendarioEventoActualizado.
  ///
  /// In es, this message translates to:
  /// **'Evento actualizado ✓'**
  String get calendarioEventoActualizado;

  /// No description provided for @calendarioEventoAgregado.
  ///
  /// In es, this message translates to:
  /// **'Evento agregado ✓'**
  String get calendarioEventoAgregado;

  /// No description provided for @comunGuardando.
  ///
  /// In es, this message translates to:
  /// **'Guardando…'**
  String get comunGuardando;

  /// No description provided for @comunGuardar.
  ///
  /// In es, this message translates to:
  /// **'Guardar'**
  String get comunGuardar;

  /// No description provided for @archivoTipoNoPermitido.
  ///
  /// In es, this message translates to:
  /// **'Tipo de archivo no permitido. Se aceptan PDF, imágenes, documentos de Word y ZIP.'**
  String get archivoTipoNoPermitido;

  /// No description provided for @archivoPesado.
  ///
  /// In es, this message translates to:
  /// **'El archivo pesa {megas} MB y el máximo son 25 MB.'**
  String archivoPesado(Object megas);

  /// No description provided for @archivoAdjuntar.
  ///
  /// In es, this message translates to:
  /// **'Adjuntar archivo'**
  String get archivoAdjuntar;

  /// No description provided for @archivoArchivo.
  ///
  /// In es, this message translates to:
  /// **'Archivo'**
  String get archivoArchivo;

  /// No description provided for @archivoPreparando.
  ///
  /// In es, this message translates to:
  /// **'Preparando la subida…'**
  String get archivoPreparando;

  /// No description provided for @archivoSubiendo.
  ///
  /// In es, this message translates to:
  /// **'Subiendo… {porcentaje}%'**
  String archivoSubiendo(Object porcentaje);

  /// No description provided for @comunQuitar.
  ///
  /// In es, this message translates to:
  /// **'Quitar'**
  String get comunQuitar;

  /// No description provided for @archivoNoAbre.
  ///
  /// In es, this message translates to:
  /// **'No se pudo abrir el archivo.'**
  String get archivoNoAbre;

  /// No description provided for @archivoNoVisible.
  ///
  /// In es, this message translates to:
  /// **'Este tipo de archivo no se puede ver dentro de la página. Descárguelo para abrirlo.'**
  String get archivoNoVisible;

  /// No description provided for @comunDescargar.
  ///
  /// In es, this message translates to:
  /// **'Descargar'**
  String get comunDescargar;

  /// No description provided for @archivoNoImagen.
  ///
  /// In es, this message translates to:
  /// **'No se pudo mostrar la imagen.'**
  String get archivoNoImagen;

  /// No description provided for @normas1Titulo.
  ///
  /// In es, this message translates to:
  /// **'Respeto ante todo'**
  String get normas1Titulo;

  /// No description provided for @normas1Texto.
  ///
  /// In es, this message translates to:
  /// **'Trate a las demás personas como quiere que lo traten. No se permiten insultos, burlas, acoso ni amenazas.'**
  String get normas1Texto;

  /// No description provided for @normas2Titulo.
  ///
  /// In es, this message translates to:
  /// **'Cero discriminación'**
  String get normas2Titulo;

  /// No description provided for @normas2Texto.
  ///
  /// In es, this message translates to:
  /// **'No se acepta contenido que discrimine por origen, nacionalidad, género, orientación sexual, religión, discapacidad o condición social.'**
  String get normas2Texto;

  /// No description provided for @normas3Titulo.
  ///
  /// In es, this message translates to:
  /// **'Contenido apropiado'**
  String get normas3Titulo;

  /// No description provided for @normas3Texto.
  ///
  /// In es, this message translates to:
  /// **'No publique contenido sexual, violento, ilegal ni nada que ponga en riesgo a otra persona.'**
  String get normas3Texto;

  /// No description provided for @normas4Titulo.
  ///
  /// In es, this message translates to:
  /// **'Sin publicidad'**
  String get normas4Titulo;

  /// No description provided for @normas4Texto.
  ///
  /// In es, this message translates to:
  /// **'El foro es para aprender y construir proyectos: no publique ventas, rifas, cadenas ni publicidad.'**
  String get normas4Texto;

  /// No description provided for @normas5Titulo.
  ///
  /// In es, this message translates to:
  /// **'Cuide los datos'**
  String get normas5Titulo;

  /// No description provided for @normas5Texto.
  ///
  /// In es, this message translates to:
  /// **'No comparta datos personales suyos ni de otras personas: teléfonos, direcciones, documentos o fotos de terceros.'**
  String get normas5Texto;

  /// No description provided for @normas6Titulo.
  ///
  /// In es, this message translates to:
  /// **'Reporte lo que no está bien'**
  String get normas6Titulo;

  /// No description provided for @normas6Texto.
  ///
  /// In es, this message translates to:
  /// **'Si algo incumple estas normas, use «Reportar» en el menú ⋮ de la publicación. Si alguien le incomoda, puede bloquearlo y dejará de ver lo que publica.'**
  String get normas6Texto;

  /// No description provided for @normasConsecuencias.
  ///
  /// In es, this message translates to:
  /// **'No hay tolerancia con el contenido ofensivo ni con el abuso. El equipo de Enactus Colombia revisa cada reporte y puede quitar el contenido y suspender la cuenta de quien incumpla estas normas.'**
  String get normasConsecuencias;

  /// No description provided for @normasAntesDePublicar.
  ///
  /// In es, this message translates to:
  /// **'Antes de publicar por primera vez, lea y acepte las normas del foro.'**
  String get normasAntesDePublicar;

  /// No description provided for @normasAcepto.
  ///
  /// In es, this message translates to:
  /// **'Acepto'**
  String get normasAcepto;

  /// No description provided for @visorAbriendo.
  ///
  /// In es, this message translates to:
  /// **'Abriendo el documento…'**
  String get visorAbriendo;

  /// No description provided for @visorNoAbre.
  ///
  /// In es, this message translates to:
  /// **'No pudimos abrir este documento. Revise su conexión e intente de nuevo.'**
  String get visorNoAbre;

  /// No description provided for @visorAppSistema.
  ///
  /// In es, this message translates to:
  /// **'Este archivo se abre con la aplicación del sistema.'**
  String get visorAppSistema;

  /// No description provided for @visorNoCarga.
  ///
  /// In es, this message translates to:
  /// **'No se pudo cargar el visor de PDF. Recargue la página.'**
  String get visorNoCarga;

  /// No description provided for @leccionTipoRecurso.
  ///
  /// In es, this message translates to:
  /// **'Recurso'**
  String get leccionTipoRecurso;

  /// No description provided for @leccionTipoEnlace.
  ///
  /// In es, this message translates to:
  /// **'Enlace'**
  String get leccionTipoEnlace;

  /// No description provided for @leccionTipoQuiz.
  ///
  /// In es, this message translates to:
  /// **'Quiz'**
  String get leccionTipoQuiz;

  /// No description provided for @leccionTipoActividad.
  ///
  /// In es, this message translates to:
  /// **'Actividad'**
  String get leccionTipoActividad;

  /// No description provided for @leccionTipoEncuesta.
  ///
  /// In es, this message translates to:
  /// **'Encuesta'**
  String get leccionTipoEncuesta;

  /// No description provided for @visorDocumento.
  ///
  /// In es, this message translates to:
  /// **'Documento'**
  String get visorDocumento;

  /// No description provided for @calendarioVeces.
  ///
  /// In es, this message translates to:
  /// **'{cantidad, plural, =1{1 vez} other{{cantidad} veces}}'**
  String calendarioVeces(int cantidad);

  /// No description provided for @glosarioOcultarTexto.
  ///
  /// In es, this message translates to:
  /// **'Ocultar texto y glosario'**
  String get glosarioOcultarTexto;

  /// No description provided for @glosarioVerTexto.
  ///
  /// In es, this message translates to:
  /// **'Ver texto y glosario de la lección'**
  String get glosarioVerTexto;

  /// No description provided for @glosarioTextoDe.
  ///
  /// In es, this message translates to:
  /// **'Texto y glosario de «{titulo}»'**
  String glosarioTextoDe(Object titulo);

  /// No description provided for @glosarioDeLeccion.
  ///
  /// In es, this message translates to:
  /// **'Glosario de esta lección'**
  String get glosarioDeLeccion;

  /// No description provided for @glosarioLeccionVacio.
  ///
  /// In es, this message translates to:
  /// **'Esta lección no tiene términos de glosario.'**
  String get glosarioLeccionVacio;

  /// No description provided for @glosarioDelModulo.
  ///
  /// In es, this message translates to:
  /// **'Glosario del módulo'**
  String get glosarioDelModulo;

  /// No description provided for @glosarioPorRepasar.
  ///
  /// In es, this message translates to:
  /// **'{cantidad} por repasar'**
  String glosarioPorRepasar(Object cantidad);

  /// No description provided for @glosarioTarjetas.
  ///
  /// In es, this message translates to:
  /// **'Tarjetas'**
  String get glosarioTarjetas;

  /// No description provided for @glosarioModoRepaso.
  ///
  /// In es, this message translates to:
  /// **'Modo repaso'**
  String get glosarioModoRepaso;

  /// No description provided for @glosarioBuscar.
  ///
  /// In es, this message translates to:
  /// **'Buscar en el glosario'**
  String get glosarioBuscar;

  /// No description provided for @glosarioBorrarBusqueda.
  ///
  /// In es, this message translates to:
  /// **'Borrar la búsqueda'**
  String get glosarioBorrarBusqueda;

  /// No description provided for @glosarioNingunoCoincide.
  ///
  /// In es, this message translates to:
  /// **'Ningún término coincide con «{busqueda}».'**
  String glosarioNingunoCoincide(Object busqueda);

  /// No description provided for @glosarioNingunoMarcado.
  ///
  /// In es, this message translates to:
  /// **'No tiene términos marcados para repasar.'**
  String get glosarioNingunoMarcado;

  /// No description provided for @glosarioNingunoLetra.
  ///
  /// In es, this message translates to:
  /// **'Ningún término empieza con esa letra.'**
  String get glosarioNingunoLetra;

  /// No description provided for @glosarioQuitarFiltros.
  ///
  /// In es, this message translates to:
  /// **'Quitar los filtros'**
  String get glosarioQuitarFiltros;

  /// No description provided for @glosarioTodas.
  ///
  /// In es, this message translates to:
  /// **'Todas'**
  String get glosarioTodas;

  /// No description provided for @glosarioTodasLasLetras.
  ///
  /// In es, this message translates to:
  /// **'Todas las letras'**
  String get glosarioTodasLasLetras;

  /// No description provided for @glosarioAyudaTarjetas.
  ///
  /// In es, this message translates to:
  /// **'Toque una tarjeta para voltearla. El avance del repaso se guarda en la cuenta de cada estudiante.'**
  String get glosarioAyudaTarjetas;

  /// No description provided for @glosarioAyudaRepaso.
  ///
  /// In es, this message translates to:
  /// **'Toque una tarjeta para ver la definición y marque si ya la sabe. Ya lo sabe: {sabe} de {total} · Por repasar: {repasar}'**
  String glosarioAyudaRepaso(Object sabe, Object total, Object repasar);

  /// No description provided for @glosarioYaLoSabeDe.
  ///
  /// In es, this message translates to:
  /// **'Ya lo sabe: {sabe} de {total}'**
  String glosarioYaLoSabeDe(Object sabe, Object total);

  /// No description provided for @glosarioSoloRepasar.
  ///
  /// In es, this message translates to:
  /// **'Solo los de repasar'**
  String get glosarioSoloRepasar;

  /// No description provided for @glosarioRelacionados.
  ///
  /// In es, this message translates to:
  /// **'Relacionados'**
  String get glosarioRelacionados;

  /// No description provided for @glosarioIrA.
  ///
  /// In es, this message translates to:
  /// **'Ir a «{palabra}»'**
  String glosarioIrA(Object palabra);

  /// No description provided for @glosarioEjemplo.
  ///
  /// In es, this message translates to:
  /// **'Ejemplo'**
  String get glosarioEjemplo;

  /// No description provided for @glosarioImagenDe.
  ///
  /// In es, this message translates to:
  /// **'Imagen de «{palabra}»'**
  String glosarioImagenDe(Object palabra);

  /// No description provided for @glosarioYaLoSabe.
  ///
  /// In es, this message translates to:
  /// **'Ya lo sabe'**
  String get glosarioYaLoSabe;

  /// No description provided for @glosarioPorRepasarEstado.
  ///
  /// In es, this message translates to:
  /// **'Por repasar'**
  String get glosarioPorRepasarEstado;

  /// No description provided for @glosarioDefinicionDe.
  ///
  /// In es, this message translates to:
  /// **'Definición de «{palabra}»: {definicion}'**
  String glosarioDefinicionDe(Object palabra, Object definicion);

  /// No description provided for @glosarioToqueParaVer.
  ///
  /// In es, this message translates to:
  /// **'«{palabra}». Toque para ver la definición.'**
  String glosarioToqueParaVer(Object palabra);

  /// No description provided for @glosarioYaLoSe.
  ///
  /// In es, this message translates to:
  /// **'Ya lo sé'**
  String get glosarioYaLoSe;

  /// No description provided for @glosarioRepasar.
  ///
  /// In es, this message translates to:
  /// **'Repasar'**
  String get glosarioRepasar;

  /// No description provided for @glosarioToqueDefinicion.
  ///
  /// In es, this message translates to:
  /// **'Toque para ver la definición'**
  String get glosarioToqueDefinicion;

  /// No description provided for @videoCargandoTitulo.
  ///
  /// In es, this message translates to:
  /// **'Cargando el video «{titulo}»'**
  String videoCargandoTitulo(Object titulo);

  /// No description provided for @videoReproducirTitulo.
  ///
  /// In es, this message translates to:
  /// **'Reproducir el video «{titulo}»'**
  String videoReproducirTitulo(Object titulo);

  /// No description provided for @videoSeguirViendo.
  ///
  /// In es, this message translates to:
  /// **'Seguir viendo «{titulo}» desde {tiempo}'**
  String videoSeguirViendo(Object titulo, Object tiempo);

  /// No description provided for @videoCargando.
  ///
  /// In es, this message translates to:
  /// **'Cargando el video…'**
  String get videoCargando;

  /// No description provided for @videoSeguirDesde.
  ///
  /// In es, this message translates to:
  /// **'Seguir desde {tiempo}'**
  String videoSeguirDesde(Object tiempo);

  /// No description provided for @videoNoDisponibleEntorno.
  ///
  /// In es, this message translates to:
  /// **'La reproducción no está disponible en este entorno'**
  String get videoNoDisponibleEntorno;

  /// No description provided for @videoYaNoDisponible.
  ///
  /// In es, this message translates to:
  /// **'Este video ya no está disponible'**
  String get videoYaNoDisponible;

  /// No description provided for @videoAviseCreador.
  ///
  /// In es, this message translates to:
  /// **'Avísele a quien armó el curso.'**
  String get videoAviseCreador;

  /// No description provided for @videoNoCarga.
  ///
  /// In es, this message translates to:
  /// **'No se pudo cargar el video'**
  String get videoNoCarga;

  /// No description provided for @videoPuedeSerConexion.
  ///
  /// In es, this message translates to:
  /// **'Puede ser la conexión. Intente de nuevo en un momento.'**
  String get videoPuedeSerConexion;

  /// No description provided for @videoPausar.
  ///
  /// In es, this message translates to:
  /// **'Pausar el video'**
  String get videoPausar;

  /// No description provided for @videoReproducir.
  ///
  /// In es, this message translates to:
  /// **'Reproducir el video'**
  String get videoReproducir;

  /// No description provided for @videoCargandoCorto.
  ///
  /// In es, this message translates to:
  /// **'Cargando el video'**
  String get videoCargandoCorto;

  /// No description provided for @videoPosicion.
  ///
  /// In es, this message translates to:
  /// **'Posición del video'**
  String get videoPosicion;

  /// No description provided for @videoTiempoDe.
  ///
  /// In es, this message translates to:
  /// **'{actual} de {total}'**
  String videoTiempoDe(Object actual, Object total);

  /// No description provided for @videoPausarK.
  ///
  /// In es, this message translates to:
  /// **'Pausar (K)'**
  String get videoPausarK;

  /// No description provided for @videoReproducirK.
  ///
  /// In es, this message translates to:
  /// **'Reproducir (K)'**
  String get videoReproducirK;

  /// No description provided for @videoActivarSonido.
  ///
  /// In es, this message translates to:
  /// **'Activar el sonido (M)'**
  String get videoActivarSonido;

  /// No description provided for @videoSilenciar.
  ///
  /// In es, this message translates to:
  /// **'Silenciar (M)'**
  String get videoSilenciar;

  /// No description provided for @videoVolumen.
  ///
  /// In es, this message translates to:
  /// **'Volumen'**
  String get videoVolumen;

  /// No description provided for @videoMinutoDe.
  ///
  /// In es, this message translates to:
  /// **'Minuto {actual} de {total}'**
  String videoMinutoDe(Object actual, Object total);

  /// No description provided for @videoVelocidad.
  ///
  /// In es, this message translates to:
  /// **'Velocidad de reproducción'**
  String get videoVelocidad;

  /// No description provided for @videoVelocidadNormal.
  ///
  /// In es, this message translates to:
  /// **'Normal (1×)'**
  String get videoVelocidadNormal;

  /// No description provided for @videoVelocidadActual.
  ///
  /// In es, this message translates to:
  /// **'Velocidad de reproducción: {velocidad}'**
  String videoVelocidadActual(Object velocidad);

  /// No description provided for @videoSalirPantallaCompleta.
  ///
  /// In es, this message translates to:
  /// **'Salir de pantalla completa (F)'**
  String get videoSalirPantallaCompleta;

  /// No description provided for @videoPantallaCompleta.
  ///
  /// In es, this message translates to:
  /// **'Pantalla completa (F)'**
  String get videoPantallaCompleta;

  /// No description provided for @videoVer.
  ///
  /// In es, this message translates to:
  /// **'Ver el video'**
  String get videoVer;

  /// No description provided for @videoPestanaNueva.
  ///
  /// In es, this message translates to:
  /// **'Se abre en una pestaña nueva.'**
  String get videoPestanaNueva;

  /// No description provided for @videoAbrir.
  ///
  /// In es, this message translates to:
  /// **'Abrir video'**
  String get videoAbrir;

  /// No description provided for @videoLeccionSinVideo.
  ///
  /// In es, this message translates to:
  /// **'Esta lección todavía no tiene video'**
  String get videoLeccionSinVideo;

  /// No description provided for @videoCreadorNoCargo.
  ///
  /// In es, this message translates to:
  /// **'Quien la creó aún no le cargó ninguno.'**
  String get videoCreadorNoCargo;

  /// No description provided for @videoEnlaceNoAbre.
  ///
  /// In es, this message translates to:
  /// **'No se pudo abrir el enlace del video.'**
  String get videoEnlaceNoAbre;

  /// No description provided for @videoAvanceSeGuarda.
  ///
  /// In es, this message translates to:
  /// **'Su avance se guarda solo: si cierra, sigue donde quedó.'**
  String get videoAvanceSeGuarda;

  /// No description provided for @videoLeccionCompletada.
  ///
  /// In es, this message translates to:
  /// **'Lección completada'**
  String get videoLeccionCompletada;

  /// No description provided for @videoVisto.
  ///
  /// In es, this message translates to:
  /// **'Visto {porcentaje}%'**
  String videoVisto(Object porcentaje);

  /// No description provided for @subidaSinTerminar.
  ///
  /// In es, this message translates to:
  /// **'Quedó sin terminar la subida de «{archivo}» ({tamano}). Elija el mismo archivo y, al guardar, sigue desde donde iba.'**
  String subidaSinTerminar(Object archivo, Object tamano);

  /// No description provided for @subidaZonaSoltar.
  ///
  /// In es, this message translates to:
  /// **'Zona para soltar el video'**
  String get subidaZonaSoltar;

  /// No description provided for @subidaSuelte.
  ///
  /// In es, this message translates to:
  /// **'Suelte el video para elegirlo'**
  String get subidaSuelte;

  /// No description provided for @subidaReemplazar.
  ///
  /// In es, this message translates to:
  /// **'Para reemplazarlo, arrastre otro video aquí'**
  String get subidaReemplazar;

  /// No description provided for @subidaArrastre.
  ///
  /// In es, this message translates to:
  /// **'Arrastre el video aquí'**
  String get subidaArrastre;

  /// No description provided for @subidaElegirVideo.
  ///
  /// In es, this message translates to:
  /// **'Elegir video'**
  String get subidaElegirVideo;

  /// No description provided for @subidaFormato.
  ///
  /// In es, this message translates to:
  /// **'MP4 (H.264 con audio AAC) · hasta 500 MB'**
  String get subidaFormato;

  /// No description provided for @subidaRevisando.
  ///
  /// In es, this message translates to:
  /// **'Revisando el video…'**
  String get subidaRevisando;

  /// No description provided for @subidaElegirOtro.
  ///
  /// In es, this message translates to:
  /// **'Elegir otro video'**
  String get subidaElegirOtro;

  /// No description provided for @subidaVistaPreviaAsi.
  ///
  /// In es, this message translates to:
  /// **'Vista previa — así lo verán los estudiantes:'**
  String get subidaVistaPreviaAsi;

  /// No description provided for @subidaVistaPrevia.
  ///
  /// In es, this message translates to:
  /// **'Vista previa'**
  String get subidaVistaPrevia;

  /// No description provided for @subidaVistaPreviaNavegador.
  ///
  /// In es, this message translates to:
  /// **'La vista previa se ve en el navegador'**
  String get subidaVistaPreviaNavegador;

  /// No description provided for @subidaVistaPreviaDetalle.
  ///
  /// In es, this message translates to:
  /// **'El video se sube igual; para mirarlo antes de guardar, abra el editor desde el sitio web.'**
  String get subidaVistaPreviaDetalle;

  /// No description provided for @subidaPortadaPropia.
  ///
  /// In es, this message translates to:
  /// **'Portada propia'**
  String get subidaPortadaPropia;

  /// No description provided for @subidaPortadaDelVideo.
  ///
  /// In es, this message translates to:
  /// **'Portada tomada del video'**
  String get subidaPortadaDelVideo;

  /// No description provided for @subidaSinPortada.
  ///
  /// In es, this message translates to:
  /// **'Sin portada: se verá un fondo genérico'**
  String get subidaSinPortada;

  /// No description provided for @subidaUsarOtraImagen.
  ///
  /// In es, this message translates to:
  /// **'Usar otra imagen'**
  String get subidaUsarOtraImagen;

  /// No description provided for @subidaVolverPortadaVideo.
  ///
  /// In es, this message translates to:
  /// **'Volver a la del video'**
  String get subidaVolverPortadaVideo;

  /// No description provided for @subidaQuitarPortada.
  ///
  /// In es, this message translates to:
  /// **'Quitar la portada'**
  String get subidaQuitarPortada;

  /// No description provided for @subidaCambiarPortada.
  ///
  /// In es, this message translates to:
  /// **'Cambiar la portada'**
  String get subidaCambiarPortada;

  /// No description provided for @subidaPonerPortada.
  ///
  /// In es, this message translates to:
  /// **'Ponerle portada'**
  String get subidaPonerPortada;

  /// No description provided for @subidaNuevaPortada.
  ///
  /// In es, this message translates to:
  /// **'Nueva portada: se guarda al guardar'**
  String get subidaNuevaPortada;

  /// No description provided for @subidaNoTermino.
  ///
  /// In es, this message translates to:
  /// **'No se pudo terminar la subida: {mensaje} Las partes que ya llegaron no se pierden: guarde de nuevo y sigue desde donde iba.'**
  String subidaNoTermino(Object mensaje);

  /// No description provided for @subidaDe.
  ///
  /// In es, this message translates to:
  /// **'{enviado} de {total}'**
  String subidaDe(Object enviado, Object total);

  /// No description provided for @subidaQuedan.
  ///
  /// In es, this message translates to:
  /// **'quedan {tiempo}'**
  String subidaQuedan(Object tiempo);

  /// No description provided for @subidaSiguiendo.
  ///
  /// In es, this message translates to:
  /// **'Siguiendo la subida… {pct} %'**
  String subidaSiguiendo(Object pct);

  /// No description provided for @subidaSubiendo.
  ///
  /// In es, this message translates to:
  /// **'Subiendo el video… {pct} %'**
  String subidaSubiendo(Object pct);

  /// No description provided for @subidaCancelar.
  ///
  /// In es, this message translates to:
  /// **'Cancelar subida'**
  String get subidaCancelar;

  /// No description provided for @subidaAvance.
  ///
  /// In es, this message translates to:
  /// **'Avance de la subida'**
  String get subidaAvance;

  /// No description provided for @subidaNoCierre.
  ///
  /// In es, this message translates to:
  /// **'No cierre esta ventana hasta que termine.'**
  String get subidaNoCierre;

  /// No description provided for @youtubeNoAbre.
  ///
  /// In es, this message translates to:
  /// **'No se pudo abrir YouTube.'**
  String get youtubeNoAbre;

  /// No description provided for @youtubeNoCarga.
  ///
  /// In es, this message translates to:
  /// **'No se pudo cargar el reproductor'**
  String get youtubeNoCarga;

  /// No description provided for @youtubeNoCargaDetalle.
  ///
  /// In es, this message translates to:
  /// **'Puede ser la conexión, o que el navegador esté bloqueando a YouTube. Puede intentar de nuevo o verlo directamente allá.'**
  String get youtubeNoCargaDetalle;

  /// No description provided for @youtubeSoloYoutube.
  ///
  /// In es, this message translates to:
  /// **'Este video solo se puede ver en YouTube'**
  String get youtubeSoloYoutube;

  /// No description provided for @youtubeSoloYoutubeDetalle.
  ///
  /// In es, this message translates to:
  /// **'Quien lo subió no permite reproducirlo fuera de YouTube.'**
  String get youtubeSoloYoutubeDetalle;

  /// No description provided for @youtubeBorrado.
  ///
  /// In es, this message translates to:
  /// **'Lo borraron de YouTube o lo hicieron privado. Avísele a quien armó el curso.'**
  String get youtubeBorrado;

  /// No description provided for @youtubeNoValido.
  ///
  /// In es, this message translates to:
  /// **'El video guardado no es válido'**
  String get youtubeNoValido;

  /// No description provided for @youtubeNoValidoDetalle.
  ///
  /// In es, this message translates to:
  /// **'Avísele a quien armó el curso para que revise el enlace.'**
  String get youtubeNoValidoDetalle;

  /// No description provided for @youtubeNoReproduce.
  ///
  /// In es, this message translates to:
  /// **'YouTube no pudo reproducir el video'**
  String get youtubeNoReproduce;

  /// No description provided for @youtubeNoReproduceDetalle.
  ///
  /// In es, this message translates to:
  /// **'Pruebe de nuevo, o mírelo directamente en YouTube.'**
  String get youtubeNoReproduceDetalle;

  /// No description provided for @youtubeVerEn.
  ///
  /// In es, this message translates to:
  /// **'Ver en YouTube'**
  String get youtubeVerEn;

  /// No description provided for @glosarioTerminos.
  ///
  /// In es, this message translates to:
  /// **'{cantidad, plural, =1{1 término} other{{cantidad} términos}}'**
  String glosarioTerminos(int cantidad);

  /// No description provided for @glosarioLetraTerminos.
  ///
  /// In es, this message translates to:
  /// **'Letra {letra}, {cantidad, plural, =1{1 término} other{{cantidad} términos}}'**
  String glosarioLetraTerminos(Object letra, int cantidad);

  /// No description provided for @subidaSubidoEl.
  ///
  /// In es, this message translates to:
  /// **'subido el {fecha}'**
  String subidaSubidoEl(Object fecha);

  /// No description provided for @subidaVideoActual.
  ///
  /// In es, this message translates to:
  /// **'Video actual: {nombre}'**
  String subidaVideoActual(Object nombre);

  /// No description provided for @subidaArchivoSubido.
  ///
  /// In es, this message translates to:
  /// **'archivo subido'**
  String get subidaArchivoSubido;

  /// No description provided for @portadaIniciarSesion.
  ///
  /// In es, this message translates to:
  /// **'Iniciar sesión'**
  String get portadaIniciarSesion;

  /// No description provided for @portadaEstudiantesActivos.
  ///
  /// In es, this message translates to:
  /// **'Estudiantes activos'**
  String get portadaEstudiantesActivos;

  /// No description provided for @portadaProyectosImpacto.
  ///
  /// In es, this message translates to:
  /// **'Proyectos de impacto'**
  String get portadaProyectosImpacto;

  /// No description provided for @portadaLaboratorios.
  ///
  /// In es, this message translates to:
  /// **'Laboratorios'**
  String get portadaLaboratorios;

  /// No description provided for @portadaUniversidadesAliadas.
  ///
  /// In es, this message translates to:
  /// **'Universidades aliadas'**
  String get portadaUniversidadesAliadas;

  /// No description provided for @portadaAreasConocimiento.
  ///
  /// In es, this message translates to:
  /// **'Áreas de conocimiento'**
  String get portadaAreasConocimiento;

  /// No description provided for @portadaNuestrosLaboratorios.
  ///
  /// In es, this message translates to:
  /// **'Nuestros Laboratorios'**
  String get portadaNuestrosLaboratorios;

  /// No description provided for @portadaAreasTexto.
  ///
  /// In es, this message translates to:
  /// **'Áreas de conocimiento donde formamos a nuestros equipos'**
  String get portadaAreasTexto;

  /// No description provided for @portadaGaleria.
  ///
  /// In es, this message translates to:
  /// **'Galería'**
  String get portadaGaleria;

  /// No description provided for @portadaNuestroTrabajo.
  ///
  /// In es, this message translates to:
  /// **'Nuestro trabajo en imágenes'**
  String get portadaNuestroTrabajo;

  /// No description provided for @portadaMomentos.
  ///
  /// In es, this message translates to:
  /// **'Momentos de la comunidad eduXaction Colombia'**
  String get portadaMomentos;

  /// No description provided for @portadaListo.
  ///
  /// In es, this message translates to:
  /// **'¿Listo para sumarse? 💛'**
  String get portadaListo;

  /// No description provided for @portadaListoTexto.
  ///
  /// In es, this message translates to:
  /// **'Sin importar si es estudiante, mentor, empresa o donante: hay un lugar para usted en eduXaction Colombia.'**
  String get portadaListoTexto;

  /// No description provided for @portadaQuieroUnirme.
  ///
  /// In es, this message translates to:
  /// **'Quiero unirme'**
  String get portadaQuieroUnirme;

  /// No description provided for @portadaExpoLugar.
  ///
  /// In es, this message translates to:
  /// **'Santa Marta · julio 2026'**
  String get portadaExpoLugar;

  /// No description provided for @portadaExpoTitulo.
  ///
  /// In es, this message translates to:
  /// **'Campeones National Expo 2026'**
  String get portadaExpoTitulo;

  /// No description provided for @portadaExpoTexto.
  ///
  /// In es, this message translates to:
  /// **'Santa Marta, julio 2026 — nuestros equipos rumbo al eduXaction World Cup en São Paulo'**
  String get portadaExpoTexto;

  /// No description provided for @portadaExpoPie.
  ///
  /// In es, this message translates to:
  /// **'Delegación eduXaction Colombia · National Expo 2026'**
  String get portadaExpoPie;

  /// No description provided for @portadaEntrar.
  ///
  /// In es, this message translates to:
  /// **'Entrar a la plataforma'**
  String get portadaEntrar;

  /// No description provided for @tabDashboard.
  ///
  /// In es, this message translates to:
  /// **'Dashboard'**
  String get tabDashboard;

  /// No description provided for @tabInicioCorto.
  ///
  /// In es, this message translates to:
  /// **'Inicio'**
  String get tabInicioCorto;

  /// No description provided for @tabCalendario.
  ///
  /// In es, this message translates to:
  /// **'Calendario'**
  String get tabCalendario;

  /// No description provided for @tabMisCursos.
  ///
  /// In es, this message translates to:
  /// **'Mis Cursos'**
  String get tabMisCursos;

  /// No description provided for @tabCursosCorto.
  ///
  /// In es, this message translates to:
  /// **'Cursos'**
  String get tabCursosCorto;

  /// No description provided for @tabLaboratorios.
  ///
  /// In es, this message translates to:
  /// **'Laboratorios'**
  String get tabLaboratorios;

  /// No description provided for @tabRutaCorto.
  ///
  /// In es, this message translates to:
  /// **'Ruta'**
  String get tabRutaCorto;

  /// No description provided for @tabDirectorioProyectos.
  ///
  /// In es, this message translates to:
  /// **'Directorio de Proyectos'**
  String get tabDirectorioProyectos;

  /// No description provided for @tabProyectosCorto.
  ///
  /// In es, this message translates to:
  /// **'Proyectos'**
  String get tabProyectosCorto;

  /// No description provided for @tabForo.
  ///
  /// In es, this message translates to:
  /// **'Foro'**
  String get tabForo;

  /// No description provided for @tabCertificados.
  ///
  /// In es, this message translates to:
  /// **'Certificados'**
  String get tabCertificados;

  /// No description provided for @tabMiPerfil.
  ///
  /// In es, this message translates to:
  /// **'Mi Perfil'**
  String get tabMiPerfil;

  /// No description provided for @tabPerfilCorto.
  ///
  /// In es, this message translates to:
  /// **'Perfil'**
  String get tabPerfilCorto;

  /// No description provided for @portalDe.
  ///
  /// In es, this message translates to:
  /// **'Portal {rol}'**
  String portalDe(Object rol);

  /// No description provided for @certificadosMisTitulo.
  ///
  /// In es, this message translates to:
  /// **'Mis Certificados'**
  String get certificadosMisTitulo;

  /// No description provided for @certificadosMisSubtitulo.
  ///
  /// In es, this message translates to:
  /// **'Certificados emitidos por sus LXD al completar una Ruta de Impacto'**
  String get certificadosMisSubtitulo;

  /// No description provided for @certificadosVacio.
  ///
  /// In es, this message translates to:
  /// **'Aún no tiene certificados.\nComplete sus cursos para obtenerlos.'**
  String get certificadosVacio;

  /// No description provided for @certificadoRutaDe.
  ///
  /// In es, this message translates to:
  /// **'Ruta de Impacto · {laboratorio}'**
  String certificadoRutaDe(Object laboratorio);

  /// No description provided for @certificadoVerPdf.
  ///
  /// In es, this message translates to:
  /// **'Ver PDF'**
  String get certificadoVerPdf;

  /// No description provided for @comunCompartir.
  ///
  /// In es, this message translates to:
  /// **'Compartir'**
  String get comunCompartir;

  /// No description provided for @perfilMiembroDesde.
  ///
  /// In es, this message translates to:
  /// **'Miembro activo desde {anio}'**
  String perfilMiembroDesde(Object anio);

  /// No description provided for @perfilMiembroComunidad.
  ///
  /// In es, this message translates to:
  /// **'Miembro de la comunidad'**
  String get perfilMiembroComunidad;

  /// No description provided for @perfilBuscarPortal.
  ///
  /// In es, this message translates to:
  /// **'Buscar en el portal'**
  String get perfilBuscarPortal;

  /// No description provided for @perfilDatosPersonales.
  ///
  /// In es, this message translates to:
  /// **'Datos personales'**
  String get perfilDatosPersonales;

  /// No description provided for @perfilCedula.
  ///
  /// In es, this message translates to:
  /// **'Cédula'**
  String get perfilCedula;

  /// No description provided for @perfilTelefonoEtiqueta.
  ///
  /// In es, this message translates to:
  /// **'Teléfono'**
  String get perfilTelefonoEtiqueta;

  /// No description provided for @perfilCorreoEtiqueta.
  ///
  /// In es, this message translates to:
  /// **'Correo'**
  String get perfilCorreoEtiqueta;

  /// No description provided for @perfilCiudad.
  ///
  /// In es, this message translates to:
  /// **'Ciudad'**
  String get perfilCiudad;

  /// No description provided for @perfilCarrera.
  ///
  /// In es, this message translates to:
  /// **'Carrera'**
  String get perfilCarrera;

  /// No description provided for @perfilVidaEduxaction.
  ///
  /// In es, this message translates to:
  /// **'Vida eduXaction'**
  String get perfilVidaEduxaction;

  /// No description provided for @perfilEquipo.
  ///
  /// In es, this message translates to:
  /// **'Equipo'**
  String get perfilEquipo;

  /// No description provided for @perfilEmpresaPatrocinadora.
  ///
  /// In es, this message translates to:
  /// **'Empresa patrocinadora'**
  String get perfilEmpresaPatrocinadora;

  /// No description provided for @perfilCursosActivos.
  ///
  /// In es, this message translates to:
  /// **'Cursos activos'**
  String get perfilCursosActivos;

  /// No description provided for @perfilLeccionesCompletadas.
  ///
  /// In es, this message translates to:
  /// **'Lecciones completadas'**
  String get perfilLeccionesCompletadas;

  /// No description provided for @perfilEditar.
  ///
  /// In es, this message translates to:
  /// **'Editar perfil'**
  String get perfilEditar;

  /// No description provided for @perfilSinProyecto.
  ///
  /// In es, this message translates to:
  /// **'Aún no tiene proyecto asignado.'**
  String get perfilSinProyecto;

  /// No description provided for @perfilMiProyecto.
  ///
  /// In es, this message translates to:
  /// **'MI PROYECTO'**
  String get perfilMiProyecto;

  /// No description provided for @certificadosVacioRuta.
  ///
  /// In es, this message translates to:
  /// **'Aún no tiene certificados. Complete una Ruta de Impacto para obtener el primero.'**
  String get certificadosVacioRuta;

  /// No description provided for @certificadosFaltaPoco.
  ///
  /// In es, this message translates to:
  /// **'Le falta poco para su primer certificado: \"{nombre}\".'**
  String certificadosFaltaPoco(Object nombre);

  /// No description provided for @leccionesDeTotal.
  ///
  /// In es, this message translates to:
  /// **'{completadas} de {total} lecciones'**
  String leccionesDeTotal(Object completadas, Object total);

  /// No description provided for @certificadoDescargar.
  ///
  /// In es, this message translates to:
  /// **'Descargar certificado'**
  String get certificadoDescargar;

  /// No description provided for @perfilSeleccioneFoto.
  ///
  /// In es, this message translates to:
  /// **'Seleccione una foto'**
  String get perfilSeleccioneFoto;

  /// No description provided for @perfilFotoFormato.
  ///
  /// In es, this message translates to:
  /// **'Use una foto en JPG o PNG.'**
  String get perfilFotoFormato;

  /// No description provided for @perfilFotoPesada.
  ///
  /// In es, this message translates to:
  /// **'La foto pesa más de 25 MB. Elija una más liviana.'**
  String get perfilFotoPesada;

  /// No description provided for @perfilTelefonoInvalido.
  ///
  /// In es, this message translates to:
  /// **'Ingrese un teléfono válido (mínimo 7 dígitos).'**
  String get perfilTelefonoInvalido;

  /// No description provided for @perfilActualizado.
  ///
  /// In es, this message translates to:
  /// **'Perfil actualizado ✓'**
  String get perfilActualizado;

  /// No description provided for @perfilSubiendoFoto.
  ///
  /// In es, this message translates to:
  /// **'Subiendo foto…'**
  String get perfilSubiendoFoto;

  /// No description provided for @perfilCambiarFoto.
  ///
  /// In es, this message translates to:
  /// **'Cambiar foto de perfil'**
  String get perfilCambiarFoto;

  /// No description provided for @perfilAsignaAdmin.
  ///
  /// In es, this message translates to:
  /// **'Cédula, universidad, equipo, proyecto y empresa patrocinadora los asigna su administrador.'**
  String get perfilAsignaAdmin;

  /// No description provided for @certificadoEmitidoDetalle.
  ///
  /// In es, this message translates to:
  /// **'Emitido el {fecha} · Por: {emisor} · Código: {codigo}'**
  String certificadoEmitidoDetalle(Object fecha, Object emisor, Object codigo);

  /// No description provided for @certificadoEmitidoEl.
  ///
  /// In es, this message translates to:
  /// **'Emitido el {fecha}'**
  String certificadoEmitidoEl(Object fecha);

  /// No description provided for @dashboardSinProyecto.
  ///
  /// In es, this message translates to:
  /// **'Aún no tiene proyecto asignado'**
  String get dashboardSinProyecto;

  /// No description provided for @dashboardTodoPorEmpezar.
  ///
  /// In es, this message translates to:
  /// **'Todo por empezar'**
  String get dashboardTodoPorEmpezar;

  /// No description provided for @dashboardSinCursos.
  ///
  /// In es, this message translates to:
  /// **'Aún no tiene cursos asignados. Cuando su administrador le asigne uno, su progreso aparecerá aquí.'**
  String get dashboardSinCursos;

  /// No description provided for @comunActualizar.
  ///
  /// In es, this message translates to:
  /// **'Actualizar'**
  String get comunActualizar;

  /// No description provided for @dashboardProgresoGeneral.
  ///
  /// In es, this message translates to:
  /// **'Progreso general'**
  String get dashboardProgresoGeneral;

  /// No description provided for @dashboardTodoCompletado.
  ///
  /// In es, this message translates to:
  /// **'Ya completó todos sus cursos asignados.'**
  String get dashboardTodoCompletado;

  /// No description provided for @dashboardContinueDonde.
  ///
  /// In es, this message translates to:
  /// **'CONTINÚE DONDE IBA'**
  String get dashboardContinueDonde;

  /// No description provided for @comunContinuar.
  ///
  /// In es, this message translates to:
  /// **'Continuar'**
  String get comunContinuar;

  /// No description provided for @dashboardProgresoPorCurso.
  ///
  /// In es, this message translates to:
  /// **'Progreso por curso'**
  String get dashboardProgresoPorCurso;

  /// No description provided for @dashboardContinuarCurso.
  ///
  /// In es, this message translates to:
  /// **'Continuar \"{nombre}\"'**
  String dashboardContinuarCurso(Object nombre);

  /// No description provided for @cursoRutaNationalExpo.
  ///
  /// In es, this message translates to:
  /// **'Ruta National Expo'**
  String get cursoRutaNationalExpo;

  /// No description provided for @dashboardChecklistExpo.
  ///
  /// In es, this message translates to:
  /// **'Checklist National Expo'**
  String get dashboardChecklistExpo;

  /// No description provided for @dashboardPendientes.
  ///
  /// In es, this message translates to:
  /// **'Pendientes'**
  String get dashboardPendientes;

  /// No description provided for @dashboardAlDia.
  ///
  /// In es, this message translates to:
  /// **'¡Está al día! No tiene pendientes.'**
  String get dashboardAlDia;

  /// No description provided for @dashboardChecklistTitulo.
  ///
  /// In es, this message translates to:
  /// **'Checklist RUTA NATIONAL EXPO'**
  String get dashboardChecklistTitulo;

  /// No description provided for @dashboardActividadReciente.
  ///
  /// In es, this message translates to:
  /// **'Actividad reciente'**
  String get dashboardActividadReciente;

  /// No description provided for @dashboardSinCalificadas.
  ///
  /// In es, this message translates to:
  /// **'Aún no tiene entregas calificadas.'**
  String get dashboardSinCalificadas;

  /// No description provided for @dashboardSuProyecto.
  ///
  /// In es, this message translates to:
  /// **'Su proyecto'**
  String get dashboardSuProyecto;

  /// No description provided for @calendarioNoTrajo.
  ///
  /// In es, this message translates to:
  /// **'No pudimos traer sus eventos.'**
  String get calendarioNoTrajo;

  /// No description provided for @calendarioCargando.
  ///
  /// In es, this message translates to:
  /// **'Cargando sus eventos…'**
  String get calendarioCargando;

  /// No description provided for @calendarioSubtitulo.
  ///
  /// In es, this message translates to:
  /// **'Sesiones sincrónicas de sus cursos y eventos de su Ruta de Impacto.'**
  String get calendarioSubtitulo;

  /// No description provided for @calendarioProximos.
  ///
  /// In es, this message translates to:
  /// **'Próximos eventos'**
  String get calendarioProximos;

  /// No description provided for @calendarioSinProximos.
  ///
  /// In es, this message translates to:
  /// **'No tiene próximos eventos.'**
  String get calendarioSinProximos;

  /// No description provided for @calendarioAgendaDespejada.
  ///
  /// In es, this message translates to:
  /// **'Agenda despejada'**
  String get calendarioAgendaDespejada;

  /// No description provided for @calendarioAgendaDespejadaTexto.
  ///
  /// In es, this message translates to:
  /// **'No tiene sesiones ni entregas programadas este mes.'**
  String get calendarioAgendaDespejadaTexto;

  /// No description provided for @comunActualizado.
  ///
  /// In es, this message translates to:
  /// **'Actualizado'**
  String get comunActualizado;

  /// No description provided for @cursoHorasEstimadas.
  ///
  /// In es, this message translates to:
  /// **'{horas} h estimadas'**
  String cursoHorasEstimadas(Object horas);

  /// No description provided for @cursoMinutosEstimados.
  ///
  /// In es, this message translates to:
  /// **'{minutos} min estimados'**
  String cursoMinutosEstimados(Object minutos);

  /// No description provided for @cursosAsignados.
  ///
  /// In es, this message translates to:
  /// **'Cursos asignados'**
  String get cursosAsignados;

  /// No description provided for @cursosCargando.
  ///
  /// In es, this message translates to:
  /// **'Cargando sus cursos…'**
  String get cursosCargando;

  /// No description provided for @cursosNoTrajo.
  ///
  /// In es, this message translates to:
  /// **'No pudimos traer sus cursos.'**
  String get cursosNoTrajo;

  /// No description provided for @cursosSubtitulo.
  ///
  /// In es, this message translates to:
  /// **'Cursos de laboratorio asignados por su administrador, más la ruta de preparación de su equipo para National Expo.'**
  String get cursosSubtitulo;

  /// No description provided for @cursosBuscar.
  ///
  /// In es, this message translates to:
  /// **'Buscar curso o laboratorio'**
  String get cursosBuscar;

  /// No description provided for @cursosSinAsignados.
  ///
  /// In es, this message translates to:
  /// **'Sin cursos asignados'**
  String get cursosSinAsignados;

  /// No description provided for @cursosSinAsignadosTexto.
  ///
  /// In es, this message translates to:
  /// **'Aún no tiene cursos asignados por su administrador.'**
  String get cursosSinAsignadosTexto;

  /// No description provided for @cursosNingunoCoincide.
  ///
  /// In es, this message translates to:
  /// **'Ningún curso coincide con su búsqueda. Pruebe con otro término.'**
  String get cursosNingunoCoincide;

  /// No description provided for @comunLimpiarBusqueda.
  ///
  /// In es, this message translates to:
  /// **'Limpiar búsqueda'**
  String get comunLimpiarBusqueda;

  /// No description provided for @cursoModulos.
  ///
  /// In es, this message translates to:
  /// **'{cantidad, plural, =1{1 módulo} other{{cantidad} módulos}}'**
  String cursoModulos(int cantidad);

  /// No description provided for @cursoLecciones.
  ///
  /// In es, this message translates to:
  /// **'{cantidad, plural, =1{1 lección} other{{cantidad} lecciones}}'**
  String cursoLecciones(int cantidad);

  /// No description provided for @cursoCertificado.
  ///
  /// In es, this message translates to:
  /// **'Certificado'**
  String get cursoCertificado;

  /// No description provided for @cursoProgresoDetalle.
  ///
  /// In es, this message translates to:
  /// **'{hechas} de {total} lecciones · {porcentaje}%'**
  String cursoProgresoDetalle(Object hechas, Object total, Object porcentaje);

  /// No description provided for @cursoTrabajoEquipo.
  ///
  /// In es, this message translates to:
  /// **'Trabajo en equipo'**
  String get cursoTrabajoEquipo;

  /// No description provided for @comunComenzar.
  ///
  /// In es, this message translates to:
  /// **'Comenzar'**
  String get comunComenzar;

  /// No description provided for @dashboardSemanaDel.
  ///
  /// In es, this message translates to:
  /// **'Semana del {desde} al {hasta}'**
  String dashboardSemanaDel(Object desde, Object hasta);

  /// No description provided for @dashboardHola.
  ///
  /// In es, this message translates to:
  /// **'Hola, {nombre}'**
  String dashboardHola(Object nombre);

  /// No description provided for @dashboardProyecto.
  ///
  /// In es, this message translates to:
  /// **'Proyecto {proyecto}'**
  String dashboardProyecto(Object proyecto);

  /// No description provided for @dashboardCursosActivos.
  ///
  /// In es, this message translates to:
  /// **'{cantidad} cursos activos'**
  String dashboardCursosActivos(int cantidad);

  /// No description provided for @dashboardLaboratorios.
  ///
  /// In es, this message translates to:
  /// **'{cantidad} laboratorios'**
  String dashboardLaboratorios(int cantidad);

  /// No description provided for @dashboardFaseVencida.
  ///
  /// In es, this message translates to:
  /// **'Fase vencida: {fase}'**
  String dashboardFaseVencida(Object fase);

  /// No description provided for @dashboardConfirmarMentoria.
  ///
  /// In es, this message translates to:
  /// **'Confirmar mentoría: {fase}'**
  String dashboardConfirmarMentoria(Object fase);

  /// No description provided for @comunFase.
  ///
  /// In es, this message translates to:
  /// **'Fase'**
  String get comunFase;

  /// No description provided for @dashboardCalificadoEl.
  ///
  /// In es, this message translates to:
  /// **'Calificado el {fecha}'**
  String dashboardCalificadoEl(Object fecha);

  /// No description provided for @cursoDocente.
  ///
  /// In es, this message translates to:
  /// **'Docente: {docente}'**
  String cursoDocente(Object docente);

  /// No description provided for @cursoGeneraCertificado.
  ///
  /// In es, this message translates to:
  /// **'Genera certificado'**
  String get cursoGeneraCertificado;

  /// No description provided for @cursoObjetivos.
  ///
  /// In es, this message translates to:
  /// **'Objetivos'**
  String get cursoObjetivos;

  /// No description provided for @cursoSoloLectura.
  ///
  /// In es, this message translates to:
  /// **'Está viendo el progreso de otro estudiante — modo de solo lectura.'**
  String get cursoSoloLectura;

  /// No description provided for @cursoSinContenido.
  ///
  /// In es, this message translates to:
  /// **'Este curso todavía no tiene contenido publicado.'**
  String get cursoSinContenido;

  /// No description provided for @cursoMisEntregas.
  ///
  /// In es, this message translates to:
  /// **'Mis entregas'**
  String get cursoMisEntregas;

  /// No description provided for @leccionVideoYoutube.
  ///
  /// In es, this message translates to:
  /// **'Video de YouTube'**
  String get leccionVideoYoutube;

  /// No description provided for @leccionCompletada.
  ///
  /// In es, this message translates to:
  /// **'Completada'**
  String get leccionCompletada;

  /// No description provided for @leccionMarcarPendiente.
  ///
  /// In es, this message translates to:
  /// **'Marcar como pendiente'**
  String get leccionMarcarPendiente;

  /// No description provided for @leccionMarcarCompletada.
  ///
  /// In es, this message translates to:
  /// **'Marcar como completada'**
  String get leccionMarcarCompletada;

  /// No description provided for @rutaCompletada.
  ///
  /// In es, this message translates to:
  /// **'¡Completó la Ruta de Impacto! 🎉'**
  String get rutaCompletada;

  /// No description provided for @leccionCompletadaExclama.
  ///
  /// In es, this message translates to:
  /// **'¡Lección completada!'**
  String get leccionCompletadaExclama;

  /// No description provided for @cursoNoPuedeResponder.
  ///
  /// In es, this message translates to:
  /// **'Está viendo el progreso de otro estudiante — no puede responder en su nombre.'**
  String get cursoNoPuedeResponder;

  /// No description provided for @leccionSinMaterial.
  ///
  /// In es, this message translates to:
  /// **'Esta lección todavía no tiene material cargado.'**
  String get leccionSinMaterial;

  /// No description provided for @leccionSinEnlace.
  ///
  /// In es, this message translates to:
  /// **'Esta lección no tiene un enlace válido.'**
  String get leccionSinEnlace;

  /// No description provided for @leccionEnlaceNoAbre.
  ///
  /// In es, this message translates to:
  /// **'No se pudo abrir el enlace.'**
  String get leccionEnlaceNoAbre;

  /// No description provided for @quizCalificar.
  ///
  /// In es, this message translates to:
  /// **'Calificar'**
  String get quizCalificar;

  /// No description provided for @quizCalificando.
  ///
  /// In es, this message translates to:
  /// **'Calificando…'**
  String get quizCalificando;

  /// No description provided for @quizSinPreguntas.
  ///
  /// In es, this message translates to:
  /// **'Este quiz todavía no tiene preguntas.'**
  String get quizSinPreguntas;

  /// No description provided for @quizAprobado.
  ///
  /// In es, this message translates to:
  /// **'¡Aprobado! {puntaje}%'**
  String quizAprobado(Object puntaje);

  /// No description provided for @quizPuntaje.
  ///
  /// In es, this message translates to:
  /// **'Puntaje: {puntaje}% (mínimo 60%)'**
  String quizPuntaje(Object puntaje);

  /// No description provided for @quizVerdadero.
  ///
  /// In es, this message translates to:
  /// **'Verdadero'**
  String get quizVerdadero;

  /// No description provided for @quizFalso.
  ///
  /// In es, this message translates to:
  /// **'Falso'**
  String get quizFalso;

  /// No description provided for @quizCompleteFrase.
  ///
  /// In es, this message translates to:
  /// **'Complete la frase…'**
  String get quizCompleteFrase;

  /// No description provided for @quizSuRespuesta.
  ///
  /// In es, this message translates to:
  /// **'Su respuesta…'**
  String get quizSuRespuesta;

  /// No description provided for @quizUseFlechas.
  ///
  /// In es, this message translates to:
  /// **'Use las flechas para ordenar:'**
  String get quizUseFlechas;

  /// No description provided for @encuestaNombreTarea.
  ///
  /// In es, this message translates to:
  /// **'Encuesta: {leccion}'**
  String encuestaNombreTarea(Object leccion);

  /// No description provided for @encuestaGracias.
  ///
  /// In es, this message translates to:
  /// **'¡Gracias por responder!'**
  String get encuestaGracias;

  /// No description provided for @comunEnviar.
  ///
  /// In es, this message translates to:
  /// **'Enviar'**
  String get comunEnviar;

  /// No description provided for @encuestaOpinion.
  ///
  /// In es, this message translates to:
  /// **'Su opinión nos ayuda a mejorar 💛'**
  String get encuestaOpinion;

  /// No description provided for @actividadArchivoObligatorio.
  ///
  /// In es, this message translates to:
  /// **'Archivo obligatorio'**
  String get actividadArchivoObligatorio;

  /// No description provided for @actividadTextoObligatorio.
  ///
  /// In es, this message translates to:
  /// **'Texto obligatorio'**
  String get actividadTextoObligatorio;

  /// No description provided for @actividadRubrica.
  ///
  /// In es, this message translates to:
  /// **'Rúbrica de evaluación'**
  String get actividadRubrica;

  /// No description provided for @actividadSuEntrega.
  ///
  /// In es, this message translates to:
  /// **'Su entrega'**
  String get actividadSuEntrega;

  /// No description provided for @actividadRetroalimentacion.
  ///
  /// In es, this message translates to:
  /// **'Retroalimentación: {retro}'**
  String actividadRetroalimentacion(Object retro);

  /// No description provided for @actividadEntregar.
  ///
  /// In es, this message translates to:
  /// **'Entregar actividad'**
  String get actividadEntregar;

  /// No description provided for @actividadNuevaEntrega.
  ///
  /// In es, this message translates to:
  /// **'Nueva entrega'**
  String get actividadNuevaEntrega;

  /// No description provided for @actividadRequiereTexto.
  ///
  /// In es, this message translates to:
  /// **'Esta actividad requiere una respuesta escrita.'**
  String get actividadRequiereTexto;

  /// No description provided for @actividadRequiereArchivo.
  ///
  /// In es, this message translates to:
  /// **'Esta actividad requiere adjuntar un archivo.'**
  String get actividadRequiereArchivo;

  /// No description provided for @actividadEntregada.
  ///
  /// In es, this message translates to:
  /// **'Actividad entregada ✓'**
  String get actividadEntregada;

  /// No description provided for @actividadEntregarTitulo.
  ///
  /// In es, this message translates to:
  /// **'Entregar: {leccion}'**
  String actividadEntregarTitulo(Object leccion);

  /// No description provided for @actividadRespuestaObligatoria.
  ///
  /// In es, this message translates to:
  /// **'Su respuesta (obligatoria)'**
  String get actividadRespuestaObligatoria;

  /// No description provided for @actividadComentarioOpcional.
  ///
  /// In es, this message translates to:
  /// **'Comentario (opcional)'**
  String get actividadComentarioOpcional;

  /// No description provided for @actividadSinEntregas.
  ///
  /// In es, this message translates to:
  /// **'Todavía no ha realizado ninguna entrega en este curso.'**
  String get actividadSinEntregas;

  /// No description provided for @actividadEntregaLibre.
  ///
  /// In es, this message translates to:
  /// **'Nueva entrega libre'**
  String get actividadEntregaLibre;

  /// No description provided for @actividadPongaNombre.
  ///
  /// In es, this message translates to:
  /// **'Póngale un nombre a la entrega.'**
  String get actividadPongaNombre;

  /// No description provided for @actividadEntregaEnviada.
  ///
  /// In es, this message translates to:
  /// **'Entrega enviada ✓'**
  String get actividadEntregaEnviada;

  /// No description provided for @actividadNombreTarea.
  ///
  /// In es, this message translates to:
  /// **'Nombre de la tarea'**
  String get actividadNombreTarea;

  /// No description provided for @comunComentario.
  ///
  /// In es, this message translates to:
  /// **'Comentario'**
  String get comunComentario;

  /// No description provided for @actividadLimite.
  ///
  /// In es, this message translates to:
  /// **'Límite: {fecha}'**
  String actividadLimite(Object fecha);

  /// No description provided for @labsEnLaRed.
  ///
  /// In es, this message translates to:
  /// **'{cantidad} en la red'**
  String labsEnLaRed(Object cantidad);

  /// No description provided for @labsQueEs.
  ///
  /// In es, this message translates to:
  /// **'Un laboratorio es un área de trabajo de eduXaction Colombia: reúne una Ruta de Impacto por fases, cursos y un LXD que la acompaña. Entre al suyo para ver qué sigue.'**
  String get labsQueEs;

  /// No description provided for @labsSinAsignados.
  ///
  /// In es, this message translates to:
  /// **'Sin laboratorios asignados'**
  String get labsSinAsignados;

  /// No description provided for @labsSinAsignadosTexto.
  ///
  /// In es, this message translates to:
  /// **'Su administrador todavía no le ha asignado un laboratorio. Sin uno no tiene Ruta de Impacto ni cursos de área.'**
  String get labsSinAsignadosTexto;

  /// No description provided for @labsOtros.
  ///
  /// In es, this message translates to:
  /// **'OTROS LABORATORIOS DE LA RED'**
  String get labsOtros;

  /// No description provided for @labsSolicite.
  ///
  /// In es, this message translates to:
  /// **'Solicite a su administrador que le asigne uno si su proyecto lo necesita.'**
  String get labsSolicite;

  /// No description provided for @rutaEntregaVencida.
  ///
  /// In es, this message translates to:
  /// **'ENTREGA VENCIDA'**
  String get rutaEntregaVencida;

  /// No description provided for @rutaEnCurso.
  ///
  /// In es, this message translates to:
  /// **'EN CURSO'**
  String get rutaEnCurso;

  /// No description provided for @rutaFaseCompletaDe.
  ///
  /// In es, this message translates to:
  /// **'Fase {total} de {total} completa'**
  String rutaFaseCompletaDe(Object total);

  /// No description provided for @rutaFaseEnCursoDe.
  ///
  /// In es, this message translates to:
  /// **'Fase {fase} de {total} en curso'**
  String rutaFaseEnCursoDe(Object fase, Object total);

  /// No description provided for @rutaSinModulos.
  ///
  /// In es, this message translates to:
  /// **'Sin módulos aún'**
  String get rutaSinModulos;

  /// No description provided for @rutaModulosFraccion.
  ///
  /// In es, this message translates to:
  /// **'{hechos}/{total} módulos'**
  String rutaModulosFraccion(Object hechos, Object total);

  /// No description provided for @rutaFases.
  ///
  /// In es, this message translates to:
  /// **'{cantidad, plural, =1{1 fase} other{{cantidad} fases}}'**
  String rutaFases(int cantidad);

  /// No description provided for @rutaCursos.
  ///
  /// In es, this message translates to:
  /// **'{cantidad, plural, =1{1 curso} other{{cantidad} cursos}}'**
  String rutaCursos(int cantidad);

  /// No description provided for @rutaSinLxd.
  ///
  /// In es, this message translates to:
  /// **'Sin LXD asignado'**
  String get rutaSinLxd;

  /// No description provided for @rutaLxd.
  ///
  /// In es, this message translates to:
  /// **'LXD: {nombre}'**
  String rutaLxd(Object nombre);

  /// No description provided for @comunEntrar.
  ///
  /// In es, this message translates to:
  /// **'Entrar'**
  String get comunEntrar;

  /// No description provided for @rutaUnEquipo.
  ///
  /// In es, this message translates to:
  /// **'1 equipo en la red'**
  String get rutaUnEquipo;

  /// No description provided for @rutaEquipos.
  ///
  /// In es, this message translates to:
  /// **'{cantidad} equipos en la red'**
  String rutaEquipos(Object cantidad);

  /// No description provided for @labNoEncontrado.
  ///
  /// In es, this message translates to:
  /// **'Laboratorio no encontrado'**
  String get labNoEncontrado;

  /// No description provided for @labNoEncontradoTexto.
  ///
  /// In es, this message translates to:
  /// **'Puede que ya no exista o que el enlace esté mal escrito.'**
  String get labNoEncontradoTexto;

  /// No description provided for @labsTodos.
  ///
  /// In es, this message translates to:
  /// **'Todos los laboratorios'**
  String get labsTodos;

  /// No description provided for @rutaMayus.
  ///
  /// In es, this message translates to:
  /// **'RUTA DE IMPACTO'**
  String get rutaMayus;

  /// No description provided for @rutaFasesEnOrden.
  ///
  /// In es, this message translates to:
  /// **'Las fases se abren en orden. Su LXD publica el contenido de cada una.'**
  String get rutaFasesEnOrden;

  /// No description provided for @rutaSuAvance.
  ///
  /// In es, this message translates to:
  /// **'Su avance'**
  String get rutaSuAvance;

  /// No description provided for @rutaFaseDe.
  ///
  /// In es, this message translates to:
  /// **'Fase {fase} de {total}'**
  String rutaFaseDe(Object fase, Object total);

  /// No description provided for @rutaModulosDeTotal.
  ///
  /// In es, this message translates to:
  /// **'{hechos} de {total} módulos'**
  String rutaModulosDeTotal(Object hechos, Object total);

  /// No description provided for @rutaFasesEnRuta.
  ///
  /// In es, this message translates to:
  /// **'Fases en la ruta'**
  String get rutaFasesEnRuta;

  /// No description provided for @rutaModulosPublicados.
  ///
  /// In es, this message translates to:
  /// **'Módulos publicados'**
  String get rutaModulosPublicados;

  /// No description provided for @rutaCursosLab.
  ///
  /// In es, this message translates to:
  /// **'Cursos del laboratorio'**
  String get rutaCursosLab;

  /// No description provided for @rutaHorasEstimadas.
  ///
  /// In es, this message translates to:
  /// **'Horas estimadas'**
  String get rutaHorasEstimadas;

  /// No description provided for @rutaSinFases.
  ///
  /// In es, this message translates to:
  /// **'Este laboratorio todavía no tiene fases publicadas.'**
  String get rutaSinFases;

  /// No description provided for @rutaFaseNumero.
  ///
  /// In es, this message translates to:
  /// **'Fase {numero}'**
  String rutaFaseNumero(Object numero);

  /// No description provided for @rutaEstadoCompleta.
  ///
  /// In es, this message translates to:
  /// **'Completa'**
  String get rutaEstadoCompleta;

  /// No description provided for @rutaEstadoVencida.
  ///
  /// In es, this message translates to:
  /// **'Vencida'**
  String get rutaEstadoVencida;

  /// No description provided for @rutaEstadoDisponible.
  ///
  /// In es, this message translates to:
  /// **'Disponible'**
  String get rutaEstadoDisponible;

  /// No description provided for @rutaEstadoBloqueada.
  ///
  /// In es, this message translates to:
  /// **'Bloqueada'**
  String get rutaEstadoBloqueada;

  /// No description provided for @rutaSeAbreCuando.
  ///
  /// In es, this message translates to:
  /// **'Se abre cuando complete la Fase {fase}'**
  String rutaSeAbreCuando(Object fase);

  /// No description provided for @rutaLxdPublicara.
  ///
  /// In es, this message translates to:
  /// **'Su LXD publicará el contenido de esta fase.'**
  String get rutaLxdPublicara;

  /// No description provided for @rutaLxdNoPublico.
  ///
  /// In es, this message translates to:
  /// **'Su LXD aún no ha publicado el contenido de esta fase.'**
  String get rutaLxdNoPublico;

  /// No description provided for @rutaSinModulosPublicados.
  ///
  /// In es, this message translates to:
  /// **'Sin módulos publicados'**
  String get rutaSinModulosPublicados;

  /// No description provided for @rutaEmpezarFase.
  ///
  /// In es, this message translates to:
  /// **'Empezar la fase'**
  String get rutaEmpezarFase;

  /// No description provided for @rutaContinuarFase.
  ///
  /// In es, this message translates to:
  /// **'Continuar la fase'**
  String get rutaContinuarFase;

  /// No description provided for @rutaSinCursos.
  ///
  /// In es, this message translates to:
  /// **'Este laboratorio todavía no tiene cursos publicados. Su LXD los abrirá junto con la Fase 1.'**
  String get rutaSinCursos;

  /// No description provided for @rutaSuLxd.
  ///
  /// In es, this message translates to:
  /// **'Su LXD'**
  String get rutaSuLxd;

  /// No description provided for @rutaLabSinLxd.
  ///
  /// In es, this message translates to:
  /// **'Este laboratorio todavía no tiene un LXD asignado.'**
  String get rutaLabSinLxd;

  /// No description provided for @rutaLxdNombreLargo.
  ///
  /// In es, this message translates to:
  /// **'Learning Experience Designer'**
  String get rutaLxdNombreLargo;

  /// No description provided for @rutaSinHorario.
  ///
  /// In es, this message translates to:
  /// **'Sin horario publicado'**
  String get rutaSinHorario;

  /// No description provided for @rutaAgendarMentoria.
  ///
  /// In es, this message translates to:
  /// **'Agendar mentoría'**
  String get rutaAgendarMentoria;

  /// No description provided for @rutaLxdSinDisponibilidad.
  ///
  /// In es, this message translates to:
  /// **'Su LXD todavía no publicó su disponibilidad.'**
  String get rutaLxdSinDisponibilidad;

  /// No description provided for @rutaDisponibilidadDe.
  ///
  /// In es, this message translates to:
  /// **'Disponibilidad de {nombre}'**
  String rutaDisponibilidadDe(Object nombre);

  /// No description provided for @rutaEscribale.
  ///
  /// In es, this message translates to:
  /// **'Escríbale para coordinar el horario exacto de {nombre}.'**
  String rutaEscribale(Object nombre);

  /// No description provided for @rutaEscribirCorreo.
  ///
  /// In es, this message translates to:
  /// **'Escribir correo'**
  String get rutaEscribirCorreo;

  /// No description provided for @rutaSubtitulo.
  ///
  /// In es, this message translates to:
  /// **'Las fases de su laboratorio, sus objetivos y lo que falta para llegar a National Expo.'**
  String get rutaSubtitulo;

  /// No description provided for @rutaSinLab.
  ///
  /// In es, this message translates to:
  /// **'Sin laboratorio asignado'**
  String get rutaSinLab;

  /// No description provided for @rutaSinLabTexto.
  ///
  /// In es, this message translates to:
  /// **'Su administrador aún no le ha asignado ningún laboratorio.'**
  String get rutaSinLabTexto;

  /// No description provided for @rutaLabSinFases.
  ///
  /// In es, this message translates to:
  /// **'Laboratorio sin fases'**
  String get rutaLabSinFases;

  /// No description provided for @rutaLabSinFasesTexto.
  ///
  /// In es, this message translates to:
  /// **'El {laboratorio} todavía no ha publicado sus fases. Su LXD las abrirá cuando el contenido esté listo.'**
  String rutaLabSinFasesTexto(Object laboratorio);

  /// No description provided for @rutaVerOtroLab.
  ///
  /// In es, this message translates to:
  /// **'Ver otro laboratorio'**
  String get rutaVerOtroLab;

  /// No description provided for @rutaEstadoSinAbrir.
  ///
  /// In es, this message translates to:
  /// **'Sin abrir'**
  String get rutaEstadoSinAbrir;

  /// No description provided for @rutaEstadoEnCurso.
  ///
  /// In es, this message translates to:
  /// **'En curso'**
  String get rutaEstadoEnCurso;

  /// No description provided for @rutaModuloNumero.
  ///
  /// In es, this message translates to:
  /// **'Módulo {numero}'**
  String rutaModuloNumero(Object numero);

  /// No description provided for @rutaCompleteAnterior.
  ///
  /// In es, this message translates to:
  /// **'Complete el módulo anterior para desbloquear \"{modulo}\".'**
  String rutaCompleteAnterior(Object modulo);

  /// No description provided for @rutaBloqueado.
  ///
  /// In es, this message translates to:
  /// **'Bloqueado'**
  String get rutaBloqueado;

  /// No description provided for @rutaModuloMentoria.
  ///
  /// In es, this message translates to:
  /// **'Módulo de mentoría'**
  String get rutaModuloMentoria;

  /// No description provided for @rutaSinContenido.
  ///
  /// In es, this message translates to:
  /// **'Sin contenido aún'**
  String get rutaSinContenido;

  /// No description provided for @rutaElementos.
  ///
  /// In es, this message translates to:
  /// **'{cantidad} elemento(s)'**
  String rutaElementos(int cantidad);

  /// No description provided for @rutaCompleto.
  ///
  /// In es, this message translates to:
  /// **'Completo'**
  String get rutaCompleto;

  /// No description provided for @rutaMetaAnio.
  ///
  /// In es, this message translates to:
  /// **'META DEL AÑO'**
  String get rutaMetaAnio;

  /// No description provided for @rutaSinEquipo.
  ///
  /// In es, this message translates to:
  /// **'Aún no pertenece a un equipo.'**
  String get rutaSinEquipo;

  /// No description provided for @rutaChecklistEquipo.
  ///
  /// In es, this message translates to:
  /// **'Checklist del equipo'**
  String get rutaChecklistEquipo;

  /// No description provided for @rutaModulo.
  ///
  /// In es, this message translates to:
  /// **'Módulo'**
  String get rutaModulo;

  /// No description provided for @rutaModuloNoExiste.
  ///
  /// In es, this message translates to:
  /// **'Este módulo ya no existe o el enlace está mal escrito.'**
  String get rutaModuloNoExiste;

  /// No description provided for @rutaEntregasLecturas.
  ///
  /// In es, this message translates to:
  /// **'Entregas y lecturas'**
  String get rutaEntregasLecturas;

  /// No description provided for @rutaModuloSinContenido.
  ///
  /// In es, this message translates to:
  /// **'Su administrador aún no agregó contenido a este módulo.'**
  String get rutaModuloSinContenido;

  /// No description provided for @rutaEstaFase.
  ///
  /// In es, this message translates to:
  /// **'esta fase'**
  String get rutaEstaFase;

  /// No description provided for @rutaReunase.
  ///
  /// In es, this message translates to:
  /// **'Reúnase con su mentor para cerrar {fase}.'**
  String rutaReunase(Object fase);

  /// No description provided for @rutaSinEnlaceReunion.
  ///
  /// In es, this message translates to:
  /// **'Su administrador todavía no configuró el enlace de la reunión.'**
  String get rutaSinEnlaceReunion;

  /// No description provided for @rutaEntrega.
  ///
  /// In es, this message translates to:
  /// **'Entrega'**
  String get rutaEntrega;

  /// No description provided for @rutaLecturaSinMaterial.
  ///
  /// In es, this message translates to:
  /// **'Esta lectura todavía no tiene material.'**
  String get rutaLecturaSinMaterial;

  /// No description provided for @labsAsignadosEnRed.
  ///
  /// In es, this message translates to:
  /// **'{asignados, plural, =1{1 laboratorio asignado} other{{asignados} laboratorios asignados}} · {total} en la red'**
  String labsAsignadosEnRed(int asignados, Object total);

  /// No description provided for @rutaFechaPrevista.
  ///
  /// In es, this message translates to:
  /// **'Fecha prevista por el laboratorio: {fecha}'**
  String rutaFechaPrevista(Object fecha);

  /// No description provided for @rutaEntregaVencidaEl.
  ///
  /// In es, this message translates to:
  /// **'Entrega vencida: {fecha}'**
  String rutaEntregaVencidaEl(Object fecha);

  /// No description provided for @rutaEntregaEl.
  ///
  /// In es, this message translates to:
  /// **'Entrega: {fecha}'**
  String rutaEntregaEl(Object fecha);

  /// No description provided for @rutaAsuntoMentoria.
  ///
  /// In es, this message translates to:
  /// **'Mentoría - {laboratorio}'**
  String rutaAsuntoMentoria(Object laboratorio);

  /// No description provided for @foroHaceMin.
  ///
  /// In es, this message translates to:
  /// **'hace {minutos} min'**
  String foroHaceMin(Object minutos);

  /// No description provided for @foroHaceHoras.
  ///
  /// In es, this message translates to:
  /// **'hace {horas} h'**
  String foroHaceHoras(Object horas);

  /// No description provided for @foroHaceDias.
  ///
  /// In es, this message translates to:
  /// **'hace {dias} días'**
  String foroHaceDias(Object dias);

  /// No description provided for @foroComunidad.
  ///
  /// In es, this message translates to:
  /// **'Comunidad'**
  String get foroComunidad;

  /// No description provided for @foroTitulo.
  ///
  /// In es, this message translates to:
  /// **'Foro de la Comunidad'**
  String get foroTitulo;

  /// No description provided for @foroNoAbre.
  ///
  /// In es, this message translates to:
  /// **'No pudimos abrir el foro.'**
  String get foroNoAbre;

  /// No description provided for @foroCargando.
  ///
  /// In es, this message translates to:
  /// **'Cargando publicaciones…'**
  String get foroCargando;

  /// No description provided for @foroSubtitulo.
  ///
  /// In es, this message translates to:
  /// **'Pregunte, comparta avances y encuentre a quién ya resolvió lo que usted está resolviendo. Escriben estudiantes, mentores y LXD de toda la red.'**
  String get foroSubtitulo;

  /// No description provided for @foroBuscar.
  ///
  /// In es, this message translates to:
  /// **'Buscar autor, organización o contenido'**
  String get foroBuscar;

  /// No description provided for @foroNadie.
  ///
  /// In es, this message translates to:
  /// **'Nadie ha escrito aún'**
  String get foroNadie;

  /// No description provided for @foroVacio.
  ///
  /// In es, this message translates to:
  /// **'El foro está vacío. Puede ser la primera persona en abrir la conversación de la comunidad.'**
  String get foroVacio;

  /// No description provided for @foroSinCoincidencias.
  ///
  /// In es, this message translates to:
  /// **'Ninguna publicación coincide con este filtro. Pruebe con otra categoría o limpie la búsqueda.'**
  String get foroSinCoincidencias;

  /// No description provided for @foroVerTodo.
  ///
  /// In es, this message translates to:
  /// **'Ver todo el foro'**
  String get foroVerTodo;

  /// No description provided for @foroTodo.
  ///
  /// In es, this message translates to:
  /// **'Todo'**
  String get foroTodo;

  /// No description provided for @foroQueCompartir.
  ///
  /// In es, this message translates to:
  /// **'¿Qué quiere compartir con la comunidad?'**
  String get foroQueCompartir;

  /// No description provided for @foroPublicando.
  ///
  /// In es, this message translates to:
  /// **'Publicando…'**
  String get foroPublicando;

  /// No description provided for @foroPublicar.
  ///
  /// In es, this message translates to:
  /// **'Publicar'**
  String get foroPublicar;

  /// No description provided for @foroUsuarioEliminado.
  ///
  /// In es, this message translates to:
  /// **'Usuario eliminado'**
  String get foroUsuarioEliminado;

  /// No description provided for @foroMasAcciones.
  ///
  /// In es, this message translates to:
  /// **'Más acciones'**
  String get foroMasAcciones;

  /// No description provided for @foroEliminarPublicacion.
  ///
  /// In es, this message translates to:
  /// **'Eliminar publicación'**
  String get foroEliminarPublicacion;

  /// No description provided for @foroEliminarPublicacionTexto.
  ///
  /// In es, this message translates to:
  /// **'¿Eliminar esta publicación del foro? Esta acción no se puede deshacer.'**
  String get foroEliminarPublicacionTexto;

  /// No description provided for @foroDesfijar.
  ///
  /// In es, this message translates to:
  /// **'Desfijar'**
  String get foroDesfijar;

  /// No description provided for @foroFijar.
  ///
  /// In es, this message translates to:
  /// **'Fijar anuncio'**
  String get foroFijar;

  /// No description provided for @foroReportar.
  ///
  /// In es, this message translates to:
  /// **'Reportar'**
  String get foroReportar;

  /// No description provided for @foroBloquearA.
  ///
  /// In es, this message translates to:
  /// **'Bloquear a {nombre}'**
  String foroBloquearA(Object nombre);

  /// No description provided for @foroResponder.
  ///
  /// In es, this message translates to:
  /// **'Responder…'**
  String get foroResponder;

  /// No description provided for @foroVerRespuestas.
  ///
  /// In es, this message translates to:
  /// **'Ver las {total} respuestas'**
  String foroVerRespuestas(Object total);

  /// No description provided for @foroEliminarRespuesta.
  ///
  /// In es, this message translates to:
  /// **'Eliminar respuesta'**
  String get foroEliminarRespuesta;

  /// No description provided for @foroEliminarRespuestaTexto.
  ///
  /// In es, this message translates to:
  /// **'¿Eliminar esta respuesta del foro? Esta acción no se puede deshacer.'**
  String get foroEliminarRespuestaTexto;

  /// No description provided for @foroRegla1.
  ///
  /// In es, this message translates to:
  /// **'Respete a los demás equipos y comparta con la misma apertura con la que le gustaría recibir ayuda.'**
  String get foroRegla1;

  /// No description provided for @foroRegla2.
  ///
  /// In es, this message translates to:
  /// **'Publique contenido real de su proyecto: evidencias y preguntas concretas ayudan más que mensajes genéricos.'**
  String get foroRegla2;

  /// No description provided for @foroRegla3.
  ///
  /// In es, this message translates to:
  /// **'Es un espacio de toda la red: preguntas de cualquier laboratorio o universidad son bienvenidas.'**
  String get foroRegla3;

  /// No description provided for @foroNormas.
  ///
  /// In es, this message translates to:
  /// **'Normas del foro'**
  String get foroNormas;

  /// No description provided for @foroNormasCompletas.
  ///
  /// In es, this message translates to:
  /// **'Normas completas'**
  String get foroNormasCompletas;

  /// No description provided for @foroPersonasBloqueadas.
  ///
  /// In es, this message translates to:
  /// **'Personas bloqueadas'**
  String get foroPersonasBloqueadas;

  /// No description provided for @foroReportes.
  ///
  /// In es, this message translates to:
  /// **'Reportes del foro'**
  String get foroReportes;

  /// No description provided for @foroRevisar.
  ///
  /// In es, this message translates to:
  /// **'Revisar'**
  String get foroRevisar;

  /// No description provided for @foroEquiposActivos.
  ///
  /// In es, this message translates to:
  /// **'Equipos más activos'**
  String get foroEquiposActivos;

  /// No description provided for @reporteMotivoOfensivo.
  ///
  /// In es, this message translates to:
  /// **'Es ofensivo o irrespetuoso'**
  String get reporteMotivoOfensivo;

  /// No description provided for @reporteMotivoAcoso.
  ///
  /// In es, this message translates to:
  /// **'Es acoso o intimidación'**
  String get reporteMotivoAcoso;

  /// No description provided for @reporteMotivoDiscrimina.
  ///
  /// In es, this message translates to:
  /// **'Discrimina a alguien'**
  String get reporteMotivoDiscrimina;

  /// No description provided for @reporteMotivoSpam.
  ///
  /// In es, this message translates to:
  /// **'Es spam o publicidad'**
  String get reporteMotivoSpam;

  /// No description provided for @reporteMotivoDatos.
  ///
  /// In es, this message translates to:
  /// **'Comparte datos personales'**
  String get reporteMotivoDatos;

  /// No description provided for @reporteMotivoOtro.
  ///
  /// In es, this message translates to:
  /// **'Otro motivo'**
  String get reporteMotivoOtro;

  /// No description provided for @reporteGracias.
  ///
  /// In es, this message translates to:
  /// **'Gracias. El equipo de Enactus revisará este contenido.'**
  String get reporteGracias;

  /// No description provided for @reporteYaReportado.
  ///
  /// In es, this message translates to:
  /// **'Ya lo había reportado; el equipo lo tiene en su lista.'**
  String get reporteYaReportado;

  /// No description provided for @reporteRespuesta.
  ///
  /// In es, this message translates to:
  /// **'Reportar respuesta'**
  String get reporteRespuesta;

  /// No description provided for @reportePublicacion.
  ///
  /// In es, this message translates to:
  /// **'Reportar publicación'**
  String get reportePublicacion;

  /// No description provided for @reportePorQue.
  ///
  /// In es, this message translates to:
  /// **'¿Por qué lo reporta? Solo el equipo de Enactus verá quién lo reportó.'**
  String get reportePorQue;

  /// No description provided for @reporteBloquearTambien.
  ///
  /// In es, this message translates to:
  /// **'Bloquear también a {nombre}'**
  String reporteBloquearTambien(Object nombre);

  /// No description provided for @reporteDejaraDeVer.
  ///
  /// In es, this message translates to:
  /// **'Dejará de ver lo que publica.'**
  String get reporteDejaraDeVer;

  /// No description provided for @bloqueoTexto.
  ///
  /// In es, this message translates to:
  /// **'Dejará de ver lo que {nombre} publica y responde en el foro. No se le avisará. Puede desbloquearle cuando quiera desde «Personas bloqueadas», en las normas del foro.'**
  String bloqueoTexto(Object nombre);

  /// No description provided for @bloqueoHecho.
  ///
  /// In es, this message translates to:
  /// **'Bloqueó a {nombre}.'**
  String bloqueoHecho(Object nombre);

  /// No description provided for @bloqueoNadie.
  ///
  /// In es, this message translates to:
  /// **'No ha bloqueado a nadie.'**
  String get bloqueoNadie;

  /// No description provided for @bloqueoDesbloquear.
  ///
  /// In es, this message translates to:
  /// **'Desbloquear'**
  String get bloqueoDesbloquear;

  /// No description provided for @reportesNinguno.
  ///
  /// In es, this message translates to:
  /// **'No hay reportes pendientes.'**
  String get reportesNinguno;

  /// No description provided for @reporteQuitarRespuesta.
  ///
  /// In es, this message translates to:
  /// **'Quitar respuesta'**
  String get reporteQuitarRespuesta;

  /// No description provided for @reporteQuitarPublicacion.
  ///
  /// In es, this message translates to:
  /// **'Quitar publicación'**
  String get reporteQuitarPublicacion;

  /// No description provided for @reporteQuitarTexto.
  ///
  /// In es, this message translates to:
  /// **'Se quitará del foro para todas las personas. No se puede deshacer.'**
  String get reporteQuitarTexto;

  /// No description provided for @reporteTipoPublicacion.
  ///
  /// In es, this message translates to:
  /// **'PUBLICACIÓN'**
  String get reporteTipoPublicacion;

  /// No description provided for @reporteYaNoSeVe.
  ///
  /// In es, this message translates to:
  /// **'· ya no se ve en el foro'**
  String get reporteYaNoSeVe;

  /// No description provided for @reporteSinMotivo.
  ///
  /// In es, this message translates to:
  /// **'Sin motivo'**
  String get reporteSinMotivo;

  /// No description provided for @reporteReporto.
  ///
  /// In es, this message translates to:
  /// **'Reportó {nombre} · {fecha}'**
  String reporteReporto(Object nombre, Object fecha);

  /// No description provided for @reporteCerrar.
  ///
  /// In es, this message translates to:
  /// **'Cerrar reporte'**
  String get reporteCerrar;

  /// No description provided for @reporteDejarlo.
  ///
  /// In es, this message translates to:
  /// **'Dejarlo'**
  String get reporteDejarlo;

  /// No description provided for @reporteQuitarDelForo.
  ///
  /// In es, this message translates to:
  /// **'Quitar del foro'**
  String get reporteQuitarDelForo;

  /// No description provided for @foroAhora.
  ///
  /// In es, this message translates to:
  /// **'ahora'**
  String get foroAhora;

  /// No description provided for @foroAyer.
  ///
  /// In es, this message translates to:
  /// **'ayer'**
  String get foroAyer;

  /// No description provided for @foroPersonasActivas.
  ///
  /// In es, this message translates to:
  /// **'{cantidad, plural, =1{1 persona activa esta semana} other{{cantidad} personas activas esta semana}}'**
  String foroPersonasActivas(int cantidad);

  /// No description provided for @foroRespuestas.
  ///
  /// In es, this message translates to:
  /// **'{cantidad, plural, =1{1 respuesta} other{{cantidad} respuestas}}'**
  String foroRespuestas(int cantidad);

  /// No description provided for @foroReportesSinAtender.
  ///
  /// In es, this message translates to:
  /// **'{cantidad, plural, =1{Hay 1 reporte sin atender.} other{Hay {cantidad} reportes sin atender.}}'**
  String foroReportesSinAtender(int cantidad);

  /// No description provided for @foroPublicaciones.
  ///
  /// In es, this message translates to:
  /// **'{cantidad, plural, =1{1 publicación} other{{cantidad} publicaciones}}'**
  String foroPublicaciones(int cantidad);

  /// No description provided for @reporteTipoRespuesta.
  ///
  /// In es, this message translates to:
  /// **'RESPUESTA'**
  String get reporteTipoRespuesta;

  /// No description provided for @proyectosComunidad.
  ///
  /// In es, this message translates to:
  /// **'Comunidad eduXaction Colombia'**
  String get proyectosComunidad;

  /// No description provided for @proyectosSubtitulo.
  ///
  /// In es, this message translates to:
  /// **'Todos los proyectos activos de la red. Filtre por etapa, explore los ODS que atienden y descubra qué está construyendo el resto de los equipos.'**
  String get proyectosSubtitulo;

  /// No description provided for @proyectosBuscar.
  ///
  /// In es, this message translates to:
  /// **'Buscar proyecto, comunidad u ODS'**
  String get proyectosBuscar;

  /// No description provided for @proyectosTodasEtapas.
  ///
  /// In es, this message translates to:
  /// **'Todas las etapas'**
  String get proyectosTodasEtapas;

  /// No description provided for @proyectosVacio.
  ///
  /// In es, this message translates to:
  /// **'Aún no hay proyectos aquí'**
  String get proyectosVacio;

  /// No description provided for @proyectosVacioTexto.
  ///
  /// In es, this message translates to:
  /// **'Todavía no se ha publicado ningún proyecto en la comunidad. Cuando su equipo registre el suyo, aparecerá aquí para toda la red.'**
  String get proyectosVacioTexto;

  /// No description provided for @proyectosSinCoincidencias.
  ///
  /// In es, this message translates to:
  /// **'Ningún proyecto coincide con este filtro. Pruebe con otra etapa o limpie la búsqueda.'**
  String get proyectosSinCoincidencias;

  /// No description provided for @proyectosVerTodasEtapas.
  ///
  /// In es, this message translates to:
  /// **'Ver todas las etapas'**
  String get proyectosVerTodasEtapas;

  /// No description provided for @proyectosProponer.
  ///
  /// In es, this message translates to:
  /// **'Proponer un proyecto'**
  String get proyectosProponer;

  /// No description provided for @proyectosSinEquipo.
  ///
  /// In es, this message translates to:
  /// **'Sin equipo asignado todavía.'**
  String get proyectosSinEquipo;

  /// No description provided for @proyectosFechaNoRegistrada.
  ///
  /// In es, this message translates to:
  /// **'Fecha no registrada'**
  String get proyectosFechaNoRegistrada;

  /// No description provided for @proyectosProblema.
  ///
  /// In es, this message translates to:
  /// **'Problema'**
  String get proyectosProblema;

  /// No description provided for @proyectosSolucion.
  ///
  /// In es, this message translates to:
  /// **'Solución'**
  String get proyectosSolucion;

  /// No description provided for @proyectosIndicadores.
  ///
  /// In es, this message translates to:
  /// **'Indicadores de impacto'**
  String get proyectosIndicadores;

  /// No description provided for @temaClaro.
  ///
  /// In es, this message translates to:
  /// **'Claro'**
  String get temaClaro;

  /// No description provided for @temaOscuro.
  ///
  /// In es, this message translates to:
  /// **'Oscuro'**
  String get temaOscuro;

  /// No description provided for @proyectosAsesor.
  ///
  /// In es, this message translates to:
  /// **'Asesor académico: {nombre}'**
  String proyectosAsesor(Object nombre);

  /// No description provided for @proyectosSinIntegrantes.
  ///
  /// In es, this message translates to:
  /// **'Sin integrantes asignados.'**
  String get proyectosSinIntegrantes;

  /// No description provided for @proyectosUniversidadSinDefinir.
  ///
  /// In es, this message translates to:
  /// **'Universidad sin definir'**
  String get proyectosUniversidadSinDefinir;

  /// No description provided for @proyectosActivos.
  ///
  /// In es, this message translates to:
  /// **'Proyectos activos'**
  String get proyectosActivos;

  /// No description provided for @proyectosUniversidades.
  ///
  /// In es, this message translates to:
  /// **'Universidades'**
  String get proyectosUniversidades;

  /// No description provided for @proyectosOdsCubiertos.
  ///
  /// In es, this message translates to:
  /// **'ODS cubiertos'**
  String get proyectosOdsCubiertos;

  /// No description provided for @proyectosEnExpo.
  ///
  /// In es, this message translates to:
  /// **'En National Expo'**
  String get proyectosEnExpo;

  /// No description provided for @labEstudiantesAsignados.
  ///
  /// In es, this message translates to:
  /// **'{cantidad} estudiante(s) asignado(s)'**
  String labEstudiantesAsignados(Object cantidad);

  /// No description provided for @labMentores.
  ///
  /// In es, this message translates to:
  /// **'Mentores'**
  String get labMentores;

  /// No description provided for @labSinModulos.
  ///
  /// In es, this message translates to:
  /// **'Sin módulos publicados todavía.'**
  String get labSinModulos;

  /// No description provided for @labBloqueadaAnterior.
  ///
  /// In es, this message translates to:
  /// **'Bloqueada — complete la fase anterior'**
  String get labBloqueadaAnterior;

  /// No description provided for @labPorVencer.
  ///
  /// In es, this message translates to:
  /// **'Por vencer'**
  String get labPorVencer;

  /// No description provided for @labSinEstudiantes.
  ///
  /// In es, this message translates to:
  /// **'Sin estudiantes'**
  String get labSinEstudiantes;

  /// No description provided for @labCompletaron.
  ///
  /// In es, this message translates to:
  /// **'{hechos}/{total} completaron'**
  String labCompletaron(Object hechos, Object total);

  /// No description provided for @usuarioEquipoProyecto.
  ///
  /// In es, this message translates to:
  /// **'Equipo y proyecto'**
  String get usuarioEquipoProyecto;

  /// No description provided for @usuarioAvanceRuta.
  ///
  /// In es, this message translates to:
  /// **'Avance en la Ruta de Impacto'**
  String get usuarioAvanceRuta;

  /// No description provided for @usuarioSinCertificados.
  ///
  /// In es, this message translates to:
  /// **'Todavía sin certificados.'**
  String get usuarioSinCertificados;

  /// No description provided for @usuarioSinLaboratorios.
  ///
  /// In es, this message translates to:
  /// **'Sin laboratorios asignados.'**
  String get usuarioSinLaboratorios;

  /// No description provided for @usuarioEmpresaTexto.
  ///
  /// In es, this message translates to:
  /// **'Sus LXD y mentores aparecen en su propio portal.'**
  String get usuarioEmpresaTexto;

  /// No description provided for @usuarioCodigoImpacto.
  ///
  /// In es, this message translates to:
  /// **'Código de impacto: {codigo}'**
  String usuarioCodigoImpacto(Object codigo);

  /// No description provided for @usuarioDonanteTexto.
  ///
  /// In es, this message translates to:
  /// **'Sus estudiantes y evidencias aparecen en su propio portal.'**
  String get usuarioDonanteTexto;

  /// No description provided for @usuarioAsesor.
  ///
  /// In es, this message translates to:
  /// **'Asesor académico'**
  String get usuarioAsesor;

  /// No description provided for @usuarioAcompana.
  ///
  /// In es, this message translates to:
  /// **'Acompaña a los equipos de {universidad}.'**
  String usuarioAcompana(Object universidad);

  /// No description provided for @usuarioCursosCreados.
  ///
  /// In es, this message translates to:
  /// **'Cursos creados'**
  String get usuarioCursosCreados;

  /// No description provided for @usuarioSinCursos.
  ///
  /// In es, this message translates to:
  /// **'Aún no ha creado ningún curso.'**
  String get usuarioSinCursos;

  /// No description provided for @usuarioLabsAcompana.
  ///
  /// In es, this message translates to:
  /// **'Laboratorios que acompaña'**
  String get usuarioLabsAcompana;

  /// No description provided for @usuarioSinLab.
  ///
  /// In es, this message translates to:
  /// **'Todavía sin laboratorio asignado.'**
  String get usuarioSinLab;

  /// No description provided for @usuarioEstudiantes.
  ///
  /// In es, this message translates to:
  /// **'{cantidad} estudiantes'**
  String usuarioEstudiantes(Object cantidad);

  /// No description provided for @usuarioEntregasRevisadas.
  ///
  /// In es, this message translates to:
  /// **'{cantidad} entregas revisadas.'**
  String usuarioEntregasRevisadas(Object cantidad);

  /// No description provided for @comunEstudiantes.
  ///
  /// In es, this message translates to:
  /// **'{cantidad, plural, =1{1 estudiante} other{{cantidad} estudiantes}}'**
  String comunEstudiantes(int cantidad);

  /// No description provided for @proyectosEstudiantesAlcance.
  ///
  /// In es, this message translates to:
  /// **'{cantidad, plural, =1{1 estudiante en su alcance} other{{cantidad} estudiantes en su alcance}}'**
  String proyectosEstudiantesAlcance(int cantidad);

  /// No description provided for @proyectosCreadoEl.
  ///
  /// In es, this message translates to:
  /// **'Creado el {fecha}'**
  String proyectosCreadoEl(Object fecha);

  /// No description provided for @labFechaLimite.
  ///
  /// In es, this message translates to:
  /// **'Fecha límite: {fecha}'**
  String labFechaLimite(Object fecha);

  /// No description provided for @usuarioCalificaEn.
  ///
  /// In es, this message translates to:
  /// **'Califica en: {contextos}'**
  String usuarioCalificaEn(Object contextos);

  /// No description provided for @usuarioNingunContexto.
  ///
  /// In es, this message translates to:
  /// **'ningún contexto'**
  String get usuarioNingunContexto;

  /// No description provided for @mapaEstudiantesRegistrados.
  ///
  /// In es, this message translates to:
  /// **'Estudiantes registrados'**
  String get mapaEstudiantesRegistrados;

  /// No description provided for @mapaCiudades.
  ///
  /// In es, this message translates to:
  /// **'Ciudades'**
  String get mapaCiudades;

  /// No description provided for @mapaDepartamentos.
  ///
  /// In es, this message translates to:
  /// **'Departamentos'**
  String get mapaDepartamentos;

  /// No description provided for @mapaRedNacional.
  ///
  /// In es, this message translates to:
  /// **'Red nacional · actualizado hoy'**
  String get mapaRedNacional;

  /// No description provided for @mapaPatrocina.
  ///
  /// In es, this message translates to:
  /// **'Estudiantes que patrocina su organización'**
  String get mapaPatrocina;

  /// No description provided for @mapaEstudiantesPais.
  ///
  /// In es, this message translates to:
  /// **'Estudiantes en el país'**
  String get mapaEstudiantesPais;

  /// No description provided for @mapaTexto.
  ///
  /// In es, this message translates to:
  /// **'Dónde están los estudiantes registrados en eduXaction Colombia. Cada punto es una ciudad con al menos una universidad activa en la red.'**
  String get mapaTexto;

  /// No description provided for @mapaSufijoPatrocina.
  ///
  /// In es, this message translates to:
  /// **'estudiantes que patrocina'**
  String get mapaSufijoPatrocina;

  /// No description provided for @mapaOrdenadas.
  ///
  /// In es, this message translates to:
  /// **'Ordenadas por número de estudiantes'**
  String get mapaOrdenadas;

  /// No description provided for @mapaSoloVinculados.
  ///
  /// In es, this message translates to:
  /// **'Solo los estudiantes vinculados a su aporte'**
  String get mapaSoloVinculados;

  /// No description provided for @mapaPortalAliados.
  ///
  /// In es, this message translates to:
  /// **'Portal de aliados · eduXaction Colombia'**
  String get mapaPortalAliados;

  /// No description provided for @mapaGeometria.
  ///
  /// In es, this message translates to:
  /// **'Geometría: Natural Earth (dominio público)'**
  String get mapaGeometria;

  /// No description provided for @mapaDosOMas.
  ///
  /// In es, this message translates to:
  /// **'2 o más estudiantes'**
  String get mapaDosOMas;

  /// No description provided for @mapaUnEstudiante.
  ///
  /// In es, this message translates to:
  /// **'1 estudiante'**
  String get mapaUnEstudiante;

  /// No description provided for @mapaEntre.
  ///
  /// In es, this message translates to:
  /// **'Entre {desde} y {hasta}'**
  String mapaEntre(Object desde, Object hasta);

  /// No description provided for @mapaOMas.
  ///
  /// In es, this message translates to:
  /// **'{cantidad} o más estudiantes'**
  String mapaOMas(Object cantidad);

  /// No description provided for @mapaMenosDe.
  ///
  /// In es, this message translates to:
  /// **'Menos de {cantidad}'**
  String mapaMenosDe(Object cantidad);

  /// No description provided for @mapaTodaLaRed.
  ///
  /// In es, this message translates to:
  /// **'Toda la red'**
  String get mapaTodaLaRed;

  /// No description provided for @mapaLosQuePatrocino.
  ///
  /// In es, this message translates to:
  /// **'Los que patrocino'**
  String get mapaLosQuePatrocino;

  /// No description provided for @mapaTema.
  ///
  /// In es, this message translates to:
  /// **'Tema'**
  String get mapaTema;

  /// No description provided for @mapaSinVinculados.
  ///
  /// In es, this message translates to:
  /// **'Aún no hay estudiantes vinculados'**
  String get mapaSinVinculados;

  /// No description provided for @mapaSinVinculadosTexto.
  ///
  /// In es, this message translates to:
  /// **'Todavía no hay estudiantes vinculados a su aporte. En cuanto su administrador asigne alguno, aparecerá aquí en el mapa.'**
  String get mapaSinVinculadosTexto;

  /// No description provided for @mapaEscribirAdmin.
  ///
  /// In es, this message translates to:
  /// **'Escribir a mi administrador'**
  String get mapaEscribirAdmin;

  /// No description provided for @mapaSolicitudTitulo.
  ///
  /// In es, this message translates to:
  /// **'Solicitud de estudiantes patrocinados'**
  String get mapaSolicitudTitulo;

  /// No description provided for @mapaSolicitudTexto.
  ///
  /// In es, this message translates to:
  /// **'Un aliado pidió que le asignen estudiantes a su aporte.'**
  String get mapaSolicitudTexto;

  /// No description provided for @mapaAvisamos.
  ///
  /// In es, this message translates to:
  /// **'Le avisamos a su administrador.'**
  String get mapaAvisamos;

  /// No description provided for @mapaSinCiudades.
  ///
  /// In es, this message translates to:
  /// **'Sin ciudades para este alcance todavía.'**
  String get mapaSinCiudades;

  /// No description provided for @mapaCiudadExplica.
  ///
  /// In es, this message translates to:
  /// **'La ciudad es la que el estudiante (o su administrador) eligió en su perfil. Los estudiantes sin ciudad asignada todavía no aparecen en el mapa.'**
  String get mapaCiudadExplica;

  /// No description provided for @talentoTitulo.
  ///
  /// In es, this message translates to:
  /// **'BuscaTalento'**
  String get talentoTitulo;

  /// No description provided for @talentoSubtitulo.
  ///
  /// In es, this message translates to:
  /// **'Estudiantes eduXaction que ya demostraron sus habilidades en la Ruta de Impacto — contáctelos para oportunidades futuras 💛'**
  String get talentoSubtitulo;

  /// No description provided for @talentoVacio.
  ///
  /// In es, this message translates to:
  /// **'Todavía no hay estudiantes eduXaction en la plataforma.'**
  String get talentoVacio;

  /// No description provided for @talentoTop.
  ///
  /// In es, this message translates to:
  /// **'Top talento'**
  String get talentoTop;

  /// No description provided for @talentoAvance.
  ///
  /// In es, this message translates to:
  /// **'{porcentaje}% de avance'**
  String talentoAvance(Object porcentaje);

  /// No description provided for @talentoObjetivosEmprendimiento.
  ///
  /// In es, this message translates to:
  /// **'{cantidad} objetivos de emprendimiento'**
  String talentoObjetivosEmprendimiento(Object cantidad);

  /// No description provided for @talentoObjetivosEmpresariales.
  ///
  /// In es, this message translates to:
  /// **'{cantidad} objetivos empresariales'**
  String talentoObjetivosEmpresariales(Object cantidad);

  /// No description provided for @talentoCertificados.
  ///
  /// In es, this message translates to:
  /// **'{cantidad} certificados'**
  String talentoCertificados(Object cantidad);

  /// No description provided for @talentoContactar.
  ///
  /// In es, this message translates to:
  /// **'Contactar'**
  String get talentoContactar;

  /// No description provided for @talentoOportunidad.
  ///
  /// In es, this message translates to:
  /// **'Una oportunidad para usted'**
  String get talentoOportunidad;

  /// No description provided for @talentoNecesitaTitulo.
  ///
  /// In es, this message translates to:
  /// **'El aviso necesita un título.'**
  String get talentoNecesitaTitulo;

  /// No description provided for @talentoMensajeEnviado.
  ///
  /// In es, this message translates to:
  /// **'Mensaje enviado ✓'**
  String get talentoMensajeEnviado;

  /// No description provided for @talentoContactarA.
  ///
  /// In es, this message translates to:
  /// **'Contactar a {nombre}'**
  String talentoContactarA(Object nombre);

  /// No description provided for @talentoMensajeLlega.
  ///
  /// In es, this message translates to:
  /// **'El mensaje llega a su bandeja dentro de la plataforma. No se entrega ningún dato de contacto.'**
  String get talentoMensajeLlega;

  /// No description provided for @talentoAsunto.
  ///
  /// In es, this message translates to:
  /// **'Asunto'**
  String get talentoAsunto;

  /// No description provided for @recursosTitulo.
  ///
  /// In es, this message translates to:
  /// **'Recursos de Comunicaciones'**
  String get recursosTitulo;

  /// No description provided for @recursosSubtitulo.
  ///
  /// In es, this message translates to:
  /// **'Plantillas, guías de marca y material para el equipo'**
  String get recursosSubtitulo;

  /// No description provided for @recursosNuevo.
  ///
  /// In es, this message translates to:
  /// **'Nuevo recurso'**
  String get recursosNuevo;

  /// No description provided for @recursosVacio.
  ///
  /// In es, this message translates to:
  /// **'Todavía no hay recursos publicados.'**
  String get recursosVacio;

  /// No description provided for @recursosEliminar.
  ///
  /// In es, this message translates to:
  /// **'Eliminar recurso'**
  String get recursosEliminar;

  /// No description provided for @recursosEliminarTexto.
  ///
  /// In es, this message translates to:
  /// **'¿Eliminar \"{titulo}\"?'**
  String recursosEliminarTexto(Object titulo);

  /// No description provided for @recursosNecesitaTitulo.
  ///
  /// In es, this message translates to:
  /// **'El recurso necesita un título.'**
  String get recursosNecesitaTitulo;

  /// No description provided for @recursosFaltaArchivo.
  ///
  /// In es, this message translates to:
  /// **'Falta subir el archivo.'**
  String get recursosFaltaArchivo;

  /// No description provided for @recursosFaltaUrl.
  ///
  /// In es, this message translates to:
  /// **'Falta la URL.'**
  String get recursosFaltaUrl;

  /// No description provided for @recursosPublicado.
  ///
  /// In es, this message translates to:
  /// **'Recurso publicado ✓'**
  String get recursosPublicado;

  /// No description provided for @comunDescripcion.
  ///
  /// In es, this message translates to:
  /// **'Descripción'**
  String get comunDescripcion;

  /// No description provided for @mapaSufijoEstudiantes.
  ///
  /// In es, this message translates to:
  /// **'estudiantes'**
  String get mapaSufijoEstudiantes;

  /// No description provided for @lxdPortal.
  ///
  /// In es, this message translates to:
  /// **'Portal LXD'**
  String get lxdPortal;

  /// No description provided for @tabMisEstudiantes.
  ///
  /// In es, this message translates to:
  /// **'Mis Estudiantes'**
  String get tabMisEstudiantes;

  /// No description provided for @tabEstudiantesCorto.
  ///
  /// In es, this message translates to:
  /// **'Estudiantes'**
  String get tabEstudiantesCorto;

  /// No description provided for @tabCalificaciones.
  ///
  /// In es, this message translates to:
  /// **'Calificaciones'**
  String get tabCalificaciones;

  /// No description provided for @tabCalificarCorto.
  ///
  /// In es, this message translates to:
  /// **'Calificar'**
  String get tabCalificarCorto;

  /// No description provided for @tabCertificaciones.
  ///
  /// In es, this message translates to:
  /// **'Certificaciones'**
  String get tabCertificaciones;

  /// No description provided for @lxdEstudiantesSubtitulo.
  ///
  /// In es, this message translates to:
  /// **'Estudiantes inscritos en cursos que usted creó'**
  String get lxdEstudiantesSubtitulo;

  /// No description provided for @lxdFiltrarNombre.
  ///
  /// In es, this message translates to:
  /// **'Filtrar por nombre o institución'**
  String get lxdFiltrarNombre;

  /// No description provided for @lxdSinEstudiantes.
  ///
  /// In es, this message translates to:
  /// **'No hay estudiantes inscritos en sus cursos.'**
  String get lxdSinEstudiantes;

  /// No description provided for @comunEstudiante.
  ///
  /// In es, this message translates to:
  /// **'Estudiante'**
  String get comunEstudiante;

  /// No description provided for @comunEtapa.
  ///
  /// In es, this message translates to:
  /// **'Etapa'**
  String get comunEtapa;

  /// No description provided for @lxdNecesidad.
  ///
  /// In es, this message translates to:
  /// **'Necesidad'**
  String get lxdNecesidad;

  /// No description provided for @comunInstitucion.
  ///
  /// In es, this message translates to:
  /// **'Institución'**
  String get comunInstitucion;

  /// No description provided for @comunProgreso.
  ///
  /// In es, this message translates to:
  /// **'Progreso'**
  String get comunProgreso;

  /// No description provided for @lxdPromedioCursos.
  ///
  /// In es, this message translates to:
  /// **'Promedio de todos sus cursos'**
  String get lxdPromedioCursos;

  /// No description provided for @lxdAcompanamientoUrgente.
  ///
  /// In es, this message translates to:
  /// **'Acompañamiento urgente'**
  String get lxdAcompanamientoUrgente;

  /// No description provided for @lxdSeguimientoRegular.
  ///
  /// In es, this message translates to:
  /// **'Seguimiento regular'**
  String get lxdSeguimientoRegular;

  /// No description provided for @lxdAutonomo.
  ///
  /// In es, this message translates to:
  /// **'Autónomo'**
  String get lxdAutonomo;

  /// No description provided for @lxdResumenAvance.
  ///
  /// In es, this message translates to:
  /// **'Avance: {porcentaje}%'**
  String lxdResumenAvance(Object porcentaje);

  /// No description provided for @lxdResumenEmpresa.
  ///
  /// In es, this message translates to:
  /// **'Empresa: {empresa}'**
  String lxdResumenEmpresa(Object empresa);

  /// No description provided for @lxdProyectosSubtitulo.
  ///
  /// In es, this message translates to:
  /// **'Equipos y avance en la Ruta de Impacto de sus estudiantes'**
  String get lxdProyectosSubtitulo;

  /// No description provided for @lxdSinProyectos.
  ///
  /// In es, this message translates to:
  /// **'Ninguno de sus estudiantes tiene proyecto asignado todavía.'**
  String get lxdSinProyectos;

  /// No description provided for @lxdCalendarioSubtitulo.
  ///
  /// In es, this message translates to:
  /// **'Agende las sesiones sincrónicas de sus cursos Open Learning'**
  String get lxdCalendarioSubtitulo;

  /// No description provided for @lxdCursosSubtitulo.
  ///
  /// In es, this message translates to:
  /// **'Cursos que usted creó — eduXaction (asignados o no a un laboratorio) y Open Learning'**
  String get lxdCursosSubtitulo;

  /// No description provided for @lxdNuevoCurso.
  ///
  /// In es, this message translates to:
  /// **'Nuevo curso'**
  String get lxdNuevoCurso;

  /// No description provided for @lxdSinCursos.
  ///
  /// In es, this message translates to:
  /// **'Aún no ha creado ningún curso. Cree el primero.'**
  String get lxdSinCursos;

  /// No description provided for @lxdNombreCurso.
  ///
  /// In es, this message translates to:
  /// **'Póngale un nombre al curso.'**
  String get lxdNombreCurso;

  /// No description provided for @lxdNombreDelCurso.
  ///
  /// In es, this message translates to:
  /// **'Nombre del curso'**
  String get lxdNombreDelCurso;

  /// No description provided for @lxdCursoOpenLearning.
  ///
  /// In es, this message translates to:
  /// **'Curso de Open Learning'**
  String get lxdCursoOpenLearning;

  /// No description provided for @lxdCursoOpenLearningTexto.
  ///
  /// In es, this message translates to:
  /// **'Se asigna directo a estudiantes externos, sin laboratorio ni Ruta de Impacto'**
  String get lxdCursoOpenLearningTexto;

  /// No description provided for @lxdLabsNoCargan.
  ///
  /// In es, this message translates to:
  /// **'No se pudieron cargar los laboratorios. Puede asignarlo después desde el constructor.'**
  String get lxdLabsNoCargan;

  /// No description provided for @lxdLaboratorioOpcional.
  ///
  /// In es, this message translates to:
  /// **'Laboratorio (opcional)'**
  String get lxdLaboratorioOpcional;

  /// No description provided for @lxdSinAsignarAun.
  ///
  /// In es, this message translates to:
  /// **'Sin asignar por ahora'**
  String get lxdSinAsignarAun;

  /// No description provided for @comunCreando.
  ///
  /// In es, this message translates to:
  /// **'Creando…'**
  String get comunCreando;

  /// No description provided for @lxdCrearAbrir.
  ///
  /// In es, this message translates to:
  /// **'Crear y abrir constructor'**
  String get lxdCrearAbrir;

  /// No description provided for @lxdInscritos.
  ///
  /// In es, this message translates to:
  /// **'{cantidad} inscritos'**
  String lxdInscritos(Object cantidad);

  /// No description provided for @lxdCompletados.
  ///
  /// In es, this message translates to:
  /// **'{cantidad} completados'**
  String lxdCompletados(Object cantidad);

  /// No description provided for @lxdAvance.
  ///
  /// In es, this message translates to:
  /// **'{porcentaje}% avance'**
  String lxdAvance(Object porcentaje);

  /// No description provided for @lxdSinNotas.
  ///
  /// In es, this message translates to:
  /// **'Sin notas'**
  String get lxdSinNotas;

  /// No description provided for @lxdPromedio.
  ///
  /// In es, this message translates to:
  /// **'Promedio {nota}'**
  String lxdPromedio(Object nota);

  /// No description provided for @lxdPendientes.
  ///
  /// In es, this message translates to:
  /// **'{cantidad} pendientes'**
  String lxdPendientes(Object cantidad);

  /// No description provided for @lxdSinVincular.
  ///
  /// In es, this message translates to:
  /// **'Sin vincular a ningún módulo todavía'**
  String get lxdSinVincular;

  /// No description provided for @lxdVinculadoA.
  ///
  /// In es, this message translates to:
  /// **'Vinculado a: {modulo}'**
  String lxdVinculadoA(Object modulo);

  /// No description provided for @lxdConstructor.
  ///
  /// In es, this message translates to:
  /// **'Constructor'**
  String get lxdConstructor;

  /// No description provided for @lxdSeguimiento.
  ///
  /// In es, this message translates to:
  /// **'Seguimiento'**
  String get lxdSeguimiento;

  /// No description provided for @lxdEliminarCurso.
  ///
  /// In es, this message translates to:
  /// **'Eliminar curso'**
  String get lxdEliminarCurso;

  /// No description provided for @lxdEliminarCursoTexto.
  ///
  /// In es, this message translates to:
  /// **'Va a eliminar \"{nombre}\" con todos sus módulos, lecciones y configuración.'**
  String lxdEliminarCursoTexto(Object nombre);

  /// No description provided for @lxdCursoEliminado.
  ///
  /// In es, this message translates to:
  /// **'Curso eliminado'**
  String get lxdCursoEliminado;

  /// No description provided for @lxdCalificacionesSubtitulo.
  ///
  /// In es, this message translates to:
  /// **'Entregas de estudiantes en sus cursos'**
  String get lxdCalificacionesSubtitulo;

  /// No description provided for @lxdSinPermisoCalificar.
  ///
  /// In es, this message translates to:
  /// **'Su Admin no le ha dado permiso de calificar todavía'**
  String get lxdSinPermisoCalificar;

  /// No description provided for @lxdSinEntregas.
  ///
  /// In es, this message translates to:
  /// **'No hay entregas para calificar.'**
  String get lxdSinEntregas;

  /// No description provided for @calificarElija.
  ///
  /// In es, this message translates to:
  /// **'Elija aprobado o reprobado.'**
  String get calificarElija;

  /// No description provided for @calificarPuntajeRango.
  ///
  /// In es, this message translates to:
  /// **'El puntaje va de 0 a 100.'**
  String get calificarPuntajeRango;

  /// No description provided for @calificarNotaRango.
  ///
  /// In es, this message translates to:
  /// **'La nota va de 0.0 a 5.0.'**
  String get calificarNotaRango;

  /// No description provided for @calificarEntregaCalificada.
  ///
  /// In es, this message translates to:
  /// **'Entrega calificada ✓'**
  String get calificarEntregaCalificada;

  /// No description provided for @calificarTitulo.
  ///
  /// In es, this message translates to:
  /// **'Calificar: {tarea}'**
  String calificarTitulo(Object tarea);

  /// No description provided for @calificarEscala.
  ///
  /// In es, this message translates to:
  /// **'Escala de calificación'**
  String get calificarEscala;

  /// No description provided for @calificarResultado.
  ///
  /// In es, this message translates to:
  /// **'Resultado:'**
  String get calificarResultado;

  /// No description provided for @calificarSoloRevision.
  ///
  /// In es, this message translates to:
  /// **'Esta actividad es de solo revisión: deja su retroalimentación sin nota.'**
  String get calificarSoloRevision;

  /// No description provided for @calificarPuntaje.
  ///
  /// In es, this message translates to:
  /// **'Puntaje (0 - 100)'**
  String get calificarPuntaje;

  /// No description provided for @calificarNota.
  ///
  /// In es, this message translates to:
  /// **'Nota (0.0 - 5.0)'**
  String get calificarNota;

  /// No description provided for @calificarRetroalimentacion.
  ///
  /// In es, this message translates to:
  /// **'Retroalimentación'**
  String get calificarRetroalimentacion;

  /// No description provided for @certificadoEmitido.
  ///
  /// In es, this message translates to:
  /// **'Certificado {codigo} emitido 🏆'**
  String certificadoEmitido(Object codigo);

  /// No description provided for @certificacionesSubtitulo.
  ///
  /// In es, this message translates to:
  /// **'El certificado se emite al completar la Ruta de Impacto completa de un laboratorio (ya no hay certificado por curso)'**
  String get certificacionesSubtitulo;

  /// No description provided for @certificacionesSinPermiso.
  ///
  /// In es, this message translates to:
  /// **'Su Admin no le ha dado permiso de calificar en eduXaction: no puede emitir certificados todavía'**
  String get certificacionesSinPermiso;

  /// No description provided for @certificacionesEmitidos.
  ///
  /// In es, this message translates to:
  /// **'Certificados emitidos'**
  String get certificacionesEmitidos;

  /// No description provided for @certificacionesVacio.
  ///
  /// In es, this message translates to:
  /// **'Aún no se han emitido certificados.'**
  String get certificacionesVacio;

  /// No description provided for @certificacionesEmitirNuevo.
  ///
  /// In es, this message translates to:
  /// **'Emitir nuevo certificado'**
  String get certificacionesEmitirNuevo;

  /// No description provided for @certificacionesLabRuta.
  ///
  /// In es, this message translates to:
  /// **'Laboratorio (Ruta completa)'**
  String get certificacionesLabRuta;

  /// No description provided for @certificacionesEmitiendo.
  ///
  /// In es, this message translates to:
  /// **'Emitiendo…'**
  String get certificacionesEmitiendo;

  /// No description provided for @certificacionesEmitir.
  ///
  /// In es, this message translates to:
  /// **'Emitir'**
  String get certificacionesEmitir;

  /// No description provided for @certificacionesComprobando.
  ///
  /// In es, this message translates to:
  /// **'Comprobando su Ruta de Impacto…'**
  String get certificacionesComprobando;

  /// No description provided for @certificacionesNoCompleto.
  ///
  /// In es, this message translates to:
  /// **'Este estudiante aún no completó la Ruta de Impacto de ningún laboratorio'**
  String get certificacionesNoCompleto;

  /// No description provided for @lxdPerfilSubtitulo.
  ///
  /// In es, this message translates to:
  /// **'Información visible para administradores y estudiantes'**
  String get lxdPerfilSubtitulo;

  /// No description provided for @lxdPermisoOL.
  ///
  /// In es, this message translates to:
  /// **'Permiso de calificar · Open Learning'**
  String get lxdPermisoOL;

  /// No description provided for @comunActivado.
  ///
  /// In es, this message translates to:
  /// **'Activado'**
  String get comunActivado;

  /// No description provided for @comunDesactivado.
  ///
  /// In es, this message translates to:
  /// **'Desactivado'**
  String get comunDesactivado;

  /// No description provided for @lxdPermisoEduxaction.
  ///
  /// In es, this message translates to:
  /// **'Permiso de calificar · eduXaction'**
  String get lxdPermisoEduxaction;

  /// No description provided for @perfilCargo.
  ///
  /// In es, this message translates to:
  /// **'Cargo'**
  String get perfilCargo;

  /// No description provided for @perfilEspecialidad.
  ///
  /// In es, this message translates to:
  /// **'Especialidad'**
  String get perfilEspecialidad;

  /// No description provided for @perfilIdiomas.
  ///
  /// In es, this message translates to:
  /// **'Idiomas'**
  String get perfilIdiomas;

  /// No description provided for @perfilDisponibilidad.
  ///
  /// In es, this message translates to:
  /// **'Disponibilidad'**
  String get perfilDisponibilidad;

  /// No description provided for @perfilExperiencia.
  ///
  /// In es, this message translates to:
  /// **'Experiencia'**
  String get perfilExperiencia;

  /// No description provided for @perfilIntereses.
  ///
  /// In es, this message translates to:
  /// **'Intereses'**
  String get perfilIntereses;

  /// No description provided for @lxdResumenProyecto.
  ///
  /// In es, this message translates to:
  /// **'Proyecto: {proyecto}'**
  String lxdResumenProyecto(Object proyecto);

  /// No description provided for @certificadoLinea.
  ///
  /// In es, this message translates to:
  /// **'{estudiante} · Ruta de Impacto {laboratorio} · {codigo}'**
  String certificadoLinea(Object estudiante, Object laboratorio, Object codigo);

  /// No description provided for @constructorInfoGeneral.
  ///
  /// In es, this message translates to:
  /// **'Información general'**
  String get constructorInfoGeneral;

  /// No description provided for @constructorCategorizacion.
  ///
  /// In es, this message translates to:
  /// **'Categorización y objetivos'**
  String get constructorCategorizacion;

  /// No description provided for @constructorDelCurso.
  ///
  /// In es, this message translates to:
  /// **'Constructor del curso'**
  String get constructorDelCurso;

  /// No description provided for @constructorEvaluacion.
  ///
  /// In es, this message translates to:
  /// **'Evaluación y certificado'**
  String get constructorEvaluacion;

  /// No description provided for @constructorRestricciones.
  ///
  /// In es, this message translates to:
  /// **'Restricciones y patrocinio'**
  String get constructorRestricciones;

  /// No description provided for @constructorTitulo.
  ///
  /// In es, this message translates to:
  /// **'Constructor de Curso'**
  String get constructorTitulo;

  /// No description provided for @comunVolver.
  ///
  /// In es, this message translates to:
  /// **'Volver'**
  String get comunVolver;

  /// No description provided for @constructorHerramienta.
  ///
  /// In es, this message translates to:
  /// **'el constructor de módulos y lecciones'**
  String get constructorHerramienta;

  /// No description provided for @constructorNecesitaNombre.
  ///
  /// In es, this message translates to:
  /// **'El curso necesita un nombre.'**
  String get constructorNecesitaNombre;

  /// No description provided for @constructorGuardado.
  ///
  /// In es, this message translates to:
  /// **'Curso guardado ✓'**
  String get constructorGuardado;

  /// No description provided for @constructorSubtitulo.
  ///
  /// In es, this message translates to:
  /// **'Subtítulo'**
  String get constructorSubtitulo;

  /// No description provided for @constructorDescCorta.
  ///
  /// In es, this message translates to:
  /// **'Descripción corta'**
  String get constructorDescCorta;

  /// No description provided for @constructorDescCompleta.
  ///
  /// In es, this message translates to:
  /// **'Descripción completa'**
  String get constructorDescCompleta;

  /// No description provided for @constructorPortada.
  ///
  /// In es, this message translates to:
  /// **'Imagen de portada'**
  String get constructorPortada;

  /// No description provided for @constructorYaPortada.
  ///
  /// In es, this message translates to:
  /// **'Ya tiene portada. Subir otra la reemplaza.'**
  String get constructorYaPortada;

  /// No description provided for @constructorNivel.
  ///
  /// In es, this message translates to:
  /// **'Nivel'**
  String get constructorNivel;

  /// No description provided for @constructorDuracion.
  ///
  /// In es, this message translates to:
  /// **'Duración estimada (horas)'**
  String get constructorDuracion;

  /// No description provided for @constructorIdioma.
  ///
  /// In es, this message translates to:
  /// **'Idioma'**
  String get constructorIdioma;

  /// No description provided for @constructorEstado.
  ///
  /// In es, this message translates to:
  /// **'Estado: '**
  String get constructorEstado;

  /// No description provided for @constructorPublicar.
  ///
  /// In es, this message translates to:
  /// **'Publicar'**
  String get constructorPublicar;

  /// No description provided for @constructorArchivar.
  ///
  /// In es, this message translates to:
  /// **'Archivar'**
  String get constructorArchivar;

  /// No description provided for @constructorArchivarCurso.
  ///
  /// In es, this message translates to:
  /// **'Archivar curso'**
  String get constructorArchivarCurso;

  /// No description provided for @constructorArchivarTexto.
  ///
  /// In es, this message translates to:
  /// **'Deja de asignarse a estudiantes nuevos, pero quienes ya tienen avance no se bloquean.'**
  String get constructorArchivarTexto;

  /// No description provided for @constructorLeccionesCompletar.
  ///
  /// In es, this message translates to:
  /// **'Lecciones a completar:'**
  String get constructorLeccionesCompletar;

  /// No description provided for @constructorCategorizacionGuardada.
  ///
  /// In es, this message translates to:
  /// **'Categorización guardada ✓'**
  String get constructorCategorizacionGuardada;

  /// No description provided for @constructorSinLab.
  ///
  /// In es, this message translates to:
  /// **'Sin laboratorio (curso especial)'**
  String get constructorSinLab;

  /// No description provided for @constructorEtiquetas.
  ///
  /// In es, this message translates to:
  /// **'Etiquetas'**
  String get constructorEtiquetas;

  /// No description provided for @constructorCompetencias.
  ///
  /// In es, this message translates to:
  /// **'Competencias que desarrolla (métricas de impacto)'**
  String get constructorCompetencias;

  /// No description provided for @constructorOdsRelacionados.
  ///
  /// In es, this message translates to:
  /// **'ODS relacionados'**
  String get constructorOdsRelacionados;

  /// No description provided for @constructorObjetivosCurso.
  ///
  /// In es, this message translates to:
  /// **'Objetivos del curso'**
  String get constructorObjetivosCurso;

  /// No description provided for @constructorObjetivosPista.
  ///
  /// In es, this message translates to:
  /// **'p. ej. Comprender los fundamentos de la IA aplicada'**
  String get constructorObjetivosPista;

  /// No description provided for @constructorObjetivosRuta.
  ///
  /// In es, this message translates to:
  /// **'Objetivos para la Ruta de Impacto'**
  String get constructorObjetivosRuta;

  /// No description provided for @constructorObjetivosRutaTexto.
  ///
  /// In es, this message translates to:
  /// **'Si este curso se vincula a un módulo de un laboratorio, estos objetivos se agregan automáticamente a los de esa fase.'**
  String get constructorObjetivosRutaTexto;

  /// No description provided for @constructorObjetivosEmprendimiento.
  ///
  /// In es, this message translates to:
  /// **'Objetivos de Emprendimiento'**
  String get constructorObjetivosEmprendimiento;

  /// No description provided for @constructorObjetivosEmprendimientoPista.
  ///
  /// In es, this message translates to:
  /// **'p. ej. Identificar oportunidades de IA en proyectos sociales'**
  String get constructorObjetivosEmprendimientoPista;

  /// No description provided for @constructorObjetivosEmpresariales.
  ///
  /// In es, this message translates to:
  /// **'Objetivos Empresariales'**
  String get constructorObjetivosEmpresariales;

  /// No description provided for @constructorObjetivosEmpresarialesPista.
  ///
  /// In es, this message translates to:
  /// **'p. ej. Comprender los fundamentos del aprendizaje automático'**
  String get constructorObjetivosEmpresarialesPista;

  /// No description provided for @constructorResultados.
  ///
  /// In es, this message translates to:
  /// **'Resultados de aprendizaje'**
  String get constructorResultados;

  /// No description provided for @constructorResultadosPista.
  ///
  /// In es, this message translates to:
  /// **'p. ej. Construye un prototipo con datos reales'**
  String get constructorResultadosPista;

  /// No description provided for @constructorPrerrequisitos.
  ///
  /// In es, this message translates to:
  /// **'Prerrequisitos'**
  String get constructorPrerrequisitos;

  /// No description provided for @constructorPrerrequisitosTexto.
  ///
  /// In es, this message translates to:
  /// **'Cursos que el estudiante debería completar antes (o ninguno).'**
  String get constructorPrerrequisitosTexto;

  /// No description provided for @constructorSinOtrosCursos.
  ///
  /// In es, this message translates to:
  /// **'No hay otros cursos disponibles.'**
  String get constructorSinOtrosCursos;

  /// No description provided for @constructorNuevoModulo.
  ///
  /// In es, this message translates to:
  /// **'Nuevo módulo'**
  String get constructorNuevoModulo;

  /// No description provided for @constructorTituloModulo.
  ///
  /// In es, this message translates to:
  /// **'Título del módulo'**
  String get constructorTituloModulo;

  /// No description provided for @constructorArrastre.
  ///
  /// In es, this message translates to:
  /// **'Arrastre con el ícono ⠿ para reordenar módulos y lecciones.'**
  String get constructorArrastre;

  /// No description provided for @constructorPrimerModulo.
  ///
  /// In es, this message translates to:
  /// **'Cree el primer módulo para empezar.'**
  String get constructorPrimerModulo;

  /// No description provided for @constructorModuloTitulo.
  ///
  /// In es, this message translates to:
  /// **'Módulo {numero}: {titulo}'**
  String constructorModuloTitulo(Object numero, Object titulo);

  /// No description provided for @constructorRenombrarModulo.
  ///
  /// In es, this message translates to:
  /// **'Renombrar módulo'**
  String get constructorRenombrarModulo;

  /// No description provided for @constructorAgregarLeccion.
  ///
  /// In es, this message translates to:
  /// **'Agregar lección'**
  String get constructorAgregarLeccion;

  /// No description provided for @constructorEliminarModulo.
  ///
  /// In es, this message translates to:
  /// **'Eliminar módulo'**
  String get constructorEliminarModulo;

  /// No description provided for @constructorSinLecciones.
  ///
  /// In es, this message translates to:
  /// **'Sin lecciones — use + para agregar contenido.'**
  String get constructorSinLecciones;

  /// No description provided for @constructorEditarTipo.
  ///
  /// In es, this message translates to:
  /// **'Editar {tipo}'**
  String constructorEditarTipo(Object tipo);

  /// No description provided for @constructorEliminarLeccion.
  ///
  /// In es, this message translates to:
  /// **'Eliminar lección'**
  String get constructorEliminarLeccion;

  /// No description provided for @constructorEliminarLeccionTexto.
  ///
  /// In es, this message translates to:
  /// **'¿Eliminar \"{titulo}\"?'**
  String constructorEliminarLeccionTexto(Object titulo);

  /// No description provided for @comunGuardado.
  ///
  /// In es, this message translates to:
  /// **'Guardado ✓'**
  String get comunGuardado;

  /// No description provided for @constructorCuentaCertificado.
  ///
  /// In es, this message translates to:
  /// **'¿Este curso cuenta para certificado?'**
  String get constructorCuentaCertificado;

  /// No description provided for @constructorCuentaCertificadoTexto.
  ///
  /// In es, this message translates to:
  /// **'Se ve un sello en el curso y sus horas cuentan para el certificado de la Ruta de Impacto del laboratorio (el PDF lo emite el LXD al completar toda la Ruta, no por curso individual)'**
  String get constructorCuentaCertificadoTexto;

  /// No description provided for @constructorHorasCertificadas.
  ///
  /// In es, this message translates to:
  /// **'Horas certificadas'**
  String get constructorHorasCertificadas;

  /// No description provided for @constructorSinDefinir.
  ///
  /// In es, this message translates to:
  /// **'Sin definir'**
  String get constructorSinDefinir;

  /// No description provided for @constructorApertura.
  ///
  /// In es, this message translates to:
  /// **'Apertura: {fecha}'**
  String constructorApertura(Object fecha);

  /// No description provided for @constructorCierre.
  ///
  /// In es, this message translates to:
  /// **'Cierre: {fecha}'**
  String constructorCierre(Object fecha);

  /// No description provided for @constructorCierreAntes.
  ///
  /// In es, this message translates to:
  /// **'El curso no puede cerrar antes de abrir.'**
  String get constructorCierreAntes;

  /// No description provided for @constructorMaximo.
  ///
  /// In es, this message translates to:
  /// **'Máximo de estudiantes (0 = sin límite)'**
  String get constructorMaximo;

  /// No description provided for @constructorVisible.
  ///
  /// In es, this message translates to:
  /// **'Visible'**
  String get constructorVisible;

  /// No description provided for @constructorOculto.
  ///
  /// In es, this message translates to:
  /// **'Oculto'**
  String get constructorOculto;

  /// No description provided for @constructorOcultosTexto.
  ///
  /// In es, this message translates to:
  /// **'Los cursos ocultos no aparecen para asignación'**
  String get constructorOcultosTexto;

  /// No description provided for @constructorPatrocinio.
  ///
  /// In es, this message translates to:
  /// **'Patrocinio'**
  String get constructorPatrocinio;

  /// No description provided for @constructorEmpresaPatrocinadora.
  ///
  /// In es, this message translates to:
  /// **'Empresa patrocinadora del curso (opcional)'**
  String get constructorEmpresaPatrocinadora;

  /// No description provided for @constructorNinguna.
  ///
  /// In es, this message translates to:
  /// **'Ninguna'**
  String get constructorNinguna;

  /// No description provided for @constructorPatrocinioTexto.
  ///
  /// In es, this message translates to:
  /// **'Las horas de formación completadas en cursos patrocinados alimentan las métricas de impacto de la empresa.'**
  String get constructorPatrocinioTexto;

  /// No description provided for @constructorQuitarFecha.
  ///
  /// In es, this message translates to:
  /// **'Quitar fecha'**
  String get constructorQuitarFecha;

  /// No description provided for @comunAgregar.
  ///
  /// In es, this message translates to:
  /// **'Agregar'**
  String get comunAgregar;

  /// No description provided for @comunAceptar.
  ///
  /// In es, this message translates to:
  /// **'Aceptar'**
  String get comunAceptar;

  /// No description provided for @constructorEliminarModuloTexto.
  ///
  /// In es, this message translates to:
  /// **'Va a eliminar \"{modulo}\" con sus {cantidad} lecciones.'**
  String constructorEliminarModuloTexto(Object modulo, int cantidad);

  /// No description provided for @quizTipoMultiple.
  ///
  /// In es, this message translates to:
  /// **'Selección múltiple'**
  String get quizTipoMultiple;

  /// No description provided for @quizTipoVerdaderoFalso.
  ///
  /// In es, this message translates to:
  /// **'Verdadero / Falso'**
  String get quizTipoVerdaderoFalso;

  /// No description provided for @quizTipoCorta.
  ///
  /// In es, this message translates to:
  /// **'Respuesta corta'**
  String get quizTipoCorta;

  /// No description provided for @quizTipoOrdenar.
  ///
  /// In es, this message translates to:
  /// **'Ordenar'**
  String get quizTipoOrdenar;

  /// No description provided for @quizTipoCompletar.
  ///
  /// In es, this message translates to:
  /// **'Completar'**
  String get quizTipoCompletar;

  /// No description provided for @leccionDescartarTexto.
  ///
  /// In es, this message translates to:
  /// **'Hay cambios sin guardar en esta lección. ¿Desea salir de todas formas?'**
  String get leccionDescartarTexto;

  /// No description provided for @leccionNecesitaTitulo.
  ///
  /// In es, this message translates to:
  /// **'La lección necesita un título.'**
  String get leccionNecesitaTitulo;

  /// No description provided for @leccionEnlaceNecesitaUrl.
  ///
  /// In es, this message translates to:
  /// **'Una lección de tipo enlace necesita su URL.'**
  String get leccionEnlaceNecesitaUrl;

  /// No description provided for @leccionEspereRevision.
  ///
  /// In es, this message translates to:
  /// **'Espere a que termine la revisión del video.'**
  String get leccionEspereRevision;

  /// No description provided for @leccionSubidaCancelada.
  ///
  /// In es, this message translates to:
  /// **'Se canceló la subida. Si la lección ya tenía video, sigue igual.'**
  String get leccionSubidaCancelada;

  /// No description provided for @leccionEnlaceYoutube.
  ///
  /// In es, this message translates to:
  /// **'Enlace del video de YouTube'**
  String get leccionEnlaceYoutube;

  /// No description provided for @leccionYoutubeEncontrado.
  ///
  /// In es, this message translates to:
  /// **'Video de YouTube encontrado. Se guarda solo su id ({id}), no el enlace.'**
  String leccionYoutubeEncontrado(Object id);

  /// No description provided for @leccionEnlaceVimeo.
  ///
  /// In es, this message translates to:
  /// **'Enlace de Vimeo: se guarda tal cual y se ve con el reproductor de Vimeo.'**
  String get leccionEnlaceVimeo;

  /// No description provided for @leccionYaTieneVideo.
  ///
  /// In es, this message translates to:
  /// **'Esta lección ya tiene un video propio cargado. Pegar un enlace lo reemplaza.'**
  String get leccionYaTieneVideo;

  /// No description provided for @leccionPegueEnlace.
  ///
  /// In es, this message translates to:
  /// **'Pegue el enlace tal como lo copia de YouTube: sirven watch?v=, youtu.be, shorts y embed. También se acepta Vimeo.'**
  String get leccionPegueEnlace;

  /// No description provided for @leccionNueva.
  ///
  /// In es, this message translates to:
  /// **'Nueva lección'**
  String get leccionNueva;

  /// No description provided for @leccionEditar.
  ///
  /// In es, this message translates to:
  /// **'Editar lección'**
  String get leccionEditar;

  /// No description provided for @leccionSubiendo.
  ///
  /// In es, this message translates to:
  /// **'Subiendo…'**
  String get leccionSubiendo;

  /// No description provided for @leccionPegarYoutube.
  ///
  /// In es, this message translates to:
  /// **'Pegar link de YouTube'**
  String get leccionPegarYoutube;

  /// No description provided for @leccionSubirVideo.
  ///
  /// In es, this message translates to:
  /// **'Subir video'**
  String get leccionSubirVideo;

  /// No description provided for @leccionDuracionMinutos.
  ///
  /// In es, this message translates to:
  /// **'Duración (minutos)'**
  String get leccionDuracionMinutos;

  /// No description provided for @leccionArchivoDescargable.
  ///
  /// In es, this message translates to:
  /// **'Archivo descargable'**
  String get leccionArchivoDescargable;

  /// No description provided for @leccionArchivoActual.
  ///
  /// In es, this message translates to:
  /// **'Actual: {archivo}'**
  String leccionArchivoActual(Object archivo);

  /// No description provided for @leccionPreguntasEncuesta.
  ///
  /// In es, this message translates to:
  /// **'Preguntas de la encuesta (sin calificación)'**
  String get leccionPreguntasEncuesta;

  /// No description provided for @leccionPreguntasQuiz.
  ///
  /// In es, this message translates to:
  /// **'Preguntas (las califica el servidor)'**
  String get leccionPreguntasQuiz;

  /// No description provided for @leccionPregunta.
  ///
  /// In es, this message translates to:
  /// **'Pregunta'**
  String get leccionPregunta;

  /// No description provided for @leccionSinPreguntas.
  ///
  /// In es, this message translates to:
  /// **'Sin preguntas todavía. Una lección de quiz sin preguntas se guarda, pero quien la abra recibe un aviso en vez de una nota.'**
  String get leccionSinPreguntas;

  /// No description provided for @leccionPreguntaNumero.
  ///
  /// In es, this message translates to:
  /// **'Pregunta {numero}'**
  String leccionPreguntaNumero(Object numero);

  /// No description provided for @leccionQuitarPregunta.
  ///
  /// In es, this message translates to:
  /// **'Quitar pregunta'**
  String get leccionQuitarPregunta;

  /// No description provided for @leccionEnunciado.
  ///
  /// In es, this message translates to:
  /// **'Enunciado'**
  String get leccionEnunciado;

  /// No description provided for @leccionQuitarOpcion.
  ///
  /// In es, this message translates to:
  /// **'Quitar opción'**
  String get leccionQuitarOpcion;

  /// No description provided for @leccionOpcion.
  ///
  /// In es, this message translates to:
  /// **'Opción'**
  String get leccionOpcion;

  /// No description provided for @leccionRespuestaCorrecta.
  ///
  /// In es, this message translates to:
  /// **'Respuesta correcta:'**
  String get leccionRespuestaCorrecta;

  /// No description provided for @leccionRespuestaFlexible.
  ///
  /// In es, this message translates to:
  /// **'Respuesta correcta (se comparan tildes y mayúsculas de forma flexible)'**
  String get leccionRespuestaFlexible;

  /// No description provided for @leccionPalabraCompleta.
  ///
  /// In es, this message translates to:
  /// **'Palabra o frase que completa el enunciado'**
  String get leccionPalabraCompleta;

  /// No description provided for @leccionOrdenCorrecto.
  ///
  /// In es, this message translates to:
  /// **'Elementos en el orden CORRECTO — así se guardan, y así se califica quien los ordene igual:'**
  String get leccionOrdenCorrecto;

  /// No description provided for @leccionQuitarElemento.
  ///
  /// In es, this message translates to:
  /// **'Quitar elemento'**
  String get leccionQuitarElemento;

  /// No description provided for @leccionElemento.
  ///
  /// In es, this message translates to:
  /// **'Elemento'**
  String get leccionElemento;

  /// No description provided for @leccionInstrucciones.
  ///
  /// In es, this message translates to:
  /// **'Instrucciones de la actividad'**
  String get leccionInstrucciones;

  /// No description provided for @leccionFechaSinDefinir.
  ///
  /// In es, this message translates to:
  /// **'Fecha límite: sin definir'**
  String get leccionFechaSinDefinir;

  /// No description provided for @leccionMaxArchivos.
  ///
  /// In es, this message translates to:
  /// **'Máx. archivos'**
  String get leccionMaxArchivos;

  /// No description provided for @leccionPedirAlgo.
  ///
  /// In es, this message translates to:
  /// **'La actividad tiene que pedir al menos texto o archivo: si no, no hay nada que entregar.'**
  String get leccionPedirAlgo;

  /// No description provided for @leccionTiposEntregable.
  ///
  /// In es, this message translates to:
  /// **'Tipos de entregable aceptados (ninguno = cualquiera)'**
  String get leccionTiposEntregable;

  /// No description provided for @leccionCalificacion.
  ///
  /// In es, this message translates to:
  /// **'Calificación'**
  String get leccionCalificacion;

  /// No description provided for @leccionRubrica.
  ///
  /// In es, this message translates to:
  /// **'Rúbrica (criterios y puntos)'**
  String get leccionRubrica;

  /// No description provided for @leccionCriterio.
  ///
  /// In es, this message translates to:
  /// **'Criterio'**
  String get leccionCriterio;

  /// No description provided for @leccionPuntos.
  ///
  /// In es, this message translates to:
  /// **'Puntos'**
  String get leccionPuntos;

  /// No description provided for @leccionQuitarCriterio.
  ///
  /// In es, this message translates to:
  /// **'Quitar criterio'**
  String get leccionQuitarCriterio;

  /// No description provided for @leccionTotalPuntos.
  ///
  /// In es, this message translates to:
  /// **'Total: {total} puntos'**
  String leccionTotalPuntos(Object total);

  /// No description provided for @leccionOpcionNumero.
  ///
  /// In es, this message translates to:
  /// **'Opción {numero}'**
  String leccionOpcionNumero(Object numero);

  /// No description provided for @leccionOpcionCorrecta.
  ///
  /// In es, this message translates to:
  /// **'Opción {numero} (correcta)'**
  String leccionOpcionCorrecta(Object numero);

  /// No description provided for @glosarioDelModuloCon.
  ///
  /// In es, this message translates to:
  /// **'Glosario del módulo · {terminos}'**
  String glosarioDelModuloCon(Object terminos);

  /// No description provided for @glosarioEditorVacio.
  ///
  /// In es, this message translates to:
  /// **'Este módulo todavía no tiene términos. Los que agregue aparecen al final de las lecciones que marque y al final del módulo.'**
  String get glosarioEditorVacio;

  /// No description provided for @glosarioAgregarTermino.
  ///
  /// In es, this message translates to:
  /// **'Agregar término'**
  String get glosarioAgregarTermino;

  /// No description provided for @glosarioArrastrar.
  ///
  /// In es, this message translates to:
  /// **'Arrastrar para reordenar «{palabra}»'**
  String glosarioArrastrar(Object palabra);

  /// No description provided for @glosarioTieneImagen.
  ///
  /// In es, this message translates to:
  /// **'Tiene imagen'**
  String get glosarioTieneImagen;

  /// No description provided for @glosarioSinLeccion.
  ///
  /// In es, this message translates to:
  /// **'No está marcado en ninguna lección'**
  String get glosarioSinLeccion;

  /// No description provided for @glosarioEditarPalabra.
  ///
  /// In es, this message translates to:
  /// **'Editar «{palabra}»'**
  String glosarioEditarPalabra(Object palabra);

  /// No description provided for @glosarioEliminarPalabra.
  ///
  /// In es, this message translates to:
  /// **'Eliminar «{palabra}»'**
  String glosarioEliminarPalabra(Object palabra);

  /// No description provided for @glosarioEliminarTermino.
  ///
  /// In es, this message translates to:
  /// **'Eliminar término'**
  String get glosarioEliminarTermino;

  /// No description provided for @glosarioEliminarTerminoTexto.
  ///
  /// In es, this message translates to:
  /// **'¿Eliminar «{palabra}» del glosario? También se quita de los relacionados de otros términos y del repaso de los estudiantes.'**
  String glosarioEliminarTerminoTexto(Object palabra);

  /// No description provided for @glosarioPalabraObligatoria.
  ///
  /// In es, this message translates to:
  /// **'La palabra es obligatoria.'**
  String get glosarioPalabraObligatoria;

  /// No description provided for @glosarioYaExiste.
  ///
  /// In es, this message translates to:
  /// **'Ya existe «{palabra}» en este módulo.'**
  String glosarioYaExiste(Object palabra);

  /// No description provided for @glosarioYaExisteEn.
  ///
  /// In es, this message translates to:
  /// **'Ya existe «{palabra}» en el módulo «{modulo}».'**
  String glosarioYaExisteEn(Object palabra, Object modulo);

  /// No description provided for @glosarioDescartarTexto.
  ///
  /// In es, this message translates to:
  /// **'Hay cambios sin guardar en este término. ¿Desea salir de todas formas?'**
  String get glosarioDescartarTexto;

  /// No description provided for @glosarioTerminoAgregado.
  ///
  /// In es, this message translates to:
  /// **'Término agregado ✓'**
  String get glosarioTerminoAgregado;

  /// No description provided for @glosarioNuevoTermino.
  ///
  /// In es, this message translates to:
  /// **'Nuevo término'**
  String get glosarioNuevoTermino;

  /// No description provided for @glosarioEditarTermino.
  ///
  /// In es, this message translates to:
  /// **'Editar término'**
  String get glosarioEditarTermino;

  /// No description provided for @glosarioModulo.
  ///
  /// In es, this message translates to:
  /// **'Módulo: {modulo}'**
  String glosarioModulo(Object modulo);

  /// No description provided for @glosarioPalabraCampo.
  ///
  /// In es, this message translates to:
  /// **'Palabra o expresión *'**
  String get glosarioPalabraCampo;

  /// No description provided for @glosarioDefinicionCorta.
  ///
  /// In es, this message translates to:
  /// **'Definición corta *'**
  String get glosarioDefinicionCorta;

  /// No description provided for @glosarioDefinicionObligatoria.
  ///
  /// In es, this message translates to:
  /// **'La definición corta es obligatoria.'**
  String get glosarioDefinicionObligatoria;

  /// No description provided for @glosarioDefinicionAyuda.
  ///
  /// In es, this message translates to:
  /// **'Una o dos frases. Es lo que se ve en la tarjeta y al pasar el mouse sobre la palabra.'**
  String get glosarioDefinicionAyuda;

  /// No description provided for @glosarioExplicacion.
  ///
  /// In es, this message translates to:
  /// **'Explicación ampliada (opcional)'**
  String get glosarioExplicacion;

  /// No description provided for @glosarioEjemploOpcional.
  ///
  /// In es, this message translates to:
  /// **'Ejemplo (opcional)'**
  String get glosarioEjemploOpcional;

  /// No description provided for @glosarioImagenOpcional.
  ///
  /// In es, this message translates to:
  /// **'Imagen (opcional)'**
  String get glosarioImagenOpcional;

  /// No description provided for @glosarioQuitarImagen.
  ///
  /// In es, this message translates to:
  /// **'Quitar imagen'**
  String get glosarioQuitarImagen;

  /// No description provided for @glosarioPngJpg.
  ///
  /// In es, this message translates to:
  /// **'PNG o JPG.'**
  String get glosarioPngJpg;

  /// No description provided for @glosarioLeccionesDonde.
  ///
  /// In es, this message translates to:
  /// **'Lecciones donde aparece'**
  String get glosarioLeccionesDonde;

  /// No description provided for @glosarioModuloSinLecciones.
  ///
  /// In es, this message translates to:
  /// **'Este módulo todavía no tiene lecciones.'**
  String get glosarioModuloSinLecciones;

  /// No description provided for @glosarioRelacionadosTitulo.
  ///
  /// In es, this message translates to:
  /// **'Términos relacionados'**
  String get glosarioRelacionadosTitulo;

  /// No description provided for @glosarioRelacionadosAyuda.
  ///
  /// In es, this message translates to:
  /// **'Cuando el curso tenga más términos, podrá relacionarlos acá.'**
  String get glosarioRelacionadosAyuda;

  /// No description provided for @glosarioDeOtroModulo.
  ///
  /// In es, this message translates to:
  /// **'De otro módulo'**
  String get glosarioDeOtroModulo;

  /// No description provided for @seguimientoTitulo.
  ///
  /// In es, this message translates to:
  /// **'Seguimiento del Curso'**
  String get seguimientoTitulo;

  /// No description provided for @seguimientoInscritos.
  ///
  /// In es, this message translates to:
  /// **'Inscritos'**
  String get seguimientoInscritos;

  /// No description provided for @seguimientoCompletados.
  ///
  /// In es, this message translates to:
  /// **'Completados'**
  String get seguimientoCompletados;

  /// No description provided for @seguimientoAvancePromedio.
  ///
  /// In es, this message translates to:
  /// **'Avance promedio'**
  String get seguimientoAvancePromedio;

  /// No description provided for @seguimientoNotaPromedio.
  ///
  /// In es, this message translates to:
  /// **'Nota promedio'**
  String get seguimientoNotaPromedio;

  /// No description provided for @seguimientoSinEstudiantes.
  ///
  /// In es, this message translates to:
  /// **'Aún no hay estudiantes asignados a este curso.\nEl admin los asigna desde su portal.'**
  String get seguimientoSinEstudiantes;

  /// No description provided for @seguimientoAnaliticas.
  ///
  /// In es, this message translates to:
  /// **'Analíticas'**
  String get seguimientoAnaliticas;

  /// No description provided for @seguimientoNota.
  ///
  /// In es, this message translates to:
  /// **'Nota'**
  String get seguimientoNota;

  /// No description provided for @seguimientoUltimaActividad.
  ///
  /// In es, this message translates to:
  /// **'Última actividad'**
  String get seguimientoUltimaActividad;

  /// No description provided for @seguimientoEstado.
  ///
  /// In es, this message translates to:
  /// **'Estado'**
  String get seguimientoEstado;

  /// No description provided for @seguimientoComentarios.
  ///
  /// In es, this message translates to:
  /// **'Comentarios'**
  String get seguimientoComentarios;

  /// No description provided for @seguimientoCompletado.
  ///
  /// In es, this message translates to:
  /// **'Completado'**
  String get seguimientoCompletado;

  /// No description provided for @seguimientoSinIniciar.
  ///
  /// In es, this message translates to:
  /// **'Sin iniciar'**
  String get seguimientoSinIniciar;

  /// No description provided for @seguimientoNotaPrivada.
  ///
  /// In es, this message translates to:
  /// **'Nota privada: {nota}'**
  String seguimientoNotaPrivada(Object nota);

  /// No description provided for @seguimientoAgregarComentario.
  ///
  /// In es, this message translates to:
  /// **'Agregar comentario privado'**
  String get seguimientoAgregarComentario;

  /// No description provided for @seguimientoComentariosDe.
  ///
  /// In es, this message translates to:
  /// **'Comentarios privados — {nombre}'**
  String seguimientoComentariosDe(Object nombre);

  /// No description provided for @seguimientoRetroObservaciones.
  ///
  /// In es, this message translates to:
  /// **'Retroalimentación y observaciones'**
  String get seguimientoRetroObservaciones;

  /// No description provided for @seguimientoSoloDocentes.
  ///
  /// In es, this message translates to:
  /// **'Solo para el equipo docente. El estudiante NO la ve.'**
  String get seguimientoSoloDocentes;

  /// No description provided for @seguimientoAvanceCurso.
  ///
  /// In es, this message translates to:
  /// **'Avance del curso'**
  String get seguimientoAvanceCurso;

  /// No description provided for @comunSinDatos.
  ///
  /// In es, this message translates to:
  /// **'Sin datos'**
  String get comunSinDatos;

  /// No description provided for @seguimientoAvanceUniversidad.
  ///
  /// In es, this message translates to:
  /// **'Avance promedio por universidad (%)'**
  String get seguimientoAvanceUniversidad;

  /// No description provided for @seguimientoRiesgo.
  ///
  /// In es, this message translates to:
  /// **'Riesgo de abandono (sin iniciar)'**
  String get seguimientoRiesgo;

  /// No description provided for @seguimientoTiempoPromedio.
  ///
  /// In es, this message translates to:
  /// **'Tiempo promedio invertido'**
  String get seguimientoTiempoPromedio;

  /// No description provided for @seguimientoAvancePatrocinados.
  ///
  /// In es, this message translates to:
  /// **'Avance de patrocinados'**
  String get seguimientoAvancePatrocinados;

  /// No description provided for @seguimientoLeccionesTotales.
  ///
  /// In es, this message translates to:
  /// **'Lecciones totales'**
  String get seguimientoLeccionesTotales;

  /// No description provided for @glosarioApareceEn.
  ///
  /// In es, this message translates to:
  /// **'Aparece en {cantidad, plural, =1{1 lección} other{{cantidad} lecciones}}'**
  String glosarioApareceEn(int cantidad);

  /// No description provided for @seguimientoNotaYActividad.
  ///
  /// In es, this message translates to:
  /// **'Nota: {nota}  ·  {actividad}'**
  String seguimientoNotaYActividad(Object nota, Object actividad);

  /// No description provided for @adminPortalSuper.
  ///
  /// In es, this message translates to:
  /// **'Portal Super Admin'**
  String get adminPortalSuper;

  /// No description provided for @adminPortal.
  ///
  /// In es, this message translates to:
  /// **'Portal Admin'**
  String get adminPortal;

  /// No description provided for @tabUsuarios.
  ///
  /// In es, this message translates to:
  /// **'Usuarios'**
  String get tabUsuarios;

  /// No description provided for @tabEquipos.
  ///
  /// In es, this message translates to:
  /// **'Equipos'**
  String get tabEquipos;

  /// No description provided for @tabEvidenciasDonantes.
  ///
  /// In es, this message translates to:
  /// **'Evidencias donantes'**
  String get tabEvidenciasDonantes;

  /// No description provided for @tabEvidenciasCorto.
  ///
  /// In es, this message translates to:
  /// **'Evidencias'**
  String get tabEvidenciasCorto;

  /// No description provided for @tabContenidoPagina.
  ///
  /// In es, this message translates to:
  /// **'Contenido página'**
  String get tabContenidoPagina;

  /// No description provided for @tabContenidoCorto.
  ///
  /// In es, this message translates to:
  /// **'Contenido'**
  String get tabContenidoCorto;

  /// No description provided for @tabDatosRespaldos.
  ///
  /// In es, this message translates to:
  /// **'Datos y respaldos'**
  String get tabDatosRespaldos;

  /// No description provided for @tabRespaldosCorto.
  ///
  /// In es, this message translates to:
  /// **'Respaldos'**
  String get tabRespaldosCorto;

  /// No description provided for @adminDashboardGeneral.
  ///
  /// In es, this message translates to:
  /// **'Dashboard General'**
  String get adminDashboardGeneral;

  /// No description provided for @adminDashboardSubtitulo.
  ///
  /// In es, this message translates to:
  /// **'Estado global de la plataforma'**
  String get adminDashboardSubtitulo;

  /// No description provided for @adminImpactoFormativo.
  ///
  /// In es, this message translates to:
  /// **'Impacto formativo eduXaction'**
  String get adminImpactoFormativo;

  /// No description provided for @adminUsuariosPorRol.
  ///
  /// In es, this message translates to:
  /// **'Usuarios por rol'**
  String get adminUsuariosPorRol;

  /// No description provided for @adminEstudAbrev.
  ///
  /// In es, this message translates to:
  /// **'Estud.'**
  String get adminEstudAbrev;

  /// No description provided for @adminAsesores.
  ///
  /// In es, this message translates to:
  /// **'Asesores'**
  String get adminAsesores;

  /// No description provided for @adminEmpresas.
  ///
  /// In es, this message translates to:
  /// **'Empresas'**
  String get adminEmpresas;

  /// No description provided for @adminDonantes.
  ///
  /// In es, this message translates to:
  /// **'Donantes'**
  String get adminDonantes;

  /// No description provided for @adminProyectosPorEtapa.
  ///
  /// In es, this message translates to:
  /// **'Proyectos por etapa'**
  String get adminProyectosPorEtapa;

  /// No description provided for @adminConfigureMetricas.
  ///
  /// In es, this message translates to:
  /// **'Configure competencias, ODS y horas en los cursos (constructor del LXD) para ver métricas de impacto formativo.'**
  String get adminConfigureMetricas;

  /// No description provided for @adminHorasCompetencia.
  ///
  /// In es, this message translates to:
  /// **'Horas de formación por competencia'**
  String get adminHorasCompetencia;

  /// No description provided for @adminSinDatosAun.
  ///
  /// In es, this message translates to:
  /// **'Sin datos aún'**
  String get adminSinDatosAun;

  /// No description provided for @adminCoberturaOds.
  ///
  /// In es, this message translates to:
  /// **'Cobertura de ODS (estudiantes que completaron)'**
  String get adminCoberturaOds;

  /// No description provided for @adminSinCursosOds.
  ///
  /// In es, this message translates to:
  /// **'Sin cursos asociados a ODS aún'**
  String get adminSinCursosOds;

  /// No description provided for @adminOdsTooltip.
  ///
  /// In es, this message translates to:
  /// **'{ods} — {completados} de {total}'**
  String adminOdsTooltip(Object ods, Object completados, Object total);

  /// No description provided for @adminCalendarioSubtitulo.
  ///
  /// In es, this message translates to:
  /// **'Sesiones sincrónicas de Open Learning, eventos de Ruta de Impacto y mentorías de toda la plataforma'**
  String get adminCalendarioSubtitulo;

  /// No description provided for @asignarCursosOk.
  ///
  /// In es, this message translates to:
  /// **'Cursos asignados ✓'**
  String get asignarCursosOk;

  /// No description provided for @asignarLabsOk.
  ///
  /// In es, this message translates to:
  /// **'Laboratorios asignados ✓'**
  String get asignarLabsOk;

  /// No description provided for @asignarA.
  ///
  /// In es, this message translates to:
  /// **'Asignar a {nombre}'**
  String asignarA(Object nombre);

  /// No description provided for @asignarNoCarga.
  ///
  /// In es, this message translates to:
  /// **'No se pudo cargar lo asignado: {error}'**
  String asignarNoCarga(Object error);

  /// No description provided for @asignarExplicaOL.
  ///
  /// In es, this message translates to:
  /// **'Cuenta de Open Learning: recibe cursos uno por uno. Es su única vía de acceso a material — sin cursos asignados no tiene nada que ver. No tiene laboratorios ni Ruta de Impacto.'**
  String get asignarExplicaOL;

  /// No description provided for @asignarExplicaEdu.
  ///
  /// In es, this message translates to:
  /// **'Cuenta eduXaction: recibe laboratorios, y con ellos el acceso a TODOS sus cursos, sin asignarlos aparte. Quitar un laboratorio le quita ese material: su avance no se borra y vuelve tal cual si se le reasigna, pero mientras tanto deja de verlo.'**
  String get asignarExplicaEdu;

  /// No description provided for @asignarSinLabs.
  ///
  /// In es, this message translates to:
  /// **'No hay laboratorios creados todavía.'**
  String get asignarSinLabs;

  /// No description provided for @asignarSinCursos.
  ///
  /// In es, this message translates to:
  /// **'No hay cursos creados todavía.'**
  String get asignarSinCursos;

  /// No description provided for @asignarDeLaboratorio.
  ///
  /// In es, this message translates to:
  /// **'De laboratorio'**
  String get asignarDeLaboratorio;

  /// No description provided for @asignarPendientes.
  ///
  /// In es, this message translates to:
  /// **'{cantidad, plural, =1{Asignado. Este curso no está publicado, así que todavía no lo verá: {cursos}.} other{Asignado. Estos cursos no están publicados, así que todavía no los verá: {cursos}.}}'**
  String asignarPendientes(int cantidad, Object cursos);

  /// No description provided for @adminHorasPatrocinadas.
  ///
  /// In es, this message translates to:
  /// **'{empresa} ha patrocinado {horas} horas de formación'**
  String adminHorasPatrocinadas(Object empresa, Object horas);

  /// No description provided for @usuariosSubtituloSuper.
  ///
  /// In es, this message translates to:
  /// **'Crea y elimina cualquier tipo de cuenta (incluidos admins)'**
  String get usuariosSubtituloSuper;

  /// No description provided for @usuariosSubtitulo.
  ///
  /// In es, this message translates to:
  /// **'Crea cuentas de estudiantes, LXD, mentores, asesores, empresas y donantes'**
  String get usuariosSubtitulo;

  /// No description provided for @usuariosNuevo.
  ///
  /// In es, this message translates to:
  /// **'Nuevo usuario'**
  String get usuariosNuevo;

  /// No description provided for @comunTodos.
  ///
  /// In es, this message translates to:
  /// **'Todos'**
  String get comunTodos;

  /// No description provided for @usuariosSinRol.
  ///
  /// In es, this message translates to:
  /// **'No hay cuentas con ese rol.'**
  String get usuariosSinRol;

  /// No description provided for @usuariosUnaSolicitud.
  ///
  /// In es, this message translates to:
  /// **'1 solicitud de eliminación de cuenta'**
  String get usuariosUnaSolicitud;

  /// No description provided for @usuariosSolicitudes.
  ///
  /// In es, this message translates to:
  /// **'{cantidad} solicitudes de eliminación de cuenta'**
  String usuariosSolicitudes(Object cantidad);

  /// No description provided for @usuariosSolicitudesTexto.
  ///
  /// In es, this message translates to:
  /// **'Estas cuentas ya no funcionan. Falta borrar sus datos personales dentro del plazo de {dias} días que se les prometió.'**
  String usuariosSolicitudesTexto(Object dias);

  /// No description provided for @usuariosBorrarDatosDe.
  ///
  /// In es, this message translates to:
  /// **'Borrar los datos de {nombre}'**
  String usuariosBorrarDatosDe(Object nombre);

  /// No description provided for @usuariosBorrarDatosTexto.
  ///
  /// In es, this message translates to:
  /// **'Se borran su nombre, correo, teléfono, cédula, ciudad, foto y perfil, el nombre en sus certificados y las notas sobre esta persona. No se puede deshacer.'**
  String get usuariosBorrarDatosTexto;

  /// No description provided for @usuariosDatosBorrados.
  ///
  /// In es, this message translates to:
  /// **'Datos borrados.'**
  String get usuariosDatosBorrados;

  /// No description provided for @usuariosBorrando.
  ///
  /// In es, this message translates to:
  /// **'Borrando…'**
  String get usuariosBorrando;

  /// No description provided for @usuariosBorrarDatos.
  ///
  /// In es, this message translates to:
  /// **'Borrar datos'**
  String get usuariosBorrarDatos;

  /// No description provided for @usuariosRol.
  ///
  /// In es, this message translates to:
  /// **'Rol'**
  String get usuariosRol;

  /// No description provided for @usuariosDetalle.
  ///
  /// In es, this message translates to:
  /// **'Detalle'**
  String get usuariosDetalle;

  /// No description provided for @usuariosAcciones.
  ///
  /// In es, this message translates to:
  /// **'Acciones'**
  String get usuariosAcciones;

  /// No description provided for @usuariosCalifica.
  ///
  /// In es, this message translates to:
  /// **'Califica: {contextos}'**
  String usuariosCalifica(Object contextos);

  /// No description provided for @usuariosAsignarCursos.
  ///
  /// In es, this message translates to:
  /// **'Asignar cursos'**
  String get usuariosAsignarCursos;

  /// No description provided for @usuariosAsignarLabs.
  ///
  /// In es, this message translates to:
  /// **'Asignar laboratorios'**
  String get usuariosAsignarLabs;

  /// No description provided for @usuariosEliminar.
  ///
  /// In es, this message translates to:
  /// **'Eliminar usuario'**
  String get usuariosEliminar;

  /// No description provided for @usuariosEliminarTexto.
  ///
  /// In es, this message translates to:
  /// **'Va a eliminar a {nombre} ({rol}).'**
  String usuariosEliminarTexto(Object nombre, Object rol);

  /// No description provided for @usuariosCuentaEliminada.
  ///
  /// In es, this message translates to:
  /// **'Cuenta eliminada ✓'**
  String get usuariosCuentaEliminada;

  /// No description provided for @usuariosNombreCorreoObligatorios.
  ///
  /// In es, this message translates to:
  /// **'El nombre y el correo son obligatorios.'**
  String get usuariosNombreCorreoObligatorios;

  /// No description provided for @usuariosContrasenaMinima.
  ///
  /// In es, this message translates to:
  /// **'La contraseña necesita al menos 6 caracteres.'**
  String get usuariosContrasenaMinima;

  /// No description provided for @usuariosEscribaInstitucion.
  ///
  /// In es, this message translates to:
  /// **'Escriba el nombre de la institución en «¿Cuál institución?».'**
  String get usuariosEscribaInstitucion;

  /// No description provided for @usuariosEditar.
  ///
  /// In es, this message translates to:
  /// **'Editar usuario'**
  String get usuariosEditar;

  /// No description provided for @usuariosRolFijo.
  ///
  /// In es, this message translates to:
  /// **'Rol: {rol} — para cambiarlo, se crea otra cuenta. Cambiarlo acá movería su acceso sin que se note.'**
  String usuariosRolFijo(Object rol);

  /// No description provided for @usuariosNombreCompleto.
  ///
  /// In es, this message translates to:
  /// **'Nombre completo'**
  String get usuariosNombreCompleto;

  /// No description provided for @usuariosContrasenaNueva.
  ///
  /// In es, this message translates to:
  /// **'Contraseña nueva (opcional)'**
  String get usuariosContrasenaNueva;

  /// No description provided for @usuariosMinimoSeis.
  ///
  /// In es, this message translates to:
  /// **'Mínimo 6 caracteres.'**
  String get usuariosMinimoSeis;

  /// No description provided for @usuariosDejeEnBlanco.
  ///
  /// In es, this message translates to:
  /// **'Déjela en blanco para no cambiarla. Cambiarla cierra las sesiones abiertas de esa persona.'**
  String get usuariosDejeEnBlanco;

  /// No description provided for @usuariosSinUniversidadAsesor.
  ///
  /// In es, this message translates to:
  /// **'Sin universidad — no verá estudiantes'**
  String get usuariosSinUniversidadAsesor;

  /// No description provided for @usuariosNombreEmpresa.
  ///
  /// In es, this message translates to:
  /// **'Nombre de la empresa'**
  String get usuariosNombreEmpresa;

  /// No description provided for @usuariosCodigoImpacto.
  ///
  /// In es, this message translates to:
  /// **'Código de impacto único'**
  String get usuariosCodigoImpacto;

  /// No description provided for @usuariosTipoEstudiante.
  ///
  /// In es, this message translates to:
  /// **'Tipo de estudiante'**
  String get usuariosTipoEstudiante;

  /// No description provided for @usuariosSoloCursos.
  ///
  /// In es, this message translates to:
  /// **'Solo ve los cursos que le asigne. Sin laboratorios ni Ruta de Impacto.'**
  String get usuariosSoloCursos;

  /// No description provided for @usuariosVeLabs.
  ///
  /// In es, this message translates to:
  /// **'Ve Laboratorios y su Ruta de Impacto (se asignan desde el laboratorio).'**
  String get usuariosVeLabs;

  /// No description provided for @usuariosElijaUniversidad.
  ///
  /// In es, this message translates to:
  /// **'Elija una universidad'**
  String get usuariosElijaUniversidad;

  /// No description provided for @usuariosSinUniversidadOL.
  ///
  /// In es, this message translates to:
  /// **'Sin universidad (Open Learning)'**
  String get usuariosSinUniversidadOL;

  /// No description provided for @usuariosCiudadAyuda.
  ///
  /// In es, this message translates to:
  /// **'De dónde es — la ubica en el Mapa de Estudiantes'**
  String get usuariosCiudadAyuda;

  /// No description provided for @usuariosLxdEmpresa.
  ///
  /// In es, this message translates to:
  /// **'Si este LXD es de una empresa aliada, sus cursos quedan atribuidos a ella.'**
  String get usuariosLxdEmpresa;

  /// No description provided for @usuariosPermisoCalificar.
  ///
  /// In es, this message translates to:
  /// **'Permiso de calificar'**
  String get usuariosPermisoCalificar;

  /// No description provided for @usuariosCambioRegistrado.
  ///
  /// In es, this message translates to:
  /// **'Cada cambio queda registrado con quién lo hizo.'**
  String get usuariosCambioRegistrado;

  /// No description provided for @usuariosOLDefecto.
  ///
  /// In es, this message translates to:
  /// **'Activado por defecto: es quien califica ahí'**
  String get usuariosOLDefecto;

  /// No description provided for @usuariosEduDefecto.
  ///
  /// In es, this message translates to:
  /// **'Desactivado por defecto: ahí no califica'**
  String get usuariosEduDefecto;

  /// No description provided for @usuariosMentorLab.
  ///
  /// In es, this message translates to:
  /// **'El laboratorio se asigna desde la pestaña \"Laboratorios\" (un laboratorio puede tener varios mentores).'**
  String get usuariosMentorLab;

  /// No description provided for @usuariosMentorEmpresa.
  ///
  /// In es, this message translates to:
  /// **'Si este Mentor es de una empresa aliada, queda atribuido a ella.'**
  String get usuariosMentorEmpresa;

  /// No description provided for @usuariosEmpresaAliada.
  ///
  /// In es, this message translates to:
  /// **'Empresa aliada (opcional)'**
  String get usuariosEmpresaAliada;

  /// No description provided for @usuariosNingunaEdu.
  ///
  /// In es, this message translates to:
  /// **'Ninguna (de eduXaction)'**
  String get usuariosNingunaEdu;

  /// No description provided for @usuariosPidioEl.
  ///
  /// In es, this message translates to:
  /// **'{correo} · pidió el {fecha}'**
  String usuariosPidioEl(Object correo, Object fecha);

  /// No description provided for @usuariosQuedanDias.
  ///
  /// In es, this message translates to:
  /// **'{cantidad, plural, =1{queda 1 día} other{quedan {cantidad} días}}'**
  String usuariosQuedanDias(int cantidad);

  /// No description provided for @usuariosPlazoVencido.
  ///
  /// In es, this message translates to:
  /// **'plazo vencido'**
  String get usuariosPlazoVencido;

  /// No description provided for @usuariosNinguno.
  ///
  /// In es, this message translates to:
  /// **'ninguno'**
  String get usuariosNinguno;

  /// No description provided for @gestionProyectosSubtitulo.
  ///
  /// In es, this message translates to:
  /// **'Cada proyecto define problema, solución, comunidad, ODS, etapa e indicadores'**
  String get gestionProyectosSubtitulo;

  /// No description provided for @gestionNuevoProyecto.
  ///
  /// In es, this message translates to:
  /// **'Nuevo proyecto'**
  String get gestionNuevoProyecto;

  /// No description provided for @gestionSinProyectos.
  ///
  /// In es, this message translates to:
  /// **'No hay proyectos.'**
  String get gestionSinProyectos;

  /// No description provided for @gestionEliminarProyecto.
  ///
  /// In es, this message translates to:
  /// **'Eliminar proyecto'**
  String get gestionEliminarProyecto;

  /// No description provided for @gestionVaAEliminar.
  ///
  /// In es, this message translates to:
  /// **'Va a eliminar \"{nombre}\".'**
  String gestionVaAEliminar(Object nombre);

  /// No description provided for @gestionIntegrantes.
  ///
  /// In es, this message translates to:
  /// **'{cantidad, plural, =1{1 integrante} other{{cantidad} integrantes}}'**
  String gestionIntegrantes(int cantidad);

  /// No description provided for @gestionProyectoNombre.
  ///
  /// In es, this message translates to:
  /// **'El proyecto necesita un nombre.'**
  String get gestionProyectoNombre;

  /// No description provided for @gestionEditarProyecto.
  ///
  /// In es, this message translates to:
  /// **'Editar proyecto'**
  String get gestionEditarProyecto;

  /// No description provided for @gestionSinUniversidadReconciliar.
  ///
  /// In es, this message translates to:
  /// **'Sin universidad (pendiente de reconciliar)'**
  String get gestionSinUniversidadReconciliar;

  /// No description provided for @gestionIntegrantesUniversidad.
  ///
  /// In es, this message translates to:
  /// **'Sus integrantes tienen que ser de esta universidad.'**
  String get gestionIntegrantesUniversidad;

  /// No description provided for @gestionProblema.
  ///
  /// In es, this message translates to:
  /// **'Problema que resuelve'**
  String get gestionProblema;

  /// No description provided for @gestionSolucion.
  ///
  /// In es, this message translates to:
  /// **'Solución propuesta'**
  String get gestionSolucion;

  /// No description provided for @gestionComunidad.
  ///
  /// In es, this message translates to:
  /// **'Comunidad beneficiada'**
  String get gestionComunidad;

  /// No description provided for @gestionEtapaActual.
  ///
  /// In es, this message translates to:
  /// **'Etapa actual'**
  String get gestionEtapaActual;

  /// No description provided for @gestionHabilitarExpo.
  ///
  /// In es, this message translates to:
  /// **'Habilitar RUTA NATIONAL EXPO'**
  String get gestionHabilitarExpo;

  /// No description provided for @gestionHabilitarExpoTexto.
  ///
  /// In es, this message translates to:
  /// **'Abre la checklist de preparación para el equipo.'**
  String get gestionHabilitarExpoTexto;

  /// No description provided for @gestionEquiposSubtitulo.
  ///
  /// In es, this message translates to:
  /// **'Cada equipo trabaja un proyecto desde una universidad, con su asesor académico'**
  String get gestionEquiposSubtitulo;

  /// No description provided for @gestionNuevoEquipo.
  ///
  /// In es, this message translates to:
  /// **'Nuevo equipo'**
  String get gestionNuevoEquipo;

  /// No description provided for @gestionSinEquipos.
  ///
  /// In es, this message translates to:
  /// **'No hay equipos.'**
  String get gestionSinEquipos;

  /// No description provided for @gestionIntegrantesTitulo.
  ///
  /// In es, this message translates to:
  /// **'Integrantes'**
  String get gestionIntegrantesTitulo;

  /// No description provided for @gestionEliminarEquipo.
  ///
  /// In es, this message translates to:
  /// **'Eliminar equipo'**
  String get gestionEliminarEquipo;

  /// No description provided for @gestionEquipoNecesita.
  ///
  /// In es, this message translates to:
  /// **'El equipo necesita un nombre y un proyecto.'**
  String get gestionEquipoNecesita;

  /// No description provided for @gestionEditarEquipo.
  ///
  /// In es, this message translates to:
  /// **'Editar equipo'**
  String get gestionEditarEquipo;

  /// No description provided for @gestionNombreEquipo.
  ///
  /// In es, this message translates to:
  /// **'Nombre del equipo'**
  String get gestionNombreEquipo;

  /// No description provided for @gestionUniversidadDelProyecto.
  ///
  /// In es, this message translates to:
  /// **'Sale del proyecto. Para cambiarla, edite el proyecto.'**
  String get gestionUniversidadDelProyecto;

  /// No description provided for @gestionElijaProyecto.
  ///
  /// In es, this message translates to:
  /// **'Elija un proyecto'**
  String get gestionElijaProyecto;

  /// No description provided for @gestionProyectoSinUniversidad.
  ///
  /// In es, this message translates to:
  /// **'El proyecto todavía no tiene universidad'**
  String get gestionProyectoSinUniversidad;

  /// No description provided for @gestionAsesorOpcional.
  ///
  /// In es, this message translates to:
  /// **'Asesor académico (opcional)'**
  String get gestionAsesorOpcional;

  /// No description provided for @gestionAsesorAyuda.
  ///
  /// In es, this message translates to:
  /// **'El asesor acompaña al equipo, no al proyecto: un proyecto puede tener equipos de varias universidades.'**
  String get gestionAsesorAyuda;

  /// No description provided for @gestionSinAsesor.
  ///
  /// In es, this message translates to:
  /// **'Sin asesor'**
  String get gestionSinAsesor;

  /// No description provided for @gestionIntegrantesDe.
  ///
  /// In es, this message translates to:
  /// **'Integrantes de {nombre}'**
  String gestionIntegrantesDe(Object nombre);

  /// No description provided for @gestionSinEstudiantes.
  ///
  /// In es, this message translates to:
  /// **'No hay estudiantes para asignar.'**
  String get gestionSinEstudiantes;

  /// No description provided for @gestionRolProyecto.
  ///
  /// In es, this message translates to:
  /// **'El rol dentro del proyecto no es el rol de la plataforma: describe qué hace esa persona en el equipo.'**
  String get gestionRolProyecto;

  /// No description provided for @gestionLabsSubtitulo.
  ///
  /// In es, this message translates to:
  /// **'Cada laboratorio tiene su Ruta de Impacto de tres fases'**
  String get gestionLabsSubtitulo;

  /// No description provided for @gestionNuevoLab.
  ///
  /// In es, this message translates to:
  /// **'Nuevo laboratorio'**
  String get gestionNuevoLab;

  /// No description provided for @gestionSinLabs.
  ///
  /// In es, this message translates to:
  /// **'No hay laboratorios.'**
  String get gestionSinLabs;

  /// No description provided for @gestionEditarRuta.
  ///
  /// In es, this message translates to:
  /// **'Editar Ruta de Impacto'**
  String get gestionEditarRuta;

  /// No description provided for @gestionEliminarLab.
  ///
  /// In es, this message translates to:
  /// **'Eliminar laboratorio'**
  String get gestionEliminarLab;

  /// No description provided for @gestionEliminarLabTexto.
  ///
  /// In es, this message translates to:
  /// **'Va a eliminar \"{nombre}\" con toda su Ruta.'**
  String gestionEliminarLabTexto(Object nombre);

  /// No description provided for @gestionLabNombre.
  ///
  /// In es, this message translates to:
  /// **'El laboratorio necesita un nombre.'**
  String get gestionLabNombre;

  /// No description provided for @gestionEditarLab.
  ///
  /// In es, this message translates to:
  /// **'Editar laboratorio'**
  String get gestionEditarLab;

  /// No description provided for @gestionLabSeCrea.
  ///
  /// In es, this message translates to:
  /// **'Se crea con sus tres fases. Después se editan desde el editor de Ruta de Impacto.'**
  String get gestionLabSeCrea;

  /// No description provided for @gestionEmpresaOpcional.
  ///
  /// In es, this message translates to:
  /// **'Empresa patrocinadora (opcional)'**
  String get gestionEmpresaOpcional;

  /// No description provided for @gestionCursosSubtitulo.
  ///
  /// In es, this message translates to:
  /// **'Todos los cursos de la plataforma, de cualquier LXD'**
  String get gestionCursosSubtitulo;

  /// No description provided for @gestionSinCursosEstado.
  ///
  /// In es, this message translates to:
  /// **'No hay cursos con ese estado.'**
  String get gestionSinCursosEstado;

  /// No description provided for @gestionCompletaron.
  ///
  /// In es, this message translates to:
  /// **'{cantidad} completaron'**
  String gestionCompletaron(Object cantidad);

  /// No description provided for @gestionSinCalificar.
  ///
  /// In es, this message translates to:
  /// **'{cantidad} sin calificar'**
  String gestionSinCalificar(Object cantidad);

  /// No description provided for @gestionRutaModulo.
  ///
  /// In es, this message translates to:
  /// **'Ruta: {modulo}'**
  String gestionRutaModulo(Object modulo);

  /// No description provided for @gestionEvidenciasTitulo.
  ///
  /// In es, this message translates to:
  /// **'Evidencias para Donantes'**
  String get gestionEvidenciasTitulo;

  /// No description provided for @gestionEvidenciasSubtitulo.
  ///
  /// In es, this message translates to:
  /// **'Fotos, historias y reportes que ve cada donante en su portal'**
  String get gestionEvidenciasSubtitulo;

  /// No description provided for @gestionNuevaEvidencia.
  ///
  /// In es, this message translates to:
  /// **'Nueva evidencia'**
  String get gestionNuevaEvidencia;

  /// No description provided for @gestionSinEvidencias.
  ///
  /// In es, this message translates to:
  /// **'No hay evidencias todavía.'**
  String get gestionSinEvidencias;

  /// No description provided for @gestionEliminarEvidencia.
  ///
  /// In es, this message translates to:
  /// **'Eliminar evidencia'**
  String get gestionEliminarEvidencia;

  /// No description provided for @gestionEvidenciaNecesita.
  ///
  /// In es, this message translates to:
  /// **'La evidencia necesita un título y un donante.'**
  String get gestionEvidenciaNecesita;

  /// No description provided for @gestionEditarEvidencia.
  ///
  /// In es, this message translates to:
  /// **'Editar evidencia'**
  String get gestionEditarEvidencia;

  /// No description provided for @gestionTipo.
  ///
  /// In es, this message translates to:
  /// **'Tipo'**
  String get gestionTipo;

  /// No description provided for @gestionDonanteRecibe.
  ///
  /// In es, this message translates to:
  /// **'Donante que la recibe'**
  String get gestionDonanteRecibe;

  /// No description provided for @gestionSoloEseDonante.
  ///
  /// In es, this message translates to:
  /// **'Solo ese donante la ve en su portal.'**
  String get gestionSoloEseDonante;

  /// No description provided for @gestionArchivoOpcional.
  ///
  /// In es, this message translates to:
  /// **'Archivo (opcional)'**
  String get gestionArchivoOpcional;

  /// No description provided for @gestionYaTieneArchivo.
  ///
  /// In es, this message translates to:
  /// **'Ya tiene un archivo. Subir otro lo reemplaza.'**
  String get gestionYaTieneArchivo;

  /// No description provided for @rutaEditorHerramienta.
  ///
  /// In es, this message translates to:
  /// **'el editor de la Ruta de Impacto'**
  String get rutaEditorHerramienta;

  /// No description provided for @rutaEditorVersion.
  ///
  /// In es, this message translates to:
  /// **'Versión de contenido {version}'**
  String rutaEditorVersion(Object version);

  /// No description provided for @rutaEditorVersionTexto.
  ///
  /// In es, this message translates to:
  /// **'Los certificados quedan anclados a la versión de contenido con la que se emitieron: agregar módulos después no invalida los que ya se entregaron.'**
  String get rutaEditorVersionTexto;

  /// No description provided for @rutaEditorAcompanan.
  ///
  /// In es, this message translates to:
  /// **'Quiénes lo acompañan'**
  String get rutaEditorAcompanan;

  /// No description provided for @rutaEditorSinMentores.
  ///
  /// In es, this message translates to:
  /// **'Todavía sin mentores ni LXD.'**
  String get rutaEditorSinMentores;

  /// No description provided for @rutaEditorMentoresDe.
  ///
  /// In es, this message translates to:
  /// **'Mentores de {nombre}'**
  String rutaEditorMentoresDe(Object nombre);

  /// No description provided for @rutaEditorMentoresAyuda.
  ///
  /// In es, this message translates to:
  /// **'Un laboratorio puede tener varios mentores, y todos ven a sus estudiantes.'**
  String get rutaEditorMentoresAyuda;

  /// No description provided for @rutaEditorEstudiantesCantidad.
  ///
  /// In es, this message translates to:
  /// **'Estudiantes ({cantidad})'**
  String rutaEditorEstudiantesCantidad(Object cantidad);

  /// No description provided for @rutaEditorEstudiantesDe.
  ///
  /// In es, this message translates to:
  /// **'Estudiantes de {nombre}'**
  String rutaEditorEstudiantesDe(Object nombre);

  /// No description provided for @rutaEditorEstudiantesAyuda.
  ///
  /// In es, this message translates to:
  /// **'Asignar a alguien acá le da acceso a los CURSOS del laboratorio. Quitarlo se lo quita: su avance no se borra, pero deja de verlo. Solo estudiantes eduXaction.'**
  String get rutaEditorEstudiantesAyuda;

  /// No description provided for @rutaEditorSinCuentas.
  ///
  /// In es, this message translates to:
  /// **'No hay cuentas disponibles.'**
  String get rutaEditorSinCuentas;

  /// No description provided for @rutaEditorEditarFase.
  ///
  /// In es, this message translates to:
  /// **'Editar la fase'**
  String get rutaEditorEditarFase;

  /// No description provided for @rutaEditorFasesTres.
  ///
  /// In es, this message translates to:
  /// **'Las fases son siempre tres: se editan, no se agregan ni se borran. Una Ruta con dos fases no se puede completar.'**
  String get rutaEditorFasesTres;

  /// No description provided for @rutaEditorObjetivo.
  ///
  /// In es, this message translates to:
  /// **'Objetivo'**
  String get rutaEditorObjetivo;

  /// No description provided for @rutaEditorSinObjetivos.
  ///
  /// In es, this message translates to:
  /// **'Sin objetivos todavía.'**
  String get rutaEditorSinObjetivos;

  /// No description provided for @rutaEditorCursosCumplen.
  ///
  /// In es, this message translates to:
  /// **'Cursos que lo cumplen'**
  String get rutaEditorCursosCumplen;

  /// No description provided for @rutaEditorQuitarObjetivo.
  ///
  /// In es, this message translates to:
  /// **'Quitar objetivo'**
  String get rutaEditorQuitarObjetivo;

  /// No description provided for @rutaEditorQuitarObjetivoTexto.
  ///
  /// In es, this message translates to:
  /// **'¿Quitar \"{objetivo}\" de la fase?'**
  String rutaEditorQuitarObjetivoTexto(Object objetivo);

  /// No description provided for @rutaEditorSinCursosTraba.
  ///
  /// In es, this message translates to:
  /// **'Sin cursos vinculados no se puede completar nunca, y eso traba la fase entera para todo el laboratorio.'**
  String get rutaEditorSinCursosTraba;

  /// No description provided for @rutaEditorObjetivoTexto.
  ///
  /// In es, this message translates to:
  /// **'El objetivo necesita su texto.'**
  String get rutaEditorObjetivoTexto;

  /// No description provided for @rutaEditorNuevoObjetivo.
  ///
  /// In es, this message translates to:
  /// **'Nuevo objetivo'**
  String get rutaEditorNuevoObjetivo;

  /// No description provided for @rutaEditorEditarObjetivo.
  ///
  /// In es, this message translates to:
  /// **'Editar objetivo'**
  String get rutaEditorEditarObjetivo;

  /// No description provided for @rutaEditorCategoria.
  ///
  /// In es, this message translates to:
  /// **'Categoría'**
  String get rutaEditorCategoria;

  /// No description provided for @rutaEditorVincular.
  ///
  /// In es, this message translates to:
  /// **'Después hay que vincularle los cursos que lo cumplen: sin ellos no se completa nunca.'**
  String get rutaEditorVincular;

  /// No description provided for @rutaEditorCursosCumplenTitulo.
  ///
  /// In es, this message translates to:
  /// **'Cursos que cumplen el objetivo'**
  String get rutaEditorCursosCumplenTitulo;

  /// No description provided for @rutaEditorCumplido.
  ///
  /// In es, this message translates to:
  /// **'\"{objetivo}\" se da por cumplido cuando el estudiante termina el 100% de TODOS los cursos marcados.'**
  String rutaEditorCumplido(Object objetivo);

  /// No description provided for @rutaEditorSinMarcados.
  ///
  /// In es, this message translates to:
  /// **'Sin ninguno marcado, este objetivo no se completa nunca.'**
  String get rutaEditorSinMarcados;

  /// No description provided for @rutaEditorModulos.
  ///
  /// In es, this message translates to:
  /// **'Módulos'**
  String get rutaEditorModulos;

  /// No description provided for @rutaEditorUltimoMentoria.
  ///
  /// In es, this message translates to:
  /// **'El último módulo de la fase es siempre el de mentoría. Se recalcula solo al agregar, quitar o reordenar.'**
  String get rutaEditorUltimoMentoria;

  /// No description provided for @rutaEditorSinModulos.
  ///
  /// In es, this message translates to:
  /// **'Sin módulos todavía.'**
  String get rutaEditorSinModulos;

  /// No description provided for @rutaEditorCursosModulo.
  ///
  /// In es, this message translates to:
  /// **'Cursos del módulo'**
  String get rutaEditorCursosModulo;

  /// No description provided for @rutaEditorRenombrar.
  ///
  /// In es, this message translates to:
  /// **'Renombrar'**
  String get rutaEditorRenombrar;

  /// No description provided for @rutaEditorEliminarModuloTexto.
  ///
  /// In es, this message translates to:
  /// **'Va a eliminar \"{modulo}\" con sus {cantidad} lecciones propias.'**
  String rutaEditorEliminarModuloTexto(Object modulo, Object cantidad);

  /// No description provided for @rutaEditorCursosCantidad.
  ///
  /// In es, this message translates to:
  /// **'{cantidad, plural, =1{1 curso} other{{cantidad} cursos}}'**
  String rutaEditorCursosCantidad(int cantidad);

  /// No description provided for @rutaEditorImportados.
  ///
  /// In es, this message translates to:
  /// **'Se agregaron {cantidad} objetivos del curso a la fase.'**
  String rutaEditorImportados(Object cantidad);

  /// No description provided for @rutaEditorCursosDe.
  ///
  /// In es, this message translates to:
  /// **'Cursos de {modulo}'**
  String rutaEditorCursosDe(Object modulo);

  /// No description provided for @rutaEditorCursoUnModulo.
  ///
  /// In es, this message translates to:
  /// **'Un curso vive en un solo módulo de esta Ruta: en dos, su avance se contaría dos veces. Al vincularlo, sus objetivos categorizados se agregan a la fase.'**
  String get rutaEditorCursoUnModulo;

  /// No description provided for @respaldoTitulo.
  ///
  /// In es, this message translates to:
  /// **'Datos y Copias de Seguridad'**
  String get respaldoTitulo;

  /// No description provided for @respaldoSubtitulo.
  ///
  /// In es, this message translates to:
  /// **'Dónde viven los datos y cómo respaldarlos'**
  String get respaldoSubtitulo;

  /// No description provided for @respaldoEstadoActual.
  ///
  /// In es, this message translates to:
  /// **'Estado actual'**
  String get respaldoEstadoActual;

  /// No description provided for @respaldoRespaldo.
  ///
  /// In es, this message translates to:
  /// **'Respaldo'**
  String get respaldoRespaldo;

  /// No description provided for @respaldoDondeDatos.
  ///
  /// In es, this message translates to:
  /// **'¿Dónde se guardan los datos?'**
  String get respaldoDondeDatos;

  /// No description provided for @respaldoDondeDatosTexto.
  ///
  /// In es, this message translates to:
  /// **'Los datos viven en la base de datos del servidor, no en este navegador. Cerrar sesión, cambiar de computador o entrar desde otro dispositivo no cambia nada: cada quien ve lo mismo.\n\nLos archivos (fotos, PDF, videos) se guardan aparte, en el almacenamiento de objetos, y el respaldo NO los incluye: guarda las referencias, no los archivos.\n\nUna copia de seguridad tampoco lleva credenciales. Las contraseñas y las sesiones abiertas quedan fuera a propósito: un respaldo es para restaurar datos, no para llevárselas.'**
  String get respaldoDondeDatosTexto;

  /// No description provided for @respaldoEntregasSinRevisar.
  ///
  /// In es, this message translates to:
  /// **'Entregas sin revisar'**
  String get respaldoEntregasSinRevisar;

  /// No description provided for @respaldoPreparando.
  ///
  /// In es, this message translates to:
  /// **'Preparando…'**
  String get respaldoPreparando;

  /// No description provided for @respaldoDescargar.
  ///
  /// In es, this message translates to:
  /// **'Descargar copia de seguridad'**
  String get respaldoDescargar;

  /// No description provided for @respaldoRestaurarArchivo.
  ///
  /// In es, this message translates to:
  /// **'Restaurar desde archivo'**
  String get respaldoRestaurarArchivo;

  /// No description provided for @respaldoSoloComputador.
  ///
  /// In es, this message translates to:
  /// **'Restaurar una copia reemplaza la base entera: solo se puede hacer desde un computador.'**
  String get respaldoSoloComputador;

  /// No description provided for @respaldoReemplaza.
  ///
  /// In es, this message translates to:
  /// **'Restaurar reemplaza la base entera por la del archivo. No se puede deshacer.'**
  String get respaldoReemplaza;

  /// No description provided for @respaldoSoloSuper.
  ///
  /// In es, this message translates to:
  /// **'Restaurar reemplaza la base entera, así que solo lo puede hacer un Super Admin.'**
  String get respaldoSoloSuper;

  /// No description provided for @respaldoGuardarCopia.
  ///
  /// In es, this message translates to:
  /// **'Guardar copia de seguridad'**
  String get respaldoGuardarCopia;

  /// No description provided for @respaldoCopiaDescargada.
  ///
  /// In es, this message translates to:
  /// **'Copia descargada ✓'**
  String get respaldoCopiaDescargada;

  /// No description provided for @respaldoSeleccioneArchivo.
  ///
  /// In es, this message translates to:
  /// **'Seleccione el archivo de respaldo'**
  String get respaldoSeleccioneArchivo;

  /// No description provided for @respaldoRestaurarCopia.
  ///
  /// In es, this message translates to:
  /// **'Restaurar copia de seguridad'**
  String get respaldoRestaurarCopia;

  /// No description provided for @respaldoRestaurarTexto.
  ///
  /// In es, this message translates to:
  /// **'La base entera se reemplaza por la del archivo \"{archivo}\". No se puede deshacer.'**
  String respaldoRestaurarTexto(Object archivo);

  /// No description provided for @respaldoNoValido.
  ///
  /// In es, this message translates to:
  /// **'Ese archivo no es un respaldo válido: no se pudo leer como JSON.'**
  String get respaldoNoValido;

  /// No description provided for @respaldoRestaurado.
  ///
  /// In es, this message translates to:
  /// **'Datos restaurados ✓'**
  String get respaldoRestaurado;

  /// No description provided for @contenidoHerramienta.
  ///
  /// In es, this message translates to:
  /// **'la edición de la página principal'**
  String get contenidoHerramienta;

  /// No description provided for @contenidoTitulo.
  ///
  /// In es, this message translates to:
  /// **'Contenido de la Página Principal'**
  String get contenidoTitulo;

  /// No description provided for @contenidoSubtitulo.
  ///
  /// In es, this message translates to:
  /// **'Hero, banner y textos visibles para el público'**
  String get contenidoSubtitulo;

  /// No description provided for @contenidoTituloVacio.
  ///
  /// In es, this message translates to:
  /// **'El título del hero no puede quedar vacío.'**
  String get contenidoTituloVacio;

  /// No description provided for @contenidoActualizado.
  ///
  /// In es, this message translates to:
  /// **'Página principal actualizada ✓'**
  String get contenidoActualizado;

  /// No description provided for @contenidoImagenesPublicadas.
  ///
  /// In es, this message translates to:
  /// **'Imágenes publicadas ✓'**
  String get contenidoImagenesPublicadas;

  /// No description provided for @contenidoTituloHero.
  ///
  /// In es, this message translates to:
  /// **'Título del hero'**
  String get contenidoTituloHero;

  /// No description provided for @contenidoSubtituloHero.
  ///
  /// In es, this message translates to:
  /// **'Subtítulo del hero'**
  String get contenidoSubtituloHero;

  /// No description provided for @contenidoBanner.
  ///
  /// In es, this message translates to:
  /// **'Banner de anuncio (vacío = oculto)'**
  String get contenidoBanner;

  /// No description provided for @contenidoSobreNosotros.
  ///
  /// In es, this message translates to:
  /// **'Texto \"Sobre nosotros\"'**
  String get contenidoSobreNosotros;

  /// No description provided for @contenidoLinkVideollamada.
  ///
  /// In es, this message translates to:
  /// **'Link de videollamada (módulos de mentoría)'**
  String get contenidoLinkVideollamada;

  /// No description provided for @contenidoLinkAyuda.
  ///
  /// In es, this message translates to:
  /// **'Un solo enlace genérico: todavía no hay integración con un proveedor de reuniones.'**
  String get contenidoLinkAyuda;

  /// No description provided for @contenidoCifras.
  ///
  /// In es, this message translates to:
  /// **'Cifras del hero'**
  String get contenidoCifras;

  /// No description provided for @contenidoCifrasAyuda.
  ///
  /// In es, this message translates to:
  /// **'Los cuatro números bajo el título. Se escriben a mano a propósito: son la cifra que el equipo quiere comunicar, no el conteo de la base — ese vive en el panel.'**
  String get contenidoCifrasAyuda;

  /// No description provided for @contenidoGuardarCambios.
  ///
  /// In es, this message translates to:
  /// **'Guardar cambios'**
  String get contenidoGuardarCambios;

  /// No description provided for @contenidoGaleria.
  ///
  /// In es, this message translates to:
  /// **'Galería de imágenes'**
  String get contenidoGaleria;

  /// No description provided for @contenidoGaleriaAyuda.
  ///
  /// In es, this message translates to:
  /// **'Se muestran en la página principal, entre los laboratorios y el cierre. Quitar una la saca de la portada de inmediato.'**
  String get contenidoGaleriaAyuda;

  /// No description provided for @contenidoGaleriaVacia.
  ///
  /// In es, this message translates to:
  /// **'Todavía no hay imágenes en la galería.'**
  String get contenidoGaleriaVacia;

  /// No description provided for @contenidoSacarImagen.
  ///
  /// In es, this message translates to:
  /// **'¿Sacarla de la página principal?'**
  String get contenidoSacarImagen;

  /// No description provided for @contenidoPublicar.
  ///
  /// In es, this message translates to:
  /// **'Publicar {cantidad} en la portada'**
  String contenidoPublicar(Object cantidad);

  /// No description provided for @respaldoNombreArchivo.
  ///
  /// In es, this message translates to:
  /// **'enactus_respaldo_{fecha}.json'**
  String respaldoNombreArchivo(Object fecha);
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
