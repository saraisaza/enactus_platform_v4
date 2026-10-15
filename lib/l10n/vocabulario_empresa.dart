import 'app_localizations.dart';
import 'app_localizations_en.dart';
import 'app_localizations_es.dart';

/// Las palabras de la plataforma en el portal de una empresa.
///
/// Una empresa no es una universidad: su gente son **empleados**, lo que
/// toman son **capacitaciones** y lo que hace su supervisor con una entrega
/// es **aprobarla**. Quien entra con una cuenta de empresa —empleado,
/// supervisor o LXD de la empresa; ver `AppUser.esDeEmpresa`— ve estos
/// textos en lugar de los de siempre. Enactus y Open Learning no cambian.
///
/// Cada texto vive en los ARB como `empresa<Clave>` (con su traducción), y
/// acá solo se dice qué texto reemplaza a cuál: así las pantallas siguen
/// pidiendo `tr.tabMisCursos` y no hay que tocar cada una.
mixin VocabularioDeEmpresa on AppLocalizations {
  @override
  String get rolEstudiante => empresaRolEstudiante;

  @override
  String get comunEstudiante => empresaComunEstudiante;

  @override
  String get tabMisCursos => empresaTabMisCursos;

  @override
  String get tabCursosCorto => empresaTabCursosCorto;

  @override
  String get tabCalificaciones => empresaTabCalificaciones;

  @override
  String get tabCalificarCorto => empresaTabCalificarCorto;

  @override
  String get tabMisEstudiantes => empresaTabMisEstudiantes;

  @override
  String get tabEstudiantesCorto => empresaTabEstudiantesCorto;

  @override
  String get busquedaPista => empresaBusquedaPista;

  @override
  String get busquedaTipoCurso => empresaBusquedaTipoCurso;

  @override
  String cursoDocente(Object docente) =>
      empresaCursoDocente(docente);

  @override
  String get cursosSubtitulo => empresaCursosSubtitulo;

  @override
  String get cursosBuscar => empresaCursosBuscar;

  @override
  String get cursosCargando => empresaCursosCargando;

  @override
  String get cursosNingunoCoincide => empresaCursosNingunoCoincide;

  @override
  String get cursosNoTrajo => empresaCursosNoTrajo;

  @override
  String get cursosSinAsignados => empresaCursosSinAsignados;

  @override
  String get cursosSinAsignadosTexto => empresaCursosSinAsignadosTexto;

  @override
  String get cursosAsignados => empresaCursosAsignados;

  @override
  String get actividadSinEntregas => empresaActividadSinEntregas;

  @override
  String get cursoSinContenido => empresaCursoSinContenido;

  @override
  String get cursoNoPuedeResponder => empresaCursoNoPuedeResponder;

  @override
  String get cursoSoloLectura => empresaCursoSoloLectura;

  @override
  String get actividadEnRevision => empresaActividadEnRevision;

  @override
  String get actividadSeCompletaAprobada => empresaActividadSeCompletaAprobada;

  @override
  String get leccionSeCompletaActividad => empresaLeccionSeCompletaActividad;

  @override
  String get calificarEntregaCalificada => empresaCalificarEntregaCalificada;

  @override
  String calificarTitulo(Object tarea) =>
      empresaCalificarTitulo(tarea);

  @override
  String get calificarEscala => empresaCalificarEscala;

  @override
  String get leccionCalificacion => empresaLeccionCalificacion;

  @override
  String dashboardCalificadoEl(Object fecha) =>
      empresaDashboardCalificadoEl(fecha);

  @override
  String get dashboardSinCalificadas => empresaDashboardSinCalificadas;

  @override
  String dashboardCursosActivos(int cantidad) =>
      empresaDashboardCursosActivos(cantidad);

  @override
  String get dashboardProgresoPorCurso => empresaDashboardProgresoPorCurso;

  @override
  String get dashboardSinCursos => empresaDashboardSinCursos;

  @override
  String get dashboardTodoCompletado => empresaDashboardTodoCompletado;

  @override
  String get certificadosMisSubtitulo => empresaCertificadosMisSubtitulo;

  @override
  String get certificadosVacio => empresaCertificadosVacio;

  @override
  String get calendarioSubtitulo => empresaCalendarioSubtitulo;

  @override
  String get perfilCursosActivos => empresaPerfilCursosActivos;

  @override
  String get perfilAsignaAdmin => empresaPerfilAsignaAdmin;

  @override
  String get supervisorTabGente => empresaSupervisorTabGente;

  @override
  String get supervisorTabGenteCorto => empresaSupervisorTabGenteCorto;

  @override
  String get supervisorGenteSubtitulo => empresaSupervisorGenteSubtitulo;

  @override
  String get supervisorSinGente => empresaSupervisorSinGente;

  @override
  String get supervisorSinCursos => empresaSupervisorSinCursos;

  @override
  String supervisorCursosTerminados(int terminados, int total) =>
      empresaSupervisorCursosTerminados(terminados, total);

  @override
  String get supervisorEntregasSubtitulo => empresaSupervisorEntregasSubtitulo;

  @override
  String get supervisorCursosSubtitulo => empresaSupervisorCursosSubtitulo;

  @override
  String get supervisorSinCursosAun => empresaSupervisorSinCursosAun;

  @override
  String get supervisorCertificadosSubtitulo => empresaSupervisorCertificadosSubtitulo;

  @override
  String get lxdCursosSubtitulo => empresaLxdCursosSubtitulo;

  @override
  String get lxdEstudiantesSubtitulo => empresaLxdEstudiantesSubtitulo;

  @override
  String get lxdCalificacionesSubtitulo => empresaLxdCalificacionesSubtitulo;

  @override
  String get lxdSinCursos => empresaLxdSinCursos;

  @override
  String get lxdSinEstudiantes => empresaLxdSinEstudiantes;

  @override
  String get lxdSinEntregas => empresaLxdSinEntregas;

  @override
  String get lxdNuevoCurso => empresaLxdNuevoCurso;

  @override
  String get lxdNombreDelCurso => empresaLxdNombreDelCurso;

  @override
  String get lxdNombreCurso => empresaLxdNombreCurso;

  @override
  String lxdCursoDeEmpresa(String empresa) =>
      empresaLxdCursoDeEmpresa(empresa);

  @override
  String get lxdCursoEliminado => empresaLxdCursoEliminado;

  @override
  String get lxdEliminarCurso => empresaLxdEliminarCurso;

  @override
  String lxdInscritos(Object cantidad) =>
      empresaLxdInscritos(cantidad);

  @override
  String get lxdPromedioCursos => empresaLxdPromedioCursos;

  @override
  String get lxdPerfilSubtitulo => empresaLxdPerfilSubtitulo;

  @override
  String get lxdCalendarioSubtitulo => empresaLxdCalendarioSubtitulo;

  @override
  String get calendarioSinCursosOL => empresaCalendarioSinCursosOL;

  @override
  String get constructorTitulo => empresaConstructorTitulo;

  @override
  String get constructorDelCurso => empresaConstructorDelCurso;

  @override
  String get constructorGuardado => empresaConstructorGuardado;

  @override
  String get constructorNecesitaNombre => empresaConstructorNecesitaNombre;

  @override
  String get constructorObjetivosCurso => empresaConstructorObjetivosCurso;

  @override
  String get constructorArchivarCurso => empresaConstructorArchivarCurso;

  @override
  String get constructorArchivarTexto => empresaConstructorArchivarTexto;

  @override
  String get constructorExclusivoDeSuEmpresa => empresaConstructorExclusivoDeSuEmpresa;

  @override
  String get constructorMaximo => empresaConstructorMaximo;

  @override
  String get constructorPrerrequisitosTexto => empresaConstructorPrerrequisitosTexto;

  @override
  String get constructorSinOtrosCursos => empresaConstructorSinOtrosCursos;

  @override
  String get constructorEntregaCertificado => empresaConstructorEntregaCertificado;

  @override
  String get constructorCierreAntes => empresaConstructorCierreAntes;

  @override
  String get constructorCategorizacion => empresaConstructorCategorizacion;

  @override
  String get seguimientoTitulo => empresaSeguimientoTitulo;

  @override
  String get seguimientoAvanceCurso => empresaSeguimientoAvanceCurso;

  @override
  String get seguimientoInscritos => empresaSeguimientoInscritos;

  @override
  String get seguimientoSinEstudiantes => empresaSeguimientoSinEstudiantes;

  @override
  String get seguimientoSoloDocentes => empresaSeguimientoSoloDocentes;

  @override
  String get subidaVistaPreviaAsi => empresaSubidaVistaPreviaAsi;

  @override
  String get usuarioCursosCreados => empresaUsuarioCursosCreados;

  @override
  String get usuarioSinCursos => empresaUsuarioSinCursos;

  @override
  String usuarioEstudiantes(Object cantidad) =>
      empresaUsuarioEstudiantes(cantidad);

  @override
  String get perfilCarrera => empresaPerfilCarrera;

  @override
  String get calificacionPendiente => empresaCalificacionPendiente;

  @override
  String get lxdFiltrarNombre => empresaLxdFiltrarNombre;

  @override
  String get constructorRestricciones => empresaConstructorRestricciones;

  @override
  String get avisoEntregaCalificadaTitulo => empresaAvisoEntregaCalificadaTitulo;

  @override
  String avisoCertificadoCursoCuerpo(String curso) =>
      empresaAvisoCertificadoCursoCuerpo(curso);
}

class TextosDeEmpresaEs extends AppLocalizationsEs with VocabularioDeEmpresa {}

class TextosDeEmpresaEn extends AppLocalizationsEn with VocabularioDeEmpresa {}

/// Los textos de empresa en [codigo] (`es` o `en`).
AppLocalizations textosDeEmpresa(String codigo) =>
    codigo == 'en' ? TextosDeEmpresaEn() : TextosDeEmpresaEs();
