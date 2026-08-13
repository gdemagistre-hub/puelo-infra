import 'dart:convert';
import 'dart:math';
import 'dart:typed_data';

import 'package:cryptography/cryptography.dart';
import 'package:flutter/foundation.dart';

/// Cifrado de Mis números.
/// v1: clave = PIN derivado.
/// v2: clave de datos (DEK) aleatoria; PIN solo envuelve la DEK.
class VaultCrypto {
  VaultCrypto._();

  static const int pinLength = 6;
  static const int pbkdf2Iterations = 120000;
  static const String checkPlain = 'puelo-finanzas-vault-v1';

  static final _pbkdf2 = Pbkdf2(
    macAlgorithm: Hmac.sha256(),
    iterations: pbkdf2Iterations,
    bits: 256,
  );
  static final _aes = AesGcm.with256bits();

  static Uint8List newSalt([int length = 16]) {
    final rnd = Random.secure();
    return Uint8List.fromList(List.generate(length, (_) => rnd.nextInt(256)));
  }

  static Future<SecretKey> newDek() async {
    return SecretKey(newSalt(32));
  }

  static Future<List<int>> keyBytes(SecretKey key) => key.extractBytes();

  static SecretKey keyFromBytes(List<int> bytes) => SecretKey(bytes);

  static Future<SecretKey> deriveKey(String pin, List<int> salt) {
    return _pbkdf2.deriveKey(
      secretKey: SecretKey(utf8.encode(pin)),
      nonce: salt,
    );
  }

  static Future<String> encryptString(String plain, SecretKey key) async {
    final clear = utf8.encode(plain);
    final box = await _aes.encrypt(clear, secretKey: key);
    final nonce = box.nonce;
    final mac = box.mac.bytes;
    final cipher = box.cipherText;
    final out = BytesBuilder();
    out.addByte(1);
    out.addByte(nonce.length);
    out.add(nonce);
    out.addByte(mac.length);
    out.add(mac);
    out.add(cipher);
    return base64Encode(out.toBytes());
  }

  static Future<String> decryptString(String packedB64, SecretKey key) async {
    final raw = base64Decode(packedB64);
    if (raw.isEmpty || raw[0] != 1) {
      throw StateError('Formato de cifrado desconocido');
    }
    var i = 1;
    final nLen = raw[i++];
    final nonce = raw.sublist(i, i + nLen);
    i += nLen;
    final mLen = raw[i++];
    final mac = raw.sublist(i, i + mLen);
    i += mLen;
    final cipher = raw.sublist(i);
    final clear = await _aes.decrypt(
      SecretBox(cipher, nonce: nonce, mac: Mac(mac)),
      secretKey: key,
    );
    return utf8.decode(clear);
  }

  /// Envuelve bytes de DEK con la clave del PIN → base64.
  static Future<String> wrapDek(List<int> dekBytes, SecretKey pinKey) {
    return encryptString(base64Encode(dekBytes), pinKey);
  }

  static Future<List<int>> unwrapDek(String packed, SecretKey pinKey) async {
    final b64 = await decryptString(packed, pinKey);
    return base64Decode(b64);
  }

  static Future<String> makePinCheck(SecretKey key) =>
      encryptString(checkPlain, key);

  static Future<bool> verifyPinCheck(String packed, SecretKey key) async {
    try {
      final s = await decryptString(packed, key);
      return s == checkPlain;
    } catch (e) {
      debugPrint('verifyPinCheck fail: $e');
      return false;
    }
  }

  static bool isValidPin(String pin) =>
      RegExp(r'^[0-9]{6}$').hasMatch(pin);
}
