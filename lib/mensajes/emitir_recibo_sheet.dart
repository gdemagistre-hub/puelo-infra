import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'mensajes_service.dart';

class EmitirReciboSheet extends StatefulWidget {
  /// Si ya estás en un hilo, pasá la contraparte.
  final String? contraparteUidFijo;
  final String? contraparteNombre;

  const EmitirReciboSheet({
    super.key,
    this.contraparteUidFijo,
    this.contraparteNombre,
  });

  @override
  State<EmitirReciboSheet> createState() => _EmitirReciboSheetState();
}

class _EmitirReciboSheetState extends State<EmitirReciboSheet> {
  final _uidCtrl = TextEditingController();
  final _montoCtrl = TextEditingController();
  final _notaCtrl = TextEditingController();
  String _concepto = 'sena';
  bool _loading = false;
  String? _error;

  static const _conceptos = [
    ('sena', 'Seña'),
    ('anticipo', 'Anticipo'),
    ('saldo', 'Saldo'),
    ('pago_total', 'Pago total'),
    ('otro', 'Otro'),
  ];

  @override
  void initState() {
    super.initState();
    if (widget.contraparteUidFijo != null) {
      _uidCtrl.text = widget.contraparteUidFijo!;
    }
  }

  @override
  void dispose() {
    _uidCtrl.dispose();
    _montoCtrl.dispose();
    _notaCtrl.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    setState(() {
      _error = null;
      _loading = true;
    });
    try {
      final uid = _uidCtrl.text.trim();
      final montoRaw =
          _montoCtrl.text.trim().replaceAll('.', '').replaceAll(',', '.');
      final monto = double.tryParse(montoRaw);
      if (uid.isEmpty) throw StateError('Indicá el UID de la otra persona');
      if (monto == null || monto <= 0) throw StateError('Monto inválido');

      final res = await MensajesService.instance.emitirRecibo(
        contraparteUid: uid,
        monto: monto,
        concepto: _concepto,
        nota: _notaCtrl.text,
      );
      if (!mounted) return;
      Navigator.pop(context, res);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Recibo emitido · sellado ${((res['content_hash'] as String?) ?? '').length >= 8 ? (res['content_hash'] as String).substring(0, 8) : ''}…',
          ),
          behavior: SnackBarBehavior.floating,
        ),
      );
    } catch (e) {
      setState(() {
        _error = e.toString().replaceFirst('Exception: ', '');
        _loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final bottom = MediaQuery.of(context).viewInsets.bottom;
    final fijo = widget.contraparteUidFijo != null;

    return Padding(
      padding: EdgeInsets.fromLTRB(20, 16, 20, 20 + bottom),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Center(
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: const Color(0xFFCBD5E1),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 16),
            const Text(
              'Emitir recibo',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 6),
            const Text(
              'Quedará registrado una sola vez, con firma del contenido. '
              'No se podrá editar ni borrar.',
              style: TextStyle(fontSize: 13, color: Color(0xFF64748B), height: 1.4),
            ),
            const SizedBox(height: 16),
            if (fijo && widget.contraparteNombre != null)
              Text(
                'Para: ${widget.contraparteNombre}',
                style: const TextStyle(fontWeight: FontWeight.w700),
              )
            else ...[
              TextField(
                controller: _uidCtrl,
                enabled: !fijo,
                decoration: const InputDecoration(
                  labelText: 'UID de la otra persona',
                  hintText: 'uid de Firebase Auth / usuarios',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 8),
              const Text(
                'Por ahora se usa el UID (luego se elige desde la tarjeta o contactos).',
                style: TextStyle(fontSize: 11, color: Color(0xFF94A3B8)),
              ),
            ],
            const SizedBox(height: 14),
            TextField(
              controller: _montoCtrl,
              keyboardType:
                  const TextInputType.numberWithOptions(decimal: true),
              inputFormatters: [
                FilteringTextInputFormatter.allow(RegExp(r'[0-9.,]')),
              ],
              decoration: const InputDecoration(
                labelText: 'Monto (ARS)',
                prefixText: '\$ ',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 14),
            const Text('Concepto', style: TextStyle(fontWeight: FontWeight.w700)),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: _conceptos.map((c) {
                final sel = _concepto == c.$1;
                return ChoiceChip(
                  label: Text(c.$2),
                  selected: sel,
                  onSelected: (_) => setState(() => _concepto = c.$1),
                  selectedColor: const Color(0xFF28B5CD).withOpacity(0.2),
                );
              }).toList(),
            ),
            const SizedBox(height: 14),
            TextField(
              controller: _notaCtrl,
              maxLength: 200,
              decoration: const InputDecoration(
                labelText: 'Nota (opcional)',
                border: OutlineInputBorder(),
              ),
            ),
            if (_error != null) ...[
              const SizedBox(height: 8),
              Text(
                _error!,
                style: const TextStyle(color: Color(0xFFB91C1C), fontSize: 13),
              ),
            ],
            const SizedBox(height: 12),
            FilledButton(
              onPressed: _loading ? null : _submit,
              style: FilledButton.styleFrom(
                backgroundColor: const Color(0xFF28B5CD),
                padding: const EdgeInsets.symmetric(vertical: 14),
              ),
              child: _loading
                  ? const SizedBox(
                      height: 22,
                      width: 22,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                  : const Text(
                      'Registrar recibo',
                      style: TextStyle(fontWeight: FontWeight.w800),
                    ),
            ),
          ],
        ),
      ),
    );
  }
}
