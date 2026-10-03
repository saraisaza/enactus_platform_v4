import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';

/// Orientación de la pantalla en la app instalada (en la web no aplica).
///
/// Los cortes de diseño son por ANCHO: un teléfono girado mide más de 600 dp
/// de ancho y pasaba al diseño de tablet, con el encabezado ocupando casi la
/// mitad de una pantalla de 360 dp de alto y los formularios en diálogos
/// flotantes. En el teléfono la app es vertical; la tablet gira libremente.
/// La excepción es el video a pantalla completa (ver [permitirCualquierOrientacion]).

/// Teléfono: el lado corto de la pantalla mide menos de 600 dp.
bool esTelefono() {
  final vistas = WidgetsBinding.instance.platformDispatcher.views;
  if (vistas.isEmpty) return true;
  final vista = vistas.first;
  if (vista.physicalSize.isEmpty) return true;
  return vista.physicalSize.shortestSide / vista.devicePixelRatio < 600;
}

/// La orientación normal de la app: vertical en teléfonos, libre en tablets.
///
/// Se llama después del primer frame —antes, en Android el tamaño de la
/// pantalla todavía puede ser cero— y al salir del video a pantalla completa.
Future<void> fijarOrientacionDeLaApp() async {
  if (kIsWeb) return;
  await SystemChrome.setPreferredOrientations(
    esTelefono() ? const [DeviceOrientation.portraitUp] : const [],
  );
}

/// Para ver un video: el teléfono puede girarse a horizontal.
Future<void> permitirCualquierOrientacion() async {
  if (kIsWeb) return;
  await SystemChrome.setPreferredOrientations(DeviceOrientation.values);
}
