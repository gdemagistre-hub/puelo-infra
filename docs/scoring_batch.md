# Batch de scoring — operación

## Pipeline (F0–F5)

1. **F0 Lock** — evita corridas solapadas (`stats/scoring_job.lock`, TTL 15 min)
2. **F1 Publicar** — calificaciones `pendiente_*` con >7 días → `publicada` (`publica_por_timeout`)
3. **F2 Indexar** — `trabajos` + `calificaciones` publicadas
4. **F3 Cache** — identidad de evaluadores (multiplicadores)
5. **F4 Score** — escribe `scoring{}`, `badge_prestador`, compat `score_credito`
6. **F5 Stats** — `stats/scoring_job` + `stats/scoring_job/runs/{runId}`

## Cómo disparar

| Modo | Cómo |
|------|------|
| Dev (app) | Home → “Correr batch scoring (dev)” (si `AppEnv.showDevTools`) |
| HTTP | `POST https://southamerica-east1-<PROJECT>.cloudfunctions.net/scoringBatchHttp` header `X-Batch-Secret` |
| Cron | Function `scoringBatchDaily` 02:30 ART |

## Qué tenés que hacer vos (una vez)

Ver checklist en el mensaje del agente / abajo en “Deploy functions”.

## Estados de calificación

| estado | Entra al score |
|--------|----------------|
| *(vacío / legacy)* | Sí |
| `publicada` | Sí |
| `pendiente_respuesta_prestador` | No (hasta timeout o par) |
| `anulada` | No |

Al crear una eval de cliente→prestador, setear:
`estado: pendiente_respuesta_prestador`, `created_at`, `prestador_id`, `cliente_id`, `estrellas`, `comentario`.
