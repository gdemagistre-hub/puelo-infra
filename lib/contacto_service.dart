import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';

import 'user_session.dart';

/// Registra un intento de contacto cliente → prestador.
///
/// Colección: `contactos/{autoId}`
/// Campos:
///   - cliente_uid
///   - prestador_uid
///   - tipo: whatsapp | llamada
///   - origen: buscador | tarjeta
///   - prestador_nombre (opcional)
///   - cliente_nombre (opcional, para el espejo del prestador)
///   - created_at (serverTimestamp)
class ContactoService {
  ContactoService._();

  static Future<void> registrar({
    required String prestadorUid,
    required String tipo,
    required String origen,
    String? prestadorNombre,
  }) async {
    final clienteUid = UserSession().uid;
    if (clienteUid == null || clienteUid.isEmpty) {
      debugPrint('ContactoService: sin sesión, no se registra');
      return;
    }
    if (prestadorUid.isEmpty) return;
    // No registrar si el cliente se contacta a sí mismo
    if (clienteUid == prestadorUid) return;

    final clienteNombre = UserSession().nombreCompleto.trim();

    try {
      await FirebaseFirestore.instance.collection('contactos').add({
        'cliente_uid': clienteUid,
        'prestador_uid': prestadorUid,
        'tipo': tipo,
        'origen': origen,
        if (prestadorNombre != null && prestadorNombre.isNotEmpty)
          'prestador_nombre': prestadorNombre,
        if (clienteNombre.isNotEmpty) 'cliente_nombre': clienteNombre,
        'created_at': FieldValue.serverTimestamp(),
      });
    } catch (e) {
      // Nunca bloquear el flujo de contacto por un fallo de log
      debugPrint('ContactoService.registrar error: $e');
    }
  }
}
