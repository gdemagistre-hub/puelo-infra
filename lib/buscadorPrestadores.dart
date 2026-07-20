import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'tarjetaDigital.dart';

class BuscadorPrestadoresWidget extends StatefulWidget {
  const BuscadorPrestadoresWidget({super.key});

  static const String routeName = 'BuscadorPrestadores';
  static const String routePath = '/buscadorPrestadores';

  @override
  State<BuscadorPrestadoresWidget> createState() => _BuscadorPrestadoresWidgetState();
}

class _BuscadorPrestadoresWidgetState extends State<BuscadorPrestadoresWidget> {
  final scaffoldKey = GlobalKey<ScaffoldState>();
  final db = FirebaseFirestore.instance;

  String _searchQuery = '';
  String _selectedRubro = 'Todos';
  final List<String> _rubros = ['Todos', 'Electricista', 'Plomero', 'Gasista', 'Carpintero', 'Pintor', 'Construcción'];

  // NUEVOS FILTROS GEOGRÁFICOS DINÁMICOS
  String? selectedProvinciaId;
  String? selectedPartidoId;
  String? selectedLocalidadId;

  List<Map<String, dynamic>> provincias = [];
  List<Map<String, dynamic>> partidos = [];
  List<Map<String, dynamic>> localidades = [];

  @override
  void initState() {
    super.initState();
    _loadProvincias();
  }

  // --- LÓGICA DE CASCADA DESDE FIRESTORE ---
  Future<void> _loadProvincias() async {
    final doc = await db.collection('cat_paises').doc('AR').get();
    if (doc.exists && doc.data()!.containsKey('provincias')) {
      setState(() {
        provincias = List<Map<String, dynamic>>.from(doc.data()!['provincias']);
      });
    }
  }

  Future<void> _onProvinciaSelected(String? provId) async {
    if (provId == null) return;
    
    setState(() {
      selectedProvinciaId = provId;
      selectedPartidoId = null;
      selectedLocalidadId = null;
      partidos = [];
      localidades = [];
    });

    final query = await db.collection('cat_departamentos')
        .where('provincia_id', isEqualTo: provId)
        .get();

    setState(() {
      partidos = query.docs.map((d) => d.data()).toList();
    });
  }

  Future<void> _onPartidoSelected(String? partId) async {
    if (partId == null) return;
    
    setState(() {
      selectedPartidoId = partId;
      selectedLocalidadId = null;
      localidades = [];
    });

    final query = await db.collection('cat_localidades')
        .where('partido_id', isEqualTo: partId)
        .get();

    setState(() {
      localidades = query.docs.map((d) => d.data()).toList();
    });
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
              // Barra de búsqueda y selectores geográficos
              Container(
                color: Colors.white,
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  children: [
                    TextField(
                      decoration: InputDecoration(
                        hintText: 'Buscar por nombre o especialidad...',
                        prefixIcon: const Icon(Icons.search),
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12.0)),
                        contentPadding: const EdgeInsets.symmetric(vertical: 12.0),
                      ),
                      onChanged: (value) => setState(() => _searchQuery = value.toLowerCase()),
                    ),
                    const SizedBox(height: 12.0),
                    
                    // SELECTORES DE FILTRO GEOGRÁFICO DINÁMICOS
                    DropdownButtonFormField<String>(
                      value: selectedProvinciaId,
                      decoration: const InputDecoration(labelText: 'Provincia', border: OutlineInputBorder()),
                      items: provincias.map((p) {
                        return DropdownMenuItem<String>(
                          value: p['id'],
                          child: Text(p['nombre']),
                        );
                      }).toList(),
                      onChanged: _onProvinciaSelected,
                    ),
                    const SizedBox(height: 12.0),
                    Row(
                      children: [
                        Expanded(
                          child: DropdownButtonFormField<String>(
                            value: selectedPartidoId,
                            decoration: const InputDecoration(labelText: 'Partido', border: OutlineInputBorder()),
                            items: partidos.map((p) {
                              return DropdownMenuItem<String>(
                                value: p['departamento_id'],
                                child: Text(p['departamento_nombre'], overflow: TextOverflow.ellipsis),
                              );
                            }).toList(),
                            onChanged: _onPartidoSelected,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: DropdownButtonFormField<String>(
                            value: selectedLocalidadId,
                            decoration: const InputDecoration(labelText: 'Localidad', border: OutlineInputBorder()),
                            items: localidades.map((l) {
                              return DropdownMenuItem<String>(
                                value: l['localidad_id'],
                                child: Text(l['localidad_nombre'], overflow: TextOverflow.ellipsis),
                              );
                            }).toList(),
                            onChanged: (val) => setState(() => selectedLocalidadId = val),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12.0),
                    
                    // CARRUSEL DE RUBROS
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

              // LISTADO FILTRADO DESDE FIRESTORE
              Expanded(
                child: StreamBuilder<QuerySnapshot>(
                  stream: FirebaseFirestore.instance.collection('usuarios').snapshots(),
                  builder: (context, snapshot) {
                    if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());

                    final docs = snapshot.data!.docs;

                    final filteredDocs = docs.where((doc) {
                      final data = doc.data() as Map<String, dynamic>;
                      
                      // 1. Validación de rol
                      if (data['rol'] != 'trabajador') return false;

                      // Descomposición del mapa de cobertura
                      final cobertura = data['zonas_cobertura'] as Map<String, dynamic>?;
                      if (cobertura == null) return false;

                      final String providerProvinciaId = cobertura['provincia_id'] ?? '';
                      final List<dynamic> provLocalidades = cobertura['localidades'] ?? [];

                      // 2. Filtrado por Provincia (si el usuario eligió una)
                      if (selectedProvinciaId != null && providerProvinciaId != selectedProvinciaId) {
                        return false;
                      }

                      // 3. Filtrado por Partido y Localidad
                      if (selectedLocalidadId != null) {
                        // Si eligió una localidad exacta, el prestador debe tenerla
                        final tieneLocalidad = provLocalidades.any((l) => l['id'] == selectedLocalidadId);
                        if (!tieneLocalidad) return false;
                      } else if (selectedPartidoId != null) {
                        // Si eligió un partido pero no una localidad, mostramos todos los del partido
                        final tienePartido = provLocalidades.any((l) => l['partido_id'] == selectedPartidoId);
                        if (!tienePartido) return false;
                      }

                      // 4. Filtro por Rubro
                      final rubro = (data['rubro'] ?? '').toString();
                      if (_selectedRubro != 'Todos' && rubro != _selectedRubro) return false;

                      // 5. Filtro por texto
                      final nombre = (data['nombre'] ?? '').toString().toLowerCase();
                      final apellido = (data['apellido'] ?? '').toString().toLowerCase();
                      return nombre.contains(_searchQuery) || apellido.contains(_searchQuery) || rubro.toLowerCase().contains(_searchQuery);
                    }).toList();

                    if (filteredDocs.isEmpty) {
                      return const Center(child: Text('No se encontraron prestadores con estos filtros.'));
                    }

                    return ListView.builder(
                      padding: const EdgeInsets.all(16.0),
                      itemCount: filteredDocs.length,
                      itemBuilder: (context, index) {
                        final doc = filteredDocs[index];
                        final data = doc.data() as Map<String, dynamic>;
                        final double promedio = (data['promedioEstrellas'] ?? 0.0).toDouble();
                        final int cantidadEvaluadores = data['cantidadEvaluadores'] ?? 0;

                        return Card(
                          margin: const EdgeInsets.only(bottom: 12.0),
                          child: ListTile(
                            leading: const CircleAvatar(child: Icon(Icons.person)),
                            title: Text('${data['nombre'] ?? ''} ${data['apellido'] ?? ''}'),
                            subtitle: Text(data['rubro'] ?? 'Prestador'),
                            trailing: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const Icon(Icons.star_rounded, color: Color(0xFFFFB000), size: 18),
                                Text(cantidadEvaluadores > 0 ? promedio.toStringAsFixed(1) : 'Nuevo'),
                              ],
                            ),
                            onTap: () {
                              Navigator.push(
                                context,
                                MaterialPageRoute(builder: (context) => TarjetaDigitalWidget(usuarioRef: doc.reference)),
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
