import 'package:cloud_firestore/cloud_firestore.dart';

import 'prestador_list_fields.dart';
import 'user_session.dart';

/// Sprint 3: unifica escritura de campos de listado + invalidación de cache Home.
class UsuarioListSync {
  UsuarioListSync._();

  /// Merge [patch] en `usuarios/{uid}` incluyendo `PrestadorListFields`.
  static Future<void> mergeUserDoc(
    String uid,
    Map<String, dynamic> patch, {
    bool touchListTimestamp = true,
  }) async {
    final session = UserSession();
    final base = {...(session.datosCompletos ?? {}), ...patch};
    final withList = {
      ...patch,
      ...PrestadorListFields.build(
        data: base,
        touchTimestamp: touchListTimestamp,
      ),
    };
    await FirebaseFirestore.instance
        .collection('usuarios')
        .doc(uid)
        .set(withList, SetOptions(merge: true));
    session.datosCompletos = {...(session.datosCompletos ?? {}), ...withList};
    session.invalidateHomeCache();
  }
}
