import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../utils/app_theme.dart';

/// Normas de la comunidad del foro.
///
/// App Store (guía 1.2) exige que, antes de publicar, la persona acepte unas
/// condiciones que dejen claro que no se tolera el contenido ofensivo ni el
/// abuso. Son estas. El texto es un borrador que el equipo de Enactus
/// Colombia debe revisar (ver `docs/movil/DATOS_Y_PRIVACIDAD.md`).
const normasDeLaComunidad = <(String, String)>[
  (
    'Respeto ante todo',
    'Trate a las demás personas como quiere que lo traten. No se permiten '
        'insultos, burlas, acoso ni amenazas.',
  ),
  (
    'Cero discriminación',
    'No se acepta contenido que discrimine por origen, nacionalidad, género, '
        'orientación sexual, religión, discapacidad o condición social.',
  ),
  (
    'Contenido apropiado',
    'No publique contenido sexual, violento, ilegal ni nada que ponga en '
        'riesgo a otra persona.',
  ),
  (
    'Sin publicidad',
    'El foro es para aprender y construir proyectos: no publique ventas, '
        'rifas, cadenas ni publicidad.',
  ),
  (
    'Cuide los datos',
    'No comparta datos personales suyos ni de otras personas: teléfonos, '
        'direcciones, documentos o fotos de terceros.',
  ),
  (
    'Reporte lo que no está bien',
    'Si algo incumple estas normas, use «Reportar» en el menú ⋮ de la '
        'publicación. Si alguien le incomoda, puede bloquearlo y dejará de '
        'ver lo que publica.',
  ),
];

const _consecuencias =
    'No hay tolerancia con el contenido ofensivo ni con el abuso. El equipo de '
    'Enactus Colombia revisa cada reporte y puede quitar el contenido y '
    'suspender la cuenta de quien incumpla estas normas.';

/// Muestra las normas. Con [pedirAceptacion], los botones son «Cancelar» y
/// «Acepto», y devuelve `true` solo si la persona aceptó.
Future<bool> mostrarNormasDeLaComunidad(
  BuildContext context, {
  bool pedirAceptacion = false,
}) async {
  final acepto = await showDialog<bool>(
    context: context,
    builder: (ctx) => AlertDialog(
      title: const Text('Normas de la comunidad',
          style: TextStyle(fontSize: 18)),
      content: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 480),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (pedirAceptacion)
                const Padding(
                  padding: EdgeInsets.only(bottom: 12),
                  child: Text(
                    'Antes de publicar por primera vez, lea y acepte las '
                    'normas del foro.',
                    style: TextStyle(color: AppColors.textMuted),
                  ),
                ),
              for (final (titulo, texto) in normasDeLaComunidad)
                Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(titulo,
                          style: const TextStyle(fontWeight: FontWeight.w700)),
                      const SizedBox(height: 2),
                      Text(texto, style: const TextStyle(height: 1.4)),
                    ],
                  ),
                ),
              const SizedBox(height: 4),
              const Text(
                _consecuencias,
                style: TextStyle(
                  fontWeight: FontWeight.w600,
                  height: 1.4,
                ),
              ),
            ],
          ),
        ),
      ),
      actions: pedirAceptacion
          ? [
              TextButton(
                onPressed: () => Navigator.pop(ctx, false),
                child: const Text('Cancelar'),
              ),
              ElevatedButton(
                onPressed: () => Navigator.pop(ctx, true),
                child: const Text('Acepto'),
              ),
            ]
          : [
              TextButton(
                onPressed: () => Navigator.pop(ctx, true),
                child: const Text('Cerrar'),
              ),
            ],
    ),
  );
  return acepto ?? false;
}

/// `true` si la persona ya aceptó las normas o las acepta ahora.
///
/// Se recuerda por cuenta y en este dispositivo: quien comparte el teléfono
/// con otra persona no acepta por ella. Si el almacenamiento falla, se vuelven
/// a mostrar —preguntar de más es mejor que publicar sin haberlas aceptado—.
Future<bool> asegurarNormasAceptadas(
    BuildContext context, String userId) async {
  final clave = 'enactus.foro.normas_aceptadas.$userId';
  SharedPreferences? prefs;
  try {
    prefs = await SharedPreferences.getInstance();
    if (prefs.getBool(clave) ?? false) return true;
  } catch (_) {
    prefs = null;
  }
  if (!context.mounted) return false;
  final acepto =
      await mostrarNormasDeLaComunidad(context, pedirAceptacion: true);
  if (acepto) {
    try {
      await prefs?.setBool(clave, true);
    } catch (_) {
      // Se volverán a pedir la próxima vez; no impide publicar ahora.
    }
  }
  return acepto;
}
