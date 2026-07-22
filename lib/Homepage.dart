import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'user_session.dart';
import 'loginScreen.dart';
import 'buscadorPrestadores.dart';
import 'menuEvaluaciones.dart';
import 'menuPerfil.dart';
import 'registroTrabajador.dart';
import 'tarjetaDigital.dart';

class HomePageWidget extends StatefulWidget {
  const HomePageWidget({super.key});
  static const String routeName = 'HomePage';
  static const String routePath = '/home';

  @override
  State<HomePageWidget> createState() => _HomePageWidgetState();
}

class _HomePageWidgetState extends State<HomePageWidget> {
  final primaryColor = const Color(0xFF0F52BA);
  final textColor = const Color(0xFF1E293B);

  void _cerrarSesion() {
    UserSession().cerrarSesion();
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(builder: (context) => const LoginScreenWidget()),
    );
  }

  void _compartirTarjeta() async {
    final String? userId = UserSession().uid;
    if (userId == null || userId.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Error: No se encontró la sesión activa.')),
      );
      return;
    }

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => const Center(child: CircularProgressIndicator()),
    );

    try {
      final doc = await FirebaseFirestore.instance.collection('usuarios').doc(userId).get();
      if (context.mounted) Navigator.pop(context);

      if (doc.exists) {
        final data = doc.data() as Map<String, dynamic>;
        final profesiones = data['profesiones'] as List<dynamic>? ?? [];
        final zonasCobertura = data['zonas_cobertura'] as Map<String, dynamic>? ?? {};
        final localidades = zonasCobertura['localidades'] as List<dynamic>? ?? [];
        final esTrabajador = data['es_trabajador'] == true;

        if (profesiones.isEmpty || localidades.isEmpty || !esTrabajador) {
          if (context.mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Para compartir tu tarjeta, primero configurá tus especialidades y zonas.')),
            );
            Navigator.push(context, MaterialPageRoute(builder: (_) => const RegistroTrabajadorWidget()));
          }
        } else {
          if (context.mounted) {
            Navigator.push(context, MaterialPageRoute(builder: (_) => TarjetaDigitalWidget(usuarioRef: FirebaseFirestore.instance.collection('usuarios').doc(userId))));
          }
        }
      }
    } catch (e) {
      if (context.mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
      }
    }
  }

  // Acción del banner (puedes cambiar el texto y destino fácilmente)
  void _irAGuiaInstagram() {
    // Aquí puedes navegar a un mini-manual o mostrar un diálogo
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Abriendo guía: Cómo promocionar tus trabajos en Instagram...')),
    );
    // Navigator.push(context, MaterialPageRoute(builder: (_) => const GuiaInstagramWidget()));
  }

  @override
  Widget build(BuildContext context) {
    final String nombreMostrar = UserSession().nombreCompleto.isNotEmpty
        ? UserSession().nombreCompleto.split(' ').first
        : 'Usuario';

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Hola $nombreMostrar', style: const TextStyle(color: Colors.black, fontSize: 20, fontWeight: FontWeight.bold)),
            const Text('¿Qué vas a hacer hoy?', style: TextStyle(color: Colors.grey, fontSize: 14)),
          ],
        ),
        actions: [
          IconButton(icon: const Icon(Icons.notifications_outlined, color: Colors.black), onPressed: () {}),
        ],
      ),
      body: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Search Bar
            Padding(
              padding: const EdgeInsets.all(16.0),
              child: TextField(
                decoration: InputDecoration(
                  hintText: 'What service do you need',
                  prefixIcon: const Icon(Icons.search, color: Colors.grey),
                  filled: true,
                  fillColor: Colors.white,
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(30), borderSide: BorderSide.none),
                ),
              ),
            ),

            // Banner Promocional / Informativo
            GestureDetector(
              onTap: _irAGuiaInstagram,
              child: Container(
                margin: const EdgeInsets.symmetric(horizontal: 16),
                height: 160,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(16),
                  color: primaryColor.withOpacity(0.1),
                  image: const DecorationImage(
                    image: AssetImage('assets/banner_placeholder.jpg'),
                    fit: BoxFit.cover,
                  ),
                ),
                child: const Padding(
                  padding: EdgeInsets.all(16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      Text(
                        '¿Sabes cómo comunicar tus trabajos en Instagram?',
                        style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 18),
                      ),
                      SizedBox(height: 4),
                      Text(
                        'Toca aquí para ver el mini-manual',
                        style: TextStyle(color: Colors.white70, fontSize: 14),
                      ),
                    ],
                  ),
                ),
              ),
            ),

            const SizedBox(height: 24),

            // Services Grid - 4 iconos
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 16),
              child: Text('Servicios', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
            ),
            const SizedBox(height: 12),
            GridView.count(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              crossAxisCount: 4,
              padding: const EdgeInsets.symmetric(horizontal: 12),
              childAspectRatio: 0.9,
              children: [
                _buildServiceIcon(Icons.search, 'Buscar Servicios', () => Navigator.push(context, MaterialPageRoute(builder: (_) => const BuscadorPrestadoresWidget()))),
                _buildServiceIcon(Icons.check_circle_outline, 'Evaluar Trabajos', () => Navigator.push(context, MaterialPageRoute(builder: (_) => const MenuEvaluacionesWidget()))),
                _buildServiceIcon(Icons.badge, 'Compartir Tarjeta', _compartirTarjeta),
                _buildServiceIcon(Icons.person_outline, 'Sobre Mí', () => Navigator.push(context, MaterialPageRoute(builder: (_) => const MenuPerfilWidget()))),
              ],
            ),

            const SizedBox(height: 24),

            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 16),
              child: Text('Últimos Mensajes', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
            ),
            const SizedBox(height: 12),

            _buildProviderCard('Electricians repair', 'Nuestro electricista completó el trabajo en tiempo récord.', 'Hace 2h', Colors.purple),
            _buildProviderCard('Plumbing Service', 'Se reparó la pérdida de agua en la cocina.', 'Ayer', Colors.blue),
          ],
        ),
      ),
      bottomNavigationBar: BottomNavigationBar(
        selectedItemColor: primaryColor,
        unselectedItemColor: Colors.grey,
        type: BottomNavigationBarType.fixed,
        items: const [
          BottomNavigationBarItem(icon: Icon(Icons.home), label: 'Home'),
          BottomNavigationBarItem(icon: Icon(Icons.add_circle_outline), label: 'Evaluar'),
          BottomNavigationBarItem(icon: Icon(Icons.chat_bubble_outline), label: 'Mensajes'),
          BottomNavigationBarItem(icon: Icon(Icons.person), label: 'Perfil'),
        ],
        onTap: (index) {
          if (index == 0) return;
          if (index == 1) Navigator.push(context, MaterialPageRoute(builder: (_) => const MenuEvaluacionesWidget()));
          if (index == 3) Navigator.push(context, MaterialPageRoute(builder: (_) => const MenuPerfilWidget()));
        },
      ),
    );
  }

  Widget _buildServiceIcon(IconData icon, String label, VoidCallback onTap) {
    return InkWell(
      onTap: onTap,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
              boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 8)],
            ),
            child: Icon(icon, size: 32, color: primaryColor),
          ),
          const SizedBox(height: 6),
          Text(label, style: const TextStyle(fontSize: 12), textAlign: TextAlign.center),
        ],
      ),
    );
  }

  Widget _buildProviderCard(String title, String description, String time, Color color) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 10)],
      ),
      child: Row(
        children: [
          CircleAvatar(backgroundColor: color.withOpacity(0.1), child: Text(title[0], style: TextStyle(color: color, fontWeight: FontWeight.bold))),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: const TextStyle(fontWeight: FontWeight.bold)),
                Text(description, maxLines: 2, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 13)),
              ],
            ),
          ),
          Text(time, style: const TextStyle(color: Colors.grey, fontSize: 12)),
        ],
      ),
    );
  }
}
