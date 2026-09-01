import 'package:flutter/material.dart';

import 'Homepage.dart';
import 'elige_camino.dart';
import 'elige_pais.dart';
import 'user_session.dart';
import 'auth_service.dart';
import 'registroCuenta.dart';
import 'pantalla_gracias_validacion.dart';
import 'validar_domicilio.dart';
import 'theme/app_colors.dart';
import 'theme/app_copy.dart';
import 'analytics/prox_analytics.dart';
import 'theme/prox_sounds.dart';

class LoginScreenWidget extends StatefulWidget {
  const LoginScreenWidget({super.key});

  static const String routeName = 'LoginScreen';
  static const String routePath = '/login';

  /// Facebook Login oculto en beta (Meta OAuth inestable).
  static const bool showFacebookLogin = false;

  @override
  State<LoginScreenWidget> createState() => _LoginScreenWidgetState();
}

class _LoginScreenWidgetState extends State<LoginScreenWidget> {
  bool _loadingGoogle = false;
  bool _loadingApple = false;
  bool _loadingFacebook = false;
  bool _loadingEmail = false;
  bool _showEmailForm = false;
  bool _obscurePass = true;

  final _emailCtrl = TextEditingController();
  final _passCtrl = TextEditingController();

  static const Color primaryColor = AppColors.cliente;
  static const Color textColor = AppColors.text;
  static const Color subTextColor = AppColors.textMuted;

  void _onFirstGesture() => ProxSounds.playOpenOnce();

  @override
  void dispose() {
    _emailCtrl.dispose();
    _passCtrl.dispose();
    super.dispose();
  }

  Future<void> _entrarConFacebook() async {
    ProxSounds.playOpenOnce();
    setState(() => _loadingFacebook = true);
    try {
      await AuthService.instance.signInWithFacebook();
      if (!mounted) return;
      ProxAnalytics.instance.action('login_facebook', screen: '/login');
      await _navegarPostLogin();
    } on AuthCancelledException {
    } on AuthValidationException catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(e.message),
          behavior: SnackBarBehavior.floating,
          duration: const Duration(seconds: 6),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'No se pudo iniciar con Facebook. '
            '${AuthService.humanizeAuthError(e)}',
          ),
          behavior: SnackBarBehavior.floating,
          duration: const Duration(seconds: 6),
        ),
      );
    } finally {
      if (mounted) setState(() => _loadingFacebook = false);
    }
  }

  Future<void> _entrarConApple() async {
    ProxSounds.playOpenOnce();
    setState(() => _loadingApple = true);
    try {
      await AuthService.instance.signInWithApple();
      if (!mounted) return;
      ProxAnalytics.instance.action('login_apple', screen: '/login');
      await _navegarPostLogin();
    } on AuthCancelledException {
    } on AuthValidationException catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(e.message),
          behavior: SnackBarBehavior.floating,
          duration: const Duration(seconds: 6),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'No se pudo iniciar con Apple. '
            '${AuthService.humanizeAuthError(e)}',
          ),
          behavior: SnackBarBehavior.floating,
          duration: const Duration(seconds: 6),
        ),
      );
    } finally {
      if (mounted) setState(() => _loadingApple = false);
    }
  }

  Future<void> _entrarConGoogle() async {
    ProxSounds.playOpenOnce();
    setState(() => _loadingGoogle = true);
    try {
      await AuthService.instance.signInWithGoogle();
      if (!mounted) return;
      await _navegarPostLogin();
    } on AuthCancelledException {
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

  Future<void> _entrarConEmail() async {
    ProxSounds.playOpenOnce();
    final email = _emailCtrl.text.trim();
    final pass = _passCtrl.text;
    if (email.isEmpty || pass.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Completá email y contraseña.'),
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }

    setState(() => _loadingEmail = true);
    try {
      await AuthService.instance.signInWithEmail(
        email: email,
        password: pass,
      );
      if (!mounted) return;
      ProxAnalytics.instance.action('login_email', screen: '/login');
      await _navegarPostLogin();
    } on EmailNotVerifiedException catch (e) {
      if (!mounted) return;
      _mostrarDialogoNoVerificado(e.email);
    } on AuthValidationException catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(e.message),
          behavior: SnackBarBehavior.floating,
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(AuthService.humanizeAuthError(e)),
          behavior: SnackBarBehavior.floating,
        ),
      );
    } finally {
      if (mounted) setState(() => _loadingEmail = false);
    }
  }

  Future<void> _olvidePassword() async {
    final email = _emailCtrl.text.trim();
    if (email.isEmpty || !email.contains('@')) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Escribí tu email arriba para enviarte el reset.'),
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }
    setState(() => _loadingEmail = true);
    try {
      await AuthService.instance.sendPasswordReset(email);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Si existe una cuenta con $email, te mandamos un mail para cambiar la contraseña.',
          ),
          behavior: SnackBarBehavior.floating,
          duration: const Duration(seconds: 5),
        ),
      );
    } on AuthValidationException catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.message), behavior: SnackBarBehavior.floating),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(AuthService.humanizeAuthError(e)),
          behavior: SnackBarBehavior.floating,
        ),
      );
    } finally {
      if (mounted) setState(() => _loadingEmail = false);
    }
  }

  void _mostrarDialogoNoVerificado(String email) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text(
          'Email sin verificar',
          style: TextStyle(fontWeight: FontWeight.w800),
        ),
        content: Text(
          'Tu cuenta ($email) todavía no confirmó el mail.\n\n'
          'Abrí el enlace que te mandamos y después volvé a iniciar sesión.',
        ),
        actions: [
          TextButton(
            onPressed: () async {
              Navigator.pop(ctx);
              try {
                await AuthService.instance.resendVerificationEmail();
                if (!mounted) return;
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Reenviamos el mail de verificación.'),
                    behavior: SnackBarBehavior.floating,
                  ),
                );
              } catch (e) {
                if (!mounted) return;
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(AuthService.humanizeAuthError(e)),
                    behavior: SnackBarBehavior.floating,
                  ),
                );
              }
            },
            child: const Text('Reenviar mail'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Entendido'),
          ),
        ],
      ),
    );
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

  Future<void> _navegarPostLogin() async {
    await UserSession().ensureHomeModoPrefLoaded();
    if (!mounted) return;
    if (UserSession().pendingValidacionToken != null) {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (context) => const PantallaGraciasValidacionWidget(),
        ),
      );
      return;
    }
    final targetId = UserSession().pendingValidacionTargetId;
    if (targetId != null && targetId.isNotEmpty) {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (context) => ValidarDomicilioWidget(usuarioId: targetId),
        ),
      );
      return;
    }
    if (EligePaisWidget.necesitaElegir()) {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (context) => const EligePaisWidget()),
      );
      return;
    }
    if (EligeCaminoWidget.necesitaElegir()) {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (context) => const EligeCaminoWidget()),
      );
      return;
    }
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(
        builder: (context) => HomePageWidget(
          initialModoPrestador: UserSession().preferredHomeModoPrestador,
        ),
      ),
    );
  }

  Widget _buildEmailForm({required bool busy}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        TextField(
          controller: _emailCtrl,
          keyboardType: TextInputType.emailAddress,
          autocorrect: false,
          enabled: !busy,
          decoration: InputDecoration(
            labelText: 'Email',
            prefixIcon: const Icon(Icons.email_outlined),
            filled: true,
            fillColor: Colors.white,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(14),
              borderSide: BorderSide.none,
            ),
          ),
        ),
        const SizedBox(height: 12),
        TextField(
          controller: _passCtrl,
          obscureText: _obscurePass,
          enabled: !busy,
          onSubmitted: (_) => busy ? null : _entrarConEmail(),
          decoration: InputDecoration(
            labelText: 'Contraseña',
            prefixIcon: const Icon(Icons.lock_outline),
            suffixIcon: IconButton(
              icon: Icon(
                _obscurePass
                    ? Icons.visibility_outlined
                    : Icons.visibility_off_outlined,
              ),
              onPressed: () => setState(() => _obscurePass = !_obscurePass),
            ),
            filled: true,
            fillColor: Colors.white,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(14),
              borderSide: BorderSide.none,
            ),
          ),
        ),
        Align(
          alignment: Alignment.centerRight,
          child: TextButton(
            onPressed: busy ? null : _olvidePassword,
            child: const Text(
              'Olvidé mi contraseña',
              style: TextStyle(fontSize: 13),
            ),
          ),
        ),
        SizedBox(
          height: 50,
          child: ElevatedButton(
            onPressed: busy ? null : _entrarConEmail,
            style: ElevatedButton.styleFrom(
              backgroundColor: primaryColor,
              foregroundColor: Colors.white,
              elevation: 0,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14),
              ),
            ),
            child: _loadingEmail
                ? const SizedBox(
                    width: 22,
                    height: 22,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: Colors.white,
                    ),
                  )
                : const Text(
                    'Entrar con email',
                    style: TextStyle(fontWeight: FontWeight.w700, fontSize: 15),
                  ),
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final busy = _loadingGoogle || _loadingApple || _loadingFacebook || _loadingEmail;

    return Scaffold(
      backgroundColor: AppColors.bg,
      body: Listener(
        behavior: HitTestBehavior.translucent,
        onPointerDown: (_) => _onFirstGesture(),
        child: SafeArea(
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
                    const SizedBox(height: 12),
                    Text(
                      AppCopy.tagline,
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                        color: subTextColor,
                        height: 1.35,
                      ),
                    ),
                    const SizedBox(height: 20),
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
                      onPressed: busy
                          ? null
                          : () => setState(() => _showEmailForm = !_showEmailForm),
                      icon: _buildIconCircle(
                        backgroundColor: primaryColor.withOpacity(0.12),
                        child: Icon(
                          Icons.email_outlined,
                          color: primaryColor,
                          size: 16,
                        ),
                      ),
                      label: _showEmailForm
                          ? 'Ocultar email'
                          : 'Continuar con email',
                      backgroundColor: Colors.white,
                      textColor: textColor,
                      hasBorder: true,
                      borderColor: primaryColor.withOpacity(0.35),
                    ),
                    if (_showEmailForm) ...[
                      const SizedBox(height: 16),
                      _buildEmailForm(busy: busy),
                    ],
                    const SizedBox(height: 14),
                    _buildLoginButton(
                      onPressed: busy ? null : _entrarConApple,
                      icon: _buildIconCircle(
                        backgroundColor: Colors.white.withOpacity(0.15),
                        child: const Icon(
                          Icons.apple,
                          color: Colors.white,
                          size: 18,
                        ),
                      ),
                      label: _loadingApple
                          ? 'Conectando con Apple…'
                          : 'Continuar con Apple',
                      backgroundColor: Colors.black,
                      textColor: Colors.white,
                      loading: _loadingApple,
                    ),
                    if (LoginScreenWidget.showFacebookLogin) ...[
                      const SizedBox(height: 14),
                      _buildLoginButton(
                        onPressed: busy ? null : _entrarConFacebook,
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
                        label: _loadingFacebook
                            ? 'Conectando con Facebook…'
                            : 'Continuar con Facebook',
                        backgroundColor: const Color(0xFF1877F2),
                        textColor: Colors.white,
                        loading: _loadingFacebook,
                      ),
                    ],
                    const SizedBox(height: 32),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Text(
                          '¿Sos nuevo en PROX? ',
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
                            'Crear cuenta',
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
    required Widget icon,
    required String label,
    required Color backgroundColor,
    required Color textColor,
    VoidCallback? onPressed,
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
