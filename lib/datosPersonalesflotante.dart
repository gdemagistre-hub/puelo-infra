import 'dart:typed_data';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';

import 'dni_ocr_parser.dart';
import 'dni_ocr_scan.dart';
import 'user_session.dart';
import 'theme/app_colors.dart';

class DatosPersonalesFlotanteWidget extends StatefulWidget {
  final bool? modoPrestador;

  const DatosPersonalesFlotanteWidget({super.key, this.modoPrestador});

  @override
  State<DatosPersonalesFlotanteWidget> createState() =>
      _DatosPersonalesFlotanteWidgetState();
}

class _DatosPersonalesFlotanteWidgetState
    extends State<DatosPersonalesFlotanteWidget> {
  static const Color _bg = AppColors.bg;
  static const Color _textColor = AppColors.text;

  bool get _esPrestador {
    if (widget.modoPrestador != null) return widget.modoPrestador!;
    final d = UserSession().datosCompletos;
    return d?['es_trabajador'] == true || d?['rol'] == 'trabajador';
  }

  Color get primaryColor =>
      AppColors.primaryFor(modoPrestador: _esPrestador);

  // PLACEHOLDER_RESTORED_MARKER - full file continues via next commit
  final _formKey = GlobalKey<FormState>();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _bg,
      appBar: AppBar(
        backgroundColor: Colors.white,
        title: Text('Datos personales', style: TextStyle(color: primaryColor)),
      ),
      body: Center(child: Text('Cargando restauraci\u00f3n...')),
    );
  }
}
