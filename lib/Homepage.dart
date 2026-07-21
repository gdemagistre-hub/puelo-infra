import 'package:flutter/material.dart';
import 'user_session.dart';
import 'loginScreen.dart';
import 'buscadorPrestadores.dart';
import 'completar_perfil.dart';
import 'menuEvaluaciones.dart';

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
              const SizedBox(height: 40),
              
              // Botón 1: Buscar servicios
              _buildMainButton(
                context,
                texto: 'Buscar servicios',
                icono: Icons.search_rounded,
                onTap: () => Navigator.push(
                  context,
                  MaterialPageRoute(builder: (context) => const BuscadorPrestadoresWidget()),
                ),
              ),
              const SizedBox(height: 16),

              // Botón 2: Evaluar trabajos
              _buildMainButton(
                context,
                texto: 'Evaluar trabajos',
                icono: Icons.check_circle_outline_rounded,
                onTap: () => Navigator.push(
                  context,
                  MaterialPageRoute(builder: (context) => const MenuEvaluacionesWidget()),
                ),
              ),
              const SizedBox(height: 16),

              // Botón 3: Sobre mí
              _buildMainButton(
                context,
                texto: 'Sobre mí',
                icono: Icons.person_outline_rounded,
                onTap: () => Navigator.push(
                  context,
                  MaterialPageRoute(builder: (context) => const CompletarPerfilWidget()),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // Widget auxiliar para mantener un diseño limpio y uniforme en los botones
  Widget _buildMainButton(BuildContext context, {required String texto, required IconData icono, required VoidCallback onTap}) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 24, horizontal: 20),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: Colors.grey.shade200),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.03),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Column(
          children: [
            Icon(icono, size: 48, color: primaryColor),
            const SizedBox(height: 12),
            Text(
              texto,
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: textColor,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
