import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../providers/data_provider.dart';
import '../utils/app_theme.dart';

/// El selector de universidad. **Reemplaza a todos los campos de texto.**
///
/// Existe por el defecto que costó más caro de la plataforma: la universidad
/// era texto libre, y de comparar esas cadenas dependía qué estudiantes veía
/// cada asesor. Un espacio de más, una tilde o «U. de los Andes» frente a
/// «Universidad de los Andes», y el asesor dejaba de ver a su gente — sin
/// error, sin log, indistinguible de «todavía no tengo estudiantes».
///
/// Por eso esto no es un `Autocomplete` ni un campo con sugerencias: **no se
/// puede escribir**. Un campo que sugiere sigue aceptando lo que la persona
/// teclee, y con eso vuelve el problema entero por la puerta de atrás.
///
/// Solo muestra universidades activas: el catálogo no manda las inactivas
/// —«Sin asignar» es una— porque estar en la lista es una invitación a
/// elegirlas, y el servidor las rechaza de todas formas.
class UniversityPicker extends StatelessWidget {
  const UniversityPicker({
    super.key,
    required this.value,
    required this.onChanged,
    this.label = 'Universidad',
    this.enabled = true,
    this.allowEmpty = true,
    this.emptyLabel = 'Sin universidad',
    this.helperText,
  });

  /// El id seleccionado, o `null`.
  final String? value;
  final ValueChanged<String?> onChanged;
  final String label;
  final bool enabled;

  /// Si se permite «sin universidad». Para un estudiante Enactus **no** se
  /// permite (INV-2); para Open Learning y los demás roles, sí: no la llevan.
  final bool allowEmpty;
  final String emptyLabel;
  final String? helperText;

  @override
  Widget build(BuildContext context) {
    final data = context.watch<DataProvider>();
    final estado = data.universities;
    final lista = estado.valueOrNull;

    if (lista == null) {
      // Mientras carga NO se dibuja un desplegable vacío: sería indistinguible
      // de «no hay universidades» y alguien esperaría a que aparezcan opciones
      // que ya llegaron.
      return InputDecorator(
        decoration: InputDecoration(labelText: label, helperText: helperText),
        child: Row(
          children: [
            const SizedBox(
              width: 14,
              height: 14,
              child: CircularProgressIndicator(strokeWidth: 2),
            ),
            const SizedBox(width: 10),
            Text('Cargando universidades…',
                style: TextStyle(color: AppColors.textSecondary, fontSize: 13)),
          ],
        ),
      );
    }

    // Un id que ya no está en el catálogo —una universidad dada de baja, o una
    // que llegó de datos viejos— NO se descarta en silencio: se agrega como
    // opción marcada, para que quien edita vea qué hay puesto en vez de
    // encontrarse el campo vacío y guardar sin querer un cambio que no hizo.
    final seleccionadaFalta =
        value != null && value!.isNotEmpty && !lista.any((u) => u.id == value);

    return DropdownButtonFormField<String?>(
      initialValue: value == null || value!.isEmpty ? null : value,
      isExpanded: true,
      decoration: InputDecoration(labelText: label, helperText: helperText),
      onChanged: enabled ? onChanged : null,
      items: [
        if (allowEmpty)
          DropdownMenuItem<String?>(
            value: null,
            child: Text(emptyLabel,
                style: const TextStyle(color: AppColors.textSecondary)),
          ),
        if (seleccionadaFalta)
          DropdownMenuItem<String?>(
            value: value,
            child: const Text('(universidad fuera del catálogo)'),
          ),
        for (final u in lista)
          DropdownMenuItem<String?>(
            value: u.id,
            child: Text(u.name, overflow: TextOverflow.ellipsis),
          ),
      ],
    );
  }
}
