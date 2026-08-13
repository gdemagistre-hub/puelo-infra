import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart'
    show defaultTargetPlatform, kIsWeb, TargetPlatform;

/// Firebase options — proyecto de datos financieros (`puelo-finanzas`).
/// En PROX es la app secundaria (nombre: [FinanzasBridge.appName]).
class FinanzasFirebaseOptions {
  static FirebaseOptions get currentPlatform {
    if (kIsWeb) return web;
    switch (defaultTargetPlatform) {
      case TargetPlatform.android:
        return android;
      default:
        return web;
    }
  }

  static const FirebaseOptions web = FirebaseOptions(
    apiKey: 'AIzaSyD4kFAaVpqQaZzSccQczzJsEyPuo6U-KS4',
    appId: '1:930477248932:web:aff08d202e7f5fee433131',
    messagingSenderId: '930477248932',
    projectId: 'puelo-finanzas',
    authDomain: 'puelo-finanzas.firebaseapp.com',
    storageBucket: 'puelo-finanzas.firebasestorage.app',
  );

  static const FirebaseOptions android = FirebaseOptions(
    apiKey: 'AIzaSyCqQq9lVK9D1Am7-uJ7QLE-gGKGjlBTl3I',
    appId: '1:930477248932:android:e57901247bcece12433131',
    messagingSenderId: '930477248932',
    projectId: 'puelo-finanzas',
    storageBucket: 'puelo-finanzas.firebasestorage.app',
  );
}
