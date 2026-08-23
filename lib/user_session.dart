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
  static const String _prefsHomeModoKey = 'puelo_home_modo_prestador';

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

  /// Incrementa cuando cambian estrellas/badge/score en sesión (Home escucha).
  final ValueNotifier<int> profileRevision = ValueNotifier<int>(0);

  bool get isLoggedIn => uid != null && uid!.isNotEmpty;

  /// Último modo Home elegido en este dispositivo (null = nunca guardado).
  bool? _homeModoPrestadorPref;

  /// Prestador si hay señal en el doc (flag, rol, camino u oficios).
  bool get esPrestador {
    final d = datosCompletos;
    if (d == null) return false;
    if (d['es_trabajador'] == true) return true;
    final rol = (d['rol'] ?? '').toString().trim().toLowerCase();
    if (rol == 'trabajador' || rol == 'prestador') return true;
    final camino = (d['camino_elegido'] ?? '').toString().trim().toLowerCase();
    if (camino == 'ofrezo' || camino == 'ofrezco') return true;
    final prof = d['profesiones'];
    if (prof is List && prof.isNotEmpty) return true;
    return false;
  }

  /// Modo Home al entrar: último toggle si existe, si no el rol detectado.
  bool get preferredHomeModoPrestador =>
      _homeModoPrestadorPref ?? esPrestador;

  Future<void> persistHomeModoPrestador(bool modoPrestador) async {
    _homeModoPrestadorPref = modoPrestador;
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(_prefsHomeModoKey, modoPrestador);
    } catch (e) {
      debugPrint('UserSession.persistHomeModoPrestador: $e');
    }
  }

  Future<void> _loadHomeModoPref() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      if (prefs.containsKey(_prefsHomeModoKey)) {
        _homeModoPrestadorPref = prefs.getBool(_prefsHomeModoKey);
      }
    } catch (e) {
      debugPrint('UserSession._loadHomeModoPref: $e');
    }
  }

  /// Token Firebase Auth real (Google, email o mintDevSession).
  bool get hasRealAuth => FirebaseAuth.instance.currentUser != null;

  /// Sesión sin token Firebase (ex-dropdown, prefs viejas, etc.): Storage/CF/rules fallan.
  /// TEMP: con dropdown oculto sigue sirviendo para sesiones residuales de prueba.
  bool get needsRealAuth => isLoggedIn && !hasRealAuth;

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

  /// Avisa a Home (y quien escuche) que datosCompletos cambió de forma relevante.
  void notifyProfileChanged() {
    invalidateHomeCache();
    profileRevision.value = profileRevision.value + 1;
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
    _loadHomeModoPref();
  }

  /// Admin de consola Prox.
  /// Preferir custom claim `admin` (Auth). Fallback a campo Firestore
  /// (solo confiable si rules bloquean write de es_admin — Sprint 0).
  bool get isAdmin {
    final d = datosCompletos;
    if (d == null) return false;
    if (d['es_admin'] == true || d['rol'] == 'admin') return true;
    return false;
  }

  /// Refresca claim admin desde Firebase Auth (si hay sesión real).
  Future<bool> refreshAdminFromClaims() async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) return isAdmin;
      final token = await user.getIdTokenResult(true);
      final claim = token.claims?['admin'] == true;
      if (claim && datosCompletos != null) {
        datosCompletos = {...datosCompletos!, 'es_admin': true};
      }
      return claim || isAdmin;
    } catch (e) {
      debugPrint('UserSession.refreshAdminFromClaims: $e');
      return isAdmin;
    }
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
          data = Map<String, dynamic>.from(doc.data()!);
          // Si el doc no tiene foto, usar la de Google Auth (no pisar selfie).
          final fp = (data['url_foto_perfil'] ?? data['foto_perfil'] ?? '')
              .toString()
              .trim();
          if (fp.isEmpty && (user.photoURL ?? '').trim().isNotEmpty) {
            data['url_foto_perfil'] = user.photoURL!.trim();
            data['foto_perfil_origen'] = data['foto_perfil_origen'] ?? 'google';
            try {
              await FirebaseFirestore.instance
                  .collection('usuarios')
                  .doc(user.uid)
                  .set({
                'url_foto_perfil': user.photoURL!.trim(),
                'foto_perfil_origen': 'google',
                'updated_at': FieldValue.serverTimestamp(),
              }, SetOptions(merge: true));
            } catch (_) {}
          }
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
        await _loadHomeModoPref();
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
      await _loadHomeModoPref();

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
    _homeModoPrestadorPref = null;
    invalidateHomeCache();
    profileRevision.value = 0;
    CatalogoGeoCache.instance.clear();
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_prefsUidKey);
      await prefs.remove(_prefsDevKey);
      await prefs.remove(_prefsHomeModoKey);
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
