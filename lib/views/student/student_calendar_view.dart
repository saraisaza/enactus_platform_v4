import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../models/models.dart';
import '../../providers/auth_provider.dart';
import '../../providers/data_provider.dart';
import '../../utils/app_theme.dart';
import '../../widgets/calendar_view.dart'
    show calendarEventColor, calendarEventIcon, calendarEventTypeLabel;
import '../../widgets/common.dart';
import '../../widgets/portal_shell.dart';

bool _sameDay(DateTime a, DateTime b) =>
    a.year == b.year && a.month == b.month && a.day == b.day;

/// Calendario del estudiante — rediseño de alta fidelidad según
/// `design_handoff_portal_estudiante/README.md` (pantalla 2): grilla
/// mensual (lunes primero) + "Próximos eventos", ambos sobre
/// `DataProvider.calendarEventsFor(student)` — el sistema real de
/// [CalendarEvent] ya construido (Admin/LXD/Mentor crean los eventos), no
/// algo derivado de `availability`. Vista de solo lectura: la gestión
/// (crear/editar/eliminar) sigue viviendo en [CalendarView], usado por
/// Admin/LXD/Mentor con su propio layout de una sola columna, sin tocar.
class StudentCalendarView extends StatefulWidget {
  const StudentCalendarView({super.key});

  @override
  State<StudentCalendarView> createState() => _StudentCalendarViewState();
}

class _StudentCalendarViewState extends State<StudentCalendarView> {
  late DateTime _visibleMonth;

  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    _visibleMonth = DateTime(now.year, now.month);
  }

  void _changeMonth(int delta) {
    setState(() {
      _visibleMonth = DateTime(_visibleMonth.year, _visibleMonth.month + delta);
    });
  }

  @override
  Widget build(BuildContext context) {
    final data = context.watch<DataProvider>();
    final student = context.watch<AuthProvider>().currentUser!;
    final events = data.calendarEventsFor(student);
    final monthEvents =
        events.where((e) => e.start.year == _visibleMonth.year && e.start.month == _visibleMonth.month).toList();
    final today = DateTime.now();
    final todayStart = DateTime(today.year, today.month, today.day);
    final upcoming = events.where((e) => !e.start.isBefore(todayStart)).toList()
      ..sort((a, b) => a.start.compareTo(b.start));

    return ContentScreenShell(
      eyebrow: DateFormat('MMMM yyyy', 'es').format(_visibleMonth),
      title: 'Calendario',
      subtitle: 'Sesiones sincrónicas de tus cursos y eventos de tu Ruta de Impacto.',
      searchHint: 'Buscar en el portal',
      trailingBuilder: (context, colors, isDark) => Wrap(
        spacing: 18,
        runSpacing: 8,
        children: [
          for (final t in CalendarEventType.values)
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 10,
                  height: 10,
                  decoration: BoxDecoration(
                      color: calendarEventColor(t), borderRadius: BorderRadius.circular(3)),
                ),
                const SizedBox(width: 8),
                Text(calendarEventTypeLabel(t),
                    style: TextStyle(fontSize: 12.5, color: colors.text2)),
              ],
            ),
        ],
      ),
      bodyBuilder: (context, colors, isDark) {
        final month = Container(
          padding: const EdgeInsets.fromLTRB(24, 22, 24, 24),
          decoration: BoxDecoration(
            color: colors.surface,
            border: Border.all(color: colors.border),
            borderRadius: BorderRadius.circular(18),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                children: [
                  IconButton(
                      icon: Icon(Icons.chevron_left, color: colors.text2),
                      onPressed: () => _changeMonth(-1)),
                  Expanded(
                    child: Text(
                        DateFormat('MMMM yyyy', 'es').format(_visibleMonth).toUpperCase(),
                        textAlign: TextAlign.center,
                        style: knockoutHeading(
                            fontSize: 20, fontWeight: FontWeight.w800, color: colors.text)),
                  ),
                  IconButton(
                      icon: Icon(Icons.chevron_right, color: colors.text2),
                      onPressed: () => _changeMonth(1)),
                ],
              ),
              const SizedBox(height: 12),
              _MonthGrid(visibleMonth: _visibleMonth, events: monthEvents, colors: colors),
            ],
          ),
        );

        final upcomingCard = Container(
          padding: const EdgeInsets.fromLTRB(24, 22, 24, 22),
          decoration: BoxDecoration(
            color: colors.surface,
            border: Border.all(color: colors.border),
            borderRadius: BorderRadius.circular(18),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text('Próximos eventos'.toUpperCase(),
                  style: knockoutHeading(
                      fontSize: 24, fontWeight: FontWeight.w800, color: colors.text)),
              const SizedBox(height: 14),
              if (upcoming.isEmpty)
                Text('No tienes próximos eventos.',
                    style: TextStyle(fontSize: 13.5, color: colors.text3))
              else
                for (final e in upcoming) _UpcomingRow(event: e, colors: colors),
            ],
          ),
        );

        if (monthEvents.isEmpty && upcoming.isEmpty) {
          return EmptyState(
            icon: Icons.event_busy_outlined,
            title: 'Agenda despejada',
            message: 'No tienes sesiones ni entregas programadas este mes.',
            primaryLabel: 'Actualizar',
            onPrimary: () => showAppSnack(context, 'Actualizado'),
            colors: colors,
          );
        }

        return LayoutBuilder(builder: (context, c) {
          if (c.maxWidth > 800) {
            return Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(flex: 210, child: month),
                const SizedBox(width: 22),
                Expanded(flex: 100, child: upcomingCard),
              ],
            );
          }
          return Column(children: [month, const SizedBox(height: 22), upcomingCard]);
        });
      },
    );
  }
}

class _MonthGrid extends StatelessWidget {
  final DateTime visibleMonth;
  final List<CalendarEvent> events;
  final ContentColors colors;
  const _MonthGrid({required this.visibleMonth, required this.events, required this.colors});

  List<CalendarEvent> _eventsOn(DateTime day) =>
      events.where((e) => _sameDay(e.start, day)).toList()
        ..sort((a, b) => a.start.compareTo(b.start));

  @override
  Widget build(BuildContext context) {
    final firstOfMonth = DateTime(visibleMonth.year, visibleMonth.month, 1);
    final leading = firstOfMonth.weekday - 1; // lunes=1..domingo=7
    final daysInMonth = DateTime(visibleMonth.year, visibleMonth.month + 1, 0).day;
    final totalCells = ((leading + daysInMonth) / 7).ceil() * 7;
    final gridStart = firstOfMonth.subtract(Duration(days: leading));
    final today = DateTime.now();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            for (final w in const ['LUN', 'MAR', 'MIÉ', 'JUE', 'VIE', 'SÁB', 'DOM'])
              Expanded(
                child: Text(w,
                    textAlign: TextAlign.center,
                    style: TextStyle(
                        fontSize: 11.5,
                        letterSpacing: 11.5 * 0.14,
                        fontWeight: FontWeight.w600,
                        color: colors.text3)),
              ),
          ],
        ),
        const SizedBox(height: 8),
        for (var row = 0; row < totalCells ~/ 7; row++)
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                for (var col = 0; col < 7; col++) ...[
                  if (col > 0) const SizedBox(width: 8),
                  Expanded(
                      child: _DayCell(
                          day: gridStart.add(Duration(days: row * 7 + col)),
                          visibleMonth: visibleMonth,
                          today: today,
                          events: _eventsOn(gridStart.add(Duration(days: row * 7 + col))),
                          colors: colors)),
                ],
              ],
            ),
          ),
      ],
    );
  }
}

class _DayCell extends StatelessWidget {
  final DateTime day;
  final DateTime visibleMonth;
  final DateTime today;
  final List<CalendarEvent> events;
  final ContentColors colors;
  const _DayCell(
      {required this.day,
      required this.visibleMonth,
      required this.today,
      required this.events,
      required this.colors});

  @override
  Widget build(BuildContext context) {
    final inMonth = day.month == visibleMonth.month;
    final isToday = _sameDay(day, today);
    if (!inMonth) return const SizedBox(height: 96);

    final cell = Container(
      constraints: const BoxConstraints(minHeight: 96),
      padding: const EdgeInsets.fromLTRB(9, 9, 9, 8),
      decoration: BoxDecoration(
        color: isToday ? colors.goldSoft : colors.surface2,
        border: isToday ? Border.all(color: colors.goldInk) : null,
        borderRadius: BorderRadius.circular(11),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Container(
            width: 22,
            height: 22,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: isToday ? colors.goldInk : Colors.transparent,
              borderRadius: BorderRadius.circular(7),
            ),
            child: Text('${day.day}',
                style: TextStyle(
                    fontSize: 12,
                    fontWeight: isToday ? FontWeight.w700 : FontWeight.w500,
                    color: isToday ? colors.bg : colors.text3)),
          ),
          const SizedBox(height: 4),
          for (final e in events.take(2))
            Container(
              width: double.infinity,
              margin: const EdgeInsets.only(top: 3),
              padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 4),
              decoration: BoxDecoration(
                  color: calendarEventColor(e.type), borderRadius: BorderRadius.circular(6)),
              child: Text(
                  e.title.isEmpty ? calendarEventTypeLabel(e.type) : e.title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontSize: 10.5, height: 1.3, color: Colors.white)),
            ),
          if (events.length > 2)
            Padding(
              padding: const EdgeInsets.only(top: 3),
              child: Text('+${events.length - 2}',
                  style: TextStyle(fontSize: 10.5, color: colors.text3)),
            ),
        ],
      ),
    );

    if (events.isEmpty) return cell;
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      child: GestureDetector(
        onTap: () => showEventsDialog(context, events, colors),
        child: cell,
      ),
    );
  }
}

class _UpcomingRow extends StatelessWidget {
  final CalendarEvent event;
  final ContentColors colors;
  const _UpcomingRow({required this.event, required this.colors});

  @override
  Widget build(BuildContext context) {
    final color = calendarEventColor(event.type);
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: HoverBuilder(
        cursor: SystemMouseCursors.click,
        builder: (context, hover) => GestureDetector(
          onTap: () => showEventsDialog(context, [event], colors),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 52,
                padding: const EdgeInsets.symmetric(vertical: 8),
                decoration: BoxDecoration(
                    color: colors.surface2, borderRadius: BorderRadius.circular(11)),
                child: Column(
                  children: [
                    Text('${event.start.day}',
                        style: knockoutHeading(
                            fontSize: 22, fontWeight: FontWeight.w800, color: color)),
                    Text(DateFormat('EEE', 'es').format(event.start).toUpperCase(),
                        style: TextStyle(
                            fontSize: 10.5, letterSpacing: 10.5 * 0.1, color: colors.text3)),
                  ],
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(event.title.isEmpty ? calendarEventTypeLabel(event.type) : event.title,
                        style: TextStyle(
                            fontSize: 13.5,
                            color: hover ? colors.goldInk : colors.text)),
                    const SizedBox(height: 2),
                    Text(
                        '${DateFormat('h:mm a').format(event.start)}'
                        '${event.guests.isEmpty ? '' : ' · ${event.guests}'}',
                        style: TextStyle(fontSize: 12, color: colors.text3)),
                  ],
                ),
              ),
              Icon(Icons.chevron_right, size: 18, color: colors.text3),
            ],
          ),
        ),
      ),
    );
  }
}

/// Detalle de uno o varios eventos del mismo día: hora, descripción,
/// invitados y el botón para unirse a la reunión — sin esto, un evento en
/// el calendario del estudiante era solo un chip de color sin forma de
/// ver el link ni el resto de la información.
Future<void> showEventsDialog(
    BuildContext context, List<CalendarEvent> events, ContentColors colors) {
  return showDialog<void>(
    context: context,
    builder: (ctx) => Dialog(
      backgroundColor: colors.surface,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
      insetPadding: const EdgeInsets.all(24),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 480, maxHeight: 560),
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Text(DateFormat("EEEE d 'de' MMMM", 'es').format(events.first.start),
                      style: TextStyle(
                          fontSize: 15, fontWeight: FontWeight.w700, color: colors.text)),
                  const Spacer(),
                  IconButton(
                    icon: Icon(Icons.close, size: 20, color: colors.text3),
                    onPressed: () => Navigator.pop(ctx),
                  ),
                ],
              ),
              Flexible(
                child: SingleChildScrollView(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [for (final e in events) _EventDetailTile(event: e, colors: colors)],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    ),
  );
}

class _EventDetailTile extends StatelessWidget {
  final CalendarEvent event;
  final ContentColors colors;
  const _EventDetailTile({required this.event, required this.colors});

  @override
  Widget build(BuildContext context) {
    final color = calendarEventColor(event.type);
    final hasLink = event.meetLink.trim().isNotEmpty;
    return Container(
      margin: const EdgeInsets.only(top: 14),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: colors.surface2,
        borderRadius: BorderRadius.circular(14),
        border: Border(left: BorderSide(color: color, width: 3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              Icon(calendarEventIcon(event.type), color: color, size: 18),
              const SizedBox(width: 8),
              Expanded(
                child: Text(event.title.isEmpty ? calendarEventTypeLabel(event.type) : event.title,
                    style: TextStyle(fontWeight: FontWeight.w700, fontSize: 14, color: colors.text)),
              ),
              Text(DateFormat('h:mm a').format(event.start),
                  style: TextStyle(color: colors.text3, fontSize: 12)),
            ],
          ),
          const SizedBox(height: 4),
          Text(calendarEventTypeLabel(event.type),
              style: TextStyle(color: color, fontSize: 11.5, fontWeight: FontWeight.w600)),
          if (event.description.isNotEmpty) ...[
            const SizedBox(height: 8),
            Text(event.description,
                style: TextStyle(fontSize: 12.5, height: 1.4, color: colors.text2)),
          ],
          if (event.guests.isNotEmpty) ...[
            const SizedBox(height: 6),
            Text(event.guests,
                style: TextStyle(
                    color: colors.text2, fontSize: 12, fontStyle: FontStyle.italic)),
          ],
          const SizedBox(height: 12),
          ElevatedButton.icon(
            icon: const Icon(Icons.videocam_outlined, size: 16),
            label: const Text('Unirse a la reunión'),
            onPressed: hasLink ? () => launchUrl(Uri.parse(event.meetLink)) : null,
          ),
        ],
      ),
    );
  }
}
