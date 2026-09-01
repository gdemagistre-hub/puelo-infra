import 'country_profile.dart';

/// Normaliza y valida celular en E.164 usando [CountryProfile].
/// AR conserva la regla vigente: `+` y exactamente 13 dígitos.
class TelefonoE164 {
  TelefonoE164._();

  static String digits(String raw) => raw.replaceAll(RegExp(r'\D'), '');

  static String forWhatsApp(String raw) => digits(raw);

  static String normalize(String raw, {String? iso}) {
    final p = CountryProfile.of(iso);
    final trimmed = raw.trim();
    if (trimmed.isEmpty) return trimmed;
    final d = digits(trimmed);
    if (d.isEmpty) return trimmed;
    final dial = digits(p.dialCode);
    if (dial.isNotEmpty && d.startsWith(dial)) {
      return '+$d';
    }
    return '${p.dialCode}$d';
  }

  static String? validar(String? raw, {String? iso}) {
    final p = CountryProfile.of(iso);
    final t = (raw ?? '').trim();
    if (t.isEmpty) return 'El celular es obligatorio';
    if (p.iso == 'AR') {
      if (!RegExp(r'^\+\d{13}$').hasMatch(t)) {
        return 'Formato: + y 13 numeros (ej: +5491112345678)';
      }
      return null;
    }
    if (!t.startsWith('+')) {
      return 'Formato: ${p.phoneExample}';
    }
    final d = digits(t);
    final dial = digits(p.dialCode);
    if (dial.isNotEmpty && !d.startsWith(dial)) {
      return 'Debe empezar con ${p.dialCode}';
    }
    if (d.length < p.phoneMin || d.length > p.phoneMax) {
      return 'Formato: ${p.phoneExample}';
    }
    return null;
  }
}
