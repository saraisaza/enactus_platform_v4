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
}
