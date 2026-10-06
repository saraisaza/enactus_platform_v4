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
