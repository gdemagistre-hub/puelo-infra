import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'homePage.dart'; // Asegurate de que el import coincida con el nombre real de tu archivo de Home

class LoginScreenWidget extends StatelessWidget {
  const LoginScreenWidget({super.key});

  static const String routeName = 'LoginScreen';
  static const String routePath = '/login';

  @override
  Widget build(BuildContext context) {
    // Colores de la paleta premium Puelo
    final primaryColor = const Color(0xFF0F52BA);
    final textColor = const Color(0xFF1E293B);
    final subTextColor = const Color(0xFF64748B);

    // Función rápida para saltar a la Home
    void irAHome() {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (context) => const HomePageWidget()), // Ajustar si tu clase se llama distinto
      );
    }

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 28.0, vertical: 24.0),
            child: Container(
              constraints: const BoxConstraints(maxWidth: 420),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // Isotipo o Logo de la App
                  Center(
                    child: Container(
                      height: 80,
                      width: 80,
                      decoration: BoxDecoration(
                        color: primaryColor,
                        borderRadius: BorderRadius.circular(20),
                        boxShadow: [
                          BoxShadow(
                            color: primaryColor.withOpacity(0.2),
                            blurRadius: 15,
                            offset: const Offset(0, 8),
                          ),
                        ],
                      ),
                      child: const Icon(
                        Icons.wallet_rounded,
                        color: Colors.white,
                        size: 42,
                      ),
                    ),
                  ),
                  const SizedBox(height: 24),
                  
                  // Textos de Bienvenida
                  Text(
                    'Te damos la bienvenida',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 26,
                      fontWeight: FontWeight.w800,
                      color: textColor,
                      letterSpacing: -0.5,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Ingresá para gestionar tus prestadores y servicios en un solo lugar.',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 15,
                      color: subTextColor,
                      height: 1.4,
                    ),
                  ),
                  const SizedBox(height: 36),

                  // Botón: Continuar con Google
                  _buildLoginButton(
                    onPressed: irAHome,
                    icon: const FaIcon(FontAwesomeIcons.google, color: Color(0xFFDB4437), size: 18),
                    label: 'Continuar con Google',
                    backgroundColor: Colors.white,
                    textColor: textColor,
                    hasBorder: true,
                  ),
                  const SizedBox(height: 14),

                  // Botón: Continuar con Apple
                  _buildLoginButton(
                    onPressed: irAHome,
                    icon: const FaIcon(FontAwesomeIcons.apple, color: Colors.black, size: 20),
                    label: 'Continuar con Apple',
                    backgroundColor: Colors.black,
                    textColor: Colors.white,
                  ),
                  const SizedBox(height: 14),

                  // Botón: Continuar con Facebook
                  _buildLoginButton(
                    onPressed: irAHome,
                    icon: const FaIcon(FontAwesomeIcons.facebook, color: Colors.white, size: 20),
                    label: 'Continuar con Facebook',
                    backgroundColor: const Color(0xFF1877F2),
                    textColor: Colors.white,
                  ),
                  const SizedBox(height: 20),

                  // Divisor estético para separar las redes del correo tradicional
                  Row(
                    children: [
                      Expanded(child: Divider(color: Colors.grey[300], thickness: 1)),
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 12.0),
                        child: Text('o con tu cuenta', style: TextStyle(color: subTextColor, fontSize: 13)),
                      ),
                      Expanded(child: Divider(color: Colors.grey[300], thickness: 1)),
                    ],
                  ),
                  const SizedBox(height: 20),

                  // Botón: Ingresar con Email
                  _buildLoginButton(
                    onPressed: irAHome,
                    icon: Icon(Icons.mail_outline_rounded, color: primaryColor, size: 20),
                    label: 'Ingresar con Email',
                    backgroundColor: Colors.white,
                    textColor: primaryColor,
                    hasBorder: true,
                    borderColor: primaryColor.withOpacity(0.4),
                  ),
                  const SizedBox(height: 32),

                  // Enlace inferior: Registrar nuevo usuario
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        '¿Sos nuevo en Puelo? ',
                        style: TextStyle(color: subTextColor, fontSize: 14),
                      ),
                      GestureDetector(
                        onTap: irAHome,
                        child: Text(
                          'Crear usuario',
                          style: TextStyle(
                            color: primaryColor,
                            fontWeight: FontWeight.bold,
                            fontSize: 14,
                            decoration: TextDecoration.underline,
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  // Helper para construir botones estilizados de manera idéntica y limpia
  Widget _buildLoginButton({
    required VoidCallback onPressed,
    required Widget icon,
    required String label,
    required Color backgroundColor,
    required Color textColor,
    bool hasBorder = false,
    Color? borderColor,
  }) {
    return ElevatedButton(
      onPressed: onPressed,
      style: ElevatedButton.styleFrom(
        backgroundColor: backgroundColor,
        foregroundColor: textColor,
        elevation: backgroundColor == Colors.white ? 1 : 0,
        padding: const EdgeInsets.symmetric(vertical: 15),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: hasBorder 
              ? BorderSide(color: borderColor ?? const Color(0xFFE2E8F0), width: 1.5)
              : BorderSide.none,
        ),
      ),
      child: Stack(
        children: [
          Align(
            alignment: Alignment.centerLeft,
            child: Padding(
              padding: const EdgeInsets.only(left: 20.0),
              child: icon,
            ),
          ),
          Align(
            alignment: Alignment.center,
            child: Text(
              label,
              style: const TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w600,
                letterSpacing: 0.2,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
