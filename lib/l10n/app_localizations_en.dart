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

  @override
  String get etapaValidacion => 'Validation';

  @override
  String get etapaPrototipo => 'Prototype';

  @override
  String get etapaPiloto => 'Pilot';

  @override
  String get etapaEscalamiento => 'Scaling';

  @override
  String get etapaIdeacion => 'Ideation';

  @override
  String get rolLider => 'Leader';

  @override
  String get rolInvestigacion => 'Research';

  @override
  String get rolFinanzas => 'Finance';

  @override
  String get rolComunicaciones => 'Communications';

  @override
  String get rolDiseno => 'Design';

  @override
  String get rolOperaciones => 'Operations';

  @override
  String get rolIntegrante => 'Member';

  @override
  String get categoriaEmpresarial => 'Business';

  @override
  String get categoriaEmprendimiento => 'Entrepreneurship';

  @override
  String get nivelIntermedio => 'Intermediate';

  @override
  String get nivelAvanzado => 'Advanced';

  @override
  String get nivelBasico => 'Basic';

  @override
  String get estadoPublicado => 'Published';

  @override
  String get estadoArchivado => 'Archived';

  @override
  String get estadoBorrador => 'Draft';

  @override
  String odsEtiqueta(Object numero, Object titulo) {
    return 'SDG $numero: $titulo';
  }

  @override
  String get idiomaCursoIngles => 'English';

  @override
  String get idiomaCursoPortugues => 'Portuguese';

  @override
  String get idiomaCursoEspanol => 'Spanish';

  @override
  String get tipoArchivoVideo => 'Video';

  @override
  String get tipoArchivoDocumento => 'Document';

  @override
  String get tipoArchivoImagen => 'Image';

  @override
  String get calificacionAprobadoReprobado => 'Pass / Fail';

  @override
  String get calificacionSoloRevision => 'Review only';

  @override
  String get calificacionEscala5 => 'Scale 0-5';

  @override
  String get calificacionPuntaje100 => 'Score 0-100';

  @override
  String get calificacionPendiente => 'Pending';

  @override
  String get calificacionAprobado => 'Passed';

  @override
  String get calificacionReprobado => 'Failed';

  @override
  String get calificacionRevisado => 'Reviewed';

  @override
  String get entregaGrupal => 'Group submission';

  @override
  String get evidenciaFoto => 'Photo';

  @override
  String get evidenciaTestimonio => 'Testimonial';

  @override
  String get evidenciaReporte => 'Report';

  @override
  String get evidenciaHistoria => 'Story';

  @override
  String get foroCategoriaAvance => 'Progress';

  @override
  String get foroCategoriaRecurso => 'Resource';

  @override
  String get foroCategoriaAnuncio => 'Announcement';

  @override
  String get foroCategoriaPregunta => 'Question';

  @override
  String get eventoSesionOpenLearning => 'Open Learning session';

  @override
  String get rutaDeImpacto => 'Impact Path';

  @override
  String get eventoMentoria => 'Mentoring';

  @override
  String get ods1 => 'No poverty';

  @override
  String get ods2 => 'Zero hunger';

  @override
  String get ods3 => 'Good health and well-being';

  @override
  String get ods4 => 'Quality education';

  @override
  String get ods5 => 'Gender equality';

  @override
  String get ods6 => 'Clean water and sanitation';

  @override
  String get ods7 => 'Affordable and clean energy';

  @override
  String get ods8 => 'Decent work and economic growth';

  @override
  String get ods9 => 'Industry, innovation and infrastructure';

  @override
  String get ods10 => 'Reduced inequalities';

  @override
  String get ods11 => 'Sustainable cities and communities';

  @override
  String get ods12 => 'Responsible consumption and production';

  @override
  String get ods13 => 'Climate action';

  @override
  String get ods14 => 'Life below water';

  @override
  String get ods15 => 'Life on land';

  @override
  String get ods16 => 'Peace, justice and strong institutions';

  @override
  String get ods17 => 'Partnerships for the goals';

  @override
  String get competenciaLeadership => 'Leadership';

  @override
  String get competenciaInnovation => 'Innovation';

  @override
  String get competenciaEntrepreneurship => 'Entrepreneurship';

  @override
  String get competenciaFinance => 'Finance';

  @override
  String get competenciaCommunication => 'Communication';

  @override
  String get competenciaPitch => 'Pitch';

  @override
  String get competenciaSustainability => 'Sustainability';

  @override
  String get competenciaArtificialIntelligence => 'Artificial Intelligence';

  @override
  String get competenciaTeamwork => 'Teamwork';

  @override
  String get competenciaUserCenteredDesign => 'User-Centered Design';

  @override
  String get competenciaProjectManagement => 'Project Management';

  @override
  String get competenciaImpactMeasurement => 'Impact Measurement';

  @override
  String errorSubidaFallo(Object status) {
    return 'The file could not be uploaded ($status). If the problem continues, let the technical team know.';
  }

  @override
  String get errorSubidaLenta =>
      'The upload took too long. Try again with a more stable connection.';

  @override
  String get errorServidorLento => 'The server took too long to respond.';

  @override
  String get errorRespuestaInesperadaServidor =>
      'The server returned an unexpected response.';

  @override
  String get errorDatosNoValidos => 'The data sent is not valid.';

  @override
  String get errorSesionExpirada =>
      'Your session has expired. Please sign in again.';

  @override
  String get errorSinPermiso => 'You do not have permission to see this.';

  @override
  String get errorNoEncontrado => 'We could not find what you are looking for.';

  @override
  String get errorOperacionNoPosible =>
      'This operation cannot be done right now.';

  @override
  String get errorArchivoGrande => 'The file is too large.';

  @override
  String get errorDemasiadosIntentos =>
      'Too many attempts. Please wait a moment.';

  @override
  String get errorServidorIntente =>
      'The server had a problem. Please try again.';

  @override
  String get errorRespuestaInesperada => 'Unexpected response from the server.';

  @override
  String get certificadoTitulo => 'CERTIFICATE OF COMPLETION';

  @override
  String get certificadoSeCertifica => 'This certifies that';

  @override
  String get certificadoCompleto =>
      'completed the Impact Path of the laboratory';

  @override
  String certificadoIntensidad(Object horas) {
    return 'Duration: $horas certified hours';
  }

  @override
  String get certificadoEmitidoPor => 'Issued by';

  @override
  String get certificadoFechaEmision => 'Date of issue';

  @override
  String certificadoCodigo(Object codigo) {
    return 'Verification code: $codigo';
  }

  @override
  String get certificadoPie =>
      'eduXaction Colombia · Non-profit organization · Bogotá D.C.';

  @override
  String certificadoTituloVisor(Object laboratorio) {
    return 'Certificate · $laboratorio';
  }

  @override
  String certificadoArchivo(Object codigo) {
    return 'certificate_$codigo.pdf';
  }

  @override
  String get errorSubidaInterrumpida =>
      'The file could not be uploaded: the connection was interrupted.';

  @override
  String get errorSubidaTardo => 'The upload took too long.';

  @override
  String get errorSubidaCancelada => 'The upload was canceled.';

  @override
  String get errorVideoConexionNoResponde =>
      'The connection stopped responding while the video was uploading.';

  @override
  String get errorVideoConexionCortada =>
      'The connection dropped while the video was uploading.';

  @override
  String get videoNavegadorNoAbre =>
      'This browser could not open the video. It may be damaged; export it again as MP4 (H.264 with AAC audio).';

  @override
  String videoPortadaPesada(Object peso) {
    return 'The cover image is $peso and the maximum is 5 MB.';
  }

  @override
  String videoParteRechazada(Object status) {
    return 'Storage rejected part of the video ($status).';
  }

  @override
  String get mp4SoloMp4 =>
      'Only MP4 videos are accepted (H.264 with AAC audio).';

  @override
  String mp4SoloMp4Ext(Object ext) {
    return 'Only MP4 videos are accepted (H.264 with AAC audio); this file is .$ext. Export it as MP4 and try again.';
  }

  @override
  String get mp4Vacio => 'The file is empty.';

  @override
  String mp4Pesado(Object peso) {
    return 'The video is $peso and the maximum is 500 MB. Compress it (for example with HandBrake, preset “Fast 1080p30”) and try again.';
  }

  @override
  String get mp4Danado =>
      'The MP4 could not be read: the file is incomplete or damaged. Export it again.';

  @override
  String get mp4NoEsMp4 =>
      'This file is not an MP4 even though it is named like one. Export it as MP4 (H.264 with AAC audio).';

  @override
  String get mp4SinIndice =>
      'The MP4 could not be read: it is missing the video index, so it is incomplete or damaged. Export it again.';

  @override
  String get mp4SoloAudio =>
      'This file has no picture: it seems to be audio only.';

  @override
  String get mp4Drm =>
      'This video is copy-protected (DRM) and cannot be played on the platform.';

  @override
  String get mp4Hevc =>
      'This MP4 is in H.265 (HEVC), the format the iPhone records in, and many browsers cannot play it. Export it in H.264: on the iPhone, Settings › Camera › Formats › “Most Compatible”; on a computer, with HandBrake and the “Fast 1080p30” preset.';

  @override
  String get mp4Mpeg4Parte2 => 'MPEG-4 Part 2';

  @override
  String mp4FormatoVideo(Object nombre) {
    return 'This MP4 uses the $nombre video format, which not all browsers can play. Export it in H.264 with AAC audio.';
  }

  @override
  String get mp4PcmSinComprimir => 'Uncompressed PCM';

  @override
  String mp4FormatoAudio(Object nombre) {
    return 'The audio in this MP4 is in $nombre, and not all browsers can play it. Export it with AAC audio.';
  }

  @override
  String get errorSinSesion => 'There is no active session.';

  @override
  String get errorRespuestaInesperadaRecibida =>
      'We received an unexpected response from the server.';

  @override
  String get rolSuperAdmin => 'Super Admin';

  @override
  String get rolAdministrador => 'Administrator';

  @override
  String get rolEstudiante => 'Student';

  @override
  String get rolAlumni => 'Alumni';

  @override
  String get rolMentor => 'Mentor';

  @override
  String get rolAsesorAcademico => 'Academic Advisor';

  @override
  String get rolEmpresa => 'Company';

  @override
  String get rolDonante => 'Donor';

  @override
  String get pieInstitucional =>
      'Non-profit organization. Founded in 2021. Bogotá D.C., Colombia.';

  @override
  String get youtubeNoEsVideo =>
      'That link is from YouTube, but not for a video (it looks like a channel or a playlist). Open the video and copy its link.';

  @override
  String get youtubePegueEnlace =>
      'Paste the link to a YouTube video, for example https://www.youtube.com/watch?v=… or https://youtu.be/…';

  @override
  String get errorSinConexion =>
      'We could not connect to the server. Check your connection.';

  @override
  String get errorServidorMomento =>
      'The server had a problem. Please try again in a moment.';

  @override
  String get pieLema => 'We develop leaders who transform communities 💛';

  @override
  String pieDerechos(Object anio) {
    return '© $anio eduXaction Colombia — All rights reserved';
  }

  @override
  String get pieHechoEn => 'Made with 💛 in Bogotá';

  @override
  String get comunMenu => 'Menu';

  @override
  String get comunBuscar => 'Search';

  @override
  String get busquedaTipoCurso => 'Course';

  @override
  String get busquedaTipoProyecto => 'Project';

  @override
  String busquedaEtapa(Object etapa) {
    return 'Stage: $etapa';
  }

  @override
  String get comunCerrar => 'Close';

  @override
  String get busquedaPista => 'Search students, courses, projects…';

  @override
  String get busquedaEscriba => 'Type to search';

  @override
  String get comunSinResultados => 'No results';

  @override
  String get cuentaMiCuenta => 'My account';

  @override
  String get cuentaMiPerfil => 'My profile';

  @override
  String get cuentaAcerca => 'About eduXaction';

  @override
  String get cuentaEliminar => 'Delete my account';

  @override
  String get notificacionesTitulo => 'Notifications';

  @override
  String get notificacionesVacio => 'No notifications';

  @override
  String get contactoEnviado => 'Message sent! We will be in touch soon.';

  @override
  String get contactoError =>
      'We could not send your message. Please try again in a moment.';

  @override
  String get contactoTitulo => 'Contact us';

  @override
  String get contactoTexto =>
      'Tell us who you are and what you would like to do with us.';

  @override
  String get comunNombre => 'Name';

  @override
  String get comunRequerido => 'Required';

  @override
  String get comunCorreoInvalido => 'Invalid email';

  @override
  String get contactoMensaje => 'Message';

  @override
  String get contactoMensajePista =>
      'How would you like to get involved? (student, mentor, company, donor...)';

  @override
  String get comunCancelar => 'Cancel';

  @override
  String get comunEnviando => 'Sending…';

  @override
  String get contactoEnviar => 'Send message';

  @override
  String get cuentaPrivacidadError =>
      'We could not open the privacy policy. Check your connection and try again.';

  @override
  String get cuentaEscribaContrasena => 'Enter your password to confirm.';

  @override
  String get cuentaSolicitudRecibida => 'Request received';

  @override
  String cuentaDesactivada(Object dias) {
    return 'Your account has been deactivated and you have been signed out on all your devices. Within $dias days at most we will delete your personal data.';
  }

  @override
  String get comunEntendido => 'Got it';

  @override
  String get cuentaEliminando => 'Deleting…';

  @override
  String get cuentaQuePasa =>
      'This is what happens if you delete your account:';

  @override
  String get cuentaPunto1 =>
      'It stops working immediately and you are signed out on all your devices.';

  @override
  String get cuentaPunto2 =>
      'Within 30 days at most we delete your personal data: name, email, phone, ID number, city, photo and profile.';

  @override
  String get cuentaPunto3 =>
      'What you posted in the forum and your submissions are kept under the name “Deleted account”, so your team\'s work is not erased.';

  @override
  String get cuentaPunto4 =>
      'If you have certificates, download them first: once your data is deleted they no longer show your name.';

  @override
  String get cuentaParaConfirmar => 'To confirm that it is you.';

  @override
  String cuentaAcercaTexto(Object pie) {
    return 'We develop leaders who transform communities 💛\n$pie';
  }

  @override
  String get cuentaNormas => 'Community guidelines';

  @override
  String get cuentaEscribanos => 'Write to us';

  @override
  String get cuentaLicencias => 'Software licenses';

  @override
  String cuentaDerechos(Object anio) {
    return '© $anio eduXaction Colombia — All rights reserved\nMade with 💛 in Bogotá';
  }

  @override
  String get portalMas => 'More';

  @override
  String get portalMasOpciones => 'More options';

  @override
  String etapaDeTotal(Object actual, Object total) {
    return 'Stage $actual of $total';
  }

  @override
  String get etapaFinal => 'Final stage';

  @override
  String etapaSigue(Object etapa) {
    return 'Next: $etapa';
  }

  @override
  String get universidadCargando => 'Loading universities…';

  @override
  String get universidadFueraCatalogo => '(university not in the catalog)';

  @override
  String get universidadOtra => 'Other (which one?)';

  @override
  String get universidadCual => 'Which institution?';

  @override
  String get universidadCualAyuda =>
      'The full official name. It stays on the list for future sign-ups.';

  @override
  String get mapaNoCarga => 'The map could not be loaded';

  @override
  String get mapaCifras =>
      'The figures and the list are still available on the right.';

  @override
  String get mapaEstudiantesPorCiudad => 'STUDENTS BY CITY';

  @override
  String perfilRol(Object rol) {
    return 'Role: $rol';
  }

  @override
  String perfilCorreo(Object correo) {
    return 'Email: $correo';
  }

  @override
  String perfilTelefono(Object telefono) {
    return 'Phone: $telefono';
  }

  @override
  String perfilUniversidad(Object universidad) {
    return 'University: $universidad';
  }

  @override
  String get universidadEtiqueta => 'University';

  @override
  String get universidadNinguna => 'No university';

  @override
  String get comunConfirmar => 'Confirm';

  @override
  String get comunNoSeDeshace => 'This action cannot be undone.';

  @override
  String comunEscribaParaConfirmar(Object palabra) {
    return 'Type $palabra to confirm';
  }

  @override
  String get comunEliminarDefinitivamente => 'Delete permanently';

  @override
  String get formularioDescartarTitulo => 'Discard changes';

  @override
  String get formularioDescartarTexto =>
      'What you wrote in this form has not been saved. Do you want to leave anyway?';

  @override
  String get escritorioTitulo => 'Better on a computer';

  @override
  String escritorioTexto(Object herramienta) {
    return 'On a phone, $herramienta is hard to use and it is easy to make mistakes: it has lists to reorder, tables and long forms. We recommend opening it at eduxaction.com on a computer.';
  }

  @override
  String get escritorioContinuar => 'Continue anyway';

  @override
  String get eventoSesionSincronica => 'Live session';

  @override
  String get eventoRutaImpacto => 'Impact Path event';

  @override
  String get calendarioMesAnterior => 'Previous month';

  @override
  String get calendarioMesSiguiente => 'Next month';

  @override
  String get calendarioAgregarEvento => 'Add event';

  @override
  String get calendarioSinEventosDia => 'There are no events on this day.';

  @override
  String get calendarioUnirse => 'Join the meeting';

  @override
  String get comunEditar => 'Edit';

  @override
  String get comunEliminar => 'Delete';

  @override
  String get calendarioEliminarEvento => 'Delete event';

  @override
  String calendarioEliminarConfirmar(Object titulo) {
    return 'Delete \"$titulo\"? This action cannot be undone.';
  }

  @override
  String get calendarioEditarEvento => 'Edit event';

  @override
  String get comunTitulo => 'Title';

  @override
  String get calendarioTipoEvento => 'Event type';

  @override
  String get calendarioSinCursosOL =>
      'You do not have any Open Learning courses of your own yet. Create one in \"My Courses\" before scheduling a session.';

  @override
  String get calendarioSinLaboratorios =>
      'You do not have any laboratories assigned yet, so there is no one to schedule a mentoring session with.';

  @override
  String get comunLaboratorio => 'Laboratory';

  @override
  String get calendarioEventoGlobal =>
      'Global event: all eduXaction students and alumni on the platform will see it, regardless of their laboratory.';

  @override
  String get calendarioLinkReunion => 'Meeting link';

  @override
  String get calendarioInvitados => 'Guests (optional)';

  @override
  String get calendarioInvitadosPista => 'E.g.: María Pérez (Bancolombia)';

  @override
  String get comunDescripcionOpcional => 'Description (optional)';

  @override
  String get calendarioRepetir => 'Repeat every 15 days';

  @override
  String get calendarioEventoActualizado => 'Event updated ✓';

  @override
  String get calendarioEventoAgregado => 'Event added ✓';

  @override
  String get comunGuardando => 'Saving…';

  @override
  String get comunGuardar => 'Save';

  @override
  String get archivoTipoNoPermitido =>
      'File type not allowed. PDF, images, Word documents and ZIP are accepted.';

  @override
  String archivoPesado(Object megas) {
    return 'The file is $megas MB and the maximum is 25 MB.';
  }

  @override
  String get archivoAdjuntar => 'Attach file';

  @override
  String get archivoArchivo => 'File';

  @override
  String get archivoPreparando => 'Preparing the upload…';

  @override
  String archivoSubiendo(Object porcentaje) {
    return 'Uploading… $porcentaje%';
  }

  @override
  String get comunQuitar => 'Remove';

  @override
  String get archivoNoAbre => 'The file could not be opened.';

  @override
  String get archivoNoVisible =>
      'This type of file cannot be viewed inside the page. Download it to open it.';

  @override
  String get comunDescargar => 'Download';

  @override
  String get archivoNoImagen => 'The image could not be displayed.';

  @override
  String get normas1Titulo => 'Respect above all';

  @override
  String get normas1Texto =>
      'Treat other people the way you want to be treated. Insults, mockery, harassment and threats are not allowed.';

  @override
  String get normas2Titulo => 'Zero discrimination';

  @override
  String get normas2Texto =>
      'Content that discriminates on the basis of origin, nationality, gender, sexual orientation, religion, disability or social status is not accepted.';

  @override
  String get normas3Titulo => 'Appropriate content';

  @override
  String get normas3Texto =>
      'Do not post sexual, violent or illegal content, or anything that puts another person at risk.';

  @override
  String get normas4Titulo => 'No advertising';

  @override
  String get normas4Texto =>
      'The forum is for learning and building projects: do not post sales, raffles, chain messages or advertising.';

  @override
  String get normas5Titulo => 'Take care of personal data';

  @override
  String get normas5Texto =>
      'Do not share your own personal data or anyone else\'s: phone numbers, addresses, documents or photos of other people.';

  @override
  String get normas6Titulo => 'Report what is not right';

  @override
  String get normas6Texto =>
      'If something breaks these guidelines, use “Report” in the ⋮ menu of the post. If someone makes you uncomfortable, you can block them and you will no longer see what they post.';

  @override
  String get normasConsecuencias =>
      'There is no tolerance for offensive content or abuse. The Enactus Colombia team reviews every report and may remove the content and suspend the account of anyone who breaks these guidelines.';

  @override
  String get normasAntesDePublicar =>
      'Before posting for the first time, read and accept the forum guidelines.';

  @override
  String get normasAcepto => 'I accept';

  @override
  String get visorAbriendo => 'Opening the document…';

  @override
  String get visorNoAbre =>
      'We could not open this document. Check your connection and try again.';

  @override
  String get visorAppSistema => 'This file opens with the system app.';

  @override
  String get visorNoCarga =>
      'The PDF viewer could not be loaded. Reload the page.';

  @override
  String get leccionTipoRecurso => 'Resource';

  @override
  String get leccionTipoEnlace => 'Link';

  @override
  String get leccionTipoQuiz => 'Quiz';

  @override
  String get leccionTipoActividad => 'Activity';

  @override
  String get leccionTipoEncuesta => 'Survey';

  @override
  String get visorDocumento => 'Document';

  @override
  String calendarioVeces(int cantidad) {
    String _temp0 = intl.Intl.pluralLogic(
      cantidad,
      locale: localeName,
      other: '$cantidad times',
      one: '1 time',
    );
    return '$_temp0';
  }

  @override
  String get glosarioOcultarTexto => 'Hide text and glossary';

  @override
  String get glosarioVerTexto => 'Show the lesson\'s text and glossary';

  @override
  String glosarioTextoDe(Object titulo) {
    return 'Text and glossary of “$titulo”';
  }

  @override
  String get glosarioDeLeccion => 'Glossary for this lesson';

  @override
  String get glosarioLeccionVacio => 'This lesson has no glossary terms.';

  @override
  String get glosarioDelModulo => 'Module glossary';

  @override
  String glosarioPorRepasar(Object cantidad) {
    return '$cantidad to review';
  }

  @override
  String get glosarioTarjetas => 'Cards';

  @override
  String get glosarioModoRepaso => 'Review mode';

  @override
  String get glosarioBuscar => 'Search the glossary';

  @override
  String get glosarioBorrarBusqueda => 'Clear the search';

  @override
  String glosarioNingunoCoincide(Object busqueda) {
    return 'No term matches “$busqueda”.';
  }

  @override
  String get glosarioNingunoMarcado => 'You have no terms marked for review.';

  @override
  String get glosarioNingunoLetra => 'No term starts with that letter.';

  @override
  String get glosarioQuitarFiltros => 'Clear the filters';

  @override
  String get glosarioTodas => 'All';

  @override
  String get glosarioTodasLasLetras => 'All letters';

  @override
  String get glosarioAyudaTarjetas =>
      'Tap a card to flip it. Review progress is saved in each student\'s account.';

  @override
  String glosarioAyudaRepaso(Object sabe, Object total, Object repasar) {
    return 'Tap a card to see the definition and mark whether you already know it. Known: $sabe of $total · To review: $repasar';
  }

  @override
  String glosarioYaLoSabeDe(Object sabe, Object total) {
    return 'Known: $sabe of $total';
  }

  @override
  String get glosarioSoloRepasar => 'Only the ones to review';

  @override
  String get glosarioRelacionados => 'Related';

  @override
  String glosarioIrA(Object palabra) {
    return 'Go to “$palabra”';
  }

  @override
  String get glosarioEjemplo => 'Example';

  @override
  String glosarioImagenDe(Object palabra) {
    return 'Image of “$palabra”';
  }

  @override
  String get glosarioYaLoSabe => 'Known';

  @override
  String get glosarioPorRepasarEstado => 'To review';

  @override
  String glosarioDefinicionDe(Object palabra, Object definicion) {
    return 'Definition of “$palabra”: $definicion';
  }

  @override
  String glosarioToqueParaVer(Object palabra) {
    return '“$palabra”. Tap to see the definition.';
  }

  @override
  String get glosarioYaLoSe => 'I know it';

  @override
  String get glosarioRepasar => 'Review';

  @override
  String get glosarioToqueDefinicion => 'Tap to see the definition';

  @override
  String videoCargandoTitulo(Object titulo) {
    return 'Loading the video “$titulo”';
  }

  @override
  String videoReproducirTitulo(Object titulo) {
    return 'Play the video “$titulo”';
  }

  @override
  String videoSeguirViendo(Object titulo, Object tiempo) {
    return 'Continue watching “$titulo” from $tiempo';
  }

  @override
  String get videoCargando => 'Loading the video…';

  @override
  String videoSeguirDesde(Object tiempo) {
    return 'Continue from $tiempo';
  }

  @override
  String get videoNoDisponibleEntorno =>
      'Playback is not available in this environment';

  @override
  String get videoYaNoDisponible => 'This video is no longer available';

  @override
  String get videoAviseCreador => 'Let the person who built the course know.';

  @override
  String get videoNoCarga => 'The video could not be loaded';

  @override
  String get videoPuedeSerConexion =>
      'It may be the connection. Please try again in a moment.';

  @override
  String get videoPausar => 'Pause the video';

  @override
  String get videoReproducir => 'Play the video';

  @override
  String get videoCargandoCorto => 'Loading the video';

  @override
  String get videoPosicion => 'Video position';

  @override
  String videoTiempoDe(Object actual, Object total) {
    return '$actual of $total';
  }

  @override
  String get videoPausarK => 'Pause (K)';

  @override
  String get videoReproducirK => 'Play (K)';

  @override
  String get videoActivarSonido => 'Unmute (M)';

  @override
  String get videoSilenciar => 'Mute (M)';

  @override
  String get videoVolumen => 'Volume';

  @override
  String videoMinutoDe(Object actual, Object total) {
    return 'Minute $actual of $total';
  }

  @override
  String get videoVelocidad => 'Playback speed';

  @override
  String get videoVelocidadNormal => 'Normal (1×)';

  @override
  String videoVelocidadActual(Object velocidad) {
    return 'Playback speed: $velocidad';
  }

  @override
  String get videoSalirPantallaCompleta => 'Exit full screen (F)';

  @override
  String get videoPantallaCompleta => 'Full screen (F)';

  @override
  String get videoVer => 'Watch the video';

  @override
  String get videoPestanaNueva => 'It opens in a new tab.';

  @override
  String get videoAbrir => 'Open video';

  @override
  String get videoLeccionSinVideo => 'This lesson does not have a video yet';

  @override
  String get videoCreadorNoCargo => 'Its creator has not uploaded one yet.';

  @override
  String get videoEnlaceNoAbre => 'The video link could not be opened.';

  @override
  String get videoAvanceSeGuarda =>
      'Your progress is saved automatically: if you close it, you will pick up where you left off.';

  @override
  String get videoLeccionCompletada => 'Lesson completed';

  @override
  String videoVisto(Object porcentaje) {
    return 'Watched $porcentaje%';
  }

  @override
  String subidaSinTerminar(Object archivo, Object tamano) {
    return 'The upload of “$archivo” ($tamano) was not finished. Choose the same file and, when you save, it will continue where it left off.';
  }

  @override
  String get subidaZonaSoltar => 'Drop zone for the video';

  @override
  String get subidaSuelte => 'Drop the video to choose it';

  @override
  String get subidaReemplazar => 'To replace it, drag another video here';

  @override
  String get subidaArrastre => 'Drag the video here';

  @override
  String get subidaElegirVideo => 'Choose video';

  @override
  String get subidaFormato => 'MP4 (H.264 with AAC audio) · up to 500 MB';

  @override
  String get subidaRevisando => 'Checking the video…';

  @override
  String get subidaElegirOtro => 'Choose another video';

  @override
  String get subidaVistaPreviaAsi =>
      'Preview — this is how students will see it:';

  @override
  String get subidaVistaPrevia => 'Preview';

  @override
  String get subidaVistaPreviaNavegador =>
      'The preview is shown in the browser';

  @override
  String get subidaVistaPreviaDetalle =>
      'The video is uploaded anyway; to watch it before saving, open the editor from the website.';

  @override
  String get subidaPortadaPropia => 'Custom cover';

  @override
  String get subidaPortadaDelVideo => 'Cover taken from the video';

  @override
  String get subidaSinPortada => 'No cover: a generic background will be shown';

  @override
  String get subidaUsarOtraImagen => 'Use another image';

  @override
  String get subidaVolverPortadaVideo => 'Go back to the video\'s cover';

  @override
  String get subidaQuitarPortada => 'Remove the cover';

  @override
  String get subidaCambiarPortada => 'Change the cover';

  @override
  String get subidaPonerPortada => 'Add a cover';

  @override
  String get subidaNuevaPortada => 'New cover: it is saved when you save';

  @override
  String subidaNoTermino(Object mensaje) {
    return 'The upload could not be finished: $mensaje The parts that already arrived are not lost: save again and it will continue where it left off.';
  }

  @override
  String subidaDe(Object enviado, Object total) {
    return '$enviado of $total';
  }

  @override
  String subidaQuedan(Object tiempo) {
    return '$tiempo left';
  }

  @override
  String subidaSiguiendo(Object pct) {
    return 'Resuming the upload… $pct %';
  }

  @override
  String subidaSubiendo(Object pct) {
    return 'Uploading the video… $pct %';
  }

  @override
  String get subidaCancelar => 'Cancel upload';

  @override
  String get subidaAvance => 'Upload progress';

  @override
  String get subidaNoCierre => 'Do not close this window until it finishes.';

  @override
  String get youtubeNoAbre => 'YouTube could not be opened.';

  @override
  String get youtubeNoCarga => 'The player could not be loaded';

  @override
  String get youtubeNoCargaDetalle =>
      'It may be the connection, or the browser may be blocking YouTube. You can try again or watch it directly there.';

  @override
  String get youtubeSoloYoutube => 'This video can only be watched on YouTube';

  @override
  String get youtubeSoloYoutubeDetalle =>
      'The person who uploaded it does not allow it to be played outside YouTube.';

  @override
  String get youtubeBorrado =>
      'It was deleted from YouTube or made private. Let the person who built the course know.';

  @override
  String get youtubeNoValido => 'The saved video is not valid';

  @override
  String get youtubeNoValidoDetalle =>
      'Let the person who built the course know so they can check the link.';

  @override
  String get youtubeNoReproduce => 'YouTube could not play the video';

  @override
  String get youtubeNoReproduceDetalle =>
      'Try again, or watch it directly on YouTube.';

  @override
  String get youtubeVerEn => 'Watch on YouTube';

  @override
  String glosarioTerminos(int cantidad) {
    String _temp0 = intl.Intl.pluralLogic(
      cantidad,
      locale: localeName,
      other: '$cantidad terms',
      one: '1 term',
    );
    return '$_temp0';
  }

  @override
  String glosarioLetraTerminos(Object letra, int cantidad) {
    String _temp0 = intl.Intl.pluralLogic(
      cantidad,
      locale: localeName,
      other: '$cantidad terms',
      one: '1 term',
    );
    return 'Letter $letra, $_temp0';
  }

  @override
  String subidaSubidoEl(Object fecha) {
    return 'uploaded on $fecha';
  }

  @override
  String subidaVideoActual(Object nombre) {
    return 'Current video: $nombre';
  }

  @override
  String get subidaArchivoSubido => 'uploaded file';

  @override
  String get portadaIniciarSesion => 'Sign in';

  @override
  String get portadaEstudiantesActivos => 'Active students';

  @override
  String get portadaProyectosImpacto => 'Impact projects';

  @override
  String get portadaLaboratorios => 'Laboratories';

  @override
  String get portadaUniversidadesAliadas => 'Partner universities';

  @override
  String get portadaAreasConocimiento => 'Fields of knowledge';

  @override
  String get portadaNuestrosLaboratorios => 'Our Laboratories';

  @override
  String get portadaAreasTexto =>
      'Fields of knowledge in which we train our teams';

  @override
  String get portadaGaleria => 'Gallery';

  @override
  String get portadaNuestroTrabajo => 'Our work in pictures';

  @override
  String get portadaMomentos =>
      'Moments from the eduXaction Colombia community';

  @override
  String get portadaListo => 'Ready to get involved? 💛';

  @override
  String get portadaListoTexto =>
      'Whether you are a student, mentor, company or donor: there is a place for you at eduXaction Colombia.';

  @override
  String get portadaQuieroUnirme => 'I want to join';

  @override
  String get portadaExpoLugar => 'Santa Marta · July 2026';

  @override
  String get portadaExpoTitulo => 'National Expo 2026 Champions';

  @override
  String get portadaExpoTexto =>
      'Santa Marta, July 2026 — our teams on their way to the eduXaction World Cup in São Paulo';

  @override
  String get portadaExpoPie =>
      'eduXaction Colombia delegation · National Expo 2026';

  @override
  String get portadaEntrar => 'Enter the platform';

  @override
  String get tabDashboard => 'Dashboard';

  @override
  String get tabInicioCorto => 'Home';

  @override
  String get tabCalendario => 'Calendar';

  @override
  String get tabMisCursos => 'My Courses';

  @override
  String get tabCursosCorto => 'Courses';

  @override
  String get tabLaboratorios => 'Laboratories';

  @override
  String get tabRutaCorto => 'Path';

  @override
  String get tabDirectorioProyectos => 'Project Directory';

  @override
  String get tabProyectosCorto => 'Projects';

  @override
  String get tabForo => 'Forum';

  @override
  String get tabCertificados => 'Certificates';

  @override
  String get tabMiPerfil => 'My Profile';

  @override
  String get tabPerfilCorto => 'Profile';

  @override
  String portalDe(Object rol) {
    return '$rol Portal';
  }

  @override
  String get certificadosMisTitulo => 'My Certificates';

  @override
  String get certificadosMisSubtitulo =>
      'Certificates issued by your LXDs when you complete an Impact Path';

  @override
  String get certificadosVacio =>
      'You do not have any certificates yet.\nComplete your courses to earn them.';

  @override
  String certificadoRutaDe(Object laboratorio) {
    return 'Impact Path · $laboratorio';
  }

  @override
  String get certificadoVerPdf => 'View PDF';

  @override
  String get comunCompartir => 'Share';

  @override
  String perfilMiembroDesde(Object anio) {
    return 'Active member since $anio';
  }

  @override
  String get perfilMiembroComunidad => 'Community member';

  @override
  String get perfilBuscarPortal => 'Search the portal';

  @override
  String get perfilDatosPersonales => 'Personal information';

  @override
  String get perfilCedula => 'ID number';

  @override
  String get perfilTelefonoEtiqueta => 'Phone';

  @override
  String get perfilCorreoEtiqueta => 'Email';

  @override
  String get perfilCiudad => 'City';

  @override
  String get perfilCarrera => 'Degree program';

  @override
  String get perfilVidaEduxaction => 'eduXaction life';

  @override
  String get perfilEquipo => 'Team';

  @override
  String get perfilEmpresaPatrocinadora => 'Sponsoring company';

  @override
  String get perfilCursosActivos => 'Active courses';

  @override
  String get perfilLeccionesCompletadas => 'Lessons completed';

  @override
  String get perfilEditar => 'Edit profile';

  @override
  String get perfilSinProyecto => 'You do not have a project assigned yet.';

  @override
  String get perfilMiProyecto => 'MY PROJECT';

  @override
  String get certificadosVacioRuta =>
      'You do not have any certificates yet. Complete an Impact Path to earn your first one.';

  @override
  String certificadosFaltaPoco(Object nombre) {
    return 'You are close to your first certificate: \"$nombre\".';
  }

  @override
  String leccionesDeTotal(Object completadas, Object total) {
    return '$completadas of $total lessons';
  }

  @override
  String get certificadoDescargar => 'Download certificate';

  @override
  String get perfilSeleccioneFoto => 'Select a photo';

  @override
  String get perfilFotoFormato => 'Use a JPG or PNG photo.';

  @override
  String get perfilFotoPesada =>
      'The photo is larger than 25 MB. Choose a lighter one.';

  @override
  String get perfilTelefonoInvalido =>
      'Enter a valid phone number (at least 7 digits).';

  @override
  String get perfilActualizado => 'Profile updated ✓';

  @override
  String get perfilSubiendoFoto => 'Uploading photo…';

  @override
  String get perfilCambiarFoto => 'Change profile photo';

  @override
  String get perfilAsignaAdmin =>
      'ID number, university, team, project and sponsoring company are assigned by your administrator.';

  @override
  String certificadoEmitidoDetalle(Object fecha, Object emisor, Object codigo) {
    return 'Issued on $fecha · By: $emisor · Code: $codigo';
  }

  @override
  String certificadoEmitidoEl(Object fecha) {
    return 'Issued on $fecha';
  }

  @override
  String get dashboardSinProyecto => 'You do not have a project assigned yet';

  @override
  String get dashboardTodoPorEmpezar => 'Everything is ready to start';

  @override
  String get dashboardSinCursos =>
      'You do not have any courses assigned yet. When your administrator assigns you one, your progress will appear here.';

  @override
  String get comunActualizar => 'Refresh';

  @override
  String get dashboardProgresoGeneral => 'Overall progress';

  @override
  String get dashboardTodoCompletado =>
      'You have completed all your assigned courses.';

  @override
  String get dashboardContinueDonde => 'PICK UP WHERE YOU LEFT OFF';

  @override
  String get comunContinuar => 'Continue';

  @override
  String get dashboardProgresoPorCurso => 'Progress by course';

  @override
  String dashboardContinuarCurso(Object nombre) {
    return 'Continue \"$nombre\"';
  }

  @override
  String get cursoRutaNationalExpo => 'National Expo Path';

  @override
  String get dashboardChecklistExpo => 'National Expo checklist';

  @override
  String get dashboardPendientes => 'To-dos';

  @override
  String get dashboardAlDia => 'You are all caught up! You have no to-dos.';

  @override
  String get dashboardChecklistTitulo => 'NATIONAL EXPO PATH checklist';

  @override
  String get dashboardActividadReciente => 'Recent activity';

  @override
  String get dashboardSinCalificadas =>
      'You do not have any graded submissions yet.';

  @override
  String get dashboardSuProyecto => 'Your project';

  @override
  String get calendarioNoTrajo => 'We could not load your events.';

  @override
  String get calendarioCargando => 'Loading your events…';

  @override
  String get calendarioSubtitulo =>
      'Live sessions from your courses and events from your Impact Path.';

  @override
  String get calendarioProximos => 'Upcoming events';

  @override
  String get calendarioSinProximos => 'You have no upcoming events.';

  @override
  String get calendarioAgendaDespejada => 'Clear schedule';

  @override
  String get calendarioAgendaDespejadaTexto =>
      'You have no sessions or deadlines scheduled this month.';

  @override
  String get comunActualizado => 'Refreshed';

  @override
  String cursoHorasEstimadas(Object horas) {
    return '$horas h estimated';
  }

  @override
  String cursoMinutosEstimados(Object minutos) {
    return '$minutos min estimated';
  }

  @override
  String get cursosAsignados => 'Assigned courses';

  @override
  String get cursosCargando => 'Loading your courses…';

  @override
  String get cursosNoTrajo => 'We could not load your courses.';

  @override
  String get cursosSubtitulo =>
      'Laboratory courses assigned by your administrator, plus your team\'s preparation path for National Expo.';

  @override
  String get cursosBuscar => 'Search for a course or laboratory';

  @override
  String get cursosSinAsignados => 'No assigned courses';

  @override
  String get cursosSinAsignadosTexto =>
      'You do not have any courses assigned by your administrator yet.';

  @override
  String get cursosNingunoCoincide =>
      'No course matches your search. Try another term.';

  @override
  String get comunLimpiarBusqueda => 'Clear search';

  @override
  String cursoModulos(int cantidad) {
    String _temp0 = intl.Intl.pluralLogic(
      cantidad,
      locale: localeName,
      other: '$cantidad modules',
      one: '1 module',
    );
    return '$_temp0';
  }

  @override
  String cursoLecciones(int cantidad) {
    String _temp0 = intl.Intl.pluralLogic(
      cantidad,
      locale: localeName,
      other: '$cantidad lessons',
      one: '1 lesson',
    );
    return '$_temp0';
  }

  @override
  String get cursoCertificado => 'Certificate';

  @override
  String cursoProgresoDetalle(Object hechas, Object total, Object porcentaje) {
    return '$hechas of $total lessons · $porcentaje%';
  }

  @override
  String get cursoTrabajoEquipo => 'Teamwork';

  @override
  String get comunComenzar => 'Start';

  @override
  String dashboardSemanaDel(Object desde, Object hasta) {
    return 'Week of $desde to $hasta';
  }

  @override
  String dashboardHola(Object nombre) {
    return 'Hello, $nombre';
  }

  @override
  String dashboardProyecto(Object proyecto) {
    return 'Project $proyecto';
  }

  @override
  String dashboardCursosActivos(int cantidad) {
    String _temp0 = intl.Intl.pluralLogic(
      cantidad,
      locale: localeName,
      other: '$cantidad active courses',
      one: '1 active course',
    );
    return '$_temp0';
  }

  @override
  String dashboardLaboratorios(int cantidad) {
    String _temp0 = intl.Intl.pluralLogic(
      cantidad,
      locale: localeName,
      other: '$cantidad laboratories',
      one: '1 laboratory',
    );
    return '$_temp0';
  }

  @override
  String dashboardFaseVencida(Object fase) {
    return 'Overdue phase: $fase';
  }

  @override
  String dashboardConfirmarMentoria(Object fase) {
    return 'Confirm mentoring: $fase';
  }

  @override
  String get comunFase => 'Phase';

  @override
  String dashboardCalificadoEl(Object fecha) {
    return 'Graded on $fecha';
  }

  @override
  String cursoDocente(Object docente) {
    return 'Instructor: $docente';
  }

  @override
  String get cursoGeneraCertificado => 'Awards a certificate';

  @override
  String get cursoObjetivos => 'Objectives';

  @override
  String get cursoSoloLectura =>
      'You are viewing another student\'s progress — read-only mode.';

  @override
  String get cursoSinContenido =>
      'This course does not have any published content yet.';

  @override
  String get cursoMisEntregas => 'My submissions';

  @override
  String get leccionVideoYoutube => 'YouTube video';

  @override
  String get leccionCompletada => 'Completed';

  @override
  String get leccionMarcarPendiente => 'Mark as pending';

  @override
  String get leccionMarcarCompletada => 'Mark as completed';

  @override
  String get rutaCompletada => 'You completed the Impact Path! 🎉';

  @override
  String get leccionCompletadaExclama => 'Lesson completed!';

  @override
  String get cursoNoPuedeResponder =>
      'You are viewing another student\'s progress — you cannot answer on their behalf.';

  @override
  String get leccionSinMaterial =>
      'This lesson does not have any material uploaded yet.';

  @override
  String get leccionSinEnlace => 'This lesson does not have a valid link.';

  @override
  String get leccionEnlaceNoAbre => 'The link could not be opened.';

  @override
  String get quizCalificar => 'Grade';

  @override
  String get quizCalificando => 'Grading…';

  @override
  String get quizSinPreguntas => 'This quiz does not have any questions yet.';

  @override
  String quizAprobado(Object puntaje) {
    return 'Passed! $puntaje%';
  }

  @override
  String quizPuntaje(Object puntaje) {
    return 'Score: $puntaje% (minimum 60%)';
  }

  @override
  String get quizVerdadero => 'True';

  @override
  String get quizFalso => 'False';

  @override
  String get quizCompleteFrase => 'Complete the sentence…';

  @override
  String get quizSuRespuesta => 'Your answer…';

  @override
  String get quizUseFlechas => 'Use the arrows to reorder:';

  @override
  String encuestaNombreTarea(Object leccion) {
    return 'Survey: $leccion';
  }

  @override
  String get encuestaGracias => 'Thank you for answering!';

  @override
  String get comunEnviar => 'Send';

  @override
  String get encuestaOpinion => 'Your opinion helps us improve 💛';

  @override
  String get actividadArchivoObligatorio => 'File required';

  @override
  String get actividadTextoObligatorio => 'Text required';

  @override
  String get actividadRubrica => 'Grading rubric';

  @override
  String get actividadSuEntrega => 'Your submission';

  @override
  String actividadRetroalimentacion(Object retro) {
    return 'Feedback: $retro';
  }

  @override
  String get actividadEntregar => 'Submit activity';

  @override
  String get actividadNuevaEntrega => 'New submission';

  @override
  String get actividadRequiereTexto =>
      'This activity requires a written answer.';

  @override
  String get actividadRequiereArchivo =>
      'This activity requires an attached file.';

  @override
  String get actividadEntregada => 'Activity submitted ✓';

  @override
  String actividadEntregarTitulo(Object leccion) {
    return 'Submit: $leccion';
  }

  @override
  String get actividadRespuestaObligatoria => 'Your answer (required)';

  @override
  String get actividadComentarioOpcional => 'Comment (optional)';

  @override
  String get actividadSinEntregas =>
      'You have not made any submissions in this course yet.';

  @override
  String get actividadEntregaLibre => 'New open submission';

  @override
  String get actividadPongaNombre => 'Give the submission a name.';

  @override
  String get actividadEntregaEnviada => 'Submission sent ✓';

  @override
  String get actividadNombreTarea => 'Task name';

  @override
  String get comunComentario => 'Comment';

  @override
  String actividadLimite(Object fecha) {
    return 'Due: $fecha';
  }

  @override
  String labsEnLaRed(Object cantidad) {
    return '$cantidad in the network';
  }

  @override
  String get labsQueEs =>
      'A laboratory is a work area of eduXaction Colombia: it brings together a phased Impact Path, courses and an LXD who guides it. Open yours to see what comes next.';

  @override
  String get labsSinAsignados => 'No laboratories assigned';

  @override
  String get labsSinAsignadosTexto =>
      'Your administrator has not assigned you a laboratory yet. Without one you do not have an Impact Path or field courses.';

  @override
  String get labsOtros => 'OTHER LABORATORIES IN THE NETWORK';

  @override
  String get labsSolicite =>
      'Ask your administrator to assign you one if your project needs it.';

  @override
  String get rutaEntregaVencida => 'OVERDUE';

  @override
  String get rutaEnCurso => 'IN PROGRESS';

  @override
  String rutaFaseCompletaDe(Object total) {
    return 'Phase $total of $total complete';
  }

  @override
  String rutaFaseEnCursoDe(Object fase, Object total) {
    return 'Phase $fase of $total in progress';
  }

  @override
  String get rutaSinModulos => 'No modules yet';

  @override
  String rutaModulosFraccion(Object hechos, Object total) {
    return '$hechos/$total modules';
  }

  @override
  String rutaFases(int cantidad) {
    String _temp0 = intl.Intl.pluralLogic(
      cantidad,
      locale: localeName,
      other: '$cantidad phases',
      one: '1 phase',
    );
    return '$_temp0';
  }

  @override
  String rutaCursos(int cantidad) {
    String _temp0 = intl.Intl.pluralLogic(
      cantidad,
      locale: localeName,
      other: '$cantidad courses',
      one: '1 course',
    );
    return '$_temp0';
  }

  @override
  String get rutaSinLxd => 'No LXD assigned';

  @override
  String rutaLxd(Object nombre) {
    return 'LXD: $nombre';
  }

  @override
  String get comunEntrar => 'Enter';

  @override
  String get rutaUnEquipo => '1 team in the network';

  @override
  String rutaEquipos(Object cantidad) {
    return '$cantidad teams in the network';
  }

  @override
  String get labNoEncontrado => 'Laboratory not found';

  @override
  String get labNoEncontradoTexto =>
      'It may no longer exist or the link may be mistyped.';

  @override
  String get labsTodos => 'All laboratories';

  @override
  String get rutaMayus => 'IMPACT PATH';

  @override
  String get rutaFasesEnOrden =>
      'Phases open in order. Your LXD publishes the content of each one.';

  @override
  String get rutaSuAvance => 'Your progress';

  @override
  String rutaFaseDe(Object fase, Object total) {
    return 'Phase $fase of $total';
  }

  @override
  String rutaModulosDeTotal(Object hechos, Object total) {
    return '$hechos of $total modules';
  }

  @override
  String get rutaFasesEnRuta => 'Phases in the path';

  @override
  String get rutaModulosPublicados => 'Published modules';

  @override
  String get rutaCursosLab => 'Laboratory courses';

  @override
  String get rutaHorasEstimadas => 'Estimated hours';

  @override
  String get rutaSinFases =>
      'This laboratory does not have any published phases yet.';

  @override
  String rutaFaseNumero(Object numero) {
    return 'Phase $numero';
  }

  @override
  String get rutaEstadoCompleta => 'Complete';

  @override
  String get rutaEstadoVencida => 'Overdue';

  @override
  String get rutaEstadoDisponible => 'Available';

  @override
  String get rutaEstadoBloqueada => 'Locked';

  @override
  String rutaSeAbreCuando(Object fase) {
    return 'Opens when you complete Phase $fase';
  }

  @override
  String get rutaLxdPublicara =>
      'Your LXD will publish the content of this phase.';

  @override
  String get rutaLxdNoPublico =>
      'Your LXD has not published the content of this phase yet.';

  @override
  String get rutaSinModulosPublicados => 'No published modules';

  @override
  String get rutaEmpezarFase => 'Start the phase';

  @override
  String get rutaContinuarFase => 'Continue the phase';

  @override
  String get rutaSinCursos =>
      'This laboratory does not have any published courses yet. Your LXD will open them along with Phase 1.';

  @override
  String get rutaSuLxd => 'Your LXD';

  @override
  String get rutaLabSinLxd =>
      'This laboratory does not have an LXD assigned yet.';

  @override
  String get rutaLxdNombreLargo => 'Learning Experience Designer';

  @override
  String get rutaSinHorario => 'No schedule published';

  @override
  String get rutaAgendarMentoria => 'Schedule mentoring';

  @override
  String get rutaLxdSinDisponibilidad =>
      'Your LXD has not published their availability yet.';

  @override
  String rutaDisponibilidadDe(Object nombre) {
    return '$nombre\'s availability';
  }

  @override
  String rutaEscribale(Object nombre) {
    return 'Write to them to arrange the exact time with $nombre.';
  }

  @override
  String get rutaEscribirCorreo => 'Write an email';

  @override
  String get rutaSubtitulo =>
      'Your laboratory\'s phases, their objectives and what remains to reach National Expo.';

  @override
  String get rutaSinLab => 'No laboratory assigned';

  @override
  String get rutaSinLabTexto =>
      'Your administrator has not assigned you any laboratory yet.';

  @override
  String get rutaLabSinFases => 'Laboratory without phases';

  @override
  String rutaLabSinFasesTexto(Object laboratorio) {
    return 'The $laboratorio has not published its phases yet. Your LXD will open them when the content is ready.';
  }

  @override
  String get rutaVerOtroLab => 'View another laboratory';

  @override
  String get rutaEstadoSinAbrir => 'Not open yet';

  @override
  String get rutaEstadoEnCurso => 'In progress';

  @override
  String rutaModuloNumero(Object numero) {
    return 'Module $numero';
  }

  @override
  String rutaCompleteAnterior(Object modulo) {
    return 'Complete the previous module to unlock \"$modulo\".';
  }

  @override
  String get rutaBloqueado => 'Locked';

  @override
  String get rutaModuloMentoria => 'Mentoring module';

  @override
  String get rutaSinContenido => 'No content yet';

  @override
  String rutaElementos(int cantidad) {
    String _temp0 = intl.Intl.pluralLogic(
      cantidad,
      locale: localeName,
      other: '$cantidad items',
      one: '1 item',
    );
    return '$_temp0';
  }

  @override
  String get rutaCompleto => 'Complete';

  @override
  String get rutaMetaAnio => 'GOAL FOR THE YEAR';

  @override
  String get rutaSinEquipo => 'You do not belong to a team yet.';

  @override
  String get rutaChecklistEquipo => 'Team checklist';

  @override
  String get rutaModulo => 'Module';

  @override
  String get rutaModuloNoExiste =>
      'This module no longer exists or the link is mistyped.';

  @override
  String get rutaEntregasLecturas => 'Submissions and readings';

  @override
  String get rutaModuloSinContenido =>
      'Your administrator has not added content to this module yet.';

  @override
  String get rutaEstaFase => 'this phase';

  @override
  String rutaReunase(Object fase) {
    return 'Meet with your mentor to close $fase.';
  }

  @override
  String get rutaSinEnlaceReunion =>
      'Your administrator has not set up the meeting link yet.';

  @override
  String get rutaEntrega => 'Submission';

  @override
  String get rutaLecturaSinMaterial =>
      'This reading does not have any material yet.';

  @override
  String labsAsignadosEnRed(int asignados, Object total) {
    String _temp0 = intl.Intl.pluralLogic(
      asignados,
      locale: localeName,
      other: '$asignados laboratories assigned',
      one: '1 laboratory assigned',
    );
    return '$_temp0 · $total in the network';
  }

  @override
  String rutaFechaPrevista(Object fecha) {
    return 'Date set by the laboratory: $fecha';
  }

  @override
  String rutaEntregaVencidaEl(Object fecha) {
    return 'Overdue: $fecha';
  }

  @override
  String rutaEntregaEl(Object fecha) {
    return 'Due: $fecha';
  }

  @override
  String rutaAsuntoMentoria(Object laboratorio) {
    return 'Mentoring - $laboratorio';
  }

  @override
  String foroHaceMin(Object minutos) {
    return '$minutos min ago';
  }

  @override
  String foroHaceHoras(Object horas) {
    return '$horas h ago';
  }

  @override
  String foroHaceDias(Object dias) {
    return '$dias days ago';
  }

  @override
  String get foroComunidad => 'Community';

  @override
  String get foroTitulo => 'Community Forum';

  @override
  String get foroNoAbre => 'We could not open the forum.';

  @override
  String get foroCargando => 'Loading posts…';

  @override
  String get foroSubtitulo =>
      'Ask questions, share progress and find someone who already solved what you are working on. Students, mentors and LXDs from the whole network post here.';

  @override
  String get foroBuscar => 'Search by author, organization or content';

  @override
  String get foroNadie => 'Nobody has posted yet';

  @override
  String get foroVacio =>
      'The forum is empty. You can be the first person to start the community conversation.';

  @override
  String get foroSinCoincidencias =>
      'No post matches this filter. Try another category or clear the search.';

  @override
  String get foroVerTodo => 'View the whole forum';

  @override
  String get foroTodo => 'All';

  @override
  String get foroQueCompartir =>
      'What would you like to share with the community?';

  @override
  String get foroPublicando => 'Posting…';

  @override
  String get foroPublicar => 'Post';

  @override
  String get foroUsuarioEliminado => 'Deleted user';

  @override
  String get foroMasAcciones => 'More actions';

  @override
  String get foroEliminarPublicacion => 'Delete post';

  @override
  String get foroEliminarPublicacionTexto =>
      'Delete this post from the forum? This action cannot be undone.';

  @override
  String get foroDesfijar => 'Unpin';

  @override
  String get foroFijar => 'Pin announcement';

  @override
  String get foroReportar => 'Report';

  @override
  String foroBloquearA(Object nombre) {
    return 'Block $nombre';
  }

  @override
  String get foroResponder => 'Reply…';

  @override
  String foroVerRespuestas(Object total) {
    return 'View all $total replies';
  }

  @override
  String get foroEliminarRespuesta => 'Delete reply';

  @override
  String get foroEliminarRespuestaTexto =>
      'Delete this reply from the forum? This action cannot be undone.';

  @override
  String get foroRegla1 =>
      'Respect the other teams and share with the same openness with which you would like to receive help.';

  @override
  String get foroRegla2 =>
      'Post real content from your project: evidence and specific questions help more than generic messages.';

  @override
  String get foroRegla3 =>
      'It is a space for the whole network: questions from any laboratory or university are welcome.';

  @override
  String get foroNormas => 'Forum guidelines';

  @override
  String get foroNormasCompletas => 'Full guidelines';

  @override
  String get foroPersonasBloqueadas => 'Blocked people';

  @override
  String get foroReportes => 'Forum reports';

  @override
  String get foroRevisar => 'Review';

  @override
  String get foroEquiposActivos => 'Most active teams';

  @override
  String get reporteMotivoOfensivo => 'It is offensive or disrespectful';

  @override
  String get reporteMotivoAcoso => 'It is harassment or bullying';

  @override
  String get reporteMotivoDiscrimina => 'It discriminates against someone';

  @override
  String get reporteMotivoSpam => 'It is spam or advertising';

  @override
  String get reporteMotivoDatos => 'It shares personal data';

  @override
  String get reporteMotivoOtro => 'Other reason';

  @override
  String get reporteGracias =>
      'Thank you. The Enactus team will review this content.';

  @override
  String get reporteYaReportado =>
      'You had already reported it; the team has it on their list.';

  @override
  String get reporteRespuesta => 'Report reply';

  @override
  String get reportePublicacion => 'Report post';

  @override
  String get reportePorQue =>
      'Why are you reporting it? Only the Enactus team will see who reported it.';

  @override
  String reporteBloquearTambien(Object nombre) {
    return 'Also block $nombre';
  }

  @override
  String get reporteDejaraDeVer => 'You will no longer see what they post.';

  @override
  String bloqueoTexto(Object nombre) {
    return 'You will no longer see what $nombre posts and replies in the forum. They will not be notified. You can unblock them whenever you want from “Blocked people”, in the forum guidelines.';
  }

  @override
  String bloqueoHecho(Object nombre) {
    return 'You blocked $nombre.';
  }

  @override
  String get bloqueoNadie => 'You have not blocked anyone.';

  @override
  String get bloqueoDesbloquear => 'Unblock';

  @override
  String get reportesNinguno => 'There are no pending reports.';

  @override
  String get reporteQuitarRespuesta => 'Remove reply';

  @override
  String get reporteQuitarPublicacion => 'Remove post';

  @override
  String get reporteQuitarTexto =>
      'It will be removed from the forum for everyone. This cannot be undone.';

  @override
  String get reporteTipoPublicacion => 'POST';

  @override
  String get reporteYaNoSeVe => '· no longer visible in the forum';

  @override
  String get reporteSinMotivo => 'No reason given';

  @override
  String reporteReporto(Object nombre, Object fecha) {
    return 'Reported by $nombre · $fecha';
  }

  @override
  String get reporteCerrar => 'Close report';

  @override
  String get reporteDejarlo => 'Leave it';

  @override
  String get reporteQuitarDelForo => 'Remove from the forum';

  @override
  String get foroAhora => 'just now';

  @override
  String get foroAyer => 'yesterday';

  @override
  String foroPersonasActivas(int cantidad) {
    String _temp0 = intl.Intl.pluralLogic(
      cantidad,
      locale: localeName,
      other: '$cantidad people active this week',
      one: '1 person active this week',
    );
    return '$_temp0';
  }

  @override
  String foroRespuestas(int cantidad) {
    String _temp0 = intl.Intl.pluralLogic(
      cantidad,
      locale: localeName,
      other: '$cantidad replies',
      one: '1 reply',
    );
    return '$_temp0';
  }

  @override
  String foroReportesSinAtender(int cantidad) {
    String _temp0 = intl.Intl.pluralLogic(
      cantidad,
      locale: localeName,
      other: 'There are $cantidad unhandled reports.',
      one: 'There is 1 unhandled report.',
    );
    return '$_temp0';
  }

  @override
  String foroPublicaciones(int cantidad) {
    String _temp0 = intl.Intl.pluralLogic(
      cantidad,
      locale: localeName,
      other: '$cantidad posts',
      one: '1 post',
    );
    return '$_temp0';
  }

  @override
  String get reporteTipoRespuesta => 'REPLY';

  @override
  String get proyectosComunidad => 'eduXaction Colombia community';

  @override
  String get proyectosSubtitulo =>
      'All the active projects in the network. Filter by stage, explore the SDGs they address and discover what the other teams are building.';

  @override
  String get proyectosBuscar => 'Search for a project, community or SDG';

  @override
  String get proyectosTodasEtapas => 'All stages';

  @override
  String get proyectosVacio => 'There are no projects here yet';

  @override
  String get proyectosVacioTexto =>
      'No project has been published in the community yet. When your team registers yours, it will appear here for the whole network.';

  @override
  String get proyectosSinCoincidencias =>
      'No project matches this filter. Try another stage or clear the search.';

  @override
  String get proyectosVerTodasEtapas => 'View all stages';

  @override
  String get proyectosProponer => 'Propose a project';

  @override
  String get proyectosSinEquipo => 'No team assigned yet.';

  @override
  String get proyectosFechaNoRegistrada => 'Date not recorded';

  @override
  String get proyectosProblema => 'Problem';

  @override
  String get proyectosSolucion => 'Solution';

  @override
  String get proyectosIndicadores => 'Impact indicators';

  @override
  String get temaClaro => 'Light';

  @override
  String get temaOscuro => 'Dark';

  @override
  String proyectosAsesor(Object nombre) {
    return 'Academic advisor: $nombre';
  }

  @override
  String get proyectosSinIntegrantes => 'No members assigned.';

  @override
  String get proyectosUniversidadSinDefinir => 'University not defined';

  @override
  String get proyectosActivos => 'Active projects';

  @override
  String get proyectosUniversidades => 'Universities';

  @override
  String get proyectosOdsCubiertos => 'SDGs covered';

  @override
  String get proyectosEnExpo => 'At National Expo';

  @override
  String labEstudiantesAsignados(Object cantidad) {
    return '$cantidad student(s) assigned';
  }

  @override
  String get labMentores => 'Mentors';

  @override
  String get labSinModulos => 'No modules published yet.';

  @override
  String get labBloqueadaAnterior => 'Locked — complete the previous phase';

  @override
  String get labPorVencer => 'Due soon';

  @override
  String get labSinEstudiantes => 'No students';

  @override
  String labCompletaron(Object hechos, Object total) {
    return '$hechos/$total completed';
  }

  @override
  String get usuarioEquipoProyecto => 'Team and project';

  @override
  String get usuarioAvanceRuta => 'Progress in the Impact Path';

  @override
  String get usuarioSinCertificados => 'No certificates yet.';

  @override
  String get usuarioSinLaboratorios => 'No laboratories assigned.';

  @override
  String get usuarioEmpresaTexto =>
      'Their LXDs and mentors appear in their own portal.';

  @override
  String usuarioCodigoImpacto(Object codigo) {
    return 'Impact code: $codigo';
  }

  @override
  String get usuarioDonanteTexto =>
      'Their students and evidence appear in their own portal.';

  @override
  String get usuarioAsesor => 'Academic advisor';

  @override
  String usuarioAcompana(Object universidad) {
    return 'Supports the teams of $universidad.';
  }

  @override
  String get usuarioCursosCreados => 'Courses created';

  @override
  String get usuarioSinCursos => 'Has not created any course yet.';

  @override
  String get usuarioLabsAcompana => 'Laboratories they support';

  @override
  String get usuarioSinLab => 'No laboratory assigned yet.';

  @override
  String usuarioEstudiantes(Object cantidad) {
    return '$cantidad students';
  }

  @override
  String usuarioEntregasRevisadas(Object cantidad) {
    return '$cantidad submissions reviewed.';
  }

  @override
  String comunEstudiantes(int cantidad) {
    String _temp0 = intl.Intl.pluralLogic(
      cantidad,
      locale: localeName,
      other: '$cantidad students',
      one: '1 student',
    );
    return '$_temp0';
  }

  @override
  String proyectosEstudiantesAlcance(int cantidad) {
    String _temp0 = intl.Intl.pluralLogic(
      cantidad,
      locale: localeName,
      other: '$cantidad students within reach',
      one: '1 student within reach',
    );
    return '$_temp0';
  }

  @override
  String proyectosCreadoEl(Object fecha) {
    return 'Created on $fecha';
  }

  @override
  String labFechaLimite(Object fecha) {
    return 'Deadline: $fecha';
  }

  @override
  String usuarioCalificaEn(Object contextos) {
    return 'Grades in: $contextos';
  }

  @override
  String get usuarioNingunContexto => 'no context';

  @override
  String get mapaEstudiantesRegistrados => 'Registered students';

  @override
  String get mapaCiudades => 'Cities';

  @override
  String get mapaDepartamentos => 'Departments';

  @override
  String get mapaRedNacional => 'National network · updated today';

  @override
  String get mapaPatrocina => 'Students sponsored by your organization';

  @override
  String get mapaEstudiantesPais => 'Students across the country';

  @override
  String get mapaTexto =>
      'Where the students registered in eduXaction Colombia are. Each dot is a city with at least one university active in the network.';

  @override
  String get mapaSufijoPatrocina => 'students you sponsor';

  @override
  String get mapaOrdenadas => 'Sorted by number of students';

  @override
  String get mapaSoloVinculados =>
      'Only the students linked to your contribution';

  @override
  String get mapaPortalAliados => 'Partner portal · eduXaction Colombia';

  @override
  String get mapaGeometria => 'Geometry: Natural Earth (public domain)';

  @override
  String get mapaDosOMas => '2 or more students';

  @override
  String get mapaUnEstudiante => '1 student';

  @override
  String mapaEntre(Object desde, Object hasta) {
    return 'Between $desde and $hasta';
  }

  @override
  String mapaOMas(Object cantidad) {
    return '$cantidad or more students';
  }

  @override
  String mapaMenosDe(Object cantidad) {
    return 'Fewer than $cantidad';
  }

  @override
  String get mapaTodaLaRed => 'The whole network';

  @override
  String get mapaLosQuePatrocino => 'The ones I sponsor';

  @override
  String get mapaTema => 'Theme';

  @override
  String get mapaSinVinculados => 'No linked students yet';

  @override
  String get mapaSinVinculadosTexto =>
      'There are no students linked to your contribution yet. As soon as your administrator assigns any, they will appear here on the map.';

  @override
  String get mapaEscribirAdmin => 'Write to my administrator';

  @override
  String get mapaSolicitudTitulo => 'Request for sponsored students';

  @override
  String get mapaSolicitudTexto =>
      'A partner asked to have students assigned to their contribution.';

  @override
  String get mapaAvisamos => 'We let your administrator know.';

  @override
  String get mapaSinCiudades => 'No cities for this scope yet.';

  @override
  String get mapaCiudadExplica =>
      'The city is the one the student (or their administrator) chose in their profile. Students without a city assigned do not appear on the map yet.';

  @override
  String get talentoTitulo => 'TalentSearch';

  @override
  String get talentoSubtitulo =>
      'eduXaction students who have already demonstrated their skills in the Impact Path — contact them for future opportunities 💛';

  @override
  String get talentoVacio =>
      'There are no eduXaction students on the platform yet.';

  @override
  String get talentoTop => 'Top talent';

  @override
  String talentoAvance(Object porcentaje) {
    return '$porcentaje% progress';
  }

  @override
  String talentoObjetivosEmprendimiento(Object cantidad) {
    return '$cantidad entrepreneurship objectives';
  }

  @override
  String talentoObjetivosEmpresariales(Object cantidad) {
    return '$cantidad business objectives';
  }

  @override
  String talentoCertificados(Object cantidad) {
    return '$cantidad certificates';
  }

  @override
  String get talentoContactar => 'Contact';

  @override
  String get talentoOportunidad => 'An opportunity for you';

  @override
  String get talentoNecesitaTitulo => 'The notice needs a title.';

  @override
  String get talentoMensajeEnviado => 'Message sent ✓';

  @override
  String talentoContactarA(Object nombre) {
    return 'Contact $nombre';
  }

  @override
  String get talentoMensajeLlega =>
      'The message arrives in their inbox inside the platform. No contact information is shared.';

  @override
  String get talentoAsunto => 'Subject';

  @override
  String get recursosTitulo => 'Communications Resources';

  @override
  String get recursosSubtitulo =>
      'Templates, brand guides and material for the team';

  @override
  String get recursosNuevo => 'New resource';

  @override
  String get recursosVacio => 'No resources have been published yet.';

  @override
  String get recursosEliminar => 'Delete resource';

  @override
  String recursosEliminarTexto(Object titulo) {
    return 'Delete \"$titulo\"?';
  }

  @override
  String get recursosNecesitaTitulo => 'The resource needs a title.';

  @override
  String get recursosFaltaArchivo => 'The file has not been uploaded yet.';

  @override
  String get recursosFaltaUrl => 'The URL is missing.';

  @override
  String get recursosPublicado => 'Resource published ✓';

  @override
  String get comunDescripcion => 'Description';

  @override
  String get mapaSufijoEstudiantes => 'students';

  @override
  String get lxdPortal => 'LXD Portal';

  @override
  String get tabMisEstudiantes => 'My Students';

  @override
  String get tabEstudiantesCorto => 'Students';

  @override
  String get tabCalificaciones => 'Grading';

  @override
  String get tabCalificarCorto => 'Grade';

  @override
  String get tabCertificaciones => 'Certifications';

  @override
  String get lxdEstudiantesSubtitulo =>
      'Students enrolled in courses you created';

  @override
  String get lxdFiltrarNombre => 'Filter by name or institution';

  @override
  String get lxdSinEstudiantes =>
      'There are no students enrolled in your courses.';

  @override
  String get comunEstudiante => 'Student';

  @override
  String get comunEtapa => 'Stage';

  @override
  String get lxdNecesidad => 'Need';

  @override
  String get comunInstitucion => 'Institution';

  @override
  String get comunProgreso => 'Progress';

  @override
  String get lxdPromedioCursos => 'Average across all your courses';

  @override
  String get lxdAcompanamientoUrgente => 'Urgent support';

  @override
  String get lxdSeguimientoRegular => 'Regular follow-up';

  @override
  String get lxdAutonomo => 'Independent';

  @override
  String lxdResumenAvance(Object porcentaje) {
    return 'Progress: $porcentaje%';
  }

  @override
  String lxdResumenEmpresa(Object empresa) {
    return 'Company: $empresa';
  }

  @override
  String get lxdProyectosSubtitulo =>
      'Teams and progress in your students\' Impact Path';

  @override
  String get lxdSinProyectos =>
      'None of your students has a project assigned yet.';

  @override
  String get lxdCalendarioSubtitulo =>
      'Schedule the live sessions of your Open Learning courses';

  @override
  String get lxdCursosSubtitulo =>
      'Courses you created — eduXaction (assigned to a laboratory or not) and Open Learning';

  @override
  String get lxdNuevoCurso => 'New course';

  @override
  String get lxdSinCursos =>
      'You have not created any course yet. Create the first one.';

  @override
  String get lxdNombreCurso => 'Give the course a name.';

  @override
  String get lxdNombreDelCurso => 'Course name';

  @override
  String get lxdCursoOpenLearning => 'Open Learning course';

  @override
  String get lxdCursoOpenLearningTexto =>
      'It is assigned directly to external students, without a laboratory or Impact Path';

  @override
  String get lxdLabsNoCargan =>
      'The laboratories could not be loaded. You can assign it later from the builder.';

  @override
  String get lxdLaboratorioOpcional => 'Laboratory (optional)';

  @override
  String get lxdSinAsignarAun => 'Unassigned for now';

  @override
  String get comunCreando => 'Creating…';

  @override
  String get lxdCrearAbrir => 'Create and open builder';

  @override
  String lxdInscritos(Object cantidad) {
    return '$cantidad enrolled';
  }

  @override
  String lxdCompletados(Object cantidad) {
    return '$cantidad completed';
  }

  @override
  String lxdAvance(Object porcentaje) {
    return '$porcentaje% progress';
  }

  @override
  String get lxdSinNotas => 'No grades';

  @override
  String lxdPromedio(Object nota) {
    return 'Average $nota';
  }

  @override
  String lxdPendientes(Object cantidad) {
    return '$cantidad pending';
  }

  @override
  String get lxdSinVincular => 'Not linked to any module yet';

  @override
  String lxdVinculadoA(Object modulo) {
    return 'Linked to: $modulo';
  }

  @override
  String get lxdConstructor => 'Builder';

  @override
  String get lxdSeguimiento => 'Tracking';

  @override
  String get lxdEliminarCurso => 'Delete course';

  @override
  String lxdEliminarCursoTexto(Object nombre) {
    return 'You are about to delete \"$nombre\" with all its modules, lessons and settings.';
  }

  @override
  String get lxdCursoEliminado => 'Course deleted';

  @override
  String get lxdCalificacionesSubtitulo =>
      'Student submissions in your courses';

  @override
  String get lxdSinPermisoCalificar =>
      'Your Admin has not given you permission to grade yet';

  @override
  String get lxdSinEntregas => 'There are no submissions to grade.';

  @override
  String get calificarElija => 'Choose passed or failed.';

  @override
  String get calificarPuntajeRango => 'The score goes from 0 to 100.';

  @override
  String get calificarNotaRango => 'The grade goes from 0.0 to 5.0.';

  @override
  String get calificarEntregaCalificada => 'Submission graded ✓';

  @override
  String calificarTitulo(Object tarea) {
    return 'Grade: $tarea';
  }

  @override
  String get calificarEscala => 'Grading scale';

  @override
  String get calificarResultado => 'Result:';

  @override
  String get calificarSoloRevision =>
      'This activity is review-only: leave your feedback without a grade.';

  @override
  String get calificarPuntaje => 'Score (0 - 100)';

  @override
  String get calificarNota => 'Grade (0.0 - 5.0)';

  @override
  String get calificarRetroalimentacion => 'Feedback';

  @override
  String certificadoEmitido(Object codigo) {
    return 'Certificate $codigo issued 🏆';
  }

  @override
  String get certificacionesSubtitulo =>
      'The certificate is issued when a laboratory\'s full Impact Path is completed (there is no longer a per-course certificate)';

  @override
  String get certificacionesSinPermiso =>
      'Your Admin has not given you permission to grade in eduXaction: you cannot issue certificates yet';

  @override
  String get certificacionesEmitidos => 'Certificates issued';

  @override
  String get certificacionesVacio => 'No certificates have been issued yet.';

  @override
  String get certificacionesEmitirNuevo => 'Issue a new certificate';

  @override
  String get certificacionesLabRuta => 'Laboratory (full Path)';

  @override
  String get certificacionesEmitiendo => 'Issuing…';

  @override
  String get certificacionesEmitir => 'Issue';

  @override
  String get certificacionesComprobando => 'Checking their Impact Path…';

  @override
  String get certificacionesNoCompleto =>
      'This student has not completed the Impact Path of any laboratory yet';

  @override
  String get lxdPerfilSubtitulo =>
      'Information visible to administrators and students';

  @override
  String get lxdPermisoOL => 'Grading permission · Open Learning';

  @override
  String get comunActivado => 'Enabled';

  @override
  String get comunDesactivado => 'Disabled';

  @override
  String get lxdPermisoEduxaction => 'Grading permission · eduXaction';

  @override
  String get perfilCargo => 'Position';

  @override
  String get perfilEspecialidad => 'Specialty';

  @override
  String get perfilIdiomas => 'Languages';

  @override
  String get perfilDisponibilidad => 'Availability';

  @override
  String get perfilExperiencia => 'Experience';

  @override
  String get perfilIntereses => 'Interests';

  @override
  String lxdResumenProyecto(Object proyecto) {
    return 'Project: $proyecto';
  }

  @override
  String certificadoLinea(
    Object estudiante,
    Object laboratorio,
    Object codigo,
  ) {
    return '$estudiante · Impact Path $laboratorio · $codigo';
  }

  @override
  String get constructorInfoGeneral => 'General information';

  @override
  String get constructorCategorizacion => 'Categorization and objectives';

  @override
  String get constructorDelCurso => 'Course builder';

  @override
  String get constructorEvaluacion => 'Assessment and certificate';

  @override
  String get constructorRestricciones => 'Restrictions and sponsorship';

  @override
  String get constructorTitulo => 'Course Builder';

  @override
  String get comunVolver => 'Back';

  @override
  String get constructorHerramienta => 'the module and lesson builder';

  @override
  String get constructorNecesitaNombre => 'The course needs a name.';

  @override
  String get constructorGuardado => 'Course saved ✓';

  @override
  String get constructorSubtitulo => 'Subtitle';

  @override
  String get constructorDescCorta => 'Short description';

  @override
  String get constructorDescCompleta => 'Full description';

  @override
  String get constructorPortada => 'Cover image';

  @override
  String get constructorYaPortada =>
      'It already has a cover. Uploading another one replaces it.';

  @override
  String get constructorNivel => 'Level';

  @override
  String get constructorDuracion => 'Estimated duration (hours)';

  @override
  String get constructorIdioma => 'Language';

  @override
  String get constructorEstado => 'Status: ';

  @override
  String get constructorPublicar => 'Publish';

  @override
  String get constructorArchivar => 'Archive';

  @override
  String get constructorArchivarCurso => 'Archive course';

  @override
  String get constructorArchivarTexto =>
      'It is no longer assigned to new students, but those who already have progress are not blocked.';

  @override
  String get constructorLeccionesCompletar => 'Lessons to complete:';

  @override
  String get constructorCategorizacionGuardada => 'Categorization saved ✓';

  @override
  String get constructorSinLab => 'No laboratory (special course)';

  @override
  String get constructorEtiquetas => 'Tags';

  @override
  String get constructorCompetencias => 'Skills it develops (impact metrics)';

  @override
  String get constructorOdsRelacionados => 'Related SDGs';

  @override
  String get constructorObjetivosCurso => 'Course objectives';

  @override
  String get constructorObjetivosPista =>
      'e.g. Understand the fundamentals of applied AI';

  @override
  String get constructorObjetivosRuta => 'Objectives for the Impact Path';

  @override
  String get constructorObjetivosRutaTexto =>
      'If this course is linked to a module of a laboratory, these objectives are automatically added to those of that phase.';

  @override
  String get constructorObjetivosEmprendimiento =>
      'Entrepreneurship Objectives';

  @override
  String get constructorObjetivosEmprendimientoPista =>
      'e.g. Identify AI opportunities in social projects';

  @override
  String get constructorObjetivosEmpresariales => 'Business Objectives';

  @override
  String get constructorObjetivosEmpresarialesPista =>
      'e.g. Understand the fundamentals of machine learning';

  @override
  String get constructorResultados => 'Learning outcomes';

  @override
  String get constructorResultadosPista =>
      'e.g. Builds a prototype with real data';

  @override
  String get constructorPrerrequisitos => 'Prerequisites';

  @override
  String get constructorPrerrequisitosTexto =>
      'Courses the student should complete beforehand (or none).';

  @override
  String get constructorSinOtrosCursos =>
      'There are no other courses available.';

  @override
  String get constructorNuevoModulo => 'New module';

  @override
  String get constructorTituloModulo => 'Module title';

  @override
  String get constructorArrastre =>
      'Drag with the ⠿ icon to reorder modules and lessons.';

  @override
  String get constructorPrimerModulo =>
      'Create the first module to get started.';

  @override
  String constructorModuloTitulo(Object numero, Object titulo) {
    return 'Module $numero: $titulo';
  }

  @override
  String get constructorRenombrarModulo => 'Rename module';

  @override
  String get constructorAgregarLeccion => 'Add lesson';

  @override
  String get constructorEliminarModulo => 'Delete module';

  @override
  String get constructorSinLecciones => 'No lessons — use + to add content.';

  @override
  String constructorEditarTipo(Object tipo) {
    return 'Edit $tipo';
  }

  @override
  String get constructorEliminarLeccion => 'Delete lesson';

  @override
  String constructorEliminarLeccionTexto(Object titulo) {
    return 'Delete \"$titulo\"?';
  }

  @override
  String get comunGuardado => 'Saved ✓';

  @override
  String get constructorCuentaCertificado =>
      'Does this course count toward a certificate?';

  @override
  String get constructorCuentaCertificadoTexto =>
      'A seal is shown on the course and its hours count toward the laboratory\'s Impact Path certificate (the LXD issues the PDF when the whole Path is completed, not per individual course)';

  @override
  String get constructorHorasCertificadas => 'Certified hours';

  @override
  String get constructorSinDefinir => 'Not set';

  @override
  String constructorApertura(Object fecha) {
    return 'Opens: $fecha';
  }

  @override
  String constructorCierre(Object fecha) {
    return 'Closes: $fecha';
  }

  @override
  String get constructorCierreAntes =>
      'The course cannot close before it opens.';

  @override
  String get constructorMaximo => 'Maximum number of students (0 = no limit)';

  @override
  String get constructorVisible => 'Visible';

  @override
  String get constructorOculto => 'Hidden';

  @override
  String get constructorOcultosTexto =>
      'Hidden courses do not appear for assignment';

  @override
  String get constructorPatrocinio => 'Sponsorship';

  @override
  String get constructorEmpresaPatrocinadora =>
      'Sponsoring company for the course (optional)';

  @override
  String get constructorNinguna => 'None';

  @override
  String get constructorPatrocinioTexto =>
      'The training hours completed in sponsored courses feed the company\'s impact metrics.';

  @override
  String get constructorQuitarFecha => 'Remove date';

  @override
  String get comunAgregar => 'Add';

  @override
  String get comunAceptar => 'OK';

  @override
  String constructorEliminarModuloTexto(Object modulo, int cantidad) {
    String _temp0 = intl.Intl.pluralLogic(
      cantidad,
      locale: localeName,
      other: 'You are about to delete \"$modulo\" with its $cantidad lessons.',
      one: 'You are about to delete \"$modulo\" with its 1 lesson.',
    );
    return '$_temp0';
  }

  @override
  String get quizTipoMultiple => 'Multiple choice';

  @override
  String get quizTipoVerdaderoFalso => 'True / False';

  @override
  String get quizTipoCorta => 'Short answer';

  @override
  String get quizTipoOrdenar => 'Order';

  @override
  String get quizTipoCompletar => 'Fill in the blank';

  @override
  String get leccionDescartarTexto =>
      'There are unsaved changes in this lesson. Do you want to leave anyway?';

  @override
  String get leccionNecesitaTitulo => 'The lesson needs a title.';

  @override
  String get leccionEnlaceNecesitaUrl => 'A link lesson needs its URL.';

  @override
  String get leccionEspereRevision => 'Wait for the video check to finish.';

  @override
  String get leccionSubidaCancelada =>
      'The upload was canceled. If the lesson already had a video, it stays the same.';

  @override
  String get leccionEnlaceYoutube => 'YouTube video link';

  @override
  String leccionYoutubeEncontrado(Object id) {
    return 'YouTube video found. Only its id ($id) is saved, not the link.';
  }

  @override
  String get leccionEnlaceVimeo =>
      'Vimeo link: it is saved as is and played with the Vimeo player.';

  @override
  String get leccionYaTieneVideo =>
      'This lesson already has its own uploaded video. Pasting a link replaces it.';

  @override
  String get leccionPegueEnlace =>
      'Paste the link just as you copy it from YouTube: watch?v=, youtu.be, shorts and embed all work. Vimeo is also accepted.';

  @override
  String get leccionNueva => 'New lesson';

  @override
  String get leccionEditar => 'Edit lesson';

  @override
  String get leccionSubiendo => 'Uploading…';

  @override
  String get leccionPegarYoutube => 'Paste YouTube link';

  @override
  String get leccionSubirVideo => 'Upload video';

  @override
  String get leccionDuracionMinutos => 'Duration (minutes)';

  @override
  String get leccionArchivoDescargable => 'Downloadable file';

  @override
  String leccionArchivoActual(Object archivo) {
    return 'Current: $archivo';
  }

  @override
  String get leccionPreguntasEncuesta => 'Survey questions (not graded)';

  @override
  String get leccionPreguntasQuiz => 'Questions (graded by the server)';

  @override
  String get leccionPregunta => 'Question';

  @override
  String get leccionSinPreguntas =>
      'No questions yet. A quiz lesson without questions is saved, but whoever opens it gets a notice instead of a grade.';

  @override
  String leccionPreguntaNumero(Object numero) {
    return 'Question $numero';
  }

  @override
  String get leccionQuitarPregunta => 'Remove question';

  @override
  String get leccionEnunciado => 'Prompt';

  @override
  String get leccionQuitarOpcion => 'Remove option';

  @override
  String get leccionOpcion => 'Option';

  @override
  String get leccionRespuestaCorrecta => 'Correct answer:';

  @override
  String get leccionRespuestaFlexible =>
      'Correct answer (accents and capitalization are compared flexibly)';

  @override
  String get leccionPalabraCompleta =>
      'Word or phrase that completes the prompt';

  @override
  String get leccionOrdenCorrecto =>
      'Items in the CORRECT order — this is how they are saved, and anyone who orders them the same way gets them right:';

  @override
  String get leccionQuitarElemento => 'Remove item';

  @override
  String get leccionElemento => 'Item';

  @override
  String get leccionInstrucciones => 'Activity instructions';

  @override
  String get leccionFechaSinDefinir => 'Deadline: not set';

  @override
  String get leccionMaxArchivos => 'Max. files';

  @override
  String get leccionPedirAlgo =>
      'The activity has to ask for at least text or a file: otherwise there is nothing to submit.';

  @override
  String get leccionTiposEntregable =>
      'Accepted deliverable types (none = any)';

  @override
  String get leccionCalificacion => 'Grading';

  @override
  String get leccionRubrica => 'Rubric (criteria and points)';

  @override
  String get leccionCriterio => 'Criterion';

  @override
  String get leccionPuntos => 'Points';

  @override
  String get leccionQuitarCriterio => 'Remove criterion';

  @override
  String leccionTotalPuntos(Object total) {
    return 'Total: $total points';
  }

  @override
  String leccionOpcionNumero(Object numero) {
    return 'Option $numero';
  }

  @override
  String leccionOpcionCorrecta(Object numero) {
    return 'Option $numero (correct)';
  }

  @override
  String glosarioDelModuloCon(Object terminos) {
    return 'Module glossary · $terminos';
  }

  @override
  String get glosarioEditorVacio =>
      'This module does not have any terms yet. The ones you add appear at the end of the lessons you mark and at the end of the module.';

  @override
  String get glosarioAgregarTermino => 'Add term';

  @override
  String glosarioArrastrar(Object palabra) {
    return 'Drag to reorder “$palabra”';
  }

  @override
  String get glosarioTieneImagen => 'Has an image';

  @override
  String get glosarioSinLeccion => 'It is not marked in any lesson';

  @override
  String glosarioEditarPalabra(Object palabra) {
    return 'Edit “$palabra”';
  }

  @override
  String glosarioEliminarPalabra(Object palabra) {
    return 'Delete “$palabra”';
  }

  @override
  String get glosarioEliminarTermino => 'Delete term';

  @override
  String glosarioEliminarTerminoTexto(Object palabra) {
    return 'Delete “$palabra” from the glossary? It is also removed from other terms\' related lists and from the students\' review.';
  }

  @override
  String get glosarioPalabraObligatoria => 'The word is required.';

  @override
  String glosarioYaExiste(Object palabra) {
    return '“$palabra” already exists in this module.';
  }

  @override
  String glosarioYaExisteEn(Object palabra, Object modulo) {
    return '“$palabra” already exists in the module “$modulo”.';
  }

  @override
  String get glosarioDescartarTexto =>
      'There are unsaved changes in this term. Do you want to leave anyway?';

  @override
  String get glosarioTerminoAgregado => 'Term added ✓';

  @override
  String get glosarioNuevoTermino => 'New term';

  @override
  String get glosarioEditarTermino => 'Edit term';

  @override
  String glosarioModulo(Object modulo) {
    return 'Module: $modulo';
  }

  @override
  String get glosarioPalabraCampo => 'Word or expression *';

  @override
  String get glosarioDefinicionCorta => 'Short definition *';

  @override
  String get glosarioDefinicionObligatoria =>
      'The short definition is required.';

  @override
  String get glosarioDefinicionAyuda =>
      'One or two sentences. It is what is shown on the card and when hovering over the word.';

  @override
  String get glosarioExplicacion => 'Extended explanation (optional)';

  @override
  String get glosarioEjemploOpcional => 'Example (optional)';

  @override
  String get glosarioImagenOpcional => 'Image (optional)';

  @override
  String get glosarioQuitarImagen => 'Remove image';

  @override
  String get glosarioPngJpg => 'PNG or JPG.';

  @override
  String get glosarioLeccionesDonde => 'Lessons where it appears';

  @override
  String get glosarioModuloSinLecciones =>
      'This module does not have any lessons yet.';

  @override
  String get glosarioRelacionadosTitulo => 'Related terms';

  @override
  String get glosarioRelacionadosAyuda =>
      'When the course has more terms, you will be able to relate them here.';

  @override
  String get glosarioDeOtroModulo => 'From another module';

  @override
  String get seguimientoTitulo => 'Course Tracking';

  @override
  String get seguimientoInscritos => 'Enrolled';

  @override
  String get seguimientoCompletados => 'Completed';

  @override
  String get seguimientoAvancePromedio => 'Average progress';

  @override
  String get seguimientoNotaPromedio => 'Average grade';

  @override
  String get seguimientoSinEstudiantes =>
      'There are no students assigned to this course yet.\nThe admin assigns them from their portal.';

  @override
  String get seguimientoAnaliticas => 'Analytics';

  @override
  String get seguimientoNota => 'Grade';

  @override
  String get seguimientoUltimaActividad => 'Last activity';

  @override
  String get seguimientoEstado => 'Status';

  @override
  String get seguimientoComentarios => 'Comments';

  @override
  String get seguimientoCompletado => 'Completed';

  @override
  String get seguimientoSinIniciar => 'Not started';

  @override
  String seguimientoNotaPrivada(Object nota) {
    return 'Private note: $nota';
  }

  @override
  String get seguimientoAgregarComentario => 'Add private comment';

  @override
  String seguimientoComentariosDe(Object nombre) {
    return 'Private comments — $nombre';
  }

  @override
  String get seguimientoRetroObservaciones => 'Feedback and observations';

  @override
  String get seguimientoSoloDocentes =>
      'Only for the teaching team. The student does NOT see it.';

  @override
  String get seguimientoAvanceCurso => 'Course progress';

  @override
  String get comunSinDatos => 'No data';

  @override
  String get seguimientoAvanceUniversidad =>
      'Average progress by university (%)';

  @override
  String get seguimientoRiesgo => 'Dropout risk (not started)';

  @override
  String get seguimientoTiempoPromedio => 'Average time spent';

  @override
  String get seguimientoAvancePatrocinados => 'Sponsored students\' progress';

  @override
  String get seguimientoLeccionesTotales => 'Total lessons';

  @override
  String glosarioApareceEn(int cantidad) {
    String _temp0 = intl.Intl.pluralLogic(
      cantidad,
      locale: localeName,
      other: '$cantidad lessons',
      one: '1 lesson',
    );
    return 'Appears in $_temp0';
  }

  @override
  String seguimientoNotaYActividad(Object nota, Object actividad) {
    return 'Grade: $nota  ·  $actividad';
  }

  @override
  String get adminPortalSuper => 'Super Admin Portal';

  @override
  String get adminPortal => 'Admin Portal';

  @override
  String get tabUsuarios => 'Users';

  @override
  String get tabEquipos => 'Teams';

  @override
  String get tabEvidenciasDonantes => 'Donor evidence';

  @override
  String get tabEvidenciasCorto => 'Evidence';

  @override
  String get tabContenidoPagina => 'Page content';

  @override
  String get tabContenidoCorto => 'Content';

  @override
  String get tabDatosRespaldos => 'Data and backups';

  @override
  String get tabRespaldosCorto => 'Backups';

  @override
  String get adminDashboardGeneral => 'General Dashboard';

  @override
  String get adminDashboardSubtitulo => 'Overall status of the platform';

  @override
  String get adminImpactoFormativo => 'eduXaction training impact';

  @override
  String get adminUsuariosPorRol => 'Users by role';

  @override
  String get adminEstudAbrev => 'Stud.';

  @override
  String get adminAsesores => 'Advisors';

  @override
  String get adminEmpresas => 'Companies';

  @override
  String get adminDonantes => 'Donors';

  @override
  String get adminProyectosPorEtapa => 'Projects by stage';

  @override
  String get adminConfigureMetricas =>
      'Set up skills, SDGs and hours in the courses (LXD builder) to see training impact metrics.';

  @override
  String get adminHorasCompetencia => 'Training hours by skill';

  @override
  String get adminSinDatosAun => 'No data yet';

  @override
  String get adminCoberturaOds => 'SDG coverage (students who completed)';

  @override
  String get adminSinCursosOds => 'No courses associated with SDGs yet';

  @override
  String adminOdsTooltip(Object ods, Object completados, Object total) {
    return '$ods — $completados of $total';
  }

  @override
  String get adminCalendarioSubtitulo =>
      'Open Learning live sessions, Impact Path events and mentoring sessions across the whole platform';

  @override
  String get asignarCursosOk => 'Courses assigned ✓';

  @override
  String get asignarLabsOk => 'Laboratories assigned ✓';

  @override
  String asignarA(Object nombre) {
    return 'Assign to $nombre';
  }

  @override
  String asignarNoCarga(Object error) {
    return 'What is assigned could not be loaded: $error';
  }

  @override
  String get asignarExplicaOL =>
      'Open Learning account: receives courses one by one. It is their only way to access material — without assigned courses there is nothing to see. It has no laboratories or Impact Path.';

  @override
  String get asignarExplicaEdu =>
      'eduXaction account: receives laboratories, and with them access to ALL their courses, without assigning them separately. Removing a laboratory removes that material: their progress is not deleted and comes back as it was if it is reassigned, but in the meantime they stop seeing it.';

  @override
  String get asignarSinLabs => 'There are no laboratories created yet.';

  @override
  String get asignarSinCursos => 'There are no courses created yet.';

  @override
  String get asignarDeLaboratorio => 'Laboratory course';

  @override
  String asignarPendientes(int cantidad, Object cursos) {
    String _temp0 = intl.Intl.pluralLogic(
      cantidad,
      locale: localeName,
      other:
          'Assigned. These courses are not published, so they will not see them yet: $cursos.',
      one:
          'Assigned. This course is not published, so they will not see it yet: $cursos.',
    );
    return '$_temp0';
  }

  @override
  String adminHorasPatrocinadas(Object empresa, Object horas) {
    return '$empresa has sponsored $horas hours of training';
  }

  @override
  String get usuariosSubtituloSuper =>
      'Creates and deletes any type of account (including admins)';

  @override
  String get usuariosSubtitulo =>
      'Creates accounts for students, LXDs, mentors, advisors, companies and donors';

  @override
  String get usuariosNuevo => 'New user';

  @override
  String get comunTodos => 'All';

  @override
  String get usuariosSinRol => 'There are no accounts with that role.';

  @override
  String get usuariosUnaSolicitud => '1 account deletion request';

  @override
  String usuariosSolicitudes(Object cantidad) {
    return '$cantidad account deletion requests';
  }

  @override
  String usuariosSolicitudesTexto(Object dias) {
    return 'These accounts no longer work. Their personal data still has to be deleted within the $dias-day period they were promised.';
  }

  @override
  String usuariosBorrarDatosDe(Object nombre) {
    return 'Delete $nombre\'s data';
  }

  @override
  String get usuariosBorrarDatosTexto =>
      'Their name, email, phone, ID number, city, photo and profile, the name on their certificates and the notes about this person are deleted. This cannot be undone.';

  @override
  String get usuariosDatosBorrados => 'Data deleted.';

  @override
  String get usuariosBorrando => 'Deleting…';

  @override
  String get usuariosBorrarDatos => 'Delete data';

  @override
  String get usuariosRol => 'Role';

  @override
  String get usuariosDetalle => 'Details';

  @override
  String get usuariosAcciones => 'Actions';

  @override
  String usuariosCalifica(Object contextos) {
    return 'Grades: $contextos';
  }

  @override
  String get usuariosAsignarCursos => 'Assign courses';

  @override
  String get usuariosAsignarLabs => 'Assign laboratories';

  @override
  String get usuariosEliminar => 'Delete user';

  @override
  String usuariosEliminarTexto(Object nombre, Object rol) {
    return 'You are about to delete $nombre ($rol).';
  }

  @override
  String get usuariosCuentaEliminada => 'Account deleted ✓';

  @override
  String get usuariosNombreCorreoObligatorios => 'Name and email are required.';

  @override
  String get usuariosContrasenaMinima =>
      'The password needs at least 6 characters.';

  @override
  String get usuariosEscribaInstitucion =>
      'Write the name of the institution in “Which institution?”.';

  @override
  String get usuariosEditar => 'Edit user';

  @override
  String usuariosRolFijo(Object rol) {
    return 'Role: $rol — to change it, another account is created. Changing it here would move their access without anyone noticing.';
  }

  @override
  String get usuariosNombreCompleto => 'Full name';

  @override
  String get usuariosContrasenaNueva => 'New password (optional)';

  @override
  String get usuariosMinimoSeis => 'At least 6 characters.';

  @override
  String get usuariosDejeEnBlanco =>
      'Leave it blank to keep it. Changing it signs that person out of their open sessions.';

  @override
  String get usuariosSinUniversidadAsesor =>
      'No university — they will not see students';

  @override
  String get usuariosNombreEmpresa => 'Company name';

  @override
  String get usuariosCodigoImpacto => 'Unique impact code';

  @override
  String get usuariosTipoEstudiante => 'Student type';

  @override
  String get usuariosSoloCursos =>
      'They only see the courses you assign them. No laboratories or Impact Path.';

  @override
  String get usuariosVeLabs =>
      'They see Laboratories and their Impact Path (assigned from the laboratory).';

  @override
  String get usuariosElijaUniversidad => 'Choose a university';

  @override
  String get usuariosSinUniversidadOL => 'No university (Open Learning)';

  @override
  String get usuariosCiudadAyuda =>
      'Where they are from — it places them on the Student Map';

  @override
  String get usuariosLxdEmpresa =>
      'If this LXD is from a partner company, their courses are attributed to it.';

  @override
  String get usuariosPermisoCalificar => 'Grading permission';

  @override
  String get usuariosCambioRegistrado =>
      'Every change is recorded with who made it.';

  @override
  String get usuariosOLDefecto =>
      'Enabled by default: they are the one who grades there';

  @override
  String get usuariosEduDefecto =>
      'Disabled by default: they do not grade there';

  @override
  String get usuariosMentorLab =>
      'The laboratory is assigned from the \"Laboratories\" tab (a laboratory can have several mentors).';

  @override
  String get usuariosMentorEmpresa =>
      'If this Mentor is from a partner company, they are attributed to it.';

  @override
  String get usuariosEmpresaAliada => 'Partner company (optional)';

  @override
  String get usuariosNingunaEdu => 'None (eduXaction\'s own)';

  @override
  String usuariosPidioEl(Object correo, Object fecha) {
    return '$correo · requested on $fecha';
  }

  @override
  String usuariosQuedanDias(int cantidad) {
    String _temp0 = intl.Intl.pluralLogic(
      cantidad,
      locale: localeName,
      other: '$cantidad days left',
      one: '1 day left',
    );
    return '$_temp0';
  }

  @override
  String get usuariosPlazoVencido => 'deadline passed';

  @override
  String get usuariosNinguno => 'none';

  @override
  String get gestionProyectosSubtitulo =>
      'Each project defines a problem, solution, community, SDGs, stage and indicators';

  @override
  String get gestionNuevoProyecto => 'New project';

  @override
  String get gestionSinProyectos => 'There are no projects.';

  @override
  String get gestionEliminarProyecto => 'Delete project';

  @override
  String gestionVaAEliminar(Object nombre) {
    return 'You are about to delete \"$nombre\".';
  }

  @override
  String gestionIntegrantes(int cantidad) {
    String _temp0 = intl.Intl.pluralLogic(
      cantidad,
      locale: localeName,
      other: '$cantidad members',
      one: '1 member',
    );
    return '$_temp0';
  }

  @override
  String get gestionProyectoNombre => 'The project needs a name.';

  @override
  String get gestionEditarProyecto => 'Edit project';

  @override
  String get gestionSinUniversidadReconciliar =>
      'No university (pending reconciliation)';

  @override
  String get gestionIntegrantesUniversidad =>
      'Its members have to be from this university.';

  @override
  String get gestionProblema => 'Problem it solves';

  @override
  String get gestionSolucion => 'Proposed solution';

  @override
  String get gestionComunidad => 'Benefiting community';

  @override
  String get gestionEtapaActual => 'Current stage';

  @override
  String get gestionHabilitarExpo => 'Enable NATIONAL EXPO PATH';

  @override
  String get gestionHabilitarExpoTexto =>
      'Opens the preparation checklist for the team.';

  @override
  String get gestionEquiposSubtitulo =>
      'Each team works on a project from a university, with its academic advisor';

  @override
  String get gestionNuevoEquipo => 'New team';

  @override
  String get gestionSinEquipos => 'There are no teams.';

  @override
  String get gestionIntegrantesTitulo => 'Members';

  @override
  String get gestionEliminarEquipo => 'Delete team';

  @override
  String get gestionEquipoNecesita => 'The team needs a name and a project.';

  @override
  String get gestionEditarEquipo => 'Edit team';

  @override
  String get gestionNombreEquipo => 'Team name';

  @override
  String get gestionUniversidadDelProyecto =>
      'It comes from the project. To change it, edit the project.';

  @override
  String get gestionElijaProyecto => 'Choose a project';

  @override
  String get gestionProyectoSinUniversidad =>
      'The project does not have a university yet';

  @override
  String get gestionAsesorOpcional => 'Academic advisor (optional)';

  @override
  String get gestionAsesorAyuda =>
      'The advisor supports the team, not the project: a project can have teams from several universities.';

  @override
  String get gestionSinAsesor => 'No advisor';

  @override
  String gestionIntegrantesDe(Object nombre) {
    return 'Members of $nombre';
  }

  @override
  String get gestionSinEstudiantes => 'There are no students to assign.';

  @override
  String get gestionRolProyecto =>
      'The role within the project is not the platform role: it describes what that person does on the team.';

  @override
  String get gestionLabsSubtitulo =>
      'Each laboratory has its three-phase Impact Path';

  @override
  String get gestionNuevoLab => 'New laboratory';

  @override
  String get gestionSinLabs => 'There are no laboratories.';

  @override
  String get gestionEditarRuta => 'Edit Impact Path';

  @override
  String get gestionEliminarLab => 'Delete laboratory';

  @override
  String gestionEliminarLabTexto(Object nombre) {
    return 'You are about to delete \"$nombre\" with its whole Path.';
  }

  @override
  String get gestionLabNombre => 'The laboratory needs a name.';

  @override
  String get gestionEditarLab => 'Edit laboratory';

  @override
  String get gestionLabSeCrea =>
      'It is created with its three phases. They are then edited from the Impact Path editor.';

  @override
  String get gestionEmpresaOpcional => 'Sponsoring company (optional)';

  @override
  String get gestionCursosSubtitulo =>
      'All the courses on the platform, from any LXD';

  @override
  String get gestionSinCursosEstado => 'There are no courses with that status.';

  @override
  String gestionCompletaron(Object cantidad) {
    return '$cantidad completed';
  }

  @override
  String gestionSinCalificar(Object cantidad) {
    return '$cantidad ungraded';
  }

  @override
  String gestionRutaModulo(Object modulo) {
    return 'Path: $modulo';
  }

  @override
  String get gestionEvidenciasTitulo => 'Evidence for Donors';

  @override
  String get gestionEvidenciasSubtitulo =>
      'Photos, stories and reports that each donor sees in their portal';

  @override
  String get gestionNuevaEvidencia => 'New evidence';

  @override
  String get gestionSinEvidencias => 'There is no evidence yet.';

  @override
  String get gestionEliminarEvidencia => 'Delete evidence';

  @override
  String get gestionEvidenciaNecesita =>
      'The evidence needs a title and a donor.';

  @override
  String get gestionEditarEvidencia => 'Edit evidence';

  @override
  String get gestionTipo => 'Type';

  @override
  String get gestionDonanteRecibe => 'Donor who receives it';

  @override
  String get gestionSoloEseDonante =>
      'Only that donor sees it in their portal.';

  @override
  String get gestionArchivoOpcional => 'File (optional)';

  @override
  String get gestionYaTieneArchivo =>
      'It already has a file. Uploading another one replaces it.';

  @override
  String get rutaEditorHerramienta => 'the Impact Path editor';

  @override
  String rutaEditorVersion(Object version) {
    return 'Content version $version';
  }

  @override
  String get rutaEditorVersionTexto =>
      'Certificates stay anchored to the content version they were issued with: adding modules later does not invalidate the ones already awarded.';

  @override
  String get rutaEditorAcompanan => 'Who supports it';

  @override
  String get rutaEditorSinMentores => 'No mentors or LXD yet.';

  @override
  String rutaEditorMentoresDe(Object nombre) {
    return 'Mentors of $nombre';
  }

  @override
  String get rutaEditorMentoresAyuda =>
      'A laboratory can have several mentors, and they all see its students.';

  @override
  String rutaEditorEstudiantesCantidad(Object cantidad) {
    return 'Students ($cantidad)';
  }

  @override
  String rutaEditorEstudiantesDe(Object nombre) {
    return 'Students of $nombre';
  }

  @override
  String get rutaEditorEstudiantesAyuda =>
      'Assigning someone here gives them access to the laboratory\'s COURSES. Removing them takes it away: their progress is not deleted, but they stop seeing it. eduXaction students only.';

  @override
  String get rutaEditorSinCuentas => 'There are no accounts available.';

  @override
  String get rutaEditorEditarFase => 'Edit the phase';

  @override
  String get rutaEditorFasesTres =>
      'There are always three phases: they are edited, not added or deleted. A Path with two phases cannot be completed.';

  @override
  String get rutaEditorObjetivo => 'Objective';

  @override
  String get rutaEditorSinObjetivos => 'No objectives yet.';

  @override
  String get rutaEditorCursosCumplen => 'Courses that fulfill it';

  @override
  String get rutaEditorQuitarObjetivo => 'Remove objective';

  @override
  String rutaEditorQuitarObjetivoTexto(Object objetivo) {
    return 'Remove \"$objetivo\" from the phase?';
  }

  @override
  String get rutaEditorSinCursosTraba =>
      'Without linked courses it can never be completed, and that blocks the whole phase for the entire laboratory.';

  @override
  String get rutaEditorObjetivoTexto => 'The objective needs its text.';

  @override
  String get rutaEditorNuevoObjetivo => 'New objective';

  @override
  String get rutaEditorEditarObjetivo => 'Edit objective';

  @override
  String get rutaEditorCategoria => 'Category';

  @override
  String get rutaEditorVincular =>
      'Afterwards you have to link the courses that fulfill it: without them it is never completed.';

  @override
  String get rutaEditorCursosCumplenTitulo =>
      'Courses that fulfill the objective';

  @override
  String rutaEditorCumplido(Object objetivo) {
    return '\"$objetivo\" is considered fulfilled when the student finishes 100% of ALL the selected courses.';
  }

  @override
  String get rutaEditorSinMarcados =>
      'With none selected, this objective is never completed.';

  @override
  String get rutaEditorModulos => 'Modules';

  @override
  String get rutaEditorUltimoMentoria =>
      'The last module of the phase is always the mentoring one. It is recalculated automatically when adding, removing or reordering.';

  @override
  String get rutaEditorSinModulos => 'No modules yet.';

  @override
  String get rutaEditorCursosModulo => 'Module courses';

  @override
  String get rutaEditorRenombrar => 'Rename';

  @override
  String rutaEditorEliminarModuloTexto(Object modulo, Object cantidad) {
    return 'You are about to delete \"$modulo\" with its $cantidad own lessons.';
  }

  @override
  String rutaEditorCursosCantidad(int cantidad) {
    String _temp0 = intl.Intl.pluralLogic(
      cantidad,
      locale: localeName,
      other: '$cantidad courses',
      one: '1 course',
    );
    return '$_temp0';
  }

  @override
  String rutaEditorImportados(Object cantidad) {
    return '$cantidad course objectives were added to the phase.';
  }

  @override
  String rutaEditorCursosDe(Object modulo) {
    return 'Courses of $modulo';
  }

  @override
  String get rutaEditorCursoUnModulo =>
      'A course lives in only one module of this Path: in two, its progress would be counted twice. When it is linked, its categorized objectives are added to the phase.';

  @override
  String get respaldoTitulo => 'Data and Backups';

  @override
  String get respaldoSubtitulo => 'Where the data lives and how to back it up';

  @override
  String get respaldoEstadoActual => 'Current status';

  @override
  String get respaldoRespaldo => 'Backup';

  @override
  String get respaldoDondeDatos => 'Where is the data stored?';

  @override
  String get respaldoDondeDatosTexto =>
      'The data lives in the server\'s database, not in this browser. Signing out, changing computers or signing in from another device changes nothing: everyone sees the same thing.\n\nFiles (photos, PDFs, videos) are stored separately, in object storage, and the backup does NOT include them: it saves the references, not the files.\n\nA backup does not include credentials either. Passwords and open sessions are left out on purpose: a backup is for restoring data, not for taking them away.';

  @override
  String get respaldoEntregasSinRevisar => 'Unreviewed submissions';

  @override
  String get respaldoPreparando => 'Preparing…';

  @override
  String get respaldoDescargar => 'Download backup';

  @override
  String get respaldoRestaurarArchivo => 'Restore from file';

  @override
  String get respaldoSoloComputador =>
      'Restoring a backup replaces the entire database: it can only be done from a computer.';

  @override
  String get respaldoReemplaza =>
      'Restoring replaces the entire database with the one in the file. This cannot be undone.';

  @override
  String get respaldoSoloSuper =>
      'Restoring replaces the entire database, so only a Super Admin can do it.';

  @override
  String get respaldoGuardarCopia => 'Save backup';

  @override
  String get respaldoCopiaDescargada => 'Backup downloaded ✓';

  @override
  String get respaldoSeleccioneArchivo => 'Select the backup file';

  @override
  String get respaldoRestaurarCopia => 'Restore backup';

  @override
  String respaldoRestaurarTexto(Object archivo) {
    return 'The entire database is replaced with the one in the file \"$archivo\". This cannot be undone.';
  }

  @override
  String get respaldoNoValido =>
      'That file is not a valid backup: it could not be read as JSON.';

  @override
  String get respaldoRestaurado => 'Data restored ✓';

  @override
  String get contenidoHerramienta => 'editing the home page';

  @override
  String get contenidoTitulo => 'Home Page Content';

  @override
  String get contenidoSubtitulo =>
      'Hero, banner and texts visible to the public';

  @override
  String get contenidoTituloVacio => 'The hero title cannot be empty.';

  @override
  String get contenidoActualizado => 'Home page updated ✓';

  @override
  String get contenidoImagenesPublicadas => 'Images published ✓';

  @override
  String get contenidoTituloHero => 'Hero title';

  @override
  String get contenidoSubtituloHero => 'Hero subtitle';

  @override
  String get contenidoBanner => 'Announcement banner (empty = hidden)';

  @override
  String get contenidoSobreNosotros => '\"About us\" text';

  @override
  String get contenidoLinkVideollamada => 'Video call link (mentoring modules)';

  @override
  String get contenidoLinkAyuda =>
      'A single generic link: there is no integration with a meeting provider yet.';

  @override
  String get contenidoCifras => 'Hero figures';

  @override
  String get contenidoCifrasAyuda =>
      'The four numbers under the title. They are written by hand on purpose: they are the figure the team wants to communicate, not the database count — that one lives in the dashboard.';

  @override
  String get contenidoGuardarCambios => 'Save changes';

  @override
  String get contenidoGaleria => 'Image gallery';

  @override
  String get contenidoGaleriaAyuda =>
      'They are shown on the home page, between the laboratories and the closing section. Removing one takes it off the home page immediately.';

  @override
  String get contenidoGaleriaVacia => 'There are no images in the gallery yet.';

  @override
  String get contenidoSacarImagen => 'Remove it from the home page?';

  @override
  String contenidoPublicar(Object cantidad) {
    return 'Publish $cantidad on the home page';
  }

  @override
  String respaldoNombreArchivo(Object fecha) {
    return 'enactus_backup_$fecha.json';
  }
}
