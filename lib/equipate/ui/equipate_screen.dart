import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../models/herramienta.dart';
import 'simulador_screen.dart';
import 'solicitud_flujo_screen.dart';

class EquipateScreen extends StatelessWidget {
  const EquipateScreen({super.key});

  static const _primary = Color(0xFF28B5CD);

  @override
  Widget build(BuildContext context) {
    final money =
        NumberFormat.currency(locale: 'es_AR', symbol: r'$', decimalDigits: 0);

    return Scaffold(
      backgroundColor: const Color(0xFFF1F5F9),
      appBar: AppBar(
        title: const Text('Equípate'),
        backgroundColor: Colors.white,
        foregroundColor: _primary,
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 12),
            child: Center(
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: const Color(0xFFF59E0B).withOpacity(0.2),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: const Text(
                  'Modo prueba',
                  style: TextStyle(
                    fontWeight: FontWeight.w700,
                    fontSize: 12,
                    color: Color(0xFFB45309),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: const Color(0xFFFFF8E7),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: const Color(0xFFFFE082)),
            ),
            child: const Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Esto es una prueba de la app',
                    style:
                        TextStyle(fontWeight: FontWeight.w800, fontSize: 16)),
                SizedBox(height: 6),
                Text(
                  'Acá podés ver cómo se pediría una herramienta. No se envía nada a un banco real todavía.',
                  style: TextStyle(height: 1.4, color: Color(0xFF475569)),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          const Text('Herramientas para tu oficio',
              style: TextStyle(fontWeight: FontWeight.w700, fontSize: 16)),
          const SizedBox(height: 12),
          ...catalogoHerramientas.map(
            (h) => Card(
              margin: const EdgeInsets.only(bottom: 12),
              elevation: 0,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14),
                side: const BorderSide(color: Color(0xFFE2E8F0)),
              ),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(h.nombre,
                        style: const TextStyle(
                            fontWeight: FontWeight.w700, fontSize: 16)),
                    const SizedBox(height: 4),
                    Text(h.oficio,
                        style: const TextStyle(
                            color: _primary,
                            fontSize: 13,
                            fontWeight: FontWeight.w600)),
                    const SizedBox(height: 6),
                    Text(h.descripcion,
                        style: const TextStyle(color: Color(0xFF64748B))),
                    const SizedBox(height: 10),
                    Text(money.format(h.precio),
                        style: const TextStyle(
                            fontWeight: FontWeight.w800, fontSize: 18)),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(
                          child: OutlinedButton(
                            onPressed: () {
                              Navigator.of(context).push(
                                MaterialPageRoute(
                                  builder: (_) =>
                                      SimuladorScreen(herramienta: h),
                                ),
                              );
                            },
                            child: const Text('Ver cómo pagarías'),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: FilledButton(
                            onPressed: () {
                              Navigator.of(context).push(
                                MaterialPageRoute(
                                  builder: (_) =>
                                      SolicitudFlujoScreen(herramienta: h),
                                ),
                              );
                            },
                            style: FilledButton.styleFrom(
                                backgroundColor: _primary),
                            child: const Text('Probar pedido'),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
