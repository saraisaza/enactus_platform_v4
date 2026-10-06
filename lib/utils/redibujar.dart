import 'package:flutter/widgets.dart';

/// Marca toda la app para reconstruirse, sin perder estado: la pestaña
/// abierta, el formulario a medio llenar y el desplazamiento quedan igual.
///
/// Hace falta cuando cambia algo que las pantallas leen sin `BuildContext`
/// —los textos (`tr`) o los colores de marca (`AppColors`)—: `MaterialApp` se
/// reconstruye al notificar, pero un widget `const`, o uno que no depende del
/// tema ni de `Localizations`, no se enteraría.
void redibujarTodaLaApp() {
  final raiz = WidgetsBinding.instance.rootElement;
  if (raiz == null) return;
  void marcar(Element e) {
    e.markNeedsBuild();
    e.visitChildren(marcar);
  }

  raiz.visitChildren(marcar);
}
