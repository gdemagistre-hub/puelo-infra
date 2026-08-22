import 'package:cloud_firestore/cloud_firestore.dart';

/// Denormaliza conteos no sensibles en usuarios/{uid}.stats_negocio.
/// No escribe montos (privacidad / vault).
class StatsNegocioWriter {
  StatsNegocioWriter._();

  static final _db = FirebaseFirestore.instance;

  static Future<void> write({
    required String uid,
    int? nMovimientos,
    int? nCobros,
    int? nFiadosCobrados,
    int? nFiadosPendientes,
    bool? tieneFondoEmergencia,
  }) async {
    if (uid.isEmpty) return;
    final payload = <String, dynamic>{
      'stats_negocio.actualizado_en': FieldValue.serverTimestamp(),
    };
    if (nMovimientos != null) {
      payload['stats_negocio.n_movimientos'] = nMovimientos;
    }
    if (nCobros != null) {
      payload['stats_negocio.n_cobros'] = nCobros;
    }
    if (nFiadosCobrados != null) {
      payload['stats_negocio.n_fiados_cobrados'] = nFiadosCobrados;
    }
    if (nFiadosPendientes != null) {
      payload['stats_negocio.n_fiados_pendientes'] = nFiadosPendientes;
    }
    if (tieneFondoEmergencia != null) {
      payload['stats_negocio.tiene_fondo_emergencia'] = tieneFondoEmergencia;
    }
    try {
      await _db.collection('usuarios').doc(uid).update(payload);
    } catch (e) {
      // Best-effort: no romper Mis Números si rules/sesión fallan.
      // ignore: avoid_print
      print('StatsNegocioWriter.write: $e');
    }
  }
}
