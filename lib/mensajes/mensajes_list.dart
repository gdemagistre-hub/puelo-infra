import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

import '../loginScreen.dart';
import '../user_session.dart';
import 'emitir_recibo_sheet.dart';
import 'mensajes_detalle.dart';
import 'mensajes_service.dart';

/// Tab Mensajes embebido: lista de hilos (comprobantes + evaluaciones).
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

    // Sin token Firebase: rules/CF bloquean; guía a login real.
    if (!UserSession().hasRealAuth) {
      return ColoredBox(
        color: const Color(0xFFF8FAFC),
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(28),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.lock_outline_rounded, size: 48, color: Color(0xFFB45309)),
                const SizedBox(height: 16),
                const Text(
                  'Mensajes requiere Google o Email',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800),
                ),
                const SizedBox(height: 10),
                const Text(
                  'Para ver hilos, registrar un pago o confirmar comprobantes '
                  'necesitás entrar con una cuenta real.',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 14, color: Color(0xFF64748B), height: 1.4),
                ),
                const SizedBox(height: 24),
                FilledButton.icon(
                  onPressed: () {
                    Navigator.of(context).pushAndRemoveUntil(
                      MaterialPageRoute(builder: (_) => const LoginScreenWidget()),
                      (_) => false,
                    );
                  },
                  style: FilledButton.styleFrom(
                    backgroundColor: _primary,
                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
                  ),
                  icon: const Icon(Icons.login_rounded),
                  label: const Text('Iniciar sesión', style: TextStyle(fontWeight: FontWeight.w800)),
                ),
              ],
            ),
          ),
        ),
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
                'Doy un pago',
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

  Future<void> _openEmitir(BuildContext context) async {
    if (!UserSession().hasRealAuth) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Entrá con Google o Email para registrar un pago'),
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }
    final res = await showModalBottomSheet<Map<String, dynamic>>(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => const EmitirReciboSheet(),
    );
    if (res == null || !context.mounted) return;

    final convId = (res['conversacion_id'] as String?)?.trim() ?? '';
    if (convId.isEmpty) return;

    // Abrir el hilo recién creado/actualizado para ver el comprobante.
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => MensajesDetalleScreen(
          conversacionId: convId,
          conversacionData: {
            'participantes': [
              UserSession().uid,
              res['contraparte_uid'],
            ].whereType<String>().toList(),
            'last_summary': res['last_summary'] ?? 'Comprobante registrado',
          },
        ),
      ),
    );
  }
}

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
              'Primero contactá al prestador desde su tarjeta (WhatsApp o Doy un pago). '
              'Acá ves comprobantes pendientes de confirmar y evaluaciones.',
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
          'Todavía no hay actividad',
          textAlign: TextAlign.center,
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.w800,
            color: MensajesListScreen._text,
          ),
        ),
        const SizedBox(height: 10),
        const Text(
          'Acá aparecen los comprobantes de pago y las evaluaciones. '
          'Para el primer pago, seguí estos pasos:',
          textAlign: TextAlign.center,
          style: TextStyle(
            fontSize: 14,
            height: 1.45,
            color: MensajesListScreen._muted,
          ),
        ),
        const SizedBox(height: 20),
        _StepRow(n: '1', text: 'Buscá un prestador en Inicio y abrí su tarjeta'),
        const SizedBox(height: 10),
        _StepRow(n: '2', text: 'Tocá WhatsApp o Llamar (queda el contacto)'),
        const SizedBox(height: 10),
        _StepRow(n: '3', text: 'Registrá el pago con “Doy un pago”'),
        const SizedBox(height: 28),
        FilledButton.icon(
          onPressed: onEmitir,
          style: FilledButton.styleFrom(
            backgroundColor: MensajesListScreen._primary,
            padding: const EdgeInsets.symmetric(vertical: 14),
          ),
          icon: const Icon(Icons.add),
          label: const Text(
            'Doy un pago',
            style: TextStyle(fontWeight: FontWeight.w800),
          ),
        ),
        const SizedBox(height: 12),
        const Text(
          'Si ya contactaste a alguien desde la app, también podés registrar el pago desde este botón.',
          textAlign: TextAlign.center,
          style: TextStyle(fontSize: 12, height: 1.35, color: Color(0xFF94A3B8)),
        ),
      ],
    );
  }
}

class _StepRow extends StatelessWidget {
  final String n;
  final String text;
  const _StepRow({required this.n, required this.text});

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 28,
          height: 28,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: MensajesListScreen._primary.withOpacity(0.15),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Text(
            n,
            style: const TextStyle(
              fontWeight: FontWeight.w900,
              fontSize: 13,
              color: MensajesListScreen._primary,
            ),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Padding(
            padding: const EdgeInsets.only(top: 4),
            child: Text(
              text,
              style: const TextStyle(
                fontSize: 14,
                height: 1.35,
                color: MensajesListScreen._text,
                fontWeight: FontWeight.w600,
              ),
            ),
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
    final pending = widget.data['pending_recibo_event_id'] != null ||
        widget.data['pending_calificacion_event_id'] != null;
    final name = _otherName ?? '…';
    final initial = name.isNotEmpty && name != '…' ? name[0].toUpperCase() : '?';

    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(16),
      elevation: pending ? 2 : 1,
      shadowColor: pending
          ? const Color(0xFFF59E0B).withOpacity(0.25)
          : Colors.black12,
      child: InkWell(
        onTap: widget.onTap,
        borderRadius: BorderRadius.circular(16),
        child: Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            border: pending
                ? const Border(
                    left: BorderSide(color: Color(0xFFF59E0B), width: 3.5),
                  )
                : null,
          ),
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
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF59E0B),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Text(
                    'Pendiente',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w800,
                      color: Colors.white,
                      letterSpacing: 0.2,
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
