import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

import 'config/app_env.dart';
import 'theme/app_theme.dart';
import 'theme/app_copy.dart';
import 'analytics/prox_analytics.dart';

import 'splashScreen.dart';
import 'loginScreen.dart';
import 'Homepage.dart';
import 'registroTrabajador.dart';
import 'buscadorPrestadores.dart';
import 'tarjetaDigital.dart';
import 'seleccionRol.dart';
import 'pantallaValidacion.dart';
import 'validar_domicilio.dart';
import 'consola_prox.dart';

final ProxRouteObserver proxRouteObserver = ProxRouteObserver();

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await Firebase.initializeApp(
    options: const FirebaseOptions(
      apiKey: 'AIzaSyAr6iPh8NaDBD4qwo3LvfpE4j9k7RfKTwQ',
      authDomain: 'lifewalletpuelo.firebaseapp.com',
      projectId: 'lifewalletpuelo',
      storageBucket: 'lifewalletpuelo.firebasestorage.app',
      messagingSenderId: '74624927314',
      appId: '1:74624927314:web:3fadcc533dd1f3a985818b',
    ),
  );

  if (AppEnv.verboseLogging) {
    debugPrint('Puelo env=${AppEnv.label} showDevTools=${AppEnv.showDevTools}');
  }

  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: AppCopy.appName,
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light(modoPrestador: false),
      navigatorObservers: [proxRouteObserver],
      initialRoute: SplashScreenWidget.routePath,
      routes: {
        SplashScreenWidget.routePath: (context) => const SplashScreenWidget(),
        LoginScreenWidget.routePath: (context) => const LoginScreenWidget(),
        HomePageWidget.routePath: (context) => const HomePageWidget(),
        RegistroTrabajadorWidget.routePath: (context) =>
            const RegistroTrabajadorWidget(),
        BuscadorPrestadoresWidget.routePath: (context) =>
            const BuscadorPrestadoresWidget(),
        ConsolaProxWidget.routePath: (context) => const ConsolaProxWidget(),
        '/seleccionRol': (context) => const SeleccionRolWidget(),
      },
      onGenerateRoute: (settings) {
        final settingsName = settings.name ?? '';
        final uri = Uri.parse(settingsName);

        if (uri.path == '/validar') {
          final String? token = uri.queryParameters['token'];
          return MaterialPageRoute(
            settings: settings,
            builder: (context) => PantallaValidacionWidget(token: token),
          );
        }

        if (uri.path == '/validarDomicilio' ||
            uri.path.startsWith('/validarDomicilio')) {
          final String? idParam = uri.queryParameters['id'];
          return MaterialPageRoute(
            settings: settings,
            builder: (context) => ValidarDomicilioWidget(usuarioId: idParam),
          );
        }

        if (uri.path == TarjetaDigitalWidget.routePath ||
            uri.path.startsWith('/tarjetaDigital')) {
          DocumentReference? userRef;
          final String? idParam =
              uri.queryParameters['id'] ?? uri.queryParameters['usuarioRef'];

          if (idParam != null && idParam.isNotEmpty) {
            userRef = FirebaseFirestore.instance.doc('usuarios/$idParam');
          } else if (settings.arguments is Map<String, dynamic>) {
            final args = settings.arguments as Map<String, dynamic>;
            userRef = args['usuarioRef'] as DocumentReference?;
          } else if (settings.arguments is DocumentReference) {
            userRef = settings.arguments as DocumentReference?;
          }

          return MaterialPageRoute(
            settings: settings,
            builder: (context) => TarjetaDigitalWidget(usuarioRef: userRef),
          );
        }

        return null;
      },
    );
  }
}
