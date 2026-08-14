import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

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
    final partes =
        (widget.conversacionData['participantes'] as List?)?.cast<String>() ??
            [];
    _otherUid = partes.firstWhere((p) => p != my, orElse: () => '');
    _loadName();
  }

  Future<void> _loadName() async {
    final o = _otherUid;
    if (o == null || o.isEmpty) return;
    final d = await MensajesService.instance.loadUsuarioLite(o);
    if (!mounted) return;
    setState(() {
      _otherName = MensajesService.instance.displayNameFromUser(d, o);
    });
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
                ? 'Recibo aceptado · registro sellado'
                : 'Recibo rechazado · queda documentado',
          ),
          behavior: SnackBarBehavior.floating,
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('$e'),
          backgroundColor: const Color(0xFFB91C1C),
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
        content: TextField(
          controller: ctrl,
          decoration: const InputDecoration(
            labelText: 'Motivo (opcional)',
            hintText: 'Monto incorrecto, no recibí, etc.',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Confirmar'),
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

  @override
  Widget build(BuildContext context) {
    final myUid = UserSession().uid ?? '';
    final pendingId =
        widget.conversacionData['pending_recibo_event_id'] as String?;

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
            onPressed: _otherUid == null || _otherUid!.isEmpty
                ? null
                : () {
                    showModalBottomSheet(
                      context: context,
                      isScrollControlled: true,
                      shape: const RoundedRectangleBorder(
                        borderRadius:
                            BorderRadius.vertical(top: Radius.circular(20)),
                      ),
                      builder: (_) => EmitirReciboSheet(
                        contraparteUidFijo: _otherUid,
                        contraparteNombre: _otherName,
                      ),
                    );
                  },
            icon: const Icon(Icons.receipt_long_rounded),
          ),
        ],
      ),
      body: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
        stream: MensajesService.instance.watchEventos(widget.conversacionId),
        builder: (context, snap) {
          if (snap.hasError) {
            return Center(child: Text('${snap.error}'));
          }
          if (!snap.hasData) {
            return const Center(child: CircularProgressIndicator());
          }
          final events = snap.data!.docs;
          if (events.isEmpty) {
            return const Center(child: Text('Sin eventos aún'));
          }

          // Mapa de respuestas por recibo_event_id
          final respuestas = <String, Map<String, dynamic>>{};
          for (final e in events) {
            final d = e.data();
            final t = d['tipo'] as String? ?? '';
            if (t == 'recibo_aceptado' || t == 'recibo_rechazado') {
              final rid = d['recibo_event_id'] as String?;
              if (rid != null) respuestas[rid] = d;
            }
          }

          return ListView.builder(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 32),
            itemCount: events.length,
            itemBuilder: (context, i) {
              final doc = events[i];
              final d = doc.data();
              final tipo = d['tipo'] as String? ?? '';
              if (tipo == 'recibo_emitido') {
                final resp = respuestas[doc.id];
                final isPending =
                    pendingId == doc.id && resp == null;
                final soyEmisor = d['actor_uid'] == myUid;
                final puedoResponder = isPending && !soyEmisor && !_busy;

                return _ReciboCard(
                  data: d,
                  eventId: doc.id,
                  respuesta: resp,
                  puedoResponder: puedoResponder,
                  onAceptar: () => _responder(
                    reciboEventId: doc.id,
                    decision: 'aceptado',
                  ),
                  onRechazar: () => _confirmReject(doc.id),
                );
              }
              if (tipo == 'recibo_aceptado' || tipo == 'recibo_rechazado') {
                // Ya se muestra dentro de la card del recibo
                return const SizedBox.shrink();
              }
              return const SizedBox.shrink();
            },
          );
        },
      ),
    );
  }
}

class _ReciboCard extends StatelessWidget {
  final Map<String, dynamic> data;
  final String eventId;
  final Map<String, dynamic>? respuesta;
  final bool puedoResponder;
  final VoidCallback onAceptar;
  final VoidCallback onRechazar;

  const _ReciboCard({
    required this.data,
    required this.eventId,
    required this.respuesta,
    required this.puedoResponder,
    required this.onAceptar,
    required this.onRechazar,
  });

  @override
  Widget build(BuildContext context) {
    final monto = MensajesService.formatMonto(data['monto']);
    final concepto = MensajesService.labelConcepto(data['concepto'] as String?);
    final hash = (data['content_hash'] as String?) ?? '';
    final hashShort = hash.length >= 10 ? hash.substring(0, 10) : hash;
    final nota = (data['nota'] as String?)?.trim() ?? '';
    final iso = (data['created_at_iso'] as String?) ?? '';
    final decision = respuesta?['decision'] as String?;

    Color border = const Color(0xFFE2E8F0);
    String estadoLabel = 'Pendiente de confirmación';
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
                  const Spacer(),
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
              const SizedBox(height: 10),
              Text(
                iso.isNotEmpty ? iso.replaceFirst('T', ' ').split('.').first : '',
                style: const TextStyle(fontSize: 11, color: Color(0xFF94A3B8)),
              ),
              const SizedBox(height: 4),
              Text(
                'Registro sellado · $hashShort…',
                style: const TextStyle(fontSize: 11, color: Color(0xFF94A3B8)),
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
