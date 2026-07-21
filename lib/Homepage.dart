import 'user_session.dart';

// Dentro de tu método build...
Text(
  'Bienvenido ${UserSession().nombreCompleto}',
  style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
),
