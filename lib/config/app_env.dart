import 'package:flutter/foundation.dart';

/// Entorno de la app. Costo cero: se resuelve en compile-time / debug.
///
/// Uso:
/// - `AppEnv.isProd` → ocultar tools sensibles en builds de release público
/// - `AppEnv.showDevTools` → dropdown "Modo prueba" (oculto TEMP 2026-08-22)
/// - `AppEnv.devLoginSecret` → mintDevSession (solo builds de equipo)
///
/// Staging web:
///   flutter build web --dart-define=PUELLO_ENV=staging --dart-define=DEV_LOGIN_SECRET=...
enum PueloEnvironment { debug, staging, prod }

class AppEnv {
  AppEnv._();

  static const String _envFromDefine = String.fromEnvironment(
    'PUELLO_ENV',
    defaultValue: '',
  );

  /// Secreto de equipo para mintDevSession. Vacío en builds públicos.
  static const String devLoginSecret = String.fromEnvironment(
    'DEV_LOGIN_SECRET',
    defaultValue: '',
  );

  static PueloEnvironment get current {
    switch (_envFromDefine.toLowerCase()) {
      case 'prod':
      case 'production':
        return PueloEnvironment.prod;
      case 'staging':
      case 'stage':
        return PueloEnvironment.staging;
      case 'debug':
        return PueloEnvironment.debug;
      default:
        // Sin dart-define: debug en desarrollo, prod en release.
        return kReleaseMode ? PueloEnvironment.prod : PueloEnvironment.debug;
    }
  }

  static bool get isProd => current == PueloEnvironment.prod;
  static bool get isStaging => current == PueloEnvironment.staging;
  static bool get isDebug => current == PueloEnvironment.debug;

  /// Menú "Modo prueba (equipo)" — dropdown de usuarios sin clave.
  ///
  /// TEMP 2026-08-22: oculto por decisión del owner (smoke test con Auth real).
  /// Para reactivar en un build local/staging:
  ///   --dart-define=SHOW_DEV_LOGIN=1
  static bool get showDevTools {
    const show = String.fromEnvironment('SHOW_DEV_LOGIN', defaultValue: '');
    if (show == '1' || show.toLowerCase() == 'true') return true;
    return false;
  }

  static bool get hasDevLoginSecret => devLoginSecret.isNotEmpty;

  /// Logs verbosos en consola
  static bool get verboseLogging => isDebug || isStaging;

  static String get label {
    switch (current) {
      case PueloEnvironment.debug:
        return 'debug';
      case PueloEnvironment.staging:
        return 'staging';
      case PueloEnvironment.prod:
        return 'prod';
    }
  }
}
