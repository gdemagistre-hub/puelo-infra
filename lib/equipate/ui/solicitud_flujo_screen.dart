import 'package:flutter/material.dart';

import '../models/herramienta.dart';

class SolicitudFlujoScreen extends StatefulWidget {
  const SolicitudFlujoScreen({
    super.key,
    required this.herramienta,
    this.cuotasPreferidas = 6,
  });

  final Herramienta herramienta;
  final int cuotasPreferidas;

  @override
  State<SolicitudFlujoScreen> createState() => _SolicitudFlujoScreenState();
}

class _SolicitudFlujoScreenState extends State<SolicitudFlujoScreen> {
  static const _primary = Color(0xFF28B5CD);
  int _paso = 0;
  bool _consentimiento = false;
  bool _trabajando = false;
  String? _estadoFinal;

  final _pasos = const [
    'Consentimiento',
    'Consulta BCRA',
    'Evaluación interna',
    'Validación de identidad',
    'Envío al banco',
  ];

  Future<void> _continuar() async {
    if (_paso == 0 && !_consentimiento) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Tenés que aceptar para seguir')),
      );
      return;
    }
    setState(() => _trabajando = true);
    await Future<void>.delayed(const Duration(milliseconds: 900));
    if (!mounted) return;
    if (_paso >= _pasos.length - 1) {
      setState(() {
        _trabajando = false;
        _estadoFinal =
            'Fin de la prueba. No se envió nada a un banco real.';
      });
      return;
    }
    setState(() {
      _trabajando = false;
      _paso++;
    });
  }

  @override
  Widget build(BuildContext context) {
    final h = widget.herramienta;
    return Scaffold(
      backgroundColor: const Color(0xFFF1F5F9),
      appBar: AppBar(
        title: const Text('Pedido (prueba)'),
        backgroundColor: Colors.white,
        foregroundColor: _primary,
      ),
      body: ListView(
        padding: const EdgeInsets.all(24),
        children: [
          Text(h.nombre,
              style:
                  const TextStyle(fontWeight: FontWeight.w700, fontSize: 18)),
          Text('Cuotas preferidas: ${widget.cuotasPreferidas}',
              style: const TextStyle(color: Color(0xFF64748B))),
          const SizedBox(height: 16),
          ...List.generate(_pasos.length, (i) {
            final done = i < _paso || _estadoFinal != null;
            final current = i == _paso && _estadoFinal == null;
            return ListTile(
              contentPadding: EdgeInsets.zero,
              leading: Icon(
                done
                    ? Icons.check_circle
                    : current
                        ? Icons.radio_button_checked
                        : Icons.radio_button_unchecked,
                color: done
                    ? const Color(0xFF16A34A)
                    : current
                        ? _primary
                        : const Color(0xFF94A3B8),
              ),
              title: Text(_pasos[i],
                  style: TextStyle(
                    fontWeight: current ? FontWeight.w700 : FontWeight.w500,
                  )),
            );
          }),
          if (_paso == 0 && _estadoFinal == null)
            CheckboxListTile(
              value: _consentimiento,
              onChanged: (v) => setState(() => _consentimiento = v ?? false),
              controlAffinity: ListTileControlAffinity.leading,
              contentPadding: EdgeInsets.zero,
              title: const Text(
                'Entiendo que esto es una prueba y autorizo el flujo de ejemplo.',
                style: TextStyle(fontSize: 14),
              ),
            ),
          if (_estadoFinal != null) ...[
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: const Color(0xFF16A34A).withOpacity(0.12),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(_estadoFinal!,
                  style: const TextStyle(fontWeight: FontWeight.w600)),
            ),
            const SizedBox(height: 20),
            FilledButton(
              onPressed: () => Navigator.of(context).pop(),
              style: FilledButton.styleFrom(backgroundColor: _primary),
              child: const Text('Volver'),
            ),
          ] else ...[
            const SizedBox(height: 24),
            FilledButton(
              onPressed: _trabajando ? null : _continuar,
              style: FilledButton.styleFrom(
                backgroundColor: _primary,
                minimumSize: const Size.fromHeight(52),
              ),
              child: _trabajando
                  ? const SizedBox(
                      width: 22,
                      height: 22,
                      child: CircularProgressIndicator(
                          strokeWidth: 2.5, color: Colors.white),
                    )
                  : Text(_paso == 0 ? 'Aceptar y seguir' : 'Continuar'),
            ),
          ],
        ],
      ),
    );
  }
}
