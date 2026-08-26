import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:flutter/services.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'Homepage.dart';
import 'scoring_service.dart';
import 'theme/app_colors.dart';
import 'user_session.dart';
import 'contacto_service.dart';
import 'contacto/post_contacto_sheet.dart';
import 'mensajes/emitir_recibo_sheet.dart';
import 'tarjeta_share_service.dart';

/// Tarjeta UX v2 — mismo diseño para cliente y prestador (hero trust).
class TarjetaDigitalWidget extends StatefulWidget {
  const TarjetaDigitalWidget({super.key, this.usuarioRef, this.shareToken});
  final DocumentReference? usuarioRef;
  final String? shareToken;
  static const String routeName = 'tarjetaDigital';
  static const String routePath = '/tarjetaDigital';
  @override
  State<TarjetaDigitalWidget> createState() => _TarjetaDigitalWidgetState();
}
