import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'Homepage.dart'; 
import 'registroTrabajador.dart';
import 'buscadorPrestadores.dart';
import 'tarjetaDigital.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  await Firebase.initializeApp(
    options: const FirebaseOptions(
      apiKey: "AIzaSyAr6iPh8NaDBD4qwo3LvfpE4j9k7RfKTwQ",
      authDomain: "lifewalletpuelo.firebaseapp.com",
      projectId: "lifewalletpuelo",
      storageBucket: "lifewalletpuelo.firebasestorage.app",
      messagingSenderId: "74624927314",
      appId: "1:74624927314:web:3fadcc533dd1f3a985818b",
    ),
  );
  
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Puelo MVP',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        primaryColor: const Color(0xFF0F52BA),
        scaffoldBackgroundColor: const Color(0xFFF8FAFC),
        useMaterial3: true,
      ),
      initialRoute: HomePageWidget.routePath,
      routes: {
        HomePageWidget.routePath: (context) => const HomePageWidget(),
        RegistroTrabajadorWidget.routePath: (context) => const RegistroTrabajadorWidget(),
        BuscadorPrestadoresWidget.routePath: (context) => const BuscadorPrestadoresWidget(),
      },
      // Manejador dinámico simplificado que permite pasar la URL sin trabar el enrutador
      onGenerateRoute: (settings) {
        final settingsName = settings.name ?? '';
        final uri = Uri.parse(settingsName);

        if (uri.path == TarjetaDigitalWidget.routePath) {
          DocumentReference? userRef;

          if (settings.arguments is Map<String, dynamic>) {
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
