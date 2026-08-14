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
  static const _fondoAccent = Color(0xFF0F766E); // teal oscuro / sobrio
  static const _fondoBg = Color(0xFFECFDF5);
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

  Future<void> _crearFondo() async {
    final montoCtrl = TextEditingController(text: '50.000');
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
              const Text(
                'Fondo días flojos',
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800),
              ),
              const SizedBox(height: 8),
              Text(
                'Colchón para cuando no se puede laburar o se rompe algo. '
                'No es para vacaciones ni compras.',
                style: TextStyle(
                  fontSize: 13,
                  height: 1.4,
                  color: Colors.grey.shade600,
                ),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: montoCtrl,
                autofocus: true,
                keyboardType: TextInputType.number,
                inputFormatters: [ThousandsFormatter()],
                decoration: const InputDecoration(
                  labelText: '¿Hasta cuánto querés llegar?',
                  prefixText: r'$ ',
                  filled: true,
                  fillColor: Color(0xFFF8FAFC),
                ),
              ),
              const SizedBox(height: 20),
              FilledButton(
                onPressed: () => Navigator.pop(ctx, true),
                style: FilledButton.styleFrom(backgroundColor: _fondoAccent),
                child: const Text('Armar fondo'),
              ),
            ],
          ),
        );
      },
    );
    if (ok != true) return;
    final objetivo = ThousandsFormatter.parse(montoCtrl.text) ?? 50000;
    if (objetivo <= 0) return;
    final meta = await widget.store.asegurarFondoEmergencia(objetivo: objetivo);
    if (meta == null && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Ya tenés un fondo de emergencia')),
      );
    }
  }

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
              const Text(
                'Nueva meta',
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: tituloCtrl,
                autofocus: true,
                decoration: const InputDecoration(
                  labelText: '¿Para qué ahorrás?',
                  hintText: 'Vacaciones, herramientas…',
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
        title: Text(
          meta.esFondoEmergencia
              ? 'Sumar al fondo'
              : 'Apartar a "${meta.titulo}"',
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Disponible: ${_money.format(disponible)}',
              style: const TextStyle(
                fontWeight: FontWeight.w600,
                color: _primary,
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: ctrl,
              autofocus: true,
              keyboardType: TextInputType.number,
              inputFormatters: [ThousandsFormatter()],
              decoration: const InputDecoration(
                labelText: 'Monto',
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
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Sumar'),
          ),
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
                Text('No alcanza. Disponible: ${_money.format(disponible)}'),
          ),
        );
      }
      return;
    }
    await widget.movimientosStore.add(Movimiento(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      tipo: TipoMovimiento.gasto,
      monto: monto,
      fecha: DateTime.now(),
      nota: meta.esFondoEmergencia
          ? 'Fondo días flojos'
          : 'Meta: ${meta.titulo}',
      categoria: CategoriaGasto.ahorro,
    ));
    await widget.store.sumarAhorro(meta.id, monto);
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Apartaste ${_money.format(monto)}'),
        backgroundColor: meta.esFondoEmergencia ? _fondoAccent : _primary,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  Future<void> _usarFondo(MetaAhorro meta) async {
    if (meta.ahorrado <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('El fondo todavía está vacío')),
      );
      return;
    }
    final ctrl = TextEditingController(
      text: NumberFormat('#,###', 'es_AR').format(meta.ahorrado.round()),
    );
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('¿Usar el colchón?'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Estás sacando plata del Fondo días flojos.\n'
              'Disponible en el fondo: ${_money.format(meta.ahorrado)}',
              style: TextStyle(height: 1.4, color: Colors.grey.shade800),
            ),
            const SizedBox(height: 14),
            TextField(
              controller: ctrl,
              autofocus: true,
              keyboardType: TextInputType.number,
              inputFormatters: [ThousandsFormatter()],
              decoration: const InputDecoration(
                labelText: 'Monto a usar',
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
            style: FilledButton.styleFrom(backgroundColor: _fondoAccent),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Sí, usar'),
          ),
        ],
      ),
    );
    if (ok != true) return;
    final monto = ThousandsFormatter.parse(ctrl.text);
    if (monto == null || monto <= 0) return;
    if (monto > meta.ahorrado + 0.001) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'En el fondo hay ${_money.format(meta.ahorrado)}',
            ),
          ),
        );
      }
      return;
    }
    final done = await widget.store.restarAhorro(meta.id, monto);
    if (!mounted) return;
    if (done) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Usaste ${_money.format(monto)} del colchón'),
          backgroundColor: _fondoAccent,
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  Future<void> _confirmarBorrar(MetaAhorro meta) async {
    if (meta.esFondoEmergencia) {
      final ok = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text('¿Borrar el fondo?'),
          content: const Text(
            'Vas a eliminar el Fondo días flojos. '
            'La plata ya apartada deja de figurar acá.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Cancelar'),
            ),
            FilledButton(
              style: FilledButton.styleFrom(
                backgroundColor: const Color(0xFFB91C1C),
              ),
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('Borrar'),
            ),
          ],
        ),
      );
      if (ok != true) return;
    }
    await widget.store.remove(meta.id);
  }

  Widget _cardFondo(MetaAhorro m) {
    final pct = (m.progreso * 100).round();
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: _fondoBg,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: _fondoAccent.withOpacity(0.35), width: 1.5),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: _fondoAccent.withOpacity(0.15),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(
                  Icons.shield_outlined,
                  color: _fondoAccent,
                  size: 22,
                ),
              ),
              const SizedBox(width: 12),
              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Fondo días flojos',
                      style: TextStyle(
                        fontWeight: FontWeight.w800,
                        fontSize: 16,
                        color: Color(0xFF134E4A),
                      ),
                    ),
                    SizedBox(height: 2),
                    Text(
                      'Para imprevistos · no es ahorro de gusto',
                      style: TextStyle(
                        fontSize: 12,
                        color: Color(0xFF0F766E),
                      ),
                    ),
                  ],
                ),
              ),
              IconButton(
                icon: const Icon(Icons.delete_outline, size: 20),
                color: Colors.grey.shade500,
                onPressed: () => _confirmarBorrar(m),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Text(
            '${_money.format(m.ahorrado)} de ${_money.format(m.objetivo)}',
            style: const TextStyle(
              fontWeight: FontWeight.w700,
              color: Color(0xFF134E4A),
            ),
          ),
          const SizedBox(height: 8),
          LinearProgressIndicator(
            value: m.progreso,
            minHeight: 10,
            borderRadius: BorderRadius.circular(8),
            color: _fondoAccent,
            backgroundColor: _fondoAccent.withOpacity(0.15),
          ),
          const SizedBox(height: 6),
          Text(
            '$pct%',
            style: const TextStyle(
              fontWeight: FontWeight.w600,
              color: _fondoAccent,
            ),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: FilledButton.icon(
                  onPressed: () => _apartar(m),
                  style: FilledButton.styleFrom(
                    backgroundColor: _fondoAccent,
                    padding: const EdgeInsets.symmetric(vertical: 12),
                  ),
                  icon: const Icon(Icons.add, size: 18),
                  label: const Text('Sumar'),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: m.ahorrado > 0 ? () => _usarFondo(m) : null,
                  style: OutlinedButton.styleFrom(
                    foregroundColor: _fondoAccent,
                    side: BorderSide(color: _fondoAccent.withOpacity(0.6)),
                    padding: const EdgeInsets.symmetric(vertical: 12),
                  ),
                  icon: const Icon(Icons.warning_amber_rounded, size: 18),
                  label: const Text('Usar'),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _cardEmptyFondo() {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: _fondoAccent.withOpacity(0.4),
          style: BorderStyle.solid,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.shield_outlined, color: _fondoAccent, size: 28),
              const SizedBox(width: 10),
              const Expanded(
                child: Text(
                  'Todavía no tenés fondo de emergencia',
                  style: TextStyle(
                    fontWeight: FontWeight.w800,
                    fontSize: 15,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            'Un colchón para días sin laburo, roturas o imprevistos. '
            'Distinto de las metas de vacaciones o compras.',
            style: TextStyle(
              fontSize: 13,
              height: 1.4,
              color: Colors.grey.shade600,
            ),
          ),
          const SizedBox(height: 14),
          SizedBox(
            width: double.infinity,
            child: FilledButton.icon(
              onPressed: _crearFondo,
              style: FilledButton.styleFrom(backgroundColor: _fondoAccent),
              icon: const Icon(Icons.shield_outlined),
              label: const Text('Armar Fondo días flojos'),
            ),
          ),
        ],
      ),
    );
  }

  Widget _cardMeta(MetaAhorro m) {
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
                  child: Text(
                    m.titulo,
                    style: const TextStyle(
                      fontWeight: FontWeight.w700,
                      fontSize: 16,
                    ),
                  ),
                ),
                if (!m.completada)
                  IconButton(
                    icon: const Icon(Icons.delete_outline, size: 20),
                    onPressed: () => widget.store.remove(m.id),
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
              color: m.completada ? const Color(0xFF16A34A) : _primary,
              backgroundColor: const Color(0xFFE2E8F0),
            ),
            const SizedBox(height: 6),
            Text(
              m.completada ? '¡Meta cumplida!' : '$pct%',
              style: TextStyle(
                fontWeight: FontWeight.w600,
                color:
                    m.completada ? const Color(0xFF16A34A) : _primary,
              ),
            ),
            if (!m.completada) ...[
              const SizedBox(height: 10),
              SizedBox(
                width: double.infinity,
                child: FilledButton.icon(
                  onPressed: () => _apartar(m),
                  style: FilledButton.styleFrom(backgroundColor: _primary),
                  icon: const Icon(Icons.savings_outlined),
                  label: const Text('Apartar del disponible'),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final store = widget.store;
    final fondo = store.fondoEmergencia;
    final aspiracionales = store.metasAspiracionales;

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
                            const Text(
                              'Disponible',
                              style: TextStyle(
                                color: AppColors.textMuted,
                                fontSize: 12,
                              ),
                            ),
                            Text(
                              _money.format(_disponible),
                              style: const TextStyle(
                                fontWeight: FontWeight.w800,
                                color: _primary,
                                fontSize: 18,
                              ),
                            ),
                          ],
                        ),
                      ),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'En metas / fondo',
                              style: TextStyle(
                                color: AppColors.textMuted,
                                fontSize: 12,
                              ),
                            ),
                            Text(
                              _money.format(_enMetas),
                              style: const TextStyle(
                                fontWeight: FontWeight.w800,
                                color: Color(0xFF734BE4),
                                fontSize: 18,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 20),
                const Text(
                  'Colchón',
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w800,
                    color: Color(0xFF0F172A),
                  ),
                ),
                const SizedBox(height: 8),
                if (fondo != null) _cardFondo(fondo) else _cardEmptyFondo(),
                const Text(
                  'Metas aspiracionales',
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w800,
                    color: Color(0xFF0F172A),
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Vacaciones, herramientas, compras…',
                  style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                ),
                const SizedBox(height: 12),
                if (aspiracionales.isEmpty)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    child: Text(
                      'Creá una meta con el botón de abajo.',
                      textAlign: TextAlign.center,
                      style: TextStyle(color: Colors.grey.shade600),
                    ),
                  )
                else
                  ...aspiracionales.map(_cardMeta),
              ],
            ),
    );
  }
}
