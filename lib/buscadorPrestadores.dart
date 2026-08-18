import 'dart:async';

import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:url_launcher/url_launcher.dart';
import 'tarjetaDigital.dart';
import 'scoring_service.dart';
import 'theme/app_copy.dart';
import 'user_session.dart';
import 'catalogo_geo_cache.dart';
import 'catalogo_oficios.dart';
import 'contacto_service.dart';
import 'prestador_list_fields.dart';

/// Buscador optimizado para pico laboral.
class BuscadorPrestadoresWidget extends StatefulWidget {
  final String? initialQuery;

  const BuscadorPrestadoresWidget({super.key, this.initialQuery});

  static const String routeName = 'BuscadorPrestadores';
  static const String routePath = '/buscadorPrestadores';

  @override
  State<BuscadorPrestadoresWidget> createState() =>
      _BuscadorPrestadoresWidgetState();
}

class _BuscadorPrestadoresWidgetState extends State<BuscadorPrestadoresWidget> {
  static const Color _clientePrimary = Color(0xFF734BE4);
  static const Color _accentCoral = Color(0xFFF75A6D);
  static const Color _accentLightBlue = Color(0xFF7AAFFF);
  static const Color _dark = Color(0xFF3D4756);
  static const Color _bg = Color(0xFFF8FAFC);
  static const Color _textColor = Color(0xFF1E293B);
  static const Color _whatsapp = Color(0xFF25D366);
  static const int _pageSize = 30;

  final db = FirebaseFirestore.instance;
  final _searchController = TextEditingController();
  final _provinciaController = TextEditingController();
  final _partidoController = TextEditingController();
  final _localidadController = TextEditingController();

  Timer? _debounce;
  String _searchQuery = '';
  bool _filtrosAbiertos = false;

  String _selectedRubro = 'Todos';
  List<String> get _rubros => CatalogoOficios.chipsBuscador();

  String? selectedProvinciaId;
  String? selectedPartidoId;
  String? selectedLocalidadId;

  String? _prefProvinciaId;
  String? _prefPartidoId;
  String? _prefLocalidadId;
  String? _prefLocalidadNombre;
  String? _prefPartidoNombre;
  String? _prefProvinciaNombre;
  bool _tienePreferenciaZona = false;

  List<Map<String, dynamic>> provincias = [];
  List<Map<String, dynamic>> partidos = [];
  List<Map<String, dynamic>> localidades = [];

  List<QueryDocumentSnapshot> _docs = [];
  DocumentSnapshot? _lastDoc;
  bool _loading = true;
  bool _loadingMore = false;
  bool _hasMore = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    final initial = widget.initialQuery?.trim() ?? '';
    _searchQuery = initial.toLowerCase();
    _searchController.text = initial;
    _selectedRubro = _rubroDesdeQuery(initial);
    _filtrosAbiertos = initial.isEmpty;
    _cargarPreferenciaZonaCliente();
    _loadProvincias();
    _cargarPrestadores(reset: true);
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _searchController.dispose();
    _provinciaController.dispose();
    _partidoController.dispose();
    _localidadController.dispose();
    super.dispose();
  }

  String _rubroDesdeQuery(String q) {
    final t = q.trim().toLowerCase();
    if (t.isEmpty) return 'Todos';
    for (final r in _rubros) {
      if (r.toLowerCase() == t) return r;
    }
    for (final c in CatalogoOficios.categorias) {
      if (c.label.toLowerCase() == t || c.id == t) return c.label;
    }
    return 'Todos';
  }

  void _cargarPreferenciaZonaCliente() {
    final data = UserSession().datosCompletos;
    final geo = data?['direccion_geo'] as Map<String, dynamic>?;
    if (geo == null) return;
    final provId = (geo['provincia_id'] ?? '').toString().trim();
    final partId = (geo['partido_id'] ?? '').toString().trim();
    final locId = (geo['localidad_id'] ?? '').toString().trim();
    if (provId.isEmpty && partId.isEmpty && locId.isEmpty) return;
    _prefProvinciaId = provId.isEmpty ? null : provId;
    _prefPartidoId = partId.isEmpty ? null : partId;
    _prefLocalidadId = locId.isEmpty ? null : locId;
    _prefProvinciaNombre = (geo['provincia_nombre'] ?? '').toString().trim().isEmpty
        ? null
        : geo['provincia_nombre'].toString().trim();
    _prefPartidoNombre = (geo['partido_nombre'] ?? '').toString().trim().isEmpty
        ? null
        : geo['partido_nombre'].toString().trim();
    _prefLocalidadNombre = (geo['localidad_nombre'] ?? '').toString().trim().isEmpty
        ? null
        : geo['localidad_nombre'].toString().trim();
    _tienePreferenciaZona = true;
  }

  Future<void> _loadProvincias() async {
    final list = await CatalogoGeoCache.instance.provinciasAR();
    if (mounted) setState(() => provincias = list);
  }

  Future<void> _onProvinciaSelected(String? provId) async {
    _partidoController.clear();
    _localidadController.clear();
    setState(() {
      selectedProvinciaId = provId;
      selectedPartidoId = null;
      selectedLocalidadId = null;
      partidos = [];
      localidades = [];
    });
    if (provId != null) {
      final list = await CatalogoGeoCache.instance.partidosDeProvincia(provId);
      if (mounted) setState(() => partidos = list);
    }
    _cargarPrestadores(reset: true);
  }

  Future<void> _onPartidoSelected(String? partId) async {
    _localidadController.clear();
    setState(() {
      selectedPartidoId = partId;
      selectedLocalidadId = null;
      localidades = [];
    });
    if (partId != null) {
      final list = await CatalogoGeoCache.instance.localidadesDePartido(partId);
      if (mounted) setState(() => localidades = list);
    }
    _cargarPrestadores(reset: true);
  }

  void _onLocalidadSelected(String? locId) {
    setState(() => selectedLocalidadId = locId);
    _cargarPrestadores(reset: true);
  }

  void _limpiarFiltrosGeo() {
    _provinciaController.clear();
    _partidoController.clear();
    _localidadController.clear();
    setState(() {
      selectedProvinciaId = null;
      selectedPartidoId = null;
      selectedLocalidadId = null;
      partidos = [];
      localidades = [];
    });
    _cargarPrestadores(reset: true);
  }

  String? get _zonaServerFilter {
    return selectedLocalidadId ?? selectedPartidoId ?? selectedProvinciaId;
  }

  Future<void> _cargarPrestadores({required bool reset}) async {
    if (reset) {
      setState(() {
        _loading = true;
        _error = null;
        _docs = [];
        _lastDoc = null;
        _hasMore = true;
      });
    } else {
      if (!_hasMore || _loadingMore) return;
      setState(() => _loadingMore = true);
    }

    try {
      final snap = await _queryPrestadores(reset: reset);
      if (!mounted) return;
      final docs = List<QueryDocumentSnapshot>.from(snap.docs);
      if (reset) _ordenarPorPreferenciaZona(docs);
      setState(() {
        if (reset) {
          _docs = docs;
        } else {
          _docs = [..._docs, ...docs];
        }
        _lastDoc = snap.docs.isNotEmpty ? snap.docs.last : _lastDoc;
        _hasMore = snap.docs.length >= _pageSize;
        _loading = false;
        _loadingMore = false;
        _error = null;
      });
    } catch (e) {
      debugPrint('Error buscador: $e');
      try {
        Query fallback =
            db.collection('usuarios').where('es_trabajador', isEqualTo: true);
        fallback = fallback.limit(_pageSize);
        if (!reset && _lastDoc != null) {
          fallback = fallback.startAfterDocument(_lastDoc!);
        }
        final snap = await fallback.get();
        if (!mounted) return;
        final docs = List<QueryDocumentSnapshot>.from(snap.docs);
        if (reset) _ordenarPorPreferenciaZona(docs);
        setState(() {
          if (reset) {
            _docs = docs;
          } else {
            _docs = [..._docs, ...docs];
          }
          _lastDoc = snap.docs.isNotEmpty ? snap.docs.last : _lastDoc;
          _hasMore = snap.docs.length >= _pageSize;
          _loading = false;
          _loadingMore = false;
          _error = null;
        });
        return;
      } catch (e2) {
        debugPrint('Buscador fallback error: $e2');
      }
      if (!mounted) return;
      setState(() {
        _loading = false;
        _loadingMore = false;
        _error = e.toString();
      });
    }
  }

  Future<QuerySnapshot> _queryPrestadores({required bool reset}) async {
    final catId = CatalogoOficios.categoriaIdDesdeChip(_selectedRubro);
    final zonaId = _zonaServerFilter;

    Query query = db.collection('usuarios').where('es_trabajador', isEqualTo: true);

    if (zonaId != null) {
      query = query.where('zona_ids', arrayContains: zonaId);
    } else if (catId != null) {
      query = query.where('categorias_servicio', arrayContains: catId);
    } else {
      query = query.where('list_visible', isEqualTo: true);
    }

    query = query.limit(_pageSize);
    if (!reset && _lastDoc != null) {
      query = query.startAfterDocument(_lastDoc!);
    }
    return query.get();
  }

  void _ordenarPorPreferenciaZona(List<QueryDocumentSnapshot> docs) {
    docs.sort((a, b) {
      final da = a.data() as Map<String, dynamic>;
      final dbMap = b.data() as Map<String, dynamic>;
      final za = _scoreZonaPref(da);
      final zb = _scoreZonaPref(dbMap);
      if (za != zb) return zb.compareTo(za);
      final ca = _scoreConfianza(da);
      final cb = _scoreConfianza(dbMap);
      if (ca != cb) return cb.compareTo(ca);
      final pa = (da['list_promedio'] as num?) ?? (da['promedioEstrellas'] as num?) ?? 0;
      final pb = (dbMap['list_promedio'] as num?) ?? (dbMap['promedioEstrellas'] as num?) ?? 0;
      return pb.compareTo(pa);
    });
  }

  int _scoreZonaPref(Map<String, dynamic> data) {
    if (!_tienePreferenciaZona) return 0;
    final zonaIds = (data['zona_ids'] as List<dynamic>? ?? []).map((e) => e.toString()).toSet();
    if (zonaIds.isEmpty) {
      final cob = data['zonas_cobertura'] as Map<String, dynamic>?;
      if (cob != null) {
        for (final id in PrestadorListFields.zonaIdsFromCobertura(cob)) {
          zonaIds.add(id);
        }
      }
    }
    if (_prefLocalidadId != null && zonaIds.contains(_prefLocalidadId)) return 3;
    if (_prefPartidoId != null && zonaIds.contains(_prefPartidoId)) return 2;
    if (_prefProvinciaId != null && zonaIds.contains(_prefProvinciaId)) return 1;
    return 0;
  }

  /// Phase 0: identidad + badge + servicio + comportamiento + estrellas.
  /// Ranking sigue priorizando zona; esto solo ordena dentro de la misma zona.
  double _scoreConfianza(Map<String, dynamic> data) {
    num? scoreId = data['list_score_identidad'] as num?;
    num? scoreServ = data['list_score_servicio'] as num?;
    num? scoreComp = data['list_score_comportamiento'] as num?;
    if (scoreId == null || scoreServ == null || scoreComp == null) {
      final sc = data['scoring'];
      if (sc is Map) {
        scoreId ??= sc['score_identidad'] as num?;
        scoreServ ??= sc['score_servicio'] as num?;
        scoreComp ??= sc['score_comportamiento'] as num?;
      }
    }
    final identidad = (scoreId ?? 0).toDouble();
    final servicio = (scoreServ ?? 0).toDouble();
    final comportamiento = (scoreComp ?? 0).toDouble();
    final badge = (data['list_badge'] ?? data['badge_prestador'] ?? '')
        .toString()
        .toLowerCase()
        .trim();
    final badgeRank = switch (badge) {
      'diamante' => 6.0,
      'oro' => 5.0,
      'plata' => 4.0,
      'bronce_plus' => 3.0,
      'bronce' => 2.0,
      'registrado' => 1.0,
      'nuevo' => 0.5,
      _ => 0.0,
    };
    final estrellas = ((data['list_promedio'] as num?) ??
            (data['promedioEstrellas'] as num?) ??
            0)
        .toDouble();
    // Pesos relativos Phase 0: identidad dominante, luego badge, servicio, comp, estrellas
    return identidad * 10 +
        badgeRank * 20 +
        servicio * 3 +
        comportamiento * 2 +
        estrellas;
  }

  String _telefonoDe(Map<String, dynamic> data) =>
      (data['telefono'] ?? data['celular'] ?? '').toString().trim();

  String _nombreDe(Map<String, dynamic> data) {
    final n = (data['nombre'] ?? data['list_nombre'] ?? '').toString().trim();
    final a = (data['apellido'] ?? '').toString().trim();
    if (n.isEmpty && a.isEmpty) return 'Prestador';
    return ('$n $a').trim();
  }

  String _oficioDe(Map<String, dynamic> data) {
    final cats = data['categorias_servicio'] as List? ?? data['profesiones'] as List? ?? [];
    if (cats.isEmpty) return 'Servicio';
    return cats.take(2).map((e) => e.toString()).join(' · ');
  }

  Future<void> _abrirTarjeta(QueryDocumentSnapshot doc) async {
    if (!mounted) return;
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => TarjetaDigitalWidget(usuarioRef: doc.reference),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _bg,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        surfaceTintColor: Colors.transparent,
        title: Text(
          _selectedRubro == 'Todos' ? 'Prestadores' : _selectedRubro,
          style: const TextStyle(color: _clientePrimary, fontWeight: FontWeight.w800, fontSize: 18),
        ),
        actions: [
          if (_tienePreferenciaZona)
            Padding(
              padding: const EdgeInsets.only(right: 12),
              child: Center(
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                  decoration: BoxDecoration(
                    color: _clientePrimary.withOpacity(0.10),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    'Cerca tuyo',
                    style: TextStyle(color: _clientePrimary, fontWeight: FontWeight.w700, fontSize: 12),
                  ),
                ),
              ),
            ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? Center(child: Text('Error: $_error'))
              : _docs.isEmpty
                  ? const Center(child: Text('No hay prestadores para mostrar'))
                  : ListView.builder(
                      padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
                      itemCount: _docs.length + (_hasMore ? 1 : 0),
                      itemBuilder: (context, index) {
                        if (index >= _docs.length) {
                          return Padding(
                            padding: const EdgeInsets.all(16),
                            child: Center(
                              child: TextButton(
                                onPressed: _loadingMore ? null : () => _cargarPrestadores(reset: false),
                                child: Text(_loadingMore ? 'Cargando…' : 'Ver más'),
                              ),
                            ),
                          );
                        }
                        final doc = _docs[index];
                        final data = doc.data() as Map<String, dynamic>;
                        final nombre = _nombreDe(data);
                        final oficio = _oficioDe(data);
                        final zona = _scoreZonaPref(data);
                        final promedio = ((data['list_promedio'] as num?) ??
                                (data['promedioEstrellas'] as num?) ??
                                0)
                            .toDouble();
                        final nEval = ((data['list_n_eval'] as num?) ??
                                (data['cantidadEvaluadores'] as num?) ??
                                (data['scoring'] is Map
                                    ? (data['scoring']['n_eval_trabajo'] as num?)
                                    : null) ??
                                0)
                            .toInt();
                        final badgeRaw = (data['list_badge'] ?? data['badge_prestador'] ?? '')
                            .toString()
                            .trim();
                        final badgeLabel = ScoringService.labelBadge(
                          badgeRaw.isEmpty ? null : badgeRaw,
                        );
                        final badgeColors = ScoringService.coloresBadge(
                          badgeRaw.isEmpty ? null : badgeRaw,
                        );
                        return Card(
                          margin: const EdgeInsets.only(bottom: 10),
                          elevation: 1.5,
                          shadowColor: Colors.black.withOpacity(0.06),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16),
                          ),
                          child: InkWell(
                            borderRadius: BorderRadius.circular(16),
                            onTap: () => _abrirTarjeta(doc),
                            child: Padding(
                              padding: const EdgeInsets.fromLTRB(14, 12, 12, 12),
                              child: Row(
                                children: [
                                  CircleAvatar(
                                    radius: 24,
                                    backgroundColor: _clientePrimary.withOpacity(0.12),
                                    child: Text(
                                      nombre.isNotEmpty ? nombre[0].toUpperCase() : 'P',
                                      style: const TextStyle(
                                        color: _clientePrimary,
                                        fontWeight: FontWeight.w800,
                                        fontSize: 16,
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          nombre,
                                          style: const TextStyle(
                                            fontWeight: FontWeight.w800,
                                            fontSize: 15,
                                            color: Color(0xFF0F172A),
                                          ),
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                        const SizedBox(height: 3),
                                        Text(
                                          oficio + (zona > 0 ? ' · Cerca tuyo' : ''),
                                          style: const TextStyle(
                                            fontSize: 12,
                                            color: Color(0xFF64748B),
                                          ),
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                        const SizedBox(height: 6),
                                        Row(
                                          children: [
                                            Icon(
                                              Icons.star_rounded,
                                              size: 16,
                                              color: promedio > 0
                                                  ? const Color(0xFFF59E0B)
                                                  : const Color(0xFFCBD5E1),
                                            ),
                                            const SizedBox(width: 3),
                                            Text(
                                              promedio > 0
                                                  ? promedio.toStringAsFixed(1)
                                                  : '—',
                                              style: TextStyle(
                                                fontSize: 13,
                                                fontWeight: FontWeight.w800,
                                                color: promedio > 0
                                                    ? const Color(0xFF0F172A)
                                                    : const Color(0xFF94A3B8),
                                              ),
                                            ),
                                            Text(
                                              ' ($nEval)',
                                              style: const TextStyle(
                                                fontSize: 12,
                                                fontWeight: FontWeight.w600,
                                                color: Color(0xFF94A3B8),
                                              ),
                                            ),
                                            if (badgeLabel.isNotEmpty) ...[
                                              const SizedBox(width: 8),
                                              Container(
                                                padding: const EdgeInsets.symmetric(
                                                  horizontal: 8,
                                                  vertical: 2,
                                                ),
                                                decoration: BoxDecoration(
                                                  color: Color(badgeColors.background),
                                                  borderRadius: BorderRadius.circular(20),
                                                ),
                                                child: Text(
                                                  badgeLabel,
                                                  style: TextStyle(
                                                    fontSize: 11,
                                                    fontWeight: FontWeight.w800,
                                                    color: Color(badgeColors.foreground),
                                                  ),
                                                ),
                                              ),
                                            ],
                                          ],
                                        ),
                                      ],
                                    ),
                                  ),
                                  const Icon(
                                    Icons.chevron_right_rounded,
                                    color: Color(0xFFCBD5E1),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        );
                      },
                    ),
    );
  }
}
