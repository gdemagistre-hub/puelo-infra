import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'catalogo_geo_cache.dart';
import 'analytics/prox_analytics.dart';
import 'identidad_pii.dart';
import 'geo/country_profile.dart';

/// Sesión en memoria + persistencia.
///
/// Prioridad al restaurar:
/// 1) Firebase Auth (Google / Facebook / email)
/// 2) SharedPreferences uid legado (ya no hay dropdown)
class UserSession {
  static final UserSession _instance = UserSession._internal();
  factory UserSession() => _instance;
  UserSession._internal();

  static const String _prefsUidKey = 'puelo_session_uid';
  static const String _prefsDevKey = 'puelo_session_dev';
  static const String _prefsHomeModoKey = 'puelo_home_modo_prestador';
  static const String _prefsPendingTokenKey = 'puelo_pending_validacion_token';
  static const String _prefsPendingTargetKey = 'puelo_pending_validacion_target';

  String? uid;
  String? nombre;
  String? apellido;
  Map<String, dynamic>? datosCompletos;

  String? authProvider;

  bool isDevImpersonation = false;

  /// Solo custom claim `admin` (no el campo público es_admin).
  bool _adminClaim = false;

  String? pendingValidacionToken;
  String? pendingValidacionTargetId;

  DateTime? _homeCacheAt;
  Map<String, dynamic>? _homeCacheData;
  static const Duration homeCacheTtl = Duration(seconds: 45);

  final ValueNotifier<int> profileRevision = ValueNotifier<int>(0);

  bool get isLoggedIn => uid != null && uid!.isNotEmpty;

  /// ISO-3166. Legacy sin campo = AR.
  String get countryCode {
    final raw =
        (datosCompletos?['country_code'] ?? '').toString().trim().toUpperCase();
    return raw.isEmpty ? CountryProfile.defaultIso : CountryProfile.of(raw).iso;
  }

  /// ISO-4217. Legacy sin campo = moneda del perfil (ARS si AR).
  String get currency {
    final raw = (datosCompletos?['currency'] ?? '').toString().trim().toUpperCase();
    if (raw.isNotEmpty) return raw;
    return CountryProfile.of(countryCode).currency;
  }

  /// Backfill lazy. No pisa country_code ya seteado.
  Future<void> ensureCountryDefaults() async {
    final id = uid;
    if (id == null || id.isEmpty) return;
    final data = datosCompletos ?? {};
    final patch = CountryProfile.legacyPatch(data);
    if (patch.isEmpty) return;
    // Alta nueva: no inventar AR. EligePais escribe el país.
    final rawCc = (data['country_code'] ?? '').toString().trim();
    final camino = (data['camino_elegido'] ?? '').toString().trim();
    final esTrab = data['es_trabajador'] == true || data['rol'] == 'trabajador';
    if (rawCc.isEmpty &&
        data['pais_confirmado'] != true &&
        camino.isEmpty &&
        !esTrab) {
      return;
    }
    try {
      await FirebaseFirestore.instance.collection('usuarios').doc(id).set({
        ...patch,
        'updated_at': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
    } catch (e) {
      debugPrint('UserSession.ensureCountryDefaults: $e');
    }
    datosCompletos = {...data, ...patch};
  }

  bool? _homeModoPrestadorPref;

  String _homeModoKeyFor(String? id) {
    if (id == null || id.isEmpty) return _prefsHomeModoKey;
    return '${_prefsHomeModoKey}_$id';
  }

  bool? _boolFrom(dynamic v) {
    if (v is bool) return v;
    if (v is String) {
      final s = v.trim().toLowerCase();
      if (s == 'true' || s == '1') return true;
      if (s == 'false' || s == '0') return false;
    }
    return null;
  }

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

  bool get preferredHomeModoPrestador {
    if (!esPrestador) return false;
    return _homeModoPrestadorPref ?? true;
  }

  Future<void> persistHomeModoPrestador(bool modoPrestador) async {
    if (!esPrestador && modoPrestador) return;
    _homeModoPrestadorPref = modoPrestador;
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(_homeModoKeyFor(uid), modoPrestador);
    } catch (e) {
      debugPrint('UserSession.persistHomeModoPrestador prefs: $e');
    }
    final id = uid;
    if (id == null || id.isEmpty) return;
    try {
      await FirebaseFirestore.instance.collection('usuarios').doc(id).set({
        'home_modo_prestador': modoPrestador,
        'updated_at': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
      if (datosCompletos != null) {
        datosCompletos = {
          ...datosCompletos!,
          'home_modo_prestador': modoPrestador,
        };
      }
    } catch (e) {
      debugPrint('UserSession.persistHomeModoPrestador firestore: $e');
    }
  }

  Future<void> ensureHomeModoPrefLoaded() => _loadHomeModoPref();

  void _applyHomeModoFromProfile() {
    final fromDoc = _boolFrom(datosCompletos?['home_modo_prestador']);
    if (fromDoc != null) {
      _homeModoPrestadorPref ??= fromDoc;
    }
  }

  Future<void> _loadHomeModoPref() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final uidKey = _homeModoKeyFor(uid);
      if (prefs.containsKey(uidKey)) {
        _homeModoPrestadorPref = prefs.getBool(uidKey);
        return;
      }
      if (prefs.containsKey(_prefsHomeModoKey)) {
        _homeModoPrestadorPref = prefs.getBool(_prefsHomeModoKey);
        if (uid != null &&
            uid!.isNotEmpty &&
            _homeModoPrestadorPref != null) {
          await prefs.setBool(uidKey, _homeModoPrestadorPref!);
        }
        return;
      }
      _applyHomeModoFromProfile();
    } catch (e) {
      debugPrint('UserSession._loadHomeModoPref: $e');
      _applyHomeModoFromProfile();
    }
  }

  bool get hasRealAuth => FirebaseAuth.instance.currentUser != null;

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
    _adminClaim = false;
    _applyHomeModoFromProfile();
    _persistUid(id, isDev: isDevImpersonation);
    _loadHomeModoPref();
    hidratarIdentidad();
    refreshAdminFromClaims();
    ensureCountryDefaults();
  }

  Future<void> hidratarIdentidad() async {
    final id = uid;
    final data = datosCompletos;
    if (id == null || id.isEmpty || data == null) return;
    try {
      final merged = await IdentidadPii.hidratarYMigrar(id, data);
      if (uid != id) return;
      merged.removeWhere((_, v) => v is FieldValue);
      datosCompletos = merged;
      nombre = merged['nombre'] ?? nombre;
      apellido = merged['apellido'] ?? apellido;
    } catch (e) {
      debugPrint('UserSession.hidratarIdentidad: $e');
    }
  }

  bool get isAdmin {
    if (isDevImpersonation) return false;
    return _adminClaim;
  }

  Future<bool> refreshAdminFromClaims() async {
    try {
      if (isDevImpersonation) {
        _adminClaim = false;
        return false;
      }
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) {
        _adminClaim = false;
        return false;
      }
      final token = await user.getIdTokenResult(true);
      _adminClaim = token.claims?['admin'] == true;
      return _adminClaim;
    } catch (e) {
      debugPrint('UserSession.refreshAdminFromClaims: $e');
      return _adminClaim;
    }
  }

  Future<bool> restaurarSesion() async {
    try {
      await _loadPendingValidacion();
      User? user = FirebaseAuth.instance.currentUser;
      if (user == null && kIsWeb) {
        try {
          final cred = await FirebaseAuth.instance.getRedirectResult();
          user = cred.user;
        } catch (e) {
          debugPrint('UserSession.getRedirectResult: $e');
        }
      }
      if (user == null) {
        await Future<void>.delayed(const Duration(milliseconds: 500));
        user = FirebaseAuth.instance.currentUser;
      }
      if (user != null) {
        final doc = await FirebaseFirestore.instance
            .collection('usuarios')
            .doc(user.uid)
            .get();

        Map<String, dynamic> data;
        if (doc.exists && doc.data() != null) {
          data = Map<String, dynamic>.from(doc.data()!);
          final fp = (data['url_foto_perfil'] ?? data['foto_perfil'] ?? '')
              .toString()
              .trim();
          if (fp.isEmpty && (user.photoURL ?? '').trim().isNotEmpty) {
            data['url_foto_perfil'] = user.photoURL!.trim();
            data['foto_perfil_origen'] =
                data['foto_perfil_origen'] ?? 'facebook';
            try {
              await FirebaseFirestore.instance
                  .collection('usuarios')
                  .doc(user.uid)
                  .set({
                'url_foto_perfil': user.photoURL!.trim(),
                'foto_perfil_origen': data['foto_perfil_origen'],
                'updated_at': FieldValue.serverTimestamp(),
              }, SetOptions(merge: true));
            } catch (_) {}
          }
        } else {
          final display = (user.displayName ?? '').trim();
          String nombre = '';
          String apellido = '';
          if (display.isNotEmpty) {
            final parts = display.split(RegExp(r'\s+'));
            nombre = parts.first;
            if (parts.length > 1) apellido = parts.sublist(1).join(' ');
          }
          final provider = user.providerData.any((p) => p.providerId == 'facebook.com')
              ? 'facebook'
              : (user.providerData.any((p) => p.providerId == 'google.com')
                  ? 'google'
                  : (user.providerData.any((p) => p.providerId == 'password')
                      ? 'password'
                      : 'auth'));
          data = {
            'nombre': nombre,
            'apellido': apellido,
            'email': user.email ?? '',
            if (user.photoURL != null) 'url_foto_perfil': user.photoURL,
            'auth_provider': provider,
            'auth_uid': user.uid,
            'es_trabajador': false,
            'estado': 'activo',
          };
          await FirebaseFirestore.instance.collection('usuarios').doc(user.uid).set({
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
        await hidratarIdentidad();
        await refreshAdminFromClaims();

        try {
          ProxAnalytics.instance.startSession(
            role: esPrestador ? 'prestador' : 'cliente',
          );
        } catch (_) {}
        await _loadHomeModoPref();
        await _loadPendingValidacion();
        await ensureCountryDefaults();
        return true;
      }

      final prefs = await SharedPreferences.getInstance();
      final savedUid = prefs.getString(_prefsUidKey);
      final wasDev = prefs.getBool(_prefsDevKey) ?? true;
      if (savedUid == null || savedUid.isEmpty) return false;

      if (!wasDev) {
        await prefs.remove(_prefsUidKey);
        await prefs.remove(_prefsDevKey);
        return false;
      }

      // Dropdown de prueba retirado: no restaurar sesión local sin Auth.
      await prefs.remove(_prefsUidKey);
      await prefs.remove(_prefsDevKey);
      await _loadPendingValidacion();
      return false;
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

  Future<void> cerrarSesion() async {
    try {
      ProxAnalytics.instance.endSession(reason: 'logout');
    } catch (_) {}
    uid = null;
    nombre = null;
    apellido = null;
    datosCompletos = null;
    pendingValidacionToken = null;
    pendingValidacionTargetId = null;
    authProvider = null;
    isDevImpersonation = false;
    _adminClaim = false;
    _homeModoPrestadorPref = null;
    invalidateHomeCache();
    profileRevision.value = 0;
    CatalogoGeoCache.instance.clear();
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_prefsUidKey);
      await prefs.remove(_prefsDevKey);
      await prefs.remove(_prefsPendingTokenKey);
      await prefs.remove(_prefsPendingTargetKey);
    } catch (e) {
      debugPrint('UserSession.cerrarSesion prefs error: $e');
    }
  }

  String get nombreCompleto => '$nombre $apellido'.trim();

  Future<void> _loadPendingValidacion() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      pendingValidacionToken ??= prefs.getString(_prefsPendingTokenKey);
      pendingValidacionTargetId ??= prefs.getString(_prefsPendingTargetKey);
    } catch (e) {
      debugPrint('UserSession._loadPendingValidacion: $e');
    }
  }

  Future<void> _persistPendingValidacion() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      if (pendingValidacionToken != null && pendingValidacionToken!.isNotEmpty) {
        await prefs.setString(_prefsPendingTokenKey, pendingValidacionToken!);
      } else {
        await prefs.remove(_prefsPendingTokenKey);
      }
      if (pendingValidacionTargetId != null &&
          pendingValidacionTargetId!.isNotEmpty) {
        await prefs.setString(_prefsPendingTargetKey, pendingValidacionTargetId!);
      } else {
        await prefs.remove(_prefsPendingTargetKey);
      }
    } catch (e) {
      debugPrint('UserSession._persistPendingValidacion: $e');
    }
  }

  void setPendingValidacion(String token) {
    pendingValidacionToken = token;
    _persistPendingValidacion();
  }

  void setPendingValidacionTarget(String userId) {
    pendingValidacionTargetId = userId;
    _persistPendingValidacion();
  }

  void clearPendingValidacionTarget() {
    pendingValidacionTargetId = null;
    _persistPendingValidacion();
  }

  void clearPendingValidacion() {
    pendingValidacionToken = null;
    pendingValidacionTargetId = null;
    _persistPendingValidacion();
  }
}
