import 'package:flutter/material.dart';

class BuscadorPrestadoresWidget extends StatefulWidget {
  const BuscadorPrestadoresWidget({super.key});

  static const String routeName = 'buscadorPrestadores';
  static const String routePath = '/buscadorPrestadores';

  @override
  State<BuscadorPrestadoresWidget> createState() =>
      _BuscadorPrestadoresWidgetState();
}

class _BuscadorPrestadoresWidgetState extends State<BuscadorPrestadoresWidget> {
  late TextEditingController _searchController;
  String _filtroProfesion = 'Todos';

  // Datos simulados (Mock Data) para probar la interfaz y la interacción inmediatamente
  final List<Map<String, dynamic>> _prestadoresMock = [
    {
      'nombre': 'Carlos',
      'apellido': 'Gómez',
      'nombre_comercial': 'Plomería Gómez e Hijos',
      'profesion': 'Plomero',
      'zonas': ['Zona Norte', 'CABA'],
      'telefono': '1123456789',
      'destacado': true,
    },
    {
      'nombre': 'Eduardo',
      'apellido': 'Rodríguez',
      'nombre_comercial': 'Soporte Técnico ER',
      'profesion': 'Soporte Técnico',
      'zonas': ['Zona Oeste', 'CABA'],
      'telefono': '1198765432',
      'destacado': false,
    },
    {
      'nombre': 'Mariano',
      'apellido': 'Sosa',
      'nombre_comercial': 'Electricidad Sosa',
      'profesion': 'Electricista',
      'zonas': ['Zona Sur'],
      'telefono': '1133445566',
      'destacado': true,
    },
    {
      'nombre': 'Juan',
      'apellido': 'Pérez',
      'nombre_comercial': 'Gasista Matriculado Pérez',
      'profesion': 'Gasista',
      'zonas': ['Zona Norte'],
      'telefono': '1155667788',
      'destacado': false,
    },
  ];

  final List<String> _categorias = [
    'Todos',
    'Electricista',
    'Plomero',
    'Gasista',
    'Soporte Técnico',
  ];

  // Paleta de colores consistente
  final primaryColor = const Color(0xFF0F52BA);
  final accentColor = const Color(0xFFE8F0FE);
  final textColor = const Color(0xFF1E293B);
  final subtitleColor = const Color(0xFF64748B);

  @override
  void initState() {
    super.initState();
    _searchController = TextEditingController();
    _searchController.addListener(() {
      setState(() {}); // Actualiza la lista al escribir
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  // Filtrado lógico local combinando buscador y categoría
  List<Map<String, dynamic>> get _prestadoresFiltrados {
    final consulta = _searchController.text.toLowerCase();
    return _prestadoresMock.where((prestador) {
      final coincideBusqueda = 
          prestador['nombre_comercial'].toString().toLowerCase().contains(consulta) ||
          prestador['nombre'].toString().toLowerCase().contains(consulta) ||
          prestador['apellido'].toString().toLowerCase().contains(consulta);

      final coincideCategoria = _filtroProfesion == 'Todos' || 
          prestador['profesion'] == _filtroProfesion;

      return coincideBusqueda && coincideCategoria;
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => FocusScope.of(context).unfocus(),
      child: Scaffold(
        backgroundColor: const Color(0xFFF8FAFC), // Gris muy suave limpio
        appBar: AppBar(
          backgroundColor: Colors.white,
          elevation: 0,
          leading: IconButton(
            icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 20),
            color: textColor,
            onPressed: () => Navigator.pop(context),
          ),
          title: Text(
            'Buscador de Prestadores',
            style: TextStyle(
              color: textColor,
              fontSize: 20,
              fontWeight: FontWeight.w800,
            ),
          ),
          centerTitle: false,
        ),
        body: SafeArea(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Panel Superior de Filtros y Búsqueda
              Container(
                color: Colors.white,
                padding: const EdgeInsets.only(bottom: 16.0, left: 16.0, right: 16.0),
                child: Column(
                  children: [
                    // Input de Búsqueda
                    TextFormField(
                      controller: _searchController,
                      style: TextStyle(color: textColor, fontSize: 15),
                      decoration: InputDecoration(
                        prefixIcon: Icon(Icons.search_rounded, color: subtitleColor, size: 22),
                        suffixIcon: _searchController.text.isNotEmpty
                            ? IconButton(
                                icon: Icon(Icons.clear_rounded, color: subtitleColor),
                                onPressed: () => _searchController.clear(),
                              )
                            : null,
                        hintText: '¿Qué servicio estás buscando?',
                        hintStyle: TextStyle(color: subtitleColor.withOpacity(0.7), fontSize: 15),
                        filled: true,
                        fillColor: const Color(0xFFF1F5F9),
                        contentPadding: const EdgeInsets.symmetric(vertical: 14.0, horizontal: 16.0),
                        enabledBorder: OutlineInputBorder(
                          borderSide: BorderSide.none,
                          borderRadius: BorderRadius.circular(16),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderSide: BorderSide(color: primaryColor, width: 1.5),
                          borderRadius: BorderRadius.circular(16),
                        ),
                      ),
                    ),
                    const SizedBox(height: 16.0),

                    // Carrusel horizontal de Categorías (chips)
                    SizedBox(
                      height: 38,
                      child: ListView.builder(
                        scrollDirection: Axis.horizontal,
                        itemCount: _categorias.length,
                        itemBuilder: (context, index) {
                          final cat = _categorias[index];
                          final isSelected = _filtroProfesion == cat;
                          return Padding(
                            padding: const EdgeInsets.only(right: 8.0),
                            child: ChoiceChip(
                              label: Text(
                                cat,
                                style: TextStyle(
                                  color: isSelected ? Colors.white : textColor,
                                  fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                                  fontSize: 13,
                                ),
                              ),
                              selected: isSelected,
                              selectedColor: primaryColor,
                              backgroundColor: const Color(0xFFF1F5F9),
                              elevation: 0,
                              pressElevation: 0,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                                side: BorderSide.none,
                              ),
                              onSelected: (selected) {
                                setState(() {
                                  _filtroProfesion = cat;
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

              // Lista de resultados
              Expanded(
                child: _prestadoresFiltrados.isEmpty
                    ? _buildEmptyState()
                    : ListView.builder(
                        padding: const EdgeInsets.all(16.0),
                        itemCount: _prestadoresFiltrados.length,
                        itemBuilder: (context, index) {
                          final prestador = _prestadoresFiltrados[index];
                          return _buildPrestadorCard(prestador);
                        },
                      ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // Tarjeta de Prestador Premium
  Widget _buildPrestadorCard(Map<String, dynamic> prestador) {
    final esDestacado = prestador['destacado'] ?? false;

    return Container(
      margin: const EdgeInsets.only(bottom: 14.0),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20.0),
        border: esDestacado ? Border.all(color: primaryColor.withOpacity(0.3), width: 1.5) : null,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.03),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(18.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                // Cabecera e Información Base
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                            decoration: BoxDecoration(
                              color: primaryColor.withOpacity(0.1),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Text(
                              prestador['profesion'].toString().toUpperCase(),
                              style: TextStyle(
                                fontSize: 10,
                                fontWeight: FontWeight.w800,
                                color: primaryColor,
                                letterSpacing: 0.5,
                              ),
                            ),
                          ),
                          if (esDestacado) ...[
                            const SizedBox(width: 8),
                            const Row(
                              children: [
                                Icon(Icons.star_rounded, color: Colors.amber, size: 16),
                                SizedBox(width: 2),
                                Text(
                                  'Verificado',
                                  style: TextStyle(
                                    fontSize: 11,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.amber,
                                  ),
                                ),
                              ],
                            ),
                          ]
                        ],
                      ),
                      const SizedBox(height: 8.0),
                      Text(
                        prestador['nombre_comercial'],
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: textColor,
                        ),
                      ),
                      const SizedBox(height: 4.0),
                      Text(
                        '${prestador['nombre']} ${prestador['apellido']}',
                        style: TextStyle(
                          fontSize: 14,
                          color: subtitleColor,
                        ),
                      ),
                    ],
                  ),
                ),
                // Avatar o Sigla
                CircleAvatar(
                  radius: 24,
                  backgroundColor: accentColor,
                  child: Text(
                    '${prestador['nombre'][0]}${prestador['apellido'][0]}',
                    style: TextStyle(
                      color: primaryColor,
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16.0),
            const Divider(color: Color(0xFFF1F5F9), thickness: 1.5),
            const SizedBox(height: 8.0),

            // Ubicación y Contacto
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                // Zonas de Cobertura
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'COBERTURA',
                        style: TextStyle(
                          fontSize: 9,
                          fontWeight: FontWeight.bold,
                          color: subtitleColor,
                          letterSpacing: 0.5,
                        ),
                      ),
                      const SizedBox(height: 4.0),
                      Wrap(
                        spacing: 4,
                        children: (prestador['zonas'] as List<String>)
                            .map((zona) => Text(
                                  zona + (zona == (prestador['zonas'] as List<String>).last ? '' : ','),
                                  style: TextStyle(
                                    fontSize: 13,
                                    color: textColor,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ))
                            .toList(),
                      ),
                    ],
                  ),
                ),
                // Botón Acción
                ElevatedButton.icon(
                  onPressed: () {
                    // TODO: Acción para contactar o ver tarjeta digital del prestador
                  },
                  icon: const Icon(Icons.phone_rounded, size: 16),
                  label: const Text('Contactar'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: primaryColor,
                    foregroundColor: Colors.white,
                    elevation: 0,
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    textStyle: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  // Componente de pantalla vacía o sin resultados
  Widget _buildEmptyState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.search_off_rounded,
              size: 72,
              color: subtitleColor.withOpacity(0.4),
            ),
            const SizedBox(height: 16),
            Text(
              'Sin resultados',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: textColor,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'No encontramos prestadores que coincidan con tu búsqueda. Intentá con otros términos.',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 14,
                color: subtitleColor,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
