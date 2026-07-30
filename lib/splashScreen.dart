import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'Homepage.dart';
import 'loginScreen.dart';
import 'user_session.dart';

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

  Future<void> _bootstrap() async {
    // Mínimo de animación visible.
    await Future<void>.delayed(const Duration(milliseconds: 1600));

    var restored = false;
    try {
      // No bloquear el splash si Firestore/prefs tardan o fallan.
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
        Navigator.pushReplacementNamed(context, HomePageWidget.routePath);
      } else {
        Navigator.pushReplacementNamed(context, LoginScreenWidget.routePath);
      }
    } catch (e) {
      debugPrint('Splash navigate error: $e');
      if (mounted) {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (_) => const LoginScreenWidget()),
        );
      }
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
    super.dispose();
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
                // Asset real en repo: logo_prox_splash.png.png
                child: Image.asset(
                  'assets/images/logo_prox_splash.png.png',
                  width: 200,
                  fit: BoxFit.contain,
                  errorBuilder: (_, __, ___) => Image.asset(
                    'assets/images/lifewallet.png',
                    width: 200,
                    fit: BoxFit.contain,
                    errorBuilder: (_, __, ___) => const Icon(
                      Icons.handyman_rounded,
                      size: 80,
                      color: Color(0xFF734BE4),
                    ),
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}
