import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

import '../user_session.dart';
import 'emitir_recibo_sheet.dart';
import 'mensajes_detalle.dart';
import 'mensajes_service.dart';

/// Tab Mensajes embebido: lista de hilos (recibos).
class MensajesListScreen extends StatelessWidget {
  final bool embedded;
  const MensajesListScreen({super.key, this.embedded = true});

  static const Color _primary = Color(0xFF28B5CD);
  static const Color _text = Color(0xFF0F172A);
  static const Color _muted = Color(0xFF64748B);

  @override
  Widget build(BuildContext context) {
    final uid = UserSession().uid;
    if (uid == null || uid.isEmpty) {
      return const Center(
        child: Text('Iniciá sesión para ver mensajes'),
      );
    }

    return ColoredBox(
      color: const Color(0xFFF1F5F9),
      child: Stack(
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const _LeyendaHeader(),
              Expanded(
                child: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
                  stream: MensajesService.instance.watchConversaciones(uid),
                  builder: (context, snap) {
                    if (snap.hasError) {
                      return _ErrorBox(
                        message:
                            'No se pudieron cargar los hilos.\n${snap.error}',
                      );
                    }
                    if (!snap.hasData) {
                      return const Center(child: CircularProgressIndicator());
                    }
                    final docs = snap.data!.docs;
                    if (docs.isEmpty) {
                      return _EmptyState(
                        onEmitir: () => _openEmitir(context),
                      );
                    }
                    return ListView.separated(
                      padding: const EdgeInsets.fromLTRB(16, 8, 16, 88),
                      itemCount: docs.length,
                      separatorBuilder: (_, __) => const SizedBox(height: 8),
                      itemBuilder: (context, i) {
                        final doc = docs[i];
                        final data = doc.data();
                        return _HiloTile(
                          key: ValueKey(doc.id),
                          convId: doc.id,
                          data: data,
                          myUid: uid,
                          onTap: () {
                            Navigator.of(context).push(
                              MaterialPageRoute(
                                builder: (_) => MensajesDetalleScreen(
                                  conversacionId: doc.id,
                                  conversacionData: data,
                                ),
                              ),
                            );
                          },
                        );
                      },
                    );
                  },
                ),
              ),
            ],
          ),
          Positioned(
            right: 16,
            bottom: 16,
            child: FloatingActionButton.extended(
              onPressed: () => _openEmitir(context),
              backgroundColor: _primary,
              icon: const Icon(Icons.receipt_long_rounded, color: Colors.white),
              label: const Text(
                'Emitir recibo',
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _openEmitir(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => const EmitirReciboSheet(),
    );
  }
}

/// Leyenda fija bajo el título de la pestaña.
class _LeyendaHeader extends StatelessWidget {
  const _LeyendaHeader();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      color: Colors.white,
      padding: const EdgeInsets.fromLTRB(16, 10, 16, 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            Icons.info_outline_rounded,
            size: 18,
            color: MensajesListScreen._primary.withOpacity(0.85),
          ),
          const SizedBox(width: 10),
          const Expanded(
            child: Text(
              'Los recibos se emiten desde la tarjeta digital de la otra persona. '
              'Acá los ves y respondés.',
              style: TextStyle(
                fontSize: 13,
                height: 1.35,
                color: MensajesListScreen._muted,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  final VoidCallback onEmitir;
  const _EmptyState({required this.onEmitir});

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(28, 36, 28, 32),
      children: [
        Center(
          child: Container(
            width: 88,
            height: 88,
            decoration: BoxDecoration(
              color: MensajesListScreen._primary.withOpacity(0.12),
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.receipt_long_rounded,
              size: 44,
              color: MensajesListScreen._primary,
            ),
          ),
        ),
        const SizedBox(height: 24),
        const Text(
          'Todavía no hay recibos',
          textAlign: TextAlign.center,
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.w800,
            color: MensajesListScreen._text,
          ),
        ),
        const SizedBox(height: 10),
        const Text(
          'Buscá a la persona, abrí su tarjeta digital y tocá “Emitir recibo”. '
          'Cada recibo queda sellado y no se puede editar.',
          textAlign: TextAlign.center,
          style: TextStyle(
            fontSize: 14,
            height: 1.45,
            color: MensajesListScreen._muted,
          ),
        ),
        const SizedBox(height: 28),
        FilledButton.icon(
          onPressed: onEmitir,
          style: FilledButton.styleFrom(
            backgroundColor: MensajesListScreen._primary,
            padding: const EdgeInsets.symmetric(vertical: 14),
          ),
          icon: const Icon(Icons.add),
          label: const Text(
            'Emitir recibo',
            style: TextStyle(fontWeight: FontWeight.w800),
          ),
        ),
        const SizedBox(height: 10),
        const Text(
          'También podés usar el botón de abajo si ya conocés el código de la otra persona.',
          textAlign: TextAlign.center,
          style: TextStyle(
            fontSize: 12,
            height: 1.4,
            color: Color(0xFF94A3B8),
          ),
        ),
      ],
    );
  }
}

class _ErrorBox extends StatelessWidget {
  final String message;
  const _ErrorBox({required this.message});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Text(
          message,
          textAlign: TextAlign.center,
          style: const TextStyle(color: Color(0xFFB91C1C)),
        ),
      ),
    );
  }
}

class _HiloTile extends StatefulWidget {
  final String convId;
  final Map<String, dynamic> data;
  final String myUid;
  final VoidCallback onTap;

  const _HiloTile({
    super.key,
    required this.convId,
    required this.data,
    required this.myUid,
    required this.onTap,
  });

  @override
  State<_HiloTile> createState() => _HiloTileState();
}

class _HiloTileState extends State<_HiloTile> {
  String? _otherName;
  String? _otherUid;

  @override
  void initState() {
    super.initState();
    _loadName();
  }

  @override
  void didUpdateWidget(covariant _HiloTile oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.convId != widget.convId || oldWidget.myUid != widget.myUid) {
      _loadName();
    }
  }

  Future<void> _loadName() async {
    final other = MensajesService.otherParticipantUid(
      myUid: widget.myUid,
      convId: widget.convId,
      data: widget.data,
    );
    _otherUid = other;
    if (other == null || other.isEmpty) {
      if (mounted) setState(() => _otherName = 'Conversación');
      return;
    }
    final name = await MensajesService.instance.resolveDisplayName(other);
    if (!mounted) return;
    setState(() => _otherName = name);
  }

  @override
  Widget build(BuildContext context) {
    final summary = (widget.data['last_summary'] as String?) ?? 'Conversación';
    final pending = widget.data['pending_recibo_event_id'] != null;
    final name = _otherName ?? '…';
    final initial = name.isNotEmpty && name != '…' ? name[0].toUpperCase() : '?';

    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(16),
      elevation: 1,
      child: InkWell(
        onTap: widget.onTap,
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
          child: Row(
            children: [
              CircleAvatar(
                backgroundColor: MensajesListScreen._primary.withOpacity(0.15),
                child: Text(
                  initial,
                  style: const TextStyle(
                    color: MensajesListScreen._primary,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      name,
                      style: const TextStyle(
                        fontWeight: FontWeight.w800,
                        fontSize: 15,
                        color: MensajesListScreen._text,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      summary,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 13,
                        color: MensajesListScreen._muted,
                      ),
                    ),
                  ],
                ),
              ),
              if (pending)
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF59E0B).withOpacity(0.15),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Text(
                    'Pendiente',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w800,
                      color: Color(0xFFB45309),
                    ),
                  ),
                )
              else
                const Icon(Icons.chevron_right_rounded,
                    color: Color(0xFF94A3B8)),
            ],
          ),
        ),
      ),
    );
  }
}
