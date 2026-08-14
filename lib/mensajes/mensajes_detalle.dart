import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../user_session.dart';
import 'emitir_recibo_sheet.dart';
import 'mensajes_service.dart';

class MensajesDetalleScreen extends StatefulWidget {
  final String conversacionId;
  final Map<String, dynamic> conversacionData;

  const MensajesDetalleScreen({
    super.key,
    required this.conversacionId,
    required this.conversacionData,
  });

  @override
  State<MensajesDetalleScreen> createState() => _MensajesDetalleScreenState();
}

class _MensajesDetalleScreenState extends State<MensajesDetalleScreen> {
  static const Color _primary = Color(0xFF28B5CD);
  String? _otherName;
  String? _otherUid;
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    final my = UserSession().uid ?? '';
    _otherUid = MensajesService.otherParticipantUid(
      myUid: my,
      convId: widget.conversacionId,
      data: widget.conversacionData,
    );
    _loadName();
  }

  Future<void> _loadName() async {
    final o = _otherUid;
    if (o == null || o.isEmpty) return;
    final name = await MensajesService.instance.resolveDisplayName(o);
    if (!mounted) return;
    setState(() => _otherName = name);
  }

  Future<void> _responder({
    required String reciboEventId,
    required String decision,
    String? motivo,
  }) async {
    setState(() => _busy = true);
    try {
      await MensajesService.instance.responderRecibo(
        conversacionId: widget.conversacionId,
        reciboEventId: reciboEventId,
        decision: decision,
        motivo: motivo,
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            decision == 'aceptado'
                ? 'Recibo aceptado · queda como evidencia'
                : 'Recibo rechazado · queda documentado',
          ),
          behavior: SnackBarBehavior.floating,
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(MensajesService.humanizeError(e)),
          backgroundColor: const Color(0xFFB91C1C),
          behavior: SnackBarBehavior.floating,
        ),
      );
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _confirmReject(String reciboEventId) async {
    final ctrl = TextEditingController();
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('No, revisemos'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'El rechazo queda registrado y no se borra. '
              'Sirve como evidencia de que no hubo acuerdo sobre ese monto.',
              style: TextStyle(fontSize: 13, color: Color(0xFF64748B), height: 1.35),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: ctrl,
              decoration: const InputDecoration(
                labelText: 'Motivo (opcional)',
                hintText: 'Monto incorrecto, no recibí, etc.',
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
            child: const Text('Confirmar rechazo'),
          ),
        ],
      ),
    );
    if (ok == true) {
      await _responder(
        reciboEventId: reciboEventId,
        decision: 'rechazado',
        motivo: ctrl.text,
      );
    }
  }

  void _openEmitir() {
    if (_otherUid == null || _otherUid!.isEmpty) return;
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => EmitirReciboSheet(
        contraparteUidFijo: _otherUid,
        contraparteNombre: _otherName,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final myUid = UserSession().uid ?? '';

    return Scaffold(
      backgroundColor: const Color(0xFFF1F5F9),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        title: Text(
          _otherName ?? 'Recibos',
          style: const TextStyle(
            color: _primary,
            fontWeight: FontWeight.w800,
          ),
        ),
        iconTheme: const IconThemeData(color: _primary),
        actions: [
          IconButton(
            tooltip: 'Emitir recibo',
            onPressed: _otherUid == null || _otherUid!.isEmpty ? null : _openEmitir,
            icon: const Icon(Icons.receipt_long_rounded),
          ),
        ],
      ),
      body: Column(
        children: [
          Container(
            width: double.infinity,
            color: const Color(0xFFE6F7FA),
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            child: const Row(
              children: [
                Icon(Icons.verified_user_outlined, size: 18, color: Color(0xFF1A8FA3)),
                SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Los recibos se sellan al emitirlos. No se editan ni se borran. '
                    'Quedan como evidencia entre las partes.',
                    style: TextStyle(
                      fontSize: 12,
                      height: 1.35,
                      color: Color(0xFF1A8FA3),
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            child: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
              stream:
                  MensajesService.instance.watchEventos(widget.conversacionId),
              builder: (context, snap) {
                if (snap.hasError) {
                  return Center(
                    child: Padding(
                      padding: const EdgeInsets.all(24),
                      child: Text(
                        MensajesService.humanizeError(snap.error),
                        textAlign: TextAlign.center,
                        style: const TextStyle(color: Color(0xFFB91C1C)),
                      ),
                    ),
                  );
                }
                if (!snap.hasData) {
                  return const Center(child: CircularProgressIndicator());
                }
                final events = snap.data!.docs;
                if (events.isEmpty) {
                  return Center(
                    child: Padding(
                      padding: const EdgeInsets.all(28),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(Icons.receipt_long_outlined,
                              size: 48, color: Color(0xFF94A3B8)),
                          const SizedBox(height: 12),
                          const Text(
                            'Todavía no hay recibos en este hilo',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              fontWeight: FontWeight.w800,
                              fontSize: 16,
                            ),
                          ),
                          const SizedBox(height: 8),
                          const Text(
                            'Emití uno cuando haya un pago, seña o anticipo.',
                            textAlign: TextAlign.center,
                            style: TextStyle(color: Color(0xFF64748B)),
                          ),
                          const SizedBox(height: 20),
                          FilledButton.icon(
                            onPressed: _openEmitir,
                            style: FilledButton.styleFrom(
                              backgroundColor: _primary,
                            ),
                            icon: const Icon(Icons.add),
                            label: const Text('Emitir recibo'),
                          ),
                        ],
                      ),
                    ),
                  );
                }

                final respuestas = <String, Map<String, dynamic>>{};
                for (final e in events) {
                  final d = e.data();
                  final t = d['tipo'] as String? ?? '';
                  if (t == 'recibo_aceptado' || t == 'recibo_rechazado') {
                    final rid = d['recibo_event_id'] as String?;
                    if (rid != null) respuestas[rid] = d;
                  }
                }

                final emitidos = events
                    .where((e) => (e.data()['tipo'] as String?) == 'recibo_emitido')
                    .toList();

                return ListView.builder(
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 32),
                  itemCount: emitidos.length,
                  itemBuilder: (context, i) {
                    final doc = emitidos[i];
                    final d = doc.data();
                    final resp = respuestas[doc.id];
                    final soyEmisor = d['actor_uid'] == myUid;
                    // Cualquier recibo sin respuesta: la contraparte puede contestar
                    final puedoResponder =
                        !soyEmisor && resp == null && !_busy;

                    return _ReciboCard(
                      data: d,
                      eventId: doc.id,
                      respuesta: resp,
                      soyEmisor: soyEmisor,
                      puedoResponder: puedoResponder,
                      otherName: _otherName,
                      onAceptar: () => _responder(
                        reciboEventId: doc.id,
                        decision: 'aceptado',
                      ),
                      onRechazar: () => _confirmReject(doc.id),
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _ReciboCard extends StatelessWidget {
  final Map<String, dynamic> data;
  final String eventId;
  final Map<String, dynamic>? respuesta;
  final bool soyEmisor;
  final bool puedoResponder;
  final String? otherName;
  final VoidCallback onAceptar;
  final VoidCallback onRechazar;

  const _ReciboCard({
    required this.data,
    required this.eventId,
    required this.respuesta,
    required this.soyEmisor,
    required this.puedoResponder,
    required this.otherName,
    required this.onAceptar,
    required this.onRechazar,
  });

  @override
  Widget build(BuildContext context) {
    final monto = MensajesService.formatMonto(data['monto']);
    final concepto = MensajesService.labelConcepto(data['concepto'] as String?);
    final hash = (data['content_hash'] as String?) ?? '';
    final hashShort = hash.length >= 12 ? hash.substring(0, 12) : hash;
    final nota = (data['nota'] as String?)?.trim() ?? '';
    final iso = (data['created_at_iso'] as String?) ?? '';
    final decision = respuesta?['decision'] as String?;
    final quien = otherName ?? 'la otra parte';

    Color border = const Color(0xFFE2E8F0);
    String estadoLabel = soyEmisor
        ? 'Esperando a $quien'
        : 'Pendiente de tu confirmación';
    Color estadoColor = const Color(0xFFB45309);
    if (decision == 'aceptado') {
      border = const Color(0xFF16A34A);
      estadoLabel = 'Aceptado';
      estadoColor = const Color(0xFF16A34A);
    } else if (decision == 'rechazado') {
      border = const Color(0xFFDC2626);
      estadoLabel = 'Rechazado';
      estadoColor = const Color(0xFFDC2626);
    }

    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: Material(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        elevation: 2,
        child: Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: border.withOpacity(0.55), width: 1.5),
          ),
          padding: const EdgeInsets.all(18),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: const Color(0xFF28B5CD).withOpacity(0.12),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      concepto,
                      style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w800,
                        color: Color(0xFF1A8FA3),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      soyEmisor ? 'Vos emitiste' : 'Te emitieron',
                      style: const TextStyle(
                        fontSize: 12,
                        color: Color(0xFF64748B),
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                  Text(
                    estadoLabel,
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w800,
                      color: estadoColor,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Text(
                monto,
                style: const TextStyle(
                  fontSize: 28,
                  fontWeight: FontWeight.w900,
                  color: Color(0xFF0F172A),
                  letterSpacing: -0.5,
                ),
              ),
              if (nota.isNotEmpty) ...[
                const SizedBox(height: 6),
                Text(nota, style: const TextStyle(color: Color(0xFF64748B))),
              ],
              const SizedBox(height: 12),
              // Firma / sello
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                decoration: BoxDecoration(
                  color: const Color(0xFFF8FAFC),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: const Color(0xFFE2E8F0)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        const Icon(Icons.shield_outlined,
                            size: 16, color: Color(0xFF64748B)),
                        const SizedBox(width: 6),
                        const Expanded(
                          child: Text(
                            'Registro sellado · no editable',
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w700,
                              color: Color(0xFF475569),
                            ),
                          ),
                        ),
                        if (hash.isNotEmpty)
                          InkWell(
                            onTap: () {
                              Clipboard.setData(ClipboardData(text: hash));
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                  content: Text('Firma copiada'),
                                  behavior: SnackBarBehavior.floating,
                                  duration: Duration(seconds: 2),
                                ),
                              );
                            },
                            child: const Padding(
                              padding: EdgeInsets.all(4),
                              child: Icon(Icons.copy_rounded,
                                  size: 16, color: Color(0xFF64748B)),
                            ),
                          ),
                      ],
                    ),
                    if (hashShort.isNotEmpty) ...[
                      const SizedBox(height: 4),
                      Text(
                        'Firma $hashShort…',
                        style: const TextStyle(
                          fontSize: 11,
                          fontFamily: 'monospace',
                          color: Color(0xFF94A3B8),
                        ),
                      ),
                    ],
                    if (iso.isNotEmpty) ...[
                      const SizedBox(height: 2),
                      Text(
                        iso.replaceFirst('T', ' ').split('.').first,
                        style: const TextStyle(
                          fontSize: 11,
                          color: Color(0xFF94A3B8),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              if (decision == 'rechazado' &&
                  ((respuesta?['motivo'] as String?) ?? '').isNotEmpty) ...[
                const SizedBox(height: 8),
                Text(
                  'Motivo: ${respuesta!['motivo']}',
                  style: const TextStyle(
                    fontSize: 13,
                    color: Color(0xFFB91C1C),
                  ),
                ),
              ],
              if (puedoResponder) ...[
                const SizedBox(height: 16),
                const Text(
                  '¿Confirmás que recibiste este monto?',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFF0F172A),
                  ),
                ),
                const SizedBox(height: 10),
                Row(
                  children: [
                    Expanded(
                      child: FilledButton(
                        onPressed: onAceptar,
                        style: FilledButton.styleFrom(
                          backgroundColor: const Color(0xFF16A34A),
                          padding: const EdgeInsets.symmetric(vertical: 12),
                        ),
                        child: const Text(
                          'Sí, gracias',
                          style: TextStyle(fontWeight: FontWeight.w800),
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: OutlinedButton(
                        onPressed: onRechazar,
                        style: OutlinedButton.styleFrom(
                          foregroundColor: const Color(0xFF64748B),
                          padding: const EdgeInsets.symmetric(vertical: 12),
                        ),
                        child: const Text(
                          'No, revisemos',
                          style: TextStyle(fontWeight: FontWeight.w700),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
