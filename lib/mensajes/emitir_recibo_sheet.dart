import 'package:flutter/material.dart';

import '../mis_numeros/ui/thousands_formatter.dart';
import '../theme/prox_sounds.dart';
import 'mensajes_service.dart';

class EmitirReciboSheet extends StatefulWidget {
  /// Si ya estás en un hilo / tarjeta, pasá la contraparte.
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
  String? _nombreResuelto;

  static const _conceptos = [
    ('sena', 'Seña'),
    ('anticipo', 'Anticipo'),
    ('saldo', 'Saldo'),
    ('pago_total', 'Pago total'),
    ('otro', 'Otro'),
  ];

  bool get _fijo =>
      widget.contraparteUidFijo != null &&
      widget.contraparteUidFijo!.trim().isNotEmpty;

  @override
  void initState() {
    super.initState();
    if (_fijo) {
      _uidCtrl.text = widget.contraparteUidFijo!.trim();
      _nombreResuelto = widget.contraparteNombre?.trim();
      if (_nombreResuelto == null || _nombreResuelto!.isEmpty) {
        _resolverNombre(_uidCtrl.text);
      }
    }
  }

  Future<void> _resolverNombre(String uid) async {
    final n = await MensajesService.instance.resolveDisplayName(uid);
    if (!mounted) return;
    setState(() => _nombreResuelto = n);
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
      final monto = ThousandsFormatter.parse(_montoCtrl.text);
      if (uid.isEmpty) {
        throw StateError(
          'Elegí a quién emitir: abrí su tarjeta digital y tocá Emitir recibo.',
        );
      }
      if (monto == null || monto <= 0) throw StateError('Monto inválido');

      final res = await MensajesService.instance.emitirRecibo(
        contraparteUid: uid,
        monto: monto,
        concepto: _concepto,
        nota: _notaCtrl.text,
        origen: _fijo ? 'tarjeta' : 'mensajes',
      );
      if (!mounted) return;
      // Sonido de confirmación PROX (recibo emitido).
      ProxSounds.playConfirm();
      Navigator.pop(context, res);
      final hash = (res['content_hash'] as String?) ?? '';
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Recibo emitido · sellado ${hash.length >= 8 ? hash.substring(0, 8) : hash}…',
          ),
          behavior: SnackBarBehavior.floating,
        ),
      );
    } catch (e) {
      setState(() {
        _error = e.toString()
            .replaceFirst('Exception: ', '')
            .replaceFirst('StateError: ', '')
            .replaceFirst('FirebaseFunctionsException: ', '');
        _loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final bottom = MediaQuery.of(context).viewInsets.bottom;
    final paraLabel = (_nombreResuelto != null && _nombreResuelto!.isNotEmpty)
        ? _nombreResuelto!
        : (_fijo ? 'Cargando…' : null);

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
              style: TextStyle(
                fontSize: 13,
                color: Color(0xFF64748B),
                height: 1.4,
              ),
            ),
            const SizedBox(height: 16),
            if (_fijo) ...[
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: const Color(0xFFE6F7FA),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: const Color(0xFF28B5CD).withOpacity(0.35)),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.person_outline, color: Color(0xFF1A8FA3)),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Para',
                            style: TextStyle(
                              fontSize: 11,
                              color: Color(0xFF64748B),
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          Text(
                            paraLabel ?? widget.contraparteUidFijo!,
                            style: const TextStyle(
                              fontWeight: FontWeight.w800,
                              fontSize: 16,
                              color: Color(0xFF0F172A),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ] else ...[
              TextField(
                controller: _uidCtrl,
                decoration: const InputDecoration(
                  labelText: 'UID de la otra persona',
                  hintText: 'Mejor: abrí su tarjeta → Emitir recibo',
                  border: OutlineInputBorder(),
                ),
                onChanged: (v) {
                  if (v.trim().length > 10) _resolverNombre(v.trim());
                },
              ),
              if (_nombreResuelto != null && _nombreResuelto!.isNotEmpty) ...[
                const SizedBox(height: 8),
                Text(
                  'Para: $_nombreResuelto',
                  style: const TextStyle(
                    fontWeight: FontWeight.w700,
                    color: Color(0xFF1A8FA3),
                  ),
                ),
              ],
              const SizedBox(height: 8),
              const Text(
                'Recomendado: desde la tarjeta digital de la otra persona, '
                'tocá “Emitir recibo” (ahí no hace falta el UID).',
                style: TextStyle(fontSize: 12, color: Color(0xFF94A3B8), height: 1.35),
              ),
            ],
            const SizedBox(height: 14),
            TextField(
              controller: _montoCtrl,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              inputFormatters: [
                ThousandsFormatter(allowDecimal: true),
              ],
              decoration: const InputDecoration(
                labelText: 'Monto (ARS)',
                prefixText: '\$ ',
                hintText: '15.000',
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
