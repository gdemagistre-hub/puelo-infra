import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';

import 'invitacion_ref.dart';
import 'user_session.dart';

/// Semilla de barrio: el usuario invita desde su teléfono.
///
/// El enlace puede llevar ?i=<uid>. No lleva nombre, teléfono ni domicilio.
class InvitacionBarrio {
  static const String urlPublica = 'https://puelo.app';

  static String urlPara(String? uid) {
    final limpio = InvitacionRef.sanitizar(uid);
    if (limpio == null) return urlPublica;
    return 'https://lifewalletpuelo.web.app/?i=$limpio';
  }

  static String get textoPrestador =>
      'Si ofrecés un oficio cerca de casa, armá tu perfil en PROX. '
      'Es gratis. ${urlPara(UserSession().uid)}';

  static String get textoVecino =>
      'Si necesitás un oficio cerca de casa, mirá PROX. '
      'Es gratis. ${urlPara(UserSession().uid)}';

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
