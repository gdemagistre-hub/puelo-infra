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
  // Paleta
  static const Color _clientePrimary = Color(0xFF734BE4);
  static const Color _prestadorPrimary = Color(0xFF28B5CD);
  static const Color _accentCoral = Color(0xFFF75A6D);
  static const Color _accentLightBlue = Color(0xFF7AAFFF);
  static const Color _dark = Color(0xFF3D4756);

  final TextEditingController _searchController = TextEditingController();

  // 0 = Home, 1 = Evaluar, 2 = Mensajes, 3 = Perfil (menú flotante)
  int _currentIndex = 0;

  // true = modo Prestador, false = modo Cliente
  bool _modoPrestador = false;
  bool _puedeSerAmbos = false;

  Color get primaryColor => _modoPrestador ? _prestadorPrimary : _clientePrimary;

  @override
  void initState() {
    super.initState();
    _detectarRol();
  }

  void _detectarRol() {
    final data = UserSession().datosCompletos;
    final esPrestador = data?['es_trabajador'] == true;
    setState(() {
      _puedeSerAmbos = esPrestador; // si es prestador puede elegir ambos modos
      _modoPrestador = esPrestador; // por defecto arranca en el rol que tiene
    });
  }

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
    if (_currentIndex == 3 && index != 3) {
      setState(() => _currentIndex = 0);
    }

    if (index == 0) {
      setState(() => _currentIndex = 0);
      return;
    }

    if (index == 1) {
      setState(() => _currentIndex = 0);
      Navigator.push(context, MaterialPageRoute(builder: (_) => const MenuEvaluacionesWidget()));
      return;
    }

    if (index == 2) {
      setState(() => _currentIndex = 0);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Mensajes próximamente')),
      );
      return;
    }

    if (index == 3) {
      setState(() => _currentIndex = 3);
    }
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
            Text(
              'Hola $nombreMostrar',
              style: const TextStyle(
                color: Colors.black,
                fontSize: 20,
                fontWeight: FontWeight.bold,
              ),
            ),
            Text(
              _modoPrestador ? '¿Qué vas a ofrecer hoy?' : '¿Qué servicio necesitás?',
              style: const TextStyle(color: Colors.grey, fontSize: 14),
            ),
          ],
        ),
        actions: [
          if (_puedeSerAmbos)
            Padding(
              padding: const EdgeInsets.only(right: 8),
              child: GestureDetector(
                onTap: () {
                  setState(() => _modoPrestador = !_modoPrestador);
                },
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: primaryColor.withOpacity(0.12),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: primaryColor.withOpacity(0.3)),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        _modoPrestador ? Icons.engineering : Icons.person_search,
                        size: 16,
                        color: primaryColor,
                      ),
                      const SizedBox(width: 6),
                      Text(
                        _modoPrestador ? 'Prestador' : 'Cliente',
                        style: TextStyle(
                          color: primaryColor,
                          fontWeight: FontWeight.w600,
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
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
      body: AnimatedSwitcher(
        duration: const Duration(milliseconds: 280),
        transitionBuilder: (child, animation) {
          final offsetAnimation = Tween<Offset>(
            begin: const Offset(0, 1),
            end: Offset.zero,
          ).animate(CurvedAnimation(parent: animation, curve: Curves.easeOutCubic));
          return SlideTransition(position: offsetAnimation, child: child);
        },
        child: _currentIndex == 3
            ? MenuPerfilOpcionesWidget(
                key: const ValueKey('perfil'),
                onClose: () => setState(() => _currentIndex = 0),
              )
            : (_modoPrestador
                ? _buildPrestadorBody(key: const ValueKey('prestador'))
                : _buildClienteBody(key: const ValueKey('cliente'))),
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

  // ===================== VISTA CLIENTE =====================
  Widget _buildClienteBody({Key? key}) {
    return SingleChildScrollView(
      key: key,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Search
          Padding(
            padding: const EdgeInsets.all(16),
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
                contentPadding: const EdgeInsets.symmetric(vertical: 14),
              ),
              onSubmitted: (value) => _irABuscador(value),
            ),
          ),

          // Categorías de servicios (estilo del modelo de iconos)
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 16),
            child: Text(
              'Servicios',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            ),
          ),
          const SizedBox(height: 12),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            child: GridView.count(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              crossAxisCount: 4,
              mainAxisSpacing: 12,
              crossAxisSpacing: 8,
              childAspectRatio: 0.82,
              children: [
                _buildCategoryIcon(Icons.cleaning_services_outlined, 'Limpieza', _clientePrimary),
                _buildCategoryIcon(Icons.restaurant_outlined, 'Cocina', _accentCoral),
                _buildCategoryIcon(Icons.bathtub_outlined, 'Baño', _accentLightBlue),
                _buildCategoryIcon(Icons.person_outline, 'Doméstica', _prestadorPrimary),
                _buildCategoryIcon(Icons.handyman_outlined, 'Carpintería', _dark),
                _buildCategoryIcon(Icons.plumbing, 'Plomería', _clientePrimary),
                _buildCategoryIcon(Icons.build_outlined, 'Reparaciones', _accentCoral),
                _buildCategoryIcon(Icons.yard_outlined, 'Jardinería', _prestadorPrimary),
              ],
            ),
          ),

          const SizedBox(height: 28),

          // Acciones rápidas cliente
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 16),
            child: Text(
              'Acciones rápidas',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
          ),
          const SizedBox(height: 12),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            child: Row(
              children: [
                Expanded(
                  child: _buildQuickAction(
                    icon: Icons.search,
                    label: 'Buscar\nprestadores',
                    onTap: () => _irABuscador(),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: _buildQuickAction(
                    icon: Icons.check_circle_outline,
                    label: 'Evaluar\ntrabajos',
                    onTap: () {
                      Navigator.push(context, MaterialPageRoute(builder: (_) => const MenuEvaluacionesWidget()));
                    },
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 28),

          // Últimos mensajes (placeholder)
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 16),
            child: Text(
              'Últimos mensajes',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
          ),
          const SizedBox(height: 12),
          _buildProviderCard(
            'Electricista',
            'Nuestro electricista completó el trabajo en tiempo récord.',
            'Hace 2h',
            _clientePrimary,
          ),
          _buildProviderCard(
            'Plomería',
            'Se reparó la pérdida de agua en la cocina.',
            'Ayer',
            _prestadorPrimary,
          ),
          const SizedBox(height: 24),
        ],
      ),
    );
  }

  // ===================== VISTA PRESTADOR =====================
  Widget _buildPrestadorBody({Key? key}) {
    return SingleChildScrollView(
      key: key,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Banner Instagram
          GestureDetector(
            onTap: _irAGuiaInstagram,
            child: Container(
              margin: const EdgeInsets.fromLTRB(16, 16, 16, 8),
              height: 120,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(16),
                gradient: LinearGradient(
                  colors: [
                    _prestadorPrimary.withOpacity(0.9),
                    _clientePrimary.withOpacity(0.85),
                  ],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
              ),
              child: const Padding(
                padding: EdgeInsets.all(18),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      '¿Sabés cómo comunicar tus trabajos en Instagram?',
                      style: TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                        height: 1.3,
                      ),
                    ),
                    SizedBox(height: 6),
                    Text(
                      'Tocá aquí para ver el mini-manual',
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

          const SizedBox(height: 16),

          // Acciones principales prestador
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 16),
            child: Text(
              'Tu negocio',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            ),
          ),
          const SizedBox(height: 12),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            child: GridView.count(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              crossAxisCount: 2,
              mainAxisSpacing: 12,
              crossAxisSpacing: 12,
              childAspectRatio: 1.45,
              children: [
                _buildPrestadorCard(
                  icon: Icons.badge_outlined,
                  title: 'Compartir tarjeta',
                  subtitle: 'Tu perfil profesional',
                  color: _prestadorPrimary,
                  onTap: _compartirTarjeta,
                ),
                _buildPrestadorCard(
                  icon: Icons.work_outline,
                  title: 'Especialidades',
                  subtitle: 'Oficios y zonas',
                  color: _clientePrimary,
                  onTap: () {
                    Navigator.push(context, MaterialPageRoute(builder: (_) => const RegistroTrabajadorWidget()));
                  },
                ),
                _buildPrestadorCard(
                  icon: Icons.star_outline,
                  title: 'Evaluaciones',
                  subtitle: 'Lo que dicen de vos',
                  color: _accentCoral,
                  onTap: () {
                    Navigator.push(context, MaterialPageRoute(builder: (_) => const MenuEvaluacionesWidget()));
                  },
                ),
                _buildPrestadorCard(
                  icon: Icons.person_outline,
                  title: 'Mi perfil',
                  subtitle: 'Datos y validaciones',
                  color: _dark,
                  onTap: () {
                    Navigator.push(context, MaterialPageRoute(builder: (_) => const MenuPerfilWidget()));
                  },
                ),
              ],
            ),
          ),

          const SizedBox(height: 28),

          // Tips rápidos
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 16),
            child: Text(
              'Consejos para crecer',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
          ),
          const SizedBox(height: 12),
          _buildTipCard(
            'Completá tu zona de cobertura',
            'Cuantas más localidades tengas, más te van a encontrar.',
            Icons.location_on_outlined,
          ),
          _buildTipCard(
            'Pedí validaciones de domicilio',
            'Las referencias aumentan la confianza de los clientes.',
            Icons.verified_user_outlined,
          ),
          const SizedBox(height: 24),
        ],
      ),
    );
  }

  // ===================== WIDGETS AUXILIARES =====================

  Widget _buildCategoryIcon(IconData icon, String label, Color accent) {
    return InkWell(
      onTap: () => _irABuscador(label),
      borderRadius: BorderRadius.circular(16),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 64,
            height: 64,
            decoration: BoxDecoration(
              color: const Color(0xFFF0F7FF),
              borderRadius: BorderRadius.circular(16),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.04),
                  blurRadius: 8,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Icon(icon, size: 30, color: accent),
          ),
          const SizedBox(height: 8),
          Text(
            label,
            style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w500),
            textAlign: TextAlign.center,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }

  Widget _buildQuickAction({
    required IconData icon,
    required String label,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 12),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 10),
          ],
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: primaryColor.withOpacity(0.12),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(icon, color: primaryColor, size: 24),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                label,
                style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13, height: 1.25),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPrestadorCard({
    required IconData icon,
    required String title,
    required String subtitle,
    required Color color,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 10),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: color.withOpacity(0.12),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(icon, color: color, size: 26),
            ),
            const SizedBox(height: 12),
            Text(
              title,
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
            ),
            const SizedBox(height: 2),
            Text(
              subtitle,
              style: TextStyle(color: Colors.grey.shade600, fontSize: 12),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTipCard(String title, String body, IconData icon) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        boxShadow: [
          BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 8),
        ],
      ),
      child: Row(
        children: [
          Icon(icon, color: primaryColor, size: 28),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
                const SizedBox(height: 2),
                Text(body, style: TextStyle(color: Colors.grey.shade600, fontSize: 12)),
              ],
            ),
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
          Text(time, style: const TextStyle(color: Colors.grey, fontSize: 12)),
        ],
      ),
    );
  }
}
