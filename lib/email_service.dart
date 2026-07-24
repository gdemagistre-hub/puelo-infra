import 'dart:convert';
import 'package:http/http.dart' as http;

/// Envío de emails vía EmailJS (sin backend propio).
class EmailService {
  static const String serviceId = 'service_pfwycby';
  static const String templateId = 'template_z0lfetl';
  static const String publicKey = 's7JFHKYeK9i4-aTMs';

  static bool get isConfigured =>
      publicKey.isNotEmpty && serviceId.isNotEmpty && templateId.isNotEmpty;

  /// Envía el email de activación de cuenta.
  /// Devuelve true si EmailJS respondió OK.
  static Future<bool> enviarValidacionCuenta({
    required String toEmail,
    required String toName,
    required String validationLink,
  }) async {
    if (!isConfigured) {
      throw Exception('EmailJS no está configurado correctamente.');
    }

    final response = await http.post(
      Uri.parse('https://api.emailjs.com/api/v1.0/email/send'),
      headers: {
        'origin': 'http://localhost',
        'Content-Type': 'application/json',
      },
      body: jsonEncode({
        'service_id': serviceId,
        'template_id': templateId,
        'user_id': publicKey,
        'template_params': {
          'to_email': toEmail,
          'to_name': toName,
          'validation_link': validationLink,
        },
      }),
    );

    return response.statusCode == 200;
  }
}
