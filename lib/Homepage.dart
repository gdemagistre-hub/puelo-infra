import 'package:flutter/material.dart';
// TEMP - will be replaced
class HomePageWidget extends StatelessWidget {
  final bool? initialModoPrestador;
  const HomePageWidget({super.key, this.initialModoPrestador});
  static const String routeName = 'HomePage';
  static const String routePath = '/home';
  @override
  Widget build(BuildContext context) {
    return const Scaffold(body: Center(child: Text('Restaurando Home...')));
  }
}
