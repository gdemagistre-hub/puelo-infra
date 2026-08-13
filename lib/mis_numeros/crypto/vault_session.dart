import 'dart:convert';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cryptography/cryptography.dart';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../finanzas_bridge.dart';
import 'vault_crypto.dart';

/// Sesion de cifrado en memoria (se borra al logout / lock).
/// Usa Firestore de la app secundaria Finanzas.
class VaultSession extends ChangeNotifier {
  VaultSession._();
  static final VaultSession instance = VaultSession._();

  SecretKey? _key;
  String? _uid;
  bool unlocked = false;
  bool hasVault = false;
  String? lastError;

  bool get isUnlocked => unlocked && _key != null;
  SecretKey? get key => _key;
  String? get uid => _uid;

  DocumentReference<Map<String, dynamic>> _metaRef(String uid) =>
      FinanzasBridge.finanzasDb
          .collection('usuarios')
          .doc(uid)
          .collection('vault')
          .doc('meta');

  Future<void> bindUser(String? uid) async {
    if (uid == null) {
      lock();
      _uid = null;
      hasVault = false;
      return;
    }
    if (_uid != uid) {
      lock();
      _uid = uid;
    }
    await refreshHasVault();
  }

  Future<void> refreshHasVault() async {
    final uid = _uid;
    if (uid == null) {
      hasVault = false;
      return;
    }
    try {
      final snap = await _metaRef(uid).get();
      hasVault = snap.exists &&
          (snap.data()?['pinCheck'] is String) &&
          (snap.data()?['salt'] is String);
    } catch (e) {
      debugPrint('refreshHasVault: $e');
      final prefs = await SharedPreferences.getInstance();
      hasVault = prefs.getString('vault_meta_$uid') != null;
    }
    notifyListeners();
  }

  Future<void> setupPin(String pin) async {
    final uid = _uid;
    if (uid == null) throw StateError('Sin usuario');
    if (!VaultCrypto.isValidPin(pin)) {
      throw ArgumentError('El PIN debe ser 6 digitos');
    }
    final salt = VaultCrypto.newSalt();
    final key = await VaultCrypto.deriveKey(pin, salt);
    final pinCheck = await VaultCrypto.makePinCheck(key);
    final saltB64 = base64Encode(salt);
    final meta = {
      'v': 1,
      'salt': saltB64,
      'pinCheck': pinCheck,
      'kdf': 'pbkdf2-sha256',
      'iterations': VaultCrypto.pbkdf2Iterations,
      'createdAt': FieldValue.serverTimestamp(),
      'note':
          'Cifrado por usuario. El PIN no se almacena. Sin PIN no hay recuperacion de montos.',
    };
    await _metaRef(uid).set(meta, SetOptions(merge: true));
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
      'vault_meta_$uid',
      jsonEncode({'salt': saltB64, 'pinCheck': pinCheck}),
    );
    _key = key;
    unlocked = true;
    hasVault = true;
    lastError = null;
    notifyListeners();
  }

  Future<bool> unlock(String pin) async {
    final uid = _uid;
    if (uid == null) return false;
    if (!VaultCrypto.isValidPin(pin)) {
      lastError = 'PIN de 6 digitos';
      notifyListeners();
      return false;
    }
    String? saltB64;
    String? pinCheck;
    try {
      final snap = await _metaRef(uid).get();
      final d = snap.data();
      saltB64 = d?['salt'] as String?;
      pinCheck = d?['pinCheck'] as String?;
    } catch (_) {}
    if (saltB64 == null || pinCheck == null) {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString('vault_meta_$uid');
      if (raw != null) {
        final m = jsonDecode(raw) as Map<String, dynamic>;
        saltB64 = m['salt'] as String?;
        pinCheck = m['pinCheck'] as String?;
      }
    }
    if (saltB64 == null || pinCheck == null) {
      lastError = 'No hay boveda. Configura el PIN.';
      notifyListeners();
      return false;
    }
    final salt = base64Decode(saltB64);
    final key = await VaultCrypto.deriveKey(pin, salt);
    final ok = await VaultCrypto.verifyPinCheck(pinCheck, key);
    if (!ok) {
      lastError = 'PIN incorrecto';
      notifyListeners();
      return false;
    }
    _key = key;
    unlocked = true;
    lastError = null;
    notifyListeners();
    return true;
  }

  void lock() {
    _key = null;
    unlocked = false;
    lastError = null;
    notifyListeners();
  }

  Future<String?> encrypt(String plain) async {
    final k = _key;
    if (k == null) return null;
    return VaultCrypto.encryptString(plain, k);
  }

  Future<String?> decrypt(String packed) async {
    final k = _key;
    if (k == null) return null;
    return VaultCrypto.decryptString(packed, k);
  }

  Future<Map<String, dynamic>> sealMap(
    Map<String, dynamic> clear, {
    required List<String> sensitiveKeys,
  }) async {
    final out = Map<String, dynamic>.from(clear);
    out['enc'] = true;
    out['enc_v'] = 1;
    for (final k in sensitiveKeys) {
      final v = out[k];
      if (v == null) continue;
      final s = v is num ? v.toString() : v.toString();
      out[k] = await encrypt(s);
    }
    return out;
  }

  Future<Map<String, dynamic>> openMap(
    Map<String, dynamic> sealed, {
    required List<String> sensitiveKeys,
    required Set<String> numericKeys,
  }) async {
    if (sealed['enc'] != true) {
      return Map<String, dynamic>.from(sealed);
    }
    final out = Map<String, dynamic>.from(sealed);
    for (final k in sensitiveKeys) {
      final v = out[k];
      if (v is! String) continue;
      final plain = await decrypt(v);
      if (plain == null) continue;
      if (numericKeys.contains(k)) {
        if (plain.isEmpty || plain == 'null') {
          out[k] = null;
        } else {
          out[k] = double.tryParse(plain) ?? 0;
        }
      } else {
        out[k] = plain;
      }
    }
    out.remove('enc');
    out.remove('enc_v');
    return out;
  }
}
