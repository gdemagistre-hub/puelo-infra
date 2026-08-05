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
      Query query = db.collection('usuarios').where('es_trabajador', isEqualTo: true);
      final catId = CatalogoOficios.categoriaIdDesdeChip(_selectedRubro);
      if (catId != null) {
        query = query.where('categorias_servicio', arrayContains: catId);
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
      try {
        Query fallback = db.collection('usuarios').where('es_trabajador', isEqualTo: true).limit(_pageSize);
        if (!reset && _lastDoc != null) {
          fallback = fallback.startAfterDocument(_lastDoc!);
        }
        final snap = await fallback.get();
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
    return profesiones.map((e) => CatalogoOficios.label(e.toString())).join(', ');
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

  Future<void> _abrirWhatsApp(String prestadorUid, Map<String, dynamic> data) async {
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
    final comercial = (data['nombre_comercial'] ?? '').toString().trim();
    final nombreLog = comercial.isNotEmpty ? comercial : '$nombre $apellido'.trim();

    // Registrar contacto (fire-and-forget)
    ContactoService.registrar(
      prestadorUid: prestadorUid,
      tipo: 'whatsapp',
      origen: 'buscador',
      prestadorNombre: nombreLog.isEmpty ? null : nombreLog,
    );

    final mensaje = Uri.encodeComponent(
      'Hola${nombre.isNotEmpty ? ' $nombre' : ''}, te escribo desde Puelo. '
      'Vi tu perfil y me gustaría consultar por un trabajo.',
    );
    final url = Uri.parse('https://wa.me/$tel?text=$mensaje');
    if (await canLaunchUrl(url)) {
      await launchUrl(url, mode: LaunchMode.externalApplication);
    }
  }

  List<QueryDocumentSnapshot> get _filtrados {
    final catId = CatalogoOficios.categoriaIdDesdeChip(_selectedRubro);
    var list = _docs.where((doc) {
      final data = doc.data() as Map<String, dynamic>;
      final profesiones = (data['profesiones'] as List<dynamic>? ?? [])
          .map((e) => e.toString())
          .toList();
      final cats = (data['categorias_servicio'] as List<dynamic>? ?? [])
          .map((e) => e.toString())
          .toList();
      final allKeys = [...profesiones, ...cats];

      if (catId != null) {
        if (!CatalogoOficios.coincide(profesiones: allKeys, categoriaId: catId)) {
          return false;
        }
      }

      if (_searchQuery.isEmpty) return true;
      final nombre = (data['nombre'] ?? '').toString().toLowerCase();
      final apellido = (data['apellido'] ?? '').toString().toLowerCase();
      final comercial = (data['nombre_comercial'] ?? '').toString().toLowerCase();
      if (nombre.contains(_searchQuery) ||
          apellido.contains(_searchQuery) ||
          comercial.contains(_searchQuery)) {
        return true;
      }
      return CatalogoOficios.coincide(profesiones: allKeys, texto: _searchQuery);
    }).toList();
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
          title: const Text(
            'Buscar prestadores',
            style: TextStyle(color: _textColor, fontWeight: FontWeight.bold, fontSize: 18),
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
                    hintText: '¿Qué servicio buscas?',
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
                              fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
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
              Expanded(
                child: _loading
                    ? const Center(child: CircularProgressIndicator(color: _clientePrimary))
                    : _error != null
                        ? Center(
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Text(AppCopy.errorGenerico),
                                const SizedBox(height: 12),
                                OutlinedButton(
                                  onPressed: () => _cargarPrestadores(reset: true),
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
                                    physics: const AlwaysScrollableScrollPhysics(),
                                    children: [
                                      const SizedBox(height: 80),
                                      Icon(Icons.search_off_rounded, size: 48, color: Colors.grey.shade400),
                                      const SizedBox(height: 12),
                                      Padding(
                                        padding: const EdgeInsets.all(24),
                                        child: Text(
                                          AppCopy.sinPrestadoresZona,
                                          textAlign: TextAlign.center,
                                          style: TextStyle(color: Colors.grey.shade600),
                                        ),
                                      ),
                                    ],
                                  )
                                : ListView.builder(
                                    padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
                                    itemCount: filtered.length + (_hasMore ? 1 : 0),
                                    itemBuilder: (context, index) {
                                      if (index >= filtered.length) {
                                        return Padding(
                                          padding: const EdgeInsets.symmetric(vertical: 16),
                                          child: Center(
                                            child: _loadingMore
                                                ? const CircularProgressIndicator(color: _clientePrimary)
                                                : TextButton(
                                                    onPressed: () => _cargarPrestadores(reset: false),
                                                    child: const Text('Ver más prestadores'),
                                                  ),
                                          ),
                                        );
                                      }

                                      final doc = filtered[index];
                                      final data = doc.data() as Map<String, dynamic>;
                                      final promedio = (data['promedioEstrellas'] as num?)?.toDouble() ?? 0.0;
                                      final cantidadEvaluadores = (data['cantidadEvaluadores'] as num?)?.toInt() ?? 0;
                                      final profesiones = data['profesiones'] as List? ?? [];
                                      final badge = data['badge_prestador'] as String?;
                                      final comercial = (data['nombre_comercial'] ?? '').toString().trim();
                                      final nombreMostrar = comercial.isNotEmpty
                                          ? comercial
                                          : '${data['nombre'] ?? ''} ${data['apellido'] ?? ''}'.trim();
                                      final tel = _telefonoDe(data);
                                      final puedeWa = tel.isNotEmpty && _tieneWhatsApp(data);
                                      final zona = _zonaResumen(data);

                                      return Container(
                                        margin: const EdgeInsets.only(bottom: 12),
                                        decoration: BoxDecoration(
                                          color: Colors.white,
                                          borderRadius: BorderRadius.circular(16),
                                          boxShadow: [
                                            BoxShadow(
                                              color: Colors.black.withOpacity(0.05),
                                              blurRadius: 10,
                                              offset: const Offset(0, 2),
                                            ),
                                          ],
                                        ),
                                        child: Material(
                                          color: Colors.transparent,
                                          borderRadius: BorderRadius.circular(16),
                                          child: InkWell(
                                            borderRadius: BorderRadius.circular(16),
                                            onTap: () {
                                              Navigator.push(
                                                context,
                                                MaterialPageRoute(
                                                  builder: (_) => TarjetaDigitalWidget(usuarioRef: doc.reference),
                                                ),
                                              );
                                            },
                                            child: Padding(
                                              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                                              child: Row(
                                                children: [
                                                  CircleAvatar(
                                                    radius: 26,
                                                    backgroundColor: _clientePrimary.withOpacity(0.14),
                                                    child: Text(
                                                      _initials(data),
                                                      style: const TextStyle(
                                                        color: _clientePrimary,
                                                        fontWeight: FontWeight.bold,
                                                        fontSize: 15,
                                                      ),
                                                    ),
                                                  ),
                                                  const SizedBox(width: 12),
                                                  Expanded(
                                                    child: Column(
                                                      crossAxisAlignment: CrossAxisAlignment.start,
                                                      children: [
                                                        Text(
                                                          nombreMostrar.isEmpty ? 'Prestador' : nombreMostrar,
                                                          style: const TextStyle(
                                                            fontWeight: FontWeight.bold,
                                                            color: _textColor,
                                                            fontSize: 15,
                                                          ),
                                                          maxLines: 1,
                                                          overflow: TextOverflow.ellipsis,
                                                        ),
                                                        Text(
                                                          _labelsOficios(profesiones),
                                                          style: TextStyle(color: Colors.grey.shade600, fontSize: 13),
                                                          maxLines: 1,
                                                          overflow: TextOverflow.ellipsis,
                                                        ),
                                                        if (zona.isNotEmpty)
                                                          Text(
                                                            zona,
                                                            style: TextStyle(color: Colors.grey.shade500, fontSize: 11),
                                                            maxLines: 1,
                                                            overflow: TextOverflow.ellipsis,
                                                          ),
                                                      ],
                                                    ),
                                                  ),
                                                  Column(
                                                    crossAxisAlignment: CrossAxisAlignment.end,
                                                    children: [
                                                      Row(
                                                        mainAxisSize: MainAxisSize.min,
                                                        children: [
                                                          const Icon(Icons.star_rounded, color: Color(0xFFFFB000), size: 18),
                                                          Text(
                                                            cantidadEvaluadores > 0 ? promedio.toStringAsFixed(1) : '—',
                                                            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                                                          ),
                                                        ],
                                                      ),
                                                      const SizedBox(height: 6),
                                                      Material(
                                                        color: puedeWa ? _whatsapp : Colors.grey.shade300,
                                                        borderRadius: BorderRadius.circular(20),
                                                        child: InkWell(
                                                          borderRadius: BorderRadius.circular(20),
                                                          onTap: puedeWa
                                                              ? () => _abrirWhatsApp(doc.id, data)
                                                              : null,
                                                          child: const Padding(
                                                            padding: EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                                                            child: Row(
                                                              mainAxisSize: MainAxisSize.min,
                                                              children: [
                                                                Icon(Icons.chat, size: 14, color: Colors.white),
                                                                SizedBox(width: 4),
                                                                Text(
                                                                  'WhatsApp',
                                                                  style: TextStyle(
                                                                    color: Colors.white,
                                                                    fontSize: 11,
                                                                    fontWeight: FontWeight.w700,
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
