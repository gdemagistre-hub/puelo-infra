import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';

/// Registro de token FCM para push (fiados vencidos, recibos, etc.).
///
/// El token vive en usuarios/{uid}/privado/push (no en el padre público).
class FcmService {
  FcmService._();
  static final FcmService instance = FcmService._();

  bool _started = false;

  Future<void> ensureStarted() async {
    if (_started) return;
    _started = true;
    try {
      final messaging = FirebaseMessaging.instance;
      final settings = await messaging.requestPermission(
        alert: true,
        badge: true,
        sound: true,
      );
      if (settings.authorizationStatus == AuthorizationStatus.denied) {
        debugPrint('FCM: permiso denegado');
        return;
      }

      String? token;
      try {
        token = await messaging.getToken();
      } catch (e) {
        debugPrint('FCM getToken: $e');
        return;
      }
      if (token == null || token.isEmpty) return;

      await _saveToken(token);
      messaging.onTokenRefresh.listen(_saveToken);
    } catch (e) {
      debugPrint('FcmService.ensureStarted: $e');
    }
  }

  Future<void> _saveToken(String token) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;
    try {
      final parent = FirebaseFirestore.instance.collection('usuarios').doc(user.uid);
      final push = parent.collection('privado').doc('push');
      await push.set({
        'fcm_token': token,
        'fcm_tokens': FieldValue.arrayUnion([token]),
        'fcm_updated_at': FieldValue.serverTimestamp(),
        'fcm_platform': kIsWeb ? 'web' : 'mobile',
      }, SetOptions(merge: true));
      await parent.set({
        'fcm_token': FieldValue.delete(),
        'fcm_tokens': FieldValue.delete(),
        'fcm_updated_at': FieldValue.delete(),
        'fcm_platform': FieldValue.delete(),
      }, SetOptions(merge: true));
      debugPrint('FCM token guardado en privado/push');
    } catch (e) {
      debugPrint('FCM saveToken: $e');
    }
  }
}
