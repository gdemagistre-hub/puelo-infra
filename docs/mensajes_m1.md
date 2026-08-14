# Mensajes — Recibos auditables

## Objetivo

Canal de **recibos de pago/anticipo** entre cliente y prestador, con doble control y registro append-only firmado (HMAC).

## Estado por etapas

| Etapa | Contenido | Estado |
|-------|-----------|--------|
| M1 | CF `emitirRecibo` / `responderRecibo` + rules | Hecho |
| M2 | UI lista + detalle + sheet | Hecho |
| M3 | Entry desde tarjeta digital | Hecho |
| M4 | Firma visible, copy inmutabilidad, errores, empty states | Hecho |
| M5 | Texto libre / chat (opcional) | Pendiente |

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

Copy UX: “Registro sellado · no editable” + firma corta copiable.

## Rules

Clientes: read si `request.auth.uid in participantes`. Write: denegado.

## UI entry points

1. Tab **Mensajes** (lista de hilos)
2. **Tarjeta digital** de otra persona → botón Emitir recibo
3. Detalle de hilo → icono / empty CTA

## Deploy backend

```bash
firebase use lifewalletpuelo
firebase deploy --only functions:emitirRecibo,functions:responderRecibo,firestore:rules
```
