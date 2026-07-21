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

  @override
  Widget build(BuildContext context) {
    final String nombreMostrar = UserSession().nombreCompleto.isNotEmpty 
        ? UserSession().nombreCompleto 
        : 'Invitado';

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        title: const Text('Panel Principal'),
        backgroundColor: primaryColor,
        foregroundColor: Colors.white,
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.logout_rounded),
            tooltip: 'Cerrar sesión',
            onPressed: _cerrarSesion,
          ),
        ],
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                'Bienvenido, $nombreMostrar',
                style: TextStyle(
                  fontSize: 24, 
                  fontWeight: FontWeight.w800, 
                  color: textColor,
                ),
              ),
              const SizedBox(height: 8),
              const Text(
                '¿Qué te gustaría hacer hoy?',
                style: TextStyle(
                  fontSize: 16, 
                  color: Color(0xFF64748B),
                ),
              ),
              const SizedBox(height: 32),
              
              // Grilla de botones estilo "Tarjeta"
              GridView.count(
                crossAxisCount: 2,
                crossAxisSpacing: 16,
                mainAxisSpacing: 16,
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                childAspectRatio: 0.85, // Ajusta la proporción vertical de las tarjetas
                children: [
                  // Tarjeta 1: Buscar servicios
                  _buildGridCard(
                    context,
                    titulo: 'Buscar\nservicios',
                    subtitulo: 'Encontrá profesionales',
                    icono: Icons.search_rounded,
                    colorIcono: const Color(0xFFF59E0B), // Naranja
                    onTap: () => Navigator.push(
                      context,
                      MaterialPageRoute(builder: (context) => const BuscadorPrestadoresWidget()),
                    ),
                  ),

                  // Tarjeta 2: Evaluar trabajos
                  _buildGridCard(
                    context,
                    titulo: 'Evaluar\ntrabajos',
                    subtitulo: 'Gestioná tus reseñas',
                    icono: Icons.check_circle_outline_rounded,
                    colorIcono: const Color(0xFF10B981), // Verde
                    onTap: () => Navigator.push(
                      context,
                      MaterialPageRoute(builder: (context) => const MenuEvaluacionesWidget()),
                    ),
                  ),

                  // Tarjeta 3: Compartir Tarjeta
                  _buildGridCard(
                    context,
                    titulo: 'Compartir\ntarjeta',
                    subtitulo: 'Enviá tu perfil web',
                    icono: Icons.badge_rounded,
                    colorIcono: const Color(0xFF8B5CF6), // Púrpura
                    onTap: () async {
                      final String? userId = UserSession().uid;
                      
                      if (userId != null && userId.isNotEmpty) {
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
                                  const SnackBar(
                                    content: Text('Para compartir tu tarjeta, primero configurá tus especialidades y zonas.'),
                                    duration: Duration(seconds: 4),
                                  ),
                                );
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(builder: (context) => const RegistroTrabajadorWidget()),
                                );
                              }
                            } else {
                              if (context.mounted) {
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (context) => TarjetaDigitalWidget(
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
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(content: Text('Error al validar tu perfil: $e')),
                            );
                          }
                        }
                      } else {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('Error: No se encontró la sesión activa.')),
                        );
                      }
                    },
                  ),

                  // Tarjeta 4: Sobre mí
                  _buildGridCard(
                    context,
                    titulo: 'Sobre\nmí',
                    subtitulo: 'Configurá tu cuenta',
                    icono: Icons.person_outline_rounded,
                    colorIcono: const Color(0xFF3B82F6), // Azul claro
                    onTap: () => Navigator.push(
                      context,
                      MaterialPageRoute(builder: (context) => const MenuPerfilWidget()),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  // Constructor de las tarjetas asimétricas
  Widget _buildGridCard(BuildContext context, {
    required String titulo, 
    required String subtitulo, 
    required IconData icono, 
    required Color colorIcono,
    required VoidCallback onTap
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: const BorderRadius.only(
        topLeft: Radius.circular(16),
        bottomLeft: Radius.circular(16),
        bottomRight: Radius.circular(16),
        topRight: Radius.circular(40), // La esquina distintiva del diseño
      ),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: const BorderRadius.only(
            topLeft: Radius.circular(16),
            bottomLeft: Radius.circular(16),
            bottomRight: Radius.circular(16),
            topRight: Radius.circular(40),
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.04),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: colorIcono.withOpacity(0.12),
                shape: BoxShape.circle,
              ),
              child: Icon(icono, size: 28, color: colorIcono),
            ),
            const Spacer(),
            Text(
              titulo,
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w800,
                color: textColor,
                height: 1.1,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              subtitulo,
              style: const TextStyle(
                fontSize: 12,
                color: Color(0xFF94A3B8),
                fontWeight: FontWeight.w500,
              ),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
      ),
    );
  }
}
