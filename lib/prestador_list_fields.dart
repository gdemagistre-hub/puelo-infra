import 'package:cloud_firestore/cloud_firestore.dart';

import 'catalogo_oficios.dart';

/// Campos desnormalizados para listados / buscador (docs livianos).
/// Se escriben al guardar servicios, zona, foto o en backfill batch.
class PrestadorListFields {
  PrestadorListFields._();

  /// Extrae ids planos de cobertura para queries futuras.
  static List<String> zonaIdsFromCobertura(Map<String, dynamic>? cobertura) {
    if (cobertura == null) return const [];
    final out = <String>{};
    void add(dynamic v) {
      final s = (v ?? '').toString().trim();
      if (s.isNotEmpty) out.add(s);
    }

    add(cobertura['provincia_id']);
    final partidos = cobertura['partidos'] as List<dynamic>? ?? [];
    for (final p in partidos) {
      if (p is Map) add(p['id']);
    }
    final locs = cobertura['localidades'] as List<dynamic>? ?? [];
    for (final l in locs) {
      if (l is Map) add(l['id']);
    }
    return out.toList();
  }

  /// Payload merge-friendly a partir del mapa de usuario (completo o parcial).
  static Map<String, dynamic> build({
    required Map<String, dynamic> data,
    bool touchTimestamp = true,
  }) {
    final profesiones = (data['profesiones'] as List<dynamic>? ?? [])
        .map((e) => e.toString())
        .where((s) => s.isNotEmpty)
        .toList();
    final cats = (data['categorias_servicio'] as List<dynamic>?)
            ?.map((e) => e.toString())
            .toList() ??
        CatalogoOficios.categoriasDesdeProfesiones(profesiones);

    final nombre = (data['nombre'] ?? '').toString().trim();
    final apellido = (data['apellido'] ?? '').toString().trim();
    final comercial = (data['nombre_comercial'] ?? '').toString().trim();
    final listNombre = comercial.isNotEmpty
        ? comercial
        : ('$nombre $apellido').trim();

    final scoring = data['scoring'];
    int? scoreServicio;
    int? scoreIdentidad;
    int? scoreComportamiento;
    if (scoring is Map) {
      scoreServicio = (scoring['score_servicio'] as num?)?.toInt();
      scoreIdentidad = (scoring['score_identidad'] as num?)?.toInt();
      scoreComportamiento = (scoring['score_comportamiento'] as num?)?.toInt();
    }

    final cobertura = data['zonas_cobertura'] as Map<String, dynamic>?;
    final zonaIds = zonaIdsFromCobertura(cobertura);

    final telefono = (data['telefono'] ?? data['celular'] ?? '').toString().trim();
    final visible = profesiones.isNotEmpty &&
        zonaIds.isNotEmpty &&
        telefono.isNotEmpty;

    final payload = <String, dynamic>{
      'categorias_servicio': cats,
      'zona_ids': zonaIds,
      'list_nombre': listNombre.isEmpty ? 'Prestador' : listNombre,
      'list_foto': (data['url_foto_perfil'] ?? '').toString(),
      'list_badge': data['badge_prestador'],
      'list_promedio': data['promedioEstrellas'],
      'list_n_eval': data['cantidadEvaluadores'],
      'list_score_servicio': scoreServicio,
      'list_score_identidad': scoreIdentidad,
      'list_score_comportamiento': scoreComportamiento,
      'list_visible': visible,
      'es_trabajador': data['es_trabajador'] == true || profesiones.isNotEmpty,
      'country_code': (() {
        final c = (data['country_code'] ?? '').toString().trim().toUpperCase();
        return c.isEmpty ? 'AR' : c;
      })(),
    };
    if (touchTimestamp) {
      payload['list_updated_at'] = FieldValue.serverTimestamp();
    }
    return payload;
  }
}
