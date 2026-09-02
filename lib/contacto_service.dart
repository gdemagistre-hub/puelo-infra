import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';

import 'identidad_pii.dart';
import 'user_session.dart';

/// Contacto cliente → prestador.
/// El número no se lee del doc público. Sale de `obtenerContactoPrestador`.
class ContactoService {
  ContactoService._();

  static const String functionsRegion = 'us-east1';

  /// Último error humano de [resolverTelefono] (para snackbar).
  static String? lastError;

  static bool puedeContactar(Map<String, dynamic>? data) {
    if (data == null) return false;
    if (data['tiene_whatsapp'] == true || data['tiene_telefono'] == true) {
      return true;
    }
    return false;
  }

  static String _mensajeDe(Object e) {
    if (e is FirebaseFunctionsException) {
      switch (e.code) {
        case 'unauthenticated':
          return 'Entrá con tu cuenta para contactarlo';
        case 'permission-denied':
          return 'Solo se puede contactar a quien ofrece servicios';
        case 'resource-exhausted':
          return 'Llegaste al tope de contactos por hoy. Probá mañana.';
        case 'failed-precondition':
          return 'Este prestador no cargó teléfono';
        case 'not-found':
          return 'No encontramos ese perfil';
        default:
          return (e.message ?? '').trim().isEmpty
              ? 'No se pudo obtener el contacto'
              : e.message!.trim();
      }
    }
    return 'No se pudo obtener el contacto';
  }

  static Future<String?> resolverTelefono({
    required String prestadorUid,
    required String tipo,
    required String origen,
    String? prestadorNombre,
    String? fallback,
  }) async {
    lastError = null;
    final me = UserSession().uid;
    if (prestadorUid.isEmpty) return null;
    if (me != null && me == prestadorUid) {
      final own = IdentidadPii.telefonoDe(UserSession().datosCompletos);
      if (own.isNotEmpty) return own;
      lastError = 'No tenés teléfono cargado';
      return null;
    }
    if (FirebaseAuth.instance.currentUser == null) {
      lastError = 'Entrá con tu cuenta para contactarlo';
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
      lastError = 'Este prestador no cargó teléfono';
      return null;
    } catch (e) {
      lastError = _mensajeDe(e);
      debugPrint('ContactoService.resolverTelefono CF: $e');
      return null;
    }
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
