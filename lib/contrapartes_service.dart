import 'package:cloud_firestore/cloud_firestore.dart';

import 'user_session.dart';

/// Contrapartes con las que el usuario ya operó (contacto o hilo).
/// Sin sesión → vacío. No lista el directorio completo.
class ContrapartesService {
  ContrapartesService._();

  static Future<Set<String>> prestadoresDeCliente(String uid) async {
    final ids = <String>{};
    if (uid.isEmpty) return ids;
    try {
      final snap = await FirebaseFirestore.instance
          .collection('contactos')
          .where('cliente_uid', isEqualTo: uid)
          .limit(100)
          .get();
      for (final d in snap.docs) {
        final p = (d.data()['prestador_uid'] ?? '').toString().trim();
        if (p.isNotEmpty && p != uid) ids.add(p);
      }
    } catch (_) {}
    try {
      final snap = await FirebaseFirestore.instance
          .collection('conversaciones')
          .where('participantes', arrayContains: uid)
          .limit(50)
          .get();
      for (final d in snap.docs) {
        final parts = d.data()['participantes'];
        if (parts is! List) continue;
        for (final raw in parts) {
          final p = raw.toString().trim();
          if (p.isNotEmpty && p != uid) ids.add(p);
        }
      }
    } catch (_) {}
    return ids;
  }

  static bool get haySesion {
    final uid = UserSession().uid;
    return uid != null && uid.isNotEmpty;
  }
}
