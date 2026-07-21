import 'package:flutter/material.dart';
import 'user_session.dart';
import 'loginScreen.dart';
import 'seleccionRol.dart';

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
    // Si el nombre está vacío, mostramos un texto por defecto.
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
        child: Padding(
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
              
              ElevatedButton.icon(
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (context) => const SeleccionRolWidget()),
                  );
                },
                icon: const Icon(Icons.add_a_photo_rounded),
                label: const Text('Cargar nuevos trabajos'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: primaryColor,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
