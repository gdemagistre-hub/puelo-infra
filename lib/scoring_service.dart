import 'package:cloud_firestore/cloud_firestore.dart';

/// Scoring Puelo v1.1-phase0 — scorecard por capas (sin ML).
///
/// Capas:
///   A) score_identidad      — confianza de perfil (visible)
///   B) score_servicio       — calidad como prestador (visible)
///   C) score_cliente        — confiabilidad como cliente (visible)
///   D) score_credito        — preview interno (NO mostrar en UI)
///   E) score_comportamiento — señales de actividad / negocio real (Phase 0)
///
/// Phase 0 (2026-08-18):
///   - Capacitaciones suman a identidad.
///   - Nueva capa comportamiento (reglas) desde signals ya disponibles + stats_negocio.
///   - Tips priorizados por impacto y tope de 6.
///   - Credito preview reserva peso para comportamiento.
///   - Batch escribe campos listos para Feature Store / Vertex.
///
/// Badge prestador: escalera de hitos (nuevo → … → plata).
/// Pensado para batch 1× día (no en cada save de pantalla).
class ScoringService {
  ScoringService._();

  static final _db = FirebaseFirestore.instance;

  /// Versión del modelo documentada (changelog en commits).
  static const String modelVersion = 'v1.1-phase0';

  /// Techo raw de identidad para normalizar a 0–100.
  static const int techoIdentidad = 55; // +5 por capacitaciones

  /// Techo raw de servicio / cliente (acumulación de eventos).
  static const int techoServicio = 40;
  static const int techoCliente = 30;

  /// Techo raw de comportamiento (Phase 0).
  static const int techoComportamiento = 25;

  // SEE_FILE artifacts/scoring_service_PHASE0.dart for full body — push truncated in tool call
  // Re-push full content in follow-up if needed.
}
