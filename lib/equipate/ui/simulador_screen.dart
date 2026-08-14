import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../models/herramienta.dart';
import 'solicitud_flujo_screen.dart';

class SimuladorScreen extends StatefulWidget {
  const SimuladorScreen({super.key, required this.herramienta});
  final Herramienta herramienta;

  @override
  State<SimuladorScreen> createState() => _SimuladorScreenState();
}

class _SimuladorScreenState extends State<SimuladorScreen> {
  static const _primary = Color(0xFF28B5CD);
  int _cuotas = 6;
  final _money =
      NumberFormat.currency(locale: 'es_AR', symbol: r'$', decimalDigits: 0);

  double get _cuotaAprox {
    const factor = 1.03;
    final total = widget.herramienta.precio * (factor * (_cuotas / 6));
    return total / _cuotas;
  }

  @override
  Widget build(BuildContext context) {
    final h = widget.herramienta;
    return Scaffold(
      backgroundColor: const Color(0xFFF1F5F9),
      appBar: AppBar(
        title: const Text('Simular cuotas'),
        backgroundColor: Colors.white,
        foregroundColor: _primary,
      ),
      body: ListView(
        padding: const EdgeInsets.all(24),
        children: [
          Text(h.nombre,
              style:
                  const TextStyle(fontWeight: FontWeight.w700, fontSize: 20)),
          Text('Precio ref.: ${_money.format(h.precio)}',
              style: const TextStyle(color: Color(0xFF64748B))),
          const SizedBox(height: 28),
          const Text('Cantidad de cuotas',
              style: TextStyle(fontWeight: FontWeight.w600)),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            children: [3, 6, 9, 12].map((n) {
              return ChoiceChip(
                label: Text('$n'),
                selected: n == _cuotas,
                onSelected: (_) => setState(() => _cuotas = n),
                selectedColor: _primary.withOpacity(0.2),
              );
            }).toList(),
          ),
          const SizedBox(height: 28),
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: const Color(0xFFE2E8F0)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Cuota aproximada',
                    style: TextStyle(color: Color(0xFF64748B))),
                Text(_money.format(_cuotaAprox),
                    style: const TextStyle(
                        fontSize: 32,
                        fontWeight: FontWeight.w800,
                        color: _primary)),
                const Text(
                  'Solo orientación. La cuota real la define el banco.',
                  style: TextStyle(fontSize: 12, color: Color(0xFF64748B)),
                ),
              ],
            ),
          ),
          const SizedBox(height: 28),
          FilledButton(
            onPressed: () {
              Navigator.of(context).pushReplacement(
                MaterialPageRoute(
                  builder: (_) => SolicitudFlujoScreen(
                    herramienta: h,
                    cuotasPreferidas: _cuotas,
                  ),
                ),
              );
            },
            style: FilledButton.styleFrom(
              backgroundColor: _primary,
              minimumSize: const Size.fromHeight(52),
            ),
            child: const Text('Pedir esta herramienta'),
          ),
        ],
      ),
    );
  }
}
