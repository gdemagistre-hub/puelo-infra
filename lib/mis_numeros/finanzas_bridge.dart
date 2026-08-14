import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';

/// Mis números usa la **misma** DB que PROX (lifewalletpuelo).
/// Este helper queda como alias al Firebase default (ya no hay proyecto puelo-finanzas).
class FinanzasBridge {
  FinanzasBridge._();

  static bool ready = true;
  static String? lastError;

  static FirebaseAuth get finanzasAuth => FirebaseAuth.instance;

  static FirebaseFirestore get finanzasDb => FirebaseFirestore.instance;

  static FirebaseAuth get walletAuth => FirebaseAuth.instance;

  /// No-op: un solo proyecto.
  static Future<void> ensureInit() async {
    ready = true;
    debugPrint('FinanzasBridge: DB única lifewalletpuelo');
  }

  /// Exige sesión Google real (mismo Auth que PROX).
  static Future<User> linkSession() async {
    lastError = null;
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      throw StateError(
        'Sin sesión Firebase Auth. Entrá con Google (no con el dropdown de prueba).',
      );
    }
    return user;
  }

  static Future<void> signOutFinanzas() async {
    // No cerramos Auth global desde acá (lo hace el logout de perfil).
  }
}
