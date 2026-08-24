import 'package:flutter/foundation.dart';

/// Entorno de la app. Costo cero: se resuelve en compile-time / debug.
///
/// Uso:
/// - `AppEnv.isProd` → ocultar tools sensibles en builds de release público
/// - `AppEnv.showDevTools` → dropdown "Modo prueba" (oculto TEMP 2026-08-22)
///
/// Staging web:
///   flutter build web --dart-define=PUELLO_ENV=staging
enum PueloEnvironment { debug, staging, prod }

class AppEnv {
  AppEnv._();

  static const String _envFromDefine = String.fromEnvironment(
    'PUELLO_ENV',
    defaultValue: '',
  );

  /// mintDevSession ya no existe. El getter queda en false para no romper calls.
  static const String devLoginSecret = '';

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

  /// Menú "Modo prueba (equipo)" — dropdown de usuarios sin Auth.
  ///
  /// TEMP 2026-08-22: oculto por decisión del owner (smoke test con Auth real).
  /// Para reactivar en un build local/staging:
  ///   --dart-define=SHOW_DEV_LOGIN=1
  static bool get showDevTools {
    const show = String.fromEnvironment('SHOW_DEV_LOGIN', defaultValue: '');
    if (show == '1' || show.toLowerCase() == 'true') return true;
    return false;
  }

  static bool get hasDevLoginSecret => false;

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
