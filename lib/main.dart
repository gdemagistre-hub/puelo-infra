import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'Homepage.dart'; 

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  // Inicialización explícita con tus credenciales de Firebase Web
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
      home: const HomePageWidget(),
    );
  }
}
