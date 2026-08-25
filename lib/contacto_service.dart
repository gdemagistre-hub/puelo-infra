import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';

import 'identidad_pii.dart';
import 'user_session.dart';

/// Contacto cliente → prestador.
///
/// El número ya no vive en el doc público. Se pide a
/// `obtenerContactoPrestador` (us-east1) y se registra en `contactos`.
class ContactoService {
  ContactoService._();

  static const String functionsRegion = 'us-east1';

  static bool puedeContactar(Map<String, dynamic>? data) {
    if (data == null) return false;
    if (data['tiene_whatsapp'] == true || data['tiene_telefono'] == true) {
      return true;
    }
    return IdentidadPii.telefonoDe(data).isNotEmpty;
  }

  static Future<String?> resolverTelefono({
    required String prestadorUid,
    required String tipo,
    required String origen,
    String? prestadorNombre,
    String? fallback,
  }) async {
    final me = UserSession().uid;
    if (prestadorUid.isEmpty) return null;
    if (me != null && me == prestadorUid) {
      final own = IdentidadPii.telefonoDe(UserSession().datosCompletos);
      if (own.isNotEmpty) return own;
      if ((fallback ?? '').trim().isNotEmpty) return fallback!.trim();
      return null;
    }
    if (FirebaseAuth.instance.currentUser == null) {
      debugPrint('ContactoService.resolverTelefono: sin Auth');
      return null;
    }
    try {
      final fn = FirebaseFunctions.instanceFor(region: functionsRegion);
      final result = await fn.httpsCallable('obtenerContactoPrestador').call({
        'prestador_uid': prestadorUid,
        'tipo': tipo,
        'origen': origen,
      });
      final data = Map<String, dynamic>.from(result.data as Map);
      final tel = (data['telefono'] ?? '').toString().trim();
      if (tel.isNotEmpty) return tel;
    } catch (e) {
      debugPrint('ContactoService.resolverTelefono CF: $e');
    }
    final local = (fallback ?? '').trim();
    if (local.isNotEmpty) {
      await registrar(
        prestadorUid: prestadorUid,
        tipo: tipo,
        origen: origen,
        prestadorNombre: prestadorNombre,
      );
      return local;
    }
    return null;
  }

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
      debugPrint('ContactoService.registrar error: $e');
    }
  }
}
