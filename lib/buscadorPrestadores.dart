import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'tarjetaDigital.dart';

class BuscadorPrestadoresWidget extends StatefulWidget {
  final String? initialQuery;

  const BuscadorPrestadoresWidget({
    super.key,
    this.initialQuery,
  });

  static const String routeName = 'BuscadorPrestadores';
  static const String routePath = '/buscadorPrestadores';

  @override
  State<BuscadorPrestadoresWidget> createState() => _BuscadorPrestadoresWidgetState();
}

class _BuscadorPrestadoresWidgetState extends State<BuscadorPrestadoresWidget> {
  final scaffoldKey = GlobalKey<ScaffoldState>();
  final db = FirebaseFirestore.instance;

  late String _searchQuery;
  final TextEditingController _searchController = TextEditingController();

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

  // Chip de UI → valor guardado en profesiones (dummies y catálogo)
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
        provincias = List<Map<String, dynamic>>.from(doc.data()!['provincias']);
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

  /// Iniciales para el avatar (nombre + apellido)
  String _initials(Map<String, dynamic> data) {
    final n = (data['nombre'] ?? '').toString().trim();
    final a = (data['apellido'] ?? '').toString().trim();
    if (n.isEmpty && a.isEmpty) return 'P';
    if (a.isEmpty) return n[0].toUpperCase();
    if (n.isEmpty) return a[0].toUpperCase();
    return '${n[0]}${a[0]}'.toUpperCase();
  }

  @override
  Widget build(BuildContext context) {
    final primaryColor = const Color(0xFF0F52BA);
    final textColor = const Color(0xFF1E293B);

    return GestureDetector(
      onTap: () => FocusScope.of(context).unfocus(),
      child: Scaffold(
        key: scaffoldKey,
        backgroundColor: const Color(0xFFF8FAFC),
        appBar: AppBar(
          title: const Text('Buscar Prestadores'),
          backgroundColor: primaryColor,
          foregroundColor: Colors.white,
          elevation: 0,
        ),
        body: SafeArea(
          child: Column(
            children: [
              Container(
                color: Colors.white,
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    TextField(
                      controller: _searchController,
                      decoration: InputDecoration(
                        hintText: 'Buscar por nombre o especialidad...',
                        prefixIcon: const Icon(Icons.search),
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12.0)),
                        contentPadding: const EdgeInsets.symmetric(vertical: 12.0),
                      ),
                      onChanged: (value) => setState(() => _searchQuery = value.toLowerCase()),
                    ),
                    const SizedBox(height: 12.0),

                    DropdownMenu<String>(
                      controller: _provinciaController,
                      expandedInsets: EdgeInsets.zero,
                      enableFilter: true,
                      requestFocusOnTap: true,
                      label: const Text('Provincia'),
                      inputDecorationTheme: InputDecorationTheme(
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12.0)),
                        contentPadding: const EdgeInsets.symmetric(horizontal: 16.0),
                      ),
                      dropdownMenuEntries: provincias.map((p) {
                        return DropdownMenuEntry<String>(
                          value: p['id'].toString(),
                          label: p['nombre'].toString(),
                        );
                      }).toList(),
                      onSelected: _onProvinciaSelected,
                    ),
                    const SizedBox(height: 12.0),

                    Row(
                      children: [
                        Expanded(
                          child: DropdownMenu<String>(
                            controller: _partidoController,
                            expandedInsets: EdgeInsets.zero,
                            enableFilter: true,
                            requestFocusOnTap: true,
                            label: const Text('Partido'),
                            inputDecorationTheme: InputDecorationTheme(
                              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12.0)),
                              contentPadding: const EdgeInsets.symmetric(horizontal: 16.0),
                            ),
                            dropdownMenuEntries: partidos.map((p) {
                              return DropdownMenuEntry<String>(
                                value: (p['departamento_id'] ?? p['id']).toString(),
                                label: (p['departamento_nombre'] ?? p['nombre']).toString(),
                              );
                            }).toList(),
                            onSelected: _onPartidoSelected,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: DropdownMenu<String>(
                            controller: _localidadController,
                            expandedInsets: EdgeInsets.zero,
                            enableFilter: true,
                            requestFocusOnTap: true,
                            label: const Text('Localidad'),
                            inputDecorationTheme: InputDecorationTheme(
                              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12.0)),
                              contentPadding: const EdgeInsets.symmetric(horizontal: 16.0),
                            ),
                            dropdownMenuEntries: localidades.map((l) {
                              return DropdownMenuEntry<String>(
                                value: (l['localidad_id'] ?? l['id']).toString(),
                                label: (l['localidad_nombre'] ?? l['nombre']).toString(),
                              );
                            }).toList(),
                            onSelected: (val) => setState(() => selectedLocalidadId = val),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12.0),

                    SizedBox(
                      height: 40,
                      child: ListView.builder(
                        scrollDirection: Axis.horizontal,
                        itemCount: _rubros.length,
                        itemBuilder: (context, index) {
                          final rubro = _rubros[index];
                          final isSelected = _selectedRubro == rubro;
                          return Padding(
                            padding: const EdgeInsets.only(right: 8.0),
                            child: FilterChip(
                              label: Text(rubro),
                              selected: isSelected,
                              selectedColor: primaryColor.withOpacity(0.2),
                              checkmarkColor: primaryColor,
                              onSelected: (selected) => setState(() => _selectedRubro = rubro),
                            ),
                          );
                        },
                      ),
                    ),
                  ],
                ),
              ),

              Expanded(
                child: StreamBuilder<QuerySnapshot>(
                  stream: FirebaseFirestore.instance.collection('usuarios').snapshots(),
                  builder: (context, snapshot) {
                    if (!snapshot.hasData) {
                      return const Center(child: CircularProgressIndicator());
                    }

                    final docs = snapshot.data!.docs;

                    final filteredDocs = docs.where((doc) {
                      final data = doc.data() as Map<String, dynamic>;

                      // Prestador real o dummy con es_trabajador
                      final esPrestador =
                          data['rol'] == 'trabajador' || data['es_trabajador'] == true;
                      if (!esPrestador) return false;

                      final cobertura = data['zonas_cobertura'] as Map<String, dynamic>?;
                      if (cobertura == null) return false;

                      final String providerProvinciaId =
                          (cobertura['provincia_id'] ?? '').toString();
                      final List<dynamic> provLocalidades =
                          cobertura['localidades'] as List<dynamic>? ?? [];
                      final List<dynamic> provPartidos =
                          cobertura['partidos'] as List<dynamic>? ?? [];

                      // Provincia (solo si el usuario eligió una)
                      if (selectedProvinciaId != null &&
                          providerProvinciaId != selectedProvinciaId.toString()) {
                        // Compatibilidad dummies BA/SF/MZ vs ids del catálogo
                        final selectedNombre = provincias
                            .where((p) => p['id'].toString() == selectedProvinciaId)
                            .map((p) => p['nombre'].toString().toLowerCase())
                            .cast<String>()
                            .toList();
                        final providerNombre =
                            (cobertura['provincia_nombre'] ?? '').toString().toLowerCase();
                        final matchByName = selectedNombre.isNotEmpty &&
                            selectedNombre.first == providerNombre;
                        if (!matchByName) return false;
                      }

                      // Localidad
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
                      }
                      // Partido
                      else if (selectedPartidoId != null) {
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

                      final List<dynamic> profesiones = data['profesiones'] ?? [];
                      final profesionesNorm = profesiones
                          .map((e) => e.toString().toLowerCase().trim())
                          .toList();

                      // Chip de rubro → clave de profesión
                      if (_selectedRubro != 'Todos') {
                        final clave = _rubroToProfesion[_selectedRubro] ??
                            _selectedRubro.toLowerCase();
                        if (!profesionesNorm.contains(clave)) return false;
                      }

                      final nombre = (data['nombre'] ?? '').toString().toLowerCase();
                      final apellido = (data['apellido'] ?? '').toString().toLowerCase();
                      final nombreComercial =
                          (data['nombre_comercial'] ?? '').toString().toLowerCase();
                      final profesionesStr = profesionesNorm.join(' ');

                      if (_searchQuery.isEmpty) return true;

                      return nombre.contains(_searchQuery) ||
                          apellido.contains(_searchQuery) ||
                          nombreComercial.contains(_searchQuery) ||
                          profesionesStr.contains(_searchQuery);
                    }).toList();

                    if (filteredDocs.isEmpty) {
                      return const Center(
                        child: Text('No se encontraron prestadores con estos filtros.'),
                      );
                    }

                    return ListView.builder(
                      padding: const EdgeInsets.all(16.0),
                      itemCount: filteredDocs.length,
                      itemBuilder: (context, index) {
                        final doc = filteredDocs[index];
                        final data = doc.data() as Map<String, dynamic>;

                        final double promedio =
                            (data['promedioEstrellas'] ?? 0.0).toDouble();
                        final int cantidadEvaluadores = data['cantidadEvaluadores'] ?? 0;
                        final List<dynamic> profesiones = data['profesiones'] ?? [];

                        return Card(
                          margin: const EdgeInsets.only(bottom: 12.0),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          elevation: 1,
                          child: ListTile(
                            contentPadding: const EdgeInsets.symmetric(
                              horizontal: 16,
                              vertical: 8,
                            ),
                            leading: CircleAvatar(
                              backgroundColor: primaryColor.withOpacity(0.15),
                              child: Text(
                                _initials(data),
                                style: TextStyle(
                                  color: primaryColor,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 14,
                                ),
                              ),
                            ),
                            title: Text(
                              '${data['nombre'] ?? ''} ${data['apellido'] ?? ''}',
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                color: textColor,
                              ),
                            ),
                            subtitle: Text(
                              profesiones.isNotEmpty
                                  ? profesiones.join(', ')
                                  : 'Prestador',
                              style: const TextStyle(color: Colors.grey),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                            trailing: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const Icon(
                                  Icons.star_rounded,
                                  color: Color(0xFFFFB000),
                                  size: 20,
                                ),
                                const SizedBox(width: 4),
                                Text(
                                  cantidadEvaluadores > 0
                                      ? promedio.toStringAsFixed(1)
                                      : 'Nuevo',
                                  style: TextStyle(
                                    fontWeight: FontWeight.bold,
                                    color: textColor,
                                  ),
                                ),
                              ],
                            ),
                            onTap: () {
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (context) =>
                                      TarjetaDigitalWidget(usuarioRef: doc.reference),
                                ),
                              );
                            },
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
