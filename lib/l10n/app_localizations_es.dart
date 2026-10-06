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

  @override
  String foroHaceMin(Object minutos) {
    return 'hace $minutos min';
  }

  @override
  String foroHaceHoras(Object horas) {
    return 'hace $horas h';
  }

  @override
  String foroHaceDias(Object dias) {
    return 'hace $dias días';
  }

  @override
  String get foroComunidad => 'Comunidad';

  @override
  String get foroTitulo => 'Foro de la Comunidad';

  @override
  String get foroNoAbre => 'No pudimos abrir el foro.';

  @override
  String get foroCargando => 'Cargando publicaciones…';

  @override
  String get foroSubtitulo =>
      'Pregunte, comparta avances y encuentre a quién ya resolvió lo que usted está resolviendo. Escriben estudiantes, mentores y LXD de toda la red.';

  @override
  String get foroBuscar => 'Buscar autor, organización o contenido';

  @override
  String get foroNadie => 'Nadie ha escrito aún';

  @override
  String get foroVacio =>
      'El foro está vacío. Puede ser la primera persona en abrir la conversación de la comunidad.';

  @override
  String get foroSinCoincidencias =>
      'Ninguna publicación coincide con este filtro. Pruebe con otra categoría o limpie la búsqueda.';

  @override
  String get foroVerTodo => 'Ver todo el foro';

  @override
  String get foroTodo => 'Todo';

  @override
  String get foroQueCompartir => '¿Qué quiere compartir con la comunidad?';

  @override
  String get foroPublicando => 'Publicando…';

  @override
  String get foroPublicar => 'Publicar';

  @override
  String get foroUsuarioEliminado => 'Usuario eliminado';

  @override
  String get foroMasAcciones => 'Más acciones';

  @override
  String get foroEliminarPublicacion => 'Eliminar publicación';

  @override
  String get foroEliminarPublicacionTexto =>
      '¿Eliminar esta publicación del foro? Esta acción no se puede deshacer.';

  @override
  String get foroDesfijar => 'Desfijar';

  @override
  String get foroFijar => 'Fijar anuncio';

  @override
  String get foroReportar => 'Reportar';

  @override
  String foroBloquearA(Object nombre) {
    return 'Bloquear a $nombre';
  }

  @override
  String get foroResponder => 'Responder…';

  @override
  String foroVerRespuestas(Object total) {
    return 'Ver las $total respuestas';
  }

  @override
  String get foroEliminarRespuesta => 'Eliminar respuesta';

  @override
  String get foroEliminarRespuestaTexto =>
      '¿Eliminar esta respuesta del foro? Esta acción no se puede deshacer.';

  @override
  String get foroRegla1 =>
      'Respete a los demás equipos y comparta con la misma apertura con la que le gustaría recibir ayuda.';

  @override
  String get foroRegla2 =>
      'Publique contenido real de su proyecto: evidencias y preguntas concretas ayudan más que mensajes genéricos.';

  @override
  String get foroRegla3 =>
      'Es un espacio de toda la red: preguntas de cualquier laboratorio o universidad son bienvenidas.';

  @override
  String get foroNormas => 'Normas del foro';

  @override
  String get foroNormasCompletas => 'Normas completas';

  @override
  String get foroPersonasBloqueadas => 'Personas bloqueadas';

  @override
  String get foroReportes => 'Reportes del foro';

  @override
  String get foroRevisar => 'Revisar';

  @override
  String get foroEquiposActivos => 'Equipos más activos';

  @override
  String get reporteMotivoOfensivo => 'Es ofensivo o irrespetuoso';

  @override
  String get reporteMotivoAcoso => 'Es acoso o intimidación';

  @override
  String get reporteMotivoDiscrimina => 'Discrimina a alguien';

  @override
  String get reporteMotivoSpam => 'Es spam o publicidad';

  @override
  String get reporteMotivoDatos => 'Comparte datos personales';

  @override
  String get reporteMotivoOtro => 'Otro motivo';

  @override
  String get reporteGracias =>
      'Gracias. El equipo de Enactus revisará este contenido.';

  @override
  String get reporteYaReportado =>
      'Ya lo había reportado; el equipo lo tiene en su lista.';

  @override
  String get reporteRespuesta => 'Reportar respuesta';

  @override
  String get reportePublicacion => 'Reportar publicación';

  @override
  String get reportePorQue =>
      '¿Por qué lo reporta? Solo el equipo de Enactus verá quién lo reportó.';

  @override
  String reporteBloquearTambien(Object nombre) {
    return 'Bloquear también a $nombre';
  }

  @override
  String get reporteDejaraDeVer => 'Dejará de ver lo que publica.';

  @override
  String bloqueoTexto(Object nombre) {
    return 'Dejará de ver lo que $nombre publica y responde en el foro. No se le avisará. Puede desbloquearle cuando quiera desde «Personas bloqueadas», en las normas del foro.';
  }

  @override
  String bloqueoHecho(Object nombre) {
    return 'Bloqueó a $nombre.';
  }

  @override
  String get bloqueoNadie => 'No ha bloqueado a nadie.';

  @override
  String get bloqueoDesbloquear => 'Desbloquear';

  @override
  String get reportesNinguno => 'No hay reportes pendientes.';

  @override
  String get reporteQuitarRespuesta => 'Quitar respuesta';

  @override
  String get reporteQuitarPublicacion => 'Quitar publicación';

  @override
  String get reporteQuitarTexto =>
      'Se quitará del foro para todas las personas. No se puede deshacer.';

  @override
  String get reporteTipoPublicacion => 'PUBLICACIÓN';

  @override
  String get reporteYaNoSeVe => '· ya no se ve en el foro';

  @override
  String get reporteSinMotivo => 'Sin motivo';

  @override
  String reporteReporto(Object nombre, Object fecha) {
    return 'Reportó $nombre · $fecha';
  }

  @override
  String get reporteCerrar => 'Cerrar reporte';

  @override
  String get reporteDejarlo => 'Dejarlo';

  @override
  String get reporteQuitarDelForo => 'Quitar del foro';

  @override
  String get foroAhora => 'ahora';

  @override
  String get foroAyer => 'ayer';

  @override
  String foroPersonasActivas(int cantidad) {
    String _temp0 = intl.Intl.pluralLogic(
      cantidad,
      locale: localeName,
      other: '$cantidad personas activas esta semana',
      one: '1 persona activa esta semana',
    );
    return '$_temp0';
  }

  @override
  String foroRespuestas(int cantidad) {
    String _temp0 = intl.Intl.pluralLogic(
      cantidad,
      locale: localeName,
      other: '$cantidad respuestas',
      one: '1 respuesta',
    );
    return '$_temp0';
  }

  @override
  String foroReportesSinAtender(int cantidad) {
    String _temp0 = intl.Intl.pluralLogic(
      cantidad,
      locale: localeName,
      other: 'Hay $cantidad reportes sin atender.',
      one: 'Hay 1 reporte sin atender.',
    );
    return '$_temp0';
  }

  @override
  String foroPublicaciones(int cantidad) {
    String _temp0 = intl.Intl.pluralLogic(
      cantidad,
      locale: localeName,
      other: '$cantidad publicaciones',
      one: '1 publicación',
    );
    return '$_temp0';
  }

  @override
  String get reporteTipoRespuesta => 'RESPUESTA';

  @override
  String get proyectosComunidad => 'Comunidad eduXaction Colombia';

  @override
  String get proyectosSubtitulo =>
      'Todos los proyectos activos de la red. Filtre por etapa, explore los ODS que atienden y descubra qué está construyendo el resto de los equipos.';

  @override
  String get proyectosBuscar => 'Buscar proyecto, comunidad u ODS';

  @override
  String get proyectosTodasEtapas => 'Todas las etapas';

  @override
  String get proyectosVacio => 'Aún no hay proyectos aquí';

  @override
  String get proyectosVacioTexto =>
      'Todavía no se ha publicado ningún proyecto en la comunidad. Cuando su equipo registre el suyo, aparecerá aquí para toda la red.';

  @override
  String get proyectosSinCoincidencias =>
      'Ningún proyecto coincide con este filtro. Pruebe con otra etapa o limpie la búsqueda.';

  @override
  String get proyectosVerTodasEtapas => 'Ver todas las etapas';

  @override
  String get proyectosProponer => 'Proponer un proyecto';

  @override
  String get proyectosSinEquipo => 'Sin equipo asignado todavía.';

  @override
  String get proyectosFechaNoRegistrada => 'Fecha no registrada';

  @override
  String get proyectosProblema => 'Problema';

  @override
  String get proyectosSolucion => 'Solución';

  @override
  String get proyectosIndicadores => 'Indicadores de impacto';

  @override
  String get temaClaro => 'Claro';

  @override
  String get temaOscuro => 'Oscuro';

  @override
  String proyectosAsesor(Object nombre) {
    return 'Asesor académico: $nombre';
  }

  @override
  String get proyectosSinIntegrantes => 'Sin integrantes asignados.';

  @override
  String get proyectosUniversidadSinDefinir => 'Universidad sin definir';

  @override
  String get proyectosActivos => 'Proyectos activos';

  @override
  String get proyectosUniversidades => 'Universidades';

  @override
  String get proyectosOdsCubiertos => 'ODS cubiertos';

  @override
  String get proyectosEnExpo => 'En National Expo';

  @override
  String labEstudiantesAsignados(Object cantidad) {
    return '$cantidad estudiante(s) asignado(s)';
  }

  @override
  String get labMentores => 'Mentores';

  @override
  String get labSinModulos => 'Sin módulos publicados todavía.';

  @override
  String get labBloqueadaAnterior => 'Bloqueada — complete la fase anterior';

  @override
  String get labPorVencer => 'Por vencer';

  @override
  String get labSinEstudiantes => 'Sin estudiantes';

  @override
  String labCompletaron(Object hechos, Object total) {
    return '$hechos/$total completaron';
  }

  @override
  String get usuarioEquipoProyecto => 'Equipo y proyecto';

  @override
  String get usuarioAvanceRuta => 'Avance en la Ruta de Impacto';

  @override
  String get usuarioSinCertificados => 'Todavía sin certificados.';

  @override
  String get usuarioSinLaboratorios => 'Sin laboratorios asignados.';

  @override
  String get usuarioEmpresaTexto =>
      'Sus LXD y mentores aparecen en su propio portal.';

  @override
  String usuarioCodigoImpacto(Object codigo) {
    return 'Código de impacto: $codigo';
  }

  @override
  String get usuarioDonanteTexto =>
      'Sus estudiantes y evidencias aparecen en su propio portal.';

  @override
  String get usuarioAsesor => 'Asesor académico';

  @override
  String usuarioAcompana(Object universidad) {
    return 'Acompaña a los equipos de $universidad.';
  }

  @override
  String get usuarioCursosCreados => 'Cursos creados';

  @override
  String get usuarioSinCursos => 'Aún no ha creado ningún curso.';

  @override
  String get usuarioLabsAcompana => 'Laboratorios que acompaña';

  @override
  String get usuarioSinLab => 'Todavía sin laboratorio asignado.';

  @override
  String usuarioEstudiantes(Object cantidad) {
    return '$cantidad estudiantes';
  }

  @override
  String usuarioEntregasRevisadas(Object cantidad) {
    return '$cantidad entregas revisadas.';
  }

  @override
  String comunEstudiantes(int cantidad) {
    String _temp0 = intl.Intl.pluralLogic(
      cantidad,
      locale: localeName,
      other: '$cantidad estudiantes',
      one: '1 estudiante',
    );
    return '$_temp0';
  }

  @override
  String proyectosEstudiantesAlcance(int cantidad) {
    String _temp0 = intl.Intl.pluralLogic(
      cantidad,
      locale: localeName,
      other: '$cantidad estudiantes en su alcance',
      one: '1 estudiante en su alcance',
    );
    return '$_temp0';
  }

  @override
  String proyectosCreadoEl(Object fecha) {
    return 'Creado el $fecha';
  }

  @override
  String labFechaLimite(Object fecha) {
    return 'Fecha límite: $fecha';
  }

  @override
  String usuarioCalificaEn(Object contextos) {
    return 'Califica en: $contextos';
  }

  @override
  String get usuarioNingunContexto => 'ningún contexto';

  @override
  String get mapaEstudiantesRegistrados => 'Estudiantes registrados';

  @override
  String get mapaCiudades => 'Ciudades';

  @override
  String get mapaDepartamentos => 'Departamentos';

  @override
  String get mapaRedNacional => 'Red nacional · actualizado hoy';

  @override
  String get mapaPatrocina => 'Estudiantes que patrocina su organización';

  @override
  String get mapaEstudiantesPais => 'Estudiantes en el país';

  @override
  String get mapaTexto =>
      'Dónde están los estudiantes registrados en eduXaction Colombia. Cada punto es una ciudad con al menos una universidad activa en la red.';

  @override
  String get mapaSufijoPatrocina => 'estudiantes que patrocina';

  @override
  String get mapaOrdenadas => 'Ordenadas por número de estudiantes';

  @override
  String get mapaSoloVinculados =>
      'Solo los estudiantes vinculados a su aporte';

  @override
  String get mapaPortalAliados => 'Portal de aliados · eduXaction Colombia';

  @override
  String get mapaGeometria => 'Geometría: Natural Earth (dominio público)';

  @override
  String get mapaDosOMas => '2 o más estudiantes';

  @override
  String get mapaUnEstudiante => '1 estudiante';

  @override
  String mapaEntre(Object desde, Object hasta) {
    return 'Entre $desde y $hasta';
  }

  @override
  String mapaOMas(Object cantidad) {
    return '$cantidad o más estudiantes';
  }

  @override
  String mapaMenosDe(Object cantidad) {
    return 'Menos de $cantidad';
  }

  @override
  String get mapaTodaLaRed => 'Toda la red';

  @override
  String get mapaLosQuePatrocino => 'Los que patrocino';

  @override
  String get mapaTema => 'Tema';

  @override
  String get mapaSinVinculados => 'Aún no hay estudiantes vinculados';

  @override
  String get mapaSinVinculadosTexto =>
      'Todavía no hay estudiantes vinculados a su aporte. En cuanto su administrador asigne alguno, aparecerá aquí en el mapa.';

  @override
  String get mapaEscribirAdmin => 'Escribir a mi administrador';

  @override
  String get mapaSolicitudTitulo => 'Solicitud de estudiantes patrocinados';

  @override
  String get mapaSolicitudTexto =>
      'Un aliado pidió que le asignen estudiantes a su aporte.';

  @override
  String get mapaAvisamos => 'Le avisamos a su administrador.';

  @override
  String get mapaSinCiudades => 'Sin ciudades para este alcance todavía.';

  @override
  String get mapaCiudadExplica =>
      'La ciudad es la que el estudiante (o su administrador) eligió en su perfil. Los estudiantes sin ciudad asignada todavía no aparecen en el mapa.';

  @override
  String get talentoTitulo => 'BuscaTalento';

  @override
  String get talentoSubtitulo =>
      'Estudiantes eduXaction que ya demostraron sus habilidades en la Ruta de Impacto — contáctelos para oportunidades futuras 💛';

  @override
  String get talentoVacio =>
      'Todavía no hay estudiantes eduXaction en la plataforma.';

  @override
  String get talentoTop => 'Top talento';

  @override
  String talentoAvance(Object porcentaje) {
    return '$porcentaje% de avance';
  }

  @override
  String talentoObjetivosEmprendimiento(Object cantidad) {
    return '$cantidad objetivos de emprendimiento';
  }

  @override
  String talentoObjetivosEmpresariales(Object cantidad) {
    return '$cantidad objetivos empresariales';
  }

  @override
  String talentoCertificados(Object cantidad) {
    return '$cantidad certificados';
  }

  @override
  String get talentoContactar => 'Contactar';

  @override
  String get talentoOportunidad => 'Una oportunidad para usted';

  @override
  String get talentoNecesitaTitulo => 'El aviso necesita un título.';

  @override
  String get talentoMensajeEnviado => 'Mensaje enviado ✓';

  @override
  String talentoContactarA(Object nombre) {
    return 'Contactar a $nombre';
  }

  @override
  String get talentoMensajeLlega =>
      'El mensaje llega a su bandeja dentro de la plataforma. No se entrega ningún dato de contacto.';

  @override
  String get talentoAsunto => 'Asunto';

  @override
  String get recursosTitulo => 'Recursos de Comunicaciones';

  @override
  String get recursosSubtitulo =>
      'Plantillas, guías de marca y material para el equipo';

  @override
  String get recursosNuevo => 'Nuevo recurso';

  @override
  String get recursosVacio => 'Todavía no hay recursos publicados.';

  @override
  String get recursosEliminar => 'Eliminar recurso';

  @override
  String recursosEliminarTexto(Object titulo) {
    return '¿Eliminar \"$titulo\"?';
  }

  @override
  String get recursosNecesitaTitulo => 'El recurso necesita un título.';

  @override
  String get recursosFaltaArchivo => 'Falta subir el archivo.';

  @override
  String get recursosFaltaUrl => 'Falta la URL.';

  @override
  String get recursosPublicado => 'Recurso publicado ✓';

  @override
  String get comunDescripcion => 'Descripción';

  @override
  String get mapaSufijoEstudiantes => 'estudiantes';

  @override
  String get lxdPortal => 'Portal LXD';

  @override
  String get tabMisEstudiantes => 'Mis Estudiantes';

  @override
  String get tabEstudiantesCorto => 'Estudiantes';

  @override
  String get tabCalificaciones => 'Calificaciones';

  @override
  String get tabCalificarCorto => 'Calificar';

  @override
  String get tabCertificaciones => 'Certificaciones';

  @override
  String get lxdEstudiantesSubtitulo =>
      'Estudiantes inscritos en cursos que usted creó';

  @override
  String get lxdFiltrarNombre => 'Filtrar por nombre o institución';

  @override
  String get lxdSinEstudiantes => 'No hay estudiantes inscritos en sus cursos.';

  @override
  String get comunEstudiante => 'Estudiante';

  @override
  String get comunEtapa => 'Etapa';

  @override
  String get lxdNecesidad => 'Necesidad';

  @override
  String get comunInstitucion => 'Institución';

  @override
  String get comunProgreso => 'Progreso';

  @override
  String get lxdPromedioCursos => 'Promedio de todos sus cursos';

  @override
  String get lxdAcompanamientoUrgente => 'Acompañamiento urgente';

  @override
  String get lxdSeguimientoRegular => 'Seguimiento regular';

  @override
  String get lxdAutonomo => 'Autónomo';

  @override
  String lxdResumenAvance(Object porcentaje) {
    return 'Avance: $porcentaje%';
  }

  @override
  String lxdResumenEmpresa(Object empresa) {
    return 'Empresa: $empresa';
  }

  @override
  String get lxdProyectosSubtitulo =>
      'Equipos y avance en la Ruta de Impacto de sus estudiantes';

  @override
  String get lxdSinProyectos =>
      'Ninguno de sus estudiantes tiene proyecto asignado todavía.';

  @override
  String get lxdCalendarioSubtitulo =>
      'Agende las sesiones sincrónicas de sus cursos Open Learning';

  @override
  String get lxdCursosSubtitulo =>
      'Cursos que usted creó — eduXaction (asignados o no a un laboratorio) y Open Learning';

  @override
  String get lxdNuevoCurso => 'Nuevo curso';

  @override
  String get lxdSinCursos => 'Aún no ha creado ningún curso. Cree el primero.';

  @override
  String get lxdNombreCurso => 'Póngale un nombre al curso.';

  @override
  String get lxdNombreDelCurso => 'Nombre del curso';

  @override
  String get lxdCursoOpenLearning => 'Curso de Open Learning';

  @override
  String get lxdCursoOpenLearningTexto =>
      'Se asigna directo a estudiantes externos, sin laboratorio ni Ruta de Impacto';

  @override
  String get lxdLabsNoCargan =>
      'No se pudieron cargar los laboratorios. Puede asignarlo después desde el constructor.';

  @override
  String get lxdLaboratorioOpcional => 'Laboratorio (opcional)';

  @override
  String get lxdSinAsignarAun => 'Sin asignar por ahora';

  @override
  String get comunCreando => 'Creando…';

  @override
  String get lxdCrearAbrir => 'Crear y abrir constructor';

  @override
  String lxdInscritos(Object cantidad) {
    return '$cantidad inscritos';
  }

  @override
  String lxdCompletados(Object cantidad) {
    return '$cantidad completados';
  }

  @override
  String lxdAvance(Object porcentaje) {
    return '$porcentaje% avance';
  }

  @override
  String get lxdSinNotas => 'Sin notas';

  @override
  String lxdPromedio(Object nota) {
    return 'Promedio $nota';
  }

  @override
  String lxdPendientes(Object cantidad) {
    return '$cantidad pendientes';
  }

  @override
  String get lxdSinVincular => 'Sin vincular a ningún módulo todavía';

  @override
  String lxdVinculadoA(Object modulo) {
    return 'Vinculado a: $modulo';
  }

  @override
  String get lxdConstructor => 'Constructor';

  @override
  String get lxdSeguimiento => 'Seguimiento';

  @override
  String get lxdEliminarCurso => 'Eliminar curso';

  @override
  String lxdEliminarCursoTexto(Object nombre) {
    return 'Va a eliminar \"$nombre\" con todos sus módulos, lecciones y configuración.';
  }

  @override
  String get lxdCursoEliminado => 'Curso eliminado';

  @override
  String get lxdCalificacionesSubtitulo =>
      'Entregas de estudiantes en sus cursos';

  @override
  String get lxdSinPermisoCalificar =>
      'Su Admin no le ha dado permiso de calificar todavía';

  @override
  String get lxdSinEntregas => 'No hay entregas para calificar.';

  @override
  String get calificarElija => 'Elija aprobado o reprobado.';

  @override
  String get calificarPuntajeRango => 'El puntaje va de 0 a 100.';

  @override
  String get calificarNotaRango => 'La nota va de 0.0 a 5.0.';

  @override
  String get calificarEntregaCalificada => 'Entrega calificada ✓';

  @override
  String calificarTitulo(Object tarea) {
    return 'Calificar: $tarea';
  }

  @override
  String get calificarEscala => 'Escala de calificación';

  @override
  String get calificarResultado => 'Resultado:';

  @override
  String get calificarSoloRevision =>
      'Esta actividad es de solo revisión: deja su retroalimentación sin nota.';

  @override
  String get calificarPuntaje => 'Puntaje (0 - 100)';

  @override
  String get calificarNota => 'Nota (0.0 - 5.0)';

  @override
  String get calificarRetroalimentacion => 'Retroalimentación';

  @override
  String certificadoEmitido(Object codigo) {
    return 'Certificado $codigo emitido 🏆';
  }

  @override
  String get certificacionesSubtitulo =>
      'El certificado se emite al completar la Ruta de Impacto completa de un laboratorio (ya no hay certificado por curso)';

  @override
  String get certificacionesSinPermiso =>
      'Su Admin no le ha dado permiso de calificar en eduXaction: no puede emitir certificados todavía';

  @override
  String get certificacionesEmitidos => 'Certificados emitidos';

  @override
  String get certificacionesVacio => 'Aún no se han emitido certificados.';

  @override
  String get certificacionesEmitirNuevo => 'Emitir nuevo certificado';

  @override
  String get certificacionesLabRuta => 'Laboratorio (Ruta completa)';

  @override
  String get certificacionesEmitiendo => 'Emitiendo…';

  @override
  String get certificacionesEmitir => 'Emitir';

  @override
  String get certificacionesComprobando => 'Comprobando su Ruta de Impacto…';

  @override
  String get certificacionesNoCompleto =>
      'Este estudiante aún no completó la Ruta de Impacto de ningún laboratorio';

  @override
  String get lxdPerfilSubtitulo =>
      'Información visible para administradores y estudiantes';

  @override
  String get lxdPermisoOL => 'Permiso de calificar · Open Learning';

  @override
  String get comunActivado => 'Activado';

  @override
  String get comunDesactivado => 'Desactivado';

  @override
  String get lxdPermisoEduxaction => 'Permiso de calificar · eduXaction';

  @override
  String get perfilCargo => 'Cargo';

  @override
  String get perfilEspecialidad => 'Especialidad';

  @override
  String get perfilIdiomas => 'Idiomas';

  @override
  String get perfilDisponibilidad => 'Disponibilidad';

  @override
  String get perfilExperiencia => 'Experiencia';

  @override
  String get perfilIntereses => 'Intereses';

  @override
  String lxdResumenProyecto(Object proyecto) {
    return 'Proyecto: $proyecto';
  }

  @override
  String certificadoLinea(
    Object estudiante,
    Object laboratorio,
    Object codigo,
  ) {
    return '$estudiante · Ruta de Impacto $laboratorio · $codigo';
  }

  @override
  String get constructorInfoGeneral => 'Información general';

  @override
  String get constructorCategorizacion => 'Categorización y objetivos';

  @override
  String get constructorDelCurso => 'Constructor del curso';

  @override
  String get constructorEvaluacion => 'Evaluación y certificado';

  @override
  String get constructorRestricciones => 'Restricciones y patrocinio';

  @override
  String get constructorTitulo => 'Constructor de Curso';

  @override
  String get comunVolver => 'Volver';

  @override
  String get constructorHerramienta => 'el constructor de módulos y lecciones';

  @override
  String get constructorNecesitaNombre => 'El curso necesita un nombre.';

  @override
  String get constructorGuardado => 'Curso guardado ✓';

  @override
  String get constructorSubtitulo => 'Subtítulo';

  @override
  String get constructorDescCorta => 'Descripción corta';

  @override
  String get constructorDescCompleta => 'Descripción completa';

  @override
  String get constructorPortada => 'Imagen de portada';

  @override
  String get constructorYaPortada =>
      'Ya tiene portada. Subir otra la reemplaza.';

  @override
  String get constructorNivel => 'Nivel';

  @override
  String get constructorDuracion => 'Duración estimada (horas)';

  @override
  String get constructorIdioma => 'Idioma';

  @override
  String get constructorEstado => 'Estado: ';

  @override
  String get constructorPublicar => 'Publicar';

  @override
  String get constructorArchivar => 'Archivar';

  @override
  String get constructorArchivarCurso => 'Archivar curso';

  @override
  String get constructorArchivarTexto =>
      'Deja de asignarse a estudiantes nuevos, pero quienes ya tienen avance no se bloquean.';

  @override
  String get constructorLeccionesCompletar => 'Lecciones a completar:';

  @override
  String get constructorCategorizacionGuardada => 'Categorización guardada ✓';

  @override
  String get constructorSinLab => 'Sin laboratorio (curso especial)';

  @override
  String get constructorEtiquetas => 'Etiquetas';

  @override
  String get constructorCompetencias =>
      'Competencias que desarrolla (métricas de impacto)';

  @override
  String get constructorOdsRelacionados => 'ODS relacionados';

  @override
  String get constructorObjetivosCurso => 'Objetivos del curso';

  @override
  String get constructorObjetivosPista =>
      'p. ej. Comprender los fundamentos de la IA aplicada';

  @override
  String get constructorObjetivosRuta => 'Objetivos para la Ruta de Impacto';

  @override
  String get constructorObjetivosRutaTexto =>
      'Si este curso se vincula a un módulo de un laboratorio, estos objetivos se agregan automáticamente a los de esa fase.';

  @override
  String get constructorObjetivosEmprendimiento =>
      'Objetivos de Emprendimiento';

  @override
  String get constructorObjetivosEmprendimientoPista =>
      'p. ej. Identificar oportunidades de IA en proyectos sociales';

  @override
  String get constructorObjetivosEmpresariales => 'Objetivos Empresariales';

  @override
  String get constructorObjetivosEmpresarialesPista =>
      'p. ej. Comprender los fundamentos del aprendizaje automático';

  @override
  String get constructorResultados => 'Resultados de aprendizaje';

  @override
  String get constructorResultadosPista =>
      'p. ej. Construye un prototipo con datos reales';

  @override
  String get constructorPrerrequisitos => 'Prerrequisitos';

  @override
  String get constructorPrerrequisitosTexto =>
      'Cursos que el estudiante debería completar antes (o ninguno).';

  @override
  String get constructorSinOtrosCursos => 'No hay otros cursos disponibles.';

  @override
  String get constructorNuevoModulo => 'Nuevo módulo';

  @override
  String get constructorTituloModulo => 'Título del módulo';

  @override
  String get constructorArrastre =>
      'Arrastre con el ícono ⠿ para reordenar módulos y lecciones.';

  @override
  String get constructorPrimerModulo => 'Cree el primer módulo para empezar.';

  @override
  String constructorModuloTitulo(Object numero, Object titulo) {
    return 'Módulo $numero: $titulo';
  }

  @override
  String get constructorRenombrarModulo => 'Renombrar módulo';

  @override
  String get constructorAgregarLeccion => 'Agregar lección';

  @override
  String get constructorEliminarModulo => 'Eliminar módulo';

  @override
  String get constructorSinLecciones =>
      'Sin lecciones — use + para agregar contenido.';

  @override
  String constructorEditarTipo(Object tipo) {
    return 'Editar $tipo';
  }

  @override
  String get constructorEliminarLeccion => 'Eliminar lección';

  @override
  String constructorEliminarLeccionTexto(Object titulo) {
    return '¿Eliminar \"$titulo\"?';
  }

  @override
  String get comunGuardado => 'Guardado ✓';

  @override
  String get constructorCuentaCertificado =>
      '¿Este curso cuenta para certificado?';

  @override
  String get constructorCuentaCertificadoTexto =>
      'Se ve un sello en el curso y sus horas cuentan para el certificado de la Ruta de Impacto del laboratorio (el PDF lo emite el LXD al completar toda la Ruta, no por curso individual)';

  @override
  String get constructorHorasCertificadas => 'Horas certificadas';

  @override
  String get constructorSinDefinir => 'Sin definir';

  @override
  String constructorApertura(Object fecha) {
    return 'Apertura: $fecha';
  }

  @override
  String constructorCierre(Object fecha) {
    return 'Cierre: $fecha';
  }

  @override
  String get constructorCierreAntes =>
      'El curso no puede cerrar antes de abrir.';

  @override
  String get constructorMaximo => 'Máximo de estudiantes (0 = sin límite)';

  @override
  String get constructorVisible => 'Visible';

  @override
  String get constructorOculto => 'Oculto';

  @override
  String get constructorOcultosTexto =>
      'Los cursos ocultos no aparecen para asignación';

  @override
  String get constructorPatrocinio => 'Patrocinio';

  @override
  String get constructorEmpresaPatrocinadora =>
      'Empresa patrocinadora del curso (opcional)';

  @override
  String get constructorNinguna => 'Ninguna';

  @override
  String get constructorPatrocinioTexto =>
      'Las horas de formación completadas en cursos patrocinados alimentan las métricas de impacto de la empresa.';

  @override
  String get constructorQuitarFecha => 'Quitar fecha';

  @override
  String get comunAgregar => 'Agregar';

  @override
  String get comunAceptar => 'Aceptar';

  @override
  String constructorEliminarModuloTexto(Object modulo, int cantidad) {
    return 'Va a eliminar \"$modulo\" con sus $cantidad lecciones.';
  }

  @override
  String get quizTipoMultiple => 'Selección múltiple';

  @override
  String get quizTipoVerdaderoFalso => 'Verdadero / Falso';

  @override
  String get quizTipoCorta => 'Respuesta corta';

  @override
  String get quizTipoOrdenar => 'Ordenar';

  @override
  String get quizTipoCompletar => 'Completar';

  @override
  String get leccionDescartarTexto =>
      'Hay cambios sin guardar en esta lección. ¿Desea salir de todas formas?';

  @override
  String get leccionNecesitaTitulo => 'La lección necesita un título.';

  @override
  String get leccionEnlaceNecesitaUrl =>
      'Una lección de tipo enlace necesita su URL.';

  @override
  String get leccionEspereRevision =>
      'Espere a que termine la revisión del video.';

  @override
  String get leccionSubidaCancelada =>
      'Se canceló la subida. Si la lección ya tenía video, sigue igual.';

  @override
  String get leccionEnlaceYoutube => 'Enlace del video de YouTube';

  @override
  String leccionYoutubeEncontrado(Object id) {
    return 'Video de YouTube encontrado. Se guarda solo su id ($id), no el enlace.';
  }

  @override
  String get leccionEnlaceVimeo =>
      'Enlace de Vimeo: se guarda tal cual y se ve con el reproductor de Vimeo.';

  @override
  String get leccionYaTieneVideo =>
      'Esta lección ya tiene un video propio cargado. Pegar un enlace lo reemplaza.';

  @override
  String get leccionPegueEnlace =>
      'Pegue el enlace tal como lo copia de YouTube: sirven watch?v=, youtu.be, shorts y embed. También se acepta Vimeo.';

  @override
  String get leccionNueva => 'Nueva lección';

  @override
  String get leccionEditar => 'Editar lección';

  @override
  String get leccionSubiendo => 'Subiendo…';

  @override
  String get leccionPegarYoutube => 'Pegar link de YouTube';

  @override
  String get leccionSubirVideo => 'Subir video';

  @override
  String get leccionDuracionMinutos => 'Duración (minutos)';

  @override
  String get leccionArchivoDescargable => 'Archivo descargable';

  @override
  String leccionArchivoActual(Object archivo) {
    return 'Actual: $archivo';
  }

  @override
  String get leccionPreguntasEncuesta =>
      'Preguntas de la encuesta (sin calificación)';

  @override
  String get leccionPreguntasQuiz => 'Preguntas (las califica el servidor)';

  @override
  String get leccionPregunta => 'Pregunta';

  @override
  String get leccionSinPreguntas =>
      'Sin preguntas todavía. Una lección de quiz sin preguntas se guarda, pero quien la abra recibe un aviso en vez de una nota.';

  @override
  String leccionPreguntaNumero(Object numero) {
    return 'Pregunta $numero';
  }

  @override
  String get leccionQuitarPregunta => 'Quitar pregunta';

  @override
  String get leccionEnunciado => 'Enunciado';

  @override
  String get leccionQuitarOpcion => 'Quitar opción';

  @override
  String get leccionOpcion => 'Opción';

  @override
  String get leccionRespuestaCorrecta => 'Respuesta correcta:';

  @override
  String get leccionRespuestaFlexible =>
      'Respuesta correcta (se comparan tildes y mayúsculas de forma flexible)';

  @override
  String get leccionPalabraCompleta =>
      'Palabra o frase que completa el enunciado';

  @override
  String get leccionOrdenCorrecto =>
      'Elementos en el orden CORRECTO — así se guardan, y así se califica quien los ordene igual:';

  @override
  String get leccionQuitarElemento => 'Quitar elemento';

  @override
  String get leccionElemento => 'Elemento';

  @override
  String get leccionInstrucciones => 'Instrucciones de la actividad';

  @override
  String get leccionFechaSinDefinir => 'Fecha límite: sin definir';

  @override
  String get leccionMaxArchivos => 'Máx. archivos';

  @override
  String get leccionPedirAlgo =>
      'La actividad tiene que pedir al menos texto o archivo: si no, no hay nada que entregar.';

  @override
  String get leccionTiposEntregable =>
      'Tipos de entregable aceptados (ninguno = cualquiera)';

  @override
  String get leccionCalificacion => 'Calificación';

  @override
  String get leccionRubrica => 'Rúbrica (criterios y puntos)';

  @override
  String get leccionCriterio => 'Criterio';

  @override
  String get leccionPuntos => 'Puntos';

  @override
  String get leccionQuitarCriterio => 'Quitar criterio';

  @override
  String leccionTotalPuntos(Object total) {
    return 'Total: $total puntos';
  }

  @override
  String leccionOpcionNumero(Object numero) {
    return 'Opción $numero';
  }

  @override
  String leccionOpcionCorrecta(Object numero) {
    return 'Opción $numero (correcta)';
  }

  @override
  String glosarioDelModuloCon(Object terminos) {
    return 'Glosario del módulo · $terminos';
  }

  @override
  String get glosarioEditorVacio =>
      'Este módulo todavía no tiene términos. Los que agregue aparecen al final de las lecciones que marque y al final del módulo.';

  @override
  String get glosarioAgregarTermino => 'Agregar término';

  @override
  String glosarioArrastrar(Object palabra) {
    return 'Arrastrar para reordenar «$palabra»';
  }

  @override
  String get glosarioTieneImagen => 'Tiene imagen';

  @override
  String get glosarioSinLeccion => 'No está marcado en ninguna lección';

  @override
  String glosarioEditarPalabra(Object palabra) {
    return 'Editar «$palabra»';
  }

  @override
  String glosarioEliminarPalabra(Object palabra) {
    return 'Eliminar «$palabra»';
  }

  @override
  String get glosarioEliminarTermino => 'Eliminar término';

  @override
  String glosarioEliminarTerminoTexto(Object palabra) {
    return '¿Eliminar «$palabra» del glosario? También se quita de los relacionados de otros términos y del repaso de los estudiantes.';
  }

  @override
  String get glosarioPalabraObligatoria => 'La palabra es obligatoria.';

  @override
  String glosarioYaExiste(Object palabra) {
    return 'Ya existe «$palabra» en este módulo.';
  }

  @override
  String glosarioYaExisteEn(Object palabra, Object modulo) {
    return 'Ya existe «$palabra» en el módulo «$modulo».';
  }

  @override
  String get glosarioDescartarTexto =>
      'Hay cambios sin guardar en este término. ¿Desea salir de todas formas?';

  @override
  String get glosarioTerminoAgregado => 'Término agregado ✓';

  @override
  String get glosarioNuevoTermino => 'Nuevo término';

  @override
  String get glosarioEditarTermino => 'Editar término';

  @override
  String glosarioModulo(Object modulo) {
    return 'Módulo: $modulo';
  }

  @override
  String get glosarioPalabraCampo => 'Palabra o expresión *';

  @override
  String get glosarioDefinicionCorta => 'Definición corta *';

  @override
  String get glosarioDefinicionObligatoria =>
      'La definición corta es obligatoria.';

  @override
  String get glosarioDefinicionAyuda =>
      'Una o dos frases. Es lo que se ve en la tarjeta y al pasar el mouse sobre la palabra.';

  @override
  String get glosarioExplicacion => 'Explicación ampliada (opcional)';

  @override
  String get glosarioEjemploOpcional => 'Ejemplo (opcional)';

  @override
  String get glosarioImagenOpcional => 'Imagen (opcional)';

  @override
  String get glosarioQuitarImagen => 'Quitar imagen';

  @override
  String get glosarioPngJpg => 'PNG o JPG.';

  @override
  String get glosarioLeccionesDonde => 'Lecciones donde aparece';

  @override
  String get glosarioModuloSinLecciones =>
      'Este módulo todavía no tiene lecciones.';

  @override
  String get glosarioRelacionadosTitulo => 'Términos relacionados';

  @override
  String get glosarioRelacionadosAyuda =>
      'Cuando el curso tenga más términos, podrá relacionarlos acá.';

  @override
  String get glosarioDeOtroModulo => 'De otro módulo';

  @override
  String get seguimientoTitulo => 'Seguimiento del Curso';

  @override
  String get seguimientoInscritos => 'Inscritos';

  @override
  String get seguimientoCompletados => 'Completados';

  @override
  String get seguimientoAvancePromedio => 'Avance promedio';

  @override
  String get seguimientoNotaPromedio => 'Nota promedio';

  @override
  String get seguimientoSinEstudiantes =>
      'Aún no hay estudiantes asignados a este curso.\nEl admin los asigna desde su portal.';

  @override
  String get seguimientoAnaliticas => 'Analíticas';

  @override
  String get seguimientoNota => 'Nota';

  @override
  String get seguimientoUltimaActividad => 'Última actividad';

  @override
  String get seguimientoEstado => 'Estado';

  @override
  String get seguimientoComentarios => 'Comentarios';

  @override
  String get seguimientoCompletado => 'Completado';

  @override
  String get seguimientoSinIniciar => 'Sin iniciar';

  @override
  String seguimientoNotaPrivada(Object nota) {
    return 'Nota privada: $nota';
  }

  @override
  String get seguimientoAgregarComentario => 'Agregar comentario privado';

  @override
  String seguimientoComentariosDe(Object nombre) {
    return 'Comentarios privados — $nombre';
  }

  @override
  String get seguimientoRetroObservaciones =>
      'Retroalimentación y observaciones';

  @override
  String get seguimientoSoloDocentes =>
      'Solo para el equipo docente. El estudiante NO la ve.';

  @override
  String get seguimientoAvanceCurso => 'Avance del curso';

  @override
  String get comunSinDatos => 'Sin datos';

  @override
  String get seguimientoAvanceUniversidad =>
      'Avance promedio por universidad (%)';

  @override
  String get seguimientoRiesgo => 'Riesgo de abandono (sin iniciar)';

  @override
  String get seguimientoTiempoPromedio => 'Tiempo promedio invertido';

  @override
  String get seguimientoAvancePatrocinados => 'Avance de patrocinados';

  @override
  String get seguimientoLeccionesTotales => 'Lecciones totales';

  @override
  String glosarioApareceEn(int cantidad) {
    String _temp0 = intl.Intl.pluralLogic(
      cantidad,
      locale: localeName,
      other: '$cantidad lecciones',
      one: '1 lección',
    );
    return 'Aparece en $_temp0';
  }

  @override
  String seguimientoNotaYActividad(Object nota, Object actividad) {
    return 'Nota: $nota  ·  $actividad';
  }

  @override
  String get adminPortalSuper => 'Portal Super Admin';

  @override
  String get adminPortal => 'Portal Admin';

  @override
  String get tabUsuarios => 'Usuarios';

  @override
  String get tabEquipos => 'Equipos';

  @override
  String get tabEvidenciasDonantes => 'Evidencias donantes';

  @override
  String get tabEvidenciasCorto => 'Evidencias';

  @override
  String get tabContenidoPagina => 'Contenido página';

  @override
  String get tabContenidoCorto => 'Contenido';

  @override
  String get tabDatosRespaldos => 'Datos y respaldos';

  @override
  String get tabRespaldosCorto => 'Respaldos';

  @override
  String get adminDashboardGeneral => 'Dashboard General';

  @override
  String get adminDashboardSubtitulo => 'Estado global de la plataforma';

  @override
  String get adminImpactoFormativo => 'Impacto formativo eduXaction';

  @override
  String get adminUsuariosPorRol => 'Usuarios por rol';

  @override
  String get adminEstudAbrev => 'Estud.';

  @override
  String get adminAsesores => 'Asesores';

  @override
  String get adminEmpresas => 'Empresas';

  @override
  String get adminDonantes => 'Donantes';

  @override
  String get adminProyectosPorEtapa => 'Proyectos por etapa';

  @override
  String get adminConfigureMetricas =>
      'Configure competencias, ODS y horas en los cursos (constructor del LXD) para ver métricas de impacto formativo.';

  @override
  String get adminHorasCompetencia => 'Horas de formación por competencia';

  @override
  String get adminSinDatosAun => 'Sin datos aún';

  @override
  String get adminCoberturaOds =>
      'Cobertura de ODS (estudiantes que completaron)';

  @override
  String get adminSinCursosOds => 'Sin cursos asociados a ODS aún';

  @override
  String adminOdsTooltip(Object ods, Object completados, Object total) {
    return '$ods — $completados de $total';
  }

  @override
  String get adminCalendarioSubtitulo =>
      'Sesiones sincrónicas de Open Learning, eventos de Ruta de Impacto y mentorías de toda la plataforma';

  @override
  String get asignarCursosOk => 'Cursos asignados ✓';

  @override
  String get asignarLabsOk => 'Laboratorios asignados ✓';

  @override
  String asignarA(Object nombre) {
    return 'Asignar a $nombre';
  }

  @override
  String asignarNoCarga(Object error) {
    return 'No se pudo cargar lo asignado: $error';
  }

  @override
  String get asignarExplicaOL =>
      'Cuenta de Open Learning: recibe cursos uno por uno. Es su única vía de acceso a material — sin cursos asignados no tiene nada que ver. No tiene laboratorios ni Ruta de Impacto.';

  @override
  String get asignarExplicaEdu =>
      'Cuenta eduXaction: recibe laboratorios, y con ellos el acceso a TODOS sus cursos, sin asignarlos aparte. Quitar un laboratorio le quita ese material: su avance no se borra y vuelve tal cual si se le reasigna, pero mientras tanto deja de verlo.';

  @override
  String get asignarSinLabs => 'No hay laboratorios creados todavía.';

  @override
  String get asignarSinCursos => 'No hay cursos creados todavía.';

  @override
  String get asignarDeLaboratorio => 'De laboratorio';

  @override
  String asignarPendientes(int cantidad, Object cursos) {
    String _temp0 = intl.Intl.pluralLogic(
      cantidad,
      locale: localeName,
      other:
          'Asignado. Estos cursos no están publicados, así que todavía no los verá: $cursos.',
      one:
          'Asignado. Este curso no está publicado, así que todavía no lo verá: $cursos.',
    );
    return '$_temp0';
  }

  @override
  String adminHorasPatrocinadas(Object empresa, Object horas) {
    return '$empresa ha patrocinado $horas horas de formación';
  }

  @override
  String get usuariosSubtituloSuper =>
      'Crea y elimina cualquier tipo de cuenta (incluidos admins)';

  @override
  String get usuariosSubtitulo =>
      'Crea cuentas de estudiantes, LXD, mentores, asesores, empresas y donantes';

  @override
  String get usuariosNuevo => 'Nuevo usuario';

  @override
  String get comunTodos => 'Todos';

  @override
  String get usuariosSinRol => 'No hay cuentas con ese rol.';

  @override
  String get usuariosUnaSolicitud => '1 solicitud de eliminación de cuenta';

  @override
  String usuariosSolicitudes(Object cantidad) {
    return '$cantidad solicitudes de eliminación de cuenta';
  }

  @override
  String usuariosSolicitudesTexto(Object dias) {
    return 'Estas cuentas ya no funcionan. Falta borrar sus datos personales dentro del plazo de $dias días que se les prometió.';
  }

  @override
  String usuariosBorrarDatosDe(Object nombre) {
    return 'Borrar los datos de $nombre';
  }

  @override
  String get usuariosBorrarDatosTexto =>
      'Se borran su nombre, correo, teléfono, cédula, ciudad, foto y perfil, el nombre en sus certificados y las notas sobre esta persona. No se puede deshacer.';

  @override
  String get usuariosDatosBorrados => 'Datos borrados.';

  @override
  String get usuariosBorrando => 'Borrando…';

  @override
  String get usuariosBorrarDatos => 'Borrar datos';

  @override
  String get usuariosRol => 'Rol';

  @override
  String get usuariosDetalle => 'Detalle';

  @override
  String get usuariosAcciones => 'Acciones';

  @override
  String usuariosCalifica(Object contextos) {
    return 'Califica: $contextos';
  }

  @override
  String get usuariosAsignarCursos => 'Asignar cursos';

  @override
  String get usuariosAsignarLabs => 'Asignar laboratorios';

  @override
  String get usuariosEliminar => 'Eliminar usuario';

  @override
  String usuariosEliminarTexto(Object nombre, Object rol) {
    return 'Va a eliminar a $nombre ($rol).';
  }

  @override
  String get usuariosCuentaEliminada => 'Cuenta eliminada ✓';

  @override
  String get usuariosNombreCorreoObligatorios =>
      'El nombre y el correo son obligatorios.';

  @override
  String get usuariosContrasenaMinima =>
      'La contraseña necesita al menos 6 caracteres.';

  @override
  String get usuariosEscribaInstitucion =>
      'Escriba el nombre de la institución en «¿Cuál institución?».';

  @override
  String get usuariosEditar => 'Editar usuario';

  @override
  String usuariosRolFijo(Object rol) {
    return 'Rol: $rol — para cambiarlo, se crea otra cuenta. Cambiarlo acá movería su acceso sin que se note.';
  }

  @override
  String get usuariosNombreCompleto => 'Nombre completo';

  @override
  String get usuariosContrasenaNueva => 'Contraseña nueva (opcional)';

  @override
  String get usuariosMinimoSeis => 'Mínimo 6 caracteres.';

  @override
  String get usuariosDejeEnBlanco =>
      'Déjela en blanco para no cambiarla. Cambiarla cierra las sesiones abiertas de esa persona.';

  @override
  String get usuariosSinUniversidadAsesor =>
      'Sin universidad — no verá estudiantes';

  @override
  String get usuariosNombreEmpresa => 'Nombre de la empresa';

  @override
  String get usuariosCodigoImpacto => 'Código de impacto único';

  @override
  String get usuariosTipoEstudiante => 'Tipo de estudiante';

  @override
  String get usuariosSoloCursos =>
      'Solo ve los cursos que le asigne. Sin laboratorios ni Ruta de Impacto.';

  @override
  String get usuariosVeLabs =>
      'Ve Laboratorios y su Ruta de Impacto (se asignan desde el laboratorio).';

  @override
  String get usuariosElijaUniversidad => 'Elija una universidad';

  @override
  String get usuariosSinUniversidadOL => 'Sin universidad (Open Learning)';

  @override
  String get usuariosCiudadAyuda =>
      'De dónde es — la ubica en el Mapa de Estudiantes';

  @override
  String get usuariosLxdEmpresa =>
      'Si este LXD es de una empresa aliada, sus cursos quedan atribuidos a ella.';

  @override
  String get usuariosPermisoCalificar => 'Permiso de calificar';

  @override
  String get usuariosCambioRegistrado =>
      'Cada cambio queda registrado con quién lo hizo.';

  @override
  String get usuariosOLDefecto => 'Activado por defecto: es quien califica ahí';

  @override
  String get usuariosEduDefecto => 'Desactivado por defecto: ahí no califica';

  @override
  String get usuariosMentorLab =>
      'El laboratorio se asigna desde la pestaña \"Laboratorios\" (un laboratorio puede tener varios mentores).';

  @override
  String get usuariosMentorEmpresa =>
      'Si este Mentor es de una empresa aliada, queda atribuido a ella.';

  @override
  String get usuariosEmpresaAliada => 'Empresa aliada (opcional)';

  @override
  String get usuariosNingunaEdu => 'Ninguna (de eduXaction)';

  @override
  String usuariosPidioEl(Object correo, Object fecha) {
    return '$correo · pidió el $fecha';
  }

  @override
  String usuariosQuedanDias(int cantidad) {
    String _temp0 = intl.Intl.pluralLogic(
      cantidad,
      locale: localeName,
      other: 'quedan $cantidad días',
      one: 'queda 1 día',
    );
    return '$_temp0';
  }

  @override
  String get usuariosPlazoVencido => 'plazo vencido';

  @override
  String get usuariosNinguno => 'ninguno';

  @override
  String get gestionProyectosSubtitulo =>
      'Cada proyecto define problema, solución, comunidad, ODS, etapa e indicadores';

  @override
  String get gestionNuevoProyecto => 'Nuevo proyecto';

  @override
  String get gestionSinProyectos => 'No hay proyectos.';

  @override
  String get gestionEliminarProyecto => 'Eliminar proyecto';

  @override
  String gestionVaAEliminar(Object nombre) {
    return 'Va a eliminar \"$nombre\".';
  }

  @override
  String gestionIntegrantes(int cantidad) {
    String _temp0 = intl.Intl.pluralLogic(
      cantidad,
      locale: localeName,
      other: '$cantidad integrantes',
      one: '1 integrante',
    );
    return '$_temp0';
  }

  @override
  String get gestionProyectoNombre => 'El proyecto necesita un nombre.';

  @override
  String get gestionEditarProyecto => 'Editar proyecto';

  @override
  String get gestionSinUniversidadReconciliar =>
      'Sin universidad (pendiente de reconciliar)';

  @override
  String get gestionIntegrantesUniversidad =>
      'Sus integrantes tienen que ser de esta universidad.';

  @override
  String get gestionProblema => 'Problema que resuelve';

  @override
  String get gestionSolucion => 'Solución propuesta';

  @override
  String get gestionComunidad => 'Comunidad beneficiada';

  @override
  String get gestionEtapaActual => 'Etapa actual';

  @override
  String get gestionHabilitarExpo => 'Habilitar RUTA NATIONAL EXPO';

  @override
  String get gestionHabilitarExpoTexto =>
      'Abre la checklist de preparación para el equipo.';

  @override
  String get gestionEquiposSubtitulo =>
      'Cada equipo trabaja un proyecto desde una universidad, con su asesor académico';

  @override
  String get gestionNuevoEquipo => 'Nuevo equipo';

  @override
  String get gestionSinEquipos => 'No hay equipos.';

  @override
  String get gestionIntegrantesTitulo => 'Integrantes';

  @override
  String get gestionEliminarEquipo => 'Eliminar equipo';

  @override
  String get gestionEquipoNecesita =>
      'El equipo necesita un nombre y un proyecto.';

  @override
  String get gestionEditarEquipo => 'Editar equipo';

  @override
  String get gestionNombreEquipo => 'Nombre del equipo';

  @override
  String get gestionUniversidadDelProyecto =>
      'Sale del proyecto. Para cambiarla, edite el proyecto.';

  @override
  String get gestionElijaProyecto => 'Elija un proyecto';

  @override
  String get gestionProyectoSinUniversidad =>
      'El proyecto todavía no tiene universidad';

  @override
  String get gestionAsesorOpcional => 'Asesor académico (opcional)';

  @override
  String get gestionAsesorAyuda =>
      'El asesor acompaña al equipo, no al proyecto: un proyecto puede tener equipos de varias universidades.';

  @override
  String get gestionSinAsesor => 'Sin asesor';

  @override
  String gestionIntegrantesDe(Object nombre) {
    return 'Integrantes de $nombre';
  }

  @override
  String get gestionSinEstudiantes => 'No hay estudiantes para asignar.';

  @override
  String get gestionRolProyecto =>
      'El rol dentro del proyecto no es el rol de la plataforma: describe qué hace esa persona en el equipo.';

  @override
  String get gestionLabsSubtitulo =>
      'Cada laboratorio tiene su Ruta de Impacto de tres fases';

  @override
  String get gestionNuevoLab => 'Nuevo laboratorio';

  @override
  String get gestionSinLabs => 'No hay laboratorios.';

  @override
  String get gestionEditarRuta => 'Editar Ruta de Impacto';

  @override
  String get gestionEliminarLab => 'Eliminar laboratorio';

  @override
  String gestionEliminarLabTexto(Object nombre) {
    return 'Va a eliminar \"$nombre\" con toda su Ruta.';
  }

  @override
  String get gestionLabNombre => 'El laboratorio necesita un nombre.';

  @override
  String get gestionEditarLab => 'Editar laboratorio';

  @override
  String get gestionLabSeCrea =>
      'Se crea con sus tres fases. Después se editan desde el editor de Ruta de Impacto.';

  @override
  String get gestionEmpresaOpcional => 'Empresa patrocinadora (opcional)';

  @override
  String get gestionCursosSubtitulo =>
      'Todos los cursos de la plataforma, de cualquier LXD';

  @override
  String get gestionSinCursosEstado => 'No hay cursos con ese estado.';

  @override
  String gestionCompletaron(Object cantidad) {
    return '$cantidad completaron';
  }

  @override
  String gestionSinCalificar(Object cantidad) {
    return '$cantidad sin calificar';
  }

  @override
  String gestionRutaModulo(Object modulo) {
    return 'Ruta: $modulo';
  }

  @override
  String get gestionEvidenciasTitulo => 'Evidencias para Donantes';

  @override
  String get gestionEvidenciasSubtitulo =>
      'Fotos, historias y reportes que ve cada donante en su portal';

  @override
  String get gestionNuevaEvidencia => 'Nueva evidencia';

  @override
  String get gestionSinEvidencias => 'No hay evidencias todavía.';

  @override
  String get gestionEliminarEvidencia => 'Eliminar evidencia';

  @override
  String get gestionEvidenciaNecesita =>
      'La evidencia necesita un título y un donante.';

  @override
  String get gestionEditarEvidencia => 'Editar evidencia';

  @override
  String get gestionTipo => 'Tipo';

  @override
  String get gestionDonanteRecibe => 'Donante que la recibe';

  @override
  String get gestionSoloEseDonante => 'Solo ese donante la ve en su portal.';

  @override
  String get gestionArchivoOpcional => 'Archivo (opcional)';

  @override
  String get gestionYaTieneArchivo =>
      'Ya tiene un archivo. Subir otro lo reemplaza.';

  @override
  String get rutaEditorHerramienta => 'el editor de la Ruta de Impacto';

  @override
  String rutaEditorVersion(Object version) {
    return 'Versión de contenido $version';
  }

  @override
  String get rutaEditorVersionTexto =>
      'Los certificados quedan anclados a la versión de contenido con la que se emitieron: agregar módulos después no invalida los que ya se entregaron.';

  @override
  String get rutaEditorAcompanan => 'Quiénes lo acompañan';

  @override
  String get rutaEditorSinMentores => 'Todavía sin mentores ni LXD.';

  @override
  String rutaEditorMentoresDe(Object nombre) {
    return 'Mentores de $nombre';
  }

  @override
  String get rutaEditorMentoresAyuda =>
      'Un laboratorio puede tener varios mentores, y todos ven a sus estudiantes.';

  @override
  String rutaEditorEstudiantesCantidad(Object cantidad) {
    return 'Estudiantes ($cantidad)';
  }

  @override
  String rutaEditorEstudiantesDe(Object nombre) {
    return 'Estudiantes de $nombre';
  }

  @override
  String get rutaEditorEstudiantesAyuda =>
      'Asignar a alguien acá le da acceso a los CURSOS del laboratorio. Quitarlo se lo quita: su avance no se borra, pero deja de verlo. Solo estudiantes eduXaction.';

  @override
  String get rutaEditorSinCuentas => 'No hay cuentas disponibles.';

  @override
  String get rutaEditorEditarFase => 'Editar la fase';

  @override
  String get rutaEditorFasesTres =>
      'Las fases son siempre tres: se editan, no se agregan ni se borran. Una Ruta con dos fases no se puede completar.';

  @override
  String get rutaEditorObjetivo => 'Objetivo';

  @override
  String get rutaEditorSinObjetivos => 'Sin objetivos todavía.';

  @override
  String get rutaEditorCursosCumplen => 'Cursos que lo cumplen';

  @override
  String get rutaEditorQuitarObjetivo => 'Quitar objetivo';

  @override
  String rutaEditorQuitarObjetivoTexto(Object objetivo) {
    return '¿Quitar \"$objetivo\" de la fase?';
  }

  @override
  String get rutaEditorSinCursosTraba =>
      'Sin cursos vinculados no se puede completar nunca, y eso traba la fase entera para todo el laboratorio.';

  @override
  String get rutaEditorObjetivoTexto => 'El objetivo necesita su texto.';

  @override
  String get rutaEditorNuevoObjetivo => 'Nuevo objetivo';

  @override
  String get rutaEditorEditarObjetivo => 'Editar objetivo';

  @override
  String get rutaEditorCategoria => 'Categoría';

  @override
  String get rutaEditorVincular =>
      'Después hay que vincularle los cursos que lo cumplen: sin ellos no se completa nunca.';

  @override
  String get rutaEditorCursosCumplenTitulo => 'Cursos que cumplen el objetivo';

  @override
  String rutaEditorCumplido(Object objetivo) {
    return '\"$objetivo\" se da por cumplido cuando el estudiante termina el 100% de TODOS los cursos marcados.';
  }

  @override
  String get rutaEditorSinMarcados =>
      'Sin ninguno marcado, este objetivo no se completa nunca.';

  @override
  String get rutaEditorModulos => 'Módulos';

  @override
  String get rutaEditorUltimoMentoria =>
      'El último módulo de la fase es siempre el de mentoría. Se recalcula solo al agregar, quitar o reordenar.';

  @override
  String get rutaEditorSinModulos => 'Sin módulos todavía.';

  @override
  String get rutaEditorCursosModulo => 'Cursos del módulo';

  @override
  String get rutaEditorRenombrar => 'Renombrar';

  @override
  String rutaEditorEliminarModuloTexto(Object modulo, Object cantidad) {
    return 'Va a eliminar \"$modulo\" con sus $cantidad lecciones propias.';
  }

  @override
  String rutaEditorCursosCantidad(int cantidad) {
    String _temp0 = intl.Intl.pluralLogic(
      cantidad,
      locale: localeName,
      other: '$cantidad cursos',
      one: '1 curso',
    );
    return '$_temp0';
  }

  @override
  String rutaEditorImportados(Object cantidad) {
    return 'Se agregaron $cantidad objetivos del curso a la fase.';
  }

  @override
  String rutaEditorCursosDe(Object modulo) {
    return 'Cursos de $modulo';
  }

  @override
  String get rutaEditorCursoUnModulo =>
      'Un curso vive en un solo módulo de esta Ruta: en dos, su avance se contaría dos veces. Al vincularlo, sus objetivos categorizados se agregan a la fase.';

  @override
  String get respaldoTitulo => 'Datos y Copias de Seguridad';

  @override
  String get respaldoSubtitulo => 'Dónde viven los datos y cómo respaldarlos';

  @override
  String get respaldoEstadoActual => 'Estado actual';

  @override
  String get respaldoRespaldo => 'Respaldo';

  @override
  String get respaldoDondeDatos => '¿Dónde se guardan los datos?';

  @override
  String get respaldoDondeDatosTexto =>
      'Los datos viven en la base de datos del servidor, no en este navegador. Cerrar sesión, cambiar de computador o entrar desde otro dispositivo no cambia nada: cada quien ve lo mismo.\n\nLos archivos (fotos, PDF, videos) se guardan aparte, en el almacenamiento de objetos, y el respaldo NO los incluye: guarda las referencias, no los archivos.\n\nUna copia de seguridad tampoco lleva credenciales. Las contraseñas y las sesiones abiertas quedan fuera a propósito: un respaldo es para restaurar datos, no para llevárselas.';

  @override
  String get respaldoEntregasSinRevisar => 'Entregas sin revisar';

  @override
  String get respaldoPreparando => 'Preparando…';

  @override
  String get respaldoDescargar => 'Descargar copia de seguridad';

  @override
  String get respaldoRestaurarArchivo => 'Restaurar desde archivo';

  @override
  String get respaldoSoloComputador =>
      'Restaurar una copia reemplaza la base entera: solo se puede hacer desde un computador.';

  @override
  String get respaldoReemplaza =>
      'Restaurar reemplaza la base entera por la del archivo. No se puede deshacer.';

  @override
  String get respaldoSoloSuper =>
      'Restaurar reemplaza la base entera, así que solo lo puede hacer un Super Admin.';

  @override
  String get respaldoGuardarCopia => 'Guardar copia de seguridad';

  @override
  String get respaldoCopiaDescargada => 'Copia descargada ✓';

  @override
  String get respaldoSeleccioneArchivo => 'Seleccione el archivo de respaldo';

  @override
  String get respaldoRestaurarCopia => 'Restaurar copia de seguridad';

  @override
  String respaldoRestaurarTexto(Object archivo) {
    return 'La base entera se reemplaza por la del archivo \"$archivo\". No se puede deshacer.';
  }

  @override
  String get respaldoNoValido =>
      'Ese archivo no es un respaldo válido: no se pudo leer como JSON.';

  @override
  String get respaldoRestaurado => 'Datos restaurados ✓';

  @override
  String get contenidoHerramienta => 'la edición de la página principal';

  @override
  String get contenidoTitulo => 'Contenido de la Página Principal';

  @override
  String get contenidoSubtitulo =>
      'Hero, banner y textos visibles para el público';

  @override
  String get contenidoTituloVacio =>
      'El título del hero no puede quedar vacío.';

  @override
  String get contenidoActualizado => 'Página principal actualizada ✓';

  @override
  String get contenidoImagenesPublicadas => 'Imágenes publicadas ✓';

  @override
  String get contenidoTituloHero => 'Título del hero';

  @override
  String get contenidoSubtituloHero => 'Subtítulo del hero';

  @override
  String get contenidoBanner => 'Banner de anuncio (vacío = oculto)';

  @override
  String get contenidoSobreNosotros => 'Texto \"Sobre nosotros\"';

  @override
  String get contenidoLinkVideollamada =>
      'Link de videollamada (módulos de mentoría)';

  @override
  String get contenidoLinkAyuda =>
      'Un solo enlace genérico: todavía no hay integración con un proveedor de reuniones.';

  @override
  String get contenidoCifras => 'Cifras del hero';

  @override
  String get contenidoCifrasAyuda =>
      'Los cuatro números bajo el título. Se escriben a mano a propósito: son la cifra que el equipo quiere comunicar, no el conteo de la base — ese vive en el panel.';

  @override
  String get contenidoGuardarCambios => 'Guardar cambios';

  @override
  String get contenidoGaleria => 'Galería de imágenes';

  @override
  String get contenidoGaleriaAyuda =>
      'Se muestran en la página principal, entre los laboratorios y el cierre. Quitar una la saca de la portada de inmediato.';

  @override
  String get contenidoGaleriaVacia => 'Todavía no hay imágenes en la galería.';

  @override
  String get contenidoSacarImagen => '¿Sacarla de la página principal?';

  @override
  String contenidoPublicar(Object cantidad) {
    return 'Publicar $cantidad en la portada';
  }

  @override
  String respaldoNombreArchivo(Object fecha) {
    return 'enactus_respaldo_$fecha.json';
  }

  @override
  String get avisoEntregaCalificadaTitulo => 'Entrega calificada';

  @override
  String avisoEntregaCalificadaCuerpo(Object tarea) {
    return '\"$tarea\" tiene nueva retroalimentación.';
  }

  @override
  String get avisoEntregaRevisadaTitulo => 'Entrega revisada';

  @override
  String avisoEntregaRevisadaCuerpo(Object tarea) {
    return '\"$tarea\" tiene un comentario nuevo de su Mentor.';
  }

  @override
  String get avisoForoReporteTitulo => 'Nuevo reporte en el foro';

  @override
  String get avisoForoReporteCuerpo =>
      'Alguien reportó contenido del foro. Revíselo en Foro › Reportes.';

  @override
  String get avisoCertificadoTitulo => 'Nuevo certificado';

  @override
  String avisoCertificadoCuerpo(Object laboratorio) {
    return 'Recibió el certificado por completar la Ruta de Impacto de $laboratorio.';
  }

  @override
  String avisoMentorComentoCuerpo(Object tarea) {
    return 'Su mentor comentó \"$tarea\".';
  }

  @override
  String avisoFirma(Object remitente, Object correo) {
    return '— $remitente ($correo)';
  }

  @override
  String get contenidoEnIngles => 'Textos en inglés';

  @override
  String get contenidoEnInglesAyuda =>
      'Para quien ve la portada en inglés. Si un campo queda vacío, se muestra el texto en español.';

  @override
  String get contenidoTituloHeroEn => 'Título del hero (inglés)';

  @override
  String get contenidoSubtituloHeroEn => 'Subtítulo del hero (inglés)';

  @override
  String get contenidoBannerEn => 'Banner de anuncio (inglés)';

  @override
  String get contenidoSobreNosotrosEn => 'Texto \"Sobre nosotros\" (inglés)';

  @override
  String get mentorPortal => 'Portal Mentor';

  @override
  String get tabMisLaboratorios => 'Mis Laboratorios';

  @override
  String get tabEntregas => 'Entregas';

  @override
  String get tabRecursosComunicaciones => 'Recursos Comunicaciones';

  @override
  String get tabRecursosCorto => 'Recursos';

  @override
  String get mentorLabsSubtitulo =>
      'Los laboratorios que acompaña y quiénes los cursan';

  @override
  String get mentorSinLabs => 'Todavía no le han asignado ningún laboratorio.';

  @override
  String get mentorSinEstudiantes => 'Sin estudiantes asignados todavía.';

  @override
  String get mentorCalendarioSubtitulo =>
      'Mentorías de sus laboratorios y eventos de la Ruta';

  @override
  String get mentorEntregasSubtitulo =>
      'Revise y comente el trabajo de sus estudiantes';

  @override
  String get mentorSinEntregas => 'No hay entregas por ahora.';

  @override
  String get mentorComoMentor =>
      'Como mentor revisa y comenta, pero no pone nota: la calificación tiene su propio autor y su propia escala. Su comentario llega igual al estudiante.';

  @override
  String get mentorRevisada => 'Revisada';

  @override
  String get mentorSinRevisar => 'Sin revisar';

  @override
  String mentorSuComentario(Object comentario) {
    return 'Su comentario: $comentario';
  }

  @override
  String get mentorEditarComentario => 'Editar comentario';

  @override
  String get mentorEscribaComentario =>
      'Escriba su comentario antes de guardar.';

  @override
  String get mentorComentarioGuardado => 'Comentario guardado ✓';

  @override
  String get mentorRevisarEntrega => 'Revisar entrega';

  @override
  String get mentorReviseComente =>
      'Revise y comente; la nota la pone quien califica el curso.';

  @override
  String get mentorSuRetro => 'Su retroalimentación';

  @override
  String get mentorPerfilSubtitulo =>
      'Sus datos y el material que comparte con los estudiantes';

  @override
  String get asesorPortal => 'Portal Asesor Académico';

  @override
  String get tabDashboardUniversidad => 'Dashboard Universidad';

  @override
  String get tabSeguimientoEstudiantes => 'Seguimiento Estudiantes';

  @override
  String get tabDirectorioCorto => 'Directorio';

  @override
  String get asesorSuUniversidad => 'Su universidad';

  @override
  String get asesorSubtitulo => 'Los equipos y estudiantes que acompaña';

  @override
  String get asesorCalendarioSubtitulo =>
      'Eventos de la Ruta de Impacto y de los laboratorios de sus estudiantes';

  @override
  String get asesorSeguimientoTitulo => 'Seguimiento de Estudiantes';

  @override
  String get asesorSeguimientoSubtitulo =>
      'Cómo van los estudiantes de su universidad';

  @override
  String get asesorBuscarNombre => 'Buscar por nombre…';

  @override
  String get asesorNingunEstudiante => 'Ningún estudiante coincide.';

  @override
  String asesorCursosFraccion(Object hechos, Object total) {
    return '$hechos/$total cursos';
  }

  @override
  String get asesorProyectosSubtitulo =>
      'Los proyectos de los equipos que asesora';

  @override
  String get asesorSinProyectos => 'Todavía no hay proyectos.';

  @override
  String get empresaPortal => 'Portal Empresa';

  @override
  String get tabImpacto => 'Impacto';

  @override
  String get tabMapaEstudiantes => 'Mapa de Estudiantes';

  @override
  String get tabMapaCorto => 'Mapa';

  @override
  String get tabEstudiantesPatrocinados => 'Estudiantes Patrocinados';

  @override
  String get tabPatrocinadosCorto => 'Patrocinados';

  @override
  String get tabMiEquipo => 'Mi Equipo';

  @override
  String get tabEquipoCorto => 'Equipo';

  @override
  String get tabTalentoCorto => 'Talento';

  @override
  String get empresaImpactoTitulo => 'Impacto de su aporte';

  @override
  String get empresaImpactoSubtitulo => 'Qué hizo posible su organización';

  @override
  String get empresaEstudiantesAlcanzados => 'Estudiantes alcanzados';

  @override
  String get empresaEquipoFormador => 'Su equipo formador';

  @override
  String get empresaHorasFormacion => 'Horas de formación';

  @override
  String empresaAcompana(
    Object empresa,
    Object estudiantes,
    Object laboratorios,
  ) {
    return '$empresa acompaña a $estudiantes estudiantes en $laboratorios laboratorios.';
  }

  @override
  String get empresaLabsSubtitulo =>
      'Los que patrocina y aquellos donde trabaja su equipo';

  @override
  String get empresaSinLabs =>
      'Todavía no hay laboratorios asociados a su organización.';

  @override
  String get empresaPatrocinadosSubtitulo =>
      'A quiénes alcanza su aporte y cómo van';

  @override
  String get empresaSinEstudiantes =>
      'Todavía no hay estudiantes vinculados a su organización.';

  @override
  String get empresaEquipoSubtitulo => 'Los LXD y mentores de su organización';

  @override
  String get empresaNuevaCuenta => 'Nueva cuenta';

  @override
  String get empresaSinCuentas => 'Todavía no ha dado de alta a nadie.';

  @override
  String get empresaCuentasAtadas =>
      'Las cuentas que cree quedan atadas a su organización. Solo puede dar de alta LXD y mentores: los estudiantes los asigna el equipo de administración.';

  @override
  String empresaEntregasRevisadas(Object cantidad) {
    return '$cantidad entregas revisadas';
  }

  @override
  String get empresaCuentaCreada => 'Cuenta creada ✓';

  @override
  String get empresaNuevaCuentaEquipo => 'Nueva cuenta de su equipo';

  @override
  String get empresaContrasenaAyuda =>
      'Mínimo 6 caracteres. Usted se la comparte.';

  @override
  String get empresaCargoOpcional => 'Cargo (opcional)';

  @override
  String get donantePortal => 'Portal Donante';

  @override
  String get tabMiImpacto => 'Mi Impacto';

  @override
  String get donanteSubtitulo => 'A quiénes apoya y cómo van';

  @override
  String get donanteEstudiantesApoyados => 'Estudiantes apoyados';

  @override
  String get donanteEvidenciasRecibidas => 'Evidencias recibidas';

  @override
  String get donanteEstudiantesQueApoya => 'Estudiantes que apoya';

  @override
  String get donanteSinEstudiantes =>
      'Todavía no hay estudiantes vinculados a su aporte. En cuanto su administrador asigne alguno, aparecerá acá.';

  @override
  String get donanteEvidenciasTitulo => 'Evidencias de Impacto';

  @override
  String get donanteEvidenciasSubtitulo =>
      'Fotos, historias y reportes de lo que su aporte hizo posible';

  @override
  String get donanteSinEvidencias =>
      'Todavía no hay evidencias para su aporte.';

  @override
  String get donanteVerArchivo => 'Ver archivo';

  @override
  String get comunPalabraEliminar => 'ELIMINAR';

  @override
  String get rutaLaboratorioMayus => 'LABORATORIO';

  @override
  String get rutaObjetivosMayus => 'OBJETIVOS';

  @override
  String get proyectosEquipoMayus => 'EQUIPO';

  @override
  String get visorNombreArchivo => 'documento.pdf';

  @override
  String odsNumero(Object numero) {
    return 'ODS $numero';
  }

  @override
  String get odsSigla => 'ODS';

  @override
  String get foroFijado => 'FIJADO';
}
