import 'package:cloud_firestore/cloud_firestore.dart';

/// Censo puntual de `usuarios` para Consola Prox (solo admin, 1 lectura).
class UsuariosResumen {
  const UsuariosResumen({
    this.total = 0,
    this.ayer = 0,
    this.loginProx = 0,
    this.loginGoogle = 0,
    this.loginApple = 0,
    this.loginOtro = 0,
    this.soloCliente = 0,
    this.soloPrestador = 0,
    this.ambos = 0,
    this.omitidos = 0,
    this.capped = false,
    this.error,
  });

  final int total;
  final int ayer;
  final int loginProx;
  final int loginGoogle;
  final int loginApple;
  final int loginOtro;
  final int soloCliente;
  final int soloPrestador;
  final int ambos;
  final int omitidos;
  final bool capped;
  final String? error;

  static const int limite = 800;

  static DateTime _artCalendarDay(DateTime utc) {
    final art = utc.toUtc().subtract(const Duration(hours: 3));
    return DateTime.utc(art.year, art.month, art.day);
  }

  static DateTime? _asDate(dynamic raw) {
    if (raw is Timestamp) return raw.toDate().toUtc();
    if (raw is DateTime) return raw.toUtc();
    if (raw is String && raw.isNotEmpty) {
      return DateTime.tryParse(raw)?.toUtc();
    }
    return null;
  }

  static bool _esPrestador(Map<String, dynamic> d) {
    if (d['es_trabajador'] == true) return true;
    final rol = (d['rol'] ?? '').toString().toLowerCase();
    if (rol.contains('trabaj') || rol.contains('prestador')) return true;
    final camino = (d['camino_elegido'] ?? '').toString().trim().toLowerCase();
    if (camino == 'ofrezo' || camino == 'ofrezco' || camino.contains('ofrec')) {
      return true;
    }
    final prof = d['profesiones'];
    if (prof is List && prof.isNotEmpty) return true;
    final cats = d['categorias_servicio'];
    if (cats is List && cats.isNotEmpty) return true;
    return false;
  }

  static String _loginBucket(Map<String, dynamic> d) {
    final raw = (d['auth_provider'] ?? '').toString().trim().toLowerCase();
    if (raw == 'password' || raw == 'email' || raw == 'prox') return 'prox';
    if (raw == 'google' || raw == 'google.com') return 'google';
    if (raw == 'apple' || raw == 'apple.com') return 'apple';
    return 'otro';
  }

  static Future<UsuariosResumen> cargar() async {
    try {
      final snap = await FirebaseFirestore.instance
          .collection('usuarios')
          .limit(limite)
          .get();

      final ayerArt = _artCalendarDay(DateTime.now())
          .subtract(const Duration(days: 1));

      var total = 0;
      var ayer = 0;
      var loginProx = 0;
      var loginGoogle = 0;
      var loginApple = 0;
      var loginOtro = 0;
      var soloCliente = 0;
      var soloPrestador = 0;
      var ambos = 0;
      var omitidos = 0;

      for (final doc in snap.docs) {
        final d = doc.data();
        if (d['cuenta_eliminada'] == true) {
          omitidos++;
          continue;
        }
        total++;

        final created = _asDate(d['creado_en'] ?? d['created_at']);
        if (created != null && _artCalendarDay(created) == ayerArt) {
          ayer++;
        }

        switch (_loginBucket(d)) {
          case 'prox':
            loginProx++;
            break;
          case 'google':
            loginGoogle++;
            break;
          case 'apple':
            loginApple++;
            break;
          default:
            loginOtro++;
        }

        final prestador = _esPrestador(d);
        final camino =
            (d['camino_elegido'] ?? '').toString().trim().toLowerCase();
        final busco = camino == 'busco' || camino.contains('busc');
        if (prestador && busco) {
          ambos++;
        } else if (prestador) {
          soloPrestador++;
        } else {
          soloCliente++;
        }
      }

      return UsuariosResumen(
        total: total,
        ayer: ayer,
        loginProx: loginProx,
        loginGoogle: loginGoogle,
        loginApple: loginApple,
        loginOtro: loginOtro,
        soloCliente: soloCliente,
        soloPrestador: soloPrestador,
        ambos: ambos,
        omitidos: omitidos,
        capped: snap.docs.length >= limite,
      );
    } catch (e) {
      return UsuariosResumen(error: '$e');
    }
  }
}
