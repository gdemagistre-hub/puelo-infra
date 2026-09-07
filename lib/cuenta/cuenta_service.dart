import 'package:cloud_functions/cloud_functions.dart';
import 'package:flutter/foundation.dart' show debugPrint;

/// Callables us-east1: mensaje a dev@ y baja de cuenta (Etapa 1).
class CuentaService {
  CuentaService._();
  static final CuentaService instance = CuentaService._();

  static const String _region = 'us-east1';
  static const int maxMensaje = 800;

  FirebaseFunctions get _fn =>
      FirebaseFunctions.instanceFor(region: _region);

  Future<void> enviarMensajeDesarrollador(String mensaje) async {
    final t = mensaje.trim();
    if (t.isEmpty) {
      throw CuentaException('Escribí un mensaje.');
    }
    if (t.length > maxMensaje) {
      throw CuentaException(
        'El mensaje no puede superar $maxMensaje caracteres.',
      );
    }
    try {
      final callable = _fn.httpsCallable('enviarMensajeDesarrollador');
      await callable.call(<String, dynamic>{'mensaje': t});
    } on FirebaseFunctionsException catch (e) {
      debugPrint('CuentaService.enviarMensaje: ${e.code} ${e.message}');
      throw CuentaException(humanize(e));
    } catch (e) {
      debugPrint('CuentaService.enviarMensaje: $e');
      throw CuentaException('No se pudo enviar el mensaje. Probá más tarde.');
    }
  }

  Future<void> solicitarEliminacionCuenta() async {
    try {
      final callable = _fn.httpsCallable('solicitarEliminacionCuenta');
      await callable.call();
    } on FirebaseFunctionsException catch (e) {
      debugPrint('CuentaService.eliminar: ${e.code} ${e.message}');
      throw CuentaException(humanize(e));
    } catch (e) {
      debugPrint('CuentaService.eliminar: $e');
      throw CuentaException(
        'No se pudo eliminar la cuenta. Probá de nuevo.',
      );
    }
  }

  static String humanize(FirebaseFunctionsException e) {
    switch (e.code) {
      case 'unauthenticated':
        return 'Iniciá sesión para continuar.';
      case 'resource-exhausted':
        return 'Ya enviaste un mensaje hoy. Probá mañana.';
      case 'failed-precondition':
        return e.message?.isNotEmpty == true
            ? e.message!
            : 'Esta cuenta no se puede eliminar desde la app.';
      case 'invalid-argument':
        return e.message?.isNotEmpty == true
            ? e.message!
            : 'Revisá el texto e intentá de nuevo.';
      case 'unavailable':
        return 'No se pudo enviar el mensaje. Probá más tarde.';
      default:
        return e.message?.isNotEmpty == true
            ? e.message!
            : 'No se pudo completar la acción.';
    }
  }
}

class CuentaException implements Exception {
  final String message;
  CuentaException(this.message);
  @override
  String toString() => message;
}
