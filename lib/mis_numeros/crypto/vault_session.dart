import 'dart:convert';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:cryptography/cryptography.dart';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'vault_crypto.dart';

/// Sesión de cifrado — DB única lifewalletpuelo.
/// v2: DEK + PIN + recuperación vía CF (Google).
class VaultSession extends ChangeNotifier {
  VaultSession._();
  static final VaultSession instance = VaultSession._();

  /// Región de las CF de PROX (puelo-infra).
  static const String functionsRegion = 'us-east1';

  SecretKey? _key;
  String? _uid;
  int vaultVersion = 1;
  bool unlocked = false;
  bool hasVault = false;
  bool hasRecovery = false;
  String? lastError;

  bool get isUnlocked => unlocked && _key != null;
  SecretKey? get key => _key;
  String? get uid => _uid;

  FirebaseFirestore get _db => FirebaseFirestore.instance;

  DocumentReference<Map<String, dynamic>> _metaRef(String uid) =>
      _db.collection('usuarios').doc(uid).collection('vault').doc('meta');

  Future<void> bindUser(String? uid) async {
    if (uid == null) {
      lock();
      _uid = null;
      hasVault = false;
      hasRecovery = false;
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
      hasRecovery = false;
      return;
    }
    try {
      final snap = await _metaRef(uid).get();
      final d = snap.data();
      hasVault = snap.exists &&
          (d?['pinCheck'] is String) &&
          (d?['salt'] is String);
      hasRecovery = d?['dek_wrapped_recovery'] is String;
      vaultVersion = (d?['v'] is num) ? (d!['v'] as num).toInt() : 1;
    } catch (e) {
      debugPrint('refreshHasVault: $e');
      final prefs = await SharedPreferences.getInstance();
      hasVault = prefs.getString('vault_meta_$uid') != null;
      hasRecovery = false;
    }
    notifyListeners();
  }

  Future<void> setupPin(String pin) async {
    final uid = _uid;
    if (uid == null) throw StateError('Sin usuario');
    if (!VaultCrypto.isValidPin(pin)) {
      throw ArgumentError('El PIN debe ser 6 dígitos');
    }

    final salt = VaultCrypto.newSalt();
    final pinKey = await VaultCrypto.deriveKey(pin, salt);
    final pinCheck = await VaultCrypto.makePinCheck(pinKey);
    final dek = await VaultCrypto.newDek();
    final dekBytes = await VaultCrypto.keyBytes(dek);
    final dekWrappedPin = await VaultCrypto.wrapDek(dekBytes, pinKey);
    final saltB64 = base64Encode(salt);

    final meta = {
      'v': 2,
      'salt': saltB64,
      'pinCheck': pinCheck,
      'dek_wrapped_pin': dekWrappedPin,
      'kdf': 'pbkdf2-sha256',
      'iterations': VaultCrypto.pbkdf2Iterations,
      'createdAt': FieldValue.serverTimestamp(),
      'note':
          'Tu PIN bloquea Mis números en el celular. Si lo olvidás, entrás de nuevo con Google y elegís uno nuevo.',
    };
    await _metaRef(uid).set(meta, SetOptions(merge: true));

    try {
      await _registerRecovery(base64Encode(dekBytes));
      hasRecovery = true;
    } catch (e) {
      debugPrint('registerVaultRecovery: $e');
      hasRecovery = false;
    }

    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
      'vault_meta_$uid',
      jsonEncode({'salt': saltB64, 'pinCheck': pinCheck, 'v': 2}),
    );

    _key = dek;
    vaultVersion = 2;
    unlocked = true;
    hasVault = true;
    lastError = null;
    notifyListeners();
  }

  Future<void> _registerRecovery(String dekBase64) async {
    final functions = FirebaseFunctions.instanceFor(region: functionsRegion);
    await functions.httpsCallable('registerVaultRecovery').call({
      'dekBase64': dekBase64,
    });
  }

  Future<bool> unlock(String pin) async {
    final uid = _uid;
    if (uid == null) return false;
    if (!VaultCrypto.isValidPin(pin)) {
      lastError = 'PIN de 6 dígitos';
      notifyListeners();
      return false;
    }

    Map<String, dynamic>? d;
    try {
      final snap = await _metaRef(uid).get();
      d = snap.data();
    } catch (_) {}

    String? saltB64 = d?['salt'] as String?;
    String? pinCheck = d?['pinCheck'] as String?;
    final version = (d?['v'] is num) ? (d!['v'] as num).toInt() : 1;
    final dekWrappedPin = d?['dek_wrapped_pin'] as String?;
    hasRecovery = d?['dek_wrapped_recovery'] is String;

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
      lastError = 'No hay bóveda. Configurá el PIN.';
      notifyListeners();
      return false;
    }

    final salt = base64Decode(saltB64);
    final pinKey = await VaultCrypto.deriveKey(pin, salt);
    final ok = await VaultCrypto.verifyPinCheck(pinCheck, pinKey);
    if (!ok) {
      lastError = 'PIN incorrecto';
      notifyListeners();
      return false;
    }

    if (version >= 2 && dekWrappedPin != null) {
      try {
        final dekBytes = await VaultCrypto.unwrapDek(dekWrappedPin, pinKey);
        _key = VaultCrypto.keyFromBytes(dekBytes);
        vaultVersion = 2;
        try {
          await _registerRecovery(base64Encode(dekBytes));
          hasRecovery = true;
        } catch (e) {
          debugPrint('registerVaultRecovery (unlock): $e');
        }
      } catch (e) {
        lastError = 'No se pudo abrir la bóveda';
        notifyListeners();
        return false;
      }
    } else {
      _key = pinKey;
      vaultVersion = 1;
    }

    unlocked = true;
    lastError = null;
    notifyListeners();
    return true;
  }

  Future<void> resetPinWithRecovery(String newPin) async {
    final uid = _uid;
    if (uid == null) throw StateError('Sin usuario');
    if (!VaultCrypto.isValidPin(newPin)) {
      throw ArgumentError('El PIN debe ser 6 dígitos');
    }

    final functions = FirebaseFunctions.instanceFor(region: functionsRegion);
    final result = await functions.httpsCallable('recoverVaultDek').call();
    final data = Map<String, dynamic>.from(result.data as Map);
    final dekBase64 = data['dekBase64'] as String?;
    if (dekBase64 == null || dekBase64.isEmpty) {
      throw StateError('Recuperación sin DEK');
    }
    final dekBytes = base64Decode(dekBase64);
    final dek = VaultCrypto.keyFromBytes(dekBytes);

    final salt = VaultCrypto.newSalt();
    final pinKey = await VaultCrypto.deriveKey(newPin, salt);
    final pinCheck = await VaultCrypto.makePinCheck(pinKey);
    final dekWrappedPin = await VaultCrypto.wrapDek(dekBytes, pinKey);
    final saltB64 = base64Encode(salt);

    await _metaRef(uid).set({
      'v': 2,
      'salt': saltB64,
      'pinCheck': pinCheck,
      'dek_wrapped_pin': dekWrappedPin,
      'kdf': 'pbkdf2-sha256',
      'iterations': VaultCrypto.pbkdf2Iterations,
      'pinResetAt': FieldValue.serverTimestamp(),
      'note':
          'Tu PIN bloquea Mis números en el celular. Si lo olvidás, entrás de nuevo con Google y elegís uno nuevo.',
    }, SetOptions(merge: true));

    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
      'vault_meta_$uid',
      jsonEncode({'salt': saltB64, 'pinCheck': pinCheck, 'v': 2}),
    );

    _key = dek;
    vaultVersion = 2;
    unlocked = true;
    hasVault = true;
    hasRecovery = true;
    lastError = null;
    notifyListeners();
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
    out['enc_v'] = vaultVersion >= 2 ? 2 : 1;
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
