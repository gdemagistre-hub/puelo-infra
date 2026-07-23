import 'dart:convert';
import 'package:crypto/crypto.dart';

class DatosOcrDni {
  final List<String> nombres;
  final List<String> apellidos;
  final String? numeroDocumento;
  final String? paisEmision;
  final DateTime? fechaNacimiento;
  final String textoCrudo;

  const DatosOcrDni({
    required this.nombres,
    required this.apellidos,
    this.numeroDocumento,
    this.paisEmision,
    this.fechaNacimiento,
    required this.textoCrudo,
  });
}

class ResultadoCotejoDni {
  final bool ok;
  final bool nombreOk;
  final bool apellidoOk;
  final bool documentoOk;
  final bool paisOk;
  final bool fechaOk;
  final String? hash;
  final DateTime? timestamp;

  const ResultadoCotejoDni({
    required this.ok,
    required this.nombreOk,
    required this.apellidoOk,
    required this.documentoOk,
    required this.paisOk,
    required this.fechaOk,
    this.hash,
    this.timestamp,
  });
}

class DniOcrParser {
  static String normTexto(String s) => s
      .toLowerCase()
      .replaceAll(RegExp(r'[áàä]'), 'a')
      .replaceAll(RegExp(r'[éèë]'), 'e')
      .replaceAll(RegExp(r'[íìï]'), 'i')
      .replaceAll(RegExp(r'[óòö]'), 'o')
      .replaceAll(RegExp(r'[úùü]'), 'u')
      .replaceAll('ñ', 'n')
      .replaceAll(RegExp(r'[^a-z0-9]'), '');

  static String normDoc(String s) => s.replaceAll(RegExp(r'\D'), '');

  static List<String> tokensPersona(String raw) {
    return raw
        .replaceAll(RegExp(r'[^A-Za-zÁÉÍÓÚáéíóúÑñÜü\s]'), ' ')
        .split(RegExp(r'\s+'))
        .map((e) => e.trim())
        .where((e) => e.length >= 2)
        .toList();
  }

  /// Parseo heurístico de DNI / documento latino
  static DatosOcrDni parsear(String texto) {
    final upper = texto.toUpperCase();
    final lineas = texto
        .replaceAll('\r', '\n')
        .split('\n')
        .map((e) => e.trim())
        .where((e) => e.isNotEmpty)
        .toList();

    String? numero;
    final dniMatch = RegExp(r'\b\d{1,2}\.?\d{3}\.?\d{3}\b').firstMatch(texto);
    if (dniMatch != null) {
      numero = dniMatch.group(0)!.replaceAll(RegExp(r'\D'), '');
    } else {
      final alt = RegExp(r'\b\d{7,9}\b').firstMatch(texto);
      if (alt != null) numero = alt.group(0);
    }

    DateTime? fecha;
    final fechaMatch = RegExp(r'\b(\d{2})[/-](\d{2})[/-](\d{4})\b').firstMatch(texto);
    if (fechaMatch != null) {
      final d = int.tryParse(fechaMatch.group(1)!);
      final m = int.tryParse(fechaMatch.group(2)!);
      final y = int.tryParse(fechaMatch.group(3)!);
      if (d != null && m != null && y != null) {
        try {
          fecha = DateTime(y, m, d);
        } catch (_) {}
      }
    }

    String? pais;
    if (upper.contains('ARGENTINA') || upper.contains('REPUBLICA ARGENTINA')) {
      pais = 'Argentina';
    } else if (upper.contains('URUGUAY')) {
      pais = 'Uruguay';
    } else if (upper.contains('CHILE')) {
      pais = 'Chile';
    } else if (upper.contains('PARAGUAY')) {
      pais = 'Paraguay';
    } else if (upper.contains('BRASIL') || upper.contains('BRAZIL')) {
      pais = 'Brasil';
    } else if (upper.contains('BOLIVIA')) {
      pais = 'Bolivia';
    }

    final nombres = <String>[];
    final apellidos = <String>[];

    for (var i = 0; i < lineas.length; i++) {
      final l = lineas[i].toUpperCase();
      if ((l.contains('APELLIDO') || l.contains('SURNAME')) && i + 1 < lineas.length) {
        apellidos.addAll(_tokensPersona(lineas[i + 1]));
      }
      if ((l.contains('NOMBRE') || l.contains('GIVEN') || l.contains('NAMES')) &&
          !l.contains('APELLIDO') &&
          i + 1 < lineas.length) {
        nombres.addAll(_tokensPersona(lineas[i + 1]));
      }
    }

    // Fallback: líneas en mayúsculas tipo persona
    if (nombres.isEmpty && apellidos.isEmpty) {
      for (final linea in lineas) {
        if (RegExp(r'^[A-ZÁÉÍÓÚÑ ]{3,}$').hasMatch(linea) &&
            !linea.contains('REPUBLICA') &&
            !linea.contains('ARGENTINA') &&
            !linea.contains('DOCUMENTO') &&
            !linea.contains('NACIONAL') &&
            !linea.contains('SEXO') &&
            !linea.contains('EJEMPLAR') &&
            !linea.contains('IDENTIDAD')) {
          final toks = _tokensPersona(linea);
          if (apellidos.isEmpty) {
            apellidos.addAll(toks);
          } else if (nombres.isEmpty) {
            nombres.addAll(toks);
          }
        }
      }
    }

    return DatosOcrDni(
      nombres: nombres.toSet().toList(),
      apellidos: apellidos.toSet().toList(),
      numeroDocumento: numero,
      paisEmision: pais,
      fechaNacimiento: fecha,
      textoCrudo: texto,
    );
  }

  static List<String> _tokensPersona(String raw) {
    return raw
        .replaceAll(RegExp(r'[^A-Za-zÁÉÍÓÚáéíóúÑñÜü\s]'), ' ')
        .split(RegExp(r'\s+'))
        .map((e) => e.trim())
        .where((e) => e.length >= 2)
        .toList();
  }

  static String _norm(String s) => s
      .toLowerCase()
      .replaceAll(RegExp(r'[áàä]'), 'a')
      .replaceAll(RegExp(r'[éèë]'), 'e')
      .replaceAll(RegExp(r'[íìï]'), 'i')
      .replaceAll(RegExp(r'[óòö]'), 'o')
      .replaceAll(RegExp(r'[úùü]'), 'u')
      .replaceAll('ñ', 'n')
      .replaceAll(RegExp(r'[^a-z0-9]'), '');

  static String _normDoc(String s) => s.replaceAll(RegExp(r'\D'), '');

  /// Reglas pedidas:
  /// - al menos un nombre OCR coincide con algún nombre cargado
  /// - al menos un apellido OCR coincide con algún apellido cargado
  /// - número de documento igual
  /// - país de emisión igual
  /// - fecha de nacimiento igual
  static ResultadoCotejoDni validarContraPerfil({
    required DatosOcrDni ocr,
    required String nombreUsuario,
    required String apellidoUsuario,
    required String numeroUsuario,
    required String? paisUsuario,
    required DateTime? fechaUsuario,
  }) {
    final nombresUser = _tokens(nombreUsuario).map(_norm).toSet();
    final apellidosUser = _tokens(apellidoUsuario).map(_norm).toSet();
    final nombresOcr = ocr.nombres.map(_norm).toSet();
    final apellidosOcr = ocr.apellidos.map(_norm).toSet();

    final nombreOk = nombresUser.isNotEmpty &&
        nombresOcr.isNotEmpty &&
        nombresUser.intersection(nombresOcr).isNotEmpty;

    final apellidoOk = apellidosUser.isNotEmpty &&
        apellidosOcr.isNotEmpty &&
        apellidosUser.intersection(apellidosOcr).isNotEmpty;

    final documentoOk = _normDoc(numeroUsuario).isNotEmpty &&
        ocr.numeroDocumento != null &&
        _normDoc(numeroUsuario) == _normDoc(ocr.numeroDocumento!);

    final paisOk = (paisUsuario ?? '').trim().isNotEmpty &&
        (ocr.paisEmision ?? '').trim().isNotEmpty &&
        _norm(paisUsuario!) == _norm(ocr.paisEmision!);

    bool fechaOk = false;
    if (fechaUsuario != null && ocr.fechaNacimiento != null) {
      fechaOk = fechaUsuario.year == ocr.fechaNacimiento!.year &&
          fechaUsuario.month == ocr.fechaNacimiento!.month &&
          fechaUsuario.day == ocr.fechaNacimiento!.day;
    }

    final ok = nombreOk && apellidoOk && documentoOk && paisOk && fechaOk;

    String? hash;
    DateTime? ts;
    if (ok) {
      ts = DateTime.now().toUtc();
      final payload = [
        _normDoc(numeroUsuario),
        nombresUser.join(','),
        apellidosUser.join(','),
        _norm(paisUsuario ?? ''),
        '${fechaUsuario!.year}-${fechaUsuario.month}-${fechaUsuario.day}',
        ts.toIso8601String(),
      ].join('|');
      hash = sha256.convert(utf8.encode(payload)).toString();
    }

    return ResultadoCotejoDni(
      ok: ok,
      nombreOk: nombreOk,
      apellidoOk: apellidoOk,
      documentoOk: documentoOk,
      paisOk: paisOk,
      fechaOk: fechaOk,
      hash: hash,
      timestamp: ts,
    );
  }

  /// Hash ancla (sin timestamp) para invalidar si el usuario edita datos clave
  static String hashDatosAncla({
    required String nombre,
    required String apellido,
    required String numero,
    required String? pais,
    required DateTime? fecha,
  }) {
    final payload = [
      _normDoc(numero),
      _tokens(nombre).map(_norm).join(','),
      _tokens(apellido).map(_norm).join(','),
      _norm(pais ?? ''),
      fecha == null ? '' : '${fecha.year}-${fecha.month}-${fecha.day}',
    ].join('|');
    return sha256.convert(utf8.encode(payload)).toString();
  }
}
