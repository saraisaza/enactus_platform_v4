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
}
