# Mensajes M1 — Recibos auditables

## Objetivo

Canal de **recibos de pago/anticipo** entre cliente y prestador, con doble control y registro append-only firmado (HMAC).

## Colecciones

- `conversaciones/{convId}` — `convId = uidA__uidB` (orden lexicográfico)
  - `participantes: [uid, uid]`
  - `pending_recibo_event_id` (si hay recibo sin respuesta)
  - `last_summary`, `last_event_at`
- `conversaciones/{convId}/eventos/{eventId}` — **solo create** (Admin SDK)
  - `recibo_emitido` — monto, concepto, content_hash, created_at_iso
  - `recibo_aceptado` / `recibo_rechazado` — apunta a `recibo_event_id`

## Cloud Functions (us-east1, onCall)

- `emitirRecibo({ contraparte_uid, monto, concepto, nota?, origen? })`
- `responderRecibo({ conversacion_id, recibo_event_id, decision, motivo? })`

Conceptos: `sena` | `anticipo` | `saldo` | `pago_total` | `otro`

## Integridad

`content_hash` = HMAC-SHA256 del payload canónico (secret `RECIBO_HMAC_SECRET` o fallback).
Los eventos de emisión **no se actualizan** al responder.

## Rules

Clientes: read si `request.auth.uid in participantes`. Write: denegado.

## Deploy

```bash
firebase use lifewalletpuelo
firebase deploy --only functions:emitirRecibo,functions:responderRecibo,firestore:rules
```

## Fuera de M1

UI, entry points desde tarjeta, texto libre, push.
