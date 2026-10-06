/// Fechas y números con la forma del idioma activo.
///
/// En español se conservan exactamente los formatos que la app ya usaba
/// ("5 oct 2026", "3:00 p. m."). En inglés se usa el orden propio del idioma
/// ("Oct 5, 2026"), no la traducción palabra por palabra del patrón español.
///
/// Los formatos técnicos —`yyyy-MM-dd` para la API, el nombre de un archivo
/// de respaldo— no pasan por acá: no son para leer, y no deben cambiar con
/// el idioma.
library;

import 'package:intl/intl.dart';

import '../l10n/idioma.dart';

bool get _es => Idioma.instancia.codigo == 'es';
String get _loc => Idioma.instancia.codigo;

DateFormat _f(String es, String en) => DateFormat(_es ? es : en, _loc);

/// "5 oct 2026" / "Oct 5, 2026".
String fechaCorta(DateTime d) => _f('d MMM yyyy', 'MMM d, yyyy').format(d);

/// "5 octubre 2026" / "October 5, 2026". Lo usa el certificado.
String fechaLarga(DateTime d) => _f('d MMMM yyyy', 'MMMM d, yyyy').format(d);

/// "5 oct 2026, 3:00 p. m." / "Oct 5, 2026, 3:00 PM".
String fechaHora(DateTime d) =>
    _f('d MMM yyyy, h:mm a', 'MMM d, yyyy, h:mm a').format(d);

/// "5 oct, 3:00 p. m." / "Oct 5, 3:00 PM".
String diaMesHora(DateTime d) => _f('d MMM, h:mm a', 'MMM d, h:mm a').format(d);

/// "5" / "5": el día solo, para rangos ("del 5 al 11 de octubre").
String dia(DateTime d) => DateFormat('d', _loc).format(d);

/// "5 de octubre" / "October 5".
String diaMes(DateTime d) => _f("d 'de' MMMM", 'MMMM d').format(d);

/// "5 de oct" / "Oct 5".
String diaMesCorto(DateTime d) => _f("d 'de' MMM", 'MMM d').format(d);

/// "octubre 2026" / "October 2026".
String mesAnio(DateTime d) => DateFormat('MMMM yyyy', _loc).format(d);

/// "lun" / "Mon".
String diaSemanaCorto(DateTime d) => DateFormat('EEE', _loc).format(d);

/// "lunes 5 de octubre" / "Monday, October 5".
String diaSemanaLargo(DateTime d) =>
    _f("EEEE d 'de' MMMM", 'EEEE, MMMM d').format(d);

/// "3:00 p. m." / "3:00 PM".
String hora(DateTime d) => DateFormat('h:mm a', _loc).format(d);

/// "4,5" / "4.5": decimales con el separador del idioma. [digitos] fija
/// cuántos decimales se muestran (como `toStringAsFixed`).
String decimal(num n, [int digitos = 1]) {
  final f = NumberFormat.decimalPattern(_loc)
    ..minimumFractionDigits = digitos
    ..maximumFractionDigits = digitos;
  return f.format(n);
}

/// "0,75" / "0.75": un número tal cual, con los decimales que tenga (hasta
/// tres) y el separador del idioma. "2" para 2.0.
String numero(num n) => NumberFormat.decimalPattern(_loc).format(n);

/// "1.234" / "1,234": enteros con separador de miles.
String entero(num n) => NumberFormat.decimalPattern(_loc).format(n.round());
