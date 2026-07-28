import 'catalogo_geo_cache.dart';
import 'analytics/prox_analytics.dart';

class UserSession {
  static final UserSession _instance = UserSession._internal();
  factory UserSession() => _instance;
  UserSession._internal();

  String? uid;
  String? nombre;
  String? apellido;
  Map<String, dynamic>? datosCompletos;

  /// Token de una validación de domicilio pendiente
  String? pendingValidacionToken;

  void iniciarSesion(String id, Map<String, dynamic> data) {
    uid = id;
    nombre = data['nombre'] ?? '';
    apellido = data['apellido'] ?? '';
    datosCompletos = data;
  }

  /// Admin de consola Prox (campo en Firestore usuarios/{id}).
  bool get isAdmin {
    final d = datosCompletos;
    if (d == null) return false;
    return d['es_admin'] == true || d['rol'] == 'admin';
  }

  void cerrarSesion() {
    // Cierra sesión de analytics sin PII
    try {
      ProxAnalytics.instance.endSession(reason: 'logout');
    } catch (_) {}
    uid = null;
    nombre = null;
    apellido = null;
    datosCompletos = null;
    pendingValidacionToken = null;
    CatalogoGeoCache.instance.clear();
  }

  String get nombreCompleto => '$nombre $apellido'.trim();

  void setPendingValidacion(String token) {
    pendingValidacionToken = token;
  }

  void clearPendingValidacion() {
    pendingValidacionToken = null;
  }
}
