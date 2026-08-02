import 'package:cloud_firestore/cloud_firestore.dart';

/// Scoring Puelo v1.0 — scorecard por capas (sin ML).
///
/// Capas:
///   A) score_identidad  — confianza de perfil (visible)
///   B) score_servicio   — calidad como prestador (visible)
///   C) score_cliente    — confiabilidad como cliente (visible)
///   D) score_credito    — preview interno (NO mostrar en UI de esta etapa)
///
/// Badge prestador: escalera de hitos (nuevo → … → plata).
/// Pensado para batch 1× día (no en cada save de pantalla).
class ScoringService {
  ScoringService._();

  static final _db = FirebaseFirestore.instance;

  /// Versión del modelo documentada (changelog en commits).
  static const String modelVersion = 'v1.0';

  /// Techo raw de identidad para normalizar a 0–100.
  static const int techoIdentidad = 50;

  /// Techo raw de servicio / cliente (acumulación de eventos).
  static const int techoServicio = 40;
  static const int techoCliente = 30;

  // ---------------------------------------------------------------------------
  // CAPA A — IDENTIDAD (confianza de perfil)
  // ---------------------------------------------------------------------------

  /// Puntos por señales del propio usuario. Normaliza a 0–100.
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

    // Auth
    final auth = (data['auth_provider'] ?? '').toString().toLowerCase();
    add('auth_google', auth == 'google', 3);
    add('auth_facebook', auth == 'facebook', 2);
    add('auth_apple', auth == 'apple', 3);
    if (auth.isEmpty ||
        (auth != 'google' && auth != 'facebook' && auth != 'apple')) {
      add('auth_app', true, 1);
    }

    // Contacto
    add('email', _noVacio(data['email']), 2);
    add('telefono', _noVacio(data['telefono']), 1);
    add('telefono_verificado', data['telefono_verificado'] == true, 4);
    add('email_verificado', data['email_verificado'] == true, 2);

    // Identidad ancla (bonus si OCR validó)
    add('nombre', _noVacio(data['nombre']), pesoAncla);
    add('apellido', _noVacio(data['apellido']), pesoAncla);
    add(
      'tipo_doc',
      _noVacio(data['tipo_doc'] ?? data['tipo_documento']),
      pesoAncla,
    );
    add(
      'pais_doc',
      _noVacio(
        data['pais_doc'] ?? data['pais_emision'] ?? data['documento_pais'],
      ),
      pesoAncla,
    );
    add(
      'doc_numero',
      _noVacio(
        data['doc_numero'] ?? data['numero_documento'] ?? data['documento'],
      ),
      pesoAncla,
    );
    add('fecha_nacimiento', data['fecha_nacimiento'] != null, pesoAncla);
    add(
      'genero_documento',
      _noVacio(data['genero_documento'] ?? data['sexo_documento']),
      1,
    );

    // Documento / OCR
    add('foto_documento', _noVacio(data['url_foto_documento']), 3);
    add('doc_ocr_validado', docValidado, 8);

    // Presencia
    add('foto_perfil', _noVacio(data['url_foto_perfil']), 3);
    add(
      'instagram',
      _noVacio(data['instagram'] ?? data['usuario_instagram']),
      1,
    );

    // Domicilio
    add('calle', _noVacio(data['calle']), 1);
    add('numero', _noVacio(data['numero']), 1);
    final geo = data['direccion_geo'] as Map<String, dynamic>?;
    add(
      'provincia_dom',
      _noVacio(geo?['provincia_id'] ?? geo?['provincia_nombre']),
      1,
    );
    add(
      'partido_dom',
      _noVacio(geo?['partido_id'] ?? geo?['partido_nombre']),
      1,
    );
    add(
      'localidad_dom',
      _noVacio(geo?['localidad_id'] ?? geo?['localidad_nombre']),
      2,
    );
    add('cp', _noVacio(data['cp'] ?? data['codigo_postal']), 1);

    // Prestador
    final esTrabajador =
        data['es_trabajador'] == true || data['rol'] == 'trabajador';
    if (esTrabajador) {
      add('nombre_comercial', _noVacio(data['nombre_comercial']), 1);
      final profesiones = data['profesiones'] as List<dynamic>? ?? [];
      add('oficios', profesiones.isNotEmpty, 2);
      final zonas = data['zonas_cobertura'] as Map<String, dynamic>?;
      final locs = zonas?['localidades'] as List<dynamic>? ?? [];
      add('zona_cobertura', locs.isNotEmpty, 2);
      final fotosPropias = fotosPortfolio.clamp(0, 5);
      detalle['fotos_trabajos_propias'] = fotosPropias; // 1 c/u máx 5
    }

    final raw = detalle.values.fold<int>(0, (a, b) => a + b);
    final normalizado = _normalizar(raw, techoIdentidad);
    return LayerScoreResult(
      raw: raw,
      score: normalizado,
      detalle: detalle,
    );
  }

  // ---------------------------------------------------------------------------
  // CAPA B — SERVICIO (reputación como prestador)
  // ---------------------------------------------------------------------------

  /// Acumula puntos de validaciones/evals de terceros con multiplicador.
  static LayerScoreResult calcularScoreServicio({
    required List<Map<String, dynamic>> eventos,
    required Map<String, int> scoreIdentidadEvaluadores,
    required Map<String, bool> evaluadorTieneHistorial,
    required Map<String, bool> evaluadorEsNuevo,
    required int scoreIdentidadReceptor,
  }) {
    final detalle = <String, int>{};
    double rawDouble = 0;
    int nEval = 0;
    int nConFoto = 0;
    int nConComentario = 0;
    double sumaRating = 0;
    int nRating = 0;

    for (var i = 0; i < eventos.length; i++) {
      final e = eventos[i];
      final tipo = (e['tipo'] ?? e['tipo_validacion'] ?? 'trabajo')
          .toString()
          .toLowerCase();
      final conFoto = e['con_foto'] == true ||
          e['tiene_foto'] == true ||
          _noVacio(e['url_foto']) ||
          ((e['fotos'] as List?)?.isNotEmpty ?? false);
      final conComentario = _noVacio(e['comentario'] ?? e['texto'] ?? e['review']);
      final evalId =
          (e['evaluador_id'] ?? e['validador_id'] ?? e['usuario_id'] ?? '')
              .toString();

      int base;
      if (tipo.contains('identidad') || tipo == 'quien_es' || tipo == 'persona') {
        base = 3;
      } else if (conFoto && conComentario) {
        base = 4;
      } else if (conFoto) {
        base = 3;
      } else {
        base = 2;
      }

      // Foto de trabajo confirmada por cliente
      if (e['foto_validada_por_cliente'] == true) {
        base += 1;
      }

      final mult = _multiplicadorEvaluador(
        evaluadorId: evalId,
        scoreIdentidadReceptor: scoreIdentidadReceptor,
        scoreIdentidadEvaluadores: scoreIdentidadEvaluadores,
        evaluadorTieneHistorial: evaluadorTieneHistorial,
        evaluadorEsNuevo: evaluadorEsNuevo,
        soloIdentidad: tipo.contains('identidad') || tipo == 'quien_es',
      );

      // Par publicado a tiempo → bonus 10%
      final parBonus = e['par_completo'] == true ? 1.10 : 1.0;
      final pts = base * mult * parBonus;
      rawDouble += pts;
      nEval++;
      if (conFoto) nConFoto++;
      if (conComentario) nConComentario++;

      final rating = e['rating'] ?? e['estrellas'] ?? e['puntaje'];
      if (rating is num) {
        sumaRating += rating.toDouble();
        nRating++;
      }

      detalle['evt_$i'] = (pts * 100).round(); // centésimas para detalle
    }

    detalle['n_eval'] = nEval;
    detalle['n_con_foto'] = nConFoto;
    detalle['n_con_comentario'] = nConComentario;

    final raw = rawDouble.round();
    final normalizado = _normalizar(raw, techoServicio);
    final ratingPromedio = nRating > 0 ? sumaRating / nRating : null;

    return LayerScoreResult(
      raw: raw,
      score: normalizado,
      detalle: detalle,
      nEventos: nEval,
      nConFoto: nConFoto,
      nConComentario: nConComentario,
      ratingPromedio: ratingPromedio,
    );
  }

  // ---------------------------------------------------------------------------
  // CAPA C — CLIENTE
  // ---------------------------------------------------------------------------

  static LayerScoreResult calcularScoreCliente({
    required List<Map<String, dynamic>> eventos,
    required Map<String, int> scoreIdentidadEvaluadores,
    required Map<String, bool> evaluadorTieneHistorial,
    required Map<String, bool> evaluadorEsNuevo,
    required int scoreIdentidadReceptor,
  }) {
    final detalle = <String, int>{};
    double rawDouble = 0;
    int n = 0;

    for (var i = 0; i < eventos.length; i++) {
      final e = eventos[i];
      const base = 2;
      final evalId =
          (e['evaluador_id'] ?? e['validador_id'] ?? e['usuario_id'] ?? '')
              .toString();
      final mult = _multiplicadorEvaluador(
        evaluadorId: evalId,
        scoreIdentidadReceptor: scoreIdentidadReceptor,
        scoreIdentidadEvaluadores: scoreIdentidadEvaluadores,
        evaluadorTieneHistorial: evaluadorTieneHistorial,
        evaluadorEsNuevo: evaluadorEsNuevo,
        soloIdentidad: false,
      );
      final parBonus = e['par_completo'] == true ? 1.10 : 1.0;
      final aTiempo = e['respondio_en_plazo'] == true ? 0.5 : 0.0;
      final pts = base * mult * parBonus + aTiempo;
      rawDouble += pts;
      n++;
      detalle['evt_$i'] = (pts * 100).round();
    }

    detalle['n_eval'] = n;
    var raw = rawDouble.round();
    var score = _normalizar(raw, techoCliente);

    // Identidad baja → techo 60 en score_cliente
    if (scoreIdentidadReceptor < 25 && score > 60) {
      score = 60;
      detalle['tope_identidad_baja'] = 60;
    }

    return LayerScoreResult(
      raw: raw,
      score: score,
      detalle: detalle,
      nEventos: n,
    );
  }

  /// Multiplicador anti-fraude del evaluador (planilla v1, suavizado cold-start).
  static double _multiplicadorEvaluador({
    required String evaluadorId,
    required int scoreIdentidadReceptor,
    required Map<String, int> scoreIdentidadEvaluadores,
    required Map<String, bool> evaluadorTieneHistorial,
    required Map<String, bool> evaluadorEsNuevo,
    required bool soloIdentidad,
  }) {
    if (evaluadorId.isEmpty) return 0.25;

    if (soloIdentidad && evaluadorTieneHistorial[evaluadorId] != true) {
      // Solo hizo validaciones de “quién es”
      return 0.15;
    }

    if (evaluadorEsNuevo[evaluadorId] == true) {
      return 0.25;
    }

    final idEval = scoreIdentidadEvaluadores[evaluadorId] ?? 0;
    if (idEval <= scoreIdentidadReceptor) {
      return 0.50;
    }

    // score_identidad > receptor
    if (evaluadorTieneHistorial[evaluadorId] == true) {
      return 1.00;
    }
    return 0.70;
  }

  // ---------------------------------------------------------------------------
  // CAPA D — CRÉDITO PREVIEW (interno, no UI)
  // ---------------------------------------------------------------------------

  /// Preview alineado a futuro microcrédito. NO mostrar al usuario en esta etapa.
  static int calcularScoreCreditoPreview({
    required int scoreIdentidad,
    required int scoreServicio,
    required int scoreCliente,
    bool esTrabajador = false,
  }) {
    // Pesos tentativos v1: identidad 35%, reputación 25%, resto reservado
    final reputacion = esTrabajador ? scoreServicio : scoreCliente;
    final v = (0.35 * scoreIdentidad) + (0.25 * reputacion) + (0.40 * 0);
    return v.round().clamp(0, 100);
  }

  /// Compat: mantiene la API anterior usada por batch viejo / tests.
  /// Ahora devuelve raw de identidad (+ fotos clientes como señal débil).
  static ScoreResult calcularScoreCredito(
    Map<String, dynamic> data, {
    int fotosClientes = 0,
  }) {
    final id = calcularScoreIdentidad(data);
    final detalle = Map<String, int>.from(id.detalle);
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
    int nEvalTrabajo = 0,
  }) {
    final tieneFotos = (fotosPortfolio + fotosClientes) > 0;
    final tieneFotoPerfil = _noVacio(data['url_foto_perfil']);
    final docValidado = data['doc_validado'] == true;
    final registrado = _cumpleRegistrado(data);
    final alta = _fechaAlta(data);
    final esNuevoPorTiempo =
        alta != null && DateTime.now().difference(alta).inDays < 30;

    // Plata: trayectoria + identidad fuerte
    if (registrado &&
        tieneFotos &&
        docValidado &&
        (validaciones6mDistintas >= 10 || nEvalTrabajo >= 10) &&
        validadoresConCalificacion >= 10) {
      return 'plata';
    }

    // Bronce+: registrado + fotos trabajo + OCR + (foto perfil recomendada)
    if (registrado && tieneFotos && docValidado) {
      return 'bronce_plus';
    }

    // Bronce: registrado + (fotos trabajo O foto perfil con al menos 1 eval)
    if (registrado && (tieneFotos || (tieneFotoPerfil && nEvalTrabajo >= 1))) {
      return 'bronce';
    }

    if (registrado) {
      return 'registrado';
    }

    if (esNuevoPorTiempo) {
      return 'nuevo';
    }

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

  static int _normalizar(int raw, int techo) {
    if (techo <= 0) return 0;
    final s = ((100.0 * raw) / techo).round();
    return s.clamp(0, 100);
  }

  static String nivelFromScore(int score) {
    if (score >= 75) return 'muy_alto';
    if (score >= 50) return 'alto';
    if (score >= 25) return 'medio';
    return 'bajo';
  }

  static String labelNivel(String? nivel) {
    switch (nivel) {
      case 'muy_alto':
        return 'Muy alta';
      case 'alto':
        return 'Alta';
      case 'medio':
        return 'Media';
      case 'bajo':
        return 'Baja';
      default:
        return 'Sin datos';
    }
  }

  /// Estrellas 1.0–5.0 a partir de score_servicio; null si no hay evals.
  static double? estrellasFromServicio(int scoreServicio, int nEval) {
    if (nEval <= 0) return null;
    return (1.0 + 4.0 * (scoreServicio / 100.0)).clamp(1.0, 5.0);
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

  /// Texto al toque (sin mencionar crédito).
  static String explicacionBadge(String? badge) {
    switch (badge) {
      case 'nuevo':
        return 'Recién llega a Puelo. Todavía está armando su perfil.';
      case 'registrado':
        return 'Completó nombre, contacto, documento y domicilio. Ya es contactable con datos básicos.';
      case 'bronce':
        return 'Perfil completo y muestra trabajos o trayectoria inicial. Más fácil confiar en lo que hace.';
      case 'bronce_plus':
        return 'Como Bronce, y además validó su documento (OCR). Identidad más sólida.';
      case 'plata':
        return 'Trayectoria sólida: datos, fotos, documento validado y varios clientes que lo respaldan.';
      case 'oro':
        return 'Nivel alto de confianza. Se definirá con más detalle más adelante.';
      case 'diamante':
        return 'Máximo nivel de confianza. Se definirá con más detalle más adelante.';
      default:
        return 'Todavía no tiene un identificador de confianza. Completar el perfil ayuda a generar confianza.';
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

  /// Recorre usuarios, calcula capas A/B/C + badge y escribe en Firestore.
  /// Llamar 1× día (Cloud Function o disparo manual admin/dev).
  static Future<BatchScoringResult> ejecutarBatchDiario({
    void Function(int hechos, int total)? onProgress,
    int pageSize = 200,
  }) async {
    // 1) Pre-agregar trabajos (fotos portfolio vs clientes)
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

    // 2) Indexar calificaciones por usuario evaluado
    final califPorUsuario = <String, List<Map<String, dynamic>>>{};
    final califComoCliente = <String, List<Map<String, dynamic>>>{};
    try {
      final califSnap = await _db.collection('calificaciones').get();
      for (final c in califSnap.docs) {
        final d = c.data();
        final map = Map<String, dynamic>.from(d);
        map['_id'] = c.id;

        // Prestador evaluado (cliente → prestador)
        final prestadorId = (d['prestador_id'] ??
                d['trabajador_id'] ??
                d['evaluado_id'] ??
                d['usuario_evaluado'] ??
                '')
            .toString();
        final rolEval = (d['rol_evaluado'] ?? d['tipo'] ?? '').toString();
        if (prestadorId.isNotEmpty &&
            !rolEval.toLowerCase().contains('cliente')) {
          califPorUsuario.putIfAbsent(prestadorId, () => []).add(map);
        }

        // Cliente evaluado (prestador → cliente)
        final clienteId = (d['cliente_id'] ?? d['usuario_cliente'] ?? '')
            .toString();
        if (clienteId.isNotEmpty) {
          califComoCliente.putIfAbsent(clienteId, () => []).add(map);
        } else if (rolEval.toLowerCase().contains('cliente') &&
            prestadorId.isNotEmpty) {
          califComoCliente.putIfAbsent(prestadorId, () => []).add(map);
        }
      }
    } catch (_) {
      // Colección vacía o sin permisos: score_servicio queda en 0
    }

    // 3) Primera pasada liviana: cache identidad + flags de evaluadores
    final scoreIdentidadCache = <String, int>{};
    final esNuevoCache = <String, bool>{};
    final tieneHistorialCache = <String, bool>{};

    // 4) Paginar usuarios
    Query<Map<String, dynamic>> query =
        _db.collection('usuarios').orderBy(FieldPath.documentId).limit(pageSize);

    int totalProcesados = 0;
    int escritos = 0;
    DocumentSnapshot? last;

    // Pre-cargar todos los docs de usuarios para multiplicadores (paginado)
    final allUserDocs = <String, Map<String, dynamic>>{};
    DocumentSnapshot? lastPre;
    while (true) {
      final snap = lastPre == null
          ? await query.get()
          : await query.startAfterDocument(lastPre).get();
      if (snap.docs.isEmpty) break;
      for (final doc in snap.docs) {
        allUserDocs[doc.id] = doc.data();
      }
      lastPre = snap.docs.last;
      if (snap.docs.length < pageSize) break;
    }

    for (final entry in allUserDocs.entries) {
      final uid = entry.key;
      final data = entry.value;
      final idLayer = calcularScoreIdentidad(
        data,
        fotosPortfolio: fotosPortfolio[uid] ?? 0,
      );
      scoreIdentidadCache[uid] = idLayer.score;
      final alta = _fechaAlta(data);
      esNuevoCache[uid] =
          alta != null && DateTime.now().difference(alta).inDays < 30;
      final nEval = (data['cantidadEvaluadores'] as num?)?.toInt() ?? 0;
      final nVal = (data['validaciones_recibidas'] as List?)?.length ?? 0;
      tieneHistorialCache[uid] = nEval > 0 || nVal > 0;
    }

    // 5) Segunda pasada: escribir scores
    last = null;
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

        final identidad = calcularScoreIdentidad(data, fotosPortfolio: fp);

        // Eventos de servicio: calificaciones + validaciones_recibidas
        final eventosServicio = <Map<String, dynamic>>[
          ...?califPorUsuario[uid],
        ];
        final vals = data['validaciones_recibidas'] as List<dynamic>? ?? [];
        for (final v in vals) {
          if (v is Map) {
            eventosServicio.add(Map<String, dynamic>.from(v));
          }
        }

        final servicio = calcularScoreServicio(
          eventos: eventosServicio,
          scoreIdentidadEvaluadores: scoreIdentidadCache,
          evaluadorTieneHistorial: tieneHistorialCache,
          evaluadorEsNuevo: esNuevoCache,
          scoreIdentidadReceptor: identidad.score,
        );

        final eventosCliente = <Map<String, dynamic>>[
          ...?califComoCliente[uid],
        ];
        final cliente = calcularScoreCliente(
          eventos: eventosCliente,
          scoreIdentidadEvaluadores: scoreIdentidadCache,
          evaluadorTieneHistorial: tieneHistorialCache,
          evaluadorEsNuevo: esNuevoCache,
          scoreIdentidadReceptor: identidad.score,
        );

        final esTrabajador =
            data['es_trabajador'] == true || data['rol'] == 'trabajador';
        final creditoPreview = calcularScoreCreditoPreview(
          scoreIdentidad: identidad.score,
          scoreServicio: servicio.score,
          scoreCliente: cliente.score,
          esTrabajador: esTrabajador,
        );

        // Validaciones 6m para badge (compat)
        final corte = DateTime.now().subtract(const Duration(days: 183));
        final idsVal = <String>{};
        for (final v in vals) {
          if (v is! Map) continue;
          DateTime? fecha;
          final f = v['fecha'] ?? v['created_at'] ?? v['fecha_validacion'];
          if (f is Timestamp) fecha = f.toDate();
          if (f is String) fecha = DateTime.tryParse(f);
          if (fecha != null && fecha.isBefore(corte)) continue;
          final vid = (v['validador_id'] ?? v['usuario_id'] ?? v['uid'] ?? '')
              .toString();
          if (vid.isNotEmpty) idsVal.add(vid);
        }
        // También contar evaluadores de calificaciones recientes
        for (final e in eventosServicio) {
          final f = e['fecha'] ?? e['created_at'] ?? e['fecha_calificacion'];
          DateTime? fecha;
          if (f is Timestamp) fecha = f.toDate();
          if (f is String) fecha = DateTime.tryParse(f);
          if (fecha != null && fecha.isBefore(corte)) continue;
          final vid =
              (e['evaluador_id'] ?? e['validador_id'] ?? e['usuario_id'] ?? '')
                  .toString();
          if (vid.isNotEmpty) idsVal.add(vid);
        }

        int validadoresConCalif = 0;
        for (final vid in idsVal) {
          if (tieneHistorialCache[vid] == true) validadoresConCalif++;
        }

        final badge = calcularBadgePrestador(
          data,
          fotosPortfolio: fp,
          fotosClientes: fc,
          validaciones6mDistintas: idsVal.length,
          validadoresConCalificacion: validadoresConCalif,
          nEvalTrabajo: servicio.nEventos,
        );

        final estrellas = estrellasFromServicio(
          servicio.score,
          servicio.nEventos,
        );

        // Compat: score_credito plano = raw identidad (como antes tendía a ser)
        final scoreCreditoCompat = calcularScoreCredito(
          data,
          fotosClientes: fc,
        );

        batch.set(
          doc.reference,
          {
            // --- compat campos planos ---
            'score_credito': scoreCreditoCompat.total,
            'score_credito_detalle': scoreCreditoCompat.detalle,
            'badge_prestador': badge,
            'score_actualizado_en': FieldValue.serverTimestamp(),
            'badge_actualizado_en': FieldValue.serverTimestamp(),
            // --- modelo v1 capas ---
            'scoring': {
              'model_version': modelVersion,
              'score_identidad': identidad.score,
              'score_identidad_raw': identidad.raw,
              'score_identidad_detalle': identidad.detalle,
              'score_servicio': servicio.score,
              'score_servicio_raw': servicio.raw,
              'score_servicio_detalle': {
                'n_eval': servicio.nEventos,
                'n_con_foto': servicio.nConFoto,
                'n_con_comentario': servicio.nConComentario,
              },
              'score_cliente': cliente.score,
              'score_cliente_raw': cliente.raw,
              'score_cliente_detalle': {
                'n_eval': cliente.nEventos,
              },
              'nivel_confianza': nivelFromScore(identidad.score),
              'nivel_cliente': nivelFromScore(cliente.score),
              'n_eval_trabajo': servicio.nEventos,
              'n_eval_cliente': cliente.nEventos,
              'rating_promedio': servicio.ratingPromedio ?? estrellas,
              'score_credito_preview': creditoPreview,
              'actualizado_en': FieldValue.serverTimestamp(),
            },
            'stats_scoring': {
              'fotos_portfolio': fp,
              'fotos_clientes': fc,
              'validaciones_6m': idsVal.length,
              'validadores_con_calificacion': validadoresConCalif,
              'model_version': modelVersion,
            },
          },
          SetOptions(merge: true),
        );

        enBatch++;
        escritos++;
        totalProcesados++;
        onProgress?.call(totalProcesados, allUserDocs.length);

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

    await _db.collection('stats').doc('scoring_job').set({
      'ultima_corrida': FieldValue.serverTimestamp(),
      'usuarios_procesados': totalProcesados,
      'fuente': 'app_batch',
      'model_version': modelVersion,
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

class LayerScoreResult {
  final int raw;
  final int score;
  final Map<String, int> detalle;
  final int nEventos;
  final int nConFoto;
  final int nConComentario;
  final double? ratingPromedio;

  const LayerScoreResult({
    required this.raw,
    required this.score,
    required this.detalle,
    this.nEventos = 0,
    this.nConFoto = 0,
    this.nConComentario = 0,
    this.ratingPromedio,
  });
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
