import 'dart:async';
import 'package:flutter/material.dart';
import 'Homepage.dart';

class SplashScreenWidget extends StatefulWidget {
  const SplashScreenWidget({super.key});

  static const String routeName = 'splashScreen';
  static const String routePath = '/splashScreen';

  @override
  State<SplashScreenWidget> createState() => _SplashScreenWidgetState();
}

class _SplashScreenWidgetState extends State<SplashScreenWidget> {
  @override
  void initState() {
    super.initState();
    
    // Temporizador de 3 segundos para redirigir a la Home
    Timer(const Duration(seconds: 3), () {
      if (mounted) {
        Navigator.pushReplacementNamed(context, HomePageWidget.routePath);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      // Un fondo blanco limpio o el color primario que prefieras
      backgroundColor: Colors.white, 
      body: SafeArea(
        child: Center(
          child: Padding(
            padding: EdgeInsets.all(40.0),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                // Contenedor para limitar y suavizar el renderizado de la imagen de alta resolución
                SizedBox(
                  width: 250,
                  height: 300,
                  child: Image(
                    image: AssetImage('assets/images/lifewallet.png'),
                    fit: BoxFit.contain,
                    filterQuality: FilterQuality.high, // Evita pixelado al escalar 300ppp
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
