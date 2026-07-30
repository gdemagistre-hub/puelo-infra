import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'catalogo_geo_cache.dart';
import 'analytics/prox_analytics.dart';

/// Sesión en memoria + uid persistido para sobrevivir F5 / kill del proceso.
///
/// Sin Firebase Auth todavía: el uid del dropdown (o del último login) se
/// guarda en SharedPreferences y se rehidrata leyendo usuarios/{uid}.
/// Cuando exista Auth, esta capa debe delegar en el token y no en prefs solas.
class UserSession {
  static final UserSession _instance = UserSession._internal();
  factory UserSession() => _instance;
  UserSession._internal();

  static const String _prefsUidKey = 'puelo_session_uid';

  String? uid;
  String? nombre;
  String? apellido;
  Map<String, dynamic>? datosCompletos;

  /// Token de una validación de domicilio pendiente
  String? pendingValidacionToken;

  bool get isLoggedIn => uid != null && uid!.isNotEmpty;

  void iniciarSesion(String id, Map<String, dynamic> data) {
    uid = id;
    nombre = data['nombre'] ?? '';
    apellido = data['apellido'] ?? '';
    datosCompletos = data;
    // Persistencia best-effort (no bloquea el UI del login).
    _persistUid(id);
  }

  /// Admin de consola Prox (campo en Firestore usuarios/{id}).
  bool get isAdmin {
    final d = datosCompletos;
    if (d == null) return false;
    return d['es_admin'] == true || d['rol'] == 'admin';
  }

  /// Restaura sesión desde prefs + Firestore. true si quedó logueado.
  Future<bool> restaurarSesion() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final savedUid = prefs.getString(_prefsUidKey);
      if (savedUid == null || savedUid.isEmpty) return false;

      final doc = await FirebaseFirestore.instance
          .collection('usuarios')
          .doc(savedUid)
          .get();

      if (!doc.exists || doc.data() == null) {
        await prefs.remove(_prefsUidKey);
        return false;
      }

      // No re-disparar persist (mismo uid).
      uid = savedUid;
      final data = doc.data()!;
      nombre = data['nombre'] ?? '';
      apellido = data['apellido'] ?? '';
      datosCompletos = data;

      final esPrestador =
          data['es_trabajador'] == true || data['rol'] == 'trabajador';
      try {
        ProxAnalytics.instance.startSession(
          role: esPrestador ? 'prestador' : 'cliente',
        );
      } catch (_) {}

      return true;
    } catch (e) {
      debugPrint('UserSession.restaurarSesion error: $e');
      return false;
    }
  }

  Future<void> _persistUid(String id) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_prefsUidKey, id);
    } catch (e) {
      debugPrint('UserSession._persistUid error: $e');
    }
  }

  Future<void> cerrarSesion() async {
    try {
      ProxAnalytics.instance.endSession(reason: 'logout');
    } catch (_) {}
    uid = null;
    nombre = null;
    apellido = null;
    datosCompletos = null;
    pendingValidacionToken = null;
    CatalogoGeoCache.instance.clear();
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_prefsUidKey);
    } catch (e) {
      debugPrint('UserSession.cerrarSesion prefs error: $e');
    }
  }

  String get nombreCompleto => '$nombre $apellido'.trim();

  void setPendingValidacion(String token) {
    pendingValidacionToken = token;
  }

  void clearPendingValidacion() {
    pendingValidacionToken = null;
  }
}
