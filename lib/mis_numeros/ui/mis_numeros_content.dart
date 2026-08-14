import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../theme/app_colors.dart';
import '../data/metas_store.dart';
import '../data/movimientos_store.dart';
import '../data/vencimientos_store.dart';
import '../models/movimiento.dart';
import 'metas_screen.dart';
import 'nuevo_movimiento_sheet.dart';
import 'vencimientos_screen.dart';

class MisNumerosContent extends StatefulWidget {
  const MisNumerosContent({
    super.key,
    required this.store,
    required this.metasStore,
    required this.vencimientosStore,
    this.onLock,
  });
  final MovimientosStore store;
  final MetasStore metasStore;
  final VencimientosStore vencimientosStore;
  final VoidCallback? onLock;
  @override
  State<MisNumerosContent> createState() => _MisNumerosContentState();
}

class _MisNumerosContentState extends State<MisNumerosContent> {
  final _money =
      NumberFormat.currency(locale: 'es_AR', symbol: r'$', decimalDigits: 0);
  PeriodoVista _periodo = PeriodoVista.hoy;
  static const _cobro = Color(0xFF28B5CD);
  static const _gasto = Color(0xFFF75A6D);

  @override
  void initState() {
    super.initState();
    widget.store.addListener(_onStore);
  }

  @override
  void dispose() {
    widget.store.removeListener(_onStore);
    super.dispose();
  }

  void _onStore() {
    if (mounted) setState(() {});
  }

  Future<void> _abrirNuevo(TipoMovimiento tipo) async {
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => NuevoMovimientoSheet(tipo: tipo, store: widget.store),
    );
  }

  void _abrirMetas() {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => MetasScreen(
          store: widget.metasStore,
          movimientosStore: widget.store,
        ),
      ),
    );
  }

  void _abrirVencimientos() {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) =>
            VencimientosScreen(store: widget.vencimientosStore),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final store = widget.store;
    if (!store.isLoaded) {
      return const Center(child: CircularProgressIndicator());
    }
    final lista = store.porPeriodo(_periodo);
    final saldo = store.saldo(lista);
    final cobros = store.totalCobros(lista);
    final gastos = store.totalGastos(lista);

    return ColoredBox(
      color: const Color(0xFFF1F5F9),
      child: RefreshIndicator(
        onRefresh: () => store.reloadFromCloud(),
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 32),
          children: [
            // Atajos temporales: Metas / Vencimientos
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: _abrirMetas,
                    icon: const Icon(Icons.flag_outlined, size: 18),
                    label: const Text('Metas'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: _cobro,
                      side: const BorderSide(color: _cobro),
                      padding: const EdgeInsets.symmetric(vertical: 10),
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: _abrirVencimientos,
                    icon: const Icon(Icons.event_outlined, size: 18),
                    label: const Text('Vencimientos'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: const Color(0xFF734BE4),
                      side: const BorderSide(color: Color(0xFF734BE4)),
                      padding: const EdgeInsets.symmetric(vertical: 10),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Row(children: [
              Expanded(
                child: Text(
                  store.syncedToCloud
                      ? 'Numeros cifrados en la nube'
                      : (store.lastCloudError ?? 'Sin sync'),
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: store.syncedToCloud ? _cobro : AppColors.danger,
                  ),
                ),
              ),
              if (widget.onLock != null)
                IconButton(
                  onPressed: widget.onLock,
                  icon: const Icon(Icons.lock_outline),
                  color: AppColors.textMuted,
                ),
              IconButton(
                onPressed: store.syncing ? null : () => store.reloadFromCloud(),
                icon: Icon(
                  store.syncedToCloud
                      ? Icons.cloud_done_outlined
                      : Icons.cloud_off_outlined,
                  color: store.syncedToCloud ? _cobro : AppColors.danger,
                ),
              ),
            ]),
            const SizedBox(height: 12),
            SegmentedButton<PeriodoVista>(
              segments: const [
                ButtonSegment(value: PeriodoVista.hoy, label: Text('Hoy')),
                ButtonSegment(
                    value: PeriodoVista.semana, label: Text('Semana')),
                ButtonSegment(value: PeriodoVista.mes, label: Text('Mes')),
              ],
              selected: {_periodo},
              onSelectionChanged: (s) => setState(() => _periodo = s.first),
            ),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: AppColors.border),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Plata que te quedo',
                      style: TextStyle(
                          color: AppColors.textMuted,
                          fontWeight: FontWeight.w600)),
                  const SizedBox(height: 6),
                  Text(
                    '${_money.format(saldo).replaceAll(r"$", "").trim()} \$',
                    style: const TextStyle(
                        fontSize: 36,
                        fontWeight: FontWeight.w800,
                        color: _cobro),
                  ),
                  const SizedBox(height: 16),
                  Row(children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text('Cobros',
                              style: TextStyle(color: AppColors.textMuted)),
                          Text(
                            '${_money.format(cobros).replaceAll(r"$", "").trim()} \$',
                            style: const TextStyle(
                                color: _cobro,
                                fontWeight: FontWeight.w700,
                                fontSize: 18),
                          ),
                        ],
                      ),
                    ),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text('Gastos',
                              style: TextStyle(color: AppColors.textMuted)),
                          Text(
                            '${_money.format(gastos).replaceAll(r"$", "").trim()} \$',
                            style: const TextStyle(
                                color: _gasto,
                                fontWeight: FontWeight.w700,
                                fontSize: 18),
                          ),
                        ],
                      ),
                    ),
                  ]),
                ],
              ),
            ),
            const SizedBox(height: 20),
            Row(children: [
              Expanded(
                child: _BigAction(
                  label: 'Cobre',
                  color: _cobro,
                  icon: Icons.arrow_downward_rounded,
                  onTap: () => _abrirNuevo(TipoMovimiento.cobro),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _BigAction(
                  label: 'Gaste',
                  color: _gasto,
                  icon: Icons.arrow_upward_rounded,
                  onTap: () => _abrirNuevo(TipoMovimiento.gasto),
                ),
              ),
            ]),
            const SizedBox(height: 28),
            const Text('Movimientos',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800)),
            const SizedBox(height: 12),
            if (lista.isEmpty)
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: AppColors.border),
                ),
                child: const Text(
                  'Todavia no anotaste nada en este periodo.',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: AppColors.textMuted),
                ),
              )
            else
              ...lista.map((m) {
                final esCobro = m.esCobro;
                final titulo = esCobro
                    ? (m.nota?.isNotEmpty == true ? m.nota! : 'Cobro')
                    : (m.categoria?.label ?? 'Gasto');
                final fecha = DateFormat('dd/MM HH:mm').format(m.fecha);
                final montoStr =
                    '${esCobro ? "" : "-"}${_money.format(m.monto).replaceAll(r"$", "").trim()} \$';
                return Card(
                  margin: const EdgeInsets.only(bottom: 10),
                  elevation: 0,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                    side: const BorderSide(color: AppColors.border),
                  ),
                  child: ListTile(
                    leading: CircleAvatar(
                      backgroundColor:
                          (esCobro ? _cobro : _gasto).withOpacity(0.15),
                      child: Icon(
                        esCobro ? Icons.arrow_downward : Icons.arrow_upward,
                        color: esCobro ? _cobro : _gasto,
                      ),
                    ),
                    title: Text(titulo,
                        style: const TextStyle(fontWeight: FontWeight.w700)),
                    subtitle: Text(fecha, style: const TextStyle(fontSize: 12)),
                    trailing: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          montoStr,
                          style: TextStyle(
                            fontWeight: FontWeight.w700,
                            color: esCobro ? _cobro : _gasto,
                          ),
                        ),
                        IconButton(
                          icon: const Icon(Icons.delete_outline, size: 20),
                          onPressed: () => store.remove(m.id),
                        ),
                      ],
                    ),
                  ),
                );
              }),
          ],
        ),
      ),
    );
  }
}

class _BigAction extends StatelessWidget {
  const _BigAction({
    required this.label,
    required this.color,
    required this.icon,
    required this.onTap,
  });
  final String label;
  final Color color;
  final IconData icon;
  final VoidCallback onTap;
  @override
  Widget build(BuildContext context) {
    return Material(
      color: color,
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 22),
          child: Column(children: [
            Icon(icon, color: Colors.white, size: 28),
            const SizedBox(height: 6),
            Text(label,
                style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w700,
                    fontSize: 18)),
          ]),
        ),
      ),
    );
  }
}
