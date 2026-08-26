import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:firebase_core/firebase_core.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

import 'config/app_env.dart';
import 'theme/app_theme.dart';
import 'theme/app_copy.dart';
import 'analytics/prox_analytics.dart';
import 'user_session.dart';

import 'splashScreen.dart';
import 'loginScreen.dart';
import 'Homepage.dart';
import 'elige_camino.dart';
import 'elige_oficio.dart';
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

  // Keys inyectadas en compile-time. Nunca en el repo.
  // Local:  --dart-define=FIREBASE_API_KEY_WEB=... --dart-define=FIREBASE_API_KEY_ANDROID=...
  // CI:     secrets FIREBASE_API_KEY_WEB / FIREBASE_API_KEY_ANDROID
  const webKey = String.fromEnvironment('FIREBASE_API_KEY_WEB');
  const androidKey = String.fromEnvironment('FIREBASE_API_KEY_ANDROID');

  if (kIsWeb) {
    if (webKey.isEmpty) {
      debugPrint(
        'Falta FIREBASE_API_KEY_WEB. Correr con '
        '--dart-define=FIREBASE_API_KEY_WEB=...',
      );
    }
    await Firebase.initializeApp(
      options: const FirebaseOptions(
        apiKey: webKey,
        authDomain: 'lifewalletpuelo.web.app',
        projectId: 'lifewalletpuelo',
        storageBucket: 'lifewalletpuelo.firebasestorage.app',
        messagingSenderId: '74624927314',
        appId: '1:74624927314:web:3fadcc533dd1f3a985818b',
      ),
    );
  } else {
    if (androidKey.isEmpty) {
      debugPrint(
        'Falta FIREBASE_API_KEY_ANDROID. Correr con '
        '--dart-define=FIREBASE_API_KEY_ANDROID=...',
      );
    }
    await Firebase.initializeApp(
      options: const FirebaseOptions(
        apiKey: androidKey,
        appId: '1:74624927314:android:8e3376cf776fd40285818b',
        messagingSenderId: '74624927314',
        projectId: 'lifewalletpuelo',
        storageBucket: 'lifewalletpuelo.firebasestorage.app',
      ),
    );
  }

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
        HomePageWidget.routePath: (context) => HomePageWidget(
          initialModoPrestador: UserSession().preferredHomeModoPrestador,
        ),
        EligeCaminoWidget.routePath: (context) => const EligeCaminoWidget(),
        EligeOficioWidget.routePath: (context) => const EligeOficioWidget(),
        RegistroTrabajadorWidget.routePath: (context) =>
            const RegistroTrabajadorWidget(),
        BuscadorPrestadoresWidget.routePath: (context) =>
            const BuscadorPrestadoresWidget(),
        ConsolaProxWidget.routePath: (context) {
          if (!ConsolaProxWidget.puedeAcceder && !UserSession().isAdmin) {
            return const Scaffold(
              body: Center(child: Text('Acceso restringido')),
            );
          }
          return const ConsolaProxWidget();
        },
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

        if (uri.path == '/t' || uri.path.startsWith('/t/')) {
          final segs = uri.pathSegments;
          final token = segs.length >= 2
              ? segs[1]
              : (uri.queryParameters['t'] ?? '');
          return MaterialPageRoute(
            settings: settings,
            builder: (context) => TarjetaDigitalWidget(
              shareToken: token.isEmpty ? null : token,
            ),
          );
        }

        if (uri.path == TarjetaDigitalWidget.routePath ||
            uri.path.startsWith('/tarjetaDigital')) {
          DocumentReference? userRef;
          final String? shareToken = uri.queryParameters['t'];
          final String? idParam =
              uri.queryParameters['id'] ?? uri.queryParameters['usuarioRef'];

          if (shareToken != null && shareToken.isNotEmpty) {
            return MaterialPageRoute(
              settings: settings,
              builder: (context) => TarjetaDigitalWidget(shareToken: shareToken),
            );
          }

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
