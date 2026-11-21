import 'package:flutter/widgets.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'redibujar.dart';

/// Modo claro u oscuro de TODA la plataforma.
///
/// Antes cada pantalla del estudiante tenía su propio botón de tema, que
/// cambiaba solo esa pantalla y se olvidaba al salir; el encabezado, el menú,
/// la administración y los diálogos eran oscuros siempre. Ahora hay un solo
/// interruptor, en el encabezado, y lo sigue todo.
///
/// Funciona como el idioma ([Idioma]) y la marca ([Marca]): los colores se
/// leen sin `BuildContext` (`AppColors.surface`), así que al cambiar se marca
/// toda la app para reconstruirse ([redibujarTodaLaApp]) y `MaterialApp`
/// arma el `ThemeData` nuevo.
///
/// La elección se guarda en el dispositivo. La primera vez, oscuro: es el
/// diseño de la marca y lo que todos conocían.
class Tema extends ChangeNotifier {
  Tema._();

  static final Tema instancia = Tema._();

  /// Clave en `SharedPreferences` (en la web, `localStorage`).
  static const claveGuardada = 'tema';

  bool _oscuro = true;

  /// Cuántas pantallas piden ir siempre en oscuro ([SiempreOscuro]): la
  /// portada pública está diseñada sobre negro, con degradados que en claro
  /// se deshacen. Mientras haya alguna, todo se dibuja oscuro sin tocar la
  /// preferencia guardada.
  int _forzadoOscuro = 0;

  /// Lectura rápida para los colores: `Tema.oscuro`.
  static bool get oscuro => instancia._oscuro || instancia._forzadoOscuro > 0;

  /// La preferencia de la persona, sin contar lo forzado.
  bool get esOscuro => _oscuro;

  /// Al arrancar, antes de `runApp`.
  Future<void> cargar() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      _oscuro = prefs.getString(claveGuardada) != 'claro';
    } catch (_) {
      // Sin almacenamiento: oscuro, y la elección dura lo que dure la pestaña.
    }
  }

  /// Pasa de oscuro a claro o al revés, sin recargar, y guarda la elección.
  Future<void> alternar() => usar(oscuro: !_oscuro);

  Future<void> usar({required bool oscuro}) async {
    if (oscuro != _oscuro) {
      _oscuro = oscuro;
      notifyListeners();
      redibujarTodaLaApp();
    }
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(claveGuardada, oscuro ? 'oscuro' : 'claro');
    } catch (_) {
      // Ver `cargar`.
    }
  }

  /// Vuelve a oscuro sin guardar nada. Solo para pruebas.
  @visibleForTesting
  void restablecer() {
    if (!_oscuro) {
      _oscuro = true;
      notifyListeners();
    }
  }
}

/// Dibuja [child] —y, mientras está montado, toda la app— en oscuro, sin
/// cambiar la preferencia de la persona. Para la portada pública.
class SiempreOscuro extends StatefulWidget {
  final Widget child;
  const SiempreOscuro({super.key, required this.child});

  @override
  State<SiempreOscuro> createState() => _SiempreOscuroState();
}

class _SiempreOscuroState extends State<SiempreOscuro> {
  @override
  void initState() {
    super.initState();
    // Los colores se leen al construir: se fuerza ya, y el aviso para que
    // `MaterialApp` arme el tema oscuro va después del cuadro en curso.
    Tema.instancia._forzadoOscuro++;
    if (!Tema.instancia._oscuro) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        // ignore: invalid_use_of_protected_member, invalid_use_of_visible_for_testing_member
        Tema.instancia.notifyListeners();
      });
    }
  }

  @override
  void dispose() {
    final tema = Tema.instancia;
    tema._forzadoOscuro--;
    if (!tema._oscuro && tema._forzadoOscuro == 0) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        // ignore: invalid_use_of_protected_member, invalid_use_of_visible_for_testing_member
        tema.notifyListeners();
        redibujarTodaLaApp();
      });
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => widget.child;
}
