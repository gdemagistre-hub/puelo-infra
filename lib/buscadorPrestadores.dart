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
import 'demanda/demanda_oficios_service.dart';
import 'contacto_service.dart';
import 'contacto/post_contacto_sheet.dart';
import 'prestador_list_fields.dart';

/// Buscador optimizado para pico laboral.
/// UX 5.2 + 5.7 + 5.8: post-WhatsApp explica comprobante.
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
  static const Color _bg = Color(0xFFF8FAFC);
  static const Color _textColor = Color(0xFF1E293B);
  static const Color _dark = Color(0xFF3D4756);
  static const Color _whatsapp = Color(0xFF25D366);
  static const int _pageSize = 30;

  final db = FirebaseFirestore.instance;
  final _searchController = TextEditingController();

  Timer? _debounce;
  String _searchQuery = '';

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
    _cargarPreferenciaZonaCliente();
    _cargarPrestadores(reset: true);
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _searchController.dispose();
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
    // Match especialidad → chip de su categoría
    for (final e in CatalogoOficios.especialidades) {
      if (e.id == t || e.label.toLowerCase() == t) {
        final cat = CatalogoOficios.categoria(e.categoriaId);
        if (cat != null) return cat.label;
      }
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

  void _onSearchChanged(String value) {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 350), () {
      if (!mounted) return;
      setState(() => _searchQuery = value.toLowerCase().trim());
    });
  }

  void _onRubroSelected(String rubro) {
    if (_selectedRubro == rubro) return;
    setState(() => _selectedRubro = rubro);
    DemandaOficiosService.registrar(rubro, fuente: 'buscador_chip');
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

    Query query =
        db.collection('usuarios').where('es_trabajador', isEqualTo: true);

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
      final pa = (da['list_promedio'] as num?) ??
          (da['promedioEstrellas'] as num?) ??
          0;
      final pb = (dbMap['list_promedio'] as num?) ??
          (dbMap['promedioEstrellas'] as num?) ??
          0;
      return pb.compareTo(pa);
    });
  }

  int _scoreZonaPref(Map<String, dynamic> data) {
    if (!_tienePreferenciaZona) return 0;
    final zonaIds = (data['zona_ids'] as List<dynamic>? ?? [])
        .map((e) => e.toString())
        .toSet();
    if (zonaIds.isEmpty) {
      final cob = data['zonas_cobertura'] as Map<String, dynamic>?;
      if (cob != null) {
        for (final id in PrestadorListFields.zonaIdsFromCobertura(cob)) {
          zonaIds.add(id);
        }
      }
    }
    if (_prefLocalidadId != null && zonaIds.contains(_prefLocalidadId)) {
      return 3;
    }
    if (_prefPartidoId != null && zonaIds.contains(_prefPartidoId)) return 2;
    if (_prefProvinciaId != null && zonaIds.contains(_prefProvinciaId)) {
      return 1;
    }
    return 0;
  }

  /// Phase 0: identidad + badge + servicio + comportamiento + estrellas.
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
    return identidad * 10 +
        badgeRank * 20 +
        servicio * 3 +
        comportamiento * 2 +
        estrellas;
  }

  String _telefonoDe(Map<String, dynamic> data) =>
      (data['telefono'] ?? data['celular'] ?? '').toString().trim();

  bool _tieneWhatsApp(Map<String, dynamic> data) {
    if (_telefonoDe(data).isEmpty) return false;
    if (data.containsKey('tiene_whatsapp')) {
      return data['tiene_whatsapp'] == true;
    }
    return true;
  }

  String? _fotoUrl(Map<String, dynamic> data) {
    final raw = (data['url_foto_perfil'] ?? data['foto_perfil'] ?? '')
        .toString()
        .trim();
    if (raw.isEmpty) return null;
    if (raw.startsWith('http://') || raw.startsWith('https://')) return raw;
    return null;
  }

  String _initials(Map<String, dynamic> data) {
    final n = (data['nombre'] ?? data['list_nombre'] ?? '').toString().trim();
    final a = (data['apellido'] ?? '').toString().trim();
    if (n.isEmpty && a.isEmpty) return 'P';
    if (a.isEmpty) return n[0].toUpperCase();
    if (n.isEmpty) return a[0].toUpperCase();
    return '${n[0]}${a[0]}'.toUpperCase();
  }

  String _labelsOficios(List<dynamic> profesiones) {
    if (profesiones.isEmpty) return 'Prestador';
    return profesiones
        .map((e) => CatalogoOficios.label(e.toString()))
        .take(2)
        .join(' · ');
  }

  String _zonaResumen(Map<String, dynamic> data) {
    final cobertura = data['zonas_cobertura'] as Map<String, dynamic>?;
    if (cobertura == null) return '';
    final locs = cobertura['localidades'] as List<dynamic>? ?? [];
    if (locs.isNotEmpty) {
      final nombres = locs
          .map((l) {
            if (l is! Map) return '';
            return (l['nombre'] ?? l['localidad_nombre'] ?? '').toString();
          })
          .where((s) => s.isNotEmpty)
          .take(2)
          .join(', ');
      if (nombres.isNotEmpty) return nombres;
    }
    return (cobertura['provincia_nombre'] ?? '').toString();
  }

  Future<void> _abrirWhatsApp(
    String prestadorUid,
    Map<String, dynamic> data,
  ) async {
    final telRaw = _telefonoDe(data);
    if (telRaw.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Este prestador no cargó teléfono.')),
      );
      return;
    }
    final tel = telRaw.replaceAll(RegExp(r'[^\d+]'), '');
    final nombre = (data['nombre'] ?? '').toString().trim();
    final apellido = (data['apellido'] ?? '').toString().trim();
    final comercial = (data['nombre_comercial'] ?? data['list_nombre'] ?? '')
        .toString()
        .trim();
    final nombreLog =
        comercial.isNotEmpty ? comercial : '$nombre $apellido'.trim();

    ContactoService.registrar(
      prestadorUid: prestadorUid,
      tipo: 'whatsapp',
      origen: 'buscador',
      prestadorNombre: nombreLog.isEmpty ? null : nombreLog,
    );

    final mensaje = Uri.encodeComponent(
      'Hola${nombre.isNotEmpty ? ' $nombre' : ''}, te escribo desde PROX. '
      'Vi tu perfil y me gustaría consultar por un trabajo.',
    );
    final url = Uri.parse('https://wa.me/$tel?text=$mensaje');
    if (await canLaunchUrl(url)) {
      await launchUrl(url, mode: LaunchMode.externalApplication);
    }
    if (!mounted) return;
    await PostContactoSheet.show(
      context,
      prestadorUid: prestadorUid,
      prestadorNombre: nombreLog.isEmpty ? null : nombreLog,
      desdeTarjeta: false,
      onPrimary: () {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => TarjetaDigitalWidget(
              usuarioRef: db.collection('usuarios').doc(prestadorUid),
            ),
          ),
        );
      },
    );
  }

  List<QueryDocumentSnapshot> get _filtrados {
    final catId = CatalogoOficios.categoriaIdDesdeChip(_selectedRubro);
    final zonaId = _zonaServerFilter;
    var list = _docs.where((doc) {
      final data = doc.data() as Map<String, dynamic>;
      if (data['list_visible'] == false) return false;

      final profesiones = (data['profesiones'] as List<dynamic>? ?? [])
          .map((e) => e.toString())
          .toList();
      final cats = (data['categorias_servicio'] as List<dynamic>? ?? [])
          .map((e) => e.toString())
          .toList();
      final allKeys = [...profesiones, ...cats];

      if (catId != null) {
        if (!CatalogoOficios.coincide(
          profesiones: allKeys,
          categoriaId: catId,
        )) {
          return false;
        }
      }

      if (zonaId != null) {
        final zonaIds = (data['zona_ids'] as List<dynamic>? ?? [])
            .map((e) => e.toString())
            .toSet();
        if (zonaIds.isNotEmpty && !zonaIds.contains(zonaId)) return false;
        if (zonaIds.isEmpty) {
          final cob = data['zonas_cobertura'] as Map<String, dynamic>?;
          final derived = PrestadorListFields.zonaIdsFromCobertura(cob);
          if (derived.isNotEmpty && !derived.contains(zonaId)) return false;
        }
      }

      if (_searchQuery.isEmpty) return true;
      final nombre = (data['nombre'] ?? '').toString().toLowerCase();
      final apellido = (data['apellido'] ?? '').toString().toLowerCase();
      final comercial =
          (data['nombre_comercial'] ?? data['list_nombre'] ?? '')
              .toString()
              .toLowerCase();
      if (nombre.contains(_searchQuery) ||
          apellido.contains(_searchQuery) ||
          comercial.contains(_searchQuery)) {
        return true;
      }
      return CatalogoOficios.coincide(
        profesiones: allKeys,
        texto: _searchQuery,
      );
    }).toList();

    if (_tienePreferenciaZona && zonaId == null) {
      _ordenarPorPreferenciaZona(list);
    }
    return list;
  }

  @override
  Widget build(BuildContext context) {
    final filtered = _filtrados;

    return GestureDetector(
      onTap: () => FocusScope.of(context).unfocus(),
      child: Scaffold(
        backgroundColor: _bg,
        appBar: AppBar(
          backgroundColor: Colors.white,
          elevation: 0,
          surfaceTintColor: Colors.transparent,
          leading: IconButton(
            icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 20),
            color: _textColor,
            onPressed: () => Navigator.pop(context),
          ),
          title: Text(
            _selectedRubro == 'Todos' ? 'Prestadores' : _selectedRubro,
            style: const TextStyle(
              color: _clientePrimary,
              fontWeight: FontWeight.w800,
              fontSize: 18,
            ),
          ),
        ),
        body: SafeArea(
          child: Column(
            children: [
              Container(
                width: double.infinity,
                color: Colors.white,
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
                child: TextField(
                  controller: _searchController,
                  textInputAction: TextInputAction.search,
                  decoration: InputDecoration(
                    hintText: '¿Qué servicio necesitás?',
                    prefixIcon: Icon(Icons.search, color: Colors.grey.shade500),
                    filled: true,
                    fillColor: _bg,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(30),
                      borderSide: BorderSide.none,
                    ),
                    contentPadding: const EdgeInsets.symmetric(vertical: 14),
                  ),
                  onChanged: _onSearchChanged,
                ),
              ),
              Container(
                color: Colors.white,
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 10),
                child: SizedBox(
                  height: 40,
                  child: ListView.builder(
                    scrollDirection: Axis.horizontal,
                    itemCount: _rubros.length,
                    itemBuilder: (context, index) {
                      final rubro = _rubros[index];
                      final isSelected = _selectedRubro == rubro;
                      return Padding(
                        padding: const EdgeInsets.only(right: 8),
                        child: FilterChip(
                          label: Text(
                            rubro,
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: isSelected
                                  ? FontWeight.w600
                                  : FontWeight.w500,
                              color: isSelected ? _clientePrimary : _dark,
                            ),
                          ),
                          selected: isSelected,
                          selectedColor: _clientePrimary.withOpacity(0.14),
                          backgroundColor: _bg,
                          checkmarkColor: _clientePrimary,
                          onSelected: (_) => _onRubroSelected(rubro),
                        ),
                      );
                    },
                  ),
                ),
              ),
              const Divider(height: 1),
              if (_tienePreferenciaZona)
                Container(
                  width: double.infinity,
                  color: _clientePrimary.withOpacity(0.06),
                  padding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  child: Row(
                    children: [
                      Icon(Icons.near_me_rounded,
                          size: 16, color: _clientePrimary),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'Priorizando cerca de '
                          '${_prefLocalidadNombre ?? _prefPartidoNombre ?? _prefProvinciaNombre ?? 'tu zona'}',
                          style: TextStyle(
                            fontSize: 12,
                            color: _clientePrimary,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              Expanded(
                child: _loading
                    ? const Center(
                        child: CircularProgressIndicator(color: _clientePrimary),
                      )
                    : _error != null
                        ? Center(
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Text(AppCopy.errorGenerico),
                                const SizedBox(height: 12),
                                OutlinedButton(
                                  onPressed: () =>
                                      _cargarPrestadores(reset: true),
                                  child: const Text('Reintentar'),
                                ),
                              ],
                            ),
                          )
                        : RefreshIndicator(
                            color: _clientePrimary,
                            onRefresh: () => _cargarPrestadores(reset: true),
                            child: filtered.isEmpty
                                ? ListView(
                                    physics:
                                        const AlwaysScrollableScrollPhysics(),
                                    children: [
                                      const SizedBox(height: 56),
                                      _emptyState(),
                                    ],
                                  )
                                : ListView.builder(
                                    padding: const EdgeInsets.fromLTRB(
                                      16,
                                      12,
                                      16,
                                      24,
                                    ),
                                    itemCount:
                                        filtered.length + (_hasMore ? 1 : 0),
                                    itemBuilder: (context, index) {
                                      if (index >= filtered.length) {
                                        return Padding(
                                          padding: const EdgeInsets.symmetric(
                                            vertical: 16,
                                          ),
                                          child: Center(
                                            child: _loadingMore
                                                ? const CircularProgressIndicator(
                                                    color: _clientePrimary,
                                                  )
                                                : TextButton(
                                                    onPressed: () =>
                                                        _cargarPrestadores(
                                                      reset: false,
                                                    ),
                                                    child: const Text(
                                                      'Ver más prestadores',
                                                    ),
                                                  ),
                                          ),
                                        );
                                      }

                                      final doc = filtered[index];
                                      final data =
                                          doc.data() as Map<String, dynamic>;
                                      final promedio =
                                          (data['list_promedio'] as num?)
                                                  ?.toDouble() ??
                                              (data['promedioEstrellas'] as num?)
                                                  ?.toDouble() ??
                                              0.0;
                                      final cantidadEvaluadores =
                                          (data['list_n_eval'] as num?)
                                                  ?.toInt() ??
                                              (data['cantidadEvaluadores']
                                                      as num?)
                                                  ?.toInt() ??
                                              0;
                                      final profesiones =
                                          data['profesiones'] as List? ?? [];
                                      final badgeRaw =
                                          (data['list_badge'] ??
                                                  data['badge_prestador'] ??
                                                  '')
                                              .toString()
                                              .trim();
                                      final badgeLabel =
                                          ScoringService.labelBadge(
                                        badgeRaw.isEmpty ? null : badgeRaw,
                                      );
                                      final badgeColors =
                                          ScoringService.coloresBadge(
                                        badgeRaw.isEmpty ? null : badgeRaw,
                                      );
                                      final listNombre =
                                          (data['list_nombre'] ?? '')
                                              .toString()
                                              .trim();
                                      final comercial =
                                          (data['nombre_comercial'] ?? '')
                                              .toString()
                                              .trim();
                                      final nombreMostrar = listNombre.isNotEmpty
                                          ? listNombre
                                          : (comercial.isNotEmpty
                                              ? comercial
                                              : '${data['nombre'] ?? ''} ${data['apellido'] ?? ''}'
                                                  .trim());
                                      final tel = _telefonoDe(data);
                                      final puedeWa =
                                          tel.isNotEmpty && _tieneWhatsApp(data);
                                      final zona = _zonaResumen(data);
                                      final cerca = _scoreZonaPref(data) > 0;

                                      return Container(
                                        margin:
                                            const EdgeInsets.only(bottom: 12),
                                        decoration: BoxDecoration(
                                          color: Colors.white,
                                          borderRadius:
                                              BorderRadius.circular(16),
                                          border: cerca
                                              ? Border.all(
                                                  color: _clientePrimary
                                                      .withOpacity(0.25),
                                                )
                                              : null,
                                          boxShadow: [
                                            BoxShadow(
                                              color: Colors.black
                                                  .withOpacity(0.05),
                                              blurRadius: 10,
                                              offset: const Offset(0, 2),
                                            ),
                                          ],
                                        ),
                                        child: Material(
                                          color: Colors.transparent,
                                          borderRadius:
                                              BorderRadius.circular(16),
                                          child: InkWell(
                                            borderRadius:
                                                BorderRadius.circular(16),
                                            onTap: () {
                                              Navigator.push(
                                                context,
                                                MaterialPageRoute(
                                                  builder: (_) =>
                                                      TarjetaDigitalWidget(
                                                    usuarioRef: doc.reference,
                                                  ),
                                                ),
                                              );
                                            },
                                            child: Padding(
                                              padding:
                                                  const EdgeInsets.symmetric(
                                                horizontal: 14,
                                                vertical: 12,
                                              ),
                                              child: Row(
                                                children: [
                                                  _avatarFila(
                                                    foto: _fotoUrl(data),
                                                    initials: _initials(data),
                                                  ),
                                                  const SizedBox(width: 12),
                                                  Expanded(
                                                    child: Column(
                                                      crossAxisAlignment:
                                                          CrossAxisAlignment
                                                              .start,
                                                      children: [
                                                        Text(
                                                          nombreMostrar.isEmpty
                                                              ? 'Prestador'
                                                              : nombreMostrar,
                                                          style:
                                                              const TextStyle(
                                                            fontWeight:
                                                                FontWeight.bold,
                                                            color: _textColor,
                                                            fontSize: 15,
                                                          ),
                                                          maxLines: 1,
                                                          overflow: TextOverflow
                                                              .ellipsis,
                                                        ),
                                                        Text(
                                                          _labelsOficios(
                                                            profesiones,
                                                          ),
                                                          style: TextStyle(
                                                            color: Colors
                                                                .grey.shade600,
                                                            fontSize: 13,
                                                          ),
                                                          maxLines: 1,
                                                          overflow: TextOverflow
                                                              .ellipsis,
                                                        ),
                                                        if (zona.isNotEmpty ||
                                                            cerca)
                                                          Padding(
                                                            padding:
                                                                const EdgeInsets.only(
                                                              top: 2,
                                                            ),
                                                            child: Row(
                                                              children: [
                                                                if (cerca) ...[
                                                                  Container(
                                                                    padding:
                                                                        const EdgeInsets.symmetric(
                                                                      horizontal: 6,
                                                                      vertical: 1,
                                                                    ),
                                                                    decoration:
                                                                        BoxDecoration(
                                                                      color: _clientePrimary
                                                                          .withOpacity(0.10),
                                                                      borderRadius:
                                                                          BorderRadius.circular(8),
                                                                    ),
                                                                    child: const Text(
                                                                      'Cerca',
                                                                      style: TextStyle(
                                                                        fontSize: 10,
                                                                        fontWeight:
                                                                            FontWeight.w800,
                                                                        color: _clientePrimary,
                                                                      ),
                                                                    ),
                                                                  ),
                                                                  const SizedBox(width: 6),
                                                                ],
                                                                if (zona.isNotEmpty)
                                                                  Expanded(
                                                                    child: Text(
                                                                      zona,
                                                                      style: TextStyle(
                                                                        color: Colors
                                                                            .grey.shade500,
                                                                        fontSize: 11,
                                                                      ),
                                                                      maxLines: 1,
                                                                      overflow:
                                                                          TextOverflow.ellipsis,
                                                                    ),
                                                                  ),
                                                              ],
                                                            ),
                                                          ),
                                                      ],
                                                    ),
                                                  ),
                                                  Column(
                                                    crossAxisAlignment:
                                                        CrossAxisAlignment.end,
                                                    children: [
                                                      Row(
                                                        mainAxisSize:
                                                            MainAxisSize.min,
                                                        children: [
                                                          const Icon(
                                                            Icons.star_rounded,
                                                            color: Color(
                                                              0xFFFFB000,
                                                            ),
                                                            size: 18,
                                                          ),
                                                          Text(
                                                            cantidadEvaluadores >
                                                                    0
                                                                ? promedio
                                                                    .toStringAsFixed(
                                                                      1,
                                                                    )
                                                                : '—',
                                                            style:
                                                                const TextStyle(
                                                              fontWeight:
                                                                  FontWeight
                                                                      .bold,
                                                              fontSize: 14,
                                                            ),
                                                          ),
                                                          Text(
                                                            ' ($cantidadEvaluadores)',
                                                            style: TextStyle(
                                                              fontSize: 11,
                                                              color: Colors.grey
                                                                  .shade500,
                                                              fontWeight:
                                                                  FontWeight
                                                                      .w600,
                                                            ),
                                                          ),
                                                        ],
                                                      ),
                                                      if (badgeLabel
                                                          .isNotEmpty) ...[
                                                        const SizedBox(
                                                          height: 4,
                                                        ),
                                                        Container(
                                                          padding:
                                                              const EdgeInsets
                                                                  .symmetric(
                                                            horizontal: 8,
                                                            vertical: 2,
                                                          ),
                                                          decoration:
                                                              BoxDecoration(
                                                            color: Color(
                                                              badgeColors
                                                                  .background,
                                                            ),
                                                            borderRadius:
                                                                BorderRadius
                                                                    .circular(
                                                              20,
                                                            ),
                                                          ),
                                                          child: Text(
                                                            badgeLabel,
                                                            style: TextStyle(
                                                              fontSize: 10,
                                                              fontWeight:
                                                                  FontWeight
                                                                      .w800,
                                                              color: Color(
                                                                badgeColors
                                                                    .foreground,
                                                              ),
                                                            ),
                                                          ),
                                                        ),
                                                      ],
                                                      const SizedBox(
                                                        height: 6,
                                                      ),
                                                      Material(
                                                        color: puedeWa
                                                            ? _whatsapp
                                                            : Colors
                                                                .grey.shade300,
                                                        borderRadius:
                                                            BorderRadius
                                                                .circular(20),
                                                        child: InkWell(
                                                          borderRadius:
                                                              BorderRadius
                                                                  .circular(
                                                            20,
                                                          ),
                                                          onTap: puedeWa
                                                              ? () =>
                                                                  _abrirWhatsApp(
                                                                    doc.id,
                                                                    data,
                                                                  )
                                                              : null,
                                                          child: const Padding(
                                                            padding:
                                                                EdgeInsets
                                                                    .symmetric(
                                                              horizontal: 10,
                                                              vertical: 6,
                                                            ),
                                                            child: Row(
                                                              mainAxisSize:
                                                                  MainAxisSize
                                                                      .min,
                                                              children: [
                                                                Icon(
                                                                  Icons.chat,
                                                                  size: 14,
                                                                  color: Colors
                                                                      .white,
                                                                ),
                                                                SizedBox(
                                                                  width: 4,
                                                                ),
                                                                Text(
                                                                  'WhatsApp',
                                                                  style:
                                                                      TextStyle(
                                                                    color: Colors
                                                                        .white,
                                                                    fontSize:
                                                                        11,
                                                                    fontWeight:
                                                                        FontWeight
                                                                            .w700,
                                                                  ),
                                                                ),
                                                              ],
                                                            ),
                                                          ),
                                                        ),
                                                      ),
                                                    ],
                                                  ),
                                                ],
                                              ),
                                            ),
                                          ),
                                        ),
                                      );
                                    },
                                  ),
                          ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _limpiarFiltros() {
    _searchController.clear();
    setState(() {
      _searchQuery = '';
      _selectedRubro = 'Todos';
    });
    _cargarPrestadores(reset: true);
  }

  Widget _avatarFila({required String? foto, required String initials}) {
    final fallback = Text(
      initials,
      style: const TextStyle(
        color: _clientePrimary,
        fontWeight: FontWeight.bold,
        fontSize: 15,
      ),
    );
    return CircleAvatar(
      radius: 26,
      backgroundColor: _clientePrimary.withOpacity(0.14),
      child: foto == null
          ? fallback
          : ClipOval(
              child: Image.network(
                foto,
                width: 52,
                height: 52,
                fit: BoxFit.cover,
                errorBuilder: (_, __, ___) => Center(child: fallback),
              ),
            ),
    );
  }

  Widget _emptyState() {
    final hayFiltro = _selectedRubro != 'Todos' || _searchQuery.isNotEmpty;
    final titulo = hayFiltro
        ? 'Nadie con ese filtro ahora'
        : 'Todavía no hay prestadores acá';
    final sub = hayFiltro
        ? 'Probá otro oficio o sacá el filtro para ver a todos.'
        : AppCopy.sinPrestadoresZona;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 28),
      child: Column(
        children: [
          Container(
            width: 72,
            height: 72,
            decoration: BoxDecoration(
              color: _clientePrimary.withOpacity(0.08),
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.search_rounded,
              size: 34,
              color: _clientePrimary,
            ),
          ),
          const SizedBox(height: 16),
          Text(
            titulo,
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w800,
              color: _textColor,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            sub,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 14,
              height: 1.35,
              color: Colors.grey.shade600,
            ),
          ),
          const SizedBox(height: 20),
          if (hayFiltro)
            SizedBox(
              width: double.infinity,
              height: 46,
              child: ElevatedButton(
                onPressed: _limpiarFiltros,
                style: ElevatedButton.styleFrom(
                  backgroundColor: _clientePrimary,
                  foregroundColor: Colors.white,
                  elevation: 0,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: const Text(
                  'Ver todos',
                  style: TextStyle(fontWeight: FontWeight.w800),
                ),
              ),
            )
          else
            SizedBox(
              width: double.infinity,
              height: 46,
              child: OutlinedButton(
                onPressed: () => _cargarPrestadores(reset: true),
                style: OutlinedButton.styleFrom(
                  foregroundColor: _clientePrimary,
                  side: const BorderSide(color: _clientePrimary),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: const Text(
                  'Actualizar',
                  style: TextStyle(fontWeight: FontWeight.w800),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
