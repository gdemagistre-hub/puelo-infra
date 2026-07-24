import 'package:cloud_firestore/cloud_firestore.dart';

/// Cálculo de score crediticio + badge de prestador.
/// Pensado para corrida batch 1× día (no en cada save de pantalla).
class ScoringService {
  ScoringService._();

  static final _db = FirebaseFirestore.instance;

  // ---------------------------------------------------------------------------
  // SCORE CRÉDITO
  // ---------------------------------------------------------------------------

  /// Cada campo con dato = 1 punto.
  /// Si doc_validado == true, los 6 campos de identidad ancla valen 2 c/u.
  static ScoreResult calcularScoreCredito(
    Map<String, dynamic> data, {
    int fotosClientes = 0,
  }) {
    final detalle = <String, int>{};
    final docValidado = data['doc_validado'] == true;
    final pesoId = docValidado ? 2 : 1;

    void add(String key, bool tiene, [int? peso]) {
      detalle[key] = tiene ? (peso ?? 1) : 0;
    }

    // Identidad ancla (×2 si documento validado por OCR)
    add('nombre', _noVacio(data['nombre']), pesoId);
    add('apellido', _noVacio(data['apellido']), pesoId);
    add(
      'tipo_doc',
      _noVacio(data['tipo_doc'] ?? data['tipo_documento']),
      pesoId,
    );
    add(
      'pais_doc',
      _noVacio(data['pais_doc'] ?? data['pais_emision'] ?? data['documento_pais']),
      pesoId,
    );
    add(
      'doc_numero',
      _noVacio(
        data['doc_numero'] ?? data['numero_documento'] ?? data['documento'],
      ),
      pesoId,
    );
    add('fecha_nacimiento', data['fecha_nacimiento'] != null, pesoId);

    // Resto siempre 1
    add(
      'foto_documento',
      _noVacio(data['url_foto_documento']),
    );
    add('email', _noVacio(data['email']));
    add(
      'instagram',
      _noVacio(data['instagram'] ?? data['usuario_instagram']),
    );

    // Domicilio
    add('calle', _noVacio(data['calle']));
    add('numero', _noVacio(data['numero']));
    final geo = data['direccion_geo'] as Map<String, dynamic>?;
    add('provincia_dom', _noVacio(geo?['provincia_id'] ?? geo?['provincia_nombre']));
    add('partido_dom', _noVacio(geo?['partido_id'] ?? geo?['partido_nombre']));
    add('localidad_dom', _noVacio(geo?['localidad_id'] ?? geo?['localidad_nombre']));
    add('cp', _noVacio(data['cp'] ?? data['codigo_postal']));

    // Especialidad laboral
    add('nombre_comercial', _noVacio(data['nombre_comercial']));
    final profesiones = data['profesiones'] as List<dynamic>? ?? [];
    add('oficios', profesiones.isNotEmpty);

    // Zona de trabajo
    final zonas = data['zonas_cobertura'] as Map<String, dynamic>?;
    add(
      'provincia_zona',
      _noVacio(zonas?['provincia_id'] ?? zonas?['provincia_nombre']),
    );
    final partidosZona = zonas?['partidos'] as List<dynamic>? ?? [];
    final locsZona = zonas?['localidades'] as List<dynamic>? ?? [];
    add('partido_zona', partidosZona.isNotEmpty);
    add('localidad_zona', locsZona.isNotEmpty);

    // Trabajos de clientes (escalonado)
    int ptsTrabajos = 0;
    if (fotosClientes >= 10) {
      ptsTrabajos = 3;
    } else if (fotosClientes >= 5) {
      ptsTrabajos = 2;
    } else if (fotosClientes >= 1) {
      ptsTrabajos = 1;
    }
    detalle['trabajos_clientes'] = ptsTrabajos;

    final total = detalle.values.fold<int>(0, (a, b) => a + b);
    return ScoreResult(total: total, detalle: detalle);
  }

  // ---------------------------------------------------------------------------
  // BADGE PRESTADOR
  // ---------------------------------------------------------------------------

  /// Escalera: nuevo → registrado → bronce → bronce_plus → plata
  static String? calcularBadgePrestador(
    Map<String, dynamic> data, {
    required int fotosPortfolio,
    required int fotosClientes,
    required int validaciones6mDistintas,
    required int validadoresConCalificacion,
  }) {
    final tieneFotos = (fotosPortfolio + fotosClientes) > 0;
    final docValidado = data['doc_validado'] == true;
    final registrado = _cumpleRegistrado(data);
    final alta = _fechaAlta(data);
    final esNuevoPorTiempo =
        alta != null && DateTime.now().difference(alta).inDays < 30;

    // Plata
    if (registrado &&
        tieneFotos &&
        docValidado &&
        validaciones6mDistintas >= 10 &&
        validadoresConCalificacion >= 10) {
      return 'plata';
    }

    // Bronce+
    if (registrado && tieneFotos && docValidado) {
      return 'bronce_plus';
    }

    // Bronce
    if (registrado && tieneFotos) {
      return 'bronce';
    }

    // Registrado (reemplaza Nuevo aunque tenga < 30 días)
    if (registrado) {
      return 'registrado';
    }

    // Nuevo solo si < 30 días y no llegó a Registrado
    if (esNuevoPorTiempo) {
      return 'nuevo';
    }

    // > 30 días sin checklist → sin identificador
    return null;
  }

  static bool _cumpleRegistrado(Map<String, dynamic> data) {
    final geo = data['direccion_geo'] as Map<String, dynamic>?;
    return _noVacio(data['nombre']) &&
        _noVacio(data['apellido']) &&
        _noVacio(data['telefono']) &&
        _noVacio(data['tipo_doc'] ?? data['tipo_documento']) &&
        _noVacio(
          data['pais_doc'] ?? data['pais_emision'] ?? data['documento_pais'],
        ) &&
        _noVacio(
          data['doc_numero'] ?? data['numero_documento'] ?? data['documento'],
        ) &&
        _noVacio(geo?['provincia_id'] ?? geo?['provincia_nombre']) &&
        _noVacio(geo?['partido_id'] ?? geo?['partido_nombre']) &&
        _noVacio(geo?['localidad_id'] ?? geo?['localidad_nombre']);
  }

  static DateTime? _fechaAlta(Map<String, dynamic> data) {
    final raw = data['creado_en'] ?? data['created_at'] ?? data['fecha_alta'];
    if (raw is Timestamp) return raw.toDate();
    if (raw is String) return DateTime.tryParse(raw);
    return null;
  }

  static bool _noVacio(dynamic v) {
    if (v == null) return false;
    return v.toString().trim().isNotEmpty;
  }

  // ---------------------------------------------------------------------------
  // LABELS / UI
  // ---------------------------------------------------------------------------

  static String labelBadge(String? badge) {
    switch (badge) {
      case 'nuevo':
        return 'Nuevo';
      case 'registrado':
        return 'Registrado';
      case 'bronce':
        return 'Bronce';
      case 'bronce_plus':
        return 'Bronce+';
      case 'plata':
        return 'Plata';
      case 'oro':
        return 'Oro';
      case 'diamante':
        return 'Diamante';
      default:
        return '';
    }
  }

  static ColorBadge coloresBadge(String? badge) {
    switch (badge) {
      case 'nuevo':
        return const ColorBadge(0xFF7AAFFF, 0xFFE8F4FF);
      case 'registrado':
        return const ColorBadge(0xFF3D4756, 0xFFEEF1F4);
      case 'bronce':
        return const ColorBadge(0xFFB45309, 0xFFFFF7ED);
      case 'bronce_plus':
        return const ColorBadge(0xFFC2410C, 0xFFFFEDD5);
      case 'plata':
        return const ColorBadge(0xFF64748B, 0xFFF1F5F9);
      case 'oro':
        return const ColorBadge(0xFFCA8A04, 0xFFFEF9C3);
      case 'diamante':
        return const ColorBadge(0xFF0EA5E9, 0xFFE0F2FE);
      default:
        return const ColorBadge(0xFF94A3B8, 0xFFF8FAFC);
    }
  }

  // ---------------------------------------------------------------------------
  // BATCH DIARIO
  // ---------------------------------------------------------------------------

  /// Recorre usuarios, agrega conteos de trabajos y escribe score + badge.
  /// Llamar 1× día (Cloud Function o disparo manual admin).
  static Future<BatchScoringResult> ejecutarBatchDiario({
    void Function(int hechos, int total)? onProgress,
    int pageSize = 200,
  }) async {
    // 1) Pre-agregar trabajos
    final fotosPortfolio = <String, int>{};
    final fotosClientes = <String, int>{};

    final trabajosSnap = await _db.collection('trabajos').get();
    for (final t in trabajosSnap.docs) {
      final d = t.data();
      final uid = _resolverUsuarioId(d);
      if (uid == null) continue;

      final imgs = d['imagenes'] as List<dynamic>? ?? [];
      final n = imgs.length;
      if (n == 0) continue;

      final esPortfolio = d['tipo'] == 'portfolio' ||
          d['cuenta_como_experiencia'] == false ||
          d['cargadoPor'] == 'Trabajador';

      if (esPortfolio) {
        fotosPortfolio[uid] = (fotosPortfolio[uid] ?? 0) + n;
      } else {
        fotosClientes[uid] = (fotosClientes[uid] ?? 0) + n;
      }
    }

    // 2) Cache liviano de "tiene calificaciones" para validadores (Plata)
    final tieneCalifCache = <String, bool>{};

    Future<bool> validadorTieneCalificaciones(String validadorId) async {
      if (tieneCalifCache.containsKey(validadorId)) {
        return tieneCalifCache[validadorId]!;
      }
      final doc = await _db.collection('usuarios').doc(validadorId).get();
      if (!doc.exists) {
        tieneCalifCache[validadorId] = false;
        return false;
      }
      final d = doc.data()!;
      final n = (d['cantidadEvaluadores'] as num?)?.toInt() ?? 0;
      final ok = n > 0;
      tieneCalifCache[validadorId] = ok;
      return ok;
    }

    // 3) Paginar usuarios
    Query<Map<String, dynamic>> query =
        _db.collection('usuarios').orderBy(FieldPath.documentId).limit(pageSize);

    int totalProcesados = 0;
    int escritos = 0;
    DocumentSnapshot? last;

    while (true) {
      final snap = last == null
          ? await query.get()
          : await query.startAfterDocument(last).get();

      if (snap.docs.isEmpty) break;

      WriteBatch batch = _db.batch();
      int enBatch = 0;

      for (final doc in snap.docs) {
        final data = doc.data();
        final uid = doc.id;

        final fp = fotosPortfolio[uid] ?? 0;
        final fc = fotosClientes[uid] ?? 0;

        final score = calcularScoreCredito(data, fotosClientes: fc);

        // Validaciones últimos 6 meses
        final corte = DateTime.now().subtract(const Duration(days: 183));
        final vals = data['validaciones_recibidas'] as List<dynamic>? ?? [];
        final idsVal = <String>{};
        for (final v in vals) {
          if (v is! Map) continue;
          DateTime? fecha;
          final f = v['fecha'];
          if (f is Timestamp) fecha = f.toDate();
          if (f is String) fecha = DateTime.tryParse(f);
          if (fecha == null || fecha.isBefore(corte)) continue;
          final vid = (v['validador_id'] ?? v['usuario_id'] ?? v['uid'] ?? '')
              .toString();
          if (vid.isNotEmpty) idsVal.add(vid);
        }

        int validadoresConCalif = 0;
        for (final vid in idsVal) {
          if (await validadorTieneCalificaciones(vid)) {
            validadoresConCalif++;
          }
        }

        final badge = calcularBadgePrestador(
          data,
          fotosPortfolio: fp,
          fotosClientes: fc,
          validaciones6mDistintas: idsVal.length,
          validadoresConCalificacion: validadoresConCalif,
        );

        batch.set(
          doc.reference,
          {
            'score_credito': score.total,
            'score_credito_detalle': score.detalle,
            'badge_prestador': badge,
            'score_actualizado_en': FieldValue.serverTimestamp(),
            'badge_actualizado_en': FieldValue.serverTimestamp(),
            'stats_scoring': {
              'fotos_portfolio': fp,
              'fotos_clientes': fc,
              'validaciones_6m': idsVal.length,
              'validadores_con_calificacion': validadoresConCalif,
            },
          },
          SetOptions(merge: true),
        );

        enBatch++;
        escritos++;
        totalProcesados++;
        onProgress?.call(totalProcesados, -1);

        if (enBatch >= 400) {
          await batch.commit();
          batch = _db.batch();
          enBatch = 0;
        }
      }

      if (enBatch > 0) await batch.commit();

      last = snap.docs.last;
      if (snap.docs.length < pageSize) break;
    }

    // Marca de corrida global
    await _db.collection('stats').doc('scoring_job').set({
      'ultima_corrida': FieldValue.serverTimestamp(),
      'usuarios_procesados': totalProcesados,
      'fuente': 'app_batch',
    }, SetOptions(merge: true));

    return BatchScoringResult(
      procesados: totalProcesados,
      actualizados: escritos,
    );
  }

  static String? _resolverUsuarioId(Map<String, dynamic> trabajo) {
    final uid = trabajo['usuario_id']?.toString();
    if (uid != null && uid.isNotEmpty) return uid;
    final ref = trabajo['trabajadorRef'];
    if (ref is DocumentReference) return ref.id;
    if (ref is String) {
      if (ref.contains('/')) return ref.split('/').last;
      return ref;
    }
    return null;
  }
}

class ScoreResult {
  final int total;
  final Map<String, int> detalle;
  const ScoreResult({required this.total, required this.detalle});
}

class BatchScoringResult {
  final int procesados;
  final int actualizados;
  const BatchScoringResult({
    required this.procesados,
    required this.actualizados,
  });
}

class ColorBadge {
  final int foreground;
  final int background;
  const ColorBadge(this.foreground, this.background);
}
