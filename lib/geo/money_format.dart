import 'package:intl/intl.dart';

import '../user_session.dart';

/// Formato de monto. AR se ve igual que hoy (`$12.000`).
/// Otras monedas agregan el código ISO.
class MoneyFormat {
  MoneyFormat._();

  static String code([String? currency]) {
    final c = (currency ?? UserSession().currency).trim().toUpperCase();
    return c.isEmpty ? 'ARS' : c;
  }

  static NumberFormat number() =>
      NumberFormat.currency(locale: 'es_AR', symbol: r'$', decimalDigits: 0);

  static String format(num n, {String? currency}) {
    final c = code(currency);
    final raw = number().format(n);
    if (c == 'ARS') return raw;
    return '$raw $c';
  }

  /// Estilo Mis números: `12.000 $` en AR; `12.000 UYU` en el resto.
  static String formatSuffix(num n, {String? currency}) {
    final c = code(currency);
    final body = number().format(n).replaceAll(r'$', '').trim();
    if (c == 'ARS') return '$body \$';
    return '$body $c';
  }
}
