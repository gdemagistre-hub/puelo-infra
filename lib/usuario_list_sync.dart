import 'package:cloud_firestore/cloud_firestore.dart';

import 'identidad_pii.dart';
import 'prestador_list_fields.dart';
import 'user_session.dart';

/// Sprint 3: unifica escritura de campos de listado + invalidación de cache Home.
class UsuarioListSync {
  UsuarioListSync._();

  /// Merge [patch] en `usuarios/{uid}` incluyendo `PrestadorListFields`.
  /// PII (DNI, email, calle) se escribe en `privado/identidad` y se borra del padre.
  static Future<void> mergeUserDoc(
    String uid,
    Map<String, dynamic> patch, {
    bool touchListTimestamp = true,
  }) async {
    final session = UserSession();
    final base = {...(session.datosCompletos ?? {}), ...patch};
    final pii = IdentidadPii.extraer(base);
    final publicPatch = IdentidadPii.sinPii(patch);
    if (pii.isNotEmpty) {
      publicPatch.addAll(IdentidadPii.deletesDe(pii.keys));
    }
    final withList = {
      ...publicPatch,
      ...PrestadorListFields.build(
        data: base,
        touchTimestamp: touchListTimestamp,
      ),
    };
    final db = FirebaseFirestore.instance;
    final batch = db.batch();
    if (pii.isNotEmpty) {
      batch.set(
        IdentidadPii.refDe(uid),
        {...pii, 'updated_at': FieldValue.serverTimestamp()},
        SetOptions(merge: true),
      );
    }
    batch.set(
      db.collection('usuarios').doc(uid),
      withList,
      SetOptions(merge: true),
    );
    await batch.commit();
    final sessionMap = <String, dynamic>{
      ...(session.datosCompletos ?? {}),
      ...withList,
      ...pii,
    };
    sessionMap.removeWhere((_, v) => v is FieldValue);
    session.datosCompletos = sessionMap;
    session.invalidateHomeCache();
  }
}
