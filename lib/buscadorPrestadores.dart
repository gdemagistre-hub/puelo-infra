import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'user_session.dart';
import 'menuPerfil.dart';

class BuscadorPrestadoresWidget extends StatefulWidget {
  const BuscadorPrestadoresWidget({super.key});

  static const String routeName = 'BuscadorPrestadores';
  static const String routePath = '/buscador-prestadores';

  @override
  State<BuscadorPrestadoresWidget> createState() => _BuscadorPrestadoresWidgetState();
}

class _BuscadorPrestadoresWidgetState extends State<BuscadorPrestadoresWidget> {
  final primaryColor = const Color(0xFF0F52BA);
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';

  // Paleta de colores pastel (igual que en homepage)
  final List<Color> _pastelColors = [
    const Color(0xFF42A5F5), // azul
    const Color(0xFFAB47BC), // púrpura
    const Color(0xFF26A69A), // teal
    const Color(0xFFEF5350), // rojo/coral
    const Color(0xFF5C6BC0), // índigo
    const Color(0xFF26C6DA), // cyan
    const Color(0xFFEC407A), // pink
    const Color(0xFF66BB6A), // verde
  ];

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  String _getInitials(String? nombre, String? apellido) {
    final n = (nombre ?? '').trim();
    final a = (apellido ?? '').trim();

    if (n.isEmpty && a.isEmpty) return '??';
    if (n.isNotEmpty && a.isNotEmpty) {
      return '${n[0]}${a[0]}'.toUpperCase();
    }
    if (n.isNotEmpty) return n[0].toUpperCase();
    return a[0].toUpperCase();
  }

  Color _getColorForUser(String key) {
    final hash = key.hashCode.abs();
    return _pastelColors[hash % _pastelColors.length];
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF0F9FF),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.black),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text(
          'Prestadores de servicio',
          style: TextStyle(
            color: Colors.black,
            fontWeight: FontWeight.bold,
            fontSize: 18,
          ),
        ),
        centerTitle: true,
        actions: [
          IconButton(
            icon: const Icon(Icons.notifications_outlined, color: Colors.black),
            onPressed: () {},
          ),
        ],
      ),
      body: Column(
        children: [
          // Search Bar
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
            child: TextField(
              controller: _searchController,
              decoration: InputDecoration(
                hintText: 'What service do you need',
                prefixIcon: const Icon(Icons.search, color: Colors.grey),
                filled: true,
                fillColor: Colors.white,
                contentPadding: const EdgeInsets.symmetric(vertical: 0),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(30),
                  borderSide: BorderSide.none,
                ),
              ),
              onChanged: (value) {
                setState(() {
                  _searchQuery = value.toLowerCase().trim();
                });
              },
            ),
          ),

          // Lista de prestadores
          Expanded(
            child: StreamBuilder<QuerySnapshot>(
              stream: FirebaseFirestore.instance
                  .collection('usuarios')
                  .where('es_trabajador', isEqualTo: true)
                  .snapshots(),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }

                if (snapshot.hasError) {
                  return Center(child: Text('Error: ${snapshot.error}'));
                }

                final docs = snapshot.data?.docs ?? [];

                // Filtro en tiempo real
                final filteredDocs = docs.where((doc) {
                  if (_searchQuery.isEmpty) return true;

                  final data = doc.data() as Map<String, dynamic>;
                  final nombre = (data['nombre'] as String? ?? '').toLowerCase();
                  final apellido = (data['apellido'] as String? ?? '').toLowerCase();
                  final profesiones = ((data['profesiones'] as List<dynamic>?) ?? [])
                      .map((e) => e.toString().toLowerCase())
                      .join(' ');

                  return nombre.contains(_searchQuery) ||
                      apellido.contains(_searchQuery) ||
                      profesiones.contains(_searchQuery);
                }).toList();

                if (filteredDocs.isEmpty) {
                  return const Center(
                    child: Text(
                      'No se encontraron prestadores',
                      style: TextStyle(color: Colors.grey),
                    ),
                  );
                }

                return ListView.builder(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  itemCount: filteredDocs.length,
                  itemBuilder: (context, index) {
                    final data = filteredDocs[index].data() as Map<String, dynamic>;
                    final docId = filteredDocs[index].id;

                    final nombre = data['nombre'] as String? ?? '';
                    final apellido = data['apellido'] as String? ?? '';
                    final nombreCompleto = '$nombre $apellido'.trim();
                    final profesiones = (data['profesiones'] as List<dynamic>?)
                            ?.map((e) => e.toString())
                            .join(', ') ??
                        'Servicio general';
                    final urlFoto = data['url_foto_perfil'] as String?;
                    final distancia = data['distancia'] as String? ?? '1.2 km';

                    final color = _getColorForUser(docId);
                    final initials = _getInitials(nombre, apellido);

                    return GestureDetector(
                      onTap: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => const MenuPerfilWidget(),
                          ),
                        );
                      },
                      child: Container(
                        margin: const EdgeInsets.only(bottom: 12),
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(16),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withOpacity(0.04),
                              blurRadius: 10,
                              offset: const Offset(0, 4),
                            ),
                          ],
                        ),
                        child: Row(
                          children: [
                            // Círculo con foto o iniciales
                            CircleAvatar(
                              radius: 28,
                              backgroundColor: color.withOpacity(0.15),
                              backgroundImage: (urlFoto != null && urlFoto.isNotEmpty)
                                  ? NetworkImage(urlFoto)
                                  : null,
                              child: (urlFoto == null || urlFoto.isEmpty)
                                  ? Text(
                                      initials,
                                      style: TextStyle(
                                        color: color,
                                        fontWeight: FontWeight.bold,
                                        fontSize: 18,
                                      ),
                                    )
                                  : null,
                            ),
                            const SizedBox(width: 14),

                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    nombreCompleto.isNotEmpty
                                        ? nombreCompleto
                                        : 'Prestador',
                                    style: const TextStyle(
                                      fontWeight: FontWeight.bold,
                                      fontSize: 16,
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    profesiones,
                                    maxLines: 2,
                                    overflow: TextOverflow.ellipsis,
                                    style: const TextStyle(
                                      fontSize: 13,
                                      color: Colors.black54,
                                    ),
                                  ),
                                ],
                              ),
                            ),

                            Text(
                              distancia,
                              style: const TextStyle(
                                color: Colors.grey,
                                fontSize: 13,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ],
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
    );
  }
}
