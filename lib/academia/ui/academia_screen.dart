import 'package:flutter/material.dart';

import '../../equipate/ui/equipate_screen.dart';
import '../data/catalogo_lecciones.dart';
import '../models/leccion.dart';
import 'leccion_detalle_screen.dart';

/// Academia embebida en el tab de PROX (sin Scaffold propio cuando [embedded]).
class AcademiaScreen extends StatelessWidget {
  final bool embedded;
  const AcademiaScreen({super.key, this.embedded = true});

  static const Color _primary = Color(0xFF28B5CD);
  static const Color _secondary = Color(0xFF734BE4);
  static const Color _text = Color(0xFF0F172A);
  static const Color _muted = Color(0xFF64748B);

  @override
  Widget build(BuildContext context) {
    final body = ListView(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 32),
      children: [
        // Atajo temporal a Equípate
        Material(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          elevation: 1,
          child: InkWell(
            borderRadius: BorderRadius.circular(16),
            onTap: () {
              Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => const EquipateScreen()),
              );
            },
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              child: Row(
                children: [
                  Container(
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                      color: _primary.withOpacity(0.12),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Icon(Icons.build_circle_outlined,
                        color: _primary),
                  ),
                  const SizedBox(width: 14),
                  const Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Equípate',
                          style: TextStyle(
                            fontWeight: FontWeight.w800,
                            fontSize: 15,
                            color: _text,
                          ),
                        ),
                        SizedBox(height: 2),
                        Text(
                          'Herramientas y simulador (modo prueba)',
                          style: TextStyle(color: _muted, fontSize: 12),
                        ),
                      ],
                    ),
                  ),
                  const Icon(Icons.chevron_right_rounded,
                      color: Color(0xFF94A3B8)),
                ],
              ),
            ),
          ),
        ),
        const SizedBox(height: 20),
        const Text(
          'Tips cortos para tu oficio',
          style: TextStyle(
            fontSize: 17,
            fontWeight: FontWeight.w800,
            color: _text,
          ),
        ),
        const SizedBox(height: 4),
        const Text(
          'Lenguaje simple. Sin vueltas. Para usar en el día a día.',
          style: TextStyle(color: _muted, fontSize: 13),
        ),
        const SizedBox(height: 20),
        ...catalogoLecciones.map(
          (l) => _LeccionCard(
            leccion: l,
            onTap: () {
              Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (_) => LeccionDetalleScreen(leccion: l),
                ),
              );
            },
          ),
        ),
      ],
    );

    if (embedded) {
      return ColoredBox(color: const Color(0xFFF1F5F9), child: body);
    }
    return Scaffold(
      backgroundColor: const Color(0xFFF1F5F9),
      appBar: AppBar(
        title: const Text('Academia'),
        backgroundColor: Colors.white,
      ),
      body: body,
    );
  }
}

class _LeccionCard extends StatelessWidget {
  const _LeccionCard({required this.leccion, required this.onTap});

  final Leccion leccion;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Material(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        elevation: 1,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(16),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: AcademiaScreen._secondary.withOpacity(0.12),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(
                    Icons.menu_book_outlined,
                    color: AcademiaScreen._secondary,
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 2,
                            ),
                            decoration: BoxDecoration(
                              color: AcademiaScreen._primary.withOpacity(0.12),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Text(
                              leccion.tag,
                              style: const TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w700,
                                color: AcademiaScreen._primary,
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Text(
                            '${leccion.minutos} min',
                            style: const TextStyle(
                              fontSize: 12,
                              color: AcademiaScreen._muted,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 6),
                      Text(
                        leccion.titulo,
                        style: const TextStyle(
                          fontWeight: FontWeight.w800,
                          fontSize: 15,
                          color: AcademiaScreen._text,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        leccion.resumen,
                        style: const TextStyle(
                          color: AcademiaScreen._muted,
                          fontSize: 13,
                          height: 1.35,
                        ),
                      ),
                    ],
                  ),
                ),
                const Icon(Icons.chevron_right_rounded,
                    color: Color(0xFF94A3B8)),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
