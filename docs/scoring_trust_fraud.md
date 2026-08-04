# Confianza, evaluaciones y fraude

## Confianza de perfil vs trayectoria
- **Confianza** = identidad/completitud (`scoring.score_identidad`), con techos por antigüedad.
- **Trayectoria** = evaluaciones de clientes publicadas (no es lo mismo).

## Techos anti-gaming
| Edad cuenta | Techo identidad |
|-------------|-----------------|
| < 7 días | 40 |
| < 30 días | 70 |
| ≥ 30 días | 100 |
| riesgo_fraude alto/medio | 25 / 50 |

Señales fuertes (OCR, fotos) maduran 3 días al 50%.

## Evaluaciones a prestadores
1. Cliente califica → `calificaciones.estado = pendiente_respuesta_prestador` (NO suma al promedio público).
2. Se publica si:
   - prestador acepta (`aceptado_por_prestador: true`) o completa el par, **o**
   - pasan **7 días** (batch F1).
3. Tras publicar, batch recalcula `promedioEstrellas` / `cantidadEvaluadores`.

## Validaciones de identidad (quién es)
- Sin que nadie te haya validado: **máx 1** emisión.
- Luego: **1 cada 7 días** mientras el ritmo anti-fraude aplique.
- Implementado en `ScoringService.canEmitirValidacion` + pantalla de gracias.

## Detección de fraude (batch F1.5)
Heurísticas (no LLM): anillo mutual, ráfaga cuenta nueva, solo-validador, volumen alto, mismo día de alta.
Escribe `riesgo_fraude` en usuarios + `stats/fraud_flags`.
Correr: Actions → **Run scoring batch**.

## Crédito futuro: Gini, KS y ROC

Ver [scoring_model_v1.md](./scoring_model_v1.md) § *Métricas de discriminación (etapa microcrédito)*.

- **Hoy (confianza / fraude heurístico):** no se publican Gini/KS/AUC como métricas de producto.
- **Etapa microcrédito:** validación del modelo de PD (y opcionalmente fraude con label) con **AUC, Gini y KS** out-of-time.
- Los scores de identidad/servicio alimentan elegibilidad y features; no sustituyen el model validation crediticio.

