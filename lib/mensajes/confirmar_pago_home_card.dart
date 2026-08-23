import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

import '../user_session.dart';
import 'mensajes_detalle.dart';
import 'mensajes_service.dart';

/// 5.12 — en Home prestador, no hace falta entrar a Mensajes para ver el pago.
class ConfirmarPagoHomeCard extends StatelessWidget {
  const ConfirmarPagoHomeCard({super.key});

  static const Color _amber = Color(0xFFF59E0B);

  @override
  Widget build(BuildContext context) {
    final uid = UserSession().uid;
    if (uid == null || uid.isEmpty || !UserSession().hasRealAuth) {
      return const SizedBox.shrink();
    }

    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: MensajesService.instance.watchConversaciones(uid),
      builder: (context, snap) {
        if (!snap.hasData) return const SizedBox.shrink();
        final pendientes = <QueryDocumentSnapshot<Map<String, dynamic>>>[];
        for (final doc in snap.data!.docs) {
          final d = doc.data();
          if (d['pending_recibo_event_id'] == null) continue;
          final actor = (d['pending_recibo_actor_uid'] ?? '').toString();
          if (actor.isEmpty || actor == uid) continue;
          pendientes.add(doc);
          if (pendientes.length >= 3) break;
        }
        if (pendientes.isEmpty) return const SizedBox.shrink();

        return Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
          child: Material(
            color: const Color(0xFFFFFBEB),
            elevation: 2,
            shadowColor: _amber.withOpacity(0.25),
            borderRadius: BorderRadius.circular(16),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 14, 16, 12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Confirmá un pago',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w800,
                      color: Color(0xFF92400E),
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    pendientes.length == 1
                        ? 'Alguien registró un comprobante. Confirmá si lo recibiste.'
                        : '${pendientes.length} comprobantes esperan tu confirmación.',
                    style: const TextStyle(
                      fontSize: 13,
                      height: 1.35,
                      color: Color(0xFFB45309),
                    ),
                  ),
                  const SizedBox(height: 10),
                  ...pendientes.map((doc) {
                    final d = doc.data();
                    final summary = (d['last_summary'] as String?)?.trim();
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: Material(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(12),
                        child: InkWell(
                          borderRadius: BorderRadius.circular(12),
                          onTap: () {
                            Navigator.of(context).push(
                              MaterialPageRoute(
                                builder: (_) => MensajesDetalleScreen(
                                  conversacionId: doc.id,
                                  conversacionData: d,
                                ),
                              ),
                            );
                          },
                          child: Padding(
                            padding: const EdgeInsets.fromLTRB(12, 10, 10, 10),
                            child: Row(
                              children: [
                                const Icon(Icons.receipt_long_rounded,
                                    color: _amber, size: 20),
                                const SizedBox(width: 10),
                                Expanded(
                                  child: Text(
                                    (summary == null || summary.isEmpty)
                                        ? 'Comprobante pendiente'
                                        : summary,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: const TextStyle(
                                      fontWeight: FontWeight.w700,
                                      fontSize: 14,
                                      color: Color(0xFF0F172A),
                                    ),
                                  ),
                                ),
                                const Icon(Icons.chevron_right_rounded,
                                    color: Color(0xFFB45309)),
                              ],
                            ),
                          ),
                        ),
                      ),
                    );
                  }),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}
