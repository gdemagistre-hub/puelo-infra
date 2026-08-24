import 'package:flutter/foundation.dart';

/// Entorno de la app. Costo cero: se resuelve en compile-time / debug.
///
/// Uso:
/// - `AppEnv.isProd` → ocultar tools sensibles en builds de release público
/// - `AppEnv.showDevTools` → siempre false (dropdown Modo prueba retirado 2026-08-24)
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
        return kReleaseMode ? PueloEnvironment.prod : PueloEnvironment.debug;
    }
  }

  static bool get isProd => current == PueloEnvironment.prod;
  static bool get isStaging => current == PueloEnvironment.staging;
  static bool get isDebug => current == PueloEnvironment.debug;

  /// Dropdown "Modo prueba" retirado. El flag SHOW_DEV_LOGIN ya no hace nada.
  static bool get showDevTools => false;

  static bool get hasDevLoginSecret => false;

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
