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

class HomePageWidget extends StatefulWidget {
  final bool? initialModoPrestador;
  const HomePageWidget({super.key, this.initialModoPrestador});
  static const String routeName = 'HomePage';
  static const String routePath = '/home';
  @override
  State<HomePageWidget> createState() => _HomePageWidgetState();
}

// TEMPORARY STUB - full file will follow in next commit
class _HomePageWidgetState extends State<HomePageWidget> {
  @override
  Widget build(BuildContext context) {
    return const Scaffold(body: Center(child: Text('Actualizando homepage...')));
  }
}
