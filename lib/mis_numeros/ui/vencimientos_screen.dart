import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';

import '../../theme/app_colors.dart';
import '../data/vencimientos_store.dart';
import '../models/vencimiento.dart';

class VencimientosScreen extends StatefulWidget {
  const VencimientosScreen({super.key, required this.store});
  final VencimientosStore store;

  @override
  State<VencimientosScreen> createState() => _VencimientosScreenState();
}

class _VencimientosScreenState extends State<VencimientosScreen> {
  static const _primary = Color(0xFF28B5CD);
  final _money =
      NumberFormat.currency(locale: 'es_AR', symbol: r'$', decimalDigits: 0);
  final _date = DateFormat('dd/MM/yyyy');

  static const _plantillas = [
    'Monotributo',
    'Luz',
    'Gas',
    'Alquiler herramienta',
    'Cuota prestamo',
    'Internet',
  ];

  @override
  void initState() {
    super.initState();
    widget.store.addListener(_refresh);
  }

  @override
  void dispose() {
    widget.store.removeListener(_refresh);
    super.dispose();
  }

  void _refresh() {
    if (mounted) setState(() {});
  }

  Future<void> _nuevo({String? tituloInicial}) async {
    final tituloCtrl = TextEditingController(text: tituloInicial ?? '');
    final montoCtrl = TextEditingController();
    DateTime fecha = DateTime.now().add(const Duration(days: 7));

    final ok = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) {
        final bottom = MediaQuery.of(ctx).viewInsets.bottom;
        return StatefulBuilder(
          builder: (ctx, setModal) {
            return Padding(
              padding: EdgeInsets.fromLTRB(24, 16, 24, 24 + bottom),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const Text('Nuevo vencimiento',
                      style:
                          TextStyle(fontSize: 20, fontWeight: FontWeight.w700)),
                  const SizedBox(height: 12),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: _plantillas
                        .map((p) => ActionChip(
                              label: Text(p),
                              onPressed: () =>
                                  setModal(() => tituloCtrl.text = p),
                            ))
                        .toList(),
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    controller: tituloCtrl,
                    decoration: const InputDecoration(
                      labelText: 'Qué es',
                      filled: true,
                      fillColor: Color(0xFFF8FAFC),
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: montoCtrl,
                    keyboardType:
                        const TextInputType.numberWithOptions(decimal: true),
                    inputFormatters: [
                      FilteringTextInputFormatter.allow(RegExp(r'[0-9.,]')),
                    ],
                    decoration: const InputDecoration(
                      labelText: 'Monto (opcional)',
                      prefixText: r'$ ',
                      filled: true,
                      fillColor: Color(0xFFF8FAFC),
                    ),
                  ),
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    title: const Text('Fecha'),
                    subtitle: Text(_date.format(fecha)),
                    trailing: const Icon(Icons.calendar_today),
                    onTap: () async {
                      final picked = await showDatePicker(
                        context: ctx,
                        initialDate: fecha,
                        firstDate:
                            DateTime.now().subtract(const Duration(days: 1)),
                        lastDate:
                            DateTime.now().add(const Duration(days: 365 * 2)),
                      );
                      if (picked != null) setModal(() => fecha = picked);
                    },
                  ),
                  FilledButton(
                    onPressed: () => Navigator.pop(ctx, true),
                    style: FilledButton.styleFrom(backgroundColor: _primary),
                    child: const Text('Guardar'),
                  ),
                ],
              ),
            );
          },
        );
      },
    );

    if (ok != true) return;
    final titulo = tituloCtrl.text.trim();
    if (titulo.isEmpty) return;
    final raw = montoCtrl.text.replaceAll('.', '').replaceAll(',', '.');
    final monto = double.tryParse(raw);
    await widget.store.add(Vencimiento(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      titulo: titulo,
      fecha: fecha,
      monto: monto,
    ));
  }

  @override
  Widget build(BuildContext context) {
    final items = widget.store.items;
    final hoy = DateTime.now();
    final hoySolo = DateTime(hoy.year, hoy.month, hoy.day);
    final vencidos = items.where((v) {
      final d = DateTime(v.fecha.year, v.fecha.month, v.fecha.day);
      return !v.pagado && d.isBefore(hoySolo);
    }).toList();
    final porVencer = items.where((v) {
      final d = DateTime(v.fecha.year, v.fecha.month, v.fecha.day);
      return !v.pagado && !d.isBefore(hoySolo);
    }).toList();
    final pagados = items.where((v) => v.pagado).toList();

    return Scaffold(
      backgroundColor: const Color(0xFFF1F5F9),
      appBar: AppBar(
        title: const Text('Vencimientos'),
        backgroundColor: Colors.white,
        foregroundColor: _primary,
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _nuevo(),
        backgroundColor: _primary,
        foregroundColor: Colors.white,
        icon: const Icon(Icons.add),
        label: const Text('Agregar'),
      ),
      body: !widget.store.loaded
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.fromLTRB(20, 12, 20, 100),
              children: [
                if (items.isEmpty)
                  const Padding(
                    padding: EdgeInsets.all(24),
                    child: Text(
                      'Anotá monotributo, servicios o cuotas.',
                      textAlign: TextAlign.center,
                      style: TextStyle(color: AppColors.textMuted),
                    ),
                  )
                else ...[
                  if (vencidos.isNotEmpty) ...[
                    _section('Vencidos', const Color(0xFFDC2626)),
                    ...vencidos.map(_tile),
                  ],
                  if (porVencer.isNotEmpty) ...[
                    _section('Por vencer', _primary),
                    ...porVencer.map(_tile),
                  ],
                  if (pagados.isNotEmpty) ...[
                    _section('Pagados', const Color(0xFF16A34A)),
                    ...pagados.map(_tile),
                  ],
                ],
              ],
            ),
    );
  }

  Widget _section(String t, Color c) => Padding(
        padding: const EdgeInsets.only(bottom: 8, top: 4),
        child: Text(t,
            style: TextStyle(fontWeight: FontWeight.w800, color: c, fontSize: 14)),
      );

  Widget _tile(Vencimiento v) {
    final hoy = DateTime.now();
    final hoySolo = DateTime(hoy.year, hoy.month, hoy.day);
    final soloDia = DateTime(v.fecha.year, v.fecha.month, v.fecha.day);
    final esPasado = soloDia.isBefore(hoySolo) && !v.pagado;
    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: const BorderSide(color: AppColors.border),
      ),
      child: ListTile(
        leading: Icon(
          v.pagado
              ? Icons.check_circle
              : esPasado
                  ? Icons.warning_amber
                  : Icons.event,
          color: v.pagado
              ? const Color(0xFF16A34A)
              : esPasado
                  ? const Color(0xFFDC2626)
                  : _primary,
        ),
        title: Text(
          v.titulo,
          style: TextStyle(
            decoration: v.pagado ? TextDecoration.lineThrough : null,
            fontWeight: FontWeight.w600,
          ),
        ),
        subtitle: Text([
          _date.format(v.fecha),
          if (v.monto != null) _money.format(v.monto),
        ].join(' · ')),
        trailing: IconButton(
          icon: Icon(v.pagado ? Icons.undo : Icons.check),
          onPressed: () => widget.store.togglePagado(v.id),
        ),
        onLongPress: () => widget.store.remove(v.id),
      ),
    );
  }
}
