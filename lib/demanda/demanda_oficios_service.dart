import 'package:cloud_firestore/cloud_firestore.dart';
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

  static Future<void> registrar(String? raw, {required String fuente}) async {
    final id = resolver(raw);
    if (id == null) return;
    try {
      await FirebaseFirestore.instance.collection('demanda_eventos').add({
        'oficio_id': id,
        'fuente': fuente,
        'created_at': FieldValue.serverTimestamp(),
      });
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
        final id = resolver(item['id']?.toString());
        if (id == null || !seen.add(id)) continue;
        out.add(_iconoDe(id, out.length));
        if (out.length >= 8) break;
      }
      for (final id in idsDefault) {
        if (out.length >= 8) break;
        if (seen.add(id)) out.add(_iconoDe(id, out.length));
      }
      return out.length == 8 ? out : fallback;
    } catch (e) {
      debugPrint('DemandaOficiosService.iconosHome: $e');
      return fallback;
    }
  }
}
