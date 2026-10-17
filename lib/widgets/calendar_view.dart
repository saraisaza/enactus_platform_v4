import 'package:flutter/material.dart';

import '../l10n/textos.dart';
import '../models/models.dart';
import '../providers/data_provider.dart';
import '../services/api_errors.dart';
import '../utils/app_theme.dart';
import '../utils/formatos.dart';
import 'async_states.dart';
import 'common.dart';
import 'visor_pdf.dart';

/// Paleta semántica por tipo de evento del calendario: colores de dato, que
/// no siguen a la marca y se distinguen del acento (reservado para «hoy»).
/// Todos pasan AA (>=4.5:1) como relleno con texto oscuro y como barra sobre
/// las tarjetas.
Color calendarEventColor(CalendarEventType t) => switch (t) {
      CalendarEventType.openLearningSync => const Color(0xFF4C8DFF), // azul
      CalendarEventType.rutaImpacto => const Color(0xFF2DD4BF), // verde azulado
      CalendarEventType.mentoria => const Color(0xFFA78BFA), // violeta
      CalendarEventType.laboratorio => const Color(0xFFA3E635), // lima
      CalendarEventType.organizacion => const Color(0xFFF472B6), // rosa
    };

IconData calendarEventIcon(CalendarEventType t) => switch (t) {
      CalendarEventType.openLearningSync => Icons.school_outlined,
      CalendarEventType.rutaImpacto => Icons.groups_outlined,
      CalendarEventType.mentoria => Icons.psychology_outlined,
      CalendarEventType.laboratorio => Icons.science_outlined,
      CalendarEventType.organizacion => Icons.apartment_outlined,
    };

String calendarEventTypeLabel(CalendarEventType t) => switch (t) {
      CalendarEventType.openLearningSync => tr.eventoCurso,
      CalendarEventType.rutaImpacto => tr.eventoRutaImpacto,
      CalendarEventType.mentoria => tr.eventoMentoria,
      CalendarEventType.laboratorio => tr.eventoLaboratorio,
      CalendarEventType.organizacion => tr.eventoOrganizacion,
    };

bool _sameDay(DateTime a, DateTime b) =>
    a.year == b.year && a.month == b.month && a.day == b.day;

DateTime _dia(DateTime d) => DateTime(d.year, d.month, d.day);

/// El lunes de la semana de [d].
DateTime _lunes(DateTime d) => _dia(d).subtract(Duration(days: d.weekday - 1));

/// Cómo se ve el calendario: el mes entero o una semana.
enum VistaCalendario { mes, semana }

/// Calendario con vista de mes y de semana. Muestra [events] por día con el
/// color de su tipo; al elegir un día se listan sus eventos con «Unirse a la
/// reunión». Si [canManage] es true se puede crear, editar y borrar: los
/// callbacks quedan a cargo de quien use el widget, así permisos y
/// persistencia viven en cada portal.
///
/// Va centrado y con un ancho máximo: en una pantalla ancha los días se
/// estiran hasta ese ancho y no quedan pegados a un lado; en el teléfono el
/// mes se vuelve compacto y la semana, una lista de días.
class CalendarView extends StatefulWidget {
  final List<CalendarEvent> events;
  final bool canManage;
  final void Function(DateTime day)? onAddEvent;
  final void Function(CalendarEvent event)? onEditEvent;
  final Future<void> Function(CalendarEvent event)? onDeleteEvent;

  /// Con qué vista abre.
  final VistaCalendario vistaInicial;

  const CalendarView({
    super.key,
    required this.events,
    this.canManage = false,
    this.onAddEvent,
    this.onEditEvent,
    this.onDeleteEvent,
    this.vistaInicial = VistaCalendario.mes,
  });

  @override
  State<CalendarView> createState() => _CalendarViewState();
}

/// El tema de los botones delineados pinta los dos segmentos igual: el elegido
/// lleva el dorado, para que se vea en qué vista se está.
final estiloSelectorDeVista = ButtonStyle(
  backgroundColor: WidgetStateProperty.resolveWith((s) =>
      s.contains(WidgetState.selected)
          ? AppColors.gold.withValues(alpha: 0.18)
          : Colors.transparent),
  foregroundColor: WidgetStateProperty.resolveWith((s) =>
      s.contains(WidgetState.selected) ? AppColors.gold : AppColors.textSecondary),
);

class _CalendarViewState extends State<CalendarView> {
  /// Un día cualquiera del mes o de la semana a la vista.
  late DateTime _ancla;
  late DateTime _selectedDay;
  late VistaCalendario _vista = widget.vistaInicial;

  @override
  void initState() {
    super.initState();
    final hoy = _dia(DateTime.now());
    _ancla = hoy;
    _selectedDay = hoy;
  }

  List<CalendarEvent> _eventsOn(DateTime day) =>
      widget.events.where((e) => _sameDay(e.startsAt, day)).toList()
        ..sort((a, b) => a.startsAt.compareTo(b.startsAt));

  void _mover(int delta) => setState(() {
        _ancla = _vista == VistaCalendario.mes
            ? DateTime(_ancla.year, _ancla.month + delta)
            : _ancla.add(Duration(days: 7 * delta));
      });

  void _irAHoy() => setState(() {
        _ancla = _dia(DateTime.now());
        _selectedDay = _ancla;
      });

  String get _titulo {
    if (_vista == VistaCalendario.mes) return mesAnio(_ancla).toUpperCase();
    final lunes = _lunes(_ancla);
    final domingo = lunes.add(const Duration(days: 6));
    return '${diaMesCorto(lunes)} – ${diaMesCorto(domingo)} ${domingo.year}'
        .toUpperCase();
  }

  @override
  Widget build(BuildContext context) {
    return Center(
      child: ConstrainedBox(
        key: const ValueKey('calendario'),
        constraints: const BoxConstraints(maxWidth: 1100),
        child: LayoutBuilder(builder: (context, c) {
          final compacto = c.maxWidth < 640;
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _encabezado(compacto),
              const SizedBox(height: 12),
              _leyenda(),
              const SizedBox(height: 14),
              if (_vista == VistaCalendario.mes)
                _mes(compacto)
              else
                _semana(compacto),
              const SizedBox(height: 22),
              _eventosDelDia(),
            ],
          );
        }),
      ),
    );
  }

  Widget _encabezado(bool compacto) {
    final esMes = _vista == VistaCalendario.mes;
    final navegacion = Row(
      children: [
        IconButton(
          icon: const Icon(Icons.chevron_left),
          tooltip: esMes ? tr.calendarioMesAnterior : tr.calendarioSemanaAnterior,
          onPressed: () => _mover(-1),
        ),
        Expanded(
          child: FittedBox(
            fit: BoxFit.scaleDown,
            child: Text(_titulo,
                key: const ValueKey('calendario-titulo'),
                textAlign: TextAlign.center,
                style: displayHeading(fontSize: compacto ? 20 : 24)),
          ),
        ),
        IconButton(
          icon: const Icon(Icons.chevron_right),
          tooltip: esMes ? tr.calendarioMesSiguiente : tr.calendarioSemanaSiguiente,
          onPressed: () => _mover(1),
        ),
      ],
    );
    final controles = Wrap(
      spacing: 8,
      runSpacing: 8,
      alignment: compacto ? WrapAlignment.center : WrapAlignment.end,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        SegmentedButton<VistaCalendario>(
          key: const ValueKey('calendario-vista'),
          showSelectedIcon: false,
          style: estiloSelectorDeVista,
          segments: [
            ButtonSegment(
                value: VistaCalendario.mes,
                icon: const Icon(Icons.calendar_view_month, size: 16),
                label: Text(tr.calendarioVistaMes)),
            ButtonSegment(
                value: VistaCalendario.semana,
                icon: const Icon(Icons.view_week_outlined, size: 16),
                label: Text(tr.calendarioVistaSemana)),
          ],
          selected: {_vista},
          onSelectionChanged: (v) => setState(() {
            _vista = v.first;
            // La semana que se abre es la del día elegido.
            _ancla = _selectedDay;
          }),
        ),
        OutlinedButton(onPressed: _irAHoy, child: Text(tr.calendarioHoy)),
        if (widget.canManage)
          ElevatedButton.icon(
            icon: const Icon(Icons.add, size: 18),
            label: Text(tr.calendarioAgregarEvento),
            onPressed: () => widget.onAddEvent?.call(_selectedDay),
          ),
      ],
    );
    if (compacto) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [navegacion, const SizedBox(height: 8), controles],
      );
    }
    return Row(
      children: [
        Expanded(child: navegacion),
        const SizedBox(width: 16),
        controles,
      ],
    );
  }

  /// Solo los tipos que hay en el calendario: una leyenda de cinco colores
  /// para dos tipos de evento no ayuda a nadie.
  Widget _leyenda() {
    final tipos = {for (final e in widget.events) e.type};
    if (tipos.isEmpty) return const SizedBox.shrink();
    return Wrap(
      alignment: WrapAlignment.center,
      spacing: 16,
      runSpacing: 6,
      children: [
        for (final t in CalendarEventType.values.where(tipos.contains))
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 10,
                height: 10,
                decoration: BoxDecoration(
                  color: calendarEventColor(t),
                  borderRadius: BorderRadius.circular(3),
                ),
              ),
              const SizedBox(width: 6),
              Flexible(
                child: Text(calendarEventTypeLabel(t),
                    style: const TextStyle(
                        color: AppColors.textMuted, fontSize: 11.5)),
              ),
            ],
          ),
      ],
    );
  }

  Widget _diasDeLaSemana() => Row(
        children: [
          for (final w in diasDeLaSemana())
            Expanded(
              child: Text(w,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                      color: AppColors.textMuted,
                      fontSize: 11.5,
                      letterSpacing: 1.2,
                      fontWeight: FontWeight.w700)),
            ),
        ],
      );

  Widget _mes(bool compacto) {
    final primero = DateTime(_ancla.year, _ancla.month, 1);
    final inicio = _lunes(primero);
    final dias = DateTime(_ancla.year, _ancla.month + 1, 0).day;
    final semanas = ((primero.weekday - 1 + dias) / 7).ceil();
    final hoy = DateTime.now();
    final separacion = compacto ? 4.0 : 6.0;
    return Column(
      children: [
        _diasDeLaSemana(),
        const SizedBox(height: 6),
        for (var s = 0; s < semanas; s++)
          Padding(
            padding: EdgeInsets.only(bottom: separacion),
            child: Row(
              children: [
                for (var d = 0; d < 7; d++) ...[
                  if (d > 0) SizedBox(width: separacion),
                  Expanded(
                    child: _celdaDelMes(
                        inicio.add(Duration(days: s * 7 + d)), compacto, hoy),
                  ),
                ],
              ],
            ),
          ),
      ],
    );
  }

  Widget _celdaDelMes(DateTime dia, bool compacto, DateTime hoy) {
    final delMes = dia.month == _ancla.month;
    final elegido = _sameDay(dia, _selectedDay);
    final esHoy = _sameDay(dia, hoy);
    final eventos = _eventsOn(dia);
    return _Celda(
      key: ValueKey('dia-${dia.year}-${dia.month}-${dia.day}'),
      alTocar: () => setState(() => _selectedDay = dia),
      tooltip: eventos.isEmpty
          ? null
          : eventos.map((e) => '${hora(e.startsAt)} · ${_tituloDe(e)}').join('\n'),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 120),
        height: compacto ? 54 : 104,
        padding: EdgeInsets.all(compacto ? 4 : 7),
        decoration: BoxDecoration(
          color: elegido
              ? AppColors.gold.withValues(alpha: 0.16)
              : delMes
                  ? AppColors.surfaceAlt
                  : Colors.transparent,
          borderRadius: BorderRadius.circular(compacto ? 8 : 11),
          border: Border.all(
              color: elegido
                  ? AppColors.gold
                  : esHoy
                      ? AppColors.gold.withValues(alpha: 0.6)
                      : Colors.transparent,
              width: elegido ? 1.6 : 1),
        ),
        child: Column(
          crossAxisAlignment:
              compacto ? CrossAxisAlignment.center : CrossAxisAlignment.end,
          children: [
            Container(
              width: 24,
              height: 22,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: esHoy ? AppColors.relleno : Colors.transparent,
                borderRadius: BorderRadius.circular(7),
              ),
              child: Text('${dia.day}',
                  style: TextStyle(
                      fontSize: 12.5,
                      fontWeight: esHoy ? FontWeight.w800 : FontWeight.w500,
                      color: esHoy
                          ? AppColors.ink
                          : delMes
                              ? AppColors.textPrimary
                              : AppColors.textMuted.withValues(alpha: 0.45))),
            ),
            if (compacto) ...[
              const Spacer(),
              // En el teléfono no caben títulos: un punto por evento.
              if (eventos.isNotEmpty)
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    for (final e in eventos.take(3))
                      Container(
                        width: 6,
                        height: 6,
                        margin: const EdgeInsets.symmetric(horizontal: 1.5),
                        decoration: BoxDecoration(
                            color: calendarEventColor(e.type),
                            shape: BoxShape.circle),
                      ),
                  ],
                ),
              const SizedBox(height: 4),
            ] else ...[
              const SizedBox(height: 4),
              for (final e in eventos.take(2)) _Chip(evento: e),
              if (eventos.length > 2)
                Padding(
                  padding: const EdgeInsets.only(top: 2),
                  child: Text('+${eventos.length - 2}',
                      style: const TextStyle(
                          fontSize: 10.5, color: AppColors.textMuted)),
                ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _semana(bool compacto) {
    final lunes = _lunes(_ancla);
    final dias = [for (var i = 0; i < 7; i++) lunes.add(Duration(days: i))];
    final hoy = DateTime.now();
    if (compacto) {
      // En el teléfono, la semana es una lista de días.
      return Column(
        children: [
          for (final dia in dias) _filaDeLaSemana(dia, hoy),
        ],
      );
    }
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (var i = 0; i < 7; i++) ...[
          if (i > 0) const SizedBox(width: 8),
          Expanded(child: _columnaDeLaSemana(dias[i], hoy)),
        ],
      ],
    );
  }

  Widget _columnaDeLaSemana(DateTime dia, DateTime hoy) {
    final elegido = _sameDay(dia, _selectedDay);
    final esHoy = _sameDay(dia, hoy);
    final eventos = _eventsOn(dia);
    return _Celda(
      key: ValueKey('dia-${dia.year}-${dia.month}-${dia.day}'),
      alTocar: () => setState(() => _selectedDay = dia),
      child: Container(
        constraints: const BoxConstraints(minHeight: 300),
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: elegido
              ? AppColors.gold.withValues(alpha: 0.12)
              : AppColors.surfaceAlt,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
              color: elegido
                  ? AppColors.gold
                  : esHoy
                      ? AppColors.gold.withValues(alpha: 0.6)
                      : Colors.transparent),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(diaSemanaCorto(dia).toUpperCase(),
                textAlign: TextAlign.center,
                style: const TextStyle(
                    fontSize: 11,
                    letterSpacing: 1.2,
                    fontWeight: FontWeight.w700,
                    color: AppColors.textMuted)),
            const SizedBox(height: 4),
            Center(
              child: Container(
                width: 34,
                height: 34,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: esHoy ? AppColors.relleno : Colors.transparent,
                  shape: BoxShape.circle,
                ),
                child: Text('${dia.day}',
                    style: displayHeading(
                        fontSize: 18,
                        color: esHoy ? AppColors.ink : AppColors.textPrimary)),
              ),
            ),
            const SizedBox(height: 8),
            for (final e in eventos) _BloqueDeSemana(evento: e),
          ],
        ),
      ),
    );
  }

  Widget _filaDeLaSemana(DateTime dia, DateTime hoy) {
    final elegido = _sameDay(dia, _selectedDay);
    final esHoy = _sameDay(dia, hoy);
    final eventos = _eventsOn(dia);
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: _Celda(
        key: ValueKey('dia-${dia.year}-${dia.month}-${dia.day}'),
        alTocar: () => setState(() => _selectedDay = dia),
        child: Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: elegido
                ? AppColors.gold.withValues(alpha: 0.12)
                : AppColors.surfaceAlt,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
                color: elegido
                    ? AppColors.gold
                    : esHoy
                        ? AppColors.gold.withValues(alpha: 0.6)
                        : Colors.transparent),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SizedBox(
                width: 48,
                child: Column(
                  children: [
                    Text(diaSemanaCorto(dia).toUpperCase(),
                        style: const TextStyle(
                            fontSize: 10.5,
                            letterSpacing: 1,
                            color: AppColors.textMuted)),
                    Text('${dia.day}',
                        style: displayHeading(
                            fontSize: 22,
                            color: esHoy ? AppColors.gold : AppColors.textPrimary)),
                  ],
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: eventos.isEmpty
                    ? Padding(
                        padding: const EdgeInsets.only(top: 10),
                        child: Text(tr.calendarioSinEventos,
                            style: const TextStyle(
                                fontSize: 12.5, color: AppColors.textMuted)),
                      )
                    : Column(
                        children: [
                          for (final e in eventos) _BloqueDeSemana(evento: e),
                        ],
                      ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _eventosDelDia() {
    final eventos = _eventsOn(_selectedDay);
    final etiqueta = diaSemanaLargo(_selectedDay);
    final titulo = etiqueta.isEmpty
        ? etiqueta
        : '${etiqueta[0].toUpperCase()}${etiqueta.substring(1)}';
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(titulo,
            style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15)),
        const SizedBox(height: 10),
        if (eventos.isEmpty)
          Text(tr.calendarioSinEventosDia,
              style: TextStyle(color: AppColors.textMuted, fontSize: 13))
        else
          for (final e in eventos)
            _EventCard(
              event: e,
              canManage: widget.canManage,
              onEdit: widget.onEditEvent,
              onDelete: widget.onDeleteEvent,
            ),
      ],
    );
  }
}

String _tituloDe(CalendarEvent e) =>
    e.title.isEmpty ? calendarEventTypeLabel(e.type) : e.title;

/// Una celda que se toca: con el mouse, cursor de mano y una vista previa
/// de los eventos del día.
class _Celda extends StatelessWidget {
  final Widget child;
  final VoidCallback alTocar;
  final String? tooltip;
  const _Celda({super.key, required this.child, required this.alTocar, this.tooltip});

  @override
  Widget build(BuildContext context) {
    final celda = MouseRegion(
      cursor: SystemMouseCursors.click,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: alTocar,
        child: child,
      ),
    );
    if (tooltip == null) return celda;
    return Tooltip(
      message: tooltip!,
      waitDuration: const Duration(milliseconds: 300),
      child: celda,
    );
  }
}

/// Un evento en la celda del mes: su color y su título, en una línea.
class _Chip extends StatelessWidget {
  final CalendarEvent evento;
  const _Chip({required this.evento});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(top: 3),
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
      decoration: BoxDecoration(
        color: calendarEventColor(evento.type),
        borderRadius: BorderRadius.circular(5),
      ),
      child: Text(_tituloDe(evento),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(
              fontSize: 10.5,
              height: 1.25,
              fontWeight: FontWeight.w600,
              color: AppColors.tintaOscura)),
    );
  }
}

/// Un evento en la vista de semana: hora y título, con la barra de su color.
class _BloqueDeSemana extends StatelessWidget {
  final CalendarEvent evento;
  const _BloqueDeSemana({required this.evento});

  @override
  Widget build(BuildContext context) {
    final color = calendarEventColor(evento.type);
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 6),
      padding: const EdgeInsets.fromLTRB(8, 6, 6, 6),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.14),
        borderRadius: BorderRadius.circular(8),
        border: Border(left: BorderSide(color: color, width: 3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(hora(evento.startsAt),
              style: TextStyle(
                  fontSize: 10.5, fontWeight: FontWeight.w700, color: color)),
          Text(_tituloDe(evento),
              maxLines: 3,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                  fontSize: 12, height: 1.3, color: AppColors.textPrimary)),
        ],
      ),
    );
  }
}

class _EventCard extends StatelessWidget {
  final CalendarEvent event;
  final bool canManage;
  final void Function(CalendarEvent)? onEdit;
  final Future<void> Function(CalendarEvent)? onDelete;
  const _EventCard(
      {required this.event,
      required this.canManage,
      this.onEdit,
      this.onDelete});

  @override
  Widget build(BuildContext context) {
    final color = calendarEventColor(event.type);
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.surfaceAlt,
        borderRadius: BorderRadius.circular(12),
        border: Border(left: BorderSide(color: color, width: 3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(calendarEventIcon(event.type), color: color, size: 18),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                    event.title.isEmpty
                        ? calendarEventTypeLabel(event.type)
                        : event.title,
                    style: const TextStyle(
                        fontWeight: FontWeight.w700, fontSize: 14)),
              ),
              Text(hora(event.startsAt),
                  style: const TextStyle(
                      color: AppColors.textMuted, fontSize: 12)),
            ],
          ),
          const SizedBox(height: 4),
          Text(calendarEventTypeLabel(event.type),
              style: TextStyle(
                  color: color, fontSize: 11.5, fontWeight: FontWeight.w600)),
          if (event.description.isNotEmpty) ...[
            const SizedBox(height: 6),
            Text(event.description,
                style: const TextStyle(fontSize: 12.5, height: 1.4)),
          ],
          if (event.guests.isNotEmpty) ...[
            const SizedBox(height: 4),
            Text(event.guests,
                style: const TextStyle(
                    color: AppColors.textSecondary,
                    fontSize: 12,
                    fontStyle: FontStyle.italic)),
          ],
          const SizedBox(height: 10),
          Row(
            children: [
              ElevatedButton.icon(
                icon: const Icon(Icons.videocam_outlined, size: 16),
                label: Text(tr.calendarioUnirse),
                onPressed: event.meetLink.trim().isEmpty
                    ? null
                    : () => abrirReunion(context, event.meetLink),
              ),
              if (canManage) ...[
                const Spacer(),
                IconButton(
                  icon: const Icon(Icons.edit_outlined, size: 18),
                  tooltip: tr.comunEditar,
                  onPressed: () => onEdit?.call(event),
                ),
                IconButton(
                  icon: const Icon(Icons.delete_outline,
                      size: 18, color: AppColors.statusCritical),
                  tooltip: tr.comunEliminar,
                  onPressed: onDelete == null
                      ? null
                      : () async {
                          final ok = await confirmDialog(
                              context,
                              tr.calendarioEliminarEvento,
                              tr.calendarioEliminarConfirmar(event.title.isEmpty ? calendarEventTypeLabel(event.type) : event.title));
                          if (ok) await onDelete!(event);
                        },
                ),
              ],
            ],
          ),
        ],
      ),
    );
  }
}

/// Abre [showCalendarEventDialog] con las organizaciones para las que puede
/// agendar quien tiene la sesión (las pide al servidor: la suya, o todas si
/// es admin o del equipo de eduXaction). Sin respuesta, se abre igual, sin la
/// opción de toda la organización llena.
Future<void> abrirEventoDelCalendario(
  BuildContext context, {
  required DataProvider data,
  CalendarEvent? existente,
  DateTime? dia,
  required List<CalendarEventType> tipos,
  required List<Course> cursos,
  required List<(String, String)> labs,
  required Future<void> Function(List<CalendarEvent>, String?) alGuardar,
}) async {
  var organizaciones = const <(String, String)>[];
  if (tipos.contains(CalendarEventType.organizacion)) {
    try {
      organizaciones = await data.organizacionesParaAgendar();
    } on ApiException {
      // El diálogo lo dice: «No hay organizaciones para elegir».
    }
  }
  if (!context.mounted) return;
  await showCalendarEventDialog(
    context,
    existing: existente,
    initialDay: dia,
    allowedTypes: tipos,
    courses: cursos,
    labs: labs,
    organizaciones: organizaciones,
    defaultMeetLink: data.siteContent.valueOrNull?.meetingLink ?? '',
    onSave: alGuardar,
  );
}

/// Crea o edita un evento. [allowedTypes] dice para quién puede agendar
/// quien lo crea (el servidor lo vuelve a revisar): el admin, todo; el LXD,
/// un curso, un laboratorio o toda su organización; el Mentor, mentorías.
/// [courses], [labs] y [organizaciones] son lo que se puede elegir en cada
/// caso. Al crear (no al editar) se puede repetir cada 15 días.
Future<void> showCalendarEventDialog(
  BuildContext context, {
  CalendarEvent? existing,
  DateTime? initialDay,
  required List<CalendarEventType> allowedTypes,
  required List<Course> courses,
  /// `(id, nombre)` de los laboratorios que se pueden elegir.
  required List<(String, String)> labs,
  /// `(id, nombre)` de las organizaciones que se pueden elegir.
  List<(String, String)> organizaciones = const [],
  required String defaultMeetLink,
  /// [idQueSeEdita] es nulo al crear y el id del evento al editar. Va aparte
  /// de los eventos porque el llamador necesita ese dato para decidir entre
  /// crear y actualizar: pasarlo dentro de la lista no servía —al crear, el
  /// `id` de esos eventos es un marcador de posición, no un id del servidor—
  /// y por eso editar terminaba **duplicando** el evento en vez de cambiarlo.
  required Future<void> Function(
    List<CalendarEvent> events,
    String? idQueSeEdita,
  ) onSave,
}) async {
  final isEditing = existing != null;
  final title = TextEditingController(text: existing?.title ?? '');
  final description = TextEditingController(text: existing?.description ?? '');
  final guests = TextEditingController(text: existing?.guests ?? '');
  final meetLink =
      TextEditingController(text: existing?.meetLink ?? defaultMeetLink);
  var type = existing != null && allowedTypes.contains(existing.type)
      ? existing.type
      : allowedTypes.first;
  var courseId = existing?.courseId ?? (courses.isNotEmpty ? courses.first.id : '');
  var labId = existing?.laboratoryId ?? (labs.isNotEmpty ? labs.first.$1 : '');
  var clientId = existing?.clientId ??
      (organizaciones.isNotEmpty ? organizaciones.first.$1 : '');
  final fallbackDay = DateTime.now().add(const Duration(days: 1));
  final day = initialDay ?? fallbackDay;
  var start = existing?.startsAt ?? DateTime(day.year, day.month, day.day, 10, 0);
  var repeatCount = 1;
  ApiException? error;
  var guardando = false;

  String destinoLabel(CalendarEventType t) => switch (t) {
        CalendarEventType.openLearningSync => tr.calendarioDestinoCurso,
        CalendarEventType.laboratorio => tr.calendarioDestinoLaboratorio,
        CalendarEventType.organizacion => tr.calendarioDestinoOrganizacion,
        CalendarEventType.rutaImpacto => tr.eventoRutaImpacto,
        CalendarEventType.mentoria => tr.eventoMentoria,
      };

  Widget aviso(String texto, {bool alerta = false}) => Text(texto,
      style: TextStyle(
          color: alerta ? AppColors.statusWarning : AppColors.textMuted,
          fontSize: 12.5));

  Widget lista({
    required Key key,
    required String etiqueta,
    required List<(String, String)> opciones,
    required String valor,
    required void Function(String) alCambiar,
  }) =>
      DropdownButtonFormField<String>(
        key: key,
        isExpanded: true,
        initialValue: opciones.any((o) => o.$1 == valor) ? valor : null,
        decoration: InputDecoration(labelText: etiqueta),
        items: [
          for (final (id, nombre) in opciones)
            DropdownMenuItem(value: id, child: Text(nombre)),
        ],
        onChanged: (v) => alCambiar(v ?? ''),
      );

  await showDialog<void>(
    context: context,
    builder: (ctx) => StatefulBuilder(
      builder: (ctx, setState) {
        final nombreOrganizacion = organizaciones
                .where((o) => o.$1 == clientId)
                .firstOrNull
                ?.$2 ??
            '';
        final faltaDestino = switch (type) {
          CalendarEventType.openLearningSync => courseId.isEmpty,
          CalendarEventType.mentoria ||
          CalendarEventType.laboratorio =>
            labId.isEmpty,
          CalendarEventType.organizacion => clientId.isEmpty,
          CalendarEventType.rutaImpacto => false,
        };
        return AlertDialog(
          title: Text(isEditing ? tr.calendarioEditarEvento : tr.calendarioAgregarEvento,
              style: const TextStyle(fontSize: 18)),
          content: SizedBox(
            width: 480,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (error != null) ErrorBanner(error!),
                  TextField(
                    controller: title,
                    decoration: InputDecoration(labelText: tr.comunTitulo),
                    onChanged: (_) => setState(() {}),
                  ),
                  const SizedBox(height: 16),
                  if (allowedTypes.length > 1) ...[
                    Text(tr.calendarioParaQuien,
                        style: const TextStyle(
                            fontWeight: FontWeight.w700, fontSize: 13.5)),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        for (final t in allowedTypes)
                          ChoiceChip(
                            key: ValueKey('destino-${t.apiValue}'),
                            avatar: Icon(calendarEventIcon(t),
                                size: 16, color: calendarEventColor(t)),
                            label: Text(destinoLabel(t)),
                            selected: type == t,
                            // El tema no distingue el chip elegido: lleva el
                            // color de su tipo de evento.
                            showCheckmark: false,
                            selectedColor:
                                calendarEventColor(t).withValues(alpha: 0.2),
                            side: BorderSide(
                                color: type == t
                                    ? calendarEventColor(t)
                                    : AppColors.border),
                            onSelected: (_) => setState(() => type = t),
                          ),
                      ],
                    ),
                    const SizedBox(height: 14),
                  ],
                  switch (type) {
                    CalendarEventType.openLearningSync => courses.isEmpty
                        ? aviso(tr.calendarioSinCursosPropios, alerta: true)
                        : lista(
                            key: const ValueKey('elegir-curso'),
                            etiqueta: tr.busquedaTipoCurso,
                            opciones: [for (final c in courses) (c.id, c.name)],
                            valor: courseId,
                            alCambiar: (v) => setState(() => courseId = v),
                          ),
                    CalendarEventType.laboratorio ||
                    CalendarEventType.mentoria =>
                      labs.isEmpty
                          ? aviso(
                              type == CalendarEventType.mentoria
                                  ? tr.calendarioSinLaboratorios
                                  : tr.calendarioSinLabsParaElegir,
                              alerta: true)
                          : lista(
                              key: const ValueKey('elegir-laboratorio'),
                              etiqueta: tr.comunLaboratorio,
                              opciones: labs,
                              valor: labId,
                              alCambiar: (v) => setState(() => labId = v),
                            ),
                    CalendarEventType.organizacion => organizaciones.isEmpty
                        ? aviso(tr.calendarioSinOrganizaciones, alerta: true)
                        : organizaciones.length == 1
                            ? const SizedBox.shrink()
                            : lista(
                                key: const ValueKey('elegir-organizacion'),
                                etiqueta: tr.calendarioOrganizacion,
                                opciones: organizaciones,
                                valor: clientId,
                                alCambiar: (v) => setState(() => clientId = v),
                              ),
                    CalendarEventType.rutaImpacto => const SizedBox.shrink(),
                  },
                  const SizedBox(height: 8),
                  // Quién lo va a ver, en palabras.
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Icon(Icons.visibility_outlined,
                          size: 15, color: AppColors.textMuted),
                      const SizedBox(width: 6),
                      Expanded(
                        child: aviso(switch (type) {
                          CalendarEventType.openLearningSync =>
                            tr.calendarioQuienCurso,
                          CalendarEventType.laboratorio =>
                            tr.calendarioQuienLaboratorio,
                          CalendarEventType.mentoria =>
                            tr.calendarioQuienMentoria,
                          CalendarEventType.organizacion =>
                            tr.calendarioQuienOrganizacion(nombreOrganizacion),
                          CalendarEventType.rutaImpacto =>
                            tr.calendarioEventoGlobal,
                        }),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton.icon(
                          icon: const Icon(Icons.calendar_today_outlined,
                              size: 16),
                          label: Text(fechaCorta(start)),
                          onPressed: () async {
                            final picked = await showDatePicker(
                              context: ctx,
                              initialDate: start,
                              firstDate: DateTime.now()
                                  .subtract(const Duration(days: 365)),
                              lastDate:
                                  DateTime.now().add(const Duration(days: 730)),
                            );
                            if (picked != null) {
                              setState(() => start = DateTime(picked.year,
                                  picked.month, picked.day, start.hour, start.minute));
                            }
                          },
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: OutlinedButton.icon(
                          icon: const Icon(Icons.access_time, size: 16),
                          label: Text(hora(start)),
                          onPressed: () async {
                            final picked = await showTimePicker(
                              context: ctx,
                              initialTime: TimeOfDay.fromDateTime(start),
                            );
                            if (picked != null) {
                              setState(() => start = DateTime(start.year,
                                  start.month, start.day, picked.hour, picked.minute));
                            }
                          },
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),
                  TextField(
                    controller: meetLink,
                    keyboardType: TextInputType.url,
                    autocorrect: false,
                    decoration: InputDecoration(
                        labelText: tr.calendarioLinkReunion),
                  ),
                  const SizedBox(height: 14),
                  TextField(
                    controller: guests,
                    decoration: InputDecoration(
                        labelText: tr.calendarioInvitados,
                        hintText: tr.calendarioInvitadosPista),
                  ),
                  const SizedBox(height: 14),
                  TextField(
                    controller: description,
                    maxLines: 2,
                    decoration: InputDecoration(
                        labelText: tr.comunDescripcionOpcional),
                  ),
                  if (!isEditing) ...[
                    const SizedBox(height: 14),
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                              tr.calendarioRepetir,
                              style: TextStyle(fontSize: 13)),
                        ),
                        IconButton(
                          icon: const Icon(Icons.remove_circle_outline,
                              size: 20),
                          onPressed: repeatCount <= 1
                              ? null
                              : () => setState(() => repeatCount--),
                        ),
                        Text(tr.calendarioVeces(repeatCount),
                            style: const TextStyle(fontSize: 13)),
                        IconButton(
                          icon: const Icon(Icons.add_circle_outline, size: 20),
                          onPressed: repeatCount >= 12
                              ? null
                              : () => setState(() => repeatCount++),
                        ),
                      ],
                    ),
                  ],
                ],
              ),
            ),
          ),
          actions: [
            TextButton(
                onPressed: guardando ? null : () => Navigator.pop(ctx),
                child: Text(tr.comunCancelar)),
            ElevatedButton(
              onPressed: guardando || title.text.trim().isEmpty || faltaDestino
                  ? null
                  : () async {
                      // Solo el destino que el tipo lleva; lo demás, `null`
                      // (la cadena vacía el servidor la rechaza como uuid).
                      CalendarEvent evento(String id, DateTime cuando) =>
                          CalendarEvent(
                            id: id,
                            title: title.text.trim(),
                            description: description.text.trim(),
                            startsAt: cuando,
                            type: type,
                            meetLink: meetLink.text.trim(),
                            guests: guests.text.trim(),
                            courseId: type == CalendarEventType.openLearningSync
                                ? courseId
                                : null,
                            laboratoryId: type == CalendarEventType.laboratorio ||
                                    type == CalendarEventType.mentoria
                                ? labId
                                : null,
                            clientId: type == CalendarEventType.organizacion
                                ? clientId
                                : null,
                          );
                      final baseId = existing?.id ??
                          'cal_${DateTime.now().millisecondsSinceEpoch}';
                      final events = [
                        evento(baseId, start),
                        if (!isEditing)
                          for (var i = 1; i < repeatCount; i++)
                            evento('${baseId}_$i',
                                start.add(Duration(days: 15 * i))),
                      ];

                      setState(() {
                        guardando = true;
                        error = null;
                      });
                      try {
                        await onSave(events, existing?.id);
                      } on ApiException catch (e) {
                        setState(() {
                          guardando = false;
                          error = e;
                        });
                        return;
                      }
                      if (ctx.mounted) Navigator.pop(ctx);
                      if (context.mounted) {
                        showSuccessCheck(context,
                            isEditing ? tr.calendarioEventoActualizado : tr.calendarioEventoAgregado);
                      }
                    },
              child: Text(guardando ? tr.comunGuardando : tr.comunGuardar),
            ),
          ],
        );
      },
    ),
  );
}
