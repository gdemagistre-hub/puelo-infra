import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'Homepage.dart';
import 'elige_camino.dart';
import 'elige_pais.dart';
import 'legales/acepto_legales.dart';
import 'loginScreen.dart';
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

    try {
      if (restored && UserSession().isLoggedIn) {
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
      } else {
        _irALogin();
      }
    } catch (e) {
      debugPrint('Splash navigate error: $e');
      if (mounted) _irALogin();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: Center(
        child: AnimatedBuilder(
          animation: _controller,
          builder: (context, child) {
            return Opacity(
              opacity: _opacityAnimation.value,
              child: Transform.scale(
                scale: _scaleAnimation.value,
                child: const ProxLockup(maxWidth: 260),
              ),
            );
          },
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
