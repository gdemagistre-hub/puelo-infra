import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';

/// Cliente de Mensajes M1/M2 — CF us-east1 + lectura Firestore.
class MensajesService {
  MensajesService._();
  static final MensajesService instance = MensajesService._();

  static const String functionsRegion = 'us-east1';

  FirebaseFirestore get _db => FirebaseFirestore.instance;

  FirebaseFunctions get _fn =>
      FirebaseFunctions.instanceFor(region: functionsRegion);

  /// Auth real requerida por las CF (no dropdown dev).
  bool get hasFirebaseAuth => FirebaseAuth.instance.currentUser != null;

  String? get authUid => FirebaseAuth.instance.currentUser?.uid;

  /// Preferir Auth real; fallback a sesión (dropdown).
  String? get effectiveUid => authUid;

  Stream<QuerySnapshot<Map<String, dynamic>>> watchConversaciones(String uid) {
    return _db
        .collection('conversaciones')
        .where('participantes', arrayContains: uid)
        .orderBy('last_event_at', descending: true)
        .limit(50)
        .snapshots();
  }

  Stream<QuerySnapshot<Map<String, dynamic>>> watchEventos(String convId) {
    return _db
        .collection('conversaciones')
        .doc(convId)
        .collection('eventos')
        .orderBy('created_at_iso', descending: false)
        .snapshots();
  }

  /// UID de la otra parte en el hilo (robusto ante tipos / convId).
  static String? otherParticipantUid({
    required String myUid,
    required String convId,
    Map<String, dynamic>? data,
  }) {
    if (myUid.isEmpty) return null;

    final raw = data?['participantes'];
    if (raw is List) {
      for (final p in raw) {
        final s = p?.toString() ?? '';
        if (s.isNotEmpty && s != myUid) return s;
      }
    }

    // convId = uidA__uidB (orden lex)
    final parts = convId.split('__');
    if (parts.length == 2) {
      if (parts[0] == myUid && parts[1].isNotEmpty) return parts[1];
      if (parts[1] == myUid && parts[0].isNotEmpty) return parts[0];
    }

    for (final key in ['prestador_uid', 'cliente_uid', 'pending_recibo_actor_uid']) {
      final v = data?[key]?.toString() ?? '';
      if (v.isNotEmpty && v != myUid) return v;
    }
    return null;
  }

  Future<Map<String, dynamic>?> loadUsuarioLite(String uid) async {
    try {
      final snap = await _db.collection('usuarios').doc(uid).get();
      return snap.data();
    } catch (e) {
      debugPrint('loadUsuarioLite: $e');
      return null;
    }
  }

  String displayNameFromUser(Map<String, dynamic>? d, String fallbackUid) {
    if (d != null) {
      final comercial = (d['nombre_comercial'] ?? '').toString().trim();
      if (comercial.isNotEmpty) return comercial;
      final n = '${d['nombre'] ?? ''} ${d['apellido'] ?? ''}'.trim();
      if (n.isNotEmpty) return n;
      final e = (d['email'] as String?)?.trim();
      if (e != null && e.isNotEmpty) {
        final at = e.indexOf('@');
        return at > 0 ? e.substring(0, at) : e;
      }
    }
    if (fallbackUid.length > 10) return '${fallbackUid.substring(0, 8)}…';
    return fallbackUid;
  }

  Future<String> resolveDisplayName(String uid) async {
    final d = await loadUsuarioLite(uid);
    return displayNameFromUser(d, uid);
  }

  Future<Map<String, dynamic>> emitirRecibo({
    required String contraparteUid,
    required double monto,
    required String concepto,
    String? nota,
    String origen = 'mensajes',
  }) async {
    if (!hasFirebaseAuth) {
      throw StateError('Necesitás entrar con Google para emitir recibos');
    }
    final result = await _fn.httpsCallable('emitirRecibo').call({
      'contraparte_uid': contraparteUid,
      'monto': monto,
      'concepto': concepto,
      if (nota != null && nota.trim().isNotEmpty) 'nota': nota.trim(),
      'origen': origen,
    });
    return Map<String, dynamic>.from(result.data as Map);
  }

  Future<Map<String, dynamic>> responderRecibo({
    required String conversacionId,
    required String reciboEventId,
    required String decision,
    String? motivo,
  }) async {
    if (!hasFirebaseAuth) {
      throw StateError('Necesitás entrar con Google para responder');
    }
    final result = await _fn.httpsCallable('responderRecibo').call({
      'conversacion_id': conversacionId,
      'recibo_event_id': reciboEventId,
      'decision': decision,
      if (motivo != null && motivo.trim().isNotEmpty) 'motivo': motivo.trim(),
    });
    return Map<String, dynamic>.from(result.data as Map);
  }

  static String labelConcepto(String? c) {
    switch ((c ?? '').toLowerCase()) {
      case 'sena':
        return 'Seña';
      case 'anticipo':
        return 'Anticipo';
      case 'saldo':
        return 'Saldo';
      case 'pago_total':
        return 'Pago total';
      default:
        return 'Otro';
    }
  }

  static String formatMonto(dynamic m) {
    final n = m is num ? m.toDouble() : double.tryParse('$m') ?? 0;
    final s = n.toStringAsFixed(n.truncateToDouble() == n ? 0 : 2);
    final parts = s.split('.');
    final intPart = parts[0].replaceAllMapped(
      RegExp(r'(\d)(?=(\d{3})+(?!\d))'),
      (m) => '${m[1]}.',
    );
    if (parts.length > 1) return '\$$intPart,${parts[1]}';
    return '\$$intPart';
  }
}
