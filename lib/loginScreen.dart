import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'Homepage.dart';
import 'user_session.dart';
import 'registroCuenta.dart';
import 'pantalla_gracias_validacion.dart';

class LoginScreenWidget extends StatefulWidget {
  const LoginScreenWidget({super.key});

  static const String routeName = 'LoginScreen';
  static const String routePath = '/login';

  @override
  State<LoginScreenWidget> createState() => _LoginScreenWidgetState();
}

class _LoginScreenWidgetState extends State<LoginScreenWidget> {
  String? _selectedUserId;
  Map<String, dynamic>? _selectedUserData;

  final primaryColor = const Color(0xFF0F52BA);
  final textColor = const Color(0xFF1E293B);
  final subTextColor = const Color(0xFF64748B);

  void _irAHome() {
    if (_selectedUserId == null || _selectedUserData == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Por favor, seleccioná un usuario del listado superior para simular el ingreso.')),
      );
      return;
    }

    // Guardamos los datos en la memoria persistente
    UserSession().iniciarSesion(_selectedUserId!, _selectedUserData!);

    // Si venimos de una validación de domicilio pendiente → mostrar pantalla de gracias
    if (UserSession().pendingValidacionToken != null) {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (context) => const PantallaGraciasValidacionWidget()),
      );
    } else {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (context) => const HomePageWidget()),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
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
                  // PULL-DOWN TEMPORAL PARA SIMULAR LOGIN
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: primaryColor.withOpacity(0.3)),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Modo Desarrollador: Elegir Usuario', style: TextStyle(color: primaryColor, fontWeight: FontWeight.bold, fontSize: 12)),
                        const SizedBox(height: 8),
                        StreamBuilder<QuerySnapshot>(
                          stream: FirebaseFirestore.instance.collection('usuarios').snapshots(),
                          builder: (context, snapshot) {
                            if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());
                            
                            var items = snapshot.data!.docs;
                            return DropdownButtonFormField<String>(
                              decoration: const InputDecoration(
                                border: OutlineInputBorder(),
                                contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                              ),
                              hint: const Text('Seleccionar...'),
                              value: _selectedUserId,
                              items: items.map((doc) {
                                Map<String, dynamic> data = doc.data() as Map<String, dynamic>;
                                String displayName = '${data['nombre'] ?? ''} ${data['apellido'] ?? ''}'.trim();
                                return DropdownMenuItem<String>(
                                  value: doc.id,
                                  child: Text(displayName.isNotEmpty ? displayName : 'Sin nombre'),
                                );
                              }).toList(),
                              onChanged: (val) {
                                setState(() {
                                  _selectedUserId = val;
                                  _selectedUserData = items.firstWhere((doc) => doc.id == val).data() as Map<String, dynamic>;
                                });
                              },
                            );
                          },
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 40),

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
                      child: const Icon(Icons.wallet_rounded, color: Colors.white, size: 42),
                    ),
                  ),
                  const SizedBox(height: 24),
                  
                  Text('Te damos la bienvenida', textAlign: TextAlign.center, style: TextStyle(fontSize: 26, fontWeight: FontWeight.w800, color: textColor, letterSpacing: -0.5)),
                  const SizedBox(height: 8),
                  Text('Ingresá para gestionar tus prestadores y servicios en un solo lugar.', textAlign: TextAlign.center, style: TextStyle(fontSize: 15, color: subTextColor, height: 1.4)),
                  const SizedBox(height: 36),

                  _buildLoginButton(
                    onPressed: _irAHome,
                    icon: _buildIconCircle(backgroundColor: const Color(0xFFF1F5F9), child: const Text('G', style: TextStyle(color: Color(0xFFDB4437), fontWeight: FontWeight.w900, fontSize: 16))),
                    label: 'Continuar con Google', backgroundColor: Colors.white, textColor: textColor, hasBorder: true,
                  ),
                  const SizedBox(height: 14),

                  _buildLoginButton(
                    onPressed: _irAHome,
                    icon: _buildIconCircle(backgroundColor: Colors.white.withOpacity(0.15), child: const Icon(Icons.apple, color: Colors.white, size: 18)),
                    label: 'Continuar con Apple', backgroundColor: Colors.black, textColor: Colors.white,
                  ),
                  const SizedBox(height: 14),

                  _buildLoginButton(
                    onPressed: _irAHome,
                    icon: _buildIconCircle(backgroundColor: Colors.white.withOpacity(0.2), child: const Text('f', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 18))),
                    label: 'Continuar con Facebook', backgroundColor: const Color(0xFF1877F2), textColor: Colors.white,
                  ),
                  const SizedBox(height: 20),

                  // Divisor estético
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

                  _buildLoginButton(
                    onPressed: _irAHome,
                    icon: _buildIconCircle(
                      backgroundColor: primaryColor.withOpacity(0.1),
                      child: Icon(Icons.mail_outline_rounded, color: primaryColor, size: 16),
                    ),
                    label: 'Ingresar con Email',
                    backgroundColor: Colors.white,
                    textColor: primaryColor,
                    hasBorder: true,
                    borderColor: primaryColor.withOpacity(0.4),
                  ),
                  const SizedBox(height: 32),

                  // Enlace inferior: Registrar nuevo usuario redirigiendo a la pantalla correspondiente
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        '¿Sos nuevo en Puelo? ',
                        style: TextStyle(color: subTextColor, fontSize: 14),
                      ),
                      GestureDetector(
                        onTap: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(builder: (context) => const RegistroCuentaWidget()),
                          );
                        },
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

  Widget _buildIconCircle({required Color backgroundColor, required Widget child}) {
    return Container(width: 28, height: 28, decoration: BoxDecoration(color: backgroundColor, shape: BoxShape.circle), alignment: Alignment.center, child: child);
  }

  Widget _buildLoginButton({required VoidCallback onPressed, required Widget icon, required String label, required Color backgroundColor, required Color textColor, bool hasBorder = false, Color? borderColor}) {
    return ElevatedButton(
      onPressed: onPressed,
      style: ElevatedButton.styleFrom(backgroundColor: backgroundColor, foregroundColor: textColor, elevation: backgroundColor == Colors.white ? 1 : 0, padding: const EdgeInsets.symmetric(vertical: 15), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16), side: hasBorder ? BorderSide(color: borderColor ?? const Color(0xFFE2E8F0), width: 1.5) : BorderSide.none)),
      child: Stack(
        children: [
          Align(alignment: Alignment.centerLeft, child: Padding(padding: const EdgeInsets.only(left: 16.0), child: icon)),
          Align(alignment: Alignment.center, child: Text(label, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600, letterSpacing: 0.2))),
        ],
      ),
    );
  }
}
