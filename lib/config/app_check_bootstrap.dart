import 'package:firebase_app_check/firebase_app_check.dart';
import 'package:flutter/foundation.dart';

/// S3 — App Check en modo monitor.
///
/// Activa el SDK para que Firebase reciba tokens y métricas.
/// NO enforce: si falta la site key o el provider falla, la app sigue.
/// Enforce (bloquear requests sin token) es una etapa posterior + consola.
///
/// API firebase_app_check 0.3.x: `webProvider` / `androidProvider`.
class AppCheckBootstrap {
  AppCheckBootstrap._();

  static const String recaptchaSiteKey = String.fromEnvironment(
    'APPCHECK_RECAPTCHA_SITE_KEY',
  );

  static Future<void> activate() async {
    try {
      if (kIsWeb) {
        if (recaptchaSiteKey.isEmpty) {
          debugPrint(
            'App Check monitor: sin APPCHECK_RECAPTCHA_SITE_KEY — skip web',
          );
          return;
        }
        await FirebaseAppCheck.instance.activate(
          webProvider: ReCaptchaV3Provider(recaptchaSiteKey),
        );
      } else {
        await FirebaseAppCheck.instance.activate(
          androidProvider:
              kDebugMode ? AndroidProvider.debug : AndroidProvider.playIntegrity,
        );
      }
      await FirebaseAppCheck.instance.setTokenAutoRefreshEnabled(true);
      debugPrint('App Check monitor: activate OK');
    } catch (e) {
      debugPrint('App Check monitor: activate falló (app sigue): $e');
    }
  }
}
