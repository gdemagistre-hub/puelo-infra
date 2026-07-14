import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'Homepage.dart'; 

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  // Inicialización explícita para Web para evitar que se cuelgue la carga
  await Firebase.initializeApp(
    options: const FirebaseOptions(
      apiKey: "TU_API_KEY_AQUÍ",
      authDomain: "lifewalletpuelo.firebaseapp.com",
      projectId: "lifewalletpuelo",
      storageBucket: "lifewalletpuelo.appspot.com",
      messagingSenderId: "TU_SENDER_ID_AQUÍ",
      appId: "TU_APP_ID_AQUÍ",
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
      home: const HomePageWidget(),
    );
  }
}
