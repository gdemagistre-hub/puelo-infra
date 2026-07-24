import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

/// Carga única de usuarios dummy a Firestore.
/// Borrar este archivo después de usarlo.
class ImportDummyUsuarios {
  static const String assetPath = 'assets/usuarios_dummy_500.json';
  static const String collection = 'usuarios';

  static Future<ImportResult> ejecutar({
    void Function(int hechos, int total)? onProgress,
  }) async {
    String raw;
    try {
      raw = await rootBundle.loadString(assetPath);
    } catch (e) {
      throw Exception(
        'No se pudo leer el asset "$assetPath". '
        '¿Está el archivo en el repo y en pubspec assets/jsons/? Detalle: $e',
      );
    }

    final trimmed = raw.trimLeft();
    if (trimmed.startsWith('<!DOCTYPE') || trimmed.startsWith('<html')) {
      throw Exception(
        'El asset "$assetPath" no está en el build web (se recibió HTML 404). '
        'Confirmá que el JSON esté commiteado en assets/jsons/ y redeployá.',
      );
    }
    if (!trimmed.startsWith('[')) {
      throw Exception(
        'El contenido de "$assetPath" no es un array JSON. '
        'Empieza con: ${trimmed.substring(0, trimmed.length > 40 ? 40 : trimmed.length)}',
      );
    }

    final lista = jsonDecode(raw) as List<dynamic>;
    final total = lista.length;
    final db = FirebaseFirestore.instance;

    int hechos = 0;
    WriteBatch batch = db.batch();
    int enBatch = 0;

    for (var i = 0; i < lista.length; i++) {
      final map = Map<String, dynamic>.from(lista[i] as Map);
      final id = 'dummy_${(i + 1).toString().padLeft(3, '0')}';

      final creadoStr = map['creado_en'];
      if (creadoStr is String && creadoStr.isNotEmpty) {
        map['creado_en'] = Timestamp.fromDate(DateTime.parse(creadoStr));
      }

      final vals = map['validaciones_recibidas'];
      if (vals is List) {
        for (final v in vals) {
          if (v is Map && v['fecha'] is String) {
            v['fecha'] = Timestamp.fromDate(DateTime.parse(v['fecha'] as String));
          }
        }
      }

      final ventas = map['ventas'];
      if (ventas is List) {
        for (final s in ventas) {
          if (s is Map && s['fecha'] is String) {
            s['fecha'] = Timestamp.fromDate(DateTime.parse(s['fecha'] as String));
          }
        }
      }

      map['dummy'] = true;

      final ref = db.collection(collection).doc(id);
      batch.set(ref, map, SetOptions(merge: true));
      enBatch++;
      hechos++;

      if (enBatch >= 400) {
        await batch.commit();
        batch = db.batch();
        enBatch = 0;
        onProgress?.call(hechos, total);
      }
    }

    if (enBatch > 0) {
      await batch.commit();
      onProgress?.call(hechos, total);
    }

    if (kDebugMode) {
      debugPrint('ImportDummyUsuarios: $hechos / $total');
    }

    return ImportResult(total: total, importados: hechos);
  }

  /// Borra por flag dummy y también por IDs dummy_001…dummy_500
  static Future<int> borrarTodosDummy() async {
    final db = FirebaseFirestore.instance;
    int borrados = 0;

    // 1) Por query dummy == true
    try {
      final snap = await db.collection(collection).where('dummy', isEqualTo: true).get();
      WriteBatch batch = db.batch();
      int enBatch = 0;
      for (final doc in snap.docs) {
        batch.delete(doc.reference);
        enBatch++;
        borrados++;
        if (enBatch >= 400) {
          await batch.commit();
          batch = db.batch();
          enBatch = 0;
        }
      }
      if (enBatch > 0) await batch.commit();
    } catch (_) {
      // Si falta índice, seguimos con borrado por ID
    }

    // 2) Por IDs fijos (no necesita índice)
    WriteBatch batch2 = db.batch();
    int enBatch2 = 0;
    for (var i = 1; i <= 500; i++) {
      final id = 'dummy_${i.toString().padLeft(3, '0')}';
      batch2.delete(db.collection(collection).doc(id));
      enBatch2++;
      if (enBatch2 >= 400) {
        await batch2.commit();
        batch2 = db.batch();
        enBatch2 = 0;
      }
    }
    if (enBatch2 > 0) await batch2.commit();

    return borrados > 0 ? borrados : 500;
  }
}

class ImportResult {
  final int total;
  final int importados;
  const ImportResult({required this.total, required this.importados});
}
