# Mensajes — Recibos auditables + texto

## Objetivo

Canal de **recibos de pago/anticipo** entre cliente y prestador, con doble control y registro append-only firmado (HMAC). También mensajes de texto libres en el mismo hilo.

## Estado por etapas

| Etapa | Contenido | Estado |
|-------|-----------|--------|
| M1 | CF `emitirRecibo` / `responderRecibo` + rules | Hecho |
| M2 | UI lista + detalle + sheet | Hecho |
| M3 | Entry desde tarjeta digital | Hecho |
| M4 | Firma visible, copy inmutabilidad, errores, empty states | Hecho |
| M5 | Texto libre (`enviarMensajeTexto` + UI bubbles + composer) | Hecho |

## Colecciones

- `conversaciones/{convId}` — `convId = uidA__uidB` (orden lexicográfico)
- `conversaciones/{convId}/eventos/{eventId}` — **solo create** (Admin SDK)
  - `recibo_emitido` / `recibo_aceptado` / `recibo_rechazado`
  - `mensaje_texto` — texto (máx 500), content_hash, created_at_iso

## Cloud Functions (us-east1, onCall)

- `emitirRecibo`
- `responderRecibo`
- `enviarMensajeTexto({ conversacion_id, texto })`

## Deploy backend

```bash
firebase use lifewalletpuelo
firebase deploy --only functions:emitirRecibo,functions:responderRecibo,functions:enviarMensajeTexto,firestore:rules
```
