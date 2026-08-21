import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';

import '../../user_session.dart';

/// Progreso de Academia (gate de readiness microcrédito).
///
/// Escribe en `usuarios/{uid}.academia`:
/// - lecciones_completadas: [id, …]
/// - n_completadas: int
/// - ultima_leccion_id / ultima_en
///
/// [ReadinessService] lee estos campos (no suma al 0–100; es gate 3+).
class AcademiaProgress {
  AcademiaProgress._();

  static final _db = FirebaseFirestore.instance;

  static String? get _uid {
    final auth = FirebaseAuth.instance.currentUser?.uid;
    if (auth != null && auth.isNotEmpty) return auth;
    final session = UserSession().uid;
    if (session != null && session.isNotEmpty) return session;
    return null;
  }

  /// Marca una cápsula como leída (idempotente).
  /// Devuelve el total de cápsulas completadas, o null si no hay sesión.
  static Future<int?> marcarCompletada(String leccionId) async {
    final uid = _uid;
    if (uid == null || leccionId.trim().isEmpty) return null;

    final ref = _db.collection('usuarios').doc(uid);
    try {
      return await _db.runTransaction((tx) async {
        final snap = await tx.get(ref);
        final data = snap.data() ?? <String, dynamic>{};
        final ac = Map<String, dynamic>.from(
          data['academia'] is Map
              ? Map<String, dynamic>.from(data['academia'] as Map)
              : <String, dynamic>{},
        );
        final raw = ac['lecciones_completadas'] ?? ac['completed'] ?? [];
        final list = <String>[
          for (final e in (raw is List ? raw : const []))
            e.toString().trim(),
        ]..removeWhere((e) => e.isEmpty);

        if (!list.contains(leccionId)) {
          list.add(leccionId);
        }

        ac['lecciones_completadas'] = list;
        ac['n_completadas'] = list.length;
        ac['ultima_leccion_id'] = leccionId;
        ac['ultima_en'] = FieldValue.serverTimestamp();

        tx.set(
          ref,
          {
            'academia': ac,
            'academia_capsulas_completadas': list.length,
          },
          SetOptions(merge: true),
        );
        return list.length;
      });
    } catch (e) {
      debugPrint('AcademiaProgress.marcarCompletada: $e');
      return null;
    }
  }

  /// IDs de lecciones ya leídas (vacío si no hay sesión / error).
  static Future<Set<String>> idsCompletadas() async {
    final uid = _uid;
    if (uid == null) return {};
    try {
      final snap = await _db.collection('usuarios').doc(uid).get();
      final data = snap.data() ?? {};
      final ac = data['academia'];
      if (ac is Map) {
        final raw = ac['lecciones_completadas'] ?? ac['completed'] ?? [];
        if (raw is List) {
          return {
            for (final e in raw)
              if (e.toString().trim().isNotEmpty) e.toString().trim(),
          };
        }
      }
    } catch (e) {
      debugPrint('AcademiaProgress.idsCompletadas: $e');
    }
    return {};
  }
}
