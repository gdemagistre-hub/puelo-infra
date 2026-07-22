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

  void cerrarSesion() {
    uid = null;
    nombre = null;
    apellido = null;
    datosCompletos = null;
    pendingValidacionToken = null;
  }

  String get nombreCompleto => '$nombre $apellido'.trim();

  void setPendingValidacion(String token) {
    pendingValidacionToken = token;
  }

  void clearPendingValidacion() {
    pendingValidacionToken = null;
  }
}
