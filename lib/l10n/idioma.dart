import 'package:flutter/widgets.dart';
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'app_localizations.dart';
import 'documento.dart';

/// El idioma de la interfaz: cuál está activo, cuál se usa la primera vez y
/// dónde se guarda lo que la persona eligió.
///
/// - La primera vez manda el idioma del navegador (o del teléfono): inglés si
///   es inglés, español en cualquier otro caso.
/// - Cuando la persona elige en el selector, la elección se guarda en el
///   dispositivo y gana sobre el navegador de ahí en adelante, con o sin
///   sesión iniciada.
///
/// Solo traduce la interfaz. Lo que escriben las personas (nombres, cursos,
/// lecciones, el foro) se muestra tal como se escribió.
class Idioma extends ChangeNotifier {
  Idioma._();

  /// Una sola instancia para toda la app: [tr] la lee sin `BuildContext`.
  static final Idioma instancia = Idioma._();

  /// Los idiomas disponibles, en el orden del selector.
  static const codigos = ['es', 'en'];

  /// Clave en `SharedPreferences` (en la web, `localStorage`).
  static const claveGuardada = 'idioma';

  String _codigo = 'es';
  AppLocalizations _textos = lookupAppLocalizations(const Locale('es'));

  /// `es` o `en`.
  String get codigo => _codigo;

  /// Los textos del idioma activo. Ver `tr` en `textos.dart`.
  AppLocalizations get textos => _textos;

  /// El `Locale` de la app. El español sigue siendo el de Colombia, como
  /// antes: los textos de Material (selector de fecha, copiar y pegar) no
  /// cambian para quien ya usaba la plataforma.
  Locale get locale =>
      _codigo == 'es' ? const Locale('es', 'CO') : const Locale('en');

  /// Los `Locale` que se le declaran a `MaterialApp`.
  static const locales = [Locale('es', 'CO'), Locale('es'), Locale('en')];

  /// Al arrancar, antes de `runApp`: lo guardado, o el idioma del sistema.
  Future<void> cargar() async {
    String? guardado;
    try {
      final prefs = await SharedPreferences.getInstance();
      guardado = prefs.getString(claveGuardada);
    } catch (_) {
      // Sin almacenamiento (navegación privada estricta): se usa el del
      // sistema y la elección dura lo que dure la pestaña.
    }
    _aplicar(codigos.contains(guardado)
        ? guardado!
        : delSistema(WidgetsBinding.instance.platformDispatcher.locales));
  }

  /// El idioma que corresponde a la lista de idiomas del navegador o del
  /// teléfono: solo cuenta el primero, que es el que la persona usa.
  @visibleForTesting
  static String delSistema(List<Locale> locales) =>
      locales.isNotEmpty && locales.first.languageCode == 'en' ? 'en' : 'es';

  /// Cambia el idioma de inmediato, sin recargar, y guarda la elección.
  Future<void> cambiar(String codigo) async {
    if (!codigos.contains(codigo)) return;
    if (codigo != _codigo) {
      _aplicar(codigo);
      notifyListeners();
      _redibujarTodo();
    }
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(claveGuardada, codigo);
    } catch (_) {
      // Ver `cargar`: el cambio vale igual para esta sesión.
    }
  }

  /// Vuelve al español sin guardar nada. Solo para pruebas.
  @visibleForTesting
  void restablecer() {
    if (_codigo != 'es') {
      _aplicar('es');
      notifyListeners();
    }
  }

  void _aplicar(String codigo) {
    _codigo = codigo;
    _textos = lookupAppLocalizations(Locale(codigo));
    // Toda fecha y número sin idioma explícito sigue al de la interfaz.
    Intl.defaultLocale = codigo;
    marcarIdiomaDelDocumento(codigo);
  }

  /// `MaterialApp` se reconstruye al notificar, pero un widget `const` o uno
  /// que no depende de `Localizations` no se enteraría: [tr] es global. Se
  /// marca todo el árbol para reconstruir —sin perder estado: la pestaña
  /// abierta, el formulario a medio llenar y el desplazamiento quedan igual—.
  void _redibujarTodo() {
    final raiz = WidgetsBinding.instance.rootElement;
    if (raiz == null) return;
    void marcar(Element e) {
      e.markNeedsBuild();
      e.visitChildren(marcar);
    }

    raiz.visitChildren(marcar);
  }
}
