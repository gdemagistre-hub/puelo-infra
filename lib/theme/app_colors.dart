import 'package:flutter/material.dart';

/// Tokens de color Puelo.
/// Cliente = busca/contrata · Prestador = ofrece servicios.
class AppColors {
  AppColors._();

  // Marca por rol
  static const Color cliente = Color(0xFF734BE4);
  static const Color prestador = Color(0xFF28B5CD);

  // Acentos compartidos
  static const Color accentCoral = Color(0xFFF75A6D);
  static const Color accentLightBlue = Color(0xFF7AAFFF);

  // Neutros
  static const Color dark = Color(0xFF3D4756);
  static const Color text = Color(0xFF1E293B);
  static const Color textMuted = Color(0xFF64748B);
  static const Color bg = Color(0xFFF8FAFC);
  static const Color surface = Colors.white;
  static const Color border = Color(0xFFE2E8F0);

  // Semánticos
  static const Color success = Color(0xFF16A34A);
  static const Color warning = Color(0xFFF59E0B);
  static const Color danger = Color(0xFFDC2626);
  static const Color whatsapp = Color(0xFF25D366);

  /// Primary según rol de UI (no confundir con rol de negocio persistido).
  static Color primaryFor({required bool modoPrestador}) =>
      modoPrestador ? prestador : cliente;

  // Legacy (solo para migrar pantallas viejas; no usar en código nuevo)
  @Deprecated('Usar AppColors.cliente o AppColors.prestador')
  static const Color legacyBlue = Color(0xFF0F52BA);
}
