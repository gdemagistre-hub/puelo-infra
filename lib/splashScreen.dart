import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'Homepage.dart';
import 'elige_camino.dart';
import 'elige_pais.dart';
import 'legales/acepto_legales.dart';
import 'loginScreen.dart';
import 'theme/app_colors.dart';
import 'user_session.dart';
import 'widgets/prox_lockup.dart';
import 'pantalla_gracias_validacion.dart';
import 'validar_domicilio.dart';

class SplashScreenWidget extends StatefulWidget {
  static const String routePath = '/splash';

  const SplashScreenWidget({super.key});

  @override
  State<SplashScreenWidget> createState() => _SplashScreenWidgetState();
}

class _SplashScreenWidgetState extends State<SplashScreenWidget>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _scaleAnimation;
  late Animation<double> _opacityAnimation;

  bool _listo = false;
  bool _haySesion = false;

  @override
  void initState() {
    super.initState();

    SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);

    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1600),
    );

    _scaleAnimation = Tween<double>(begin: 0.88, end: 1.0).animate(
      CurvedAnimation(
        parent: _controller,
        curve: Curves.easeOutCubic,
      ),
    );

    _opacityAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _controller,
        curve: const Interval(0.0, 0.7, curve: Curves.easeIn),
      ),
    );

    _controller.forward();
    _bootstrap();
  }

  void _irALogin() {
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(
        builder: (_) => const LoginScreenWidget(),
      ),
    );
  }

  void _irAHomeInvitado() {
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(
        builder: (_) => const HomePageWidget(initialModoPrestador: false),
      ),
    );
  }

  Future<void> _entrarConSesion() async {
    if (!mounted) return;
    try {
      if (UserSession().pendingValidacionToken != null) {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder: (_) => const PantallaGraciasValidacionWidget(),
          ),
        );
      } else if ((UserSession().pendingValidacionTargetId ?? '').isNotEmpty) {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder: (_) => ValidarDomicilioWidget(
              usuarioId: UserSession().pendingValidacionTargetId,
            ),
          ),
        );
      } else if (AceptoLegalesWidget.necesitaAceptar()) {
        Navigator.pushReplacementNamed(context, AceptoLegalesWidget.routePath);
      } else if (EligePaisWidget.necesitaElegir()) {
        Navigator.pushReplacementNamed(context, EligePaisWidget.routePath);
      } else if (EligeCaminoWidget.necesitaElegir()) {
        Navigator.pushReplacementNamed(context, EligeCaminoWidget.routePath);
      } else {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder: (_) => HomePageWidget(
              initialModoPrestador: UserSession().preferredHomeModoPrestador,
            ),
          ),
        );
      }
    } catch (e) {
      debugPrint('Splash navigate session error: $e');
      if (mounted) _irALogin();
    }
  }

  Future<void> _bootstrap() async {
    await Future<void>.delayed(const Duration(milliseconds: 1600));

    var restored = false;
    try {
      restored = await UserSession()
          .restaurarSesion()
          .timeout(const Duration(seconds: 6), onTimeout: () => false);
    } catch (e) {
      debugPrint('Splash restore error: $e');
      restored = false;
    }

    if (!mounted) return;

    final haySesion = restored && UserSession().isLoggedIn;
    if (haySesion) {
      await _entrarConSesion();
      return;
    }

    // Sin cuenta: el logo se queda y aparecen las dos entradas.
    setState(() {
      _haySesion = false;
      _listo = true;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: Center(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 28),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 420),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  AnimatedBuilder(
                    animation: _controller,
                    builder: (context, child) {
                      return Opacity(
                        opacity: _opacityAnimation.value,
                        child: Transform.scale(
                          scale: _scaleAnimation.value,
                          child: child,
                        ),
                      );
                    },
                    child: const ProxLockup(maxWidth: 260),
                  ),
                  if (_listo && !_haySesion) ...[
                    const SizedBox(height: 36),
                    const Text(
                      '¿Cómo querés entrar?',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.w800,
                        color: AppColors.text,
                        letterSpacing: -0.3,
                      ),
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      'Podés mirar el directorio sin cuenta, o entrar con la tuya.',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 14,
                        height: 1.4,
                        color: AppColors.textMuted,
                      ),
                    ),
                    const SizedBox(height: 28),
                    SizedBox(
                      width: double.infinity,
                      height: 52,
                      child: ElevatedButton(
                        onPressed: _irALogin,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.cliente,
                          foregroundColor: Colors.white,
                          elevation: 0,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14),
                          ),
                        ),
                        child: const Text(
                          'Iniciar sesión o crear cuenta',
                          style: TextStyle(
                            fontWeight: FontWeight.w700,
                            fontSize: 15,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                    SizedBox(
                      width: double.infinity,
                      height: 52,
                      child: OutlinedButton(
                        onPressed: _irAHomeInvitado,
                        style: OutlinedButton.styleFrom(
                          foregroundColor: AppColors.text,
                          side: const BorderSide(color: AppColors.border),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14),
                          ),
                        ),
                        child: const Text(
                          'Explorar como invitado',
                          style: TextStyle(
                            fontWeight: FontWeight.w700,
                            fontSize: 15,
                          ),
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
    super.dispose();
  }
}
