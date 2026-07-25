import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:url_launcher/url_launcher.dart';
import 'tarjetaDigital.dart';
import 'scoring_service.dart';
import 'theme/app_copy.dart';

class BuscadorPrestadoresWidget extends StatefulWidget {
  final String? initialQuery;

  const BuscadorPrestadoresWidget({
    super.key,
    this.initialQuery,
  });

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

  final scaffoldKey = GlobalKey<ScaffoldState>();
  final db = FirebaseFirestore.instance;

  late String _searchQuery;
  final TextEditingController _searchController = TextEditingController();

  bool _filtrosAbiertos = false;

  String _selectedRubro = 'Todos';
  final List<String> _rubros = [
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

  final TextEditingController _provinciaController = TextEditingController();
  final TextEditingController _partidoController = TextEditingController();
  final TextEditingController _localidadController = TextEditingController();

  String? selectedProvinciaId;
  String? selectedPartidoId;
  String? selectedLocalidadId;

  List<Map<String, dynamic>> provincias = [];
  List<Map<String, dynamic>> partidos = [];
  List<Map<String, dynamic>> localidades = [];

  @override
  void initState() {
    super.initState();
    final initial = widget.initialQuery?.trim() ?? '';
    _searchQuery = initial.toLowerCase();
    _searchController.text = initial;
    _filtrosAbiertos = initial.isEmpty;
    _loadProvincias();
  }

  @override
  void dispose() {
    _searchController.dispose();
    _provinciaController.dispose();
    _partidoController.dispose();
    _localidadController.dispose();
    super.dispose();
  }

  Future<void> _loadProvincias() async {
    final doc = await db.collection('cat_paises').doc('AR').get();
    if (doc.exists && doc.data()!.containsKey('provincias')) {
      setState(() {
        provincias =
            List<Map<String, dynamic>>.from(doc.data()!['provincias']);
      });
    }
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

    final query = await db
        .collection('cat_departamentos')
        .where('provincia_id', isEqualTo: provId)
        .get();

    setState(() {
      partidos = query.docs.map((d) => d.data()).toList();
    });
  }

  Future<void> _onPartidoSelected(String? partId) async {
    _localidadController.clear();

    setState(() {
      selectedPartidoId = partId;
      selectedLocalidadId = null;
      localidades = [];
    });

    if (partId == null) return;

    final query = await db
        .collection('cat_localidades')
        .where('partido_id', isEqualTo: partId)
        .get();

    setState(() {
      localidades = query.docs.map((d) => d.data()).toList();
    });
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

  String _initials(Map<String, dynamic> data) {
    final n = (data['nombre'] ?? '').toString().trim();
    final a = (data['apellido'] ?? '').toString().trim();
    if (n.isEmpty && a.isEmpty) return 'P';
    if (a.isEmpty) return n[0].toUpperCase();
    if (n.isEmpty) return a[0].toUpperCase();
    return '${n[0]}${a[0]}'.toUpperCase();
  }

  String _telefonoDe(Map<String, dynamic> data) {
    return (data['telefono'] ?? data['celular'] ?? '').toString().trim();
  }

  bool _tieneWhatsApp(Map<String, dynamic> data) {
    final tel = _telefonoDe(data);
    if (tel.isEmpty) return false;
    if (data.containsKey('tiene_whatsapp')) {
      return data['tiene_whatsapp'] == true;
    }
    return true;
  }

  String _labelsOficios(List<dynamic> profesiones) {
    if (profesiones.isEmpty) return 'Prestador';
    return profesiones.map((e) {
      final k = e.toString().toLowerCase().trim();
      return _labelOficio[k] ?? e.toString();
    }).join(', ');
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
    } else {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('No se pudo abrir WhatsApp')),
        );
      }
    }
  }

  int _scoreOrden(Map<String, dynamic> data) {
    int s = 0;
    final cobertura = data['zonas_cobertura'] as Map<String, dynamic>?;
    if (selectedLocalidadId != null && cobertura != null) {
      final locs = cobertura['localidades'] as List<dynamic>? ?? [];
      final match = locs.any((l) {
        if (l is! Map) return false;
        final id = (l['id'] ?? l['localidad_id'] ?? '').toString();
        return id == selectedLocalidadId;
      });
      if (match) s += 100;
    } else if (selectedProvinciaId != null && cobertura != null) {
      final pid = (cobertura['provincia_id'] ?? '').toString();
      if (pid == selectedProvinciaId) s += 40;
    }
    if (_tieneWhatsApp(data) && _telefonoDe(data).isNotEmpty) s += 30;

    final evals = (data['cantidadEvaluadores'] as num?)?.toInt() ?? 0;
    final prom = (data['promedioEstrellas'] as num?)?.toDouble() ?? 0.0;
    s += (prom * 2).round().toInt();
    if (evals > 0) s += 5;

    final badge = (data['badge_prestador'] ?? '').toString();
    if (badge == 'plata') s += 15;
    if (badge == 'bronce_plus' || badge == 'bronce+') s += 10;
    if (badge == 'bronce') s += 6;
    if (badge == 'registrado') s += 3;
    return s;
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
        labelStyle: TextStyle(color: Colors.grey.shade600, fontSize: 14),
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

  bool _pasaFiltrosZona(Map<String, dynamic> data) {
    final cobertura = data['zonas_cobertura'] as Map<String, dynamic>?;
    if (cobertura == null) {
      return selectedProvinciaId == null &&
          selectedPartidoId == null &&
          selectedLocalidadId == null;
    }

    final String providerProvinciaId =
        (cobertura['provincia_id'] ?? '').toString();
    final List<dynamic> provLocalidades =
        cobertura['localidades'] as List<dynamic>? ?? [];
    final List<dynamic> provPartidos =
        cobertura['partidos'] as List<dynamic>? ?? [];

    if (selectedProvinciaId != null &&
        providerProvinciaId != selectedProvinciaId.toString()) {
      final selectedNombre = provincias
          .where((p) => p['id'].toString() == selectedProvinciaId)
          .map((p) => p['nombre'].toString().toLowerCase())
          .cast<String>()
          .toList();
      final providerNombre =
          (cobertura['provincia_nombre'] ?? '').toString().toLowerCase();
      final matchByName =
          selectedNombre.isNotEmpty && selectedNombre.first == providerNombre;
      if (!matchByName) return false;
    }

    if (selectedLocalidadId != null) {
      final tieneLocalidad = provLocalidades.any((l) {
        if (l is! Map) return false;
        final id = (l['id'] ?? l['localidad_id'] ?? '').toString();
        final nombre = (l['nombre'] ?? l['localidad_nombre'] ?? '')
            .toString()
            .toLowerCase();
        final selectedLoc = localidades
            .where((x) =>
                (x['localidad_id'] ?? x['id']).toString() ==
                selectedLocalidadId)
            .toList();
        final selectedNombre = selectedLoc.isNotEmpty
            ? (selectedLoc.first['localidad_nombre'] ??
                    selectedLoc.first['nombre'] ??
                    '')
                .toString()
                .toLowerCase()
            : '';
        return id == selectedLocalidadId ||
            (selectedNombre.isNotEmpty && nombre == selectedNombre);
      });
      if (!tieneLocalidad) return false;
    } else if (selectedPartidoId != null) {
      final tienePartido = provPartidos.any((p) {
            if (p is! Map) return false;
            final id = (p['id'] ?? '').toString();
            final nombre = (p['nombre'] ?? '').toString().toLowerCase();
            final selectedPart = partidos
                .where((x) =>
                    (x['departamento_id'] ?? x['id']).toString() ==
                    selectedPartidoId)
                .toList();
            final selectedNombre = selectedPart.isNotEmpty
                ? (selectedPart.first['departamento_nombre'] ??
                        selectedPart.first['nombre'] ??
                        '')
                    .toString()
                    .toLowerCase()
                : '';
            return id == selectedPartidoId ||
                (selectedNombre.isNotEmpty && nombre == selectedNombre);
          }) ||
          provLocalidades.any((l) {
            if (l is! Map) return false;
            return (l['partido_id'] ?? '').toString() == selectedPartidoId;
          });
      if (!tienePartido) return false;
    }

    return true;
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => FocusScope.of(context).unfocus(),
      child: Scaffold(
        key: scaffoldKey,
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
          centerTitle: false,
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
                    hintStyle: TextStyle(color: Colors.grey.shade500),
                    prefixIcon: Icon(
                      Icons.search,
                      color: Colors.grey.shade500,
                    ),
                    filled: true,
                    fillColor: _bg,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(30),
                      borderSide: BorderSide.none,
                    ),
                    contentPadding: const EdgeInsets.symmetric(vertical: 14),
                  ),
                  onChanged: (value) =>
                      setState(() => _searchQuery = value.toLowerCase()),
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
                          side: BorderSide(
                            color: isSelected
                                ? _clientePrimary.withOpacity(0.4)
                                : Colors.grey.shade300,
                          ),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(20),
                          ),
                          onSelected: (_) =>
                              setState(() => _selectedRubro = rubro),
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
                    crossAxisAlignment: CrossAxisAlignment.stretch,
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
                              (p) => DropdownMenuEntry<String>(
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
                                    (p) => DropdownMenuEntry<String>(
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
                                    (l) => DropdownMenuEntry<String>(
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
                      if (selectedProvinciaId != null) ...[
                        const SizedBox(height: 8),
                        Align(
                          alignment: Alignment.centerRight,
                          child: TextButton(
                            onPressed: _limpiarFiltrosZona,
                            child: const Text('Limpiar zona'),
                          ),
                        ),
                      ],
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
                child: StreamBuilder<QuerySnapshot>(
                  stream: FirebaseFirestore.instance
                      .collection('usuarios')
                      .where('es_trabajador', isEqualTo: true)
                      .limit(120)
                      .snapshots(),
                  builder: (context, snapshot) {
                    if (snapshot.hasError) {
                      return Center(
                        child: Padding(
                          padding: const EdgeInsets.all(24),
                          child: Text(
                            AppCopy.errorGenerico,
                            textAlign: TextAlign.center,
                            style: TextStyle(color: Colors.grey.shade700),
                          ),
                        ),
                      );
                    }

                    if (!snapshot.hasData) {
                      return const Center(
                        child: CircularProgressIndicator(
                          color: _clientePrimary,
                        ),
                      );
                    }

                    final docs = snapshot.data!.docs;

                    var filtered = docs.where((doc) {
                      final data = doc.data() as Map<String, dynamic>;

                      if (!_pasaFiltrosZona(data)) return false;

                      final List<dynamic> profesiones =
                          data['profesiones'] ?? [];
                      final profesionesNorm = profesiones
                          .map((e) => e.toString().toLowerCase().trim())
                          .toList();

                      if (_selectedRubro != 'Todos') {
                        final clave = _rubroToProfesion[_selectedRubro] ??
                            _selectedRubro.toLowerCase();
                        if (!profesionesNorm.contains(clave)) return false;
                      }

                      final nombre =
                          (data['nombre'] ?? '').toString().toLowerCase();
                      final apellido =
                          (data['apellido'] ?? '').toString().toLowerCase();
                      final nombreComercial = (data['nombre_comercial'] ?? '')
                          .toString()
                          .toLowerCase();
                      final profesionesStr = profesionesNorm.join(' ');
                      final labels = profesionesNorm
                          .map((k) => _labelOficio[k] ?? k)
                          .join(' ')
                          .toLowerCase();

                      if (_searchQuery.isEmpty) return true;

                      return nombre.contains(_searchQuery) ||
                          apellido.contains(_searchQuery) ||
                          nombreComercial.contains(_searchQuery) ||
                          profesionesStr.contains(_searchQuery) ||
                          labels.contains(_searchQuery);
                    }).toList();

                    filtered.sort((a, b) {
                      final da = a.data() as Map<String, dynamic>;
                      final db_ = b.data() as Map<String, dynamic>;
                      return _scoreOrden(db_).compareTo(_scoreOrden(da));
                    });

                    if (filtered.isEmpty) {
                      return Center(
                        child: Padding(
                          padding: const EdgeInsets.all(32),
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(
                                Icons.search_off_rounded,
                                size: 48,
                                color: Colors.grey.shade400,
                              ),
                              const SizedBox(height: 12),
                              Text(
                                AppCopy.sinPrestadoresZona,
                                textAlign: TextAlign.center,
                                style: TextStyle(
                                  color: Colors.grey.shade600,
                                  fontSize: 15,
                                  height: 1.4,
                                ),
                              ),
                              const SizedBox(height: 16),
                              OutlinedButton(
                                onPressed: () {
                                  _limpiarFiltrosZona();
                                  setState(() {
                                    _selectedRubro = 'Todos';
                                    _searchQuery = '';
                                    _searchController.clear();
                                    _filtrosAbiertos = true;
                                  });
                                },
                                style: OutlinedButton.styleFrom(
                                  foregroundColor: _clientePrimary,
                                  side: const BorderSide(
                                    color: _clientePrimary,
                                  ),
                                ),
                                child: const Text('Ampliar búsqueda'),
                              ),
                            ],
                          ),
                        ),
                      );
                    }

                    return ListView.builder(
                      padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
                      itemCount: filtered.length,
                      itemBuilder: (context, index) {
                        final doc = filtered[index];
                        final data = doc.data() as Map<String, dynamic>;

                        final double promedio =
                            (data['promedioEstrellas'] as num?)?.toDouble() ??
                                0.0;
                        final int cantidadEvaluadores =
                            (data['cantidadEvaluadores'] as num?)?.toInt() ??
                                0;
                        final List<dynamic> profesiones =
                            data['profesiones'] ?? [];
                        final String? badge =
                            data['badge_prestador'] as String?;
                        final nombreComercial =
                            (data['nombre_comercial'] ?? '').toString().trim();
                        final nombreMostrar = nombreComercial.isNotEmpty
                            ? nombreComercial
                            : '${data['nombre'] ?? ''} ${data['apellido'] ?? ''}'
                                .trim();
                        final tel = _telefonoDe(data);
                        final puedeWa =
                            tel.isNotEmpty && _tieneWhatsApp(data);

                        final accentColors = [
                          _clientePrimary,
                          _accentCoral,
                          _accentLightBlue,
                          _dark,
                        ];
                        final accent =
                            accentColors[index % accentColors.length];

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
                                    builder: (context) => TarjetaDigitalWidget(
                                      usuarioRef: doc.reference,
                                    ),
                                  ),
                                );
                              },
                              child: Padding(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 14,
                                  vertical: 12,
                                ),
                                child: Row(
                                  children: [
                                    CircleAvatar(
                                      radius: 26,
                                      backgroundColor:
                                          accent.withOpacity(0.14),
                                      child: Text(
                                        _initials(data),
                                        style: TextStyle(
                                          color: accent,
                                          fontWeight: FontWeight.bold,
                                          fontSize: 15,
                                        ),
                                      ),
                                    ),
                                    const SizedBox(width: 12),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            nombreMostrar.isEmpty
                                                ? 'Prestador'
                                                : nombreMostrar,
                                            style: const TextStyle(
                                              fontWeight: FontWeight.bold,
                                              color: _textColor,
                                              fontSize: 15,
                                            ),
                                            maxLines: 1,
                                            overflow: TextOverflow.ellipsis,
                                          ),
                                          const SizedBox(height: 2),
                                          Text(
                                            _labelsOficios(profesiones),
                                            style: TextStyle(
                                              color: Colors.grey.shade600,
                                              fontSize: 13,
                                            ),
                                            maxLines: 1,
                                            overflow: TextOverflow.ellipsis,
                                          ),
                                          _badgeChip(badge),
                                        ],
                                      ),
                                    ),
                                    const SizedBox(width: 6),
                                    Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.end,
                                      children: [
                                        Row(
                                          mainAxisSize: MainAxisSize.min,
                                          children: [
                                            const Icon(
                                              Icons.star_rounded,
                                              color: Color(0xFFFFB000),
                                              size: 18,
                                            ),
                                            const SizedBox(width: 3),
                                            Text(
                                              cantidadEvaluadores > 0
                                                  ? promedio
                                                      .toStringAsFixed(1)
                                                  : '—',
                                              style: const TextStyle(
                                                fontWeight: FontWeight.bold,
                                                color: _textColor,
                                                fontSize: 14,
                                              ),
                                            ),
                                          ],
                                        ),
                                        if (cantidadEvaluadores > 0)
                                          Text(
                                            '$cantidadEvaluadores eval.',
                                            style: TextStyle(
                                              fontSize: 11,
                                              color: Colors.grey.shade500,
                                            ),
                                          ),
                                        const SizedBox(height: 6),
                                        Material(
                                          color: puedeWa
                                              ? _whatsapp
                                              : Colors.grey.shade300,
                                          borderRadius:
                                              BorderRadius.circular(20),
                                          child: InkWell(
                                            borderRadius:
                                                BorderRadius.circular(20),
                                            onTap: puedeWa
                                                ? () => _abrirWhatsApp(data)
                                                : null,
                                            child: const Padding(
                                              padding: EdgeInsets.symmetric(
                                                horizontal: 10,
                                                vertical: 6,
                                              ),
                                              child: Row(
                                                mainAxisSize:
                                                    MainAxisSize.min,
                                                children: [
                                                  Icon(
                                                    Icons.chat,
                                                    size: 14,
                                                    color: Colors.white,
                                                  ),
                                                  SizedBox(width: 4),
                                                  Text(
                                                    'WhatsApp',
                                                    style: TextStyle(
                                                      color: Colors.white,
                                                      fontSize: 11,
                                                      fontWeight:
                                                          FontWeight.w700,
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
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
