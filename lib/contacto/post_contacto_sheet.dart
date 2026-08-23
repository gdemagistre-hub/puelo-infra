import 'package:flutter/material.dart';

import '../user_session.dart';

/// 5.8 — cierra el loop después de WhatsApp / llamada.
/// No es chat: explica que el comprobante se registra en la tarjeta.
class PostContactoSheet {
  PostContactoSheet._();

  static const Color _primary = Color(0xFF734BE4);

  static Future<void> show(
    BuildContext context, {
    required String prestadorUid,
    String? prestadorNombre,
    required bool desdeTarjeta,
    VoidCallback? onPrimary,
  }) async {
    final me = UserSession().uid;
    if (me != null && me == prestadorUid) return;
    if (!context.mounted) return;

    final nombre = (prestadorNombre ?? '').trim();
    final titulo = nombre.isEmpty
        ? 'Ya le escribiste'
        : 'Le escribiste a $nombre';
    final primaryLabel = desdeTarjeta ? 'Doy un pago' : 'Ver tarjeta';

    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 12, 20, 20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Center(
                  child: Container(
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(
                      color: const Color(0xFFCBD5E1),
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                const Icon(Icons.check_circle_rounded, color: _primary, size: 36),
                const SizedBox(height: 10),
                Text(
                  titulo,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w800,
                    color: Color(0xFF0F172A),
                  ),
                ),
                const SizedBox(height: 8),
                const Text(
                  'Cuando cierren el trabajo, registrá el comprobante '
                  'desde la tarjeta (Doy un pago). Queda en PROX; '
                  'no hace falta un chat acá.',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 14,
                    height: 1.4,
                    color: Color(0xFF64748B),
                  ),
                ),
                const SizedBox(height: 20),
                SizedBox(
                  height: 48,
                  child: ElevatedButton(
                    onPressed: () {
                      Navigator.pop(ctx);
                      onPrimary?.call();
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: _primary,
                      foregroundColor: Colors.white,
                      elevation: 0,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: Text(
                      primaryLabel,
                      style: const TextStyle(fontWeight: FontWeight.w800),
                    ),
                  ),
                ),
                const SizedBox(height: 8),
                SizedBox(
                  height: 44,
                  child: TextButton(
                    onPressed: () => Navigator.pop(ctx),
                    child: const Text(
                      'Ahora no',
                      style: TextStyle(
                        fontWeight: FontWeight.w700,
                        color: Color(0xFF64748B),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}
