// 1. Agregar la importación arriba de todo junto a las demás:
import 'splashScreen.dart';

// ... tu código de inicialización de Firebase ...

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
      // 2. Establecer la pantalla de bienvenida como la inicial
      initialRoute: SplashScreenWidget.routePath,
      routes: {
        SplashScreenWidget.routePath: (context) => const SplashScreenWidget(),
        HomePageWidget.routePath: (context) => const HomePageWidget(),
        RegistroTrabajadorWidget.routePath: (context) => const RegistroTrabajadorWidget(),
        BuscadorPrestadoresWidget.routePath: (context) => const BuscadorPrestadoresWidget(),
      },
      onGenerateRoute: (settings) {
        // ... tu lógica existente de onGenerateRoute para la tarjeta digital ...
      },
    );
  }
}
