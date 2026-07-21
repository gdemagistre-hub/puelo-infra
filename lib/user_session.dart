class UserSession {
  static final UserSession _instance = UserSession._internal();
  factory UserSession() => _instance;
  UserSession._internal();

  String? uid;
  String? nombre;
  String? apellido;
  Map<String, dynamic>? datosCompletos;

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
  }

  String get nombreCompleto => '$nombre $apellido'.trim();
}
