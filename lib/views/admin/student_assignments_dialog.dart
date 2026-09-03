import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../models/models.dart';
import '../../providers/data_provider.dart';
import '../../services/api_errors.dart';
import '../../utils/app_theme.dart';
import '../../widgets/async_states.dart';
import '../../widgets/common.dart';

/// Asigna material a UN estudiante: sus laboratorios, o sus cursos.
///
/// Se abre desde la fila de la persona en Usuarios, que es donde se la busca
/// cuando la pregunta es "¿qué tiene asignado?". La otra vía —desde el
/// laboratorio hacia las personas— sigue existiendo y sirve para matricular a
/// un grupo entero de una vez; esta sirve para lo contrario.
///
/// **Qué se puede asignar depende del tipo de cuenta, y no es una preferencia
/// de esta pantalla**: la vista `student_course_access` del servidor define el
/// acceso de un Enactus por sus laboratorios y el de un Open Learning por sus
/// cursos directos, sin mirar la otra tabla. Ofrecer las dos opciones haría
/// que una de ellas se guardara sin efecto alguno.
Future<void> showStudentAssignmentsDialog(
  BuildContext context,
  AppUser student,
) =>
    showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (_) => _StudentAssignmentsDialog(student: student),
    );

class _StudentAssignmentsDialog extends StatefulWidget {
  final AppUser student;

  const _StudentAssignmentsDialog({required this.student});

  @override
  State<_StudentAssignmentsDialog> createState() =>
      _StudentAssignmentsDialogState();
}

class _StudentAssignmentsDialogState extends State<_StudentAssignmentsDialog> {
  /// Lo asignado hoy. Se pide al abrir y no se cachea: la escritura reemplaza
  /// la lista completa, así que partir de un valor viejo pisaría en silencio
  /// lo que otro administrador acabe de asignar.
  Future<StudentAssignments>? _carga;

  Set<String>? _seleccion;
  bool _saving = false;
  ApiException? _error;

  bool get _esOpenLearning =>
      widget.student.studentType == StudentType.openLearning;

  @override
  void initState() {
    super.initState();
    _carga = context.read<DataProvider>().studentAssignments(widget.student.id);
  }

  Future<void> _save() async {
    final seleccion = _seleccion;
    if (seleccion == null) return;

    setState(() {
      _saving = true;
      _error = null;
    });

    final data = context.read<DataProvider>();

    // El aviso se emite contra el contexto del NAVEGADOR, no contra el de
    // este diálogo. Hoy usar el de acá también funciona —el elemento sigue
    // vivo hasta que termina el frame— pero es una casualidad de tiempos, no
    // una garantía: apoyarse en ella hace que el aviso dependa de cuándo se
    // desmonta el diálogo. El del navegador sigue montado por definición.
    final navegador = Navigator.of(context);
    final contextoVivo = navegador.context;

    try {
      // Primero se guarda y se arma el aviso; recién al final se cierra y se
      // avisa. Así hay un solo lugar donde se toca el contexto después del
      // `await`, en vez de tres repartidos entre las dos ramas.
      String? pendiente;
      if (_esOpenLearning) {
        final pendientes =
            await data.setStudentCourses(widget.student.id, seleccion.toList());
        if (pendientes.isNotEmpty) {
          // No es un error: la asignación se guardó. Pero el estudiante no va
          // a ver esos cursos hasta que se publiquen, y darlo por hecho es
          // exactamente cómo alguien queda sin material sin que nadie lo note.
          pendiente =
              'Asignado. ${pendientes.length == 1 ? "Este curso no está publicado" : "Estos cursos no están publicados"}, '
              'así que todavía no los verá: ${pendientes.map((c) => c.name).join(", ")}.';
        }
      } else {
        await data.setStudentLaboratories(
            widget.student.id, seleccion.toList());
      }

      if (!mounted) return;
      navegador.pop();
      if (!contextoVivo.mounted) return;

      if (pendiente != null) {
        showAppSnack(contextoVivo, pendiente);
      } else {
        showSuccessCheck(
          contextoVivo,
          _esOpenLearning ? 'Cursos asignados ✓' : 'Laboratorios asignados ✓',
        );
      }
    } on ApiException catch (e) {
      if (mounted) {
        setState(() {
          _saving = false;
          _error = e;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return AdaptiveFormShell(
      title: 'Asignar a ${widget.student.name}',
      maxWidth: 520,
      saving: _saving,
      onCancel: () => Navigator.pop(context),
      onSave: _seleccion == null ? () {} : _save,
      child: FutureBuilder<StudentAssignments>(
        future: _carga,
        builder: (context, snap) {
          if (snap.hasError) {
            // `FutureBuilder` entrega el error como `Object`: casi siempre es
            // un `ApiException`, pero un fallo de red crudo no lo es, y forzar
            // el tipo cambiaría un mensaje útil por un error de casteo.
            final e = snap.error;
            return e is ApiException
                ? ErrorBanner(e)
                : _Vacio('No se pudo cargar lo asignado: $e');
          }
          if (!snap.hasData) {
            return const CardListSkeleton(count: 4, height: 48);
          }

          // Primera construcción con datos: la selección arranca de lo que ya
          // tiene asignado, no vacía. Vacía convertiría "abrir y guardar sin
          // tocar nada" en un borrado completo.
          _seleccion ??= {
            ...(_esOpenLearning ? snap.data!.courseIds : snap.data!.laboratoryIds)
          };

          return Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (_error != null) ...[
                ErrorBanner(_error!),
                const SizedBox(height: 12),
              ],
              _Explicacion(esOpenLearning: _esOpenLearning),
              const SizedBox(height: 12),
              if (_esOpenLearning)
                _ListaDeCursos(
                  seleccion: _seleccion!,
                  habilitado: !_saving,
                  onToggle: _alternar,
                )
              else
                _ListaDeLaboratorios(
                  seleccion: _seleccion!,
                  habilitado: !_saving,
                  onToggle: _alternar,
                ),
            ],
          );
        },
      ),
    );
  }

  void _alternar(String id, bool marcado) => setState(() {
        marcado ? _seleccion!.add(id) : _seleccion!.remove(id);
      });
}

/// Por qué esta cuenta recibe una cosa y no la otra, y qué pasa al quitar.
class _Explicacion extends StatelessWidget {
  final bool esOpenLearning;

  const _Explicacion({required this.esOpenLearning});

  @override
  Widget build(BuildContext context) {
    final texto = esOpenLearning
        ? 'Cuenta de Open Learning: recibe cursos uno por uno. Es su única vía '
            'de acceso a material — sin cursos asignados no tiene nada que ver. '
            'No tiene laboratorios ni Ruta de Impacto.'
        : 'Cuenta eduXaction: recibe laboratorios, y con ellos el acceso a '
            'TODOS sus cursos, sin asignarlos aparte. Quitar un laboratorio le '
            'quita ese material: su avance no se borra y vuelve tal cual si se '
            'le reasigna, pero mientras tanto deja de verlo.';

    return Container(
      padding: const EdgeInsets.all(11),
      decoration: BoxDecoration(
        color: AppColors.gold.withValues(alpha: 0.07),
        borderRadius: BorderRadius.circular(9),
        border: Border.all(color: AppColors.gold.withValues(alpha: 0.25)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.info_outline, size: 15, color: AppColors.gold),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              texto,
              style: const TextStyle(
                  fontSize: 12, color: AppColors.textMuted, height: 1.45),
            ),
          ),
        ],
      ),
    );
  }
}

class _ListaDeLaboratorios extends StatelessWidget {
  final Set<String> seleccion;
  final bool habilitado;
  final void Function(String id, bool marcado) onToggle;

  const _ListaDeLaboratorios({
    required this.seleccion,
    required this.habilitado,
    required this.onToggle,
  });

  @override
  Widget build(BuildContext context) {
    return context.watch<DataProvider>().laboratories.when(
          loading: () => const CardListSkeleton(count: 4, height: 48),
          error: (e) => ErrorBanner(e),
          data: (labs) => labs.isEmpty
              ? const _Vacio('No hay laboratorios creados todavía.')
              : Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    for (final lab in labs)
                      CheckboxListTile(
                        dense: true,
                        contentPadding: EdgeInsets.zero,
                        activeColor: AppColors.gold,
                        title: Text(lab.name,
                            style: const TextStyle(fontSize: 13),
                            overflow: TextOverflow.ellipsis),
                        subtitle: lab.description.isEmpty
                            ? null
                            : Text(lab.description,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(fontSize: 11.5)),
                        value: seleccion.contains(lab.id),
                        onChanged: habilitado
                            ? (v) => onToggle(lab.id, v == true)
                            : null,
                      ),
                  ],
                ),
        );
  }
}

class _ListaDeCursos extends StatelessWidget {
  final Set<String> seleccion;
  final bool habilitado;
  final void Function(String id, bool marcado) onToggle;

  const _ListaDeCursos({
    required this.seleccion,
    required this.habilitado,
    required this.onToggle,
  });

  @override
  Widget build(BuildContext context) {
    return context.watch<DataProvider>().courses.when(
          loading: () => const CardListSkeleton(count: 4, height: 48),
          error: (e) => ErrorBanner(e),
          data: (cursos) {
            // Los de Open Learning primero: son los pensados para estas
            // cuentas. Los demás se pueden asignar igual —un curso de
            // laboratorio sirve suelto— pero no son lo que se busca primero.
            final ordenados = [...cursos]..sort((a, b) {
                if (a.isOpenLearning != b.isOpenLearning) {
                  return a.isOpenLearning ? -1 : 1;
                }
                return a.name.toLowerCase().compareTo(b.name.toLowerCase());
              });

            if (ordenados.isEmpty) {
              return const _Vacio('No hay cursos creados todavía.');
            }

            return Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                for (final curso in ordenados)
                  CheckboxListTile(
                    dense: true,
                    contentPadding: EdgeInsets.zero,
                    activeColor: AppColors.gold,
                    title: Text(curso.name,
                        style: const TextStyle(fontSize: 13),
                        overflow: TextOverflow.ellipsis),
                    subtitle: _Subtitulo(curso: curso),
                    value: seleccion.contains(curso.id),
                    onChanged: habilitado
                        ? (v) => onToggle(curso.id, v == true)
                        : null,
                  ),
              ],
            );
          },
        );
  }
}

/// Lo que hace falta saber ANTES de marcar la casilla: si es un curso de Open
/// Learning, y si el estudiante lo va a poder ver.
class _Subtitulo extends StatelessWidget {
  final Course curso;

  const _Subtitulo({required this.curso});

  @override
  Widget build(BuildContext context) {
    final visible = curso.status == 'published' && curso.visible;

    return Row(
      children: [
        if (curso.isOpenLearning)
          const _Etiqueta('Open Learning', color: AppColors.gold),
        if (!visible)
          _Etiqueta(
            curso.status == 'published' ? 'Oculto' : 'Borrador',
            color: AppColors.statusCritical,
          ),
        if (visible && !curso.isOpenLearning)
          const _Etiqueta('De laboratorio', color: AppColors.textMuted),
      ],
    );
  }
}

class _Etiqueta extends StatelessWidget {
  final String texto;
  final Color color;

  const _Etiqueta(this.texto, {required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(right: 6, top: 2),
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(5),
      ),
      child: Text(
        texto,
        style: TextStyle(
            fontSize: 10, color: color, fontWeight: FontWeight.w600),
      ),
    );
  }
}

class _Vacio extends StatelessWidget {
  final String texto;

  const _Vacio(this.texto);

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: Text(texto,
            style: const TextStyle(
                fontSize: 12.5, color: AppColors.textMuted)),
      );
}
