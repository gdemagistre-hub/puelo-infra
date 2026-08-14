import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../theme/app_colors.dart';
import '../data/fiados_store.dart';
import '../data/metas_store.dart';
import '../data/movimientos_store.dart';
import '../data/vencimientos_store.dart';
import '../models/movimiento.dart';
import 'fiados_screen.dart';
import 'metas_screen.dart';
import 'nuevo_movimiento_sheet.dart';
import 'vencimientos_screen.dart';

class MisNumerosContent extends StatefulWidget {
  const MisNumerosContent({
    super.key,
    required this.store,
    required this.metasStore,
    required this.vencimientosStore,
    required this.fiadosStore,
    this.onLock,
  });
  final MovimientosStore store;
  final MetasStore metasStore;
  final VencimientosStore vencimientosStore;
  final FiadosStore fiadosStore;
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
  static const _retiro = Color(0xFFF59E0B);
  static const _fiado = Color(0xFF7C3AED);

  @override
  void initState() {
    super.initState();
    widget.store.addListener(_onStore);
    widget.fiadosStore.addListener(_onStore);
  }

  @override
  void dispose() {
    widget.store.removeListener(_onStore);
    widget.fiadosStore.removeListener(_onStore);
    super.dispose();
  }

  void _onStore() {
    if (mounted) setState(() {});
  }

  String _fmt(double v) =>
      '${_money.format(v).replaceAll(r"$", "").trim()} \$';

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
        builder: (_) => VencimientosScreen(store: widget.vencimientosStore),
      ),
    );
  }

  void _abrirFiados() {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => FiadosScreen(
          store: widget.fiadosStore,
          movimientosStore: widget.store,
        ),
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
    final cobros = store.totalCobros(lista);
    final gastos = store.totalGastos(lista);
    final retiros = store.totalRetiros(lista);
    final saldoNegocio = store.saldoNegocio(lista);

    final fiados = widget.fiadosStore;
    final totalFiados = fiados.totalPendiente;
    final nFiados = fiados.cantidadPendiente;

    return ColoredBox(
      color: const Color(0xFFF1F5F9),
      child: RefreshIndicator(
        onRefresh: () => store.reloadFromCloud(),
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 32),
          children: [
            // Atajos Metas / Vencimientos
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
                      ? 'Números cifrados en la nube'
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

            // Resumen Casa vs Negocio
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
                  const Text(
                    'Plata que quedó en el negocio',
                    style: TextStyle(
                      color: AppColors.textMuted,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    _fmt(saldoNegocio),
                    style: TextStyle(
                      fontSize: 34,
                      fontWeight: FontWeight.w800,
                      color: saldoNegocio >= 0 ? _cobro : _gasto,
                    ),
                  ),
                  const SizedBox(height: 16),
                  _ResumenLinea(
                    label: 'Cobros',
                    value: _fmt(cobros),
                    color: _cobro,
                  ),
                  const SizedBox(height: 8),
                  _ResumenLinea(
                    label: 'Gastos del trabajo',
                    value: _fmt(gastos),
                    color: _gasto,
                  ),
                  const SizedBox(height: 8),
                  _ResumenLinea(
                    label: 'Me saqué para casa',
                    value: _fmt(retiros),
                    color: _retiro,
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),

            // Tres acciones
            Row(children: [
              Expanded(
                child: _BigAction(
                  label: 'Cobré',
                  color: _cobro,
                  icon: Icons.arrow_downward_rounded,
                  onTap: () => _abrirNuevo(TipoMovimiento.cobro),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _BigAction(
                  label: 'Gasté',
                  color: _gasto,
                  icon: Icons.arrow_upward_rounded,
                  onTap: () => _abrirNuevo(TipoMovimiento.gasto),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _BigAction(
                  label: 'Me saqué',
                  color: _retiro,
                  icon: Icons.account_balance_wallet_outlined,
                  onTap: () => _abrirNuevo(TipoMovimiento.retiro),
                ),
              ),
            ]),
            const SizedBox(height: 16),

            // Me deben
            Material(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              child: InkWell(
                onTap: _abrirFiados,
                borderRadius: BorderRadius.circular(16),
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 14,
                  ),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: nFiados > 0
                          ? _fiado.withOpacity(0.35)
                          : AppColors.border,
                    ),
                  ),
                  child: Row(
                    children: [
                      Container(
                        width: 40,
                        height: 40,
                        decoration: BoxDecoration(
                          color: _fiado.withOpacity(0.12),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: const Icon(
                          Icons.handshake_outlined,
                          color: _fiado,
                          size: 22,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'Me deben',
                              style: TextStyle(
                                fontWeight: FontWeight.w800,
                                fontSize: 15,
                              ),
                            ),
                            Text(
                              nFiados == 0
                                  ? 'Libreta de fiados · anotar plata prestada'
                                  : '$nFiados pendiente${nFiados == 1 ? '' : 's'}',
                              style: const TextStyle(
                                fontSize: 12,
                                color: AppColors.textMuted,
                              ),
                            ),
                          ],
                        ),
                      ),
                      if (nFiados > 0)
                        Text(
                          _fmt(totalFiados),
                          style: const TextStyle(
                            fontWeight: FontWeight.w800,
                            fontSize: 15,
                            color: _fiado,
                          ),
                        ),
                      const SizedBox(width: 4),
                      Icon(
                        Icons.chevron_right_rounded,
                        color: Colors.grey.shade400,
                      ),
                    ],
                  ),
                ),
              ),
            ),

            const SizedBox(height: 28),
            const Text(
              'Movimientos',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800),
            ),
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
                  'Todavía no anotaste nada en este período.\n'
                  'Usá “Me saqué” cuando te pases plata a casa.',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: AppColors.textMuted, height: 1.4),
                ),
              )
            else
              ...lista.map((m) {
                final Color accent;
                final IconData icon;
                final String titulo;
                final String montoStr;

                if (m.esCobro) {
                  accent = _cobro;
                  icon = Icons.arrow_downward_rounded;
                  titulo = (m.nota?.isNotEmpty == true) ? m.nota! : 'Cobro';
                  montoStr = _fmt(m.monto);
                } else if (m.esRetiro) {
                  accent = _retiro;
                  icon = Icons.account_balance_wallet_outlined;
                  titulo = (m.nota?.isNotEmpty == true)
                      ? m.nota!
                      : 'Me saqué para casa';
                  montoStr = _fmt(m.monto);
                } else {
                  accent = _gasto;
                  icon = Icons.arrow_upward_rounded;
                  titulo = m.categoria?.label ??
                      ((m.nota?.isNotEmpty == true) ? m.nota! : 'Gasto');
                  montoStr = '-${_fmt(m.monto)}';
                }

                final fecha = DateFormat('dd/MM HH:mm').format(m.fecha);

                return Card(
                  margin: const EdgeInsets.only(bottom: 10),
                  elevation: 0,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                    side: const BorderSide(color: AppColors.border),
                  ),
                  child: ListTile(
                    leading: CircleAvatar(
                      backgroundColor: accent.withOpacity(0.15),
                      child: Icon(icon, color: accent, size: 22),
                    ),
                    title: Text(
                      titulo,
                      style: const TextStyle(fontWeight: FontWeight.w700),
                    ),
                    subtitle: Text(
                      fecha,
                      style: const TextStyle(fontSize: 12),
                    ),
                    trailing: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          montoStr,
                          style: TextStyle(
                            fontWeight: FontWeight.w700,
                            color: accent,
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

class _ResumenLinea extends StatelessWidget {
  const _ResumenLinea({
    required this.label,
    required this.value,
    required this.color,
  });
  final String label;
  final String value;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          width: 8,
          height: 8,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            label,
            style: const TextStyle(
              color: AppColors.textMuted,
              fontSize: 13,
              fontWeight: FontWeight.w500,
            ),
          ),
        ),
        Text(
          value,
          style: TextStyle(
            color: color,
            fontWeight: FontWeight.w700,
            fontSize: 15,
          ),
        ),
      ],
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
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(14),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 16),
          child: Column(
            children: [
              Icon(icon, color: Colors.white, size: 24),
              const SizedBox(height: 4),
              Text(
                label,
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w700,
                  fontSize: 13,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
