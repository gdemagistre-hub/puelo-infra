import 'package:flutter/material.dart';

// Emergency restore — full Homepage follows immediately
class HomePageWidget extends StatefulWidget {
  const HomePageWidget({super.key});
  static const String routeName = 'HomePage';
  static const String routePath = '/home';
  @override
  State<HomePageWidget> createState() => _HomePageWidgetState();
}

class _HomePageWidgetState extends State<HomePageWidget> {
  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      body: Center(
        child: Padding(
          padding: EdgeInsets.all(24),
          child: Text(
            'Restaurando home completo…\nRecarg\u00e1 en unos segundos.',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 16),
          ),
        ),
      ),
    );
  }
}
