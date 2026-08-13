import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';

import 'finanzas_options.dart';

/// Bridge dual-Firebase dentro de PROX:
/// - App default = lifewalletpuelo (Auth identidad + datos PROX)
/// - App `finanzas` = puelo-finanzas (Firestore cifrada de números)
///
/// exchangeWalletToken (CF en puelo-finanzas) intercambia idToken Wallet →
/// custom token Finanzas con el mismo uid.
class FinanzasBridge {
  FinanzasBridge._();

  static const String appName = 'finanzas';
  static const String exchangeFunctionName = 'exchangeWalletToken';

  static FirebaseApp? _finanzasApp;
  static bool ready = false;
  static String? lastError;

  static FirebaseApp get finanzasApp {
    final a = _finanzasApp;
    if (a == null) {
      throw StateError('Finanzas Firebase app no inicializada');
    }
    return a;
  }

  static FirebaseAuth get finanzasAuth =>
      FirebaseAuth.instanceFor(app: finanzasApp);

  static FirebaseFirestore get finanzasDb =>
      FirebaseFirestore.instanceFor(app: finanzasApp);

  static FirebaseAuth get walletAuth => FirebaseAuth.instance;

  /// Inicializa la app secundaria (idempotente).
  static Future<void> ensureInit() async {
    if (_finanzasApp != null) {
      ready = true;
      return;
    }
    try {
      _finanzasApp = await Firebase.initializeApp(
        name: appName,
        options: FinanzasFirebaseOptions.currentPlatform,
      );
    } on FirebaseException catch (e) {
      if (e.code == 'duplicate-app') {
        _finanzasApp = Firebase.app(appName);
      } else {
        lastError = e.toString();
        rethrow;
      }
    }
    ready = true;
    debugPrint(
      'FinanzasBridge OK project=${finanzasApp.options.projectId}',
    );
  }

  /// Wallet idToken → custom token Finanzas (mismo uid).
  /// Requiere sesión real de Firebase Auth (no dropdown dev).
  static Future<User> linkSession() async {
    lastError = null;
    await ensureInit();

    final walletUser = walletAuth.currentUser;
    if (walletUser == null) {
      throw StateError(
        'Sin sesión Firebase Auth. Entrá con Google (no con el dropdown de prueba).',
      );
    }

    final existing = finanzasAuth.currentUser;
    if (existing != null && existing.uid == walletUser.uid) {
      return existing;
    }

    final idToken = await walletUser.getIdToken(true);
    if (idToken == null || idToken.isEmpty) {
      throw StateError('No se pudo obtener idToken de Wallet');
    }

    try {
      final functions = FirebaseFunctions.instanceFor(
        app: finanzasApp,
        region: 'us-central1',
      );
      final callable = functions.httpsCallable(exchangeFunctionName);
      final result = await callable.call(<String, dynamic>{
        'idToken': idToken,
      });
      final data = Map<String, dynamic>.from(result.data as Map);
      final token = data['token'] as String?;
      if (token == null || token.isEmpty) {
        throw StateError('Bridge sin token');
      }
      final cred = await finanzasAuth.signInWithCustomToken(token);
      final user = cred.user;
      if (user == null) throw StateError('Custom token sin user');
      debugPrint('FinanzasBridge link OK uid=${user.uid}');
      return user;
    } catch (e, st) {
      lastError = e.toString();
      debugPrint('FinanzasBridge link falló: $e\n$st');
      rethrow;
    }
  }

  static Future<void> signOutFinanzas() async {
    try {
      if (_finanzasApp != null) {
        await finanzasAuth.signOut();
      }
    } catch (_) {}
  }
}
