import 'package:flutter/services.dart';
import 'package:intl/intl.dart';

/// Formatea mientras se escribe: 45000 → 45.000
class ThousandsFormatter extends TextInputFormatter {
  ThousandsFormatter({this.allowDecimal = false});

  final bool allowDecimal;
  final _fmt = NumberFormat('#,##0', 'es_AR');

  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    if (newValue.text.isEmpty) {
      return newValue;
    }

    var raw = newValue.text.replaceAll('.', '').replaceAll(' ', '');
    if (!allowDecimal) {
      raw = raw.replaceAll(RegExp(r'[^0-9]'), '');
    } else {
      raw = raw.replaceAll(RegExp(r'[^0-9,]'), '');
      final parts = raw.split(',');
      if (parts.length > 2) {
        raw = '${parts[0]},${parts.sublist(1).join()}';
      }
    }

    if (raw.isEmpty) {
      return const TextEditingValue(text: '');
    }

    if (allowDecimal && raw.contains(',')) {
      final parts = raw.split(',');
      final intPart = int.tryParse(parts[0].isEmpty ? '0' : parts[0]) ?? 0;
      final dec = parts.length > 1 ? parts[1] : '';
      final formatted = '${_fmt.format(intPart)},$dec';
      return TextEditingValue(
        text: formatted,
        selection: TextSelection.collapsed(offset: formatted.length),
      );
    }

    final number = int.tryParse(raw);
    if (number == null) return oldValue;
    final formatted = _fmt.format(number);
    return TextEditingValue(
      text: formatted,
      selection: TextSelection.collapsed(offset: formatted.length),
    );
  }

  static double? parse(String text) {
    final raw =
        text.replaceAll('.', '').replaceAll(' ', '').replaceAll(',', '.');
    return double.tryParse(raw);
  }
}
