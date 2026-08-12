import 'dart:convert';

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:http/http.dart' as http;

/// Envío de emails vía EmailJS (sin backend propio).
///
/// Dashboard: https://dashboard.emailjs.com
/// Si falla en producción, revisar:
/// 1) Email Services → reconectar Gmail/proveedor (permiso "Send email on your behalf")
/// 2) Account → Security → dominios permitidos incluyen lifewalletpuelo.web.app
/// 3) Template: campos to_email / to_name / validation_link (o email / name / link)
class EmailService {
  static const String serviceId = 'service_pfwycby';
  static const String templateId = 'template_z0lfetl';
  static const String publicKey = 's7JFHKYeK9i4-aTMs';

  static bool get isConfigured =>
      publicKey.isNotEmpty && serviceId.isNotEmpty && templateId.isNotEmpty;

  /// Envía el email de activación de cuenta.
  /// Lanza [Exception] con detalle de EmailJS si falla.
  static Future<bool> enviarValidacionCuenta({
    required String toEmail,
    required String toName,
    required String validationLink,
  }) async {
    if (!isConfigured) {
      throw Exception('EmailJS no está configurado correctamente.');
    }

    // No forzar Origin: en web el browser lo envía solo (lifewalletpuelo.web.app).
    final headers = <String, String>{
      'Content-Type': 'application/json',
    };
    if (!kIsWeb) {
      headers['Origin'] = 'https://lifewalletpuelo.web.app';
    }

    final body = <String, dynamic>{
      'service_id': serviceId,
      'template_id': templateId,
      'user_id': publicKey,
      'template_params': {
        'to_email': toEmail,
        'to_name': toName,
        'validation_link': validationLink,
        'email': toEmail,
        'name': toName,
        'link': validationLink,
        'message': 'Activá tu cuenta en Puelo con este enlace: $validationLink',
      },
    };

    final response = await http.post(
      Uri.parse('https://api.emailjs.com/api/v1.0/email/send'),
      headers: headers,
      body: jsonEncode(body),
    );

    if (response.statusCode == 200) return true;

    final detail = response.body.trim().isEmpty
        ? 'HTTP ${response.statusCode}'
        : response.body.trim();
    throw Exception(
      'No se pudo enviar el email ($detail). '
      'Revisá EmailJS: servicio conectado, template y dominio permitido.',
    );
  }
}
