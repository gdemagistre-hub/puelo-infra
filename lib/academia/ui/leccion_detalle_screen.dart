import 'package:flutter/material.dart';

import '../models/leccion.dart';

class LeccionDetalleScreen extends StatelessWidget {
  const LeccionDetalleScreen({super.key, required this.leccion});

  final Leccion leccion;

  static const Color _primary = Color(0xFF28B5CD);
  static const Color _text = Color(0xFF3D4756);
  static const Color _muted = Color(0xFF6B7280);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF7F9FC),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        title: Text(
          leccion.tag,
          style: const TextStyle(
            color: _primary,
            fontWeight: FontWeight.w800,
          ),
        ),
        iconTheme: const IconThemeData(color: _primary),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(24, 8, 24, 40),
        children: [
          Text(
            leccion.titulo,
            style: const TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.w800,
              color: _text,
              height: 1.25,
            ),
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              const Icon(Icons.schedule, size: 16, color: _muted),
              const SizedBox(width: 4),
              Text(
                '${leccion.minutos} min de lectura',
                style: const TextStyle(color: _muted),
              ),
            ],
          ),
          const SizedBox(height: 24),
          Text(
            leccion.cuerpo.trim(),
            style: const TextStyle(
              fontSize: 16,
              height: 1.55,
              color: _text,
            ),
          ),
        ],
      ),
    );
  }
}
