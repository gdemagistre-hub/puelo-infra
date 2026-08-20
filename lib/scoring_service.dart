import 'package:cloud_firestore/cloud_firestore.dart';

import 'scoring_features.dart';

/// Scoring Puelo v1.2-phase1 — TEMP minimal restore to unblock build.
/// Full body will be restored from artifacts/scoring_service_PHASE1_web_lock.dart
class ScoringService {
  ScoringService._();
  static final _db = FirebaseFirestore.instance;
  static const String modelVersion = 'v1.2-phase1.5';
  static const int techoIdentidad = 55;
  static const int techoServicio = 40;
  static const int techoCliente = 30;
  static const int techoComportamiento = 25;
  static const Duration lockTtl = Duration(minutes: 15);

  static String _unwrapErr(Object e) {
    try {
      final dynamic d = e;
      final inner = d.error;
      if (inner != null) return '$inner';
    } catch (_) {}
    return e.toString();
  }

  static Future<BatchScoringResult> ejecutarBatchDiario({
    void Function(int hechos, int total)? onProgress,
    int pageSize = 200,
    String trigger = 'app_batch',
    bool force = false,
  }) async {
    final started = DateTime.now();
    final runId =
        '${started.toUtc().toIso8601String().replaceAll(':', '-')}_$trigger';
    final jobRef = _db.collection('stats').doc('scoring_job');
    final runRef = jobRef.collection('runs').doc(runId);
    final errores = <String>[];
    try {
      // Web-safe lock (no runTransaction)
      final snap = await jobRef.get();
      final data = snap.data();
      final lock = data?['lock'];
      if (!force && lock is Map) {
        final untilRaw = lock['until'];
        DateTime? until;
        if (untilRaw is Timestamp) until = untilRaw.toDate();
        if (untilRaw is String) until = DateTime.tryParse(untilRaw);
        if (until != null && until.isAfter(DateTime.now())) {
          await runRef.set({
            'status': 'aborted_lock',
            'error_message': 'lock activo',
            'finished_at': FieldValue.serverTimestamp(),
          });
          return BatchScoringResult(
            procesados: 0,
            actualizados: 0,
            runId: runId,
            status: 'aborted_lock',
            errores: const ['lock_activo'],
            duracionMs: DateTime.now().difference(started).inMilliseconds,
          );
        }
      }
      await jobRef.set({
        'lock': {
          'holder': runId,
          'trigger': trigger,
          'acquired_at': FieldValue.serverTimestamp(),
          'until': Timestamp.fromDate(DateTime.now().add(lockTtl)),
        },
        'status': 'running',
      }, SetOptions(merge: true));

      await runRef.set({
        'run_id': runId,
        'started_at': FieldValue.serverTimestamp(),
        'trigger': trigger,
        'model_version': modelVersion,
        'status': 'running',
      });

      // Minimal pass: score identidad only for all users (Phase1 simplified)
      int procesados = 0;
      int escritos = 0;
      WriteBatch batch = _db.batch();
      int enBatch = 0;
      final users = await _db.collection('usuarios').limit(pageSize * 5).get();
      for (final doc in users.docs) {
        final d = doc.data();
        final id = calcularScoreIdentidad(d);
        final badge = calcularBadgePrestador(
          d,
          fotosPortfolio: 0,
          fotosClientes: 0,
          validaciones6mDistintas: 0,
          validadoresConCalificacion: 0,
          scoreIdentidad: id.score,
        );
        batch.set(
          doc.reference,
          {
            'badge_prestador': badge,
            'scoring': {
              'model_version': modelVersion,
              'score_identidad': id.score,
              'score_identidad_raw': id.raw,
              'score_servicio': 0,
              'score_cliente': 0,
              'score_comportamiento': 0,
              'nivel_confianza': nivelFromScore(id.score),
              'last_run_id': runId,
              'actualizado_en': FieldValue.serverTimestamp(),
            },
            'list_score_identidad': id.score,
            'list_badge': badge,
            'score_actualizado_en': FieldValue.serverTimestamp(),
          },
          SetOptions(merge: true),
        );
        enBatch++;
        escritos++;
        procesados++;
        if (enBatch >= 400) {
          await batch.commit();
          batch = _db.batch();
          enBatch = 0;
        }
      }
      if (enBatch > 0) await batch.commit();

      final duracionMs = DateTime.now().difference(started).inMilliseconds;
      await jobRef.set({
        'status': 'ok',
        'ultima_corrida': FieldValue.serverTimestamp(),
        'usuarios_procesados': procesados,
        'usuarios_actualizados': escritos,
        'last_run_id': runId,
        'model_version': modelVersion,
        'fuente': trigger,
        'duracion_ms': duracionMs,
        'lock': FieldValue.delete(),
      }, SetOptions(merge: true));
      await runRef.set({
        'status': 'ok',
        'finished_at': FieldValue.serverTimestamp(),
        'duracion_ms': duracionMs,
        'metrics': {
          'usuarios_procesados': procesados,
          'usuarios_actualizados': escritos,
        },
        'model_version': modelVersion,
      }, SetOptions(merge: true));

      return BatchScoringResult(
        procesados: procesados,
        actualizados: escritos,
        runId: runId,
        status: 'ok',
        duracionMs: duracionMs,
      );
    } catch (e) {
      final msg = _unwrapErr(e);
      try {
        await jobRef.set({
          'status': 'error',
          'error_message': msg,
          'last_run_id': runId,
          'lock': FieldValue.delete(),
        }, SetOptions(merge: true));
        await runRef.set({
          'status': 'error',
          'error_message': msg,
          'errores': ['FATAL: $msg'],
          'finished_at': FieldValue.serverTimestamp(),
        }, SetOptions(merge: true));
      } catch (_) {}
      return BatchScoringResult(
        procesados: 0,
        actualizados: 0,
        runId: runId,
        status: 'error',
        errores: ['FATAL: $msg'],
        duracionMs: DateTime.now().difference(started).inMilliseconds,
      );
    }
  }

  static LayerScoreResult calcularScoreIdentidad(
    Map<String, dynamic> data, {
    int fotosPortfolio = 0,
  }) {
    final detalle = <String, int>{};
    void add(String key, bool tiene, [int peso = 1]) {
      detalle[key] = tiene ? peso : 0;
    }
    final docValidado = data['doc_validado'] == true;
    final pesoAncla = docValidado ? 2 : 1;
    final auth = (data['auth_provider'] ?? '').toString().toLowerCase();
    add('auth_google', auth == 'google', 3);
    add('email', _noVacio(data['email']), 2);
    add('telefono', _noVacio(data['telefono']), 1);
    add('nombre', _noVacio(data['nombre']), pesoAncla);
    add('apellido', _noVacio(data['apellido']), pesoAncla);
    add('doc_numero', _noVacio(data['doc_numero'] ?? data['numero_documento']), pesoAncla);
    add('doc_ocr_validado', docValidado, 8);
    add('foto_perfil', _noVacio(data['url_foto_perfil']), 3);
    final raw = detalle.values.fold<int>(0, (a, b) => a + b);
    final score = ((100.0 * raw) / techoIdentidad).round().clamp(0, 100);
    return LayerScoreResult(raw: raw, score: score, detalle: detalle);
  }

  /// Escalera alineada a CF scoringCore:
  /// nuevo → registrado → bronce → bronce_plus (plata/oro más adelante).
  static String? calcularBadgePrestador(
    Map<String, dynamic> data, {
    required int fotosPortfolio,
    required int fotosClientes,
    required int validaciones6mDistintas,
    required int validadoresConCalificacion,
    int nEvalTrabajo = 0,
    int scoreIdentidad = 0,
  }) {
    final registrado = _noVacio(data['nombre']) &&
        _noVacio(data['apellido']) &&
        _noVacio(data['telefono']);
    final docOk = data['doc_validado'] == true;
    final tieneDoc = _noVacio(data['doc_numero'] ?? data['numero_documento']);
    final geo = data['direccion_geo'];
    final tieneZona = geo is Map &&
        (_noVacio(geo['localidad_id']) || _noVacio(geo['localidad_nombre']));
    final perfilFuerte = registrado && (tieneDoc || tieneZona || scoreIdentidad >= 30);

    if (registrado && docOk) return 'bronce_plus';
    if (perfilFuerte && scoreIdentidad >= 35) return 'bronce';
    if (registrado) return 'registrado';
    return 'nuevo';
  }

  static bool _noVacio(dynamic v) => v != null && v.toString().trim().isNotEmpty;
  static String nivelFromScore(int score) {
    if (score >= 75) return 'muy_alto';
    if (score >= 50) return 'alto';
    if (score >= 25) return 'medio';
    return 'bajo';
  }
  static String labelNivel(String? nivel) => nivel ?? 'Sin datos';

  /// Etiqueta legible para UI (nunca mostrar el id crudo).
  static String labelBadge(String? badge) {
    switch ((badge ?? '').toLowerCase().trim()) {
      case 'nuevo':
        return 'Nuevo';
      case 'registrado':
        return 'Registrado';
      case 'bronce':
        return 'Bronce';
      case 'bronce_plus':
        return 'Bronce Plus';
      case 'plata':
        return 'Plata';
      case 'oro':
        return 'Oro';
      case '':
        return 'Sin nivel aún';
      default:
        return badge!
            .split('_')
            .where((p) => p.isNotEmpty)
            .map((p) => '${p[0].toUpperCase()}${p.substring(1)}')
            .join(' ');
    }
  }

  static String explicacionBadge(String? badge) {
    switch ((badge ?? '').toLowerCase().trim()) {
      case 'nuevo':
        return 'Acabás de empezar · completá tu perfil';
      case 'registrado':
        return 'Datos básicos cargados · validá tu DNI para subir';
      case 'bronce':
        return 'Perfil sólido · seguí sumando validaciones';
      case 'bronce_plus':
        return 'Identidad validada · los clientes te ven con más confianza';
      case 'plata':
        return 'Trayectoria comprobada · alto nivel de confianza';
      case 'oro':
        return 'Referente de confianza en tu zona';
      default:
        return '';
    }
  }

  /// foreground = texto, background = chip/fondo suave.
  static ColorBadge coloresBadge(String? badge) {
    switch ((badge ?? '').toLowerCase().trim()) {
      case 'nuevo':
        return const ColorBadge(0xFF64748B, 0xFFF1F5F9);
      case 'registrado':
        return const ColorBadge(0xFF0284C7, 0xFFE0F2FE);
      case 'bronce':
        return const ColorBadge(0xFF9A6B2F, 0xFFF5E6D3);
      case 'bronce_plus':
        return const ColorBadge(0xFF8B6914, 0xFFF0E6C8);
      case 'plata':
        return const ColorBadge(0xFF475569, 0xFFE2E8F0);
      case 'oro':
        return const ColorBadge(0xFFA16207, 0xFFFEF3C7);
      default:
        return const ColorBadge(0xFF94A3B8, 0xFFF8FAFC);
    }
  }

  /// Tips priorizados (máx 6) para "Para subir tu Confianza".
  static List<Map<String, String>> generarConsejosConfianza(
    Map<String, dynamic> data, {
    int fotosPortfolio = 0,
  }) {
    final tips = <Map<String, String>>[];
    void add(String id, String titulo, String sub) {
      if (tips.length >= 6) return;
      tips.add({'id': id, 'titulo': titulo, 'subtitulo': sub});
    }

    final docOk = data['doc_validado'] == true;
    final geo = data['direccion_geo'];
    final tieneZona = geo is Map &&
        (_noVacio(geo['localidad_id']) || _noVacio(geo['localidad_nombre']));
    final profesiones = data['profesiones'] ?? data['categorias_servicio'];
    final tieneOficios = profesiones is List && profesiones.isNotEmpty;
    final capacitaciones = data['capacitaciones'];
    final nCap = capacitaciones is List ? capacitaciones.length : 0;

    if (!_noVacio(data['url_foto_perfil'])) {
      add('foto', 'Subí una foto de perfil', 'Los clientes confían más con cara visible');
    }
    if (!docOk) {
      add('ocr', 'Validá tu DNI con la cámara', 'Salto grande a Bronce Plus');
    }
    if (!_noVacio(data['telefono'])) {
      add('tel', 'Agregá tu celular', 'Necesario para que te contacten');
    }
    if (!tieneZona) {
      add('domicilio', 'Cargá tu zona de trabajo', 'Aparecés en búsquedas de tu barrio');
    }
    if (!tieneOficios) {
      add('oficios', 'Elegí tus oficios', 'Sin oficio no te encuentran en el buscador');
    }
    if (fotosPortfolio < 1) {
      add('fotos_trabajo', 'Subí fotos de trabajos hechos', 'Portfolio visible en tu tarjeta digital');
    }
    if (nCap < 1) {
      add('capacitaciones', 'Sumá un curso o capacitación', 'Suma solidez profesional (opcional)');
    }
    if (!_noVacio(data['email'])) {
      add('email', 'Confirmá tu email', 'Recuperación de cuenta y avisos');
    }
    return tips;
  }
  static Future<void> actualizarStatsNegocio({required String uid, int? nMovimientos, int? nCobros, int? nFiadosCobrados, int? nFiadosPendientes, bool? tieneFondoEmergencia}) async {}
}

class ScoreResult {
  final int total;
  final Map<String, int> detalle;
  const ScoreResult({required this.total, required this.detalle});
}
class LayerScoreResult {
  final int raw;
  final int score;
  final Map<String, int> detalle;
  final int nEventos;
  final int nConFoto;
  final int nConComentario;
  final double? ratingPromedio;
  const LayerScoreResult({required this.raw, required this.score, required this.detalle, this.nEventos = 0, this.nConFoto = 0, this.nConComentario = 0, this.ratingPromedio});
}
class BatchScoringResult {
  final int procesados;
  final int actualizados;
  final String runId;
  final String status;
  final int evalsPublicadasTimeout;
  final int evalsParCompleto;
  final List<String> errores;
  final int duracionMs;
  const BatchScoringResult({required this.procesados, required this.actualizados, this.runId = '', this.status = 'ok', this.evalsPublicadasTimeout = 0, this.evalsParCompleto = 0, this.errores = const [], this.duracionMs = 0});
}
class ValidationGate {
  final bool allowed;
  final String reason;
  const ValidationGate({required this.allowed, required this.reason});
}
class ColorBadge {
  final int foreground;
  final int background;
  const ColorBadge(this.foreground, this.background);
}
