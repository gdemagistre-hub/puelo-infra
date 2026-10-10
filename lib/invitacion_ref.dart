import 'package:shared_preferences/shared_preferences.dart';

/// Guarda solo el uid de quien invitó. Sin nombre, teléfono ni domicilio.
class InvitacionRef {
  static const _key = 'puelo_invitado_por';
  static final _uid = RegExp(r'^[A-Za-z0-9]{20,36}$');

  static String? sanitizar(String? raw) {
    final s = (raw ?? '').trim();
    if (!_uid.hasMatch(s)) return null;
    return s;
  }

  static Future<void> capturarDeUri(Uri uri) async {
    final v = sanitizar(uri.queryParameters['i']);
    if (v == null) return;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_key, v);
  }

  static Future<String?> pendienteDistintoDe(String uid) async {
    final prefs = await SharedPreferences.getInstance();
    final v = sanitizar(prefs.getString(_key));
    if (v == null || v == uid) return null;
    return v;
  }

  static Future<void> consumir() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_key);
  }
}
