import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../l10n/textos.dart';
import '../utils/app_theme.dart';

/// Normas de la comunidad del foro.
///
/// App Store (guía 1.2) exige que, antes de publicar, la persona acepte unas
/// condiciones que dejen claro que no se tolera el contenido ofensivo ni el
/// abuso. Son estas. El texto es un borrador que el equipo de Enactus
/// Colombia debe revisar (ver `docs/movil/DATOS_Y_PRIVACIDAD.md`).
/// Es una función, no una constante: el texto sigue al idioma activo.
List<(String, String)> get normasDeLaComunidad => [
      (tr.normas1Titulo, tr.normas1Texto),
      (tr.normas2Titulo, tr.normas2Texto),
      (tr.normas3Titulo, tr.normas3Texto),
      (tr.normas4Titulo, tr.normas4Texto),
      (tr.normas5Titulo, tr.normas5Texto),
      (tr.normas6Titulo, tr.normas6Texto),
    ];

String get _consecuencias => tr.normasConsecuencias;

/// Muestra las normas. Con [pedirAceptacion], los botones son «Cancelar» y
/// «Acepto», y devuelve `true` solo si la persona aceptó.
Future<bool> mostrarNormasDeLaComunidad(
  BuildContext context, {
  bool pedirAceptacion = false,
}) async {
  final acepto = await showDialog<bool>(
    context: context,
    builder: (ctx) => AlertDialog(
      title: Text(tr.cuentaNormas,
          style: TextStyle(fontSize: 18)),
      content: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 480),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (pedirAceptacion)
                Padding(
                  padding: EdgeInsets.only(bottom: 12),
                  child: Text(
                    tr.normasAntesDePublicar,
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
              Text(
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
                child: Text(tr.comunCancelar),
              ),
              ElevatedButton(
                onPressed: () => Navigator.pop(ctx, true),
                child: Text(tr.normasAcepto),
              ),
            ]
          : [
              TextButton(
                onPressed: () => Navigator.pop(ctx, true),
                child: Text(tr.comunCerrar),
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
