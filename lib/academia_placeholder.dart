import 'package:flutter/material.dart';

/// Placeholder Academia / cápsulas financieras (contenido vendrá de Finanzas).
class AcademiaPlaceholderWidget extends StatelessWidget {
  final bool embedded;
  const AcademiaPlaceholderWidget({super.key, this.embedded = true});

  @override
  Widget build(BuildContext context) {
    return ColoredBox(
      color: const Color(0xFFF1F5F9),
      child: SafeArea(
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(28),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(
                  width: 88,
                  height: 88,
                  decoration: BoxDecoration(
                    color: const Color(0xFF734BE4).withOpacity(0.12),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.school_rounded,
                    size: 44,
                    color: Color(0xFF734BE4),
                  ),
                ),
                const SizedBox(height: 24),
                const Text(
                  'Academia Puelo',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.w800,
                    color: Color(0xFF0F172A),
                  ),
                ),
                const SizedBox(height: 12),
                const Text(
                  'Cápsulas y cursos de finanzas para oficios.\n'
                  'El contenido se está migrando desde Puelo Finanzas.',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 14,
                    height: 1.45,
                    color: Color(0xFF64748B),
                  ),
                ),
                const SizedBox(height: 20),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                  decoration: BoxDecoration(
                    color: const Color(0xFF28B5CD).withOpacity(0.12),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: const Text(
                    'Próximamente',
                    style: TextStyle(
                      fontWeight: FontWeight.w700,
                      color: Color(0xFF1A8FA3),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
