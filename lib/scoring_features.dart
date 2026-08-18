/// Feature vector builder for Puelo scoring → Vertex / batch export.
/// Phase 1 (2026-08-18): flat, privacy-safe features (no amounts, no PII plain).
class ScoringFeatures {
  ScoringFeatures._();

  static const String schemaVersion = 'features_v1';
  static const String modelVersion = 'v1.2-phase1';

  /// Builds a flat int/double feature map from user doc + batch layer outputs.
  /// [layerScores] keys: identidad, servicio, cliente, comportamiento, creditoPreview
  /// [counts] keys: fotosPortfolio, fotosClientes, nEvalTrabajo, nEvalCliente,
  ///   nValidaciones6m, validadoresConCalif, nEvalConFoto
  static Map<String, dynamic> build({
    required Map<String, dynamic> userData,
    required Map<String, int> layerScores,
    required Map<String, num> counts,
    String? badge,
  }) {
    final geo = userData['direccion_geo'] as Map<String, dynamic>?;
    final auth = (userData['auth_provider'] ?? '').toString().toLowerCase();
    final profesiones = userData['profesiones'] as List? ?? [];
    final caps = userData['capacitaciones'] as List? ?? [];
    final zonas = userData['zonas_cobertura'] as Map<String, dynamic>?;
    final locs = zonas?['localidades'] as List? ?? [];
    final stats = userData['stats_negocio'];
    final statsMap = stats is Map ? Map<String, dynamic>.from(stats) : null;
    final flags = userData['riesgo_fraude_flags'] as List? ?? [];
    final riesgo = (userData['riesgo_fraude'] ?? '').toString().toLowerCase();

    int b(bool v) => v ? 1 : 0;
    bool noVacio(dynamic v) => v != null && v.toString().trim().isNotEmpty;

    final diasAlta = _diasDesdeAlta(userData);
    int techoAntiguedad = 100;
    if (diasAlta != null) {
      if (diasAlta < 7) {
        techoAntiguedad = 40;
      } else if (diasAlta < 30) {
        techoAntiguedad = 70;
      }
    } else {
      techoAntiguedad = 50;
    }

    final esTrabajador = userData['es_trabajador'] == true ||
        userData['rol'] == 'trabajador';

    final badgeRank = switch ((badge ?? userData['badge_prestador'] ?? '')
        .toString()
        .toLowerCase()
        .trim()) {
      'diamante' => 6,
      'oro' => 5,
      'plata' => 4,
      'bronce_plus' => 3,
      'bronce' => 2,
      'registrado' => 1,
      'nuevo' => 0,
      _ => -1,
    };

    int riesgoCode = 0;
    if (riesgo == 'bajo') riesgoCode = 1;
    if (riesgo == 'medio') riesgoCode = 2;
    if (riesgo == 'alto') riesgoCode = 3;

    return {
      // A. Identidad
      'f_auth_google': b(auth == 'google'),
      'f_email': b(noVacio(userData['email'])),
      'f_tel': b(noVacio(userData['telefono'])),
      'f_tel_verificado': b(userData['telefono_verificado'] == true),
      'f_doc_ocr': b(userData['doc_validado'] == true),
      'f_foto_perfil': b(noVacio(userData['url_foto_perfil'])),
      'f_foto_doc': b(noVacio(userData['url_foto_documento'])),
      'f_domicilio_completo': b(noVacio(
        geo?['localidad_id'] ?? geo?['localidad_nombre'],
      )),
      'f_genero_doc': b(noVacio(
        userData['genero_documento'] ?? userData['sexo_documento'],
      )),
      'f_dias_alta': diasAlta ?? -1,
      'f_techo_antiguedad': techoAntiguedad,

      // B. Oficio
      'f_es_trabajador': b(esTrabajador),
      'f_n_oficios': profesiones.length.clamp(0, 20),
      'f_zona_cobertura': b(locs.isNotEmpty),
      'f_n_capacitaciones': caps.length.clamp(0, 10),
      'f_fotos_portfolio': (counts['fotosPortfolio'] ?? 0).toInt(),
      'f_fotos_clientes': (counts['fotosClientes'] ?? 0).toInt(),

      // C. Reputación
      'f_n_eval_trabajo': (counts['nEvalTrabajo'] ?? 0).toInt(),
      'f_n_eval_con_foto': (counts['nEvalConFoto'] ?? 0).toInt(),
      'f_rating_promedio':
          (counts['ratingPromedio'] ?? 0).toDouble().clamp(0.0, 5.0),
      'f_n_validaciones_6m': (counts['nValidaciones6m'] ?? 0).toInt(),
      'f_validadores_con_calif': (counts['validadoresConCalif'] ?? 0).toInt(),
      'f_score_servicio': layerScores['servicio'] ?? 0,
      'f_badge_rank': badgeRank,

      // D. Comportamiento (counts only)
      'f_n_movimientos': (statsMap?['n_movimientos'] as num?)?.toInt() ?? 0,
      'f_n_cobros': (statsMap?['n_cobros'] as num?)?.toInt() ?? 0,
      'f_n_fiados_pend':
          (statsMap?['n_fiados_pendientes'] as num?)?.toInt() ?? 0,
      'f_n_fiados_cobrados':
          (statsMap?['n_fiados_cobrados'] as num?)?.toInt() ?? 0,
      'f_fondo_emergencia': b(statsMap?['tiene_fondo_emergencia'] == true),
      'f_score_comportamiento': layerScores['comportamiento'] ?? 0,

      // E. Cliente
      'f_score_cliente': layerScores['cliente'] ?? 0,
      'f_n_eval_cliente': (counts['nEvalCliente'] ?? 0).toInt(),

      // F. Riesgo
      'f_riesgo_fraude': riesgoCode,
      'f_n_flags_fraude': flags.length,

      // Meta
      'f_schema': schemaVersion,
    };
  }

  static Map<String, dynamic> labels({
    required Map<String, int> layerScores,
    String? badge,
  }) {
    return {
      'y_score_identidad': layerScores['identidad'] ?? 0,
      'y_score_servicio': layerScores['servicio'] ?? 0,
      'y_score_cliente': layerScores['cliente'] ?? 0,
      'y_score_comportamiento': layerScores['comportamiento'] ?? 0,
      'y_score_credito_preview': layerScores['creditoPreview'] ?? 0,
      'y_badge': badge ?? '',
    };
  }

  /// Document payload for scoring_features/{uid}
  static Map<String, dynamic> exportDoc({
    required String uid,
    required Map<String, dynamic> userData,
    required Map<String, int> layerScores,
    required Map<String, num> counts,
    String? badge,
    String? runId,
  }) {
    return {
      'uid': uid,
      'model_version': modelVersion,
      'schema': schemaVersion,
      'run_id': runId,
      'exported_at': DateTime.now().toUtc().toIso8601String(),
      'features': build(
        userData: userData,
        layerScores: layerScores,
        counts: counts,
        badge: badge,
      ),
      'labels': labels(layerScores: layerScores, badge: badge),
    };
  }

  static int? _diasDesdeAlta(Map<String, dynamic> data) {
    final raw = data['creado_en'] ?? data['created_at'] ?? data['fecha_alta'];
    DateTime? alta;
    if (raw is DateTime) {
      alta = raw;
    } else if (raw is String) {
      alta = DateTime.tryParse(raw);
    } else {
      try {
        final dyn = raw as dynamic;
        if (dyn != null && dyn.toDate != null) {
          alta = dyn.toDate() as DateTime?;
        }
      } catch (_) {}
    }
    if (alta == null) return null;
    return DateTime.now().difference(alta).inDays;
  }
}
