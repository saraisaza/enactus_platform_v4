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
}
