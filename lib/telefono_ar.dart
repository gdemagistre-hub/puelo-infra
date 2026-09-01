import 'package:flutter/services.dart';

import 'geo/country_profile.dart';
import 'geo/telefono_e164.dart';
import 'user_session.dart';

/// Celular. AR: + y 13 dígitos (regla vigente).
/// Otros países: E.164 según [CountryProfile].
class TelefonoAr {
  static CountryProfile get _profile =>
      CountryProfile.of(UserSession().countryCode);

  static final allowChars = FilteringTextInputFormatter.allow(RegExp(r'[+\d]'));

  static TextInputFormatter get lengthLimit =>
      LengthLimitingTextInputFormatter(1 + _profile.phoneMax);

  static String? validar(String? v) =>
      TelefonoE164.validar(v, iso: UserSession().countryCode);

  static String hint() => _profile.phoneExample;

  static String helper() {
    if (_profile.iso == 'AR') return '+ y 13 digitos, sin espacios';
    return '${_profile.dialCode} · ejemplo ${_profile.phoneExample}';
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
    final maxDigits = CountryProfile.of(UserSession().countryCode).phoneMax;
    final digits = text.replaceAll(RegExp(r'\D'), '');
    final limited =
        digits.length > maxDigits ? digits.substring(0, maxDigits) : digits;
    final result = '+$limited';
    return TextEditingValue(
      text: result,
      selection: TextSelection.collapsed(offset: result.length),
    );
  }
}
