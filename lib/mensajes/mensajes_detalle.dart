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
  bool _sending = false;
  final _textCtrl = TextEditingController();
  final _scrollCtrl = ScrollController();

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

  @override
  void dispose() {
    _textCtrl.dispose();
    _scrollCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadName() async {
    final o = _otherUid;
    if (o == null || o.isEmpty) return;
    final name = await MensajesService.instance.resolveDisplayName(o);
    if (!mounted) return;
    setState(() => _otherName = name);
  }

  Future<void> _enviarTexto() async {
    final t = _textCtrl.text.trim();
    if (t.isEmpty || _sending) return;
    setState(() => _sending = true);
    try {
      await MensajesService.instance.enviarMensajeTexto(
        conversacionId: widget.conversacionId,
        texto: t,
      );
      if (!mounted) return;
      _textCtrl.clear();
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
      if (mounted) setState(() => _sending = false);
    }
  }

  Future<void> _responderRecibo({
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
                ? 'Recibo aceptado \u00b7 queda como evidencia'
                : 'Recibo rechazado \u00b7 queda documentado',
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
              style: TextStyle(
                fontSize: 13,
                color: Color(0xFF64748B),
                height: 1.35,
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: ctrl,
              decoration: const InputDecoration(
                labelText: 'Motivo (opcional)',
                hintText: 'Monto incorrecto, no recib\u00ed, etc.',
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
      await _responderRecibo(
        reciboEventId: reciboEventId,
        decision: 'rechazado',
        motivo: ctrl.text,
      );
    }
  }

  Future<void> _responderCalificacion({
    required String calificacionEventId,
    required String decision,
    String? respuestaTexto,
  }) async {
    setState(() => _busy = true);
    try {
      await MensajesService.instance.responderCalificacion(
        conversacionId: widget.conversacionId,
        calificacionEventId: calificacionEventId,
        decision: decision,
        respuestaTexto: respuestaTexto,
      );
      if (!mounted) return;
      final conRespuesta = decision == 'respondido' ||
          (respuestaTexto != null && respuestaTexto.trim().isNotEmpty);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            conRespuesta
                ? 'Evaluaci\u00f3n publicada con tu respuesta. Las estrellas se actualizan en tu perfil al instante.'
                : 'Evaluaci\u00f3n aceptada y publicada. Las estrellas se actualizan en tu perfil al instante.',
          ),
          behavior: SnackBarBehavior.floating,
          duration: const Duration(seconds: 5),
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

  Future<void> _confirmResponderCalificacion(String eventId) async {
    final ctrl = TextEditingController();
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Responder evaluaci\u00f3n'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Tu respuesta queda p\u00fablica junto a la evaluaci\u00f3n. '
              'M\u00e1ximo 200 caracteres.',
              style: TextStyle(
                fontSize: 13,
                color: Color(0xFF64748B),
                height: 1.35,
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: ctrl,
              maxLength: 200,
              maxLines: 3,
              decoration: const InputDecoration(
                labelText: 'Tu respuesta',
                hintText: 'Gracias por confiar\u2026',
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
            child: const Text('Publicar respuesta'),
          ),
        ],
      ),
    );
    if (ok == true) {
      final texto = ctrl.text.trim();
      await _responderCalificacion(
        calificacionEventId: eventId,
        decision: texto.isEmpty ? 'aceptado' : 'respondido',
        respuestaTexto: texto.isEmpty ? null : texto,
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
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;

    return Scaffold(
      backgroundColor: const Color(0xFFF1F5F9),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        title: Text(
          _otherName ?? 'Mensajes',
          style: const TextStyle(
            color: _primary,
            fontWeight: FontWeight.w800,
          ),
        ),
        iconTheme: const IconThemeData(color: _primary),
        actions: [
          IconButton(
            tooltip: 'Emitir recibo',
            onPressed:
                _otherUid == null || _otherUid!.isEmpty ? null : _openEmitir,
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
                Icon(Icons.verified_user_outlined,
                    size: 18, color: Color(0xFF1A8FA3)),
                SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Recibos, evaluaciones y mensajes quedan registrados. '
                    'Los recibos se sellan; las evaluaciones se publican al aceptar.',
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

                final respuestasRecibo = <String, Map<String, dynamic>>{};
                final respuestasCalif = <String, Map<String, dynamic>>{};
                for (final e in events) {
                  final d = e.data();
                  final t = d['tipo'] as String? ?? '';
                  if (t == 'recibo_aceptado' || t == 'recibo_rechazado') {
                    final rid = d['recibo_event_id'] as String?;
                    if (rid != null) respuestasRecibo[rid] = d;
                  }
                  if (t == 'calificacion_aceptada' ||
                      t == 'calificacion_respondida') {
                    final cid = d['calificacion_event_id'] as String?;
                    if (cid != null) respuestasCalif[cid] = d;
                  }
                }

                final timeline = events.where((e) {
                  final t = e.data()['tipo'] as String? ?? '';
                  return t == 'recibo_emitido' ||
                      t == 'mensaje_texto' ||
                      t == 'calificacion_recibida';
                }).toList();

                if (timeline.isEmpty) {
                  return Center(
                    child: Padding(
                      padding: const EdgeInsets.all(28),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(Icons.chat_bubble_outline,
                              size: 48, color: Color(0xFF94A3B8)),
                          const SizedBox(height: 12),
                          const Text(
                            'Todav\u00eda no hay mensajes en este hilo',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              fontWeight: FontWeight.w800,
                              fontSize: 16,
                            ),
                          ),
                          const SizedBox(height: 8),
                          const Text(
                            'Escrib\u00ed algo o emit\u00ed un recibo cuando haya un pago o se\u00f1a.',
                            textAlign: TextAlign.center,
                            style: TextStyle(color: Color(0xFF64748B)),
                          ),
                          const SizedBox(height: 20),
                          FilledButton.icon(
                            onPressed: _openEmitir,
                            style: FilledButton.styleFrom(
                              backgroundColor: _primary,
                            ),
                            icon: const Icon(Icons.receipt_long),
                            label: const Text('Emitir recibo'),
                          ),
                        ],
                      ),
                    ),
                  );
                }

                return ListView.builder(
                  controller: _scrollCtrl,
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
                  itemCount: timeline.length,
                  itemBuilder: (context, i) {
                    final doc = timeline[i];
                    final d = doc.data();
                    final tipo = d['tipo'] as String? ?? '';

                    if (tipo == 'mensaje_texto') {
                      final mine = d['actor_uid'] == myUid;
                      return _TextoBubble(
                        texto: (d['texto'] as String?) ?? '',
                        iso: (d['created_at_iso'] as String?) ?? '',
                        mine: mine,
                      );
                    }

                    if (tipo == 'calificacion_recibida') {
                      final resp = respuestasCalif[doc.id];
                      final soyCliente = d['actor_uid'] == myUid;
                      final puedoResponder =
                          !soyCliente && resp == null && !_busy;
                      return _CalificacionCard(
                        data: d,
                        eventId: doc.id,
                        respuesta: resp,
                        soyCliente: soyCliente,
                        puedoResponder: puedoResponder,
                        otherName: _otherName,
                        onAceptar: () => _responderCalificacion(
                          calificacionEventId: doc.id,
                          decision: 'aceptado',
                        ),
                        onResponder: () =>
                            _confirmResponderCalificacion(doc.id),
                      );
                    }

                    final resp = respuestasRecibo[doc.id];
                    final soyEmisor = d['actor_uid'] == myUid;
                    final puedoResponder =
                        !soyEmisor && resp == null && !_busy;

                    return _ReciboCard(
                      data: d,
                      eventId: doc.id,
                      respuesta: resp,
                      soyEmisor: soyEmisor,
                      puedoResponder: puedoResponder,
                      otherName: _otherName,
                      onAceptar: () => _responderRecibo(
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
          Material(
            color: Colors.white,
            elevation: 8,
            child: Padding(
              padding: EdgeInsets.fromLTRB(12, 10, 12, 10 + bottomInset),
              child: SafeArea(
                top: false,
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Expanded(
                      child: TextField(
                        controller: _textCtrl,
                        minLines: 1,
                        maxLines: 4,
                        maxLength: 500,
                        textInputAction: TextInputAction.send,
                        onSubmitted: (_) => _enviarTexto(),
                        decoration: InputDecoration(
                          hintText: 'Escrib\u00ed un mensaje\u2026',
                          counterText: '',
                          filled: true,
                          fillColor: const Color(0xFFF1F5F9),
                          contentPadding: const EdgeInsets.symmetric(
                            horizontal: 14,
                            vertical: 12,
                          ),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(22),
                            borderSide: BorderSide.none,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Material(
                      color: _primary,
                      shape: const CircleBorder(),
                      child: IconButton(
                        onPressed: _sending ? null : _enviarTexto,
                        icon: _sending
                            ? const SizedBox(
                                width: 18,
                                height: 18,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: Colors.white,
                                ),
                              )
                            : const Icon(Icons.send_rounded,
                                color: Colors.white),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _TextoBubble extends StatelessWidget {
  final String texto;
  final String iso;
  final bool mine;

  const _TextoBubble({
    required this.texto,
    required this.iso,
    required this.mine,
  });

  @override
  Widget build(BuildContext context) {
    final time = iso.isNotEmpty
        ? iso.replaceFirst('T', ' ').split('.').first
        : '';
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Align(
        alignment: mine ? Alignment.centerRight : Alignment.centerLeft,
        child: ConstrainedBox(
          constraints: BoxConstraints(
            maxWidth: MediaQuery.of(context).size.width * 0.78,
          ),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: BoxDecoration(
              color: mine ? const Color(0xFF28B5CD) : Colors.white,
              borderRadius: BorderRadius.only(
                topLeft: const Radius.circular(16),
                topRight: const Radius.circular(16),
                bottomLeft: Radius.circular(mine ? 16 : 4),
                bottomRight: Radius.circular(mine ? 4 : 16),
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.04),
                  blurRadius: 6,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Column(
              crossAxisAlignment:
                  mine ? CrossAxisAlignment.end : CrossAxisAlignment.start,
              children: [
                Text(
                  texto,
                  style: TextStyle(
                    color: mine ? Colors.white : const Color(0xFF0F172A),
                    fontSize: 15,
                    height: 1.35,
                  ),
                ),
                if (time.isNotEmpty) ...[
                  const SizedBox(height: 4),
                  Text(
                    time,
                    style: TextStyle(
                      fontSize: 10,
                      color: mine
                          ? Colors.white.withOpacity(0.75)
                          : const Color(0xFF94A3B8),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _CalificacionCard extends StatelessWidget {
  final Map<String, dynamic> data;
  final String eventId;
  final Map<String, dynamic>? respuesta;
  final bool soyCliente;
  final bool puedoResponder;
  final String? otherName;
  final VoidCallback onAceptar;
  final VoidCallback onResponder;

  const _CalificacionCard({
    required this.data,
    required this.eventId,
    required this.respuesta,
    required this.soyCliente,
    required this.puedoResponder,
    required this.otherName,
    required this.onAceptar,
    required this.onResponder,
  });

  @override
  Widget build(BuildContext context) {
    final estrellas = (data['estrellas'] is num)
        ? (data['estrellas'] as num).toInt()
        : int.tryParse('${data['estrellas']}') ?? 0;
    final comentario = (data['comentario'] as String?)?.trim() ?? '';
    final iso = (data['created_at_iso'] as String?) ?? '';
    final decision = respuesta?['decision'] as String?;
    final respTexto = (respuesta?['respuesta_texto'] as String?)?.trim() ?? '';
    final quien = otherName ?? 'la otra parte';

    Color border = const Color(0xFFF59E0B);
    String estadoLabel = soyCliente
        ? 'Esperando a $quien'
        : 'Pendiente de tu confirmaci\u00f3n';
    Color estadoColor = const Color(0xFFB45309);

    if (decision == 'aceptado') {
      border = const Color(0xFF16A34A);
      estadoLabel = 'Aceptada';
      estadoColor = const Color(0xFF16A34A);
    } else if (decision == 'respondido') {
      border = const Color(0xFF28B5CD);
      estadoLabel = 'Respondida';
      estadoColor = const Color(0xFF1A8FA3);
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
            border: Border.all(color: border.withOpacity(0.65), width: 1.5),
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
                      color: const Color(0xFFF59E0B).withOpacity(0.15),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Text(
                      'Evaluaci\u00f3n',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w800,
                        color: Color(0xFFB45309),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      soyCliente ? 'Vos enviaste' : 'Te calificaron',
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
              const SizedBox(height: 14),
              Row(
                children: List.generate(5, (i) {
                  final filled = i < estrellas;
                  return Icon(
                    filled ? Icons.star_rounded : Icons.star_outline_rounded,
                    size: 28,
                    color: filled
                        ? const Color(0xFFF59E0B)
                        : const Color(0xFFCBD5E1),
                  );
                }),
              ),
              if (comentario.isNotEmpty) ...[
                const SizedBox(height: 10),
                Text(
                  comentario,
                  style: const TextStyle(
                    fontSize: 14,
                    height: 1.4,
                    color: Color(0xFF334155),
                  ),
                ),
              ],
              if (iso.isNotEmpty) ...[
                const SizedBox(height: 8),
                Text(
                  iso.replaceFirst('T', ' ').split('.').first,
                  style: const TextStyle(
                    fontSize: 11,
                    color: Color(0xFF94A3B8),
                  ),
                ),
              ],
              if (respTexto.isNotEmpty) ...[
                const SizedBox(height: 12),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF0FDFA),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: const Color(0xFF99F6E4)),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        soyCliente ? 'Respuesta del prestador' : 'Tu respuesta',
                        style: const TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w800,
                          color: Color(0xFF0F766E),
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        respTexto,
                        style: const TextStyle(
                          fontSize: 13,
                          height: 1.35,
                          color: Color(0xFF134E4A),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
              if (puedoResponder) ...[
                const SizedBox(height: 16),
                const Text(
                  '\u00bfPublicamos esta evaluaci\u00f3n en tu perfil?',
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
                          'Aceptar',
                          style: TextStyle(fontWeight: FontWeight.w800),
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: OutlinedButton(
                        onPressed: onResponder,
                        style: OutlinedButton.styleFrom(
                          foregroundColor: const Color(0xFF1A8FA3),
                          side: const BorderSide(color: Color(0xFF28B5CD)),
                          padding: const EdgeInsets.symmetric(vertical: 12),
                        ),
                        child: const Text(
                          'Responder',
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
        : 'Pendiente de tu confirmaci\u00f3n';
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
              Container(
                width: double.infinity,
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
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
                            'Registro sellado \u00b7 no editable',
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
                        'Firma $hashShort\u2026',
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
                  '\u00bfConfirm\u00e1s que recibiste este monto?',
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
                          'S\u00ed, gracias',
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
