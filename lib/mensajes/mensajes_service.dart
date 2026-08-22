import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';

/// Cliente de Mensajes — CF us-east1 + lectura Firestore.
class MensajesService {
  MensajesService._();
  static final MensajesService instance = MensajesService._();

  static const String functionsRegion = 'us-east1';

  FirebaseFirestore get _db => FirebaseFirestore.instance;

  FirebaseFunctions get _fn =>
      FirebaseFunctions.instanceFor(region: functionsRegion);

  bool get hasFirebaseAuth => FirebaseAuth.instance.currentUser != null;

  String? get authUid => FirebaseAuth.instance.currentUser?.uid;

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

    final parts = convId.split('__');
    if (parts.length == 2) {
      if (parts[0] == myUid && parts[1].isNotEmpty) return parts[1];
      if (parts[1] == myUid && parts[0].isNotEmpty) return parts[0];
    }

    for (final key in [
      'prestador_uid',
      'cliente_uid',
      'pending_recibo_actor_uid',
      'pending_calificacion_actor_uid',
    ]) {
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
      throw StateError('Necesitás entrar con Google para registrar un pago');
    }
    try {
      final result = await _fn.httpsCallable('emitirRecibo').call({
        'contraparte_uid': contraparteUid,
        'monto': monto,
        'concepto': concepto,
        if (nota != null && nota.trim().isNotEmpty) 'nota': nota.trim(),
        'origen': origen,
      });
      return Map<String, dynamic>.from(result.data as Map);
    } catch (e) {
      throw StateError(humanizeError(e));
    }
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
    try {
      final result = await _fn.httpsCallable('responderRecibo').call({
        'conversacion_id': conversacionId,
        'recibo_event_id': reciboEventId,
        'decision': decision,
        if (motivo != null && motivo.trim().isNotEmpty) 'motivo': motivo.trim(),
      });
      return Map<String, dynamic>.from(result.data as Map);
    } catch (e) {
      throw StateError(humanizeError(e));
    }
  }

  Future<Map<String, dynamic>> enviarMensajeTexto({
    required String conversacionId,
    required String texto,
  }) async {
    if (!hasFirebaseAuth) {
      throw StateError('Necesitás entrar con Google para enviar mensajes');
    }
    final t = texto.trim();
    if (t.isEmpty) throw StateError('Escribí un mensaje');
    try {
      final result = await _fn.httpsCallable('enviarMensajeTexto').call({
        'conversacion_id': conversacionId,
        'texto': t,
      });
      return Map<String, dynamic>.from(result.data as Map);
    } catch (e) {
      throw StateError(humanizeError(e));
    }
  }

  /// Prestador acepta o responde una calificación pendiente (publica al score).
  Future<Map<String, dynamic>> responderCalificacion({
    required String conversacionId,
    required String calificacionEventId,
    String decision = 'aceptado',
    String? respuestaTexto,
  }) async {
    if (!hasFirebaseAuth) {
      throw StateError('Necesitás entrar con Google para responder');
    }
    try {
      final result = await _fn.httpsCallable('responderCalificacion').call({
        'conversacion_id': conversacionId,
        'calificacion_event_id': calificacionEventId,
        'decision': decision,
        if (respuestaTexto != null && respuestaTexto.trim().isNotEmpty)
          'respuesta_texto': respuestaTexto.trim(),
      });
      return Map<String, dynamic>.from(result.data as Map);
    } catch (e) {
      throw StateError(humanizeError(e));
    }
  }

  static String humanizeError(Object? e) {
    final s = '$e';
    final lower = s.toLowerCase();
    if (lower.contains('unauthenticated') || lower.contains('not-authenticated')) {
      return 'Entrá con Google para usar mensajes.';
    }
    if (lower.contains('permission-denied') || lower.contains('permission_denied')) {
      return 'No tenés permiso para esta acción.';
    }
    if (lower.contains('already-exists') || lower.contains('ya respondido')) {
      return 'Ese comprobante ya fue confirmado.';
    }
    if (lower.contains('not-found')) {
      return 'No encontramos ese registro.';
    }
    if (lower.contains('invalid-argument')) {
      return 'Datos incompletos o inválidos.';
    }
    if (lower.contains('failed-precondition')) {
      return 'No se puede completar ahora. Revisá e intentá de nuevo.';
    }
    if (lower.contains('deadline') || lower.contains('timeout') || lower.contains('unavailable')) {
      return 'Sin conexión o el servidor no respondió. Probá de nuevo.';
    }
    final m = RegExp(r'(?:FirebaseFunctionsException:\s*)?(?:\[[^\]]*\]\s*)?(.+)')
        .firstMatch(s);
    final msg = (m?.group(1) ?? s).trim();
    if (msg.length > 160) return '${msg.substring(0, 157)}…';
    return msg
        .replaceFirst('Exception: ', '')
        .replaceFirst('StateError: ', '');
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
