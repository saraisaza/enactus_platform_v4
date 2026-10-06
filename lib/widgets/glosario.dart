import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show KeyDownEvent, LogicalKeyboardKey;
import 'package:provider/provider.dart';

import '../l10n/textos.dart';
import '../models/glossary.dart';
import '../models/models.dart';
import '../providers/data_provider.dart';
import '../services/api_errors.dart';
import '../utils/app_theme.dart';
import '../utils/glosario_texto.dart';
import 'app_image.dart';
import 'common.dart';

/// El glosario como lo ve el estudiante: el texto de la lección con las
/// palabras resaltadas, el glosario de cada lección y el de cada módulo, con
/// tarjetas que se expanden, buscador, letras A–Z y modo repaso.
///
/// Todo sale de UN pedido por curso (`DataProvider.glossaryOf`): cualquier
/// lección puede resaltar palabras de cualquier módulo, y un término
/// relacionado puede vivir en otro.

/// Duración de las animaciones del glosario: cortas, para que expandir o
/// voltear una tarjeta no se sienta lento al recorrer muchas.
const _rapida = Duration(milliseconds: 200);
const _media = Duration(milliseconds: 250);
const _volteo = Duration(milliseconds: 300);

Duration _animacion(BuildContext context, Duration normal) =>
    MediaQuery.maybeDisableAnimationsOf(context) ?? false
        ? Duration.zero
        : normal;

// ---------------------------------------------------------------------------
// Texto con palabras resaltadas
// ---------------------------------------------------------------------------

/// [texto] con cada término del glosario resaltado: al pasar el mouse, al
/// tocarlo o al llegar con el teclado muestra su definición corta.
///
/// Con `Enter` sobre una palabra resaltada se abre la tarjeta completa
/// ([onAbrir]).
class TextoConGlosario extends StatelessWidget {
  final String texto;
  final Iterable<GlossaryTerm> terminos;
  final TextStyle? style;
  final void Function(GlossaryTerm termino)? onAbrir;

  const TextoConGlosario({
    super.key,
    required this.texto,
    required this.terminos,
    this.style,
    this.onAbrir,
  });

  @override
  Widget build(BuildContext context) {
    final base = DefaultTextStyle.of(context).style.merge(style);
    return Text.rich(TextSpan(
      style: base,
      children: [
        for (final s in segmentarConGlosario(texto, terminos))
          if (s.termino == null)
            TextSpan(text: s.texto)
          else
            WidgetSpan(
              alignment: PlaceholderAlignment.baseline,
              baseline: TextBaseline.alphabetic,
              child: _PalabraDelGlosario(
                texto: s.texto,
                termino: s.termino!,
                style: base,
                onAbrir: onAbrir,
              ),
            ),
      ],
    ));
  }
}

class _PalabraDelGlosario extends StatefulWidget {
  final String texto;
  final GlossaryTerm termino;
  final TextStyle style;
  final void Function(GlossaryTerm termino)? onAbrir;

  const _PalabraDelGlosario({
    required this.texto,
    required this.termino,
    required this.style,
    this.onAbrir,
  });

  @override
  State<_PalabraDelGlosario> createState() => _PalabraDelGlosarioState();
}

class _PalabraDelGlosarioState extends State<_PalabraDelGlosario> {
  final _tooltip = GlobalKey<TooltipState>();
  bool _enfocada = false;

  @override
  Widget build(BuildContext context) {
    final t = widget.termino;
    return Tooltip(
      key: _tooltip,
      richMessage: TextSpan(children: [
        TextSpan(
            text: t.word,
            style: TextStyle(
                fontWeight: FontWeight.w700, color: AppColors.gold)),
        TextSpan(text: '\n${t.shortDefinition}'),
      ]),
      // Tocar en el teléfono; en la web, además, pasar el mouse.
      triggerMode: TooltipTriggerMode.tap,
      showDuration: const Duration(seconds: 8),
      waitDuration: const Duration(milliseconds: 200),
      constraints: const BoxConstraints(maxWidth: 320),
      mouseCursor: SystemMouseCursors.help,
      child: Focus(
        onFocusChange: (enfocada) {
          setState(() => _enfocada = enfocada);
          if (enfocada) _tooltip.currentState?.ensureTooltipVisible();
        },
        onKeyEvent: (node, event) {
          final abrir = widget.onAbrir;
          if (abrir != null &&
              event is KeyDownEvent &&
              (event.logicalKey == LogicalKeyboardKey.enter ||
                  event.logicalKey == LogicalKeyboardKey.space)) {
            abrir(t);
            return KeyEventResult.handled;
          }
          return KeyEventResult.ignored;
        },
        child: AnimatedContainer(
          duration: _animacion(context, _rapida),
          decoration: BoxDecoration(
            color: _enfocada
                ? AppColors.gold.withValues(alpha: 0.18)
                : Colors.transparent,
            borderRadius: BorderRadius.circular(3),
          ),
          child: Text(
            widget.texto,
            style: widget.style.copyWith(
              color: AppColors.gold,
              decoration: TextDecoration.underline,
              decorationStyle: TextDecorationStyle.dotted,
              decorationColor: AppColors.gold,
            ),
          ),
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Lección y módulo
// ---------------------------------------------------------------------------

/// Envuelve la tarjeta de una lección y le agrega, debajo, un panel que se
/// despliega con su texto y su glosario.
///
/// Tocar la lección sigue abriendo su contenido (video, PDF, quiz…) como
/// siempre: el panel se abre con su propio botón, que [builder] recibe para
/// ponerlo donde corresponda. Con [desplegable] en `false` no hay botón.
class LeccionDesplegable extends StatefulWidget {
  final bool desplegable;
  final Widget Function(Widget? botonDesplegar) builder;
  final WidgetBuilder panel;
  final String titulo;

  const LeccionDesplegable({
    super.key,
    required this.desplegable,
    required this.builder,
    required this.panel,
    required this.titulo,
  });

  @override
  State<LeccionDesplegable> createState() => _LeccionDesplegableState();
}

class _LeccionDesplegableState extends State<LeccionDesplegable> {
  bool _abierta = false;

  @override
  Widget build(BuildContext context) {
    final boton = !widget.desplegable
        ? null
        : Semantics(
            expanded: _abierta,
            child: IconButton(
              tooltip: _abierta
                  ? tr.glosarioOcultarTexto
                  : tr.glosarioVerTexto,
              onPressed: () => setState(() => _abierta = !_abierta),
              icon: AnimatedRotation(
                turns: _abierta ? 0.5 : 0,
                duration: _animacion(context, _rapida),
                child: Icon(Icons.expand_more,
                    color: _abierta ? AppColors.gold : AppColors.textMuted,
                    semanticLabel: tr.glosarioTextoDe(widget.titulo)),
              ),
            ),
          );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        widget.builder(boton),
        AnimatedSize(
          duration: _animacion(context, _media),
          curve: Curves.easeOutCubic,
          alignment: Alignment.topCenter,
          child: _abierta && widget.desplegable
              ? Container(
                  margin: const EdgeInsets.fromLTRB(12, 0, 0, 12),
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: AppColors.surface,
                    borderRadius: BorderRadius.circular(12),
                    border: Border(
                      left: BorderSide(color: AppColors.gold, width: 2),
                    ),
                  ),
                  child: widget.panel(context),
                )
              : const SizedBox(width: double.infinity),
        ),
      ],
    );
  }
}

/// Lo que va dentro del panel de una lección: su texto, con las palabras del
/// glosario resaltadas, y al final «Glosario de esta lección».
class GlosarioDeLeccion extends StatelessWidget {
  final String courseId;
  final Lesson leccion;
  final CourseGlossary glosario;
  final bool puedeRepasar;

  const GlosarioDeLeccion({
    super.key,
    required this.courseId,
    required this.leccion,
    required this.glosario,
    required this.puedeRepasar,
  });

  @override
  Widget build(BuildContext context) {
    final terminos = glosario.forLesson(leccion.id);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (leccion.description.isNotEmpty) ...[
          TextoConGlosario(
            texto: leccion.description,
            terminos: glosario.terms,
            style: const TextStyle(
                color: AppColors.textSecondary, fontSize: 14, height: 1.6),
            onAbrir: (t) => mostrarTerminoDelGlosario(context,
                termino: t, glosario: glosario),
          ),
          const SizedBox(height: 18),
        ],
        _Subtitulo(tr.glosarioDeLeccion),
        if (terminos.isEmpty)
          _Vacio(
            icono: Icons.menu_book_outlined,
            texto: tr.glosarioLeccionVacio,
          )
        else
          GlosarioPanel(
            courseId: courseId,
            glosario: glosario,
            terminos: terminos,
            buscador: false,
            puedeRepasar: puedeRepasar,
          ),
      ],
    );
  }
}

/// El glosario completo de un módulo, al final de sus lecciones. Se
/// despliega con un toque y trae buscador, letras A–Z y modo repaso.
class GlosarioDelModulo extends StatefulWidget {
  final String courseId;
  final CourseModule modulo;
  final CourseGlossary glosario;
  final bool puedeRepasar;

  const GlosarioDelModulo({
    super.key,
    required this.courseId,
    required this.modulo,
    required this.glosario,
    required this.puedeRepasar,
  });

  @override
  State<GlosarioDelModulo> createState() => _GlosarioDelModuloState();
}

class _GlosarioDelModuloState extends State<GlosarioDelModulo> {
  bool _abierto = false;

  @override
  Widget build(BuildContext context) {
    final terminos = widget.glosario.forModule(widget.modulo.id);
    final porRepasar = terminos
        .where((t) => widget.glosario.reviewOf(t.id) == ReviewStatus.review)
        .length;

    return Padding(
      padding: const EdgeInsets.only(top: 4, bottom: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Semantics(
            expanded: _abierto,
            child: HoverCard(
              key: ValueKey('glosario-modulo-${widget.modulo.id}'),
              hoverScale: 1.0,
              bg: AppColors.slate,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              onTap: () => setState(() => _abierto = !_abierto),
              child: Row(
                children: [
                  Icon(Icons.menu_book_outlined,
                      color: AppColors.gold, size: 22),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(tr.glosarioDelModulo,
                            style: TextStyle(fontWeight: FontWeight.w600)),
                        Text(
                          [
                            tr.glosarioTerminos(terminos.length),
                            if (widget.puedeRepasar && porRepasar > 0)
                              tr.glosarioPorRepasar(porRepasar),
                          ].join(' · '),
                          style: const TextStyle(
                              color: AppColors.textMuted, fontSize: 12),
                        ),
                      ],
                    ),
                  ),
                  AnimatedRotation(
                    turns: _abierto ? 0.5 : 0,
                    duration: _animacion(context, _rapida),
                    child: const Icon(Icons.expand_more,
                        color: AppColors.textMuted),
                  ),
                ],
              ),
            ),
          ),
          AnimatedSize(
            duration: _animacion(context, _media),
            curve: Curves.easeOutCubic,
            alignment: Alignment.topCenter,
            child: _abierto
                ? Padding(
                    padding: const EdgeInsets.only(top: 12),
                    child: GlosarioPanel(
                      courseId: widget.courseId,
                      glosario: widget.glosario,
                      terminos: terminos,
                      buscador: true,
                      puedeRepasar: widget.puedeRepasar,
                    ),
                  )
                : const SizedBox(width: double.infinity),
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Panel: tarjetas, buscador, A–Z y repaso
// ---------------------------------------------------------------------------

enum _Modo { tarjetas, repaso }

const _letras = 'ABCDEFGHIJKLMNÑOPQRSTUVWXYZ';

/// Las tarjetas de un conjunto de términos, con sus controles.
///
/// [terminos] es lo que se muestra (los de una lección o un módulo);
/// [glosario] es el curso entero, para resolver los relacionados que viven
/// en otro lado. Con [buscador] agrega la búsqueda y las letras A–Z.
class GlosarioPanel extends StatefulWidget {
  final String courseId;
  final CourseGlossary glosario;
  final List<GlossaryTerm> terminos;
  final bool buscador;

  /// Solo un estudiante mirando SU curso guarda «ya lo sé» / «repasar». Los
  /// demás pueden voltear las tarjetas, pero no hay a nombre de quién
  /// guardar.
  final bool puedeRepasar;

  const GlosarioPanel({
    super.key,
    required this.courseId,
    required this.glosario,
    required this.terminos,
    required this.buscador,
    required this.puedeRepasar,
  });

  @override
  State<GlosarioPanel> createState() => _GlosarioPanelState();
}

class _GlosarioPanelState extends State<GlosarioPanel> {
  final _busqueda = TextEditingController();
  String? _letra;
  _Modo _modo = _Modo.tarjetas;
  bool _soloPorRepasar = false;
  final Set<String> _abiertas = {};
  String? _resaltada;
  Timer? _quitarResaltado;

  final Map<String, GlobalKey> _claves = {};
  final Map<String, FocusNode> _focos = {};

  @override
  void dispose() {
    _busqueda.dispose();
    _quitarResaltado?.cancel();
    for (final f in _focos.values) {
      f.dispose();
    }
    super.dispose();
  }

  GlobalKey _claveDe(String id) => _claves.putIfAbsent(id, GlobalKey.new);
  FocusNode _focoDe(String id) => _focos.putIfAbsent(
      id, () => FocusNode(debugLabel: 'término $id'));

  bool get _hayFiltros =>
      _busqueda.text.trim().isNotEmpty || _letra != null || _soloPorRepasar;

  List<GlossaryTerm> get _visibles {
    final q = claveDeTermino(_busqueda.text);
    return widget.terminos.where((t) {
      if (_letra != null && t.letra != _letra) return false;
      if (_modo == _Modo.repaso &&
          _soloPorRepasar &&
          widget.glosario.reviewOf(t.id) != ReviewStatus.review) {
        return false;
      }
      if (q.isEmpty) return true;
      return claveDeTermino(t.word).contains(q) ||
          claveDeTermino(t.shortDefinition).contains(q);
    }).toList();
  }

  void _limpiarFiltros() => setState(() {
        _busqueda.clear();
        _letra = null;
        _soloPorRepasar = false;
      });

  /// Lleva a un término relacionado: si está en este panel, lo abre, lo
  /// muestra y le pasa el foco; si vive en otro lado, lo abre en un diálogo.
  void _irA(String id) {
    final termino = widget.glosario.termById(id);
    if (termino == null) return;
    if (!widget.terminos.any((t) => t.id == id)) {
      mostrarTerminoDelGlosario(context,
          termino: termino, glosario: widget.glosario);
      return;
    }
    setState(() {
      _busqueda.clear();
      _letra = null;
      _soloPorRepasar = false;
      _modo = _Modo.tarjetas;
      _abiertas.add(id);
      _resaltada = id;
    });
    _quitarResaltado?.cancel();
    _quitarResaltado = Timer(const Duration(milliseconds: 1600), () {
      if (mounted) setState(() => _resaltada = null);
    });
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final destino = _claves[id]?.currentContext;
      if (destino == null || !mounted) return;
      Scrollable.ensureVisible(destino,
          duration: _animacion(context, _media),
          curve: Curves.easeOutCubic,
          alignment: 0.15);
      _focos[id]?.requestFocus();
    });
  }

  Future<void> _marcar(GlossaryTerm t, ReviewStatus status) async {
    try {
      await context
          .read<DataProvider>()
          .setGlossaryReview(t.id, status, courseId: widget.courseId);
    } on ApiException catch (e) {
      if (mounted) showAppSnack(context, e.message, error: true);
    }
  }

  @override
  Widget build(BuildContext context) {
    final visibles = _visibles;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Wrap(
          spacing: 8,
          runSpacing: 8,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            _chipModo(_Modo.tarjetas, tr.glosarioTarjetas, Icons.view_module_outlined),
            _chipModo(_Modo.repaso, tr.glosarioModoRepaso, Icons.style_outlined),
          ],
        ),
        if (widget.buscador) ...[
          const SizedBox(height: 12),
          TextField(
            controller: _busqueda,
            onChanged: (_) => setState(() {}),
            textInputAction: TextInputAction.search,
            decoration: InputDecoration(
              labelText: tr.glosarioBuscar,
              prefixIcon: const Icon(Icons.search, size: 20),
              suffixIcon: _busqueda.text.isEmpty
                  ? null
                  : IconButton(
                      tooltip: tr.glosarioBorrarBusqueda,
                      icon: const Icon(Icons.close, size: 18),
                      onPressed: () => setState(_busqueda.clear),
                    ),
              isDense: true,
            ),
          ),
          const SizedBox(height: 10),
          _barraDeLetras(),
        ],
        if (_modo == _Modo.repaso) ...[
          const SizedBox(height: 12),
          _resumenRepaso(),
        ],
        const SizedBox(height: 12),
        if (visibles.isEmpty)
          _Vacio(
            icono: Icons.search_off,
            texto: _busqueda.text.trim().isNotEmpty
                ? tr.glosarioNingunoCoincide(_busqueda.text.trim())
                : _soloPorRepasar
                    ? tr.glosarioNingunoMarcado
                    : tr.glosarioNingunoLetra,
            accion: _hayFiltros
                ? TextButton(
                    onPressed: _limpiarFiltros,
                    child: Text(tr.glosarioQuitarFiltros))
                : null,
          )
        else
          _Rejilla(
            children: [
              for (final t in visibles)
                _modo == _Modo.tarjetas
                    ? TarjetaTermino(
                        key: _claveDe(t.id),
                        termino: t,
                        glosario: widget.glosario,
                        abierta: _abiertas.contains(t.id),
                        resaltada: _resaltada == t.id,
                        foco: _focoDe(t.id),
                        onAlternar: () => setState(() => _abiertas.contains(t.id)
                            ? _abiertas.remove(t.id)
                            : _abiertas.add(t.id)),
                        onRelacionado: _irA,
                      )
                    : TarjetaRepaso(
                        key: ValueKey('repaso-${t.id}'),
                        termino: t,
                        estado: widget.glosario.reviewOf(t.id),
                        onMarcar: widget.puedeRepasar
                            ? (status) => _marcar(t, status)
                            : null,
                      ),
            ],
          ),
      ],
    );
  }

  Widget _chipModo(_Modo modo, String texto, IconData icono) {
    final elegido = _modo == modo;
    return ChoiceChip(
      avatar: Icon(icono,
          size: 16, color: elegido ? AppColors.gold : AppColors.textMuted),
      label: Text(texto, style: const TextStyle(fontSize: 12.5)),
      selected: elegido,
      showCheckmark: false,
      selectedColor: AppColors.gold.withValues(alpha: 0.2),
      onSelected: (_) => setState(() {
        _modo = modo;
        if (modo == _Modo.tarjetas) _soloPorRepasar = false;
      }),
    );
  }

  /// A–Z con la Ñ en su lugar, y `#` si algún término no empieza con letra.
  /// Las letras sin términos quedan deshabilitadas, no ocultas: así la barra
  /// no cambia de forma y se ve de un vistazo qué hay.
  Widget _barraDeLetras() {
    final disponibles = {for (final t in widget.terminos) t.letra};
    final letras = [
      ..._letras.split(''),
      if (disponibles.contains('#')) '#',
    ];
    return SizedBox(
      height: 36,
      child: ListView(
        scrollDirection: Axis.horizontal,
        children: [
          _botonLetra(null, tr.glosarioTodas, disponible: true),
          for (final l in letras)
            _botonLetra(l, l, disponible: disponibles.contains(l)),
        ],
      ),
    );
  }

  Widget _botonLetra(String? letra, String texto, {required bool disponible}) {
    final elegida = _letra == letra;
    final cuantos = letra == null
        ? widget.terminos.length
        : widget.terminos.where((t) => t.letra == letra).length;
    return Padding(
      padding: const EdgeInsets.only(right: 4),
      child: Semantics(
        selected: elegida,
        label: letra == null
            ? tr.glosarioTodasLasLetras
            : tr.glosarioLetraTerminos(letra, cuantos),
        excludeSemantics: true,
        button: true,
        enabled: disponible,
        child: TextButton(
          onPressed: !disponible
              ? null
              : () => setState(() => _letra = elegida ? null : letra),
          style: TextButton.styleFrom(
            minimumSize: Size(letra == null ? 56 : 34, 34),
            padding: const EdgeInsets.symmetric(horizontal: 8),
            backgroundColor: elegida ? AppColors.gold : Colors.transparent,
            foregroundColor: elegida ? AppColors.ink : AppColors.textPrimary,
            disabledForegroundColor: AppColors.textMuted.withValues(alpha: 0.5),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            // Con la familia explícita: el `textStyle` de un `ButtonStyle`
            // reemplaza el del tema (ver `buildAppTheme`).
            textStyle: const TextStyle(
                fontFamily: AppFonts.ui,
                fontSize: 13,
                fontWeight: FontWeight.w600),
          ),
          child: Text(texto),
        ),
      ),
    );
  }

  Widget _resumenRepaso() {
    final total = widget.terminos.length;
    final sabe = widget.terminos
        .where((t) => widget.glosario.reviewOf(t.id) == ReviewStatus.known)
        .length;
    final repasar = widget.terminos
        .where((t) => widget.glosario.reviewOf(t.id) == ReviewStatus.review)
        .length;

    if (!widget.puedeRepasar) {
      return Text(
        tr.glosarioAyudaTarjetas,
        style: TextStyle(color: AppColors.textMuted, fontSize: 12.5),
      );
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          tr.glosarioAyudaRepaso(sabe, total, repasar),
          style: const TextStyle(color: AppColors.textSecondary, fontSize: 12.5),
        ),
        const SizedBox(height: 6),
        ThinProgressBar(
          value: total == 0 ? 0 : sabe / total,
          tooltip: tr.glosarioYaLoSabeDe(sabe, total),
        ),
        const SizedBox(height: 8),
        FilterChip(
          label: Text(tr.glosarioSoloRepasar,
              style: TextStyle(fontSize: 12.5)),
          selected: _soloPorRepasar,
          onSelected: (on) => setState(() => _soloPorRepasar = on),
        ),
      ],
    );
  }
}

/// 1 columna en el teléfono, 2 en una tableta o una columna angosta, 3 en
/// escritorio. Por ancho DISPONIBLE, no de ventana: el panel de una lección
/// es más angosto que la pantalla.
class _Rejilla extends StatelessWidget {
  final List<Widget> children;
  const _Rejilla({required this.children});

  static const _espacio = 12.0;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(builder: (context, constraints) {
      final ancho = constraints.maxWidth;
      final columnas = ancho < 560 ? 1 : (ancho < 900 ? 2 : 3);
      final anchoTarjeta = (ancho - _espacio * (columnas - 1)) / columnas;
      return Wrap(
        spacing: _espacio,
        runSpacing: _espacio,
        children: [
          for (final c in children) SizedBox(width: anchoTarjeta, child: c),
        ],
      );
    });
  }
}

// ---------------------------------------------------------------------------
// Tarjetas
// ---------------------------------------------------------------------------

/// La palabra y su definición corta; al tocarla se expande con la
/// explicación, el ejemplo, la imagen y los relacionados.
class TarjetaTermino extends StatefulWidget {
  final GlossaryTerm termino;
  final CourseGlossary glosario;
  final bool abierta;

  /// Se acaba de llegar acá desde un relacionado: el borde lo marca un rato.
  final bool resaltada;
  final FocusNode? foco;
  final VoidCallback onAlternar;
  final void Function(String termId) onRelacionado;

  const TarjetaTermino({
    super.key,
    required this.termino,
    required this.glosario,
    required this.abierta,
    required this.onAlternar,
    required this.onRelacionado,
    this.resaltada = false,
    this.foco,
  });

  @override
  State<TarjetaTermino> createState() => _TarjetaTerminoState();
}

class _TarjetaTerminoState extends State<TarjetaTermino> {
  bool _activa = false;

  bool get _expandible =>
      widget.termino.hasDetail || widget.termino.relatedTermIds.isNotEmpty;

  @override
  Widget build(BuildContext context) {
    final t = widget.termino;
    final estado = widget.glosario.reviewOf(t.id);
    final relacionados = [
      for (final id in t.relatedTermIds) ?widget.glosario.termById(id),
    ];
    final destacada = _activa || widget.resaltada;

    return AnimatedContainer(
      duration: _animacion(context, _rapida),
      decoration: BoxDecoration(
        color: destacada ? AppColors.surfaceAlt : AppColors.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: destacada ? AppColors.gold : AppColors.border,
          width: destacada ? 1.2 : 1,
        ),
        boxShadow: destacada
            ? const [
                BoxShadow(
                    color: Colors.black45, blurRadius: 18, offset: Offset(0, 6)),
              ]
            : const [],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Semantics(
            expanded: _expandible ? widget.abierta : null,
            child: InkWell(
              focusNode: widget.foco,
              borderRadius: BorderRadius.circular(12),
              onTap: _expandible ? widget.onAlternar : null,
              onHover: (h) => setState(() => _activa = h),
              onFocusChange: (f) => setState(() => _activa = f),
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 14, 12, 14),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(t.word,
                              style: const TextStyle(
                                  fontSize: 15,
                                  fontWeight: FontWeight.w700,
                                  color: AppColors.textPrimary)),
                          const SizedBox(height: 4),
                          Text(t.shortDefinition,
                              style: const TextStyle(
                                  fontSize: 13.5,
                                  height: 1.45,
                                  color: AppColors.textSecondary)),
                        ],
                      ),
                    ),
                    if (estado != null) _MarcaRepaso(estado),
                    if (_expandible)
                      AnimatedRotation(
                        turns: widget.abierta ? 0.5 : 0,
                        duration: _animacion(context, _rapida),
                        child: const Icon(Icons.expand_more,
                            color: AppColors.textMuted),
                      ),
                  ],
                ),
              ),
            ),
          ),
          AnimatedSize(
            duration: _animacion(context, _media),
            curve: Curves.easeOutCubic,
            alignment: Alignment.topCenter,
            child: !widget.abierta || !_expandible
                ? const SizedBox(width: double.infinity)
                : Padding(
                    padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Divider(height: 1),
                        const SizedBox(height: 12),
                        if (t.explanation.isNotEmpty) ...[
                          Text(t.explanation,
                              style: const TextStyle(
                                  fontSize: 13.5,
                                  height: 1.55,
                                  color: AppColors.textPrimary)),
                          const SizedBox(height: 12),
                        ],
                        if (t.example.isNotEmpty) ...[
                          _Ejemplo(t.example),
                          const SizedBox(height: 12),
                        ],
                        if (t.imageS3Key != null) ...[
                          _Imagen(termino: t),
                          const SizedBox(height: 12),
                        ],
                        if (relacionados.isNotEmpty) ...[
                          Text(tr.glosarioRelacionados,
                              style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600,
                                  color: AppColors.textMuted)),
                          const SizedBox(height: 6),
                          Wrap(
                            spacing: 6,
                            runSpacing: 6,
                            children: [
                              for (final r in relacionados)
                                ActionChip(
                                  avatar: Icon(Icons.north_east,
                                      size: 14, color: AppColors.gold),
                                  label: Text(r.word,
                                      style: const TextStyle(fontSize: 12.5)),
                                  tooltip: tr.glosarioIrA(r.word),
                                  onPressed: () => widget.onRelacionado(r.id),
                                ),
                            ],
                          ),
                        ],
                      ],
                    ),
                  ),
          ),
        ],
      ),
    );
  }
}

class _Ejemplo extends StatelessWidget {
  final String texto;
  const _Ejemplo(this.texto);

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
      decoration: BoxDecoration(
        color: AppColors.gold.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(8),
        border: Border(left: BorderSide(color: AppColors.gold, width: 3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(tr.glosarioEjemplo,
              style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: AppColors.gold)),
          const SizedBox(height: 4),
          Text(texto,
              style: const TextStyle(
                  fontSize: 13.5, height: 1.5, color: AppColors.textPrimary)),
        ],
      ),
    );
  }
}

class _Imagen extends StatelessWidget {
  final GlossaryTerm termino;
  const _Imagen({required this.termino});

  @override
  Widget build(BuildContext context) {
    return Semantics(
      image: true,
      label: tr.glosarioImagenDe(termino.word),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(8),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxHeight: 200),
          child: AppImage(
            s3Key: termino.imageS3Key,
            fit: BoxFit.contain,
            loadingBuilder: (_) => Container(
              height: 120,
              color: AppColors.surfaceAlt,
            ),
            errorWidgetBuilder: (_, _) => const SizedBox.shrink(),
          ),
        ),
      ),
    );
  }
}

class _MarcaRepaso extends StatelessWidget {
  final ReviewStatus estado;
  const _MarcaRepaso(this.estado);

  @override
  Widget build(BuildContext context) {
    final (icono, color, texto) = switch (estado) {
      ReviewStatus.known => (
          Icons.check_circle,
          AppColors.statusGood,
          tr.glosarioYaLoSabe
        ),
      ReviewStatus.review => (Icons.replay, AppColors.statusWarning, tr.glosarioPorRepasarEstado),
    };
    return Padding(
      padding: const EdgeInsets.only(left: 6, top: 1),
      child: Tooltip(
        message: texto,
        child: Icon(icono, size: 18, color: color, semanticLabel: texto),
      ),
    );
  }
}

/// Modo repaso: la palabra de un lado y la definición del otro. Debajo,
/// «Ya lo sé» / «Repasar» ([onMarcar] en `null` = sin guardar).
class TarjetaRepaso extends StatefulWidget {
  final GlossaryTerm termino;
  final ReviewStatus? estado;
  final void Function(ReviewStatus status)? onMarcar;

  const TarjetaRepaso({
    super.key,
    required this.termino,
    required this.estado,
    required this.onMarcar,
  });

  @override
  State<TarjetaRepaso> createState() => _TarjetaRepasoState();
}

class _TarjetaRepasoState extends State<TarjetaRepaso>
    with SingleTickerProviderStateMixin {
  late final AnimationController _giro =
      AnimationController(vsync: this, duration: _volteo);
  bool _activa = false;

  @override
  void dispose() {
    _giro.dispose();
    super.dispose();
  }

  void _voltear() {
    _giro.duration = _animacion(context, _volteo);
    _giro.isForwardOrCompleted ? _giro.reverse() : _giro.forward();
  }

  @override
  Widget build(BuildContext context) {
    final t = widget.termino;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        AnimatedBuilder(
          animation: _giro,
          builder: (context, _) {
            final angulo = Curves.easeInOut.transform(_giro.value) * math.pi;
            final atras = angulo > math.pi / 2;
            return Semantics(
              button: true,
              onTap: _voltear,
              label: atras
                  ? tr.glosarioDefinicionDe(t.word, t.shortDefinition)
                  : tr.glosarioToqueParaVer(t.word),
              excludeSemantics: true,
              child: Transform(
                alignment: Alignment.center,
                transform: Matrix4.identity()
                  ..setEntry(3, 2, 0.001)
                  ..rotateY(angulo),
                child: InkWell(
                  borderRadius: BorderRadius.circular(12),
                  onTap: _voltear,
                  onHover: (h) => setState(() => _activa = h),
                  onFocusChange: (f) => setState(() => _activa = f),
                  child: Container(
                    height: 168,
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: atras ? AppColors.surfaceAlt : AppColors.surface,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: _activa ? AppColors.gold : AppColors.border,
                        width: _activa ? 1.2 : 1,
                      ),
                    ),
                    // La cara de atrás se dibuja girada otra media vuelta,
                    // para que no se lea al revés.
                    child: atras
                        ? Transform(
                            alignment: Alignment.center,
                            transform: Matrix4.identity()..rotateY(math.pi),
                            child: _reverso(t),
                          )
                        : _frente(t),
                  ),
                ),
              ),
            );
          },
        ),
        if (widget.onMarcar != null) ...[
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: _BotonRepaso(
                  texto: tr.glosarioYaLoSe,
                  icono: Icons.check_circle_outline,
                  color: AppColors.statusGood,
                  elegido: widget.estado == ReviewStatus.known,
                  onPressed: () => widget.onMarcar!(ReviewStatus.known),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _BotonRepaso(
                  texto: tr.glosarioRepasar,
                  icono: Icons.replay,
                  color: AppColors.statusWarning,
                  elegido: widget.estado == ReviewStatus.review,
                  onPressed: () => widget.onMarcar!(ReviewStatus.review),
                ),
              ),
            ],
          ),
        ],
      ],
    );
  }

  Widget _frente(GlossaryTerm t) => Stack(
        children: [
          Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(t.word,
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.w700,
                        color: AppColors.textPrimary)),
                const SizedBox(height: 8),
                Text(tr.glosarioToqueDefinicion,
                    style: TextStyle(color: AppColors.textMuted, fontSize: 12)),
              ],
            ),
          ),
          if (widget.estado != null)
            Positioned(top: 0, right: 0, child: _MarcaRepaso(widget.estado!)),
        ],
      );

  Widget _reverso(GlossaryTerm t) => Center(
        child: SingleChildScrollView(
          child: Text(t.shortDefinition,
              textAlign: TextAlign.center,
              style: const TextStyle(
                  fontSize: 14.5, height: 1.5, color: AppColors.textPrimary)),
        ),
      );
}

class _BotonRepaso extends StatelessWidget {
  final String texto;
  final IconData icono;
  final Color color;
  final bool elegido;
  final VoidCallback onPressed;

  const _BotonRepaso({
    required this.texto,
    required this.icono,
    required this.color,
    required this.elegido,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    return Semantics(
      selected: elegido,
      child: OutlinedButton.icon(
        onPressed: onPressed,
        icon: Icon(elegido ? Icons.check : icono, size: 17),
        label: Text(texto),
        style: OutlinedButton.styleFrom(
          foregroundColor: elegido ? color : AppColors.textSecondary,
          backgroundColor:
              elegido ? color.withValues(alpha: 0.14) : Colors.transparent,
          side: BorderSide(color: elegido ? color : AppColors.border),
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 12),
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Término suelto
// ---------------------------------------------------------------------------

/// Muestra un término en un diálogo: un relacionado que vive en otro módulo,
/// o la palabra resaltada del texto que se abrió con el teclado. Sus
/// relacionados se recorren dentro del mismo diálogo.
Future<void> mostrarTerminoDelGlosario(
  BuildContext context, {
  required GlossaryTerm termino,
  required CourseGlossary glosario,
}) {
  return showDialog<void>(
    context: context,
    builder: (_) => _DialogoTermino(termino: termino, glosario: glosario),
  );
}

class _DialogoTermino extends StatefulWidget {
  final GlossaryTerm termino;
  final CourseGlossary glosario;
  const _DialogoTermino({required this.termino, required this.glosario});

  @override
  State<_DialogoTermino> createState() => _DialogoTerminoState();
}

class _DialogoTerminoState extends State<_DialogoTermino> {
  late GlossaryTerm _actual = widget.termino;

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: AppColors.background,
      insetPadding: const EdgeInsets.all(16),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 480),
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Align(
                alignment: Alignment.centerRight,
                child: IconButton(
                  tooltip: tr.comunCerrar,
                  icon: const Icon(Icons.close),
                  onPressed: () => Navigator.pop(context),
                ),
              ),
              AnimatedSwitcher(
                duration: _animacion(context, _media),
                child: TarjetaTermino(
                  key: ValueKey(_actual.id),
                  termino: _actual,
                  glosario: widget.glosario,
                  abierta: true,
                  onAlternar: () {},
                  onRelacionado: (id) {
                    final siguiente = widget.glosario.termById(id);
                    if (siguiente != null) setState(() => _actual = siguiente);
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Piezas chicas
// ---------------------------------------------------------------------------

class _Subtitulo extends StatelessWidget {
  final String texto;
  const _Subtitulo(this.texto);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Semantics(
        header: true,
        child: Text(texto.toUpperCase(),
            style: displayHeading(
                fontSize: 17, color: AppColors.textPrimary, height: 1.1)),
      ),
    );
  }
}

class _Vacio extends StatelessWidget {
  final IconData icono;
  final String texto;
  final Widget? accion;
  const _Vacio({required this.icono, required this.texto, this.accion});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 18),
      decoration: BoxDecoration(
        color: AppColors.surfaceAlt.withValues(alpha: 0.4),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        children: [
          Icon(icono, color: AppColors.textMuted, size: 28),
          const SizedBox(height: 8),
          Text(texto,
              textAlign: TextAlign.center,
              style: const TextStyle(color: AppColors.textMuted, fontSize: 13.5)),
          ?accion,
        ],
      ),
    );
  }
}
