import 'package:cloud_firestore/cloud_firestore.dart';

/// Madurez para microcrédito (V1).
///
/// Independiente del score/badge públicos del marketplace.
/// Academia es **indicativa** (gate educativo): no suma al 0–100.
class ReadinessService {
  ReadinessService._();
  static final _db = FirebaseFirestore.instance;

  /// Mínimo de cápsulas de Academia para considerar preparación financiera.
  static const int academiaMinRequeridas = 3;

  /// Pesos (suman 100). Solo capas operativas / KYC / actividad.
  static const int wIdentidad = 10;
  static const int wKyc = 25;
  static const int wFoto = 5;
  static const int wZona = 10;
  static const int wScoreId = 15;
  static const int wReputacion = 15;
  static const int wMisNumeros = 20;
  static const int wColchon = 5;

  static bool _noVacio(dynamic v) =>
      v != null && v.toString().trim().isNotEmpty;

  /// Calcula readiness a partir del doc usuario + senales opcionales de subcolecciones.
  static ReadinessResult calcular(
    Map<String, dynamic> data, {
    int nMovimientos = 0,
    int nCobros = 0,
    bool? tieneFondoEmergencia,
    int nCapsulasAcademia = 0,
  }) {
    final detalle = <String, int>{};

    // 1) Identidad base
    final idBase = _noVacio(data['nombre']) &&
        _noVacio(data['apellido']) &&
        (_noVacio(data['telefono']) || _noVacio(data['email']));
    detalle['identidad'] = idBase ? wIdentidad : 0;

    // 2) KYC / DNI
    final docOk = data['doc_validado'] == true;
    detalle['kyc'] = docOk ? wKyc : 0;

    // 3) Foto
    detalle['foto'] =
        _noVacio(data['url_foto_perfil'] ?? data['foto_perfil']) ? wFoto : 0;

    // 4) Zona / domicilio
    final geo = data['direccion_geo'];
    final tieneZona = (geo is Map &&
            (_noVacio(geo['localidad_id']) ||
                _noVacio(geo['localidad_nombre']))) ||
        _noVacio(data['calle']);
    detalle['zona'] = tieneZona ? wZona : 0;

    // 5) Score identidad existente (solo input; no lo modifica)
    final scoring = data['scoring'];
    int scoreId = 0;
    if (data['list_score_identidad'] is num) {
      scoreId = (data['list_score_identidad'] as num).toInt();
    } else if (scoring is Map && scoring['score_identidad'] is num) {
      scoreId = (scoring['score_identidad'] as num).toInt();
    }
    // Escalado lineal 0..100 → 0..wScoreId
    detalle['score_id'] =
        ((scoreId.clamp(0, 100) / 100.0) * wScoreId).round();

    // 6) Reputación marketplace
    final nEvalRaw =
        data['list_n_evaluaciones'] ?? data['nEvaluaciones'] ?? 0;
    final nEval =
        nEvalRaw is num ? nEvalRaw.toInt() : (int.tryParse('$nEvalRaw') ?? 0);
    final starsRaw = data['list_promedio'] ?? data['promedioEstrellas'] ?? 0;
    final stars = starsRaw is num
        ? starsRaw.toDouble()
        : (double.tryParse('$starsRaw') ?? 0.0);
    int rep = 0;
    if (nEval >= 5 && stars >= 4.0) {
      rep = wReputacion;
    } else if (nEval >= 3 && stars >= 3.5) {
      rep = (wReputacion * 0.7).round();
    } else if (nEval >= 1) {
      rep = (wReputacion * 0.4).round();
    }
    detalle['reputacion'] = rep;

    // 7) Mis números — preferir stats denormalizados; si no, conteos pasados
    final stats = data['stats_negocio'];
    int mov = nMovimientos;
    int cobros = nCobros;
    if (stats is Map) {
      final sm = stats['n_movimientos'] ?? stats['movimientos'];
      final sc = stats['n_cobros'] ?? stats['cobros'];
      if (sm is num) mov = sm.toInt();
      if (sc is num) cobros = sc.toInt();
    }
    int mn = 0;
    if (cobros >= 8 || mov >= 15) {
      mn = wMisNumeros;
    } else if (cobros >= 3 || mov >= 5) {
      mn = (wMisNumeros * 0.6).round();
    } else if (mov >= 1 || cobros >= 1) {
      mn = (wMisNumeros * 0.25).round();
    }
    detalle['mis_numeros'] = mn;

    // 8) Colchón / fondo emergencia
    bool fondo = tieneFondoEmergencia ?? false;
    if (!fondo && stats is Map) {
      fondo = stats['tiene_fondo_emergencia'] == true ||
          stats['fondo_emergencia'] == true;
    }
    if (!fondo && data['meta_fondo_emergencia'] == true) fondo = true;
    // metas array con flag
    final metas = data['metas'];
    if (!fondo && metas is List) {
      for (final m in metas) {
        if (m is Map &&
            (m['esFondoEmergencia'] == true ||
                m['es_fondo_emergencia'] == true)) {
          fondo = true;
          break;
        }
      }
    }
    detalle['colchon'] = fondo ? wColchon : 0;

    final score =
        detalle.values.fold<int>(0, (a, b) => a + b).clamp(0, 100);

    // Academia: solo gate
    int nCap = nCapsulasAcademia;
    final ac = data['academia'];
    if (ac is Map) {
      final nc = ac['n_completadas'] ?? ac['completadas'] ?? ac['n'];
      if (nc is num) nCap = nc.toInt();
    }
    if (data['academia_capsulas_completadas'] is num) {
      nCap = (data['academia_capsulas_completadas'] as num).toInt();
    }
    final academiaOk = nCap >= academiaMinRequeridas;

    final bucket = score >= 70
        ? 'listo'
        : score >= 40
            ? 'casi'
            : 'lejos';

    final next = _nextStep(
      detalle: detalle,
      docOk: docOk,
      idBase: idBase,
      tieneZona: tieneZona,
      mov: mov,
      cobros: cobros,
      fondo: fondo,
      nEval: nEval,
      academiaOk: academiaOk,
      nCap: nCap,
    );

    return ReadinessResult(
      score: score,
      bucket: bucket,
      detalle: detalle,
      nextStep: next,
      nMovimientos: mov,
      nCobros: cobros,
      academiaN: nCap,
      academiaOk: academiaOk,
      ofertaElegible: score >= 70 && academiaOk,
    );
  }

  static String _nextStep({
    required Map<String, int> detalle,
    required bool docOk,
    required bool idBase,
    required bool tieneZona,
    required int mov,
    required int cobros,
    required bool fondo,
    required int nEval,
    required bool academiaOk,
    required int nCap,
  }) {
    // Prioridad: lo que más mueve readiness o el gate educativo
    if (!docOk) return 'Validá tu DNI con la cámara';
    if (!idBase) return 'Completá nombre, apellido y teléfono o email';
    if (detalle['foto'] == 0) return 'Subí una foto de perfil';
    if (!tieneZona) return 'Cargá domicilio o zona de trabajo';
    if (cobros < 3 && mov < 5) {
      return 'Registrá cobros en Mis números (meta: 3+)';
    }
    if (nEval < 1) return 'Conseguí tu primera calificación de cliente';
    if (!fondo) return 'Activá el colchón / fondo de emergencia';
    if (!academiaOk) {
      return 'Completá $academiaMinRequeridas cápsulas de Academia '
          '(vas $nCap)';
    }
    if (cobros < 8) return 'Seguí cargando cobros para fortalecer tu historial';
    return 'Perfil sólido · candidato a microcrédito';
  }

  /// Enrichment liviano: cuenta movimientos (tope) sin barrer todo.
  static Future<({int mov, int cobros, bool fondo})> _senalesNegocio(
    String uid,
    Map<String, dynamic> data,
  ) async {
    final stats = data['stats_negocio'];
    if (stats is Map &&
        (stats['n_movimientos'] is num || stats['n_cobros'] is num)) {
      final mov = (stats['n_movimientos'] as num?)?.toInt() ?? 0;
      final cob = (stats['n_cobros'] as num?)?.toInt() ?? 0;
      final fondo = stats['tiene_fondo_emergencia'] == true;
      return (mov: mov, cobros: cob, fondo: fondo);
    }

    int mov = 0;
    int cobros = 0;
    try {
      final snap = await _db
          .collection('usuarios')
          .doc(uid)
          .collection('movimientos')
          .limit(40)
          .get();
      mov = snap.docs.length;
      for (final d in snap.docs) {
        final t = (d.data()['tipo'] ?? d.data()['type'] ?? '')
            .toString()
            .toLowerCase();
        if (t.contains('cobro') || t == 'ingreso' || t == 'venta') {
          cobros++;
        }
      }
    } catch (_) {}

    bool fondo = false;
    try {
      final metas = await _db
          .collection('usuarios')
          .doc(uid)
          .collection('metas')
          .limit(20)
          .get();
      for (final d in metas.docs) {
        final m = d.data();
        if (m['esFondoEmergencia'] == true ||
            m['es_fondo_emergencia'] == true) {
          fondo = true;
          break;
        }
      }
    } catch (_) {}

    return (mov: mov, cobros: cobros, fondo: fondo);
  }

  static int _academiaFromData(Map<String, dynamic> data) {
    final ac = data['academia'];
    if (ac is Map) {
      final nc = ac['n_completadas'] ?? ac['completadas'] ?? ac['n'];
      if (nc is num) return nc.toInt();
      final list = ac['lecciones_completadas'] ?? ac['completed'];
      if (list is List) return list.length;
    }
    if (data['academia_capsulas_completadas'] is num) {
      return (data['academia_capsulas_completadas'] as num).toInt();
    }
    return 0;
  }

  /// Batch: escribe solo campos readiness_* (no toca badge/list/scoring público).
  static Future<ReadinessBatchResult> recalcularTodos({
    int pageSize = 150,
    int maxUsers = 800,
    void Function(int hechos, int total)? onProgress,
  }) async {
    final started = DateTime.now();
    int procesados = 0;
    int escritos = 0;
    final errores = <String>[];

    QueryDocumentSnapshot<Map<String, dynamic>>? last;
    while (procesados < maxUsers) {
      Query<Map<String, dynamic>> q =
          _db.collection('usuarios').orderBy(FieldPath.documentId).limit(pageSize);
      if (last != null) q = q.startAfterDocument(last);
      final snap = await q.get();
      if (snap.docs.isEmpty) break;

      WriteBatch batch = _db.batch();
      int enBatch = 0;

      for (final doc in snap.docs) {
        last = doc;
        procesados++;
        try {
          final data = doc.data();
          final sig = await _senalesNegocio(doc.id, data);
          final nCap = _academiaFromData(data);
          final r = calcular(
            data,
            nMovimientos: sig.mov,
            nCobros: sig.cobros,
            tieneFondoEmergencia: sig.fondo,
            nCapsulasAcademia: nCap,
          );
          batch.set(
            doc.reference,
            {
              'readiness_microcredito': r.score,
              'readiness_bucket': r.bucket,
              'readiness_detalle': r.detalle,
              'readiness_next_step': r.nextStep,
              'readiness_academia': {
                'n_capsulas': r.academiaN,
                'ok': r.academiaOk,
                'min_requeridas': academiaMinRequeridas,
              },
              'readiness_oferta_elegible': r.ofertaElegible,
              'readiness_actualizado_en': FieldValue.serverTimestamp(),
            },
            SetOptions(merge: true),
          );
          enBatch++;
          escritos++;
          if (enBatch >= 400) {
            await batch.commit();
            batch = _db.batch();
            enBatch = 0;
          }
        } catch (e) {
          if (errores.length < 8) errores.add('${doc.id}: $e');
        }
        onProgress?.call(procesados, maxUsers);
      }
      if (enBatch > 0) await batch.commit();
      if (snap.docs.length < pageSize) break;
    }

    return ReadinessBatchResult(
      procesados: procesados,
      actualizados: escritos,
      errores: errores,
      duracionMs: DateTime.now().difference(started).inMilliseconds,
    );
  }

  /// Recalcula un solo uid (detalle admin / debug).
  static Future<ReadinessResult> recalcularUid(String uid) async {
    final doc = await _db.collection('usuarios').doc(uid).get();
    final data = doc.data() ?? {};
    final sig = await _senalesNegocio(uid, data);
    final r = calcular(
      data,
      nMovimientos: sig.mov,
      nCobros: sig.cobros,
      tieneFondoEmergencia: sig.fondo,
      nCapsulasAcademia: _academiaFromData(data),
    );
    await doc.reference.set({
      'readiness_microcredito': r.score,
      'readiness_bucket': r.bucket,
      'readiness_detalle': r.detalle,
      'readiness_next_step': r.nextStep,
      'readiness_academia': {
        'n_capsulas': r.academiaN,
        'ok': r.academiaOk,
        'min_requeridas': academiaMinRequeridas,
      },
      'readiness_oferta_elegible': r.ofertaElegible,
      'readiness_actualizado_en': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
    return r;
  }
}

class ReadinessResult {
  final int score;
  final String bucket;
  final Map<String, int> detalle;
  final String nextStep;
  final int nMovimientos;
  final int nCobros;
  final int academiaN;
  final bool academiaOk;
  final bool ofertaElegible;

  const ReadinessResult({
    required this.score,
    required this.bucket,
    required this.detalle,
    required this.nextStep,
    this.nMovimientos = 0,
    this.nCobros = 0,
    this.academiaN = 0,
    this.academiaOk = false,
    this.ofertaElegible = false,
  });
}

class ReadinessBatchResult {
  final int procesados;
  final int actualizados;
  final List<String> errores;
  final int duracionMs;

  const ReadinessBatchResult({
    required this.procesados,
    required this.actualizados,
    this.errores = const [],
    this.duracionMs = 0,
  });
}
