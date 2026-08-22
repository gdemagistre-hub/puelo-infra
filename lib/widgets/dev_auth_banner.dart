import 'package:flutter/material.dart';

import '../loginScreen.dart';
import '../user_session.dart';

/// Banner persistente cuando la sesión es solo dropdown (sin token Firebase).
class DevAuthBanner extends StatelessWidget {
  const DevAuthBanner({super.key, this.topPadding = 8});

  final double topPadding;

  @override
  Widget build(BuildContext context) {
    if (!UserSession().needsRealAuth) return const SizedBox.shrink();

    return Positioned(
      left: 12,
      right: 12,
      top: MediaQuery.of(context).padding.top + topPadding,
      child: Material(
        elevation: 3,
        borderRadius: BorderRadius.circular(12),
        color: const Color(0xFFFEF3C7),
        child: InkWell(
          borderRadius: BorderRadius.circular(12),
          onTap: () {
            Navigator.of(context).pushAndRemoveUntil(
              MaterialPageRoute(builder: (_) => const LoginScreenWidget()),
              (route) => false,
            );
          },
          child: const Padding(
            padding: EdgeInsets.fromLTRB(12, 10, 12, 10),
            child: Row(
              children: [
                Icon(Icons.lock_outline_rounded, color: Color(0xFFB45309), size: 20),
                SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Fotos, mensajes y Mis números requieren Google o Email. Tocá para iniciar sesión real.',
                    style: TextStyle(
                      color: Color(0xFF92400E),
                      fontSize: 12.5,
                      fontWeight: FontWeight.w600,
                      height: 1.3,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
