import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';

import '../models/models.dart';
import '../utils/app_theme.dart';
import 'common.dart';

/// Paleta semántica por tipo de evento del calendario. Elegida (y medida)
/// para leerse con claridad como relleno/barra sobre fondo casi negro
/// (#111315) y sobre las tarjetas (#22262B): las tres pasan AA (>=4.5:1)
/// contra ambos — sesión 5.8:1, ruta 10.0:1, mentoría 6.8:1 — y son
/// visualmente distintas del dorado de marca (reservado para "hoy", nunca
/// se usa como color de evento para no competir con esa señal).
Color calendarEventColor(CalendarEventType t) => switch (t) {
      CalendarEventType.openLearningSync => const Color(0xFF4C8DFF), // azul
      CalendarEventType.rutaImpacto => const Color(0xFF2DD4BF), // verde azulado
      CalendarEventType.mentoria => const Color(0xFFA78BFA), // violeta
    };

IconData calendarEventIcon(CalendarEventType t) => switch (t) {
      CalendarEventType.openLearningSync => Icons.laptop_mac_outlined,
      CalendarEventType.rutaImpacto => Icons.groups_outlined,
      CalendarEventType.mentoria => Icons.psychology_outlined,
    };

String calendarEventTypeLabel(CalendarEventType t) => switch (t) {
      CalendarEventType.openLearningSync => 'Sesión sincrónica',
      CalendarEventType.rutaImpacto => 'Evento Ruta de Impacto',
      CalendarEventType.mentoria => 'Mentoría',
    };

bool _sameDay(DateTime a, DateTime b) =>
    a.year == b.year && a.month == b.month && a.day == b.day;

/// Calendario mensual estilo Google Calendar. Muestra [events] agrupados
/// por día con un punto de color por tipo; al seleccionar un día se listan
/// sus eventos con botón "Unirse a la reunión". Si [canManage] es true
/// (LXD/Mentor/Admin) se puede crear/editar/borrar — los callbacks quedan
/// a cargo de quien use el widget, así permisos y persistencia viven en
/// cada portal, no aquí.
class CalendarView extends StatefulWidget {
  final List<CalendarEvent> events;
  final bool canManage;
  final void Function(DateTime day)? onAddEvent;
  final void Function(CalendarEvent event)? onEditEvent;
  final Future<void> Function(CalendarEvent event)? onDeleteEvent;

  const CalendarView({
    super.key,
    required this.events,
    this.canManage = false,
    this.onAddEvent,
    this.onEditEvent,
    this.onDeleteEvent,
  });

  @override
  State<CalendarView> createState() => _CalendarViewState();
}

class _CalendarViewState extends State<CalendarView> {
  late DateTime _visibleMonth;
  late DateTime _selectedDay;

  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    _visibleMonth = DateTime(now.year, now.month);
    _selectedDay = DateTime(now.year, now.month, now.day);
  }

  List<CalendarEvent> _eventsOn(DateTime day) =>
      widget.events.where((e) => _sameDay(e.start, day)).toList()
        ..sort((a, b) => a.start.compareTo(b.start));

  void _changeMonth(int delta) {
    setState(() {
      _visibleMonth =
          DateTime(_visibleMonth.year, _visibleMonth.month + delta);
    });
  }

  @override
  Widget build(BuildContext context) {
    final firstOfMonth = DateTime(_visibleMonth.year, _visibleMonth.month, 1);
    final leading = firstOfMonth.weekday - 1; // lunes=1..domingo=7
    final daysInMonth =
        DateTime(_visibleMonth.year, _visibleMonth.month + 1, 0).day;
    final totalCells = ((leading + daysInMonth) / 7).ceil() * 7;
    final gridStart = firstOfMonth.subtract(Duration(days: leading));
    final today = DateTime.now();
    final monthLabel = DateFormat('MMMM yyyy', 'es').format(_visibleMonth);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            IconButton(
              icon: const Icon(Icons.chevron_left),
              onPressed: () => _changeMonth(-1),
            ),
            Text(monthLabel.toUpperCase(),
                style: knockoutHeading(
                    fontSize: 20, fontWeight: FontWeight.w800)),
            IconButton(
              icon: const Icon(Icons.chevron_right),
              onPressed: () => _changeMonth(1),
            ),
            const Spacer(),
            if (widget.canManage)
              ElevatedButton.icon(
                icon: const Icon(Icons.add, size: 18),
                label: const Text('Agregar evento'),
                onPressed: () => widget.onAddEvent?.call(_selectedDay),
              ),
          ],
        ),
        const SizedBox(height: 10),
        _buildLegend(),
        const SizedBox(height: 12),
        LayoutBuilder(builder: (context, constraints) {
          final cellSize = (constraints.maxWidth / 7).clamp(36.0, 96.0);
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  for (final w in const ['L', 'M', 'M', 'J', 'V', 'S', 'D'])
                    SizedBox(
                      width: cellSize,
                      child: Text(w,
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                              color: AppColors.textMuted,
                              fontSize: 12,
                              fontWeight: FontWeight.w700)),
                    ),
                ],
              ),
              const SizedBox(height: 4),
              for (var row = 0; row < totalCells ~/ 7; row++)
                Row(
                  children: [
                    for (var col = 0; col < 7; col++)
                      _buildDayCell(
                          gridStart.add(Duration(days: row * 7 + col)),
                          cellSize,
                          today),
                  ],
                ),
            ],
          );
        }),
        const SizedBox(height: 20),
        _buildDayEvents(),
      ],
    );
  }

  Widget _buildLegend() {
    return Wrap(
      spacing: 16,
      runSpacing: 6,
      children: [
        for (final t in CalendarEventType.values)
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
              Text(calendarEventTypeLabel(t),
                  style: const TextStyle(
                      color: AppColors.textMuted, fontSize: 11.5)),
            ],
          ),
      ],
    );
  }

  Widget _buildDayCell(DateTime day, double size, DateTime today) {
    final inMonth = day.month == _visibleMonth.month;
    final isSelected = _sameDay(day, _selectedDay);
    final isToday = _sameDay(day, today);
    final dayEvents = _eventsOn(day);
    final hasEvents = dayEvents.isNotEmpty;
    final barColor =
        hasEvents ? calendarEventColor(dayEvents.first.type) : null;

    return _HoverableDayCell(
      onTap: () => setState(() => _selectedDay = day),
      tooltip: hasEvents
          ? dayEvents
              .map((e) =>
                  '${DateFormat('h:mm a').format(e.start)} · ${e.title.isEmpty ? calendarEventTypeLabel(e.type) : e.title}')
              .join('\n')
          : null,
      child: Container(
        width: size,
        height: size,
        margin: const EdgeInsets.all(2),
        clipBehavior: Clip.antiAlias,
        decoration: BoxDecoration(
          color: isSelected
              ? AppColors.gold.withValues(alpha: 0.18)
              : hasEvents
                  ? barColor!.withValues(alpha: 0.12)
                  : Colors.transparent,
          borderRadius: BorderRadius.circular(10),
          border: isToday
              ? Border.all(color: AppColors.gold, width: 1.6)
              : hasEvents
                  ? Border.all(color: barColor!.withValues(alpha: 0.35))
                  : null,
        ),
        child: Stack(
          children: [
            Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                if (hasEvents && size >= 56)
                  Icon(calendarEventIcon(dayEvents.first.type),
                      size: 12, color: barColor),
                Text('${day.day}',
                    style: TextStyle(
                        fontSize: 13,
                        fontWeight:
                            isToday ? FontWeight.w800 : FontWeight.w500,
                        color: inMonth
                            ? AppColors.textPrimary
                            : AppColors.textMuted.withValues(alpha: 0.4))),
              ],
            ),
            if (hasEvents)
              Positioned(
                left: 0,
                right: 0,
                bottom: 0,
                child: Container(
                  height: size >= 64 ? 5 : 4,
                  color: barColor,
                ),
              ),
            if (dayEvents.length > 1)
              Positioned(
                top: 2,
                right: 2,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 4),
                  height: 15,
                  constraints: const BoxConstraints(minWidth: 15),
                  decoration: BoxDecoration(
                    color: barColor,
                    borderRadius: BorderRadius.circular(8),
                    border:
                        Border.all(color: AppColors.background, width: 1.2),
                  ),
                  alignment: Alignment.center,
                  child: Text('${dayEvents.length}',
                      style: const TextStyle(
                          fontSize: 9,
                          fontWeight: FontWeight.w800,
                          color: Color(0xFF0B0B0C))),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildDayEvents() {
    final dayEvents = _eventsOn(_selectedDay);
    final label = DateFormat("EEEE d 'de' MMMM", 'es').format(_selectedDay);
    final capitalized = label.isEmpty
        ? label
        : label[0].toUpperCase() + label.substring(1);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(capitalized,
            style:
                const TextStyle(fontWeight: FontWeight.w700, fontSize: 15)),
        const SizedBox(height: 10),
        if (dayEvents.isEmpty)
          const Text('No hay eventos este día.',
              style: TextStyle(color: AppColors.textMuted, fontSize: 13))
        else
          for (final e in dayEvents)
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

/// Micro-interacción de una celda del día: al pasar el mouse, un ligero
/// zoom (si tiene eventos) y un tooltip con hora + título de cada evento
/// — preview rápido sin abrir nada.
class _HoverableDayCell extends StatelessWidget {
  final Widget child;
  final VoidCallback onTap;
  final String? tooltip;
  const _HoverableDayCell(
      {required this.child, required this.onTap, this.tooltip});

  @override
  Widget build(BuildContext context) {
    final content = HoverBuilder(
      cursor: SystemMouseCursors.click,
      builder: (context, hovered) => GestureDetector(
        onTap: onTap,
        child: AnimatedScale(
          scale: hovered && tooltip != null ? 1.06 : 1.0,
          duration: const Duration(milliseconds: 120),
          curve: Curves.easeOut,
          child: child,
        ),
      ),
    );
    if (tooltip == null) return content;
    return Tooltip(
      message: tooltip!,
      waitDuration: const Duration(milliseconds: 300),
      child: content,
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
              Text(DateFormat('h:mm a').format(event.start),
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
                label: const Text('Unirse a la reunión'),
                onPressed: event.meetLink.trim().isEmpty
                    ? null
                    : () => launchUrl(Uri.parse(event.meetLink)),
              ),
              if (canManage) ...[
                const Spacer(),
                IconButton(
                  icon: const Icon(Icons.edit_outlined, size: 18),
                  tooltip: 'Editar',
                  onPressed: () => onEdit?.call(event),
                ),
                IconButton(
                  icon: const Icon(Icons.delete_outline,
                      size: 18, color: AppColors.statusCritical),
                  tooltip: 'Eliminar',
                  onPressed: onDelete == null
                      ? null
                      : () async {
                          final ok = await confirmDialog(
                              context,
                              'Eliminar evento',
                              '¿Eliminar "${event.title.isEmpty ? calendarEventTypeLabel(event.type) : event.title}"? Esta acción no se puede deshacer.');
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

/// Crea o edita un evento de calendario. [allowedTypes] limita qué tipos
/// puede elegir quien lo crea (LXD solo sesiones Open Learning; Mentor solo
/// eventos de Ruta de Impacto/mentoría; Admin cualquiera). [courses]/[labs]
/// alimentan el dropdown de a qué se vincula, según el tipo elegido. Al
/// crear (no al editar) se puede repetir el evento cada 15 días varias
/// veces de una sola vez.
Future<void> showCalendarEventDialog(
  BuildContext context, {
  CalendarEvent? existing,
  DateTime? initialDay,
  required List<CalendarEventType> allowedTypes,
  required List<Course> courses,
  required List<Laboratory> labs,
  required String defaultMeetLink,
  required Future<void> Function(List<CalendarEvent> events) onSave,
}) async {
  final isEditing = existing != null;
  final title = TextEditingController(text: existing?.title ?? '');
  final description = TextEditingController(text: existing?.description ?? '');
  final guests = TextEditingController(text: existing?.guests ?? '');
  final meetLink =
      TextEditingController(text: existing?.meetLink ?? defaultMeetLink);
  var type = existing?.type ?? allowedTypes.first;
  var courseId = existing?.courseId ?? (courses.isNotEmpty ? courses.first.id : '');
  var labId = existing?.labId ?? (labs.isNotEmpty ? labs.first.id : '');
  final fallbackDay = DateTime.now().add(const Duration(days: 1));
  final day = initialDay ?? fallbackDay;
  var start = existing?.start ?? DateTime(day.year, day.month, day.day, 10, 0);
  var repeatCount = 1;

  await showDialog<void>(
    context: context,
    builder: (ctx) => StatefulBuilder(
      builder: (ctx, setState) => AlertDialog(
        title: Text(isEditing ? 'Editar evento' : 'Agregar evento',
            style: const TextStyle(fontSize: 18)),
        content: SizedBox(
          width: 460,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                TextField(
                  controller: title,
                  decoration: const InputDecoration(labelText: 'Título'),
                  onChanged: (_) => setState(() {}),
                ),
                const SizedBox(height: 14),
                DropdownButtonFormField<CalendarEventType>(
                  initialValue: type,
                  decoration: const InputDecoration(labelText: 'Tipo de evento'),
                  items: [
                    for (final t in allowedTypes)
                      DropdownMenuItem(
                          value: t, child: Text(calendarEventTypeLabel(t))),
                  ],
                  onChanged: (v) => setState(() => type = v ?? type),
                ),
                const SizedBox(height: 14),
                if (type == CalendarEventType.openLearningSync)
                  courses.isEmpty
                      ? const Text(
                          'Todavía no tienes cursos de Open Learning '
                          'propios. Crea uno en "Mis Cursos" antes de '
                          'agendar una sesión.',
                          style: TextStyle(
                              color: AppColors.statusWarning, fontSize: 12.5))
                      : DropdownButtonFormField<String>(
                          initialValue: courseId.isEmpty ? null : courseId,
                          decoration:
                              const InputDecoration(labelText: 'Curso'),
                          items: [
                            for (final c in courses)
                              DropdownMenuItem(
                                  value: c.id, child: Text(c.name)),
                          ],
                          onChanged: (v) => setState(() => courseId = v ?? ''),
                        )
                else if (type == CalendarEventType.mentoria)
                  labs.isEmpty
                      ? const Text(
                          'Todavía no tienes laboratorios asignados, así '
                          'que no hay a quién agendarle una mentoría.',
                          style: TextStyle(
                              color: AppColors.statusWarning, fontSize: 12.5))
                      : DropdownButtonFormField<String>(
                          initialValue: labId.isEmpty ? null : labId,
                          decoration: const InputDecoration(
                              labelText: 'Laboratorio'),
                          items: [
                            for (final l in labs)
                              DropdownMenuItem(
                                  value: l.id, child: Text(l.name)),
                          ],
                          onChanged: (v) => setState(() => labId = v ?? ''),
                        )
                else
                  const Text(
                      'Evento global: lo verán todos los estudiantes y '
                      'alumni Enactus de la plataforma, sin importar su '
                      'laboratorio.',
                      style: TextStyle(
                          color: AppColors.textMuted, fontSize: 12)),
                const SizedBox(height: 14),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton.icon(
                        icon: const Icon(Icons.calendar_today_outlined,
                            size: 16),
                        label: Text(
                            DateFormat('d MMM yyyy', 'es').format(start)),
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
                        label: Text(DateFormat('h:mm a').format(start)),
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
                  decoration: const InputDecoration(
                      labelText: 'Link de la reunión'),
                ),
                const SizedBox(height: 14),
                TextField(
                  controller: guests,
                  decoration: const InputDecoration(
                      labelText: 'Invitados (opcional)',
                      hintText: 'Ej: María Pérez (Bancolombia)'),
                ),
                const SizedBox(height: 14),
                TextField(
                  controller: description,
                  maxLines: 2,
                  decoration: const InputDecoration(
                      labelText: 'Descripción (opcional)'),
                ),
                if (!isEditing) ...[
                  const SizedBox(height: 14),
                  Row(
                    children: [
                      const Expanded(
                        child: Text(
                            'Repetir cada 15 días',
                            style: TextStyle(fontSize: 13)),
                      ),
                      IconButton(
                        icon: const Icon(Icons.remove_circle_outline,
                            size: 20),
                        onPressed: repeatCount <= 1
                            ? null
                            : () => setState(() => repeatCount--),
                      ),
                      Text('$repeatCount vez${repeatCount == 1 ? '' : 'es'}',
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
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Cancelar')),
          ElevatedButton(
            onPressed: () {
              final missingTarget = switch (type) {
                CalendarEventType.openLearningSync => courseId.isEmpty,
                CalendarEventType.mentoria => labId.isEmpty,
                CalendarEventType.rutaImpacto => false,
              };
              return title.text.trim().isEmpty || missingTarget;
            }()
                ? null
                : () async {
                    final eventCourseId =
                        type == CalendarEventType.openLearningSync
                            ? courseId
                            : '';
                    final eventLabId =
                        type == CalendarEventType.mentoria ? labId : '';
                    final baseId = existing?.id ??
                        'cal_${DateTime.now().millisecondsSinceEpoch}';
                    final events = <CalendarEvent>[
                      CalendarEvent(
                        id: baseId,
                        title: title.text.trim(),
                        description: description.text.trim(),
                        start: start,
                        type: type,
                        meetLink: meetLink.text.trim(),
                        guests: guests.text.trim(),
                        courseId: eventCourseId,
                        labId: eventLabId,
                      ),
                    ];
                    if (!isEditing && repeatCount > 1) {
                      for (var i = 1; i < repeatCount; i++) {
                        events.add(CalendarEvent(
                          id: '${baseId}_$i',
                          title: title.text.trim(),
                          description: description.text.trim(),
                          start: start.add(Duration(days: 15 * i)),
                          type: type,
                          meetLink: meetLink.text.trim(),
                          guests: guests.text.trim(),
                          courseId: events.first.courseId,
                          labId: events.first.labId,
                        ));
                      }
                    }
                    await onSave(events);
                    if (ctx.mounted) Navigator.pop(ctx);
                    if (context.mounted) {
                      showSuccessCheck(context,
                          isEditing ? 'Evento actualizado ✓' : 'Evento agregado ✓');
                    }
                  },
            child: const Text('Guardar'),
          ),
        ],
      ),
    ),
  );
}
