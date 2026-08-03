import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'catalogo_geo_cache.dart';
import 'analytics/prox_analytics.dart';

/// Sesión en memoria + persistencia.
///
/// Prioridad al restaurar:
/// 1) Firebase Auth (Google / futuros providers)
/// 2) SharedPreferences uid del dropdown de prueba (impersonación)
class UserSession {
  static final UserSession _instance = UserSession._internal();
  factory UserSession() => _instance;
  UserSession._internal();

  static const String _prefsUidKey = 'puelo_session_uid';
  static const String _prefsDevKey = 'puelo_session_dev';

  String? uid;
  String? nombre;
  String? apellido;
  Map<String, dynamic>? datosCompletos;

  /// google | facebook | apple | email | dev | null
  String? authProvider;

  /// true = entró por pulldown (sin Firebase Auth)
  bool isDevImpersonation = false;

  /// Token de una validación de domicilio pendiente
  String? pendingValidacionToken;

  /// Cache liviano Home prestador (evita re-fetch al volver a la pestaña).
  DateTime? _homeCacheAt;
  Map<String, dynamic>? _homeCacheData;
  static const Duration homeCacheTtl = Duration(seconds: 45);

  bool get isLoggedIn => uid != null && uid!.isNotEmpty;

  Map<String, dynamic>? get homeCacheIfFresh {
    final at = _homeCacheAt;
    final data = _homeCacheData;
    if (at == null || data == null) return null;
    if (DateTime.now().difference(at) > homeCacheTtl) return null;
    return data;
  }

  void setHomeCache(Map<String, dynamic> data) {
    _homeCacheData = Map<String, dynamic>.from(data);
    _homeCacheAt = DateTime.now();
  }

  void invalidateHomeCache() {
    _homeCacheData = null;
    _homeCacheAt = null;
  }

  void iniciarSesion(
    String id,
    Map<String, dynamic> data, {
    String? authProvider,
    bool isDevImpersonation = false,
  }) {
    uid = id;
    nombre = data['nombre'] ?? '';
    apellido = data['apellido'] ?? '';
    datosCompletos = data;
    this.authProvider = authProvider ??
        (data['auth_provider'] as String?) ??
        (isDevImpersonation ? 'dev' : null);
    this.isDevImpersonation = isDevImpersonation;
    _persistUid(id, isDev: isDevImpersonation);
  }

  /// Admin de consola Prox (campo en Firestore usuarios/{id}).
  bool get isAdmin {
    final d = datosCompletos;
    if (d == null) return false;
    return d['es_admin'] == true || d['rol'] == 'admin';
  }

  /// Restaura: Auth real primero, luego prefs del dropdown.
  Future<bool> restaurarSesion() async {
    try {
      // 1) Firebase Auth
      final user = FirebaseAuth.instance.currentUser;
      if (user != null) {
        final doc = await FirebaseFirestore.instance
            .collection('usuarios')
            .doc(user.uid)
            .get();

        Map<String, dynamic> data;
        if (doc.exists && doc.data() != null) {
          data = doc.data()!;
        } else {
          // Perfil mínimo si Auth existe pero falta el doc (race / borrado).
          final display = (user.displayName ?? '').trim();
          String nombre = '';
          String apellido = '';
          if (display.isNotEmpty) {
            final parts = display.split(RegExp(r'\s+'));
            nombre = parts.first;
            if (parts.length > 1) apellido = parts.sublist(1).join(' ');
          }
          data = {
            'nombre': nombre,
            'apellido': apellido,
            'email': user.email ?? '',
            if (user.photoURL != null) 'url_foto_perfil': user.photoURL,
            'auth_provider': 'google',
            'auth_uid': user.uid,
            'es_trabajador': false,
            'estado': 'activo',
          };
          await FirebaseFirestore.instance
              .collection('usuarios')
              .doc(user.uid)
              .set({
            ...data,
            'creado_en': FieldValue.serverTimestamp(),
            'updated_at': FieldValue.serverTimestamp(),
          }, SetOptions(merge: true));
        }

        uid = user.uid;
        nombre = data['nombre'] ?? '';
        apellido = data['apellido'] ?? '';
        datosCompletos = data;
        authProvider = (data['auth_provider'] as String?) ?? 'google';
        isDevImpersonation = false;
        await _persistUid(user.uid, isDev: false);

        final esPrestador =
            data['es_trabajador'] == true || data['rol'] == 'trabajador';
        try {
          ProxAnalytics.instance.startSession(
            role: esPrestador ? 'prestador' : 'cliente',
          );
        } catch (_) {}
        return true;
      }

      // 2) Impersonación dev (dropdown)
      final prefs = await SharedPreferences.getInstance();
      final savedUid = prefs.getString(_prefsUidKey);
      final wasDev = prefs.getBool(_prefsDevKey) ?? true;
      if (savedUid == null || savedUid.isEmpty) return false;

      // Si no era dev y no hay Auth, limpiar (sesión inconsistente).
      if (!wasDev) {
        await prefs.remove(_prefsUidKey);
        await prefs.remove(_prefsDevKey);
        return false;
      }

      final doc = await FirebaseFirestore.instance
          .collection('usuarios')
          .doc(savedUid)
          .get();

      if (!doc.exists || doc.data() == null) {
        await prefs.remove(_prefsUidKey);
        await prefs.remove(_prefsDevKey);
        return false;
      }

      uid = savedUid;
      final data = doc.data()!;
      nombre = data['nombre'] ?? '';
      apellido = data['apellido'] ?? '';
      datosCompletos = data;
      authProvider = 'dev';
      isDevImpersonation = true;

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

  Future<void> _persistUid(String id, {required bool isDev}) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_prefsUidKey, id);
      await prefs.setBool(_prefsDevKey, isDev);
    } catch (e) {
      debugPrint('UserSession._persistUid error: $e');
    }
  }

  /// Solo limpia memoria + prefs. Para Auth real usar AuthService.signOut().
  Future<void> cerrarSesion() async {
    try {
      ProxAnalytics.instance.endSession(reason: 'logout');
    } catch (_) {}
    uid = null;
    nombre = null;
    apellido = null;
    datosCompletos = null;
    pendingValidacionToken = null;
    authProvider = null;
    isDevImpersonation = false;
    invalidateHomeCache();
    CatalogoGeoCache.instance.clear();
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_prefsUidKey);
      await prefs.remove(_prefsDevKey);
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
