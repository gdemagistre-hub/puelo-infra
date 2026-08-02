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
    var normalizado = _normalizar(raw, techoIdentidad);

    // --- Anti-gaming: techo por antigüedad de cuenta ---
    final dias = _diasDesdeAlta(data);
    int techoEdad = 100;
    if (dias != null) {
      if (dias < 7) {
        techoEdad = 40;
      } else if (dias < 30) {
        techoEdad = 70;
      }
    } else {
      techoEdad = 50; // sin fecha de alta: no regalar "muy alto"
    }
    if (normalizado > techoEdad) {
      detalle['techo_antiguedad'] = techoEdad;
      normalizado = techoEdad;
    }

    // Fraude: techo duro
    final riesgo = (data['riesgo_fraude'] ?? '').toString();
    if (riesgo == 'alto' && normalizado > 25) {
      detalle['techo_fraude'] = 25;
      normalizado = 25;
    } else if (riesgo == 'medio' && normalizado > 50) {
      detalle['techo_fraude'] = 50;
      normalizado = 50;
    }

    // --- Maduración: señales fuertes al 50% si < 3 días ---
    if (dias != null && dias < 3) {
      final fuertes = (detalle['doc_ocr_validado'] ?? 0) +
          (detalle['foto_perfil'] ?? 0) +
          (detalle['foto_documento'] ?? 0);
      if (fuertes > 0) {
        final castigo = (fuertes * 0.5).round();
        // re-normalizar con raw reducido conceptualmente
        final rawMaduro = (raw - castigo).clamp(0, raw);
        normalizado = _normalizar(rawMaduro, techoIdentidad);
        if (normalizado > techoEdad) normalizado = techoEdad;
        detalle['maduracion_3d'] = 1;
      }
    }

    return LayerScoreResult(
      raw: raw,
      score: normalizado,
      detalle: detalle,
    );
  }

  static int? _diasDesdeAlta(Map<String, dynamic> data) {
    final alta = _fechaAlta(data);
    if (alta == null) return null;
    return DateTime.now().difference(alta).inDays;
  }

  // ---------------------------------------------------------------------------
  // CONSEJOS DE CONFIANZA (UI Home prestador)
  // ---------------------------------------------------------------------------

  /// Checklist accionable para subir confianza de perfil (sin mencionar crédito).
  static List<Map<String, String>> generarConsejosConfianza(
    Map<String, dynamic> data, {
    int fotosPortfolio = 0,
  }) {
    final out = <Map<String, String>>[];
    void tip(String id, String title, String body) {
      out.add({'id': id, 'title': title, 'body': body});
    }

    if (!_noVacio(data['url_foto_perfil'])) {
      tip(
        'foto_perfil',
        'Sumá una foto de perfil',
        'Selfie clara: los clientes quieren verte.',
      );
    }
    if (data['doc_validado'] != true) {
      tip(
        'ocr',
        'Validá tu documento con la cámara',
        'El scan del DNI es el mayor salto de confianza.',
      );
    } else if (!_noVacio(data['url_foto_documento'])) {
      tip(
        'foto_doc',
        'Adjuntá la foto de tu documento',
        'Refuerza que el documento es real.',
      );
    }
    if (_noVacio(data['doc_numero'] ?? data['numero_documento']) &&
        !_noVacio(data['genero_documento'] ?? data['sexo_documento'])) {
      tip(
        'genero',
        'Indicá cómo figura tu género en el documento',
        'Mujer, Hombre o No binario según el DNI.',
      );
    }
    if (!_noVacio(data['telefono'])) {
      tip(
        'tel',
        'Cargá tu celular',
        'Para WhatsApp o llamada.',
      );
    }
    final geo = data['direccion_geo'] as Map<String, dynamic>?;
    if (!_noVacio(geo?['localidad_id'] ?? geo?['localidad_nombre'])) {
      tip(
        'domicilio',
        'Completá tu domicilio',
        'Provincia, partido y localidad.',
      );
    }
    final profesiones = data['profesiones'] as List<dynamic>? ?? [];
    if (profesiones.isEmpty) {
      tip(
        'oficios',
        'Indicá los servicios que ofrecés',
        'Así aparecés cuando buscan tu rubro.',
      );
    }
    final zonas = data['zonas_cobertura'] as Map<String, dynamic>?;
    final locs = zonas?['localidades'] as List<dynamic>? ?? [];
    if (locs.isEmpty) {
      tip(
        'zona',
        'Definí tu zona de trabajo',
        'Para que te encuentren en tu barrio.',
      );
    }
    if (fotosPortfolio < 1) {
      tip(
        'fotos_trabajo',
        'Subí fotos de trabajos hechos',
        'Evidencia visual de lo que hacés.',
      );
    }

    final scoring = data['scoring'];
    final nEval = scoring is Map
        ? (scoring['n_eval_trabajo'] as num?)?.toInt() ?? 0
        : 0;
    final cant = (data['cantidadEvaluadores'] as num?)?.toInt() ?? 0;
    if (nEval == 0 && cant == 0) {
      tip(
        'evals',
        'Pedí tu primera evaluación de un cliente real',
        'Pedí a un cliente real que te califique.',
      );
    }

    // Tiempo: no prometer "muy alta" de un día para el otro
    final dias = _diasDesdeAlta(data);
    if (dias != null && dias < 7) {
      tip(
        'tiempo',
        'La confianza crece con el tiempo',
        'La primera semana hay techo de confianza: datos reales, sin atajos.',
      );
    }

    return out;
  }

  // ---------------------------------------------------------------------------
  // LÍMITES DE VALIDACIÓN (anti-granja)
  // ---------------------------------------------------------------------------

  /// ¿Puede este usuario emitir una validación de identidad/domicilio?
  /// Frágil: máx 1 total hasta que alguien lo valide; luego 1 cada 7 días.
  static ValidationGate canEmitirValidacion(Map<String, dynamic> validador) {
    final recibidas =
        (validador['validaciones_recibidas'] as List<dynamic>? ?? []).length;
    final emitidas = (validador['validaciones_emitidas_count'] as num?)?.toInt() ??
        (validador['validaciones_emitidas'] as List?)?.length ??
        0;
    final ultima = validador['ultima_validacion_emitida_en'];
    DateTime? ultimaDt;
    if (ultima is Timestamp) ultimaDt = ultima.toDate();
    if (ultima is String) ultimaDt = DateTime.tryParse(ultima);

    final fragil = recibidas == 0;
    if (fragil && emitidas >= 1) {
      return const ValidationGate(
        allowed: false,
        reason:
            'Para validar a otra persona, primero alguien tiene que validarte a vos. Así evitamos cuentas solo creadas para inflar confianza.',
      );
    }
    if (!fragil && emitidas >= 1 && ultimaDt != null) {
      final dias = DateTime.now().difference(ultimaDt).inDays;
      if (dias < 7) {
        return ValidationGate(
          allowed: false,
          reason:
              'Podés volver a validar a alguien en ${7 - dias} día(s). El ritmo lento protege a la comunidad del fraude.',
        );
      }
    }
    // Cuenta muy nueva: mismo freno aunque ya tenga 1 slot
    final diasAlta = _diasDesdeAlta(validador) ?? 0;
    if (diasAlta < 1 && emitidas >= 1) {
      return const ValidationGate(
        allowed: false,
        reason: 'Tu cuenta es muy nueva. Esperá un poco antes de validar a más personas.',
      );
    }
    return const ValidationGate(allowed: true, reason: '');
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

  // ---------------------------------------------------------------------------
  // BATCH DIARIO — pipeline F0…F5
  // ---------------------------------------------------------------------------

  static const Duration ventanaRespuestaPrestador = Duration(days: 7);
  static const Duration lockTtl = Duration(minutes: 15);

  static const List<String> _estadosPendientes = [
    'pendiente_respuesta_prestador',
    'borrador_par',
    'borrador_cliente',
    'pendiente',
  ];

  static const List<String> _estadosPublicados = [
    'publicada',
    'publicado',
    'published',
  ];

  /// Pipeline completo:
  /// F0 lock → F1 publicar vencidas → F2 indexar → F3 cache → F4 score → F5 stats.
  ///
  /// [trigger]: `manual_dev` | `manual_admin` | `scheduler` | `app_batch`
  static Future<BatchScoringResult> ejecutarBatchDiario({
    void Function(int hechos, int total)? onProgress,
    int pageSize = 200,
    String trigger = 'app_batch',
    bool force = false,
  }) async {
    final started = DateTime.now();
    final runId =
        '${started.toUtc().toIso8601String().replaceAll(':', '-')}_${trigger}';
    final errores = <String>[];
    int evalsPublicadasTimeout = 0;
    int evalsParCompleto = 0;
    int totalProcesados = 0;
    int escritos = 0;

    // ----- F0: lock + run metadata -----
    final jobRef = _db.collection('stats').doc('scoring_job');
    final runRef = _db.collection('stats').doc('scoring_job').collection('runs').doc(runId);

    try {
      final acquired = await _adquirirLock(
        jobRef: jobRef,
        runId: runId,
        trigger: trigger,
        force: force,
      );
      if (!acquired) {
        await runRef.set({
          'run_id': runId,
          'started_at': FieldValue.serverTimestamp(),
          'trigger': trigger,
          'model_version': modelVersion,
          'status': 'aborted_lock',
          'error_message': 'Otra corrida en curso (lock activo)',
          'finished_at': FieldValue.serverTimestamp(),
        });
        return BatchScoringResult(
          procesados: 0,
          actualizados: 0,
          runId: runId,
          status: 'aborted_lock',
          evalsPublicadasTimeout: 0,
          evalsParCompleto: 0,
          errores: const ['lock_activo'],
          duracionMs: DateTime.now().difference(started).inMilliseconds,
        );
      }

      await runRef.set({
        'run_id': runId,
        'started_at': FieldValue.serverTimestamp(),
        'trigger': trigger,
        'model_version': modelVersion,
        'status': 'running',
      });

      // ----- F1: publicar calificaciones vencidas (7 días) o aceptadas -----
      try {
        final pub = await _publicarCalificacionesVencidas();
        evalsPublicadasTimeout = pub.porTimeout;
        evalsParCompleto = pub.parCompleto;
        // Recalcular promedios públicos solo con evals publicadas
        await _recalcularPromediosDesdeCalificacionesPublicadas();
      } catch (e) {
        errores.add('F1_publicar: $e');
      }

      // ----- F1.5: detección de patrones de fraude (reglas + grafo) -----
      int flagsFraude = 0;
      try {
        flagsFraude = await _detectarPatronesFraude();
      } catch (e) {
        errores.add('F1_5_fraude: $e');
      }

      // ----- F2: indexar trabajos -----
      final fotosPortfolio = <String, int>{};
      final fotosClientes = <String, int>{};
      try {
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
      } catch (e) {
        errores.add('F2_trabajos: $e');
      }

      // ----- F2b: indexar calificaciones (solo publicadas / legacy) -----
      final califPorUsuario = <String, List<Map<String, dynamic>>>{};
      final califComoCliente = <String, List<Map<String, dynamic>>>{};
      try {
        final califSnap = await _db.collection('calificaciones').get();
        for (final c in califSnap.docs) {
          final d = c.data();
          if (!_esCalificacionPublicada(d)) continue;
          final map = Map<String, dynamic>.from(d);
          map['_id'] = c.id;

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

          final clienteId =
              (d['cliente_id'] ?? d['usuario_cliente'] ?? '').toString();
          if (clienteId.isNotEmpty) {
            califComoCliente.putIfAbsent(clienteId, () => []).add(map);
          } else if (rolEval.toLowerCase().contains('cliente') &&
              prestadorId.isNotEmpty) {
            califComoCliente.putIfAbsent(prestadorId, () => []).add(map);
          }
        }
      } catch (e) {
        errores.add('F2_calificaciones: $e');
      }

      // ----- F3: precargar usuarios + cache identidad -----
      final scoreIdentidadCache = <String, int>{};
      final esNuevoCache = <String, bool>{};
      final tieneHistorialCache = <String, bool>{};
      final allUserDocs = <String, Map<String, dynamic>>{};
      final allUserRefs = <String, DocumentReference<Map<String, dynamic>>>{};

      Query<Map<String, dynamic>> query = _db
          .collection('usuarios')
          .orderBy(FieldPath.documentId)
          .limit(pageSize);

      DocumentSnapshot? lastPre;
      try {
        while (true) {
          final snap = lastPre == null
              ? await query.get()
              : await query.startAfterDocument(lastPre).get();
          if (snap.docs.isEmpty) break;
          for (final doc in snap.docs) {
            allUserDocs[doc.id] = doc.data();
            allUserRefs[doc.id] = doc.reference;
          }
          lastPre = snap.docs.last;
          if (snap.docs.length < pageSize) break;
        }
      } catch (e) {
        errores.add('F3_usuarios: $e');
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

      // ----- F4: calcular y escribir -----
      WriteBatch batch = _db.batch();
      int enBatch = 0;
      final totalUsers = allUserDocs.length;

      for (final entry in allUserDocs.entries) {
        final uid = entry.key;
        final data = entry.value;
        final ref = allUserRefs[uid]!;

        try {
          final fp = fotosPortfolio[uid] ?? 0;
          final fc = fotosClientes[uid] ?? 0;

          final identidad = calcularScoreIdentidad(data, fotosPortfolio: fp);

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

          final corte = DateTime.now().subtract(const Duration(days: 183));
          final idsVal = <String>{};
          for (final v in vals) {
            if (v is! Map) continue;
            DateTime? fecha;
            final f = v['fecha'] ?? v['created_at'] ?? v['fecha_validacion'];
            if (f is Timestamp) fecha = f.toDate();
            if (f is String) fecha = DateTime.tryParse(f);
            if (fecha != null && fecha.isBefore(corte)) continue;
            final vid =
                (v['validador_id'] ?? v['usuario_id'] ?? v['uid'] ?? '')
                    .toString();
            if (vid.isNotEmpty) idsVal.add(vid);
          }
          for (final e in eventosServicio) {
            final f = e['fecha'] ?? e['created_at'] ?? e['fecha_calificacion'];
            DateTime? fecha;
            if (f is Timestamp) fecha = f.toDate();
            if (f is String) fecha = DateTime.tryParse(f);
            if (fecha != null && fecha.isBefore(corte)) continue;
            final vid = (e['evaluador_id'] ??
                    e['validador_id'] ??
                    e['usuario_id'] ??
                    '')
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

          final scoreCreditoCompat = calcularScoreCredito(
            data,
            fotosClientes: fc,
          );

          batch.set(
            ref,
            {
              'score_credito': scoreCreditoCompat.total,
              'score_credito_detalle': scoreCreditoCompat.detalle,
              'badge_prestador': badge,
              'score_actualizado_en': FieldValue.serverTimestamp(),
              'badge_actualizado_en': FieldValue.serverTimestamp(),
              'scoring_stale': false,
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
                'last_run_id': runId,
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
          onProgress?.call(totalProcesados, totalUsers);

          if (enBatch >= 400) {
            await batch.commit();
            batch = _db.batch();
            enBatch = 0;
          }
        } catch (e) {
          errores.add('F4_$uid: $e');
        }
      }

      if (enBatch > 0) await batch.commit();

      // ----- F5: stats + unlock -----
      final duracionMs = DateTime.now().difference(started).inMilliseconds;
      final status = errores.isEmpty ? 'ok' : 'ok_with_errors';

      await jobRef.set({
        'ultima_corrida': FieldValue.serverTimestamp(),
        'usuarios_procesados': totalProcesados,
        'usuarios_actualizados': escritos,
        'evals_publicadas_timeout': evalsPublicadasTimeout,
        'evals_par_completo': evalsParCompleto,
        'flags_fraude': flagsFraude,
        'fuente': trigger,
        'model_version': modelVersion,
        'last_run_id': runId,
        'status': status,
        'duracion_ms': duracionMs,
        'errores_count': errores.length,
        'lock': FieldValue.delete(),
      }, SetOptions(merge: true));

      await runRef.set({
        'status': status,
        'finished_at': FieldValue.serverTimestamp(),
        'duracion_ms': duracionMs,
        'metrics': {
          'usuarios_procesados': totalProcesados,
          'usuarios_actualizados': escritos,
          'evals_publicadas_timeout': evalsPublicadasTimeout,
          'evals_par_completo': evalsParCompleto,
          'flags_fraude': flagsFraude,
          'errores_count': errores.length,
        },
        'errores': errores.take(50).toList(),
        'model_version': modelVersion,
      }, SetOptions(merge: true));

      return BatchScoringResult(
        procesados: totalProcesados,
        actualizados: escritos,
        runId: runId,
        status: status,
        evalsPublicadasTimeout: evalsPublicadasTimeout,
        evalsParCompleto: evalsParCompleto,
        errores: errores,
        duracionMs: duracionMs,
      );
    } catch (e, st) {
      final duracionMs = DateTime.now().difference(started).inMilliseconds;
      errores.add('FATAL: $e');
      try {
        await jobRef.set({
          'status': 'error',
          'error_message': e.toString(),
          'ultima_corrida': FieldValue.serverTimestamp(),
          'last_run_id': runId,
          'lock': FieldValue.delete(),
        }, SetOptions(merge: true));
        await runRef.set({
          'status': 'error',
          'finished_at': FieldValue.serverTimestamp(),
          'error_message': e.toString(),
          'stack': st.toString().length > 1500
              ? st.toString().substring(0, 1500)
              : st.toString(),
          'duracion_ms': duracionMs,
          'errores': errores.take(50).toList(),
        }, SetOptions(merge: true));
      } catch (_) {}
      return BatchScoringResult(
        procesados: totalProcesados,
        actualizados: escritos,
        runId: runId,
        status: 'error',
        evalsPublicadasTimeout: evalsPublicadasTimeout,
        evalsParCompleto: evalsParCompleto,
        errores: errores,
        duracionMs: duracionMs,
      );
    }
  }

  // ---------- F0 helpers ----------

  static Future<bool> _adquirirLock({
    required DocumentReference<Map<String, dynamic>> jobRef,
    required String runId,
    required String trigger,
    required bool force,
  }) async {
    return _db.runTransaction<bool>((tx) async {
      final snap = await tx.get(jobRef);
      final data = snap.data();
      final lock = data?['lock'];
      if (!force && lock is Map) {
        final untilRaw = lock['until'];
        DateTime? until;
        if (untilRaw is Timestamp) until = untilRaw.toDate();
        if (untilRaw is String) until = DateTime.tryParse(untilRaw);
        if (until != null && until.isAfter(DateTime.now())) {
          return false;
        }
      }
      tx.set(
        jobRef,
        {
          'lock': {
            'holder': runId,
            'trigger': trigger,
            'acquired_at': FieldValue.serverTimestamp(),
            'until': Timestamp.fromDate(DateTime.now().add(lockTtl)),
          },
          'status': 'running',
        },
        SetOptions(merge: true),
      );
      return true;
    });
  }

  // ---------- F1 helpers ----------

  static Future<({int porTimeout, int parCompleto})>
      _publicarCalificacionesVencidas() async {
    int porTimeout = 0;
    int parCompleto = 0;
    final corte = DateTime.now().subtract(ventanaRespuestaPrestador);

    final snap = await _db.collection('calificaciones').get();
    WriteBatch batch = _db.batch();
    int enBatch = 0;

    for (final doc in snap.docs) {
      final d = doc.data();
      final estado = (d['estado'] ?? '').toString().toLowerCase();

      // Par ya listo para publicar
      final ambos =
          d['par_completo'] == true || d['tiene_respuesta_prestador'] == true;
      final aceptadoPrestador = d['aceptado_por_prestador'] == true;
      final pendientePar = estado == 'par_completo_pendiente_pub' ||
          (ambos && _estadosPendientes.contains(estado)) ||
          (aceptadoPrestador && _estadosPendientes.contains(estado));

      DateTime? fecha;
      final f = d['fecha'] ??
          d['created_at'] ??
          d['fecha_calificacion'] ??
          d['creado_en'];
      if (f is Timestamp) fecha = f.toDate();
      if (f is String) fecha = DateTime.tryParse(f);

      if (pendientePar) {
        batch.set(
          doc.reference,
          {
            'estado': 'publicada',
            'par_completo': true,
            'publicada_en': FieldValue.serverTimestamp(),
            'publica_por_timeout': false,
          },
          SetOptions(merge: true),
        );
        parCompleto++;
        enBatch++;
      } else if (_estadosPendientes.contains(estado) &&
          fecha != null &&
          fecha.isBefore(corte)) {
        batch.set(
          doc.reference,
          {
            'estado': 'publicada',
            'publicada_en': FieldValue.serverTimestamp(),
            'publica_por_timeout': true,
            'par_completo': false,
          },
          SetOptions(merge: true),
        );
        porTimeout++;
        enBatch++;
      }

      if (enBatch >= 400) {
        await batch.commit();
        batch = _db.batch();
        enBatch = 0;
      }
    }
    if (enBatch > 0) await batch.commit();
    return (porTimeout: porTimeout, parCompleto: parCompleto);
  }

  /// Legacy (sin estado) cuenta como publicada. Pendientes no suman al score.
  static bool _esCalificacionPublicada(Map<String, dynamic> d) {
    final estado = (d['estado'] ?? '').toString().toLowerCase().trim();
    if (estado.isEmpty) return true; // legacy
    if (_estadosPublicados.contains(estado)) return true;
    if (_estadosPendientes.contains(estado)) return false;
    if (estado == 'anulada' || estado == 'cancelada' || estado == 'borrador') {
      return false;
    }
    // desconocido → no sumar (seguro)
    return false;
  }


  /// Promedios públicos del prestador = solo calificaciones publicadas.
  static Future<void> _recalcularPromediosDesdeCalificacionesPublicadas() async {
    final snap = await _db.collection('calificaciones').get();
    final porPrestador = <String, List<int>>{};
    for (final doc in snap.docs) {
      final d = doc.data();
      if (!_esCalificacionPublicada(d)) continue;
      final pid = (d['prestador_id'] ??
              d['trabajador_id'] ??
              d['evaluado_id'] ??
              '')
          .toString();
      if (pid.isEmpty) continue;
      final est = d['estrellas'] ?? d['rating'] ?? d['puntaje'];
      if (est is! num) continue;
      porPrestador.putIfAbsent(pid, () => []).add(est.round());
    }
    WriteBatch batch = _db.batch();
    int n = 0;
    for (final e in porPrestador.entries) {
      final votos = e.value;
      final suma = votos.fold<int>(0, (a, b) => a + b);
      final prom = votos.isEmpty ? 0.0 : suma / votos.length;
      batch.set(
        _db.collection('usuarios').doc(e.key),
        {
          'sumaEstrellas': suma,
          'cantidadEvaluadores': votos.length,
          'promedioEstrellas': prom,
        },
        SetOptions(merge: true),
      );
      n++;
      if (n >= 400) {
        await batch.commit();
        batch = _db.batch();
        n = 0;
      }
    }
    if (n > 0) await batch.commit();
  }

  /// Patrones de fraude (sin ML externo): anillos, granjas, ráfagas, solo-validador.
  /// Escribe flags en usuarios y resumen en stats/fraud_flags.
  static Future<int> _detectarPatronesFraude() async {
    final users = await _db.collection('usuarios').get();
    final edges = <String, Set<String>>{}; // validador -> targets
    final recibidos = <String, Set<String>>{}; // target -> validadores
    final altaMs = <String, int>{};
    final now = DateTime.now();

    for (final doc in users.docs) {
      final d = doc.data();
      final uid = doc.id;
      final alta = _fechaAlta(d);
      if (alta != null) altaMs[uid] = alta.millisecondsSinceEpoch;
      final vals = d['validaciones_recibidas'] as List<dynamic>? ?? [];
      for (final v in vals) {
        if (v is! Map) continue;
        final vid = (v['validadorId'] ??
                v['validador_id'] ??
                v['usuario_id'] ??
                '')
            .toString();
        if (vid.isEmpty) continue;
        edges.putIfAbsent(vid, () => {}).add(uid);
        recibidos.putIfAbsent(uid, () => {}).add(vid);
      }
      final emitidas = d['validaciones_emitidas'] as List<dynamic>? ?? [];
      for (final v in emitidas) {
        if (v is! Map) continue;
        final tid = (v['target_id'] ?? v['targetUserId'] ?? '').toString();
        if (tid.isEmpty) continue;
        edges.putIfAbsent(uid, () => {}).add(tid);
        recibidos.putIfAbsent(tid, () => {}).add(uid);
      }
    }

    final flagsByUser = <String, List<String>>{};
    void flag(String uid, String code) {
      flagsByUser.putIfAbsent(uid, () => []);
      if (!flagsByUser[uid]!.contains(code)) flagsByUser[uid]!.add(code);
    }

    // Anillo A↔B
    for (final a in edges.keys) {
      for (final b in edges[a]!) {
        if (edges[b]?.contains(a) == true) {
          flag(a, 'anillo_mutual');
          flag(b, 'anillo_mutual');
        }
      }
    }

    // Ráfaga: >3 validaciones emitidas y cuenta < 48h
    for (final e in edges.entries) {
      final alta = altaMs[e.key];
      if (alta == null) continue;
      final ageH = (now.millisecondsSinceEpoch - alta) / 3600000;
      if (e.value.length >= 3 && ageH < 48) {
        flag(e.key, 'rafaga_cuenta_nueva');
      }
      if (e.value.length >= 5) {
        flag(e.key, 'volumen_alto_saliente');
      }
    }

    // Solo-validador: emite ≥2 y no recibió ninguna + perfil pobre
    for (final doc in users.docs) {
      final uid = doc.id;
      final d = doc.data();
      final sal = edges[uid]?.length ?? 0;
      final rec = recibidos[uid]?.length ?? 0;
      final scoreId = (d['scoring'] is Map)
          ? ((d['scoring'] as Map)['score_identidad'] as num?)?.toInt() ?? 0
          : 0;
      if (sal >= 2 && rec == 0 && scoreId < 30) {
        flag(uid, 'solo_validador');
      }
    }

    // Clúster mismo día: validador y validado creados el mismo día calendario
    for (final e in edges.entries) {
      final aAlta = altaMs[e.key];
      if (aAlta == null) continue;
      final aDay = DateTime.fromMillisecondsSinceEpoch(aAlta);
      for (final t in e.value) {
        final tAlta = altaMs[t];
        if (tAlta == null) continue;
        final tDay = DateTime.fromMillisecondsSinceEpoch(tAlta);
        if (aDay.year == tDay.year &&
            aDay.month == tDay.month &&
            aDay.day == tDay.day) {
          flag(e.key, 'mismo_dia_alta');
          flag(t, 'mismo_dia_alta');
        }
      }
    }

    WriteBatch batch = _db.batch();
    int n = 0;
    int totalFlags = 0;
    for (final e in flagsByUser.entries) {
      final codes = e.value;
      totalFlags += codes.length;
      final nivel = codes.length >= 3
          ? 'alto'
          : codes.length == 2
              ? 'medio'
              : 'bajo';
      // riesgo alto → techo de identidad en próximo cálculo vía campo
      batch.set(
        _db.collection('usuarios').doc(e.key),
        {
          'riesgo_fraude': nivel,
          'riesgo_fraude_flags': codes,
          'riesgo_fraude_en': FieldValue.serverTimestamp(),
          if (nivel == 'alto') 'scoring_stale': true,
        },
        SetOptions(merge: true),
      );
      n++;
      if (n >= 400) {
        await batch.commit();
        batch = _db.batch();
        n = 0;
      }
    }
    if (n > 0) await batch.commit();

    await _db.collection('stats').doc('fraud_flags').set({
      'ultima_corrida': FieldValue.serverTimestamp(),
      'usuarios_flaggeados': flagsByUser.length,
      'flags_totales': totalFlags,
      'model': 'heuristics_v1',
    }, SetOptions(merge: true));

    return flagsByUser.length;
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
  final String runId;
  final String status;
  final int evalsPublicadasTimeout;
  final int evalsParCompleto;
  final List<String> errores;
  final int duracionMs;

  const BatchScoringResult({
    required this.procesados,
    required this.actualizados,
    this.runId = '',
    this.status = 'ok',
    this.evalsPublicadasTimeout = 0,
    this.evalsParCompleto = 0,
    this.errores = const [],
    this.duracionMs = 0,
  });

  String get resumen =>
      '[$status] $actualizados/$procesados users · timeout=$evalsPublicadasTimeout · ${duracionMs}ms';
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
