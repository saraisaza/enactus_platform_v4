import 'dart:convert';

import 'package:http/http.dart' as http;

import 'api_service.dart';

/// Envía el formulario «Hablemos» de la portada (`POST /contact`).
///
/// Antes no había adónde mandarlo: el formulario decía «¡Mensaje enviado!»
/// y el mensaje solo quedaba en la consola del navegador. Ahora el servidor
/// se lo hace llegar a cada administrador como aviso.
///
/// Es un pedido sin sesión, así que no pasa por [ApiService] (que agrega el
/// token y renueva la sesión): solo usa su dirección.
class ContactService {
  /// El cliente HTTP; las pruebas ponen uno falso.
  static http.Client Function() cliente = http.Client.new;

  static Future<bool> sendMessage({
    required String name,
    required String email,
    required String message,
    String company = '',
  }) async {
    final c = cliente();
    try {
      final res = await c.post(
        Uri.parse('${ApiService.baseUrl}/contact'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'name': name,
          'email': email,
          'company': company,
          'message': message,
          // La trampa para robots va siempre vacía: la página no la muestra.
          'website': '',
        }),
      );
      return res.statusCode >= 200 && res.statusCode < 300;
    } catch (_) {
      return false;
    } finally {
      c.close();
    }
  }
}
