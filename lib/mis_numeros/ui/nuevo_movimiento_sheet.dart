import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';

import '../../theme/app_colors.dart';
import '../data/movimientos_store.dart';
import '../models/movimiento.dart';
import 'thousands_formatter.dart';

class NuevoMovimientoSheet extends StatefulWidget {
  const NuevoMovimientoSheet({
    super.key,
    required this.tipo,
    required this.store,
  });
  final TipoMovimiento tipo;
  final MovimientosStore store;
  @override
  State<NuevoMovimientoSheet> createState() => _NuevoMovimientoSheetState();
}

class _NuevoMovimientoSheetState extends State<NuevoMovimientoSheet> {
  final _montoCtrl = TextEditingController();
  final _notaCtrl = TextEditingController();
  CategoriaGasto _categoria = CategoriaGasto.materiales;
  bool _saving = false;

  static const _cobro = Color(0xFF28B5CD);
  static const _gasto = Color(0xFFF75A6D);
  static const _retiro = Color(0xFFF59E0B); // ámbar — bolsillo personal

  bool get _esCobro => widget.tipo == TipoMovimiento.cobro;
  bool get _esGasto => widget.tipo == TipoMovimiento.gasto;
  bool get _esRetiro => widget.tipo == TipoMovimiento.retiro;

  Color get _color {
    if (_esCobro) return _cobro;
    if (_esRetiro) return _retiro;
    return _gasto;
  }

  String get _titulo {
    if (_esCobro) return '¿Cuánto cobraste?';
    if (_esRetiro) return '¿Cuánto te pasaste a tu bolsillo?';
    return '¿Cuánto gastaste del trabajo?';
  }

  String get _hintNota {
    if (_esCobro) return 'Ej: trabajo en lo de la Pantera';
    if (_esRetiro) return 'Ej: súper, alquiler, familia';
    return 'Ej: caños, nafta, herramientas';
  }

  String get _cta {
    if (_esCobro) return 'Guardar cobro';
    if (_esRetiro) return 'Confirmar retiro';
    return 'Guardar gasto';
  }

  @override
  void dispose() {
    _montoCtrl.dispose();
    _notaCtrl.dispose();
    super.dispose();
  }

  Future<void> _guardar() async {
    final monto = ThousandsFormatter.parse(_montoCtrl.text);
    if (monto == null || monto <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Escribí un monto válido')),
      );
      return;
    }
    setState(() => _saving = true);
    HapticFeedback.mediumImpact();
    final m = Movimiento(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      tipo: widget.tipo,
      monto: monto,
      fecha: DateTime.now(),
      nota: _notaCtrl.text.trim().isEmpty ? null : _notaCtrl.text.trim(),
      categoria: _esGasto ? _categoria : null,
    );
    final cloudOk = await widget.store.add(m);
    if (!mounted) return;
    final money =
        NumberFormat.currency(locale: 'es_AR', symbol: r'$', decimalDigits: 0);
    String base;
    if (_esCobro) {
      base = 'Listo: +${money.format(monto)}';
    } else if (_esRetiro) {
      base = 'Retiro a casa: ${money.format(monto)}';
    } else {
      base = 'Listo: -${money.format(monto)}';
    }
    Navigator.of(context).pop();
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(
        cloudOk ? '$base · nube' : '$base · solo local',
        style: const TextStyle(fontWeight: FontWeight.w600),
      ),
      backgroundColor: cloudOk ? _color : AppColors.danger,
    ));
  }

  @override
  Widget build(BuildContext context) {
    final bottom = MediaQuery.of(context).viewInsets.bottom;
    final color = _color;
    return Padding(
      padding: EdgeInsets.fromLTRB(24, 16, 24, 24 + bottom),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Center(
            child: Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: AppColors.border,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          const SizedBox(height: 16),
          Text(
            _titulo,
            style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w800),
          ),
          if (_esRetiro) ...[
            const SizedBox(height: 8),
            Text(
              'No es un gasto del negocio: es plata que te llevás a casa.',
              style: TextStyle(
                fontSize: 13,
                height: 1.35,
                color: Colors.grey.shade600,
              ),
            ),
          ],
          const SizedBox(height: 20),
          TextField(
            controller: _montoCtrl,
            autofocus: true,
            keyboardType: TextInputType.number,
            inputFormatters: [ThousandsFormatter()],
            style: const TextStyle(fontSize: 36, fontWeight: FontWeight.w800),
            textAlign: TextAlign.center,
            decoration: InputDecoration(
              prefixText: r'$ ',
              hintText: '0',
              filled: true,
              fillColor: color.withOpacity(0.06),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(16),
                borderSide: BorderSide(color: color.withOpacity(0.4)),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(16),
                borderSide: BorderSide(color: color, width: 2),
              ),
            ),
          ),
          if (_esGasto) ...[
            const SizedBox(height: 16),
            const Text('Categoría', style: TextStyle(fontWeight: FontWeight.w600)),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: CategoriaGasto.values
                  .where((c) => c != CategoriaGasto.ahorro)
                  .map((c) {
                return ChoiceChip(
                  label: Text(c.label),
                  selected: c == _categoria,
                  onSelected: (_) => setState(() => _categoria = c),
                  selectedColor: color.withOpacity(0.2),
                );
              }).toList(),
            ),
          ],
          const SizedBox(height: 16),
          TextField(
            controller: _notaCtrl,
            textInputAction: TextInputAction.done,
            onSubmitted: (_) => _guardar(),
            decoration: InputDecoration(
              labelText: 'Nota (opcional)',
              hintText: _hintNota,
            ),
          ),
          const SizedBox(height: 24),
          SizedBox(
            height: 56,
            child: FilledButton(
              style: FilledButton.styleFrom(backgroundColor: color),
              onPressed: _saving ? null : _guardar,
              child: _saving
                  ? const SizedBox(
                      width: 22,
                      height: 22,
                      child: CircularProgressIndicator(
                        strokeWidth: 2.5,
                        color: Colors.white,
                      ),
                    )
                  : Text(_cta),
            ),
          ),
        ],
      ),
    );
  }
}
