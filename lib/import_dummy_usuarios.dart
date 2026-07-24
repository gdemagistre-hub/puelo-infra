import 'dart:convert';
import 'package:flutter/services.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

/// Carga única de usuarios dummy a Firestore.
/// Borrar este archivo después de usarlo.
class ImportDummyUsuarios {
  static const String assetPath = 'assets/jsons/usuarios_dummy_500.json';
  static const String collection = 'usuarios';

  /// Importa los 500 registros.
  /// - IDs: dummy_001 … dummy_500 (fáciles de borrar)
  /// - No duplica si ya existen (merge)
  /// - Convierte creado_en ISO → Timestamp
  static Future<ImportResult> ejecutar({
    void Function(int hechos, int total)? onProgress,
  }) async {
    final raw = await rootBundle.loadString(assetPath);
    final lista = jsonDecode(raw) as List<dynamic>;
    final total = lista.length;
    final db = FirebaseFirestore.instance;

    int hechos = 0;
    WriteBatch batch = db.batch();
    int enBatch = 0;

    for (var i = 0; i < lista.length; i++) {
      final map = Map<String, dynamic>.from(lista[i] as Map);
      final id = 'dummy_${(i + 1).toString().padLeft(3, '0')}';

      // ISO string → Timestamp
      final creadoStr = map['creado_en'];
      if (creadoStr is String && creadoStr.isNotEmpty) {
        map['creado_en'] = Timestamp.fromDate(DateTime.parse(creadoStr));
      }

      // Fechas internas de validaciones y ventas
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

    return ImportResult(total: total, importados: hechos);
  }

  /// Borra todos los docs con dummy == true (o por prefijo de id).
  static Future<int> borrarTodosDummy() async {
    final db = FirebaseFirestore.instance;
    final snap = await db
        .collection(collection)
        .where('dummy', isEqualTo: true)
        .get();

    int borrados = 0;
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
    return borrados;
  }
}

class ImportResult {
  final int total;
  final int importados;
  const ImportResult({required this.total, required this.importados});
}
