import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';

/// Semilla de barrio: el usuario invita desde su teléfono.
///
/// Límites a propósito:
/// - No escribe Firestore ni Storage.
/// - No lista usuarios ni sugiere contactos de la base.
/// - El texto compartido es fijo + URL pública. Sin uid, teléfono,
///   domicilio, zona interna ni condiciones de filtrado.
class InvitacionBarrio {
  static const String urlPublica = 'https://puelo.app';

  static const String textoPrestador =
      'Si ofrecés un oficio cerca de casa, armá tu perfil en PROX. '
      'Es gratis. $urlPublica';

  static const String textoVecino =
      'Si necesitás un oficio cerca de casa, mirá PROX. '
      'Es gratis. $urlPublica';

  static Future<void> invitarPrestador(BuildContext context) =>
      _abrir(context, textoPrestador);

  static Future<void> invitarVecino(BuildContext context) =>
      _abrir(context, textoVecino);

  static Future<void> _abrir(BuildContext context, String texto) async {
    final wa = Uri.parse(
      'https://wa.me/?text=${Uri.encodeComponent(texto)}',
    );
    var lanzado = false;
    try {
      lanzado = await launchUrl(wa, mode: LaunchMode.externalApplication);
    } catch (_) {
      lanzado = false;
    }
    if (lanzado) return;
    await Clipboard.setData(ClipboardData(text: texto));
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Mensaje copiado. Pegalo donde quieras.')),
    );
  }
}
