import 'package:flutter/services.dart';

/// Celular AR: + y 13 digitos.
class TelefonoAr {
  static final allowChars = FilteringTextInputFormatter.allow(RegExp(r'[+\d]'));
  static final lengthLimit = LengthLimitingTextInputFormatter(14);

  static String? validar(String? v) {
    final t = (v ?? '').trim();
    if (t.isEmpty) return 'El celular es obligatorio';
    if (!RegExp(r'^\+\d{13}$').hasMatch(t)) {
      return 'Formato: + y 13 numeros (ej: +5491112345678)';
    }
    return null;
  }
}

class TelefonoInputFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    final text = newValue.text;
    if (text.isEmpty) return newValue;
    final digits = text.replaceAll(RegExp(r'\D'), '');
    final limited = digits.length > 13 ? digits.substring(0, 13) : digits;
    final result = '+$limited';
    return TextEditingValue(
      text: result,
      selection: TextSelection.collapsed(offset: result.length),
    );
  }
}
