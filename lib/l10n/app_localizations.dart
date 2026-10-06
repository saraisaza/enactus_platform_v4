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
