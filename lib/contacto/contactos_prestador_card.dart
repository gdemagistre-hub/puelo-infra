import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

import '../user_session.dart';

/// 5.9 — espejo del contacto para el prestador. No es un chat.
class ContactosPrestadorCard extends StatefulWidget {
  const ContactosPrestadorCard({super.key, this.onIrMensajes});

  final VoidCallback? onIrMensajes;

  @override
  State<ContactosPrestadorCard> createState() => _ContactosPrestadorCardState();
}

class _FilaContacto {
  final String clienteUid;
  final String nombre;
  final String tipo;
  final DateTime? at;
  _FilaContacto({
    required this.clienteUid,
    required this.nombre,
    required this.tipo,
    this.at,
  });
}

class _ContactosPrestadorCardState extends State<ContactosPrestadorCard> {
  static const Color _teal = Color(0xFF28B5CD);

  List<_FilaContacto> _filas = const [];
  int _unicos = 0;
  bool _ready = false;

  @override
  void initState() {
    super.initState();
    _cargar();
  }

  Future<void> _cargar() async {
    final uid = UserSession().uid;
    if (uid == null || uid.isEmpty || !UserSession().hasRealAuth) {
      if (mounted) setState(() => _ready = true);
      return;
    }
    try {
      final snap = await FirebaseFirestore.instance
          .collection('contactos')
          .where('prestador_uid', isEqualTo: uid)
          .limit(40)
          .get();
      final raw = snap.docs.toList();
      raw.sort((a, b) {
        final ta = a.data()['created_at'];
        final tb = b.data()['created_at'];
        final da = ta is Timestamp ? ta.toDate() : DateTime.fromMillisecondsSinceEpoch(0);
        final db = tb is Timestamp ? tb.toDate() : DateTime.fromMillisecondsSinceEpoch(0);
        return db.compareTo(da);
      });

      final seen = <String>{};
      final filas = <_FilaContacto>[];
      for (final doc in raw) {
        final d = doc.data();
        final cid = (d['cliente_uid'] ?? '').toString().trim();
        if (cid.isEmpty || cid == uid || !seen.add(cid)) continue;
        final hint = (d['cliente_nombre'] ?? '').toString().trim();
        final tipo = (d['tipo'] ?? 'whatsapp').toString();
        final ts = d['created_at'];
        filas.add(_FilaContacto(
          clienteUid: cid,
          nombre: hint,
          tipo: tipo,
          at: ts is Timestamp ? ts.toDate() : null,
        ));
      }

      final missing = filas.where((f) => f.nombre.isEmpty).toList();
      if (missing.isNotEmpty) {
        await Future.wait(missing.take(5).map((f) async {
          try {
            final u = await FirebaseFirestore.instance
                .collection('usuarios')
                .doc(f.clienteUid)
                .get();
            final data = u.data() ?? {};
            final comercial = (data['nombre_comercial'] ?? '').toString().trim();
            final n = (data['nombre'] ?? '').toString().trim();
            final a = (data['apellido'] ?? '').toString().trim();
            final label = comercial.isNotEmpty
                ? comercial
                : ('$n $a').trim();
            if (label.isEmpty) return;
            final i = filas.indexWhere((x) => x.clienteUid == f.clienteUid);
            if (i >= 0) {
              filas[i] = _FilaContacto(
                clienteUid: f.clienteUid,
                nombre: label,
                tipo: f.tipo,
                at: f.at,
              );
            }
          } catch (_) {}
        }));
      }

      if (!mounted) return;
      setState(() {
        _unicos = filas.length;
        _filas = filas.take(3).toList();
        _ready = true;
      });
    } catch (e) {
      debugPrint('ContactosPrestadorCard: $e');
      if (mounted) setState(() => _ready = true);
    }
  }

  String _cuando(DateTime? at) {
    if (at == null) return '';
    final now = DateTime.now();
    final d = DateTime(at.year, at.month, at.day);
    final today = DateTime(now.year, now.month, now.day);
    final diff = today.difference(d).inDays;
    if (diff == 0) return 'Hoy';
    if (diff == 1) return 'Ayer';
    if (diff < 7) return 'Hace $diff días';
    return '${at.day}/${at.month}';
  }

  String _tipoLabel(String tipo) =>
      tipo == 'llamada' ? 'Llamada' : 'WhatsApp';

  @override
  Widget build(BuildContext context) {
    if (!_ready || _filas.isEmpty) return const SizedBox.shrink();

    final titulo = _unicos == 1
        ? '1 cliente te contactó'
        : '$_unicos clientes te contactaron';

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
      child: Material(
        color: Colors.white,
        elevation: 2,
        shadowColor: _teal.withOpacity(0.12),
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 14, 16, 12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Te contactaron',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w800,
                  color: Color(0xFF0F172A),
                ),
              ),
              const SizedBox(height: 2),
              Text(
                titulo,
                style: const TextStyle(
                  fontSize: 13,
                  color: Color(0xFF64748B),
                ),
              ),
              const SizedBox(height: 10),
              ..._filas.map((f) {
                final label = f.nombre.isEmpty ? 'Cliente' : f.nombre;
                final initial = label[0].toUpperCase();
                final when = _cuando(f.at);
                return Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: Row(
                    children: [
                      CircleAvatar(
                        radius: 16,
                        backgroundColor: _teal.withOpacity(0.15),
                        child: Text(
                          initial,
                          style: const TextStyle(
                            fontWeight: FontWeight.w800,
                            fontSize: 13,
                            color: Color(0xFF1A8FA3),
                          ),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          label,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontWeight: FontWeight.w700,
                            fontSize: 14,
                            color: Color(0xFF0F172A),
                          ),
                        ),
                      ),
                      Text(
                        [
                          _tipoLabel(f.tipo),
                          if (when.isNotEmpty) when,
                        ].join(' · '),
                        style: const TextStyle(
                          fontSize: 11,
                          color: Color(0xFF94A3B8),
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                );
              }),
              const SizedBox(height: 4),
              const Text(
                'Cuando cierren el trabajo, el comprobante llega a Mensajes.',
                style: TextStyle(
                  fontSize: 12,
                  height: 1.35,
                  color: Color(0xFF64748B),
                ),
              ),
              if (widget.onIrMensajes != null) ...[
                const SizedBox(height: 10),
                Align(
                  alignment: Alignment.centerLeft,
                  child: TextButton(
                    onPressed: widget.onIrMensajes,
                    style: TextButton.styleFrom(
                      foregroundColor: _teal,
                      padding: EdgeInsets.zero,
                      minimumSize: const Size(0, 36),
                      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    ),
                    child: const Text(
                      'Ir a Mensajes',
                      style: TextStyle(fontWeight: FontWeight.w800),
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
