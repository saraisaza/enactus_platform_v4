import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../l10n/textos.dart';
import '../../models/models.dart';
import '../../providers/auth_provider.dart';
import '../../providers/data_provider.dart';
import '../../utils/constants.dart';
import '../../utils/formatos.dart';
import '../../widgets/async_states.dart';
import '../../utils/app_theme.dart';
import '../../widgets/calendar_view.dart'
    show
        VistaCalendario,
        calendarEventIcon,
        calendarEventTypeLabel,
        colorDeEntrega,
        colorDeEvento,
        estiloSelectorDeVista,
        leyendaDelCalendario;
import '../../widgets/common.dart';
import '../../widgets/portal_shell.dart';
import '../../widgets/visor_pdf.dart';
import 'course_detail_view.dart';

bool _sameDay(DateTime a, DateTime b) =>
    a.year == b.year && a.month == b.month && a.day == b.day;

/// Lo que el calendario pone en un día: un evento que alguien agendó o una
/// entrega con fecha.
///
/// Los dos van en el mismo lugar, pero no son lo mismo: el evento tiene hora
/// y reunión; la entrega tiene un día, y lleva al curso o al laboratorio
/// donde se entrega.
class _Item {
  final CalendarEvent? evento;
  final Entrega? entrega;
  const _Item.evento(CalendarEvent this.evento) : entrega = null;
  const _Item.entrega(Entrega this.entrega) : evento = null;

  DateTime get cuando => evento?.startsAt ?? entrega!.dueDate;

  /// Una entrega ya hecha: sigue en su día, pero ya no es algo por venir.
  bool get hecha => entrega?.done ?? false;

  /// El del laboratorio, si es de uno: el mismo de sus tarjetas.
  Color get color =>
      evento != null ? colorDeEvento(evento!) : colorDeEntrega(entrega!);

  IconData get icono => evento != null
      ? calendarEventIcon(evento!.type)
      : (hecha ? Icons.task_alt : Icons.flag_outlined);

  /// «Curso», «Laboratorio»… o de qué es la entrega.
  String get etiqueta {
    final e = evento;
    if (e != null) return calendarEventTypeLabel(e.type);
    return switch (entrega!.tipo) {
      TipoDeEntrega.actividadDeCurso => tr.calendarioEntregaDeCurso,
      TipoDeEntrega.faseDeLaboratorio => tr.calendarioFechaDeFase,
      TipoDeEntrega.actividadDeLaboratorio => tr.calendarioEntregaDeLaboratorio,
    };
  }

  String get titulo {
    final e = evento;
    if (e != null) return e.title.isEmpty ? calendarEventTypeLabel(e.type) : e.title;
    final entrega = this.entrega!;
    return entrega.title.isEmpty
        ? tr.rutaFaseNumero(entrega.phaseOrder ?? 1)
        : entrega.title;
  }

  /// De dónde es la entrega: su curso, o su laboratorio y su fase.
  String get origen {
    final entrega = this.entrega;
    if (entrega == null) return '';
    if (!entrega.esDeLaboratorio) return entrega.courseName ?? '';
    return [
      if (entrega.laboratoryName != null) entrega.laboratoryName!,
      if (entrega.tipo == TipoDeEntrega.actividadDeLaboratorio &&
          entrega.phaseOrder != null)
        tr.rutaFaseNumero(entrega.phaseOrder!),
    ].join(' · ');
  }
}

/// Calendario del estudiante — rediseño de alta fidelidad según
/// `design_handoff_portal_estudiante/README.md` (pantalla 2): grilla
/// mensual (lunes primero) + "Próximos eventos", ambos sobre
/// `DataProvider.calendarEventsFor(student)` — el sistema real de
/// [CalendarEvent] ya construido (Admin/LXD/Mentor crean los eventos), no
/// algo derivado de `availability`. Vista de solo lectura: la gestión
/// (crear/editar/eliminar) sigue viviendo en [CalendarView], usado por
/// Admin/LXD/Mentor con su propio layout de una sola columna, sin tocar.
///
/// Además de los eventos muestra las **entregas con fecha**
/// (`DataProvider.entregas`): la fecha límite de cada actividad de sus cursos
/// y de cada fase de sus laboratorios, como recordatorio. Y todo lo que es de
/// un laboratorio va con el color de ese laboratorio.
class StudentCalendarView extends StatefulWidget {
  const StudentCalendarView({super.key});

  @override
  State<StudentCalendarView> createState() => _StudentCalendarViewState();
}

class _StudentCalendarViewState extends State<StudentCalendarView> {
  late DateTime _visibleMonth;

  /// Un día de la semana a la vista, en la vista de semana.
  late DateTime _semana;
  VistaCalendario _vista = VistaCalendario.mes;

  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    _visibleMonth = DateTime(now.year, now.month);
    _semana = DateTime(now.year, now.month, now.day);
  }

  void _mover(int delta) {
    setState(() {
      if (_vista == VistaCalendario.mes) {
        _visibleMonth = DateTime(_visibleMonth.year, _visibleMonth.month + delta);
      } else {
        _semana = _semana.add(Duration(days: 7 * delta));
        _visibleMonth = DateTime(_semana.year, _semana.month);
      }
    });
  }

  void _irAHoy() {
    final now = DateTime.now();
    setState(() {
      _semana = DateTime(now.year, now.month, now.day);
      _visibleMonth = DateTime(now.year, now.month);
    });
  }

  String get _titulo {
    if (_vista == VistaCalendario.mes) return mesAnio(_visibleMonth).toUpperCase();
    final lunes = _lunes(_semana);
    final domingo = lunes.add(const Duration(days: 6));
    return '${diaMesCorto(lunes)} – ${diaMesCorto(domingo)} ${domingo.year}'
        .toUpperCase();
  }

  @override
  Widget build(BuildContext context) {
    final data = context.watch<DataProvider>();
    final eventsState = data.calendarEvents;

    final error = eventsState.errorOrNull;
    if (error != null) {
      return ContentScreenShell(
        eyebrow: mesAnio(_visibleMonth),
        title: tr.tabCalendario,
        subtitle: tr.calendarioNoTrajo,
        bodyBuilder: (context, colors, isDark) =>
            ErrorState(error, onRetry: data.reloadCalendarEvents),
      );
    }

    final events = eventsState.valueOrNull;
    if (events == null) {
      return ContentScreenShell(
        eyebrow: mesAnio(_visibleMonth),
        title: tr.tabCalendario,
        subtitle: tr.calendarioCargando,
        bodyBuilder: (context, colors, isDark) =>
            const CardListSkeleton(count: 3, height: 96),
      );
    }

    // Qué eventos ve cada rol lo decide el servidor (`ruta_impacto` es global
    // para el mundo Enactus, `mentoria` va por laboratorio y
    // `open_learning_sync` por curso). Antes ese filtro lo hacía el cliente
    // con `calendarEventsFor(student)` sobre todos los eventos de Hive.
    //
    // Las entregas llegan aparte y pueden tardar o fallar: el calendario no
    // las espera, aparecen cuando llegan.
    final entregas = data.entregas.valueOrNull ?? const <Entrega>[];
    final items = [
      for (final e in events) _Item.evento(e),
      for (final e in entregas) _Item.entrega(e),
    ];
    final monthItems =
        items.where((i) => i.cuando.year == _visibleMonth.year && i.cuando.month == _visibleMonth.month).toList();
    final today = DateTime.now();
    final todayStart = DateTime(today.year, today.month, today.day);
    final upcoming = items.where((i) => !i.cuando.isBefore(todayStart) && !i.hecha).toList()
      ..sort((a, b) => a.cuando.compareTo(b.cuando));

    return ContentScreenShell(
      eyebrow: mesAnio(_visibleMonth),
      title: tr.tabCalendario,
      subtitle: tr.calendarioSubtitulo,
      searchHint: tr.perfilBuscarPortal,
      trailingBuilder: (context, colors, isDark) => Wrap(
        spacing: 18,
        runSpacing: 8,
        children: [
          // Solo lo que hay: una leyenda de cinco colores para dos tipos de
          // evento no ayuda. Cada laboratorio, con su color y su nombre.
          for (final linea in leyendaDelCalendario(events, entregas))
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 10,
                  height: 10,
                  decoration: BoxDecoration(
                      color: linea.color, borderRadius: BorderRadius.circular(3)),
                ),
                const SizedBox(width: 8),
                Flexible(
                  child: Text(linea.texto,
                      style: TextStyle(fontSize: 12.5, color: colors.text2)),
                ),
              ],
            ),
          // Las entregas no se distinguen por color —llevan el de su
          // laboratorio— sino por la banderita.
          if (entregas.isNotEmpty)
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.flag_outlined, size: 14, color: colors.text2),
                const SizedBox(width: 6),
                Flexible(
                  child: Text(tr.calendarioEntregas,
                      style: TextStyle(fontSize: 12.5, color: colors.text2)),
                ),
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
                      tooltip: _vista == VistaCalendario.mes
                          ? tr.calendarioMesAnterior
                          : tr.calendarioSemanaAnterior,
                      onPressed: () => _mover(-1)),
                  Expanded(
                    child: FittedBox(
                      fit: BoxFit.scaleDown,
                      child: Text(_titulo,
                          key: const ValueKey('calendario-titulo'),
                          textAlign: TextAlign.center,
                          style: displayHeading(
                              fontSize: 20, fontWeight: AppWeights.display, color: colors.text)),
                    ),
                  ),
                  IconButton(
                      icon: Icon(Icons.chevron_right, color: colors.text2),
                      tooltip: _vista == VistaCalendario.mes
                          ? tr.calendarioMesSiguiente
                          : tr.calendarioSemanaSiguiente,
                      onPressed: () => _mover(1)),
                ],
              ),
              const SizedBox(height: 8),
              Wrap(
                alignment: WrapAlignment.center,
                spacing: 8,
                runSpacing: 8,
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
                      if (_vista == VistaCalendario.semana &&
                          (_semana.year != _visibleMonth.year ||
                              _semana.month != _visibleMonth.month)) {
                        _semana = _visibleMonth;
                      }
                    }),
                  ),
                  OutlinedButton(onPressed: _irAHoy, child: Text(tr.calendarioHoy)),
                ],
              ),
              const SizedBox(height: 14),
              if (_vista == VistaCalendario.mes)
                _MonthGrid(visibleMonth: _visibleMonth, items: monthItems, colors: colors)
              else
                _WeekGrid(semana: _semana, items: items, colors: colors),
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
              Text(tr.calendarioProximos.toUpperCase(),
                  style: displayHeading(
                      fontSize: 24, fontWeight: AppWeights.display, color: colors.text)),
              const SizedBox(height: 14),
              if (upcoming.isEmpty)
                Text(tr.calendarioSinProximos,
                    style: TextStyle(fontSize: 13.5, color: colors.text3))
              else
                for (final i in upcoming) _UpcomingRow(item: i, colors: colors),
            ],
          ),
        );

        // Solo sin ningún evento ni entrega: si se mostrara al llegar a un mes
        // vacío, se irían con él las flechas y no habría cómo volver.
        if (items.isEmpty) {
          return EmptyState(
            icon: Icons.event_busy_outlined,
            title: tr.calendarioAgendaDespejada,
            message: tr.calendarioAgendaDespejadaTexto,
            primaryLabel: tr.comunActualizar,
            onPrimary: () => showAppSnack(context, tr.comunActualizado),
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

DateTime _lunes(DateTime d) =>
    DateTime(d.year, d.month, d.day).subtract(Duration(days: d.weekday - 1));

List<_Item> _delDia(List<_Item> items, DateTime day) =>
    items.where((i) => _sameDay(i.cuando, day)).toList()
      ..sort((a, b) => a.cuando.compareTo(b.cuando));

/// La semana: siete columnas en una pantalla ancha, una lista de días en el
/// teléfono. Tocar un evento abre su detalle, como en el mes.
class _WeekGrid extends StatelessWidget {
  final DateTime semana;
  final List<_Item> items;
  final ContentColors colors;
  const _WeekGrid({required this.semana, required this.items, required this.colors});

  @override
  Widget build(BuildContext context) {
    final lunes = _lunes(semana);
    final dias = [for (var i = 0; i < 7; i++) lunes.add(Duration(days: i))];
    final hoy = DateTime.now();
    return LayoutBuilder(builder: (context, c) {
      if (c.maxWidth < 600) {
        return Column(
          children: [
            for (final dia in dias) _fila(context, dia, hoy),
          ],
        );
      }
      return Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          for (var i = 0; i < 7; i++) ...[
            if (i > 0) const SizedBox(width: 8),
            Expanded(child: _columna(context, dias[i], hoy)),
          ],
        ],
      );
    });
  }

  Widget _bloque(BuildContext context, _Item item) {
    final color = item.color;
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      child: GestureDetector(
        onTap: () => _mostrarDia(context, [item], colors),
        child: Container(
          width: double.infinity,
          margin: const EdgeInsets.only(bottom: 6),
          padding: const EdgeInsets.fromLTRB(8, 6, 6, 6),
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.16),
            borderRadius: BorderRadius.circular(8),
            border: Border(left: BorderSide(color: color, width: 3)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Un evento dice su hora; una entrega no tiene: dice que lo es.
              if (item.evento != null)
                Text(hora(item.cuando),
                    style: TextStyle(
                        fontSize: 10.5, fontWeight: FontWeight.w700, color: colors.text2))
              else
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(item.icono, size: 12, color: colors.text2),
                    const SizedBox(width: 4),
                    Flexible(
                      child: Text(
                          item.hecha ? tr.calendarioEntregaHecha : tr.rutaEntrega,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                              fontSize: 10.5,
                              fontWeight: FontWeight.w700,
                              color: colors.text2)),
                    ),
                  ],
                ),
              Text(item.titulo,
                  maxLines: 3,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(fontSize: 12, height: 1.3, color: colors.text)),
            ],
          ),
        ),
      ),
    );
  }

  Widget _columna(BuildContext context, DateTime dia, DateTime hoy) {
    final esHoy = _sameDay(dia, hoy);
    return Container(
      constraints: const BoxConstraints(minHeight: 280),
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: esHoy ? colors.goldSoft : colors.surface2,
        border: esHoy ? Border.all(color: colors.goldInk) : null,
        borderRadius: BorderRadius.circular(11),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(diaSemanaCorto(dia).toUpperCase(),
              textAlign: TextAlign.center,
              style: TextStyle(
                  fontSize: 11, letterSpacing: 1.2, fontWeight: FontWeight.w600, color: colors.text3)),
          Text('${dia.day}',
              textAlign: TextAlign.center,
              style: displayHeading(
                  fontSize: 20, fontWeight: AppWeights.display,
                  color: esHoy ? colors.goldInk : colors.text)),
          const SizedBox(height: 8),
          for (final i in _delDia(items, dia)) _bloque(context, i),
        ],
      ),
    );
  }

  Widget _fila(BuildContext context, DateTime dia, DateTime hoy) {
    final esHoy = _sameDay(dia, hoy);
    final delDia = _delDia(items, dia);
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: esHoy ? colors.goldSoft : colors.surface2,
        border: esHoy ? Border.all(color: colors.goldInk) : null,
        borderRadius: BorderRadius.circular(11),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 48,
            child: Column(
              children: [
                Text(diaSemanaCorto(dia).toUpperCase(),
                    style: TextStyle(fontSize: 10.5, letterSpacing: 1, color: colors.text3)),
                Text('${dia.day}',
                    style: displayHeading(
                        fontSize: 22, fontWeight: AppWeights.display,
                        color: esHoy ? colors.goldInk : colors.text)),
              ],
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: delDia.isEmpty
                ? Padding(
                    padding: const EdgeInsets.only(top: 10),
                    child: Text(tr.calendarioSinEventos,
                        style: TextStyle(fontSize: 12.5, color: colors.text3)),
                  )
                : Column(children: [for (final i in delDia) _bloque(context, i)]),
          ),
        ],
      ),
    );
  }
}

class _MonthGrid extends StatelessWidget {
  final DateTime visibleMonth;
  final List<_Item> items;
  final ContentColors colors;
  const _MonthGrid({required this.visibleMonth, required this.items, required this.colors});

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
            for (final w in diasDeLaSemana())
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
                          items: _delDia(items, gridStart.add(Duration(days: row * 7 + col))),
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
  final List<_Item> items;
  final ContentColors colors;
  const _DayCell(
      {required this.day,
      required this.visibleMonth,
      required this.today,
      required this.items,
      required this.colors});

  /// Un evento va relleno con su color. Una entrega va delineada y con su
  /// banderita: en el mismo día se distingue de un vistazo qué es una reunión
  /// y qué es algo por entregar.
  Widget _marca(_Item item) {
    final color = item.color;
    if (item.evento != null) {
      return Container(
        width: double.infinity,
        margin: const EdgeInsets.only(top: 3),
        padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 4),
        decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(6)),
        child: Text(item.titulo,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            // La tinta se elige según el fondo: sobre el ámbar de un
            // laboratorio el blanco no se lee.
            style: TextStyle(fontSize: 10.5, height: 1.3, color: inkSobre(color))),
      );
    }
    return Container(
      key: ValueKey('entrega-${item.entrega!.id}'),
      width: double.infinity,
      margin: const EdgeInsets.only(top: 3),
      padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.16),
        border: Border.all(color: color),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Row(
        children: [
          Icon(item.icono, size: 11, color: colors.text),
          const SizedBox(width: 3),
          Expanded(
            child: Text(item.titulo,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(fontSize: 10.5, height: 1.3, color: colors.text)),
          ),
        ],
      ),
    );
  }

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
          for (final i in items.take(2)) _marca(i),
          if (items.length > 2)
            Padding(
              padding: const EdgeInsets.only(top: 3),
              child: Text('+${items.length - 2}',
                  style: TextStyle(fontSize: 10.5, color: colors.text3)),
            ),
        ],
      ),
    );

    if (items.isEmpty) return cell;
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      child: GestureDetector(
        onTap: () => _mostrarDia(context, items, colors),
        child: cell,
      ),
    );
  }
}

class _UpcomingRow extends StatelessWidget {
  final _Item item;
  final ContentColors colors;
  const _UpcomingRow({required this.item, required this.colors});

  @override
  Widget build(BuildContext context) {
    final color = item.color;
    final evento = item.evento;
    // Del evento, su hora y sus invitados. De la entrega, qué es y de dónde.
    final detalle = evento != null
        ? '${hora(evento.startsAt)}'
            '${evento.guests.isEmpty ? '' : ' · ${evento.guests}'}'
        : [item.etiqueta, if (item.origen.isNotEmpty) item.origen].join(' · ');
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: HoverBuilder(
        cursor: SystemMouseCursors.click,
        builder: (context, hover) => GestureDetector(
          onTap: () => _mostrarDia(context, [item], colors),
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
                    Text('${item.cuando.day}',
                        style: displayHeading(
                            fontSize: 22, fontWeight: AppWeights.display, color: color)),
                    Text(diaSemanaCorto(item.cuando).toUpperCase(),
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
                    Text(item.titulo,
                        style: TextStyle(
                            fontSize: 13.5,
                            color: hover ? colors.goldInk : colors.text)),
                    const SizedBox(height: 2),
                    Row(
                      children: [
                        if (evento == null) ...[
                          Icon(item.icono, size: 13, color: colors.text3),
                          const SizedBox(width: 4),
                        ],
                        Expanded(
                          child: Text(detalle,
                              style: TextStyle(fontSize: 12, color: colors.text3)),
                        ),
                      ],
                    ),
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

/// Detalle de lo que hay en un día. De un evento: hora, descripción,
/// invitados y el botón para unirse a la reunión — sin esto, un evento en
/// el calendario del estudiante era solo un chip de color sin forma de
/// ver el link ni el resto de la información. De una entrega: de qué curso o
/// laboratorio es, si ya la hizo, y el botón que lleva a entregarla.
Future<void> _mostrarDia(
    BuildContext context, List<_Item> items, ContentColors colors) {
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
                  Expanded(
                    child: Text(diaSemanaLargo(items.first.cuando),
                        style: TextStyle(
                            fontSize: 15, fontWeight: FontWeight.w700, color: colors.text)),
                  ),
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
                    children: [
                      for (final i in items)
                        if (i.evento != null)
                          _EventDetailTile(event: i.evento!, colors: colors)
                        else
                          _EntregaDetailTile(item: i, colors: colors),
                    ],
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
    final color = colorDeEvento(event);
    final hasLink = event.meetLink.trim().isNotEmpty;
    // De qué curso o laboratorio es, si el servidor lo dijo.
    final origen = [
      calendarEventTypeLabel(event.type),
      if (event.courseName?.isNotEmpty ?? false) event.courseName!,
      if (event.laboratoryName?.isNotEmpty ?? false) event.laboratoryName!,
    ].join(' · ');
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
              Text(hora(event.startsAt),
                  style: TextStyle(color: colors.text3, fontSize: 12)),
            ],
          ),
          const SizedBox(height: 4),
          // En el color del texto y no en el del laboratorio: el ámbar de un
          // laboratorio no se lee como letra sobre el fondo claro.
          Text(origen,
              style: TextStyle(
                  color: colors.text2, fontSize: 11.5, fontWeight: FontWeight.w600)),
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
            label: Text(tr.calendarioUnirse),
            // En la app de Meet o Zoom si está instalada, no en un
            // navegador dentro de eduXaction.
            onPressed: hasLink ? () => abrirReunion(context, event.meetLink) : null,
          ),
        ],
      ),
    );
  }
}

/// Una entrega en el detalle del día: qué hay que entregar, de dónde es, si
/// ya está hecha, y el botón que lleva al curso o al laboratorio.
class _EntregaDetailTile extends StatelessWidget {
  final _Item item;
  final ContentColors colors;
  const _EntregaDetailTile({required this.item, required this.colors});

  @override
  Widget build(BuildContext context) {
    final entrega = item.entrega!;
    final color = item.color;
    final cursoId = entrega.esDeLaboratorio ? null : entrega.courseId;
    final labId = entrega.esDeLaboratorio ? entrega.laboratoryId : null;
    final estado = entrega.done
        ? (entrega.tipo == TipoDeEntrega.faseDeLaboratorio
            ? tr.leccionCompletada
            : tr.calendarioEntregaHecha)
        : tr.calificacionPendiente;

    // El diálogo se cierra antes de navegar: si quedara abierto, al volver
    // del curso seguiría ahí, tapando el calendario.
    void ir() {
      final navegador = Navigator.of(context);
      final rol = context.read<AuthProvider>().currentUser?.role;
      navegador.pop();
      if (cursoId != null) {
        navegador.push(MaterialPageRoute(
            settings: RouteSettings(name: '${AppRoutes.courses}/$cursoId'),
            builder: (_) => CourseDetailView(courseId: cursoId)));
      } else if (labId != null && rol != null) {
        navegador.pushNamed('${AppRoutes.forRole(rol)}/lab/$labId');
      }
    }

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
              Icon(item.icono, color: colors.text, size: 18),
              const SizedBox(width: 8),
              Expanded(
                child: Text(item.titulo,
                    style: TextStyle(fontWeight: FontWeight.w700, fontSize: 14, color: colors.text)),
              ),
              Text(estado, style: TextStyle(color: colors.text3, fontSize: 12)),
            ],
          ),
          const SizedBox(height: 4),
          Text([item.etiqueta, if (item.origen.isNotEmpty) item.origen].join(' · '),
              style: TextStyle(
                  color: colors.text2, fontSize: 11.5, fontWeight: FontWeight.w600)),
          const SizedBox(height: 8),
          Text(tr.calendarioVenceEsteDia,
              style: TextStyle(fontSize: 12.5, height: 1.4, color: colors.text2)),
          if (cursoId != null || labId != null) ...[
            const SizedBox(height: 12),
            ElevatedButton.icon(
              icon: const Icon(Icons.arrow_forward, size: 16),
              label: Text(
                  cursoId != null ? tr.calendarioIrAlCurso : tr.calendarioIrAlLaboratorio),
              onPressed: ir,
            ),
          ],
        ],
      ),
    );
  }
}
