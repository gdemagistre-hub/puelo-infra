import 'package:flutter/material.dart';

import '../user_session.dart';

/// Cierra el loop después de WhatsApp / llamada.
/// Primario: registrar comprobante. Secundario: ver tarjeta.
class PostContactoSheet {
  PostContactoSheet._();

  static const Color _primary = Color(0xFF734BE4);

  static Future<void> show(
    BuildContext context, {
    required String prestadorUid,
    String? prestadorNombre,
    required bool desdeTarjeta,
    VoidCallback? onPrimary,
    VoidCallback? onPagar,
  }) async {
    final me = UserSession().uid;
    if (me != null && me == prestadorUid) return;
    if (!context.mounted) return;

    final nombre = (prestadorNombre ?? '').trim();
    final titulo = nombre.isEmpty
        ? 'Ya le escribiste'
        : 'Le escribiste a $nombre';
    final puedePagar = onPagar != null || (desdeTarjeta && onPrimary != null);
    final puedeVerTarjeta = onPrimary != null && !desdeTarjeta;

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
                  'Cuando paguen el trabajo, registralo acá. '
                  'La otra parte lo confirma. No hace falta chat.',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 14,
                    height: 1.4,
                    color: Color(0xFF64748B),
                  ),
                ),
                const SizedBox(height: 20),
                if (puedePagar)
                  SizedBox(
                    height: 48,
                    child: ElevatedButton(
                      onPressed: () {
                        Navigator.pop(ctx);
                        if (onPagar != null) {
                          onPagar();
                        } else {
                          onPrimary?.call();
                        }
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: _primary,
                        foregroundColor: Colors.white,
                        elevation: 0,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      child: const Text(
                        'Doy un pago',
                        style: TextStyle(fontWeight: FontWeight.w800),
                      ),
                    ),
                  ),
                if (puedeVerTarjeta) ...[
                  const SizedBox(height: 8),
                  SizedBox(
                    height: 44,
                    child: OutlinedButton(
                      onPressed: () {
                        Navigator.pop(ctx);
                        onPrimary?.call();
                      },
                      style: OutlinedButton.styleFrom(
                        foregroundColor: _primary,
                        side: const BorderSide(color: _primary),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      child: const Text(
                        'Ver tarjeta',
                        style: TextStyle(fontWeight: FontWeight.w800),
                      ),
                    ),
                  ),
                ],
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
