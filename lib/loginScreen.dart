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
import 'widgets/google_g_mark.dart';
import 'widgets/prox_lockup.dart';

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
                    const Center(child: ProxLockup(maxWidth: 280)),
                    const SizedBox(height: 28),
                    Text(
                      AppCopy.welcomeTitle,
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.w800,
                        color: textColor,
                        letterSpacing: -0.4,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      AppCopy.welcomeSubtitle,
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        fontSize: 14,
                        color: subTextColor,
                        height: 1.4,
                      ),
                    ),
                    const SizedBox(height: 28),
                    _authButton(
                      onPressed: busy ? null : _entrarConGoogle,
                      icon: const GoogleGMark(size: 22),
                      label: _loadingGoogle
                          ? 'Conectando con Google…'
                          : 'Continuar con Google',
                      loading: _loadingGoogle,
                    ),
                    const SizedBox(height: 12),
                    _authButton(
                      onPressed: busy ? null : _entrarConApple,
                      icon: const Icon(Icons.apple, size: 24, color: Color(0xFF1F1F1F)),
                      label: _loadingApple
                          ? 'Conectando con Apple…'
                          : 'Continuar con Apple',
                      loading: _loadingApple,
                    ),
                    const SizedBox(height: 12),
                    _authButton(
                      onPressed: busy
                          ? null
                          : () => setState(() => _showEmailForm = !_showEmailForm),
                      icon: const Icon(
                        Icons.mail_outline_rounded,
                        size: 22,
                        color: Color(0xFF1F1F1F),
                      ),
                      label: _showEmailForm
                          ? 'Ocultar email'
                          : 'Continuar con email',
                    ),
                    if (_showEmailForm) ...[
                      const SizedBox(height: 16),
                      _buildEmailForm(busy: busy),
                    ],
                    if (LoginScreenWidget.showFacebookLogin) ...[
                      const SizedBox(height: 12),
                      _authButton(
                        onPressed: busy ? null : _entrarConFacebook,
                        icon: const Icon(Icons.facebook, size: 22, color: Color(0xFF1877F2)),
                        label: _loadingFacebook
                            ? 'Conectando con Facebook…'
                            : 'Continuar con Facebook',
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

  /// Botón de auth homologado: misma geometría para Google / Apple / email.
  /// Blanco, borde #747775 (guideline Google), alto 52, radio 12.
  Widget _authButton({
    required Widget icon,
    required String label,
    VoidCallback? onPressed,
    bool loading = false,
  }) {
    const border = Color(0xFF747775);
    const ink = Color(0xFF1F1F1F);
    return SizedBox(
      height: 52,
      child: OutlinedButton(
        onPressed: onPressed,
        style: OutlinedButton.styleFrom(
          backgroundColor: Colors.white,
          foregroundColor: ink,
          disabledForegroundColor: ink.withOpacity(0.45),
          disabledBackgroundColor: Colors.white,
          elevation: 0,
          side: const BorderSide(color: border, width: 1),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 16),
        ),
        child: Row(
          children: [
            SizedBox(
              width: 24,
              height: 24,
              child: loading
                  ? const CircularProgressIndicator(
                      strokeWidth: 2,
                      color: ink,
                    )
                  : Center(child: icon),
            ),
            Expanded(
              child: Text(
                label,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  letterSpacing: 0.15,
                  color: ink,
                ),
              ),
            ),
            const SizedBox(width: 24),
          ],
        ),
      ),
    );
  }
}
