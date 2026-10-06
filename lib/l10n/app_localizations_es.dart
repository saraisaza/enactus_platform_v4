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

  @override
  String get pieLema => 'Formamos líderes que transforman comunidades 💛';

  @override
  String pieDerechos(Object anio) {
    return '© $anio eduXaction Colombia — Todos los derechos reservados';
  }

  @override
  String get pieHechoEn => 'Hecho con 💛 en Bogotá';

  @override
  String get comunMenu => 'Menú';

  @override
  String get comunBuscar => 'Buscar';

  @override
  String get busquedaTipoCurso => 'Curso';

  @override
  String get busquedaTipoProyecto => 'Proyecto';

  @override
  String busquedaEtapa(Object etapa) {
    return 'Etapa: $etapa';
  }

  @override
  String get comunCerrar => 'Cerrar';

  @override
  String get busquedaPista => 'Buscar estudiantes, cursos, proyectos…';

  @override
  String get busquedaEscriba => 'Escriba para buscar';

  @override
  String get comunSinResultados => 'Sin resultados';

  @override
  String get cuentaMiCuenta => 'Mi cuenta';

  @override
  String get cuentaMiPerfil => 'Mi perfil';

  @override
  String get cuentaAcerca => 'Acerca de eduXaction';

  @override
  String get cuentaEliminar => 'Eliminar mi cuenta';

  @override
  String get notificacionesTitulo => 'Notificaciones';

  @override
  String get notificacionesVacio => 'Sin notificaciones';

  @override
  String get contactoEnviado =>
      '¡Mensaje enviado! Nos pondremos en contacto pronto.';

  @override
  String get contactoError =>
      'No pudimos enviar su mensaje. Intente de nuevo en un momento.';

  @override
  String get contactoTitulo => 'Contáctenos';

  @override
  String get contactoTexto =>
      'Cuéntenos quién es y qué le gustaría hacer con nosotros.';

  @override
  String get comunNombre => 'Nombre';

  @override
  String get comunRequerido => 'Requerido';

  @override
  String get comunCorreoInvalido => 'Correo inválido';

  @override
  String get contactoMensaje => 'Mensaje';

  @override
  String get contactoMensajePista =>
      '¿Cómo quiere sumarse? (estudiante, mentor, empresa, donante...)';

  @override
  String get comunCancelar => 'Cancelar';

  @override
  String get comunEnviando => 'Enviando…';

  @override
  String get contactoEnviar => 'Enviar mensaje';

  @override
  String get cuentaPrivacidadError =>
      'No pudimos abrir la política de privacidad. Revise su conexión e intente de nuevo.';

  @override
  String get cuentaEscribaContrasena => 'Escriba su contraseña para confirmar.';

  @override
  String get cuentaSolicitudRecibida => 'Solicitud recibida';

  @override
  String cuentaDesactivada(Object dias) {
    return 'Su cuenta quedó desactivada y se cerró la sesión en todos sus dispositivos. En un plazo máximo de $dias días borraremos sus datos personales.';
  }

  @override
  String get comunEntendido => 'Entendido';

  @override
  String get cuentaEliminando => 'Eliminando…';

  @override
  String get cuentaQuePasa => 'Esto es lo que pasa si elimina su cuenta:';

  @override
  String get cuentaPunto1 =>
      'Deja de funcionar de inmediato y se cierra la sesión en todos sus dispositivos.';

  @override
  String get cuentaPunto2 =>
      'En un plazo máximo de 30 días borramos sus datos personales: nombre, correo, teléfono, cédula, ciudad, foto y perfil.';

  @override
  String get cuentaPunto3 =>
      'Lo que publicó en el foro y sus entregas se conservan a nombre de «Cuenta eliminada», para no borrar el trabajo de su equipo.';

  @override
  String get cuentaPunto4 =>
      'Si tiene certificados, descárguelos antes: al borrar sus datos dejan de mostrar su nombre.';

  @override
  String get cuentaParaConfirmar => 'Para confirmar que es usted.';

  @override
  String cuentaAcercaTexto(Object pie) {
    return 'Formamos líderes que transforman comunidades 💛\n$pie';
  }

  @override
  String get cuentaNormas => 'Normas de la comunidad';

  @override
  String get cuentaEscribanos => 'Escríbanos';

  @override
  String get cuentaLicencias => 'Licencias de software';

  @override
  String cuentaDerechos(Object anio) {
    return '© $anio eduXaction Colombia — Todos los derechos reservados\nHecho con 💛 en Bogotá';
  }

  @override
  String get portalMas => 'Más';

  @override
  String get portalMasOpciones => 'Más opciones';

  @override
  String etapaDeTotal(Object actual, Object total) {
    return 'Etapa $actual de $total';
  }

  @override
  String get etapaFinal => 'Etapa final';

  @override
  String etapaSigue(Object etapa) {
    return 'Sigue: $etapa';
  }

  @override
  String get universidadCargando => 'Cargando universidades…';

  @override
  String get universidadFueraCatalogo => '(universidad fuera del catálogo)';

  @override
  String get universidadOtra => 'Otra (¿cuál?)';

  @override
  String get universidadCual => '¿Cuál institución?';

  @override
  String get universidadCualAyuda =>
      'El nombre oficial completo. Queda en la lista para las próximas inscripciones.';

  @override
  String get mapaNoCarga => 'No se pudo cargar el mapa';

  @override
  String get mapaCifras =>
      'Las cifras y el listado siguen disponibles a la derecha.';

  @override
  String get mapaEstudiantesPorCiudad => 'ESTUDIANTES POR CIUDAD';

  @override
  String perfilRol(Object rol) {
    return 'Rol: $rol';
  }

  @override
  String perfilCorreo(Object correo) {
    return 'Correo: $correo';
  }

  @override
  String perfilTelefono(Object telefono) {
    return 'Teléfono: $telefono';
  }

  @override
  String perfilUniversidad(Object universidad) {
    return 'Universidad: $universidad';
  }

  @override
  String get universidadEtiqueta => 'Universidad';

  @override
  String get universidadNinguna => 'Sin universidad';

  @override
  String get comunConfirmar => 'Confirmar';

  @override
  String get comunNoSeDeshace => 'Esta acción no se puede deshacer.';

  @override
  String comunEscribaParaConfirmar(Object palabra) {
    return 'Escriba $palabra para confirmar';
  }

  @override
  String get comunEliminarDefinitivamente => 'Eliminar definitivamente';

  @override
  String get formularioDescartarTitulo => 'Descartar cambios';

  @override
  String get formularioDescartarTexto =>
      'Lo que escribió en este formulario no se ha guardado. ¿Desea salir de todas formas?';

  @override
  String get escritorioTitulo => 'Mejor desde un computador';

  @override
  String escritorioTexto(Object herramienta) {
    return 'Desde el teléfono, $herramienta es difícil de usar y es fácil equivocarse: tiene listas para ordenar, tablas y formularios largos. Le recomendamos abrirlo en eduxaction.com desde un computador.';
  }

  @override
  String get escritorioContinuar => 'Continuar de todas formas';

  @override
  String get eventoSesionSincronica => 'Sesión sincrónica';

  @override
  String get eventoRutaImpacto => 'Evento Ruta de Impacto';

  @override
  String get calendarioMesAnterior => 'Mes anterior';

  @override
  String get calendarioMesSiguiente => 'Mes siguiente';

  @override
  String get calendarioAgregarEvento => 'Agregar evento';

  @override
  String get calendarioSinEventosDia => 'No hay eventos este día.';

  @override
  String get calendarioUnirse => 'Unirse a la reunión';

  @override
  String get comunEditar => 'Editar';

  @override
  String get comunEliminar => 'Eliminar';

  @override
  String get calendarioEliminarEvento => 'Eliminar evento';

  @override
  String calendarioEliminarConfirmar(Object titulo) {
    return '¿Eliminar \"$titulo\"? Esta acción no se puede deshacer.';
  }

  @override
  String get calendarioEditarEvento => 'Editar evento';

  @override
  String get comunTitulo => 'Título';

  @override
  String get calendarioTipoEvento => 'Tipo de evento';

  @override
  String get calendarioSinCursosOL =>
      'Todavía no tiene cursos de Open Learning propios. Cree uno en \"Mis Cursos\" antes de agendar una sesión.';

  @override
  String get calendarioSinLaboratorios =>
      'Todavía no tiene laboratorios asignados, así que no hay a quién agendarle una mentoría.';

  @override
  String get comunLaboratorio => 'Laboratorio';

  @override
  String get calendarioEventoGlobal =>
      'Evento global: lo verán todos los estudiantes y alumni eduXaction de la plataforma, sin importar su laboratorio.';

  @override
  String get calendarioLinkReunion => 'Link de la reunión';

  @override
  String get calendarioInvitados => 'Invitados (opcional)';

  @override
  String get calendarioInvitadosPista => 'Ej: María Pérez (Bancolombia)';

  @override
  String get comunDescripcionOpcional => 'Descripción (opcional)';

  @override
  String get calendarioRepetir => 'Repetir cada 15 días';

  @override
  String get calendarioEventoActualizado => 'Evento actualizado ✓';

  @override
  String get calendarioEventoAgregado => 'Evento agregado ✓';

  @override
  String get comunGuardando => 'Guardando…';

  @override
  String get comunGuardar => 'Guardar';

  @override
  String get archivoTipoNoPermitido =>
      'Tipo de archivo no permitido. Se aceptan PDF, imágenes, documentos de Word y ZIP.';

  @override
  String archivoPesado(Object megas) {
    return 'El archivo pesa $megas MB y el máximo son 25 MB.';
  }

  @override
  String get archivoAdjuntar => 'Adjuntar archivo';

  @override
  String get archivoArchivo => 'Archivo';

  @override
  String get archivoPreparando => 'Preparando la subida…';

  @override
  String archivoSubiendo(Object porcentaje) {
    return 'Subiendo… $porcentaje%';
  }

  @override
  String get comunQuitar => 'Quitar';

  @override
  String get archivoNoAbre => 'No se pudo abrir el archivo.';

  @override
  String get archivoNoVisible =>
      'Este tipo de archivo no se puede ver dentro de la página. Descárguelo para abrirlo.';

  @override
  String get comunDescargar => 'Descargar';

  @override
  String get archivoNoImagen => 'No se pudo mostrar la imagen.';

  @override
  String get normas1Titulo => 'Respeto ante todo';

  @override
  String get normas1Texto =>
      'Trate a las demás personas como quiere que lo traten. No se permiten insultos, burlas, acoso ni amenazas.';

  @override
  String get normas2Titulo => 'Cero discriminación';

  @override
  String get normas2Texto =>
      'No se acepta contenido que discrimine por origen, nacionalidad, género, orientación sexual, religión, discapacidad o condición social.';

  @override
  String get normas3Titulo => 'Contenido apropiado';

  @override
  String get normas3Texto =>
      'No publique contenido sexual, violento, ilegal ni nada que ponga en riesgo a otra persona.';

  @override
  String get normas4Titulo => 'Sin publicidad';

  @override
  String get normas4Texto =>
      'El foro es para aprender y construir proyectos: no publique ventas, rifas, cadenas ni publicidad.';

  @override
  String get normas5Titulo => 'Cuide los datos';

  @override
  String get normas5Texto =>
      'No comparta datos personales suyos ni de otras personas: teléfonos, direcciones, documentos o fotos de terceros.';

  @override
  String get normas6Titulo => 'Reporte lo que no está bien';

  @override
  String get normas6Texto =>
      'Si algo incumple estas normas, use «Reportar» en el menú ⋮ de la publicación. Si alguien le incomoda, puede bloquearlo y dejará de ver lo que publica.';

  @override
  String get normasConsecuencias =>
      'No hay tolerancia con el contenido ofensivo ni con el abuso. El equipo de Enactus Colombia revisa cada reporte y puede quitar el contenido y suspender la cuenta de quien incumpla estas normas.';

  @override
  String get normasAntesDePublicar =>
      'Antes de publicar por primera vez, lea y acepte las normas del foro.';

  @override
  String get normasAcepto => 'Acepto';

  @override
  String get visorAbriendo => 'Abriendo el documento…';

  @override
  String get visorNoAbre =>
      'No pudimos abrir este documento. Revise su conexión e intente de nuevo.';

  @override
  String get visorAppSistema =>
      'Este archivo se abre con la aplicación del sistema.';

  @override
  String get visorNoCarga =>
      'No se pudo cargar el visor de PDF. Recargue la página.';

  @override
  String get leccionTipoRecurso => 'Recurso';

  @override
  String get leccionTipoEnlace => 'Enlace';

  @override
  String get leccionTipoQuiz => 'Quiz';

  @override
  String get leccionTipoActividad => 'Actividad';

  @override
  String get leccionTipoEncuesta => 'Encuesta';

  @override
  String get visorDocumento => 'Documento';

  @override
  String calendarioVeces(int cantidad) {
    String _temp0 = intl.Intl.pluralLogic(
      cantidad,
      locale: localeName,
      other: '$cantidad veces',
      one: '1 vez',
    );
    return '$_temp0';
  }

  @override
  String get glosarioOcultarTexto => 'Ocultar texto y glosario';

  @override
  String get glosarioVerTexto => 'Ver texto y glosario de la lección';

  @override
  String glosarioTextoDe(Object titulo) {
    return 'Texto y glosario de «$titulo»';
  }

  @override
  String get glosarioDeLeccion => 'Glosario de esta lección';

  @override
  String get glosarioLeccionVacio =>
      'Esta lección no tiene términos de glosario.';

  @override
  String get glosarioDelModulo => 'Glosario del módulo';

  @override
  String glosarioPorRepasar(Object cantidad) {
    return '$cantidad por repasar';
  }

  @override
  String get glosarioTarjetas => 'Tarjetas';

  @override
  String get glosarioModoRepaso => 'Modo repaso';

  @override
  String get glosarioBuscar => 'Buscar en el glosario';

  @override
  String get glosarioBorrarBusqueda => 'Borrar la búsqueda';

  @override
  String glosarioNingunoCoincide(Object busqueda) {
    return 'Ningún término coincide con «$busqueda».';
  }

  @override
  String get glosarioNingunoMarcado =>
      'No tiene términos marcados para repasar.';

  @override
  String get glosarioNingunoLetra => 'Ningún término empieza con esa letra.';

  @override
  String get glosarioQuitarFiltros => 'Quitar los filtros';

  @override
  String get glosarioTodas => 'Todas';

  @override
  String get glosarioTodasLasLetras => 'Todas las letras';

  @override
  String get glosarioAyudaTarjetas =>
      'Toque una tarjeta para voltearla. El avance del repaso se guarda en la cuenta de cada estudiante.';

  @override
  String glosarioAyudaRepaso(Object sabe, Object total, Object repasar) {
    return 'Toque una tarjeta para ver la definición y marque si ya la sabe. Ya lo sabe: $sabe de $total · Por repasar: $repasar';
  }

  @override
  String glosarioYaLoSabeDe(Object sabe, Object total) {
    return 'Ya lo sabe: $sabe de $total';
  }

  @override
  String get glosarioSoloRepasar => 'Solo los de repasar';

  @override
  String get glosarioRelacionados => 'Relacionados';

  @override
  String glosarioIrA(Object palabra) {
    return 'Ir a «$palabra»';
  }

  @override
  String get glosarioEjemplo => 'Ejemplo';

  @override
  String glosarioImagenDe(Object palabra) {
    return 'Imagen de «$palabra»';
  }

  @override
  String get glosarioYaLoSabe => 'Ya lo sabe';

  @override
  String get glosarioPorRepasarEstado => 'Por repasar';

  @override
  String glosarioDefinicionDe(Object palabra, Object definicion) {
    return 'Definición de «$palabra»: $definicion';
  }

  @override
  String glosarioToqueParaVer(Object palabra) {
    return '«$palabra». Toque para ver la definición.';
  }

  @override
  String get glosarioYaLoSe => 'Ya lo sé';

  @override
  String get glosarioRepasar => 'Repasar';

  @override
  String get glosarioToqueDefinicion => 'Toque para ver la definición';

  @override
  String videoCargandoTitulo(Object titulo) {
    return 'Cargando el video «$titulo»';
  }

  @override
  String videoReproducirTitulo(Object titulo) {
    return 'Reproducir el video «$titulo»';
  }

  @override
  String videoSeguirViendo(Object titulo, Object tiempo) {
    return 'Seguir viendo «$titulo» desde $tiempo';
  }

  @override
  String get videoCargando => 'Cargando el video…';

  @override
  String videoSeguirDesde(Object tiempo) {
    return 'Seguir desde $tiempo';
  }

  @override
  String get videoNoDisponibleEntorno =>
      'La reproducción no está disponible en este entorno';

  @override
  String get videoYaNoDisponible => 'Este video ya no está disponible';

  @override
  String get videoAviseCreador => 'Avísele a quien armó el curso.';

  @override
  String get videoNoCarga => 'No se pudo cargar el video';

  @override
  String get videoPuedeSerConexion =>
      'Puede ser la conexión. Intente de nuevo en un momento.';

  @override
  String get videoPausar => 'Pausar el video';

  @override
  String get videoReproducir => 'Reproducir el video';

  @override
  String get videoCargandoCorto => 'Cargando el video';

  @override
  String get videoPosicion => 'Posición del video';

  @override
  String videoTiempoDe(Object actual, Object total) {
    return '$actual de $total';
  }

  @override
  String get videoPausarK => 'Pausar (K)';

  @override
  String get videoReproducirK => 'Reproducir (K)';

  @override
  String get videoActivarSonido => 'Activar el sonido (M)';

  @override
  String get videoSilenciar => 'Silenciar (M)';

  @override
  String get videoVolumen => 'Volumen';

  @override
  String videoMinutoDe(Object actual, Object total) {
    return 'Minuto $actual de $total';
  }

  @override
  String get videoVelocidad => 'Velocidad de reproducción';

  @override
  String get videoVelocidadNormal => 'Normal (1×)';

  @override
  String videoVelocidadActual(Object velocidad) {
    return 'Velocidad de reproducción: $velocidad';
  }

  @override
  String get videoSalirPantallaCompleta => 'Salir de pantalla completa (F)';

  @override
  String get videoPantallaCompleta => 'Pantalla completa (F)';

  @override
  String get videoVer => 'Ver el video';

  @override
  String get videoPestanaNueva => 'Se abre en una pestaña nueva.';

  @override
  String get videoAbrir => 'Abrir video';

  @override
  String get videoLeccionSinVideo => 'Esta lección todavía no tiene video';

  @override
  String get videoCreadorNoCargo => 'Quien la creó aún no le cargó ninguno.';

  @override
  String get videoEnlaceNoAbre => 'No se pudo abrir el enlace del video.';

  @override
  String get videoAvanceSeGuarda =>
      'Su avance se guarda solo: si cierra, sigue donde quedó.';

  @override
  String get videoLeccionCompletada => 'Lección completada';

  @override
  String videoVisto(Object porcentaje) {
    return 'Visto $porcentaje%';
  }

  @override
  String subidaSinTerminar(Object archivo, Object tamano) {
    return 'Quedó sin terminar la subida de «$archivo» ($tamano). Elija el mismo archivo y, al guardar, sigue desde donde iba.';
  }

  @override
  String get subidaZonaSoltar => 'Zona para soltar el video';

  @override
  String get subidaSuelte => 'Suelte el video para elegirlo';

  @override
  String get subidaReemplazar => 'Para reemplazarlo, arrastre otro video aquí';

  @override
  String get subidaArrastre => 'Arrastre el video aquí';

  @override
  String get subidaElegirVideo => 'Elegir video';

  @override
  String get subidaFormato => 'MP4 (H.264 con audio AAC) · hasta 500 MB';

  @override
  String get subidaRevisando => 'Revisando el video…';

  @override
  String get subidaElegirOtro => 'Elegir otro video';

  @override
  String get subidaVistaPreviaAsi =>
      'Vista previa — así lo verán los estudiantes:';

  @override
  String get subidaVistaPrevia => 'Vista previa';

  @override
  String get subidaVistaPreviaNavegador =>
      'La vista previa se ve en el navegador';

  @override
  String get subidaVistaPreviaDetalle =>
      'El video se sube igual; para mirarlo antes de guardar, abra el editor desde el sitio web.';

  @override
  String get subidaPortadaPropia => 'Portada propia';

  @override
  String get subidaPortadaDelVideo => 'Portada tomada del video';

  @override
  String get subidaSinPortada => 'Sin portada: se verá un fondo genérico';

  @override
  String get subidaUsarOtraImagen => 'Usar otra imagen';

  @override
  String get subidaVolverPortadaVideo => 'Volver a la del video';

  @override
  String get subidaQuitarPortada => 'Quitar la portada';

  @override
  String get subidaCambiarPortada => 'Cambiar la portada';

  @override
  String get subidaPonerPortada => 'Ponerle portada';

  @override
  String get subidaNuevaPortada => 'Nueva portada: se guarda al guardar';

  @override
  String subidaNoTermino(Object mensaje) {
    return 'No se pudo terminar la subida: $mensaje Las partes que ya llegaron no se pierden: guarde de nuevo y sigue desde donde iba.';
  }

  @override
  String subidaDe(Object enviado, Object total) {
    return '$enviado de $total';
  }

  @override
  String subidaQuedan(Object tiempo) {
    return 'quedan $tiempo';
  }

  @override
  String subidaSiguiendo(Object pct) {
    return 'Siguiendo la subida… $pct %';
  }

  @override
  String subidaSubiendo(Object pct) {
    return 'Subiendo el video… $pct %';
  }

  @override
  String get subidaCancelar => 'Cancelar subida';

  @override
  String get subidaAvance => 'Avance de la subida';

  @override
  String get subidaNoCierre => 'No cierre esta ventana hasta que termine.';

  @override
  String get youtubeNoAbre => 'No se pudo abrir YouTube.';

  @override
  String get youtubeNoCarga => 'No se pudo cargar el reproductor';

  @override
  String get youtubeNoCargaDetalle =>
      'Puede ser la conexión, o que el navegador esté bloqueando a YouTube. Puede intentar de nuevo o verlo directamente allá.';

  @override
  String get youtubeSoloYoutube => 'Este video solo se puede ver en YouTube';

  @override
  String get youtubeSoloYoutubeDetalle =>
      'Quien lo subió no permite reproducirlo fuera de YouTube.';

  @override
  String get youtubeBorrado =>
      'Lo borraron de YouTube o lo hicieron privado. Avísele a quien armó el curso.';

  @override
  String get youtubeNoValido => 'El video guardado no es válido';

  @override
  String get youtubeNoValidoDetalle =>
      'Avísele a quien armó el curso para que revise el enlace.';

  @override
  String get youtubeNoReproduce => 'YouTube no pudo reproducir el video';

  @override
  String get youtubeNoReproduceDetalle =>
      'Pruebe de nuevo, o mírelo directamente en YouTube.';

  @override
  String get youtubeVerEn => 'Ver en YouTube';

  @override
  String glosarioTerminos(int cantidad) {
    String _temp0 = intl.Intl.pluralLogic(
      cantidad,
      locale: localeName,
      other: '$cantidad términos',
      one: '1 término',
    );
    return '$_temp0';
  }

  @override
  String glosarioLetraTerminos(Object letra, int cantidad) {
    String _temp0 = intl.Intl.pluralLogic(
      cantidad,
      locale: localeName,
      other: '$cantidad términos',
      one: '1 término',
    );
    return 'Letra $letra, $_temp0';
  }

  @override
  String subidaSubidoEl(Object fecha) {
    return 'subido el $fecha';
  }

  @override
  String subidaVideoActual(Object nombre) {
    return 'Video actual: $nombre';
  }

  @override
  String get subidaArchivoSubido => 'archivo subido';

  @override
  String get portadaIniciarSesion => 'Iniciar sesión';

  @override
  String get portadaEstudiantesActivos => 'Estudiantes activos';

  @override
  String get portadaProyectosImpacto => 'Proyectos de impacto';

  @override
  String get portadaLaboratorios => 'Laboratorios';

  @override
  String get portadaUniversidadesAliadas => 'Universidades aliadas';

  @override
  String get portadaAreasConocimiento => 'Áreas de conocimiento';

  @override
  String get portadaNuestrosLaboratorios => 'Nuestros Laboratorios';

  @override
  String get portadaAreasTexto =>
      'Áreas de conocimiento donde formamos a nuestros equipos';

  @override
  String get portadaGaleria => 'Galería';

  @override
  String get portadaNuestroTrabajo => 'Nuestro trabajo en imágenes';

  @override
  String get portadaMomentos => 'Momentos de la comunidad eduXaction Colombia';

  @override
  String get portadaListo => '¿Listo para sumarse? 💛';

  @override
  String get portadaListoTexto =>
      'Sin importar si es estudiante, mentor, empresa o donante: hay un lugar para usted en eduXaction Colombia.';

  @override
  String get portadaQuieroUnirme => 'Quiero unirme';

  @override
  String get portadaExpoLugar => 'Santa Marta · julio 2026';

  @override
  String get portadaExpoTitulo => 'Campeones National Expo 2026';

  @override
  String get portadaExpoTexto =>
      'Santa Marta, julio 2026 — nuestros equipos rumbo al eduXaction World Cup en São Paulo';

  @override
  String get portadaExpoPie =>
      'Delegación eduXaction Colombia · National Expo 2026';

  @override
  String get portadaEntrar => 'Entrar a la plataforma';

  @override
  String get tabDashboard => 'Dashboard';

  @override
  String get tabInicioCorto => 'Inicio';

  @override
  String get tabCalendario => 'Calendario';

  @override
  String get tabMisCursos => 'Mis Cursos';

  @override
  String get tabCursosCorto => 'Cursos';

  @override
  String get tabLaboratorios => 'Laboratorios';

  @override
  String get tabRutaCorto => 'Ruta';

  @override
  String get tabDirectorioProyectos => 'Directorio de Proyectos';

  @override
  String get tabProyectosCorto => 'Proyectos';

  @override
  String get tabForo => 'Foro';

  @override
  String get tabCertificados => 'Certificados';

  @override
  String get tabMiPerfil => 'Mi Perfil';

  @override
  String get tabPerfilCorto => 'Perfil';

  @override
  String portalDe(Object rol) {
    return 'Portal $rol';
  }

  @override
  String get certificadosMisTitulo => 'Mis Certificados';

  @override
  String get certificadosMisSubtitulo =>
      'Certificados emitidos por sus LXD al completar una Ruta de Impacto';

  @override
  String get certificadosVacio =>
      'Aún no tiene certificados.\nComplete sus cursos para obtenerlos.';

  @override
  String certificadoRutaDe(Object laboratorio) {
    return 'Ruta de Impacto · $laboratorio';
  }

  @override
  String get certificadoVerPdf => 'Ver PDF';

  @override
  String get comunCompartir => 'Compartir';

  @override
  String perfilMiembroDesde(Object anio) {
    return 'Miembro activo desde $anio';
  }

  @override
  String get perfilMiembroComunidad => 'Miembro de la comunidad';

  @override
  String get perfilBuscarPortal => 'Buscar en el portal';

  @override
  String get perfilDatosPersonales => 'Datos personales';

  @override
  String get perfilCedula => 'Cédula';

  @override
  String get perfilTelefonoEtiqueta => 'Teléfono';

  @override
  String get perfilCorreoEtiqueta => 'Correo';

  @override
  String get perfilCiudad => 'Ciudad';

  @override
  String get perfilCarrera => 'Carrera';

  @override
  String get perfilVidaEduxaction => 'Vida eduXaction';

  @override
  String get perfilEquipo => 'Equipo';

  @override
  String get perfilEmpresaPatrocinadora => 'Empresa patrocinadora';

  @override
  String get perfilCursosActivos => 'Cursos activos';

  @override
  String get perfilLeccionesCompletadas => 'Lecciones completadas';

  @override
  String get perfilEditar => 'Editar perfil';

  @override
  String get perfilSinProyecto => 'Aún no tiene proyecto asignado.';

  @override
  String get perfilMiProyecto => 'MI PROYECTO';

  @override
  String get certificadosVacioRuta =>
      'Aún no tiene certificados. Complete una Ruta de Impacto para obtener el primero.';

  @override
  String certificadosFaltaPoco(Object nombre) {
    return 'Le falta poco para su primer certificado: \"$nombre\".';
  }

  @override
  String leccionesDeTotal(Object completadas, Object total) {
    return '$completadas de $total lecciones';
  }

  @override
  String get certificadoDescargar => 'Descargar certificado';

  @override
  String get perfilSeleccioneFoto => 'Seleccione una foto';

  @override
  String get perfilFotoFormato => 'Use una foto en JPG o PNG.';

  @override
  String get perfilFotoPesada =>
      'La foto pesa más de 25 MB. Elija una más liviana.';

  @override
  String get perfilTelefonoInvalido =>
      'Ingrese un teléfono válido (mínimo 7 dígitos).';

  @override
  String get perfilActualizado => 'Perfil actualizado ✓';

  @override
  String get perfilSubiendoFoto => 'Subiendo foto…';

  @override
  String get perfilCambiarFoto => 'Cambiar foto de perfil';

  @override
  String get perfilAsignaAdmin =>
      'Cédula, universidad, equipo, proyecto y empresa patrocinadora los asigna su administrador.';

  @override
  String certificadoEmitidoDetalle(Object fecha, Object emisor, Object codigo) {
    return 'Emitido el $fecha · Por: $emisor · Código: $codigo';
  }

  @override
  String certificadoEmitidoEl(Object fecha) {
    return 'Emitido el $fecha';
  }

  @override
  String get dashboardSinProyecto => 'Aún no tiene proyecto asignado';

  @override
  String get dashboardTodoPorEmpezar => 'Todo por empezar';

  @override
  String get dashboardSinCursos =>
      'Aún no tiene cursos asignados. Cuando su administrador le asigne uno, su progreso aparecerá aquí.';

  @override
  String get comunActualizar => 'Actualizar';

  @override
  String get dashboardProgresoGeneral => 'Progreso general';

  @override
  String get dashboardTodoCompletado =>
      'Ya completó todos sus cursos asignados.';

  @override
  String get dashboardContinueDonde => 'CONTINÚE DONDE IBA';

  @override
  String get comunContinuar => 'Continuar';

  @override
  String get dashboardProgresoPorCurso => 'Progreso por curso';

  @override
  String dashboardContinuarCurso(Object nombre) {
    return 'Continuar \"$nombre\"';
  }

  @override
  String get cursoRutaNationalExpo => 'Ruta National Expo';

  @override
  String get dashboardChecklistExpo => 'Checklist National Expo';

  @override
  String get dashboardPendientes => 'Pendientes';

  @override
  String get dashboardAlDia => '¡Está al día! No tiene pendientes.';

  @override
  String get dashboardChecklistTitulo => 'Checklist RUTA NATIONAL EXPO';

  @override
  String get dashboardActividadReciente => 'Actividad reciente';

  @override
  String get dashboardSinCalificadas => 'Aún no tiene entregas calificadas.';

  @override
  String get dashboardSuProyecto => 'Su proyecto';

  @override
  String get calendarioNoTrajo => 'No pudimos traer sus eventos.';

  @override
  String get calendarioCargando => 'Cargando sus eventos…';

  @override
  String get calendarioSubtitulo =>
      'Sesiones sincrónicas de sus cursos y eventos de su Ruta de Impacto.';

  @override
  String get calendarioProximos => 'Próximos eventos';

  @override
  String get calendarioSinProximos => 'No tiene próximos eventos.';

  @override
  String get calendarioAgendaDespejada => 'Agenda despejada';

  @override
  String get calendarioAgendaDespejadaTexto =>
      'No tiene sesiones ni entregas programadas este mes.';

  @override
  String get comunActualizado => 'Actualizado';

  @override
  String cursoHorasEstimadas(Object horas) {
    return '$horas h estimadas';
  }

  @override
  String cursoMinutosEstimados(Object minutos) {
    return '$minutos min estimados';
  }

  @override
  String get cursosAsignados => 'Cursos asignados';

  @override
  String get cursosCargando => 'Cargando sus cursos…';

  @override
  String get cursosNoTrajo => 'No pudimos traer sus cursos.';

  @override
  String get cursosSubtitulo =>
      'Cursos de laboratorio asignados por su administrador, más la ruta de preparación de su equipo para National Expo.';

  @override
  String get cursosBuscar => 'Buscar curso o laboratorio';

  @override
  String get cursosSinAsignados => 'Sin cursos asignados';

  @override
  String get cursosSinAsignadosTexto =>
      'Aún no tiene cursos asignados por su administrador.';

  @override
  String get cursosNingunoCoincide =>
      'Ningún curso coincide con su búsqueda. Pruebe con otro término.';

  @override
  String get comunLimpiarBusqueda => 'Limpiar búsqueda';

  @override
  String cursoModulos(int cantidad) {
    String _temp0 = intl.Intl.pluralLogic(
      cantidad,
      locale: localeName,
      other: '$cantidad módulos',
      one: '1 módulo',
    );
    return '$_temp0';
  }

  @override
  String cursoLecciones(int cantidad) {
    String _temp0 = intl.Intl.pluralLogic(
      cantidad,
      locale: localeName,
      other: '$cantidad lecciones',
      one: '1 lección',
    );
    return '$_temp0';
  }

  @override
  String get cursoCertificado => 'Certificado';

  @override
  String cursoProgresoDetalle(Object hechas, Object total, Object porcentaje) {
    return '$hechas de $total lecciones · $porcentaje%';
  }

  @override
  String get cursoTrabajoEquipo => 'Trabajo en equipo';

  @override
  String get comunComenzar => 'Comenzar';

  @override
  String dashboardSemanaDel(Object desde, Object hasta) {
    return 'Semana del $desde al $hasta';
  }

  @override
  String dashboardHola(Object nombre) {
    return 'Hola, $nombre';
  }

  @override
  String dashboardProyecto(Object proyecto) {
    return 'Proyecto $proyecto';
  }

  @override
  String dashboardCursosActivos(int cantidad) {
    return '$cantidad cursos activos';
  }

  @override
  String dashboardLaboratorios(int cantidad) {
    return '$cantidad laboratorios';
  }

  @override
  String dashboardFaseVencida(Object fase) {
    return 'Fase vencida: $fase';
  }

  @override
  String dashboardConfirmarMentoria(Object fase) {
    return 'Confirmar mentoría: $fase';
  }

  @override
  String get comunFase => 'Fase';

  @override
  String dashboardCalificadoEl(Object fecha) {
    return 'Calificado el $fecha';
  }

  @override
  String cursoDocente(Object docente) {
    return 'Docente: $docente';
  }

  @override
  String get cursoGeneraCertificado => 'Genera certificado';

  @override
  String get cursoObjetivos => 'Objetivos';

  @override
  String get cursoSoloLectura =>
      'Está viendo el progreso de otro estudiante — modo de solo lectura.';

  @override
  String get cursoSinContenido =>
      'Este curso todavía no tiene contenido publicado.';

  @override
  String get cursoMisEntregas => 'Mis entregas';

  @override
  String get leccionVideoYoutube => 'Video de YouTube';

  @override
  String get leccionCompletada => 'Completada';

  @override
  String get leccionMarcarPendiente => 'Marcar como pendiente';

  @override
  String get leccionMarcarCompletada => 'Marcar como completada';

  @override
  String get rutaCompletada => '¡Completó la Ruta de Impacto! 🎉';

  @override
  String get leccionCompletadaExclama => '¡Lección completada!';

  @override
  String get cursoNoPuedeResponder =>
      'Está viendo el progreso de otro estudiante — no puede responder en su nombre.';

  @override
  String get leccionSinMaterial =>
      'Esta lección todavía no tiene material cargado.';

  @override
  String get leccionSinEnlace => 'Esta lección no tiene un enlace válido.';

  @override
  String get leccionEnlaceNoAbre => 'No se pudo abrir el enlace.';

  @override
  String get quizCalificar => 'Calificar';

  @override
  String get quizCalificando => 'Calificando…';

  @override
  String get quizSinPreguntas => 'Este quiz todavía no tiene preguntas.';

  @override
  String quizAprobado(Object puntaje) {
    return '¡Aprobado! $puntaje%';
  }

  @override
  String quizPuntaje(Object puntaje) {
    return 'Puntaje: $puntaje% (mínimo 60%)';
  }

  @override
  String get quizVerdadero => 'Verdadero';

  @override
  String get quizFalso => 'Falso';

  @override
  String get quizCompleteFrase => 'Complete la frase…';

  @override
  String get quizSuRespuesta => 'Su respuesta…';

  @override
  String get quizUseFlechas => 'Use las flechas para ordenar:';

  @override
  String encuestaNombreTarea(Object leccion) {
    return 'Encuesta: $leccion';
  }

  @override
  String get encuestaGracias => '¡Gracias por responder!';

  @override
  String get comunEnviar => 'Enviar';

  @override
  String get encuestaOpinion => 'Su opinión nos ayuda a mejorar 💛';

  @override
  String get actividadArchivoObligatorio => 'Archivo obligatorio';

  @override
  String get actividadTextoObligatorio => 'Texto obligatorio';

  @override
  String get actividadRubrica => 'Rúbrica de evaluación';

  @override
  String get actividadSuEntrega => 'Su entrega';

  @override
  String actividadRetroalimentacion(Object retro) {
    return 'Retroalimentación: $retro';
  }

  @override
  String get actividadEntregar => 'Entregar actividad';

  @override
  String get actividadNuevaEntrega => 'Nueva entrega';

  @override
  String get actividadRequiereTexto =>
      'Esta actividad requiere una respuesta escrita.';

  @override
  String get actividadRequiereArchivo =>
      'Esta actividad requiere adjuntar un archivo.';

  @override
  String get actividadEntregada => 'Actividad entregada ✓';

  @override
  String actividadEntregarTitulo(Object leccion) {
    return 'Entregar: $leccion';
  }

  @override
  String get actividadRespuestaObligatoria => 'Su respuesta (obligatoria)';

  @override
  String get actividadComentarioOpcional => 'Comentario (opcional)';

  @override
  String get actividadSinEntregas =>
      'Todavía no ha realizado ninguna entrega en este curso.';

  @override
  String get actividadEntregaLibre => 'Nueva entrega libre';

  @override
  String get actividadPongaNombre => 'Póngale un nombre a la entrega.';

  @override
  String get actividadEntregaEnviada => 'Entrega enviada ✓';

  @override
  String get actividadNombreTarea => 'Nombre de la tarea';

  @override
  String get comunComentario => 'Comentario';

  @override
  String actividadLimite(Object fecha) {
    return 'Límite: $fecha';
  }

  @override
  String labsEnLaRed(Object cantidad) {
    return '$cantidad en la red';
  }

  @override
  String get labsQueEs =>
      'Un laboratorio es un área de trabajo de eduXaction Colombia: reúne una Ruta de Impacto por fases, cursos y un LXD que la acompaña. Entre al suyo para ver qué sigue.';

  @override
  String get labsSinAsignados => 'Sin laboratorios asignados';

  @override
  String get labsSinAsignadosTexto =>
      'Su administrador todavía no le ha asignado un laboratorio. Sin uno no tiene Ruta de Impacto ni cursos de área.';

  @override
  String get labsOtros => 'OTROS LABORATORIOS DE LA RED';

  @override
  String get labsSolicite =>
      'Solicite a su administrador que le asigne uno si su proyecto lo necesita.';

  @override
  String get rutaEntregaVencida => 'ENTREGA VENCIDA';

  @override
  String get rutaEnCurso => 'EN CURSO';

  @override
  String rutaFaseCompletaDe(Object total) {
    return 'Fase $total de $total completa';
  }

  @override
  String rutaFaseEnCursoDe(Object fase, Object total) {
    return 'Fase $fase de $total en curso';
  }

  @override
  String get rutaSinModulos => 'Sin módulos aún';

  @override
  String rutaModulosFraccion(Object hechos, Object total) {
    return '$hechos/$total módulos';
  }

  @override
  String rutaFases(int cantidad) {
    String _temp0 = intl.Intl.pluralLogic(
      cantidad,
      locale: localeName,
      other: '$cantidad fases',
      one: '1 fase',
    );
    return '$_temp0';
  }

  @override
  String rutaCursos(int cantidad) {
    String _temp0 = intl.Intl.pluralLogic(
      cantidad,
      locale: localeName,
      other: '$cantidad cursos',
      one: '1 curso',
    );
    return '$_temp0';
  }

  @override
  String get rutaSinLxd => 'Sin LXD asignado';

  @override
  String rutaLxd(Object nombre) {
    return 'LXD: $nombre';
  }

  @override
  String get comunEntrar => 'Entrar';

  @override
  String get rutaUnEquipo => '1 equipo en la red';

  @override
  String rutaEquipos(Object cantidad) {
    return '$cantidad equipos en la red';
  }

  @override
  String get labNoEncontrado => 'Laboratorio no encontrado';

  @override
  String get labNoEncontradoTexto =>
      'Puede que ya no exista o que el enlace esté mal escrito.';

  @override
  String get labsTodos => 'Todos los laboratorios';

  @override
  String get rutaMayus => 'RUTA DE IMPACTO';

  @override
  String get rutaFasesEnOrden =>
      'Las fases se abren en orden. Su LXD publica el contenido de cada una.';

  @override
  String get rutaSuAvance => 'Su avance';

  @override
  String rutaFaseDe(Object fase, Object total) {
    return 'Fase $fase de $total';
  }

  @override
  String rutaModulosDeTotal(Object hechos, Object total) {
    return '$hechos de $total módulos';
  }

  @override
  String get rutaFasesEnRuta => 'Fases en la ruta';

  @override
  String get rutaModulosPublicados => 'Módulos publicados';

  @override
  String get rutaCursosLab => 'Cursos del laboratorio';

  @override
  String get rutaHorasEstimadas => 'Horas estimadas';

  @override
  String get rutaSinFases =>
      'Este laboratorio todavía no tiene fases publicadas.';

  @override
  String rutaFaseNumero(Object numero) {
    return 'Fase $numero';
  }

  @override
  String get rutaEstadoCompleta => 'Completa';

  @override
  String get rutaEstadoVencida => 'Vencida';

  @override
  String get rutaEstadoDisponible => 'Disponible';

  @override
  String get rutaEstadoBloqueada => 'Bloqueada';

  @override
  String rutaSeAbreCuando(Object fase) {
    return 'Se abre cuando complete la Fase $fase';
  }

  @override
  String get rutaLxdPublicara => 'Su LXD publicará el contenido de esta fase.';

  @override
  String get rutaLxdNoPublico =>
      'Su LXD aún no ha publicado el contenido de esta fase.';

  @override
  String get rutaSinModulosPublicados => 'Sin módulos publicados';

  @override
  String get rutaEmpezarFase => 'Empezar la fase';

  @override
  String get rutaContinuarFase => 'Continuar la fase';

  @override
  String get rutaSinCursos =>
      'Este laboratorio todavía no tiene cursos publicados. Su LXD los abrirá junto con la Fase 1.';

  @override
  String get rutaSuLxd => 'Su LXD';

  @override
  String get rutaLabSinLxd =>
      'Este laboratorio todavía no tiene un LXD asignado.';

  @override
  String get rutaLxdNombreLargo => 'Learning Experience Designer';

  @override
  String get rutaSinHorario => 'Sin horario publicado';

  @override
  String get rutaAgendarMentoria => 'Agendar mentoría';

  @override
  String get rutaLxdSinDisponibilidad =>
      'Su LXD todavía no publicó su disponibilidad.';

  @override
  String rutaDisponibilidadDe(Object nombre) {
    return 'Disponibilidad de $nombre';
  }

  @override
  String rutaEscribale(Object nombre) {
    return 'Escríbale para coordinar el horario exacto de $nombre.';
  }

  @override
  String get rutaEscribirCorreo => 'Escribir correo';

  @override
  String get rutaSubtitulo =>
      'Las fases de su laboratorio, sus objetivos y lo que falta para llegar a National Expo.';

  @override
  String get rutaSinLab => 'Sin laboratorio asignado';

  @override
  String get rutaSinLabTexto =>
      'Su administrador aún no le ha asignado ningún laboratorio.';

  @override
  String get rutaLabSinFases => 'Laboratorio sin fases';

  @override
  String rutaLabSinFasesTexto(Object laboratorio) {
    return 'El $laboratorio todavía no ha publicado sus fases. Su LXD las abrirá cuando el contenido esté listo.';
  }

  @override
  String get rutaVerOtroLab => 'Ver otro laboratorio';

  @override
  String get rutaEstadoSinAbrir => 'Sin abrir';

  @override
  String get rutaEstadoEnCurso => 'En curso';

  @override
  String rutaModuloNumero(Object numero) {
    return 'Módulo $numero';
  }

  @override
  String rutaCompleteAnterior(Object modulo) {
    return 'Complete el módulo anterior para desbloquear \"$modulo\".';
  }

  @override
  String get rutaBloqueado => 'Bloqueado';

  @override
  String get rutaModuloMentoria => 'Módulo de mentoría';

  @override
  String get rutaSinContenido => 'Sin contenido aún';

  @override
  String rutaElementos(int cantidad) {
    return '$cantidad elemento(s)';
  }

  @override
  String get rutaCompleto => 'Completo';

  @override
  String get rutaMetaAnio => 'META DEL AÑO';

  @override
  String get rutaSinEquipo => 'Aún no pertenece a un equipo.';

  @override
  String get rutaChecklistEquipo => 'Checklist del equipo';

  @override
  String get rutaModulo => 'Módulo';

  @override
  String get rutaModuloNoExiste =>
      'Este módulo ya no existe o el enlace está mal escrito.';

  @override
  String get rutaEntregasLecturas => 'Entregas y lecturas';

  @override
  String get rutaModuloSinContenido =>
      'Su administrador aún no agregó contenido a este módulo.';

  @override
  String get rutaEstaFase => 'esta fase';

  @override
  String rutaReunase(Object fase) {
    return 'Reúnase con su mentor para cerrar $fase.';
  }

  @override
  String get rutaSinEnlaceReunion =>
      'Su administrador todavía no configuró el enlace de la reunión.';

  @override
  String get rutaEntrega => 'Entrega';

  @override
  String get rutaLecturaSinMaterial =>
      'Esta lectura todavía no tiene material.';

  @override
  String labsAsignadosEnRed(int asignados, Object total) {
    String _temp0 = intl.Intl.pluralLogic(
      asignados,
      locale: localeName,
      other: '$asignados laboratorios asignados',
      one: '1 laboratorio asignado',
    );
    return '$_temp0 · $total en la red';
  }

  @override
  String rutaFechaPrevista(Object fecha) {
    return 'Fecha prevista por el laboratorio: $fecha';
  }

  @override
  String rutaEntregaVencidaEl(Object fecha) {
    return 'Entrega vencida: $fecha';
  }

  @override
  String rutaEntregaEl(Object fecha) {
    return 'Entrega: $fecha';
  }

  @override
  String rutaAsuntoMentoria(Object laboratorio) {
    return 'Mentoría - $laboratorio';
  }
}
