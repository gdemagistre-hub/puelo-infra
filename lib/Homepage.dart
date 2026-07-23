import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'user_session.dart';
import 'loginScreen.dart';
import 'buscadorPrestadores.dart';
import 'menuEvaluaciones.dart';
import 'menuPerfil.dart';
import 'registroTrabajador.dart';
import 'tarjetaDigital.dart';
import 'menuPerfilOpciones.dart';

class HomePageWidget extends StatefulWidget {
  const HomePageWidget({super.key});
  static const String routeName = 'HomePage';
  static const String routePath = '/home';

  @override
  State<HomePageWidget> createState() => _HomePageWidgetState();
}

class _HomePageWidgetState extends State<HomePageWidget> {
  final primaryColor = const Color(0xFF0F52BA);
  final accentBlue = const Color(0xFF00BCD4);
  final TextEditingController _searchController = TextEditingController();

  // 0 = Home, 1 = Evaluar, 2 = Mensajes, 3 = Perfil (menú flotante)
  int _currentIndex = 0;

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

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
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => TarjetaDigitalWidget(
                  usuarioRef: FirebaseFirestore.instance.collection('usuarios').doc(userId),
                ),
              ),
            );
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

  void _irAGuiaInstagram() {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Abriendo guía: Cómo promocionar tus trabajos en Instagram...')),
    );
  }

  void _irABuscador([String? query]) {
    final texto = (query ?? _searchController.text).trim();
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => BuscadorPrestadoresWidget(initialQuery: texto.isEmpty ? null : texto),
      ),
    );
  }

  String _getInitials() {
    final nombreCompleto = UserSession().nombreCompleto.trim();
    if (nombreCompleto.isEmpty) return 'U';

    final partes = nombreCompleto.split(' ');
    if (partes.length >= 2) {
      return '${partes[0][0]}${partes[1][0]}'.toUpperCase();
    }
    return partes[0][0].toUpperCase();
  }

  void _onBottomNavTap(int index) {
    // Si estaba en Perfil y toca Home / Evaluar / Mensajes → cierra el menú (flota hacia abajo)
    if (_currentIndex == 3 && index != 3) {
      setState(() => _currentIndex = 0);
    }

    if (index == 0) {
      setState(() => _currentIndex = 0);
      return;
    }

    if (index == 1) {
      setState(() => _currentIndex = 0); // cierra perfil si estaba abierto
      Navigator.push(context, MaterialPageRoute(builder: (_) => const MenuEvaluacionesWidget()));
      return;
    }

    if (index == 2) {
      setState(() => _currentIndex = 0);
      // Mensajes todavía no implementado
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Mensajes próximamente')),
      );
      return;
    }

    if (index == 3) {
      // Mostrar menú de perfil flotante
      setState(() => _currentIndex = 3);
    }
  }

  @override
  Widget build(BuildContext context) {
    final String nombreMostrar = UserSession().nombreCompleto.isNotEmpty
        ? UserSession().nombreCompleto.split(' ').first
        : 'Usuario';

    return Scaffold(
      backgroundColor: const Color(0xFFF0F9FF),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Hola $nombreMostrar',
              style: const TextStyle(
                color: Colors.black,
                fontSize: 20,
                fontWeight: FontWeight.bold,
              ),
            ),
            const Text(
              '¿Qué vas a hacer hoy?',
              style: TextStyle(color: Colors.grey, fontSize: 14),
            ),
          ],
        ),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 16),
            child: CircleAvatar(
              radius: 20,
              backgroundColor: primaryColor,
              child: Text(
                _getInitials(),
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                ),
              ),
            ),
          ),
        ],
      ),
      // El body cambia: Home normal o menú de perfil (animado)
      body: AnimatedSwitcher(
        duration: const Duration(milliseconds: 280),
        transitionBuilder: (child, animation) {
          // Flota desde abajo cuando entra el menú de perfil
          final offsetAnimation = Tween<Offset>(
            begin: const Offset(0, 1),
            end: Offset.zero,
          ).animate(CurvedAnimation(parent: animation, curve: Curves.easeOutCubic));

          return SlideTransition(
            position: offsetAnimation,
            child: child,
          );
        },
        child: _currentIndex == 3
            ? MenuPerfilOpcionesWidget(
                key: const ValueKey('perfil'),
                onClose: () => setState(() => _currentIndex = 0),
              )
            : _buildHomeBody(key: const ValueKey('home')),
      ),
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _currentIndex == 3 ? 3 : 0,
        selectedItemColor: primaryColor,
        unselectedItemColor: Colors.grey,
        type: BottomNavigationBarType.fixed,
        items: const [
          BottomNavigationBarItem(icon: Icon(Icons.home), label: 'Home'),
          BottomNavigationBarItem(icon: Icon(Icons.add_circle_outline), label: 'Evaluar'),
          BottomNavigationBarItem(icon: Icon(Icons.chat_bubble_outline), label: 'Mensajes'),
          BottomNavigationBarItem(icon: Icon(Icons.person), label: 'Perfil'),
        ],
        onTap: _onBottomNavTap,
      ),
    );
  }

  Widget _buildHomeBody({Key? key}) {
    return SingleChildScrollView(
      key: key,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Search Bar
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: TextField(
              controller: _searchController,
              textInputAction: TextInputAction.search,
              decoration: InputDecoration(
                hintText: '¿Qué servicio buscas?',
                prefixIcon: const Icon(Icons.search, color: Colors.grey),
                filled: true,
                fillColor: Colors.white,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(30),
                  borderSide: BorderSide.none,
                ),
              ),
              onSubmitted: (value) {
                _irABuscador(value);
              },
            ),
          ),

          // Banner
          GestureDetector(
            onTap: _irAGuiaInstagram,
            child: Container(
              margin: const EdgeInsets.symmetric(horizontal: 16),
              height: 128,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(16),
                gradient: LinearGradient(
                  colors: [
                    primaryColor.withOpacity(0.85),
                    accentBlue.withOpacity(0.9),
                  ],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
              ),
              child: const Padding(
                padding: EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      '¿Sabes cómo comunicar tus trabajos en Instagram?',
                      style: TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                        height: 1.3,
                      ),
                    ),
                    SizedBox(height: 6),
                    Text(
                      'Toca aquí para ver el mini-manual',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 13,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),

          const SizedBox(height: 24),

          // Services Grid
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 16),
            child: Text(
              'Servicios',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            ),
          ),
          const SizedBox(height: 12),
          GridView.count(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            crossAxisCount: 4,
            padding: const EdgeInsets.symmetric(horizontal: 12),
            childAspectRatio: 0.9,
            children: [
              _buildServiceIcon(Icons.search, 'Buscar Servicios', () {
                _irABuscador();
              }),
              _buildServiceIcon(Icons.check_circle_outline, 'Evaluar Trabajos', () {
                Navigator.push(context, MaterialPageRoute(builder: (_) => const MenuEvaluacionesWidget()));
              }),
              _buildServiceIcon(Icons.badge, 'Compartir Tarjeta', _compartirTarjeta),
              _buildServiceIcon(Icons.person_outline, 'Sobre Mí', () {
                setState(() => _currentIndex = 3);
              }),
            ],
          ),

          const SizedBox(height: 24),

          // Últimos Mensajes
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 16),
            child: Text(
              'Últimos Mensajes',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            ),
          ),
          const SizedBox(height: 12),

          _buildProviderCard(
            'Electricians repair',
            'Nuestro electricista completó el trabajo en tiempo récord.',
            'Hace 2h',
            Colors.blue,
          ),
          _buildProviderCard(
            'Plumbing Service',
            'Se reparó la pérdida de agua en la cocina.',
            'Ayer',
            Colors.purple,
          ),
        ],
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
              boxShadow: [
                BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 8),
              ],
            ),
            child: Icon(icon, size: 32, color: primaryColor),
          ),
          const SizedBox(height: 6),
          Text(
            label,
            style: const TextStyle(fontSize: 12),
            textAlign: TextAlign.center,
          ),
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
        boxShadow: [
          BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 10),
        ],
      ),
      child: Row(
        children: [
          CircleAvatar(
            backgroundColor: color.withOpacity(0.15),
            child: Text(
              title[0],
              style: TextStyle(color: color, fontWeight: FontWeight.bold),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: const TextStyle(fontWeight: FontWeight.bold)),
                Text(
                  description,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontSize: 13),
                ),
              ],
            ),
          ),
          Text(
            time,
            style: const TextStyle(color: Colors.grey, fontSize: 12),
          ),
        ],
      ),
    );
  }
}
