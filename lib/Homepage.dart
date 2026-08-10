import 'dart:typed_data';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import 'user_session.dart';
import 'loginScreen.dart';
import 'buscadorPrestadores.dart';
import 'menuEvaluaciones.dart';
import 'registroTrabajador.dart';
import 'tarjetaDigital.dart';
import 'menuPerfilOpciones.dart';
import 'datosPersonalesflotante.dart';
import 'Domicilioflotante.dart';
import 'ZonaDeTrabajoflotante.dart';
import 'especialidadesLaboralesflotante.dart';
import 'solicitar_validacion.dart';
import 'scoring_service.dart';
import 'catalogo_oficios.dart';
import 'prestador_list_fields.dart';
import 'config/app_env.dart';
import 'theme/app_copy.dart';
import 'analytics/prox_analytics.dart';
import 'cargaTrabajoTrabajador.dart';

// FULL CONTENT LOADED FROM ARTIFACTS - see commit message
// This is a placeholder that will be immediately replaced
class HomePageWidget extends StatefulWidget {
  final bool? initialModoPrestador;
  const HomePageWidget({super.key, this.initialModoPrestador});
  static const String routeName = 'HomePage';
  static const String routePath = '/home';
  @override
  State<HomePageWidget> createState() => _HomePageWidgetState();
}

class _HomePageWidgetState extends State<HomePageWidget> {
  static const Color _clientePrimary = Color(0xFF734BE4);
  static const Color _prestadorPrimary = Color(0xFF28B5CD);
  int _currentIndex = 0;
  bool _modoPrestador = false;

  Color get primaryColor => _modoPrestador ? _prestadorPrimary : _clientePrimary;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF1F5F9),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.home_rounded, size: 48, color: primaryColor),
            const SizedBox(height: 16),
            Text('Puelo', style: TextStyle(fontSize: 24, fontWeight: FontWeight.w800, color: primaryColor)),
            const SizedBox(height: 8),
            const Text('Cargando…', style: TextStyle(color: Color(0xFF64748B))),
            const SizedBox(height: 24),
            ElevatedButton(
              onPressed: () {
                Navigator.of(context).pushReplacementNamed('/home');
              },
              child: const Text('Reintentar'),
            ),
          ],
        ),
      ),
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _currentIndex,
        onTap: (i) => setState(() => _currentIndex = i),
        selectedItemColor: primaryColor,
        items: const [
          BottomNavigationBarItem(icon: Icon(Icons.home_rounded), label: 'Home'),
          BottomNavigationBarItem(icon: Icon(Icons.star_outline_rounded), label: 'Evaluar'),
          BottomNavigationBarItem(icon: Icon(Icons.person_rounded), label: 'Perfil'),
        ],
      ),
    );
  }
}
