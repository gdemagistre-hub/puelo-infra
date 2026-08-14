import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../theme/app_colors.dart';
import '../data/metas_store.dart';
import '../data/movimientos_store.dart';
import '../models/meta_ahorro.dart';
import '../models/movimiento.dart';
import 'thousands_formatter.dart';

class MetasScreen extends StatefulWidget {
  const MetasScreen({
    super.key,
    required this.store,
    required this.movimientosStore,
  });

  final MetasStore store;
  final MovimientosStore movimientosStore;

  @override
  State<MetasScreen> createState() => _MetasScreenState();
}

class _MetasScreenState extends State<MetasScreen> {
  static const _primary = Color(0xFF28B5CD);
  final _money =
      NumberFormat.currency(locale: 'es_AR', symbol: r'$', decimalDigits: 0);

  @override
  void initState() {
    super.initState();
    widget.store.addListener(_onChange);
    widget.movimientosStore.addListener(_onChange);
  }

  @override
  void dispose() {
    widget.store.removeListener(_onChange);
    widget.movimientosStore.removeListener(_onChange);
    super.dispose();
  }

  void _onChange() {
    if (mounted) setState(() {});
  }

  double get _disponible => widget.movimientosStore.saldoTotal;

  double get _enMetas =>
      widget.store.items.fold<double>(0, (s, m) => s + m.ahorrado);

  Future<void> _nuevaMeta() async {
    final tituloCtrl = TextEditingController();
    final montoCtrl = TextEditingController();
    final ok = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) {
        final bottom = MediaQuery.of(ctx).viewInsets.bottom;
        return Padding(
          padding: EdgeInsets.fromLTRB(24, 16, 24, 24 + bottom),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Text('Nueva meta',
                  style: TextStyle(fontSize: 20, fontWeight: FontWeight.w700)),
              const SizedBox(height: 16),
              TextField(
                controller: tituloCtrl,
                autofocus: true,
                decoration: const InputDecoration(
                  labelText: '¿Para qué ahorrás?',
                  filled: true,
                  fillColor: Color(0xFFF8FAFC),
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: montoCtrl,
                keyboardType: TextInputType.number,
                inputFormatters: [ThousandsFormatter()],
                decoration: const InputDecoration(
                  labelText: '¿Cuánto necesitás?',
                  prefixText: r'$ ',
                  filled: true,
                  fillColor: Color(0xFFF8FAFC),
                ),
              ),
              const SizedBox(height: 20),
              FilledButton(
                onPressed: () => Navigator.pop(ctx, true),
                style: FilledButton.styleFrom(backgroundColor: _primary),
                child: const Text('Crear meta'),
              ),
            ],
          ),
        );
      },
    );
    if (ok != true) return;
    final titulo = tituloCtrl.text.trim();
    final objetivo = ThousandsFormatter.parse(montoCtrl.text);
    if (titulo.isEmpty || objetivo == null || objetivo <= 0) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Completá nombre y monto válido')),
        );
      }
      return;
    }
    await widget.store.add(MetaAhorro(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      titulo: titulo,
      objetivo: objetivo,
      ahorrado: 0,
      creada: DateTime.now(),
    ));
  }

  Future<void> _apartar(MetaAhorro meta) async {
    final disponible = _disponible;
    final ctrl = TextEditingController();
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Apartar a "${meta.titulo}"'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Disponible: ${_money.format(disponible)}',
                style: const TextStyle(
                    fontWeight: FontWeight.w600, color: _primary)),
            const SizedBox(height: 12),
            TextField(
              controller: ctrl,
              autofocus: true,
              keyboardType: TextInputType.number,
              inputFormatters: [ThousandsFormatter()],
              decoration: const InputDecoration(
                labelText: 'Monto a apartar',
                prefixText: r'$ ',
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Cancelar')),
          FilledButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('Apartar')),
        ],
      ),
    );
    if (ok != true) return;
    final monto = ThousandsFormatter.parse(ctrl.text);
    if (monto == null || monto <= 0) return;
    if (monto > disponible + 0.001) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content:
                  Text('No alcanza. Disponible: ${_money.format(disponible)}')),
        );
      }
      return;
    }
    await widget.movimientosStore.add(Movimiento(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      tipo: TipoMovimiento.gasto,
      monto: monto,
      fecha: DateTime.now(),
      nota: 'Meta: ${meta.titulo}',
      categoria: CategoriaGasto.ahorro,
    ));
    await widget.store.sumarAhorro(meta.id, monto);
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Apartaste ${_money.format(monto)} a ${meta.titulo}'),
        backgroundColor: _primary,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final store = widget.store;
    return Scaffold(
      backgroundColor: const Color(0xFFF1F5F9),
      appBar: AppBar(
        title: const Text('Metas'),
        backgroundColor: Colors.white,
        foregroundColor: _primary,
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _nuevaMeta,
        backgroundColor: _primary,
        foregroundColor: Colors.white,
        icon: const Icon(Icons.add),
        label: const Text('Nueva meta'),
      ),
      body: !store.loaded || !widget.movimientosStore.isLoaded
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.fromLTRB(20, 12, 20, 100),
              children: [
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: AppColors.border),
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text('Disponible',
                                style: TextStyle(
                                    color: AppColors.textMuted, fontSize: 12)),
                            Text(_money.format(_disponible),
                                style: const TextStyle(
                                    fontWeight: FontWeight.w800,
                                    color: _primary,
                                    fontSize: 18)),
                          ],
                        ),
                      ),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text('En metas',
                                style: TextStyle(
                                    color: AppColors.textMuted, fontSize: 12)),
                            Text(_money.format(_enMetas),
                                style: const TextStyle(
                                    fontWeight: FontWeight.w800,
                                    color: Color(0xFF734BE4),
                                    fontSize: 18)),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                if (store.items.isEmpty)
                  const Padding(
                    padding: EdgeInsets.all(24),
                    child: Text(
                      'Creá una meta y apartá desde el disponible.',
                      textAlign: TextAlign.center,
                      style: TextStyle(color: AppColors.textMuted),
                    ),
                  )
                else
                  ...store.items.map((m) {
                    final pct = (m.progreso * 100).round();
                    return Card(
                      margin: const EdgeInsets.only(bottom: 12),
                      elevation: 0,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                        side: const BorderSide(color: AppColors.border),
                      ),
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Expanded(
                                  child: Text(m.titulo,
                                      style: const TextStyle(
                                          fontWeight: FontWeight.w700,
                                          fontSize: 16)),
                                ),
                                if (!m.completada)
                                  IconButton(
                                    icon: const Icon(Icons.delete_outline,
                                        size: 20),
                                    onPressed: () => store.remove(m.id),
                                  ),
                              ],
                            ),
                            Text(
                              '${_money.format(m.ahorrado)} de ${_money.format(m.objetivo)}',
                              style: const TextStyle(color: AppColors.textMuted),
                            ),
                            const SizedBox(height: 8),
                            LinearProgressIndicator(
                              value: m.progreso,
                              minHeight: 8,
                              borderRadius: BorderRadius.circular(8),
                              color: m.completada
                                  ? const Color(0xFF16A34A)
                                  : _primary,
                              backgroundColor: const Color(0xFFE2E8F0),
                            ),
                            const SizedBox(height: 6),
                            Text(m.completada ? '¡Meta cumplida!' : '$pct%',
                                style: TextStyle(
                                  fontWeight: FontWeight.w600,
                                  color: m.completada
                                      ? const Color(0xFF16A34A)
                                      : _primary,
                                )),
                            if (!m.completada) ...[
                              const SizedBox(height: 10),
                              SizedBox(
                                width: double.infinity,
                                child: FilledButton.icon(
                                  onPressed: () => _apartar(m),
                                  style: FilledButton.styleFrom(
                                      backgroundColor: _primary),
                                  icon: const Icon(Icons.savings_outlined),
                                  label: const Text('Apartar del disponible'),
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),
                    );
                  }),
              ],
            ),
    );
  }
}
