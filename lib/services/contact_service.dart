import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

/// Envía los mensajes del formulario "Contáctanos" del landing (botón
/// "Quiero unirme").
///
/// Todavía no hay una API de correo conectada. Para activarla:
/// 1. Pon la URL de tu API (Cloud Function, Resend, SendGrid, Formspree,
///    un backend propio, etc.) en [_apiEndpoint].
/// 2. Si esa API necesita autenticación, agrega el header en el
///    `http.post` de abajo (p. ej. `'Authorization': 'Bearer ...'`).
///
/// Mientras [_apiEndpoint] esté vacío, el mensaje solo se imprime en la
/// consola (modo demo) para no romper el formulario.
class ContactService {
  static const String _apiEndpoint = ''; // TODO: URL de la API de email

  static Future<bool> sendMessage({
    required String name,
    required String email,
    required String message,
  }) async {
    if (_apiEndpoint.isEmpty) {
      await Future.delayed(const Duration(milliseconds: 500));
      debugPrint('[Contacto demo] $name <$email>: $message');
      return true;
    }

    try {
      final res = await http.post(
        Uri.parse(_apiEndpoint),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'name': name, 'email': email, 'message': message}),
      );
      return res.statusCode >= 200 && res.statusCode < 300;
    } catch (_) {
      return false;
    }
  }
}
