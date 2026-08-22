import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';

/// Servicio de Mensajes (M1–M5): listar hilos, emitir/responder recibo, texto libre.
class MensajesService {
  MensajesService._();
  static final MensajesService instance = MensajesService._();

  final _db = FirebaseFirestore.instance;
  final _fn = FirebaseFunctions.instance;

  CollectionReference<Map<String, dynamic>> get _conversaciones =>
      _db.collection('conversaciones');

  /// UID real de Auth (Google / email). Null si solo hay sesión de prueba.
  String? get _authUid => FirebaseAuth.instance.currentUser?.uid;

  /// Lista conversaciones del usuario autenticado (orden last_event_at desc).
  Stream<QuerySnapshot<Map<String, dynamic>>> streamMisConversaciones() {
    final uid = _authUid;
    if (uid == null) {
      return const Stream.empty();
    }
    return _conversaciones
        .where('participantes', arrayContains: uid)
        .orderBy('last_event_at', descending: true)
        .limit(50)
        .snapshots();
  }

  /// Eventos de un hilo (append-only).
  Stream<QuerySnapshot<Map<String, dynamic>>> streamEventos(String convId) {
    return _conversaciones
        .doc(convId)
        .collection('eventos')
        .orderBy('created_at')
        .snapshots();
  }

  /// Nombre legible de la contraparte a partir del doc de conversación.
  String nombreContraparte(Map<String, dynamic> data, String myUid) {
    final parts = (data['participantes'] as List?)?.cast<String>() ?? [];
    final other = parts.where((p) => p != myUid).toList();
    if (other.isEmpty) return 'Conversación';
    final nombres = data['nombres'] as Map?;
    if (nombres != null && nombres[other.first] != null) {
      return nombres[other.first].toString();
    }
    return other.first;
  }

  /// Resumen de última actividad.
  String resumen(Map<String, dynamic> data) {
    final s = data['last_summary'] as String?;
    if (s != null && s.trim().isNotEmpty) return s;
    return 'Sin actividad';
  }

  bool tienePendiente(Map<String, dynamic> data) {
    final p = data['pending_recibo_event_id'];
    return p != null && p.toString().isNotEmpty;
  }

  /// Actor del recibo pendiente (para saber si me toca responder).
  String? pendingActorUid(Map<String, dynamic> data) {
    return data['pending_recibo_actor_uid'] as String?;
  }

  Future<Map<String, dynamic>> emitirRecibo({
    required String contraparteUid,
    required double monto,
    required String concepto,
    String? nota,
  }) async {
    if (_authUid == null) {
      throw StateError('Necesitás entrar con Google para registrar un pago');
    }
    try {
      final result = await _fn.httpsCallable('emitirRecibo').call({
        'contraparte_uid': contraparteUid,
        'monto': monto,
        'concepto': concepto,
        if (nota != null && nota.trim().isNotEmpty) 'nota': nota.trim(),
      });
      return Map<String, dynamic>.from(result.data as Map);
    } on FirebaseFunctionsException catch (e) {
      throw StateError(_humanizeError(e));
    }
  }

  Future<Map<String, dynamic>> responderRecibo({
    required String conversacionId,
    required String reciboEventId,
    required String decision, // aceptado | rechazado
    String? motivo,
  }) async {
    if (_authUid == null) {
      throw StateError('Necesitás entrar con Google');
    }
    try {
      final result = await _fn.httpsCallable('responderRecibo').call({
        'conversacion_id': conversacionId,
        'recibo_event_id': reciboEventId,
        'decision': decision,
        if (motivo != null && motivo.trim().isNotEmpty) 'motivo': motivo.trim(),
      });
      return Map<String, dynamic>.from(result.data as Map);
    } on FirebaseFunctionsException catch (e) {
      throw StateError(_humanizeError(e));
    }
  }

  Future<Map<String, dynamic>> enviarMensajeTexto({
    required String conversacionId,
    required String texto,
  }) async {
    if (_authUid == null) {
      throw StateError('Necesitás entrar con Google');
    }
    try {
      final result = await _fn.httpsCallable('enviarMensajeTexto').call({
        'conversacion_id': conversacionId,
        'texto': texto,
      });
      return Map<String, dynamic>.from(result.data as Map);
    } on FirebaseFunctionsException catch (e) {
      throw StateError(_humanizeError(e));
    }
  }

  String _humanizeError(FirebaseFunctionsException e) {
    final code = e.code;
    final msg = e.message ?? '';
    if (code == 'unauthenticated') {
      return 'Sesión expirada. Entrá de nuevo con Google.';
    }
    if (code == 'permission-denied') {
      return 'No tenés permiso para esta acción.';
    }
    if (code == 'not-found') {
      return 'No se encontró la conversación o el comprobante.';
    }
    if (code == 'failed-precondition') {
      if (msg.contains('pendiente')) {
        return 'Ya hay un comprobante pendiente en este hilo.';
      }
      if (msg.contains('propio')) {
        return 'No podés confirmar tu propio comprobante.';
      }
      return msg.isNotEmpty ? msg : 'No se pudo completar la acción.';
    }
    if (code == 'already-exists' || msg.contains('ya fue')) {
      return 'Ese comprobante ya fue confirmado.';
    }
    if (kDebugMode) {
      return '[$code] $msg';
    }
    return msg.isNotEmpty ? msg : 'Error al contactar el servidor.';
  }
}
