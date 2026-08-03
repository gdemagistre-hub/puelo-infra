import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

import 'Homepage.dart';
import 'user_session.dart';
import 'auth_service.dart';
import 'registroCuenta.dart';
import 'pantalla_gracias_validacion.dart';
import 'theme/app_colors.dart';
import 'theme/app_copy.dart';
import 'analytics/prox_analytics.dart';

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
  bool _loadingGoogle = false;
  bool _loadingDev = false;

  static const Color primaryColor = AppColors.cliente;
  static const Color textColor = AppColors.text;
  static const Color subTextColor = AppColors.textMuted;

  Future<void> _entrarDevDropdown() async {
    if (_selectedUserId == null || _selectedUserData == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Seleccioná un usuario del listado para entrar en modo prueba.',
          ),
        ),
      );
      return;
    }

    setState(() => _loadingDev = true);
    try {
      UserSession().iniciarSesion(
        _selectedUserId!,
        _selectedUserData!,
        authProvider: 'dev',
        isDevImpersonation: true,
      );

      final esPrestador = _selectedUserData!['es_trabajador'] == true ||
          _selectedUserData!['rol'] == 'trabajador';
      ProxAnalytics.instance.startSession(
        role: esPrestador ? 'prestador' : 'cliente',
      );
      ProxAnalytics.instance.action('login_dev_dropdown', screen: '/login');

      if (!mounted) return;
      _navegarPostLogin();
    } finally {
      if (mounted) setState(() => _loadingDev = false);
    }
  }

  Future<void> _entrarConGoogle() async {
    setState(() => _loadingGoogle = true);
    try {
      await AuthService.instance.signInWithGoogle();
      if (!mounted) return;
      _navegarPostLogin();
    } on AuthCancelledException {
      // Usuario cerró el popup: no mostrar error.
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'No se pudo iniciar con Google. '
            'Verificá que el proveedor esté habilitado en Firebase. ($e)',
          ),
          duration: const Duration(seconds: 6),
        ),
      );
    } finally {
      if (mounted) setState(() => _loadingGoogle = false);
    }
  }

  void _proximamente(String provider) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          '$provider se habilita en la siguiente etapa (mismo flujo que Google).',
        ),
      ),
    );
  }

  void _navegarPostLogin() {
    if (UserSession().pendingValidacionToken != null) {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (context) => const PantallaGraciasValidacionWidget(),
        ),
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
    final busy = _loadingGoogle || _loadingDev;

    return Scaffold(
      backgroundColor: AppColors.bg,
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding:
                const EdgeInsets.symmetric(horizontal: 28.0, vertical: 24.0),
            child: Container(
              constraints: const BoxConstraints(maxWidth: 420),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // MUST: listado de prueba hasta decisión contraria.
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: AppColors.surface,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                        color: primaryColor.withOpacity(0.3),
                      ),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Modo prueba (equipo)',
                          style: TextStyle(
                            color: primaryColor,
                            fontWeight: FontWeight.bold,
                            fontSize: 12,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'Impersoná un usuario de Firestore sin Google. '
                          'Se apaga al abrir el servicio al público.',
                          style: TextStyle(
                            color: Colors.grey.shade600,
                            fontSize: 11,
                            height: 1.3,
                          ),
                        ),
                        const SizedBox(height: 8),
                        StreamBuilder<QuerySnapshot>(
                          stream: FirebaseFirestore.instance
                              .collection('usuarios')
                              .snapshots(),
                          builder: (context, snapshot) {
                            if (!snapshot.hasData) {
                              return const Center(
                                child: CircularProgressIndicator(
                                  color: primaryColor,
                                ),
                              );
                            }

                            final items = snapshot.data!.docs;
                            return DropdownButtonFormField<String>(
                              decoration: const InputDecoration(
                                border: OutlineInputBorder(),
                                contentPadding: EdgeInsets.symmetric(
                                  horizontal: 12,
                                  vertical: 8,
                                ),
                              ),
                              hint: const Text('Seleccionar usuario…'),
                              value: _selectedUserId,
                              items: items.map((doc) {
                                final data =
                                    doc.data() as Map<String, dynamic>;
                                final displayName =
                                    '${data['nombre'] ?? ''} ${data['apellido'] ?? ''}'
                                        .trim();
                                return DropdownMenuItem<String>(
                                  value: doc.id,
                                  child: Text(
                                    displayName.isNotEmpty
                                        ? displayName
                                        : 'Sin nombre',
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                );
                              }).toList(),
                              onChanged: busy
                                  ? null
                                  : (val) {
                                      setState(() {
                                        _selectedUserId = val;
                                        _selectedUserData = items
                                            .firstWhere((doc) => doc.id == val)
                                            .data() as Map<String, dynamic>;
                                      });
                                    },
                            );
                          },
                        ),
                        const SizedBox(height: 12),
                        SizedBox(
                          width: double.infinity,
                          child: OutlinedButton(
                            onPressed: busy ? null : _entrarDevDropdown,
                            style: OutlinedButton.styleFrom(
                              foregroundColor: primaryColor,
                              side: BorderSide(
                                color: primaryColor.withOpacity(0.5),
                              ),
                              padding:
                                  const EdgeInsets.symmetric(vertical: 12),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                            ),
                            child: _loadingDev
                                ? const SizedBox(
                                    height: 18,
                                    width: 18,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                    ),
                                  )
                                : const Text('Entrar como este usuario'),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 32),
                  Center(
                    child: Image.asset(
                      'assets/images/logo_prox_icon.png.png',
                      height: 88,
                      width: 88,
                      fit: BoxFit.contain,
                      errorBuilder: (_, __, ___) => Container(
                        height: 80,
                        width: 80,
                        decoration: BoxDecoration(
                          color: primaryColor,
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: const Icon(
                          Icons.handyman_rounded,
                          color: Colors.white,
                          size: 42,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 24),
                  Text(
                    AppCopy.welcomeTitle,
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      fontSize: 26,
                      fontWeight: FontWeight.w800,
                      color: textColor,
                      letterSpacing: -0.5,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    AppCopy.welcomeSubtitle,
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      fontSize: 15,
                      color: subTextColor,
                      height: 1.4,
                    ),
                  ),
                  const SizedBox(height: 36),
                  _buildLoginButton(
                    onPressed: busy ? null : _entrarConGoogle,
                    icon: _buildIconCircle(
                      backgroundColor: const Color(0xFFF1F5F9),
                      child: const Text(
                        'G',
                        style: TextStyle(
                          color: Color(0xFFDB4437),
                          fontWeight: FontWeight.w900,
                          fontSize: 16,
                        ),
                      ),
                    ),
                    label: _loadingGoogle
                        ? 'Conectando con Google…'
                        : 'Continuar con Google',
                    backgroundColor: Colors.white,
                    textColor: textColor,
                    hasBorder: true,
                    loading: _loadingGoogle,
                  ),
                  const SizedBox(height: 14),
                  _buildLoginButton(
                    onPressed: busy ? null : () => _proximamente('Apple'),
                    icon: _buildIconCircle(
                      backgroundColor: Colors.white.withOpacity(0.15),
                      child: const Icon(
                        Icons.apple,
                        color: Colors.white,
                        size: 18,
                      ),
                    ),
                    label: 'Continuar con Apple',
                    backgroundColor: Colors.black,
                    textColor: Colors.white,
                  ),
                  const SizedBox(height: 14),
                  _buildLoginButton(
                    onPressed: busy ? null : () => _proximamente('Facebook'),
                    icon: _buildIconCircle(
                      backgroundColor: Colors.white.withOpacity(0.2),
                      child: const Text(
                        'f',
                        style: TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                          fontSize: 18,
                        ),
                      ),
                    ),
                    label: 'Continuar con Facebook',
                    backgroundColor: const Color(0xFF1877F2),
                    textColor: Colors.white,
                  ),
                  const SizedBox(height: 20),
                  Row(
                    children: [
                      Expanded(
                        child: Divider(color: Colors.grey[300], thickness: 1),
                      ),
                      const Padding(
                        padding: EdgeInsets.symmetric(horizontal: 12.0),
                        child: Text(
                          'o con tu cuenta',
                          style: TextStyle(color: subTextColor, fontSize: 13),
                        ),
                      ),
                      Expanded(
                        child: Divider(color: Colors.grey[300], thickness: 1),
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),
                  _buildLoginButton(
                    onPressed: busy ? null : () => _proximamente('Email'),
                    icon: _buildIconCircle(
                      backgroundColor: primaryColor.withOpacity(0.1),
                      child: const Icon(
                        Icons.mail_outline_rounded,
                        color: primaryColor,
                        size: 16,
                      ),
                    ),
                    label: 'Ingresar con Email',
                    backgroundColor: Colors.white,
                    textColor: primaryColor,
                    hasBorder: true,
                    borderColor: primaryColor.withOpacity(0.4),
                  ),
                  const SizedBox(height: 32),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Text(
                        '¿Sos nuevo en Puelo? ',
                        style: TextStyle(color: subTextColor, fontSize: 14),
                      ),
                      GestureDetector(
                        onTap: busy
                            ? null
                            : () {
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (context) =>
                                        const RegistroCuentaWidget(),
                                  ),
                                );
                              },
                        child: const Text(
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

  Widget _buildIconCircle({
    required Color backgroundColor,
    required Widget child,
  }) {
    return Container(
      width: 28,
      height: 28,
      decoration: BoxDecoration(
        color: backgroundColor,
        shape: BoxShape.circle,
      ),
      alignment: Alignment.center,
      child: child,
    );
  }

  Widget _buildLoginButton({
    required VoidCallback? onPressed,
    required Widget icon,
    required String label,
    required Color backgroundColor,
    required Color textColor,
    bool hasBorder = false,
    Color? borderColor,
    bool loading = false,
  }) {
    return ElevatedButton(
      onPressed: onPressed,
      style: ElevatedButton.styleFrom(
        backgroundColor: backgroundColor,
        foregroundColor: textColor,
        disabledBackgroundColor: backgroundColor.withOpacity(0.7),
        elevation: backgroundColor == Colors.white ? 1 : 0,
        padding: const EdgeInsets.symmetric(vertical: 15),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: hasBorder
              ? BorderSide(
                  color: borderColor ?? AppColors.border,
                  width: 1.5,
                )
              : BorderSide.none,
        ),
      ),
      child: Stack(
        alignment: Alignment.center,
        children: [
          Align(
            alignment: Alignment.centerLeft,
            child: Padding(
              padding: const EdgeInsets.only(left: 16.0),
              child: loading
                  ? SizedBox(
                      width: 22,
                      height: 22,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: textColor,
                      ),
                    )
                  : icon,
            ),
          ),
          Text(
            label,
            style: const TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w600,
              letterSpacing: 0.2,
            ),
          ),
        ],
      ),
    );
  }
}
