import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:flutter/services.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'Homepage.dart';
import 'scoring_service.dart';
import 'theme/app_colors.dart';
import 'theme/app_copy.dart';
import 'user_session.dart';

// TEMP minimal stub - will be replaced
class TarjetaDigitalWidget extends StatefulWidget {
  const TarjetaDigitalWidget({super.key, this.usuarioRef});
  final DocumentReference? usuarioRef;
  static const String routeName = 'tarjetaDigital';
  static const String routePath = '/tarjetaDigital';
  @override
  State<TarjetaDigitalWidget> createState() => _TarjetaDigitalWidgetState();
}

class _TarjetaDigitalWidgetState extends State<TarjetaDigitalWidget> {
  @override
  Widget build(BuildContext context) {
    return const Scaffold(body: Center(child: Text('Cargando tarjeta...')));
  }
}
