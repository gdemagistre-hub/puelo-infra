# Puelo Scoring Model v1.0

**Estado:** productivo en batch (`ScoringService.modelVersion = v1.0`)  
**ML/IA:** fuera de alcance (etapa microcrédito)  
**UI:** badge + confianza de perfil + estrellas/evals; **no** mostrar `score_credito_preview`

## Capas

| Campo | Visible | Significado |
|-------|---------|-------------|
| `scoring.score_identidad` (0–100) | Sí (confianza) | ¿Es quien dice ser? |
| `scoring.score_servicio` (0–100) | Sí (orden / calidad) | Qué tan bueno es como prestador |
| `scoring.score_cliente` (0–100) | Sí (sello cliente) | Confiabilidad como cliente |
| `scoring.score_credito_preview` | No | Preview interno futuro crédito |
| `badge_prestador` | Sí | Escalera de hitos |
| `score_credito` (plano) | No (compat) | Raw legado / compat batch |

## Identidad (techo raw 50 → 0–100)

Señales principales: auth (Google 3), email (2), celular (1), OCR doc (8), foto doc (3), foto perfil (3), ancla doc (×2 si OCR), domicilio, oficios, zona, hasta 5 fotos propias.

## Servicio

Base por evento: identidad 3 / trabajo sin foto 2 / con foto 3 / foto+comentario 4.  
Multiplicador evaluador: nuevo 0.25 · id≤receptor 0.50 · id>receptor 0.70 · +historial 1.00 · solo-identidad 0.15.  
Par completo: ×1.10.

## Badge

nuevo → registrado → bronce → bronce_plus (OCR) → plata (≥10 evals/validadores con historial).

## Ops

- Cálculo: `ScoringService.ejecutarBatchDiario()` (Home dev o scheduler).
- No recalcular en cada save de pantalla.
- `stats/scoring_job` guarda `model_version`.

## Changelog

- **v1.0** — Capas A/B/C + preview crédito; foto perfil y OCR explícitos; multiplicadores de evaluador.

## Batch

Ver [scoring_batch.md](./scoring_batch.md). Pipeline F0–F5 en `ScoringService.ejecutarBatchDiario` y Cloud Functions.
