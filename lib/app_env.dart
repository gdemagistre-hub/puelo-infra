import 'package:flutter/foundation.dart';

/// Entorno de la app. Costo cero: se resuelve en compile-time / debug.
///
/// Uso:
/// - `AppEnv.isProd` → ocultar dropdown dev, botones admin, logs sensibles
/// - `AppEnv.showDevTools` → solo debug o staging explícito
///
/// Para staging en web podés compilar con:
///   flutter build web --dart-define=PUELLO_ENV=staging
enum PueloEnvironment { debug, staging, prod }

class AppEnv {
  AppEnv._();

  static const String _envFromDefine = String.fromEnvironment(
    'PUELLO_ENV',
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

  /// Herramientas de desarrollo (dropdown usuarios, batch scoring, etc.)
  static bool get showDevTools => !isProd;

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
