import 'package:flutter/material.dart';
import 'registroTrabajador.dart';
import 'buscadorPrestadores.dart';
import 'seleccionRol.dart'; 
import 'completar_perfil.dart'; // Importamos la nueva pantalla de scoring

class HomePageWidget extends StatefulWidget {
  const HomePageWidget({super.key});

  static const String routeName = 'HomePage';
  static const String routePath = '/homePage';

  @override
  State<HomePageWidget> createState() => _HomePageWidgetState();
}

class _HomePageWidgetState extends State<HomePageWidget> {
  final scaffoldKey = GlobalKey<ScaffoldState>();

  @override
  Widget build(BuildContext context) {
    final primaryColor = const Color(0xFF0F52BA); 
    final textColor = const Color(0xFF1E293B);    
    final subtitleColor = const Color(0xFF64748B); 

    return GestureDetector(
      onTap: () => FocusScope.of(context).unfocus(),
      child: Scaffold(
        key: scaffoldKey,
        backgroundColor: const Color(0xFFF8FAFC), 
        body: SafeArea(
          top: true,
          child: Center(
            child: SingleChildScrollView(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 28.0, vertical: 24.0),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Cabecera de Marca (Branding)
                    Icon(
                      Icons.wallet_giftcard_rounded,
                      size: 72,
                      color: primaryColor,
                    ),
                    const SizedBox(height: 16.0),
                    Text(
                      'Puelo',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 32,
                        fontWeight: FontWeight.w800,
                        color: primaryColor,
                        letterSpacing: -0.5,
                      ),
                    ),
                    Text(
                      'Life Wallet',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w500,
                        color: subtitleColor,
                        letterSpacing: 1.5,
                      ),
                    ),
                    const SizedBox(height: 32.0),

                    // Botón Destacado: Enriquecer Perfil (Scoring)
                    ElevatedButton.icon(
                      onPressed: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => const CompletarPerfilWidget(),
                          ),
                        );
                      },
                      icon: const Icon(Icons.verified_user_outlined, color: Colors.white),
                      label: const Text(
                        'Enriquecer mi perfil (Scoring)',
                        style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16),
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: primaryColor,
                        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                        elevation: 4,
                        shadowColor: primaryColor.withOpacity(0.4),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                      ),
                    ),
                    
                    const SizedBox(height: 32.0),

                    // Tarjeta/Botón 1: Registrarme como Trabajador
                    _buildFeatureCard(
                      context,
                      title: 'Registrarme como Trabajador',
                      description: 'Formá parte de nuestra red de prestadores confiables y gestioná tus servicios.',
                      icon: Icons.badge_outlined,
                      color: primaryColor,
                      textColor: Colors.white,
                      backgroundColor: primaryColor,
                      onPressed: () {
                        Navigator.pushNamed(context, RegistroTrabajadorWidget.routePath);
                      },
                    ),

                    const SizedBox(height: 20.0),

                    // Tarjeta/Botón 2: Buscar Servicios
                    _buildFeatureCard(
                      context,
                      title: 'Buscar Servicios',
                      description: 'Encontrá prestadores validados en tu comunidad de manera rápida y segura.',
                      icon: Icons.search_rounded,
                      color: primaryColor,
                      textColor: textColor,
                      backgroundColor: Colors.white,
                      onPressed: () {
                        Navigator.pushNamed(context, BuscadorPrestadoresWidget.routePath);
                      },
                      hasBorder: true,
                    ),

                    const SizedBox(height: 20.0),

                    // Tarjeta/Botón 3: Cargar Trabajos (Nueva Arista)
                    _buildFeatureCard(
                      context,
                      title: 'Cargar trabajos',
                      description: 'Documentá tus obras o servicios completados asociando fotos a un prestador.',
                      icon: Icons.work_history_outlined,
                      color: primaryColor,
                      textColor: textColor,
                      backgroundColor: Colors.white,
                      onPressed: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(builder: (context) => const SeleccionRolWidget()),
                        );
                      },
                      hasBorder: true,
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildFeatureCard(
    BuildContext context, {
    required String title,
    required String description,
    required IconData icon,
    required Color color,
    required Color textColor,
    required Color backgroundColor,
    required VoidCallback onPressed,
    bool hasBorder = false,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: backgroundColor,
        borderRadius: BorderRadius.circular(16.0),
        border: hasBorder ? Border.all(color: const Color(0xFFE2E8F0), width: 1.5) : null,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onPressed,
          borderRadius: BorderRadius.circular(16.0),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 24.0),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(12.0),
                  decoration: BoxDecoration(
                    color: backgroundColor == Colors.white 
                        ? color.withOpacity(0.1) 
                        : Colors.white.withOpacity(0.2),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    icon,
                    size: 28,
                    color: backgroundColor == Colors.white ? color : Colors.white,
                  ),
                ),
                const SizedBox(width: 20.0),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: textColor,
                        ),
                      ),
                      const SizedBox(height: 4.0),
                      Text(
                        description,
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.normal,
                          color: backgroundColor == Colors.white 
                              ? const Color(0xFF64748B) 
                              : Colors.white.withOpacity(0.85),
                          height: 1.3,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
