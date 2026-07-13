import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'Homepage.dart'; // Importa tu pantalla principal

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  // Inicializa Firebase con las configuraciones por defecto de la plataforma (Web)
  await Firebase.initializeApp();
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
        primarySwatch: Colors.blue,
        useMaterial3: true,
      ),
      home: const HomePageWidget(), // Llama a tu Widget de la página de inicio
    );
  }
}
