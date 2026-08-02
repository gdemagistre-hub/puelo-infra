import 'dart:async';

import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:url_launcher/url_launcher.dart';
import 'tarjetaDigital.dart';
import 'scoring_service.dart';
import 'theme/app_copy.dart';
import 'user_session.dart';
import 'catalogo_geo_cache.dart';

/// Buscador optimizado para pico laboral:
/// - get() + RefreshIndicator (no stream de 400)
/// - array-contains por oficio cuando el chip ≠ Todos
/// - páginas de 30 + "Ver más"
/// - debounce 350ms en texto
/// - catálogos geo vía CatalogoGeoCache
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
  final List<String> _rubros = const [
    'Todos',
    'Electricista',
    'Plomero',
    'Gasista',
    'Carpintero',
    'Pintor',
    'Construcción',
    'Jardinería',
    'Limpieza',
  ];

  static const Map<String, String> _rubroToProfesion = {
    'Electricista': 'electricidad',
    'Plomero': 'plomeria',
    'Gasista': 'gasista',
    'Carpintero': 'carpinteria',
    'Pintor': 'pintura',
    'Construcción': 'albanileria',
    'Jardinería': 'jardineria',
    'Limpieza': 'limpieza',
  };

  static const Map<String, String> _labelOficio = {
    'electricidad': 'Electricista',
    'plomeria': 'Plomería',
    'gasista': 'Gasista',
    'carpinteria': 'Carpintería',
    'pintura': 'Pintura',
    'albanileria': 'Construcción',
    'jardineria': 'Jardinería',
    'limpieza': 'Limpieza',
  };

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
    for (final e in _labelOficio.entries) {
      if (e.value.toLowerCase() == t || e.key == t) {
        for (final r in _rubros) {
          if (r.toLowerCase() == e.value.toLowerCase() ||
              (_rubroToProfesion[r] ?? '') == e.key) {
            return r;
          }
        }
      }
    }
    for (final e in _rubroToProfesion.entries) {
      if (e.value == t || e.key.toLowerCase() == t) return e.key;
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
    _prefProvinciaNombre =
        (geo['provincia_nombre'] ?? '').toString().trim().isEmpty
            ? null
            : geo['provincia_nombre'].toString().trim();
    _prefPartidoNombre =
        (geo['partido_nombre'] ?? '').toString().trim().isEmpty
            ? null
            : geo['partido_nombre'].toString().trim();
    _prefLocalidadNombre =
        (geo['localidad_nombre'] ?? '').toString().trim().isEmpty
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
    if (provId == null) return;
    final list = await CatalogoGeoCache.instance.partidosDeProvincia(provId);
    if (mounted) setState(() => partidos = list);
  }

  Future<void> _onPartidoSelected(String? partId) async {
    _localidadController.clear();
    setState(() {
      selectedPartidoId = partId;
      selectedLocalidadId = null;
      localidades = [];
    });
    if (partId == null) return;
    final list = await CatalogoGeoCache.instance.localidadesDePartido(partId);
    if (mounted) setState(() => localidades = list);
  }

  void _limpiarFiltrosZona() {
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
    _cargarPrestadores(reset: true);
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
      Query query = db
          .collection('usuarios')
          .where('es_trabajador', isEqualTo: true);

      if (_selectedRubro != 'Todos') {
        final clave = _rubroToProfesion[_selectedRubro] ??
            _selectedRubro.toLowerCase();
        query = query.where('profesiones', arrayContains: clave);
      }

      query = query.limit(_pageSize);
      if (!reset && _lastDoc != null) {
        query = query.startAfterDocument(_lastDoc!);
      }

      final snap = await query.get();
      if (!mounted) return;

      setState(() {
        if (reset) {
          _docs = snap.docs;
        } else {
          _docs = [..._docs, ...snap.docs];
        }
        _lastDoc = snap.docs.isNotEmpty ? snap.docs.last : _lastDoc;
        _hasMore = snap.docs.length >= _pageSize;
        _loading = false;
        _loadingMore = false;
        _error = null;
      });
    } catch (e) {
      debugPrint('Error buscador: $e');
      if (!mounted) return;
      setState(() {
        _loading = false;
        _loadingMore = false;
        _error = e.toString();
      });
    }
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

  String _initials(Map<String, dynamic> data) {
    final n = (data['nombre'] ?? '').toString().trim();
    final a = (data['apellido'] ?? '').toString().trim();
    if (n.isEmpty && a.isEmpty) return 'P';
    if (a.isEmpty) return n[0].toUpperCase();
    if (n.isEmpty) return a[0].toUpperCase();
    return '${n[0]}${a[0]}'.toUpperCase();
  }

  String _labelsOficios(List<dynamic> profesiones) {
    if (profesiones.isEmpty) return 'Prestador';
    return profesiones
        .map((e) => _labelOficio[e.toString().toLowerCase().trim()] ?? e.toString())
        .join(', ');
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

  Future<void> _abrirWhatsApp(Map<String, dynamic> data) async {
    final telRaw = _telefonoDe(data);
    if (telRaw.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Este prestador no cargó teléfono.')),
      );
      return;
    }
    final tel = telRaw.replaceAll(RegExp(r'[^\d+]'), '');
    final nombre = (data['nombre'] ?? '').toString().trim();
    final mensaje = Uri.encodeComponent(
      'Hola${nombre.isNotEmpty ? ' $nombre' : ''}, te escribo desde Puelo. '
      'Vi tu perfil y me gustaría consultar por un trabajo.',
    );
    final url = Uri.parse('https://wa.me/$tel?text=$mensaje');
    if (await canLaunchUrl(url)) {
      await launchUrl(url, mode: LaunchMode.externalApplication);
    }
  }

  bool _matchLoc(Map<String, dynamic>? c, String? id, String? nom) {
    if (c == null) return false;
    final locs = c['localidades'] as List<dynamic>? ?? [];
    return locs.any((l) {
      if (l is! Map) return false;
      final lid = (l['id'] ?? l['localidad_id'] ?? '').toString();
      final ln =
          (l['nombre'] ?? l['localidad_nombre'] ?? '').toString().toLowerCase();
      if (id != null && id.isNotEmpty && lid == id) return true;
      if (nom != null && nom.isNotEmpty && ln == nom.toLowerCase()) return true;
      return false;
    });
  }

  bool _matchPart(Map<String, dynamic>? c, String? id, String? nom) {
    if (c == null) return false;
    final partidos = c['partidos'] as List<dynamic>? ?? [];
    final locs = c['localidades'] as List<dynamic>? ?? [];
    if (partidos.any((p) {
      if (p is! Map) return false;
      final pid =
          (p['id'] ?? p['partido_id'] ?? p['departamento_id'] ?? '').toString();
      final pn = (p['nombre'] ??
              p['partido_nombre'] ??
              p['departamento_nombre'] ??
              '')
          .toString()
          .toLowerCase();
      if (id != null && id.isNotEmpty && pid == id) return true;
      if (nom != null && nom.isNotEmpty && pn == nom.toLowerCase()) return true;
      return false;
    })) {
      return true;
    }
    return locs.any((l) {
      if (l is! Map) return false;
      return id != null &&
          id.isNotEmpty &&
          (l['partido_id'] ?? '').toString() == id;
    });
  }

  bool _matchProv(Map<String, dynamic>? c, String? id, String? nom) {
    if (c == null) return false;
    final pid = (c['provincia_id'] ?? '').toString();
    final pn = (c['provincia_nombre'] ?? '').toString().toLowerCase();
    if (id != null && id.isNotEmpty && pid == id) return true;
    if (nom != null && nom.isNotEmpty && pn == nom.toLowerCase()) return true;
    return false;
  }

  int _scoreOrden(Map<String, dynamic> data) {
    int s = 0;
    final cobertura = data['zonas_cobertura'] as Map<String, dynamic>?;
    final useProv = selectedProvinciaId ?? _prefProvinciaId;
    final usePart = selectedPartidoId ?? _prefPartidoId;
    final useLoc = selectedLocalidadId ?? _prefLocalidadId;
    final useLocNom =
        selectedLocalidadId != null ? null : _prefLocalidadNombre;
    final usePartNom = selectedPartidoId != null ? null : _prefPartidoNombre;
    final useProvNom =
        selectedProvinciaId != null ? null : _prefProvinciaNombre;

    if (useLoc != null || (useLocNom != null && useLocNom.isNotEmpty)) {
      if (_matchLoc(cobertura, useLoc, useLocNom)) s += 300;
    }
    if (usePart != null || (usePartNom != null && usePartNom.isNotEmpty)) {
      if (_matchPart(cobertura, usePart, usePartNom)) s += 180;
    }
    if (useProv != null || (useProvNom != null && useProvNom.isNotEmpty)) {
      if (_matchProv(cobertura, useProv, useProvNom)) s += 80;
    }
    if (cobertura == null) s -= 20;
    if (_tieneWhatsApp(data) && _telefonoDe(data).isNotEmpty) s += 25;
    final evals = (data['cantidadEvaluadores'] as num?)?.toInt() ?? 0;
    final prom = (data['promedioEstrellas'] as num?)?.toDouble() ?? 0.0;
    s += (prom * 2).round();
    if (evals > 0) s += 5;
    final badge = (data['badge_prestador'] ?? '').toString();
    if (badge == 'plata') s += 15;
    if (badge == 'bronce_plus' || badge == 'bronce+') s += 10;
    if (badge == 'bronce') s += 6;
    if (badge == 'registrado') s += 3;
    // Scoring v1: calidad de servicio (0–100) aporta al orden, sin mostrar crédito
    final scoring = data['scoring'];
    if (scoring is Map) {
      final ss = (scoring['score_servicio'] as num?)?.toInt() ?? 0;
      s += (ss / 5).round(); // 0–20
      final conf = (scoring['nivel_confianza'] ?? '').toString();
      if (conf == 'muy_alto') s += 4;
      if (conf == 'alto') s += 2;
    }
    return s;
  }

  bool _pasaFiltrosZona(Map<String, dynamic> data) {
    final hay = selectedProvinciaId != null ||
        selectedPartidoId != null ||
        selectedLocalidadId != null;
    if (!hay) return true;
    final cobertura = data['zonas_cobertura'] as Map<String, dynamic>?;
    if (cobertura == null) return false;
    if (selectedLocalidadId != null) {
      return _matchLoc(cobertura, selectedLocalidadId, null);
    }
    if (selectedPartidoId != null) {
      return _matchPart(cobertura, selectedPartidoId, null);
    }
    if (selectedProvinciaId != null) {
      return _matchProv(cobertura, selectedProvinciaId, null);
    }
    return true;
  }

  List<QueryDocumentSnapshot> get _filtrados {
    var list = _docs.where((doc) {
      final data = doc.data() as Map<String, dynamic>;
      if (!_pasaFiltrosZona(data)) return false;
      if (_searchQuery.isEmpty) return true;
      final profesiones = (data['profesiones'] as List<dynamic>? ?? [])
          .map((e) => e.toString().toLowerCase())
          .toList();
      final nombre = (data['nombre'] ?? '').toString().toLowerCase();
      final apellido = (data['apellido'] ?? '').toString().toLowerCase();
      final comercial =
          (data['nombre_comercial'] ?? '').toString().toLowerCase();
      final labels = profesiones
          .map((k) => _labelOficio[k] ?? k)
          .join(' ')
          .toLowerCase();
      return nombre.contains(_searchQuery) ||
          apellido.contains(_searchQuery) ||
          comercial.contains(_searchQuery) ||
          profesiones.join(' ').contains(_searchQuery) ||
          labels.contains(_searchQuery);
    }).toList();

    list.sort((a, b) {
      final da = a.data() as Map<String, dynamic>;
      final db_ = b.data() as Map<String, dynamic>;
      return _scoreOrden(db_).compareTo(_scoreOrden(da));
    });
    return list;
  }

  InputDecorationTheme get _dropdownDecoration => InputDecorationTheme(
        filled: true,
        fillColor: Colors.white,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: Colors.grey.shade200),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: Colors.grey.shade200),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: _clientePrimary, width: 1.5),
        ),
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      );

  Widget _badgeChip(String? badge) {
    final label = ScoringService.labelBadge(badge);
    if (label.isEmpty) return const SizedBox.shrink();
    final c = ScoringService.coloresBadge(badge);
    return Container(
      margin: const EdgeInsets.only(top: 4),
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: Color(c.background),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: Color(c.foreground).withOpacity(0.35)),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w700,
          color: Color(c.foreground),
        ),
      ),
    );
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
          title: const Text(
            'Buscar prestadores',
            style: TextStyle(
              color: _textColor,
              fontWeight: FontWeight.bold,
              fontSize: 18,
            ),
          ),
          actions: [
            TextButton.icon(
              onPressed: () =>
                  setState(() => _filtrosAbiertos = !_filtrosAbiertos),
              icon: Icon(
                _filtrosAbiertos ? Icons.expand_less : Icons.tune_rounded,
                color: _clientePrimary,
                size: 20,
              ),
              label: Text(
                _filtrosAbiertos ? 'Ocultar' : 'Filtros',
                style: const TextStyle(
                  color: _clientePrimary,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
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
                    hintText: '¿Qué servicio buscas?',
                    prefixIcon:
                        Icon(Icons.search, color: Colors.grey.shade500),
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
              if (_tienePreferenciaZona)
                Container(
                  width: double.infinity,
                  color: _clientePrimary.withOpacity(0.08),
                  padding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  child: Row(
                    children: [
                      const Icon(Icons.place_outlined,
                          size: 18, color: _clientePrimary),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          _prefLocalidadNombre != null
                              ? 'Priorizando cerca de $_prefLocalidadNombre'
                              : 'Priorizando según tu domicilio',
                          style: const TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: _clientePrimary,
                          ),
                        ),
                      ),
                    ],
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
              AnimatedCrossFade(
                firstChild: const SizedBox(width: double.infinity),
                secondChild: Container(
                  width: double.infinity,
                  color: Colors.white,
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                  child: Column(
                    children: [
                      DropdownMenu<String>(
                        controller: _provinciaController,
                        expandedInsets: EdgeInsets.zero,
                        enableFilter: true,
                        requestFocusOnTap: true,
                        label: const Text('Provincia'),
                        inputDecorationTheme: _dropdownDecoration,
                        onSelected: _onProvinciaSelected,
                        dropdownMenuEntries: provincias
                            .map(
                              (p) => DropdownMenuEntry(
                                value: p['id'].toString(),
                                label: p['nombre'].toString(),
                              ),
                            )
                            .toList(),
                      ),
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          Expanded(
                            child: DropdownMenu<String>(
                              controller: _partidoController,
                              expandedInsets: EdgeInsets.zero,
                              enableFilter: true,
                              requestFocusOnTap: true,
                              label: const Text('Partido'),
                              inputDecorationTheme: _dropdownDecoration,
                              onSelected: _onPartidoSelected,
                              dropdownMenuEntries: partidos
                                  .map(
                                    (p) => DropdownMenuEntry(
                                      value: (p['departamento_id'] ?? p['id'])
                                          .toString(),
                                      label: (p['departamento_nombre'] ??
                                              p['nombre'])
                                          .toString(),
                                    ),
                                  )
                                  .toList(),
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: DropdownMenu<String>(
                              controller: _localidadController,
                              expandedInsets: EdgeInsets.zero,
                              enableFilter: true,
                              requestFocusOnTap: true,
                              label: const Text('Localidad'),
                              inputDecorationTheme: _dropdownDecoration,
                              onSelected: (val) =>
                                  setState(() => selectedLocalidadId = val),
                              dropdownMenuEntries: localidades
                                  .map(
                                    (l) => DropdownMenuEntry(
                                      value: (l['localidad_id'] ?? l['id'])
                                          .toString(),
                                      label: (l['localidad_nombre'] ??
                                              l['nombre'])
                                          .toString(),
                                    ),
                                  )
                                  .toList(),
                            ),
                          ),
                        ],
                      ),
                      if (selectedProvinciaId != null)
                        Align(
                          alignment: Alignment.centerRight,
                          child: TextButton(
                            onPressed: _limpiarFiltrosZona,
                            child: const Text('Limpiar zona'),
                          ),
                        ),
                    ],
                  ),
                ),
                crossFadeState: _filtrosAbiertos
                    ? CrossFadeState.showSecond
                    : CrossFadeState.showFirst,
                duration: const Duration(milliseconds: 200),
              ),
              const Divider(height: 1),
              Expanded(
                child: _loading
                    ? const Center(
                        child: CircularProgressIndicator(
                          color: _clientePrimary,
                        ),
                      )
                    : _error != null
                        ? Center(
                            child: Padding(
                              padding: const EdgeInsets.all(24),
                              child: Column(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Text(
                                    AppCopy.errorGenerico,
                                    textAlign: TextAlign.center,
                                  ),
                                  const SizedBox(height: 12),
                                  OutlinedButton(
                                    onPressed: () =>
                                        _cargarPrestadores(reset: true),
                                    child: const Text('Reintentar'),
                                  ),
                                ],
                              ),
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
                                      const SizedBox(height: 80),
                                      Icon(Icons.search_off_rounded,
                                          size: 48,
                                          color: Colors.grey.shade400),
                                      const SizedBox(height: 12),
                                      Padding(
                                        padding: const EdgeInsets.all(24),
                                        child: Text(
                                          AppCopy.sinPrestadoresZona,
                                          textAlign: TextAlign.center,
                                          style: TextStyle(
                                            color: Colors.grey.shade600,
                                          ),
                                        ),
                                      ),
                                      Center(
                                        child: OutlinedButton(
                                          onPressed: () {
                                            _limpiarFiltrosZona();
                                            _searchController.clear();
                                            setState(() {
                                              _selectedRubro = 'Todos';
                                              _searchQuery = '';
                                              _filtrosAbiertos = true;
                                            });
                                            _cargarPrestadores(reset: true);
                                          },
                                          child: const Text('Ampliar búsqueda'),
                                        ),
                                      ),
                                    ],
                                  )
                                : ListView.builder(
                                    padding: const EdgeInsets.fromLTRB(
                                        16, 12, 16, 24),
                                    itemCount: filtered.length +
                                        (_hasMore ? 1 : 0),
                                    itemBuilder: (context, index) {
                                      if (index >= filtered.length) {
                                        return Padding(
                                          padding: const EdgeInsets.symmetric(
                                              vertical: 16),
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
                                          (data['promedioEstrellas'] as num?)
                                                  ?.toDouble() ??
                                              0.0;
                                      final cantidadEvaluadores =
                                          (data['cantidadEvaluadores'] as num?)
                                                  ?.toInt() ??
                                              0;
                                      final profesiones =
                                          data['profesiones'] as List? ?? [];
                                      final badge =
                                          data['badge_prestador'] as String?;
                                      final comercial =
                                          (data['nombre_comercial'] ?? '')
                                              .toString()
                                              .trim();
                                      final nombreMostrar =
                                          comercial.isNotEmpty
                                              ? comercial
                                              : '${data['nombre'] ?? ''} ${data['apellido'] ?? ''}'
                                                  .trim();
                                      final tel = _telefonoDe(data);
                                      final puedeWa =
                                          tel.isNotEmpty && _tieneWhatsApp(data);
                                      final zona = _zonaResumen(data);
                                      final accents = [
                                        _clientePrimary,
                                        _accentCoral,
                                        _accentLightBlue,
                                        _dark,
                                      ];
                                      final accent =
                                          accents[index % accents.length];

                                      return Container(
                                        margin:
                                            const EdgeInsets.only(bottom: 12),
                                        decoration: BoxDecoration(
                                          color: Colors.white,
                                          borderRadius:
                                              BorderRadius.circular(16),
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
                                                  CircleAvatar(
                                                    radius: 26,
                                                    backgroundColor: accent
                                                        .withOpacity(0.14),
                                                    child: Text(
                                                      _initials(data),
                                                      style: TextStyle(
                                                        color: accent,
                                                        fontWeight:
                                                            FontWeight.bold,
                                                        fontSize: 15,
                                                      ),
                                                    ),
                                                  ),
                                                  const SizedBox(width: 12),
                                                  Expanded(
                                                    child: Column(
                                                      crossAxisAlignment:
                                                          CrossAxisAlignment
                                                              .start,
                                                      children: [
                                                        Text(
                                                          nombreMostrar
                                                                  .isEmpty
                                                              ? 'Prestador'
                                                              : nombreMostrar,
                                                          style:
                                                              const TextStyle(
                                                            fontWeight:
                                                                FontWeight
                                                                    .bold,
                                                            color: _textColor,
                                                            fontSize: 15,
                                                          ),
                                                          maxLines: 1,
                                                          overflow: TextOverflow
                                                              .ellipsis,
                                                        ),
                                                        Text(
                                                          _labelsOficios(
                                                              profesiones),
                                                          style: TextStyle(
                                                            color: Colors
                                                                .grey.shade600,
                                                            fontSize: 13,
                                                          ),
                                                          maxLines: 1,
                                                          overflow: TextOverflow
                                                              .ellipsis,
                                                        ),
                                                        if (zona.isNotEmpty)
                                                          Text(
                                                            zona,
                                                            style: TextStyle(
                                                              color: Colors
                                                                  .grey
                                                                  .shade500,
                                                              fontSize: 11,
                                                            ),
                                                            maxLines: 1,
                                                            overflow:
                                                                TextOverflow
                                                                    .ellipsis,
                                                          ),
                                                        _badgeChip(badge),
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
                                                                0xFFFFB000),
                                                            size: 18,
                                                          ),
                                                          Text(
                                                            cantidadEvaluadores >
                                                                    0
                                                                ? promedio
                                                                    .toStringAsFixed(
                                                                        1)
                                                                : '—',
                                                            style:
                                                                const TextStyle(
                                                              fontWeight:
                                                                  FontWeight
                                                                      .bold,
                                                              fontSize: 14,
                                                            ),
                                                          ),
                                                        ],
                                                      ),
                                                      const SizedBox(
                                                          height: 6),
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
                                                                      20),
                                                          onTap: puedeWa
                                                              ? () =>
                                                                  _abrirWhatsApp(
                                                                      data)
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
                                                                    width: 4),
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
}
