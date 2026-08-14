import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../theme/app_colors.dart';
import '../data/fiados_store.dart';
import '../data/movimientos_store.dart';
import '../models/fiado.dart';
import '../models/movimiento.dart';
import 'thousands_formatter.dart';

class FiadosScreen extends StatefulWidget {
  const FiadosScreen({
    super.key,
    required this.store,
    required this.movimientosStore,
  });

  final FiadosStore store;
  final MovimientosStore movimientosStore;

  @override
  State<FiadosScreen> createState() => _FiadosScreenState();
}

class _FiadosScreenState extends State<FiadosScreen> {
  static const _accent = Color(0xFF7C3AED); // violeta — plata en la calle
  final _money =
      NumberFormat.currency(locale: 'es_AR', symbol: r'$', decimalDigits: 0);

  @override
  void initState() {
    super.initState();
    widget.store.addListener(_onChange);
  }

  @override
  void dispose() {
    widget.store.removeListener(_onChange);
    super.dispose();
  }

  void _onChange() {
    if (mounted) setState(() {});
  }

  Future<void> _nuevoFiado() async {
    final nombreCtrl = TextEditingController();
    final montoCtrl = TextEditingController();
    final notaCtrl = TextEditingController();
    DateTime? fechaAcordada;

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
                  const Text(
                    'Anotar fiado',
                    style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    'Plata que te deben. No entra al saldo hasta que cobrés.',
                    style: TextStyle(
                      fontSize: 13,
                      height: 1.35,
                      color: Colors.grey.shade600,
                    ),
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    controller: nombreCtrl,
                    autofocus: true,
                    textCapitalization: TextCapitalization.words,
                    decoration: const InputDecoration(
                      labelText: 'Nombre del cliente',
                      hintText: 'Ej: Carlos Pérez',
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
                      labelText: 'Monto',
                      prefixText: r'$ ',
                      filled: true,
                      fillColor: Color(0xFFF8FAFC),
                    ),
                  ),
                  const SizedBox(height: 12),
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    title: Text(
                      fechaAcordada == null
                          ? 'Fecha de cobro (opcional)'
                          : 'Cobrar el ${DateFormat('dd/MM/yyyy').format(fechaAcordada!)}',
                      style: const TextStyle(fontSize: 14),
                    ),
                    trailing: Icon(
                      Icons.calendar_today_outlined,
                      color: _accent,
                      size: 20,
                    ),
                    onTap: () async {
                      final now = DateTime.now();
                      final picked = await showDatePicker(
                        context: ctx,
                        initialDate: fechaAcordada ?? now,
                        firstDate: now.subtract(const Duration(days: 30)),
                        lastDate: now.add(const Duration(days: 365)),
                      );
                      if (picked != null) {
                        setModal(() => fechaAcordada = picked);
                      }
                    },
                  ),
                  TextField(
                    controller: notaCtrl,
                    decoration: const InputDecoration(
                      labelText: 'Nota (opcional)',
                      hintText: 'Ej: arreglo caño cocina',
                      filled: true,
                      fillColor: Color(0xFFF8FAFC),
                    ),
                  ),
                  const SizedBox(height: 20),
                  FilledButton(
                    onPressed: () => Navigator.pop(ctx, true),
                    style: FilledButton.styleFrom(
                      backgroundColor: _accent,
                      minimumSize: const Size.fromHeight(48),
                    ),
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
    final nombre = nombreCtrl.text.trim();
    final monto = ThousandsFormatter.parse(montoCtrl.text);
    if (nombre.isEmpty || monto == null || monto <= 0) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Completá nombre y monto válido')),
        );
      }
      return;
    }
    await widget.store.add(Fiado(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      nombre: nombre,
      monto: monto,
      creado: DateTime.now(),
      fechaAcordada: fechaAcordada,
      nota: notaCtrl.text.trim().isEmpty ? null : notaCtrl.text.trim(),
    ));
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Anotaste fiado de ${_money.format(monto)} a $nombre'),
          backgroundColor: _accent,
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  Future<void> _cobrar(Fiado f) async {
    final ctrl = TextEditingController(
      text: NumberFormat('#,###', 'es_AR').format(f.monto.round()),
    );
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('¿Cobró ${f.nombre}?'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Se va a registrar como cobro del día y se cierra el fiado.',
              style: TextStyle(height: 1.4, color: Colors.grey.shade700),
            ),
            const SizedBox(height: 14),
            TextField(
              controller: ctrl,
              autofocus: true,
              keyboardType: TextInputType.number,
              inputFormatters: [ThousandsFormatter()],
              decoration: const InputDecoration(
                labelText: 'Monto cobrado',
                prefixText: r'$ ',
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: const Color(0xFF28B5CD)),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Cobré'),
          ),
        ],
      ),
    );
    if (ok != true) return;
    final monto = ThousandsFormatter.parse(ctrl.text);
    if (monto == null || monto <= 0) return;

    // 1) Movimiento de cobro real
    await widget.movimientosStore.add(Movimiento(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      tipo: TipoMovimiento.cobro,
      monto: monto,
      fecha: DateTime.now(),
      nota: 'Fiado: ${f.nombre}',
    ));

    // 2) Cerrar fiado
    await widget.store.marcarCobrado(f.id, montoCobrado: monto);

    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          'Cobrado ${_money.format(monto)} de ${f.nombre} · entró como cobro',
        ),
        backgroundColor: const Color(0xFF28B5CD),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  String _subtitulo(Fiado f) {
    final parts = <String>[];
    if (f.fechaAcordada != null) {
      final d = f.fechaAcordada!;
      final hoy = DateTime.now();
      final soloDia = DateTime(d.year, d.month, d.day);
      final hoyDia = DateTime(hoy.year, hoy.month, hoy.day);
      if (soloDia.isBefore(hoyDia)) {
        parts.add('Acordado ${DateFormat('dd/MM').format(d)} · vencido');
      } else if (soloDia == hoyDia) {
        parts.add('Acordado para hoy');
      } else {
        parts.add('Acordado ${DateFormat('dd/MM').format(d)}');
      }
    } else {
      final dias = DateTime.now().difference(f.creado).inDays;
      if (dias == 0) {
        parts.add('Hoy');
      } else if (dias == 1) {
        parts.add('Hace 1 día');
      } else {
        parts.add('Hace $dias días');
      }
    }
    if (f.nota != null && f.nota!.isNotEmpty) {
      parts.add(f.nota!);
    }
    return parts.join(' · ');
  }

  @override
  Widget build(BuildContext context) {
    final store = widget.store;
    final lista = store.pendientes;
    final total = store.totalPendiente;

    return Scaffold(
      backgroundColor: const Color(0xFFF1F5F9),
      appBar: AppBar(
        title: const Text('Me deben'),
        backgroundColor: Colors.white,
        foregroundColor: _accent,
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _nuevoFiado,
        backgroundColor: _accent,
        foregroundColor: Colors.white,
        icon: const Icon(Icons.add),
        label: const Text('Anotar'),
      ),
      body: !store.loaded
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.fromLTRB(20, 12, 20, 100),
              children: [
                Container(
                  padding: const EdgeInsets.all(18),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: AppColors.border),
                  ),
                  child: Row(
                    children: [
                      Container(
                        width: 44,
                        height: 44,
                        decoration: BoxDecoration(
                          color: _accent.withOpacity(0.12),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: const Icon(
                          Icons.handshake_outlined,
                          color: _accent,
                        ),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'Total pendiente',
                              style: TextStyle(
                                color: AppColors.textMuted,
                                fontSize: 12,
                              ),
                            ),
                            Text(
                              _money.format(total),
                              style: const TextStyle(
                                fontWeight: FontWeight.w800,
                                fontSize: 22,
                                color: _accent,
                              ),
                            ),
                            Text(
                              lista.isEmpty
                                  ? 'Nadie te debe'
                                  : '${lista.length} pendiente${lista.length == 1 ? '' : 's'}',
                              style: TextStyle(
                                fontSize: 12,
                                color: Colors.grey.shade600,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                if (lista.isEmpty)
                  Container(
                    padding: const EdgeInsets.all(24),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: AppColors.border),
                    ),
                    child: Column(
                      children: [
                        Icon(
                          Icons.menu_book_outlined,
                          size: 48,
                          color: _accent.withOpacity(0.5),
                        ),
                        const SizedBox(height: 12),
                        const Text(
                          'Libreta vacía',
                          style: TextStyle(
                            fontWeight: FontWeight.w800,
                            fontSize: 16,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'Anotá a quién le fiás. Cuando cobrés, tocá “Cobré” '
                          'y entra como cobro del día.',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontSize: 13,
                            height: 1.4,
                            color: Colors.grey.shade600,
                          ),
                        ),
                      ],
                    ),
                  )
                else
                  ...lista.map((f) {
                    final vencido = f.fechaAcordada != null &&
                        DateTime(
                          f.fechaAcordada!.year,
                          f.fechaAcordada!.month,
                          f.fechaAcordada!.day,
                        ).isBefore(DateTime(
                          DateTime.now().year,
                          DateTime.now().month,
                          DateTime.now().day,
                        ));
                    return Card(
                      margin: const EdgeInsets.only(bottom: 10),
                      elevation: 0,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                        side: BorderSide(
                          color: vencido
                              ? const Color(0xFFF59E0B).withOpacity(0.5)
                              : AppColors.border,
                        ),
                      ),
                      child: Padding(
                        padding: const EdgeInsets.fromLTRB(14, 12, 8, 12),
                        child: Row(
                          children: [
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    f.nombre,
                                    style: const TextStyle(
                                      fontWeight: FontWeight.w800,
                                      fontSize: 15,
                                    ),
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    _subtitulo(f),
                                    style: TextStyle(
                                      fontSize: 12,
                                      color: vencido
                                          ? const Color(0xFFB45309)
                                          : AppColors.textMuted,
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    _money.format(f.monto),
                                    style: const TextStyle(
                                      fontWeight: FontWeight.w800,
                                      fontSize: 16,
                                      color: _accent,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            Column(
                              children: [
                                FilledButton(
                                  onPressed: () => _cobrar(f),
                                  style: FilledButton.styleFrom(
                                    backgroundColor: const Color(0xFF28B5CD),
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 14,
                                      vertical: 8,
                                    ),
                                    minimumSize: Size.zero,
                                  ),
                                  child: const Text(
                                    'Cobré',
                                    style: TextStyle(
                                      fontWeight: FontWeight.w700,
                                      fontSize: 13,
                                    ),
                                  ),
                                ),
                                IconButton(
                                  icon: const Icon(
                                    Icons.delete_outline,
                                    size: 20,
                                  ),
                                  color: Colors.grey.shade500,
                                  onPressed: () => widget.store.remove(f.id),
                                ),
                              ],
                            ),
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
