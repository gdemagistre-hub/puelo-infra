import 'package:cloud_firestore/cloud_firestore.dart';

/// PII que no debe vivir en el documento público `usuarios/{uid}`.
///
/// Firestore no enmascara campos en un get/list: o se lee el doc entero o no.
/// La proyección pública es el padre (nombre, badge, zona, foto,
/// `tiene_whatsapp` / `tiene_telefono`). El número exacto va a
/// `usuarios/{uid}/privado/identidad` y se revela sólo vía CF al contactar.
class IdentidadPii {
  IdentidadPii._();

  static const Set<String> keys = {
    'doc_numero',
    'numero_documento',
    'documento',
    'documento_tipo',
    'documento_pais',
    'tipo_doc',
    'tipo_documento',
    'pais_doc',
    'pais_emision',
    'genero_documento',
    'sexo_documento',
    'fecha_nacimiento',
    'email',
    'url_foto_documento',
    'foto_documento',
    'dni_frente',
    'dni_dorso',
    'url_dni_frente',
    'url_dni_dorso',
    'foto_dni_frente',
    'foto_dni_dorso',
    'calle',
    'numero',
    'piso',
    'piso_depto',
    'depto',
    'cp',
    'codigo_postal',
    'cuit',
    'cuil',
    'doc_hash_datos',
    'telefono',
    'celular',
    'phone',
    'whatsapp',
    'telefono_whatsapp',
  };

  static DocumentReference<Map<String, dynamic>> refDe(String uid) =>
      FirebaseFirestore.instance
          .collection('usuarios')
          .doc(uid)
          .collection('privado')
          .doc('identidad');

  static Map<String, dynamic> extraer(Map<String, dynamic> data) {
    final out = <String, dynamic>{};
    for (final k in keys) {
      if (data.containsKey(k) && data[k] != null) {
        out[k] = data[k];
      }
    }
    return out;
  }

  static Map<String, dynamic> deletesDe(Iterable<String> ks) => {
        for (final k in ks) k: FieldValue.delete(),
      };

  static Map<String, dynamic> sinPii(Map<String, dynamic> data) {
    final out = Map<String, dynamic>.from(data);
    out.removeWhere((k, _) => keys.contains(k));
    return out;
  }

  static String telefonoDe(Map<String, dynamic>? data) {
    if (data == null) return '';
    return (data['telefono'] ?? data['celular'] ?? data['phone'] ?? '')
        .toString()
        .trim();
  }

  static Future<Map<String, dynamic>> cargar(String uid) async {
    try {
      final snap = await refDe(uid).get();
      if (snap.exists && snap.data() != null) {
        return Map<String, dynamic>.from(snap.data()!);
      }
    } catch (e) {
      // Sin permiso o red: el caller sigue con el padre.
    }
    return {};
  }

  static Future<Map<String, dynamic>> mezclar(
    String uid,
    Map<String, dynamic> parent,
  ) async {
    final pii = await cargar(uid);
    if (pii.isEmpty) return Map<String, dynamic>.from(parent);
    return {...parent, ...pii};
  }

  /// Si el padre todavía tiene PII, la copia a privado y la borra del padre.
  /// Deja flags públicos de contacto (`tiene_telefono` / `tiene_whatsapp`).
  static Future<Map<String, dynamic>> hidratarYMigrar(
    String uid,
    Map<String, dynamic> parent,
  ) async {
    final fromParent = extraer(parent);
    if (fromParent.isNotEmpty) {
      try {
        final batch = FirebaseFirestore.instance.batch();
        batch.set(
          refDe(uid),
          {...fromParent, 'updated_at': FieldValue.serverTimestamp()},
          SetOptions(merge: true),
        );
        final parentPatch = deletesDe(fromParent.keys);
        final tel = telefonoDe(fromParent);
        if (tel.isNotEmpty) {
          parentPatch['tiene_telefono'] = true;
          if (parent['tiene_whatsapp'] != false) {
            parentPatch['tiene_whatsapp'] = parent['tiene_whatsapp'] == true ||
                !parent.containsKey('tiene_whatsapp');
          }
        }
        batch.set(
          FirebaseFirestore.instance.collection('usuarios').doc(uid),
          parentPatch,
          SetOptions(merge: true),
        );
        await batch.commit();
      } catch (_) {}
    }
    final stored = await cargar(uid);
    return {...parent, ...fromParent, ...stored};
  }
}
