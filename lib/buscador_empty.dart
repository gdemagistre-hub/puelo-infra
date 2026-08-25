import 'package:flutter/material.dart';

import 'Domicilioflotante.dart';

/// Vacío del listado: filtro, zona o sin domicilio.
class BuscadorEmptyState extends StatelessWidget {
  static const Color _primary = Color(0xFF734BE4);
  static const Color _text = Color(0xFF1E293B);

  final String rubro;
  final String query;
  final String? zonaNombre;
  final bool tieneZona;
  final VoidCallback onVerTodos;
  final VoidCallback onActualizar;

  const BuscadorEmptyState({
    super.key,
    required this.rubro,
    required this.query,
    required this.zonaNombre,
    required this.tieneZona,
    required this.onVerTodos,
    required this.onActualizar,
  });

  @override
  Widget build(BuildContext context) {
    final hayFiltro = (rubro.isNotEmpty && rubro != 'Todos') || query.isNotEmpty;
    final zona = (zonaNombre ?? '').trim();
    final oficio = (rubro.isNotEmpty && rubro != 'Todos') ? rubro : '';

    late final String titulo;
    late final String sub;
    if (hayFiltro && zona.isNotEmpty) {
      titulo = oficio.isNotEmpty
          ? 'Nadie de $oficio cerca de $zona'
          : 'Nadie con esa búsqueda cerca de $zona';
      sub = 'Probá otro oficio o mirá a todos los prestadores.';
    } else if (hayFiltro) {
      titulo = oficio.isNotEmpty
          ? 'Nadie de $oficio por ahora'
          : 'Nadie con esa búsqueda';
      sub = 'Probá otro oficio o sacá el filtro.';
    } else if (zona.isNotEmpty) {
      titulo = 'Todavía no hay prestadores en $zona';
      sub = 'Estamos sumando gente de oficio en el barrio.';
    } else {
      titulo = 'Todavía no hay prestadores acá';
      sub = 'Cargá tu domicilio para priorizar a los que quedan cerca.';
    }

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 28),
      child: Column(
        children: [
          Container(
            width: 72,
            height: 72,
            decoration: BoxDecoration(
              color: _primary.withOpacity(0.08),
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.search_off_rounded, size: 34, color: _primary),
          ),
          const SizedBox(height: 16),
          Text(
            titulo,
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w800,
              color: _text,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            sub,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 14,
              height: 1.35,
              color: Colors.grey.shade600,
            ),
          ),
          const SizedBox(height: 20),
          if (hayFiltro)
            _btnFilled('Ver todos', onVerTodos)
          else if (!tieneZona)
            _btnFilled('Cargar domicilio', () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) =>
                      const DomicilioFlotanteWidget(modoPrestador: false),
                ),
              );
            })
          else
            SizedBox(
              width: double.infinity,
              height: 46,
              child: OutlinedButton(
                onPressed: onActualizar,
                style: OutlinedButton.styleFrom(
                  foregroundColor: _primary,
                  side: const BorderSide(color: _primary),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: const Text(
                  'Actualizar',
                  style: TextStyle(fontWeight: FontWeight.w800),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _btnFilled(String label, VoidCallback onTap) {
    return SizedBox(
      width: double.infinity,
      height: 46,
      child: ElevatedButton(
        onPressed: onTap,
        style: ElevatedButton.styleFrom(
          backgroundColor: _primary,
          foregroundColor: Colors.white,
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
        child: Text(label, style: const TextStyle(fontWeight: FontWeight.w800)),
      ),
    );
  }
}
