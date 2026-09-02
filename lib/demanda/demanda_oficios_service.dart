import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../catalogo_oficios.dart';

/// Demanda de oficios (taps / búsquedas) → top 8 del día anterior.
class DemandaOficiosService {
  DemandaOficiosService._();

  static const List<String> idsDefault = [
    'electricidad',
    'plomeria',
    'gasista',
    'carpinteria',
    'pintura',
    'albanileria',
    'jardineria',
    'limpieza',
  ];

  static const List<Color> _palette = [
    Color(0xFF734BE4),
    Color(0xFF4A90E2),
    Color(0xFFF75A6D),
    Color(0xFF28B5CD),
    Color(0xFFF59E0B),
    Color(0xFF3D4756),
    Color(0xFF16A34A),
    Color(0xFF8B5CF6),
  ];

  static const Map<String, Color> _colorFijo = {
    'electricidad': Color(0xFF734BE4),
    'plomeria': Color(0xFF4A90E2),
    'gasista': Color(0xFFF75A6D),
    'carpinteria': Color(0xFF28B5CD),
    'pintura': Color(0xFFF59E0B),
    'albanileria': Color(0xFF3D4756),
    'jardineria': Color(0xFF16A34A),
    'limpieza': Color(0xFF8B5CF6),
  };

  static List<Map<String, dynamic>> iconosDefault() {
    return [
      for (var i = 0; i < idsDefault.length; i++) _iconoDe(idsDefault[i], i),
    ];
  }

  static Map<String, dynamic> _iconoDe(String id, int index) {
    return {
      'id': id,
      'label': CatalogoOficios.label(id),
      'icon': CatalogoOficios.iconFor(id),
      'color': _colorFijo[id] ?? _palette[index % _palette.length],
    };
  }

  static String? resolver(String? raw) {
    final q = (raw ?? '').trim().toLowerCase();
    if (q.isEmpty || q == 'todos') return null;
    if (CatalogoOficios.especialidad(q) != null) return q;
    final cat = CatalogoOficios.categoria(q);
    if (cat != null) {
      final list = CatalogoOficios.especialidadesDe(cat.id);
      if (list.isEmpty) return null;
      final same = list.where((e) => e.id == cat.id);
      return same.isNotEmpty ? same.first.id : list.first.id;
    }
    for (final e in CatalogoOficios.especialidades) {
      if (e.label.toLowerCase() == q) return e.id;
      if (e.sinonimos.any((s) => s.toLowerCase() == q)) return e.id;
    }
    if (raw == null) return null;
    final chip = CatalogoOficios.categoriaIdDesdeChip(raw.trim());
    if (chip != null) return resolver(chip);
    return null;
  }

  /// Día civil ART (UTC-3, sin DST). Alineado al batch 02:30 ART.
  static String ymdArt([DateTime? now]) {
    final art = (now ?? DateTime.now()).toUtc().subtract(const Duration(hours: 3));
    final y = art.year.toString().padLeft(4, '0');
    final m = art.month.toString().padLeft(2, '0');
    final d = art.day.toString().padLeft(2, '0');
    return '$y$m$d';
  }

  static Future<void> registrar(String? raw, {required String fuente}) async {
    final id = resolver(raw);
    if (id == null) return;
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null || uid.isEmpty) return;
    final fuenteOk = fuente.trim();
    if (fuenteOk.isEmpty || fuenteOk.length >= 32) return;
    try {
      final docId = '${uid}_${ymdArt()}_$id';
      await FirebaseFirestore.instance.collection('demanda_eventos').doc(docId).set({
        'oficio_id': id,
        'fuente': fuenteOk,
        'created_at': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
    } catch (e) {
      debugPrint('DemandaOficiosService.registrar: $e');
    }
  }

  static Future<List<Map<String, dynamic>>> iconosHome() async {
    final fallback = iconosDefault();
    try {
      final snap = await FirebaseFirestore.instance
          .collection('stats')
          .doc('top_servicios')
          .get();
      if (!snap.exists) return fallback;
      final raw = snap.data()?['items'];
      if (raw is! List || raw.isEmpty) return fallback;
      final seen = <String>{};
      final out = <Map<String, dynamic>>[];
      for (final item in raw) {
        if (item is! Map) continue;
        final oid = resolver(item['id']?.toString());
        if (oid == null || !seen.add(oid)) continue;
        out.add(_iconoDe(oid, out.length));
        if (out.length >= 8) break;
      }
      for (final defId in idsDefault) {
        if (out.length >= 8) break;
        if (seen.add(defId)) out.add(_iconoDe(defId, out.length));
      }
      return out.length == 8 ? out : fallback;
    } catch (e) {
      debugPrint('DemandaOficiosService.iconosHome: $e');
      return fallback;
    }
  }
}
