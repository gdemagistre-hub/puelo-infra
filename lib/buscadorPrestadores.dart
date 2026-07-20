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
  String _searchQuery = '';
  String _selectedRubro = 'Todos';

  // NUEVOS FILTROS GEOGRÁFICOS DE BÚSQUEDA
  String _filtroProvinciaId = '06'; // Por defecto Buenos Aires para Pilar
  String _filtroLocalidadId = 'Todos';

  final List<String> _rubros = ['Todos', 'Electricista', 'Plomero', 'Gasista', 'Carpintero', 'Pintor', 'Construcción'];

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
                    
                    // SELECTORES DE FILTRO GEOGRÁFICO EN EL BUSCADOR
                    Row(
                      children: [
                        Expanded(
                          child: DropdownButtonFormField<String>(
                            value: _filtroProvinciaId,
                            decoration: const InputDecoration(labelText: 'Provincia', border: OutlineInputBorder()),
                            items: const [
                              DropdownMenuItem(value: '06', child: Text('Buenos Aires')),
                              DropdownMenuItem(value: '14', child: Text('Córdoba')),
                              DropdownMenuItem(value: '30', child: Text('Entre Ríos')),
                            ],
                            onChanged: (val) => setState(() {
                              _filtroProvinciaId = val!;
                              _filtroLocalidadId = 'Todos'; // Reset localidad
                            }),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: DropdownButtonFormField<String>(
                            value: _filtroLocalidadId,
                            decoration: const InputDecoration(labelText: 'Localidad', border: OutlineInputBorder()),
                            items: [
                              const DropdownMenuItem(value: 'Todos', child: Text('Todas')),
                              if (_filtroProvinciaId == '06') ...[
                                const DropdownMenuItem(value: '06638040', child: Text('Pilar')),
                                const DropdownMenuItem(value: '06042010', child: Text('Ayacucho')),
                              ] else if (_filtroProvinciaId == '14') ...[
                                const DropdownMenuItem(value: '14042170', child: Text('Villa María')),
                              ]
                            ],
                            onChanged: (val) => setState(() => _filtroLocalidadId = val!),
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

              // LISTADO FILTRADO CON NESTED MAPS DE COBERTURA
              Expanded(
                child: StreamBuilder<QuerySnapshot>(
                  stream: FirebaseFirestore.instance.collection('usuarios').snapshots(),
                  builder: (context, snapshot) {
                    if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());

                    final docs = snapshot.data!.docs;

                    final filteredDocs = docs.where((doc) {
                      final data = doc.data() as Map<String, dynamic>;
                      
                      // Validación de rol
                      if (data['rol'] != 'trabajador') return false;

                      // Descomposición del mapa de cobertura
                      final cobertura = data['zonas_cobertura'] as Map<String, dynamic>?;
                      if (cobertura == null) return false;

                      final String providerProvinciaId = cobertura['provincia_id'] ?? '';
                      final List<dynamic> localidades = cobertura['localidades'] ?? [];

                      // 1. Filtrado por Provincia
                      if (providerProvinciaId != _filtroProvinciaId) return false;

                      // 2. Filtrado por Localidad seleccionada
                      if (_filtroLocalidadId != 'Todos') {
                        final tieneLocalidad = localidades.any((l) => l['id'] == _filtroLocalidadId);
                        if (!tieneLocalidad) return false;
                      }

                      // 3. Filtro por Rubro
                      final rubro = (data['rubro'] ?? '').toString();
                      if (_selectedRubro != 'Todos' && rubro != _selectedRubro) return false;

                      // 4. Filtro por texto
                      final nombre = (data['nombre'] ?? '').toString().toLowerCase();
                      final apellido = (data['apellido'] ?? '').toString().toLowerCase();
                      return nombre.contains(_searchQuery) || apellido.contains(_searchQuery);
                    }).toList();

                    if (filteredDocs.isEmpty) {
                      return const Center(child: Text('No se encontraron prestadores en esta zona.'));
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
