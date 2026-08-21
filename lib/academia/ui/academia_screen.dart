import 'package:flutter/material.dart';

import '../data/academia_progress.dart';
import '../data/catalogo_lecciones.dart';
import '../models/leccion.dart';
import 'leccion_detalle_screen.dart';

/// Academia embebida en el tab de PROX.
class AcademiaScreen extends StatefulWidget {
  final bool embedded;
  const AcademiaScreen({super.key, this.embedded = true});

  @override
  State<AcademiaScreen> createState() => _AcademiaScreenState();
}

class _AcademiaScreenState extends State<AcademiaScreen> {
  static const Color _primary = Color(0xFF28B5CD);
  static const Color _secondary = Color(0xFF734BE4);
  static const Color _text = Color(0xFF0F172A);
  static const Color _muted = Color(0xFF64748B);

  Set<String> _completadas = {};

  @override
  void initState() {
    super.initState();
    _cargarProgreso();
  }

  Future<void> _cargarProgreso() async {
    final ids = await AcademiaProgress.idsCompletadas();
    if (!mounted) return;
    setState(() => _completadas = ids);
  }

  Future<void> _abrir(Leccion l) async {
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => LeccionDetalleScreen(leccion: l),
      ),
    );
    // Al volver, refrescar checks (por si se registró la lectura).
    await _cargarProgreso();
  }

  @override
  Widget build(BuildContext context) {
    final body = ListView(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 32),
      children: [
        const Text(
          'Tips cortos para tu oficio',
          style: TextStyle(
            fontSize: 17,
            fontWeight: FontWeight.w800,
            color: _text,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          _completadas.isEmpty
              ? 'Lenguaje simple. Sin vueltas. Para usar en el día a día.'
              : 'Leídas: ${_completadas.length} · Gate readiness: 3+',
          style: const TextStyle(color: _muted, fontSize: 13),
        ),
        const SizedBox(height: 20),
        ...catalogoLecciones.map(
          (l) => _LeccionCard(
            leccion: l,
            completada: _completadas.contains(l.id),
            onTap: () => _abrir(l),
          ),
        ),
      ],
    );

    if (widget.embedded) {
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
  const _LeccionCard({
    required this.leccion,
    required this.onTap,
    this.completada = false,
  });

  final Leccion leccion;
  final VoidCallback onTap;
  final bool completada;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Material(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        elevation: 1.5,
        shadowColor: Colors.black12,
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
                    color: completada
                        ? const Color(0xFFDCFCE7)
                        : _AcademiaScreenState._secondary.withOpacity(0.12),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(
                    completada
                        ? Icons.check_rounded
                        : (leccion.hasAudio
                            ? Icons.headphones_outlined
                            : Icons.menu_book_outlined),
                    color: completada
                        ? const Color(0xFF16A34A)
                        : _AcademiaScreenState._secondary,
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
                              horizontal: 9,
                              vertical: 3,
                            ),
                            decoration: BoxDecoration(
                              color: _AcademiaScreenState._secondary
                                  .withOpacity(0.12),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Text(
                              leccion.tag,
                              style: const TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w800,
                                color: _AcademiaScreenState._secondary,
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Text(
                            '${leccion.minutos} min',
                            style: const TextStyle(
                              fontSize: 12,
                              color: _AcademiaScreenState._muted,
                            ),
                          ),
                          if (leccion.hasAudio) ...[
                            const SizedBox(width: 8),
                            const Icon(Icons.play_circle_outline,
                                size: 16,
                                color: _AcademiaScreenState._secondary),
                          ],
                          if (completada) ...[
                            const SizedBox(width: 8),
                            const Text(
                              'Leída',
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w700,
                                color: Color(0xFF16A34A),
                              ),
                            ),
                          ],
                        ],
                      ),
                      const SizedBox(height: 6),
                      Text(
                        leccion.titulo,
                        style: const TextStyle(
                          fontWeight: FontWeight.w800,
                          fontSize: 15,
                          color: _AcademiaScreenState._text,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        leccion.resumen,
                        style: const TextStyle(
                          color: _AcademiaScreenState._muted,
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
