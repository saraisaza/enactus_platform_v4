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

  @override
  String get etapaValidacion => 'Validación';

  @override
  String get etapaPrototipo => 'Prototipo';

  @override
  String get etapaPiloto => 'Piloto';

  @override
  String get etapaEscalamiento => 'Escalamiento';

  @override
  String get etapaIdeacion => 'Ideación';

  @override
  String get rolLider => 'Líder';

  @override
  String get rolInvestigacion => 'Investigación';

  @override
  String get rolFinanzas => 'Finanzas';

  @override
  String get rolComunicaciones => 'Comunicaciones';

  @override
  String get rolDiseno => 'Diseño';

  @override
  String get rolOperaciones => 'Operaciones';

  @override
  String get rolIntegrante => 'Integrante';

  @override
  String get categoriaEmpresarial => 'Empresarial';

  @override
  String get categoriaEmprendimiento => 'Emprendimiento';

  @override
  String get nivelIntermedio => 'Intermedio';

  @override
  String get nivelAvanzado => 'Avanzado';

  @override
  String get nivelBasico => 'Básico';

  @override
  String get estadoPublicado => 'Publicado';

  @override
  String get estadoArchivado => 'Archivado';

  @override
  String get estadoBorrador => 'Borrador';

  @override
  String odsEtiqueta(Object numero, Object titulo) {
    return 'ODS $numero: $titulo';
  }

  @override
  String get idiomaCursoIngles => 'Inglés';

  @override
  String get idiomaCursoPortugues => 'Portugués';

  @override
  String get idiomaCursoEspanol => 'Español';

  @override
  String get tipoArchivoVideo => 'Video';

  @override
  String get tipoArchivoDocumento => 'Documento';

  @override
  String get tipoArchivoImagen => 'Imagen';

  @override
  String get calificacionAprobadoReprobado => 'Aprobado / Reprobado';

  @override
  String get calificacionSoloRevision => 'Solo revisión';

  @override
  String get calificacionEscala5 => 'Escala 0-5';

  @override
  String get calificacionPuntaje100 => 'Puntaje 0-100';

  @override
  String get calificacionPendiente => 'Pendiente';

  @override
  String get calificacionAprobado => 'Aprobado';

  @override
  String get calificacionReprobado => 'Reprobado';

  @override
  String get calificacionRevisado => 'Revisado';

  @override
  String get entregaGrupal => 'Entrega grupal';

  @override
  String get evidenciaFoto => 'Foto';

  @override
  String get evidenciaTestimonio => 'Testimonio';

  @override
  String get evidenciaReporte => 'Reporte';

  @override
  String get evidenciaHistoria => 'Historia';

  @override
  String get foroCategoriaAvance => 'Avance';

  @override
  String get foroCategoriaRecurso => 'Recurso';

  @override
  String get foroCategoriaAnuncio => 'Anuncio';

  @override
  String get foroCategoriaPregunta => 'Pregunta';

  @override
  String get eventoSesionOpenLearning => 'Sesión Open Learning';

  @override
  String get rutaDeImpacto => 'Ruta de Impacto';

  @override
  String get eventoMentoria => 'Mentoría';

  @override
  String get ods1 => 'Fin de la pobreza';

  @override
  String get ods2 => 'Hambre cero';

  @override
  String get ods3 => 'Salud y bienestar';

  @override
  String get ods4 => 'Educación de calidad';

  @override
  String get ods5 => 'Igualdad de género';

  @override
  String get ods6 => 'Agua limpia y saneamiento';

  @override
  String get ods7 => 'Energía asequible y no contaminante';

  @override
  String get ods8 => 'Trabajo decente y crecimiento económico';

  @override
  String get ods9 => 'Industria, innovación e infraestructura';

  @override
  String get ods10 => 'Reducción de las desigualdades';

  @override
  String get ods11 => 'Ciudades y comunidades sostenibles';

  @override
  String get ods12 => 'Producción y consumo responsables';

  @override
  String get ods13 => 'Acción por el clima';

  @override
  String get ods14 => 'Vida submarina';

  @override
  String get ods15 => 'Vida de ecosistemas terrestres';

  @override
  String get ods16 => 'Paz, justicia e instituciones sólidas';

  @override
  String get ods17 => 'Alianzas para lograr los objetivos';

  @override
  String get competenciaLeadership => 'Liderazgo';

  @override
  String get competenciaInnovation => 'Innovación';

  @override
  String get competenciaEntrepreneurship => 'Emprendimiento';

  @override
  String get competenciaFinance => 'Finanzas';

  @override
  String get competenciaCommunication => 'Comunicación';

  @override
  String get competenciaPitch => 'Pitch';

  @override
  String get competenciaSustainability => 'Sostenibilidad';

  @override
  String get competenciaArtificialIntelligence => 'Inteligencia Artificial';

  @override
  String get competenciaTeamwork => 'Trabajo en equipo';

  @override
  String get competenciaUserCenteredDesign => 'Diseño Centrado en el Usuario';

  @override
  String get competenciaProjectManagement => 'Gestión de Proyectos';

  @override
  String get competenciaImpactMeasurement => 'Medición de Impacto';

  @override
  String errorSubidaFallo(Object status) {
    return 'No se pudo subir el archivo ($status). Si el problema persiste, avise al equipo técnico.';
  }

  @override
  String get errorSubidaLenta =>
      'La subida tardó demasiado. Intente con una conexión más estable.';

  @override
  String get errorServidorLento => 'El servidor tardó demasiado en responder.';

  @override
  String get errorRespuestaInesperadaServidor =>
      'El servidor devolvió una respuesta inesperada.';

  @override
  String get errorDatosNoValidos => 'Los datos enviados no son válidos.';

  @override
  String get errorSesionExpirada => 'Su sesión expiró. Inicie sesión de nuevo.';

  @override
  String get errorSinPermiso => 'No tiene permiso para ver esto.';

  @override
  String get errorNoEncontrado => 'No encontramos lo que busca.';

  @override
  String get errorOperacionNoPosible =>
      'La operación no se puede hacer en este momento.';

  @override
  String get errorArchivoGrande => 'El archivo es demasiado grande.';

  @override
  String get errorDemasiadosIntentos =>
      'Demasiados intentos. Espere un momento.';

  @override
  String get errorServidorIntente =>
      'El servidor tuvo un problema. Intente de nuevo.';

  @override
  String get errorRespuestaInesperada => 'Respuesta inesperada del servidor.';

  @override
  String get certificadoTitulo => 'CERTIFICADO DE FINALIZACIÓN';

  @override
  String get certificadoSeCertifica => 'Se certifica que';

  @override
  String get certificadoCompleto =>
      'completó la Ruta de Impacto del laboratorio';

  @override
  String certificadoIntensidad(Object horas) {
    return 'Intensidad: $horas horas certificadas';
  }

  @override
  String get certificadoEmitidoPor => 'Emitido por';

  @override
  String get certificadoFechaEmision => 'Fecha de emisión';

  @override
  String certificadoCodigo(Object codigo) {
    return 'Código de verificación: $codigo';
  }

  @override
  String get certificadoPie =>
      'eduXaction Colombia · Entidad sin ánimo de lucro · Bogotá D. C.';

  @override
  String certificadoTituloVisor(Object laboratorio) {
    return 'Certificado · $laboratorio';
  }

  @override
  String certificadoArchivo(Object codigo) {
    return 'certificado_$codigo.pdf';
  }

  @override
  String get errorSubidaInterrumpida =>
      'No se pudo subir el archivo: la conexión se interrumpió.';

  @override
  String get errorSubidaTardo => 'La subida tardó demasiado.';

  @override
  String get errorSubidaCancelada => 'La subida se canceló.';

  @override
  String get errorVideoConexionNoResponde =>
      'La conexión dejó de responder mientras subía el video.';

  @override
  String get errorVideoConexionCortada =>
      'Se cortó la conexión mientras subía el video.';

  @override
  String get videoNavegadorNoAbre =>
      'Este navegador no pudo abrir el video. Puede estar dañado; vuelva a exportarlo como MP4 (H.264 con audio AAC).';

  @override
  String videoPortadaPesada(Object peso) {
    return 'La portada pesa $peso y el máximo es 5 MB.';
  }

  @override
  String videoParteRechazada(Object status) {
    return 'El almacenamiento rechazó una parte del video ($status).';
  }

  @override
  String get mp4SoloMp4 => 'Solo se aceptan videos MP4 (H.264 con audio AAC).';

  @override
  String mp4SoloMp4Ext(Object ext) {
    return 'Solo se aceptan videos MP4 (H.264 con audio AAC); este archivo es .$ext. Expórtelo como MP4 y vuelva a intentar.';
  }

  @override
  String get mp4Vacio => 'El archivo está vacío.';

  @override
  String mp4Pesado(Object peso) {
    return 'El video pesa $peso y el máximo es 500 MB. Comprímalo (por ejemplo con HandBrake, ajuste «Fast 1080p30») y vuelva a intentar.';
  }

  @override
  String get mp4Danado =>
      'No se pudo leer el MP4: el archivo está incompleto o dañado. Vuelva a exportarlo.';

  @override
  String get mp4NoEsMp4 =>
      'Este archivo no es un MP4 aunque se llame así. Expórtelo como MP4 (H.264 con audio AAC).';

  @override
  String get mp4SinIndice =>
      'No se pudo leer el MP4: le falta el índice del video, así que está incompleto o dañado. Vuelva a exportarlo.';

  @override
  String get mp4SoloAudio =>
      'Este archivo no tiene imagen: parece ser solo audio.';

  @override
  String get mp4Drm =>
      'Este video está protegido contra copia (DRM) y no se puede reproducir en la plataforma.';

  @override
  String get mp4Hevc =>
      'Este MP4 está en H.265 (HEVC), el formato con el que graba el iPhone, y muchos navegadores no lo reproducen. Expórtelo en H.264: en el iPhone, Ajustes › Cámara › Formatos › «Más compatible»; en la computadora, con HandBrake y el ajuste «Fast 1080p30».';

  @override
  String get mp4Mpeg4Parte2 => 'MPEG-4 Parte 2';

  @override
  String mp4FormatoVideo(Object nombre) {
    return 'Este MP4 usa el formato de video $nombre, que no todos los navegadores reproducen. Expórtelo en H.264 con audio AAC.';
  }

  @override
  String get mp4PcmSinComprimir => 'PCM sin comprimir';

  @override
  String mp4FormatoAudio(Object nombre) {
    return 'El audio de este MP4 está en $nombre, y no todos los navegadores lo reproducen. Expórtelo con audio AAC.';
  }

  @override
  String get errorSinSesion => 'No hay una sesión activa.';

  @override
  String get errorRespuestaInesperadaRecibida =>
      'Recibimos una respuesta inesperada del servidor.';

  @override
  String get rolSuperAdmin => 'Super Admin';

  @override
  String get rolAdministrador => 'Administrador';

  @override
  String get rolEstudiante => 'Estudiante';

  @override
  String get rolAlumni => 'Alumni';

  @override
  String get rolMentor => 'Mentor';

  @override
  String get rolAsesorAcademico => 'Asesor Académico';

  @override
  String get rolEmpresa => 'Empresa';

  @override
  String get rolDonante => 'Donante';

  @override
  String get pieInstitucional =>
      'Entidad sin ánimo de lucro. Fundada en 2021. Bogotá D. C., Colombia.';

  @override
  String get youtubeNoEsVideo =>
      'Ese enlace es de YouTube, pero no de un video (parece un canal o una lista). Abra el video y copie su enlace.';

  @override
  String get youtubePegueEnlace =>
      'Pegue el enlace de un video de YouTube, por ejemplo https://www.youtube.com/watch?v=… o https://youtu.be/…';

  @override
  String get errorSinConexion =>
      'No pudimos conectar con el servidor. Revise su conexión.';

  @override
  String get errorServidorMomento =>
      'El servidor tuvo un problema. Intente de nuevo en un momento.';
}
