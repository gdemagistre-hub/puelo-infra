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

  // Lista estática de rubros para el filtro superior rápido
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
              // Barra de búsqueda y Filtros
              Container(
                color: Colors.white,
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  children: [
                    TextField(
                      decoration: InputDecoration(
                        hintText: 'Buscar por nombre o especialidad...',
                        prefixIcon: const Icon(Icons.search),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12.0),
                        ),
                        contentPadding: const EdgeInsets.symmetric(vertical: 12.0),
                      ),
                      onChanged: (value) {
                        setState(() {
                          _searchQuery = value.toLowerCase();
                        });
                      },
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
                              labelStyle: TextStyle(
                                color: isSelected ? primaryColor : textColor,
                                fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                              ),
                              onSelected: (selected) {
                                setState(() {
                                  _selectedRubro = rubro;
                                });
                              },
                            ),
                          );
                        },
                      ),
                    ),
                  ],
                ),
              ),

              // Lista Dinámica desde Firestore
              Expanded(
                child: StreamBuilder<QuerySnapshot>(
                  stream: FirebaseFirestore.instance.collection('usuarios').snapshots(),
                  builder: (context, snapshot) {
                    if (snapshot.hasError) {
                      return const Center(child: Text('Ocurrió un error al cargar los datos.'));
                    }
                    if (snapshot.connectionState == ConnectionState.waiting) {
                      return const Center(child: CircularProgressIndicator());
                    }

                    final docs = snapshot.data?.docs ?? [];

                    // Filtramos los usuarios en el cliente para permitir búsquedas parciales fluidas
                    final filteredDocs = docs.where((doc) {
                      final data = doc.data() as Map<String, dynamic>;
                      
                      final nombre = (data['nombre'] ?? '').toString().toLowerCase();
                      final apellido = (data['apellido'] ?? '').toString().toLowerCase();
                      final nombreComercial = (data['nombre_comercial'] ?? '').toString().toLowerCase();
                      final rubro = (data['rubro'] ?? '').toString();

                      // Filtro por Rubro seleccionado en los Chips
                      if (_selectedRubro != 'Todos' && rubro != _selectedRubro) {
                        return false;
                      }

                      // Filtro por texto de búsqueda
                      final matchesText = nombre.contains(_searchQuery) || 
                                          apellido.contains(_searchQuery) || 
                                          nombreComercial.contains(_searchQuery) ||
                                          rubro.toLowerCase().contains(_searchQuery);

                      return matchesText;
                    }).toList();

                    if (filteredDocs.isEmpty) {
                      return const Center(
                        child: Text(
                          'No se encontraron prestadores que coincidan.',
                          style: TextStyle(color: Colors.grey, fontSize: 16),
                        ),
                      );
                    }

                    return ListView.builder(
                      padding: const EdgeInsets.all(16.0),
                      itemCount: filteredDocs.length,
                      itemBuilder: (context, index) {
                        final doc = filteredDocs[index];
                        final data = doc.data() as Map<String, dynamic>;

                        String displayName = data['nombre_comercial'] ?? '${data['nombre'] ?? ''} ${data['apellido'] ?? ''}';
                        if (displayName.trim().isEmpty) displayName = 'Prestador sin nombre';
                        
                        final rubro = data['rubro'] ?? 'Especialidad no especificada';
                        final telefono = data['telefono'] ?? 'Sin teléfono';

                        // Recuperamos las variables del promedio pre-computado anti-fraude
                        final double promedio = (data['promedioEstrellas'] ?? 0.0).toDouble();
                        final int cantidadEvaluadores = data['cantidadEvaluadores'] ?? 0;

                        return Card(
                          margin: const EdgeInsets.only(bottom: 12.0),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16.0),
                          ),
                          elevation: 2,
                          child: ListTile(
                            contentPadding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
                            leading: CircleAvatar(
                              backgroundColor: primaryColor.withOpacity(0.1),
                              child: Icon(Icons.person, color: primaryColor),
                            ),
                            title: Row(
                              children: [
                                Expanded(
                                  child: Text(
                                    displayName,
                                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                                const SizedBox(width: 8),
                                // Componente visual dinámico de estrellas en el listado
                                Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    const Icon(Icons.star_rounded, color: Color(0xFFFFB000), size: 18),
                                    const SizedBox(width: 2),
                                    Text(
                                      cantidadEvaluadores > 0 
                                          ? promedio.toStringAsFixed(1) 
                                          : 'Nuevo',
                                      style: TextStyle(
                                        fontSize: 13,
                                        fontWeight: FontWeight.bold,
                                        color: textColor,
                                      ),
                                    ),
                                    if (cantidadEvaluadores > 0) ...[
                                      const SizedBox(width: 2),
                                      Text(
                                        '($cantidadEvaluadores)',
                                        style: const TextStyle(
                                          fontSize: 11,
                                          color: Color(0xFF64748B),
                                        ),
                                      ),
                                    ],
                                  ],
                                ),
                              ],
                            ),
                            subtitle: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const SizedBox(height: 4),
                                Text(rubro, style: TextStyle(color: primaryColor, fontWeight: FontWeight.w500)),
                                const SizedBox(height: 2),
                                Text(telefono, style: const TextStyle(color: Colors.grey)),
                              ],
                            ),
                            trailing: const Icon(Icons.arrow_forward_ios, size: 16, color: Colors.grey),
                            onTap: () {
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (context) => TarjetaDigitalWidget(usuarioRef: doc.reference),
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
