# Consola Prox — seguridad y operación

## Qué mide
- `screen_view` / `screen_exit` (dwell)
- `screen_timing` (load_ms)
- `session_start` / `session_end` (última pantalla)
- `action` (ej. whatsapp_tap, login)
- `error` (código + mensaje sanitizado)

## Qué NO se guarda
Nombre, apellido, email, teléfono, documento, calle, tokens, passwords.

## Cómo habilitar un admin
En Firestore, documento `usuarios/{id}`:

```json
{ "es_admin": true }
```

O `rol: "admin"`. La opción **Consola Prox** aparece en Perfil solo para esos usuarios.

## Reglas Firestore
Archivo `firestore.rules` en el repo:

1. `analytics_events`: create con validación de keys; **read solo admin** (con Auth).
2. `update/delete` de eventos: denegado.
3. Hoy el catch-all temporal permite read/write amplio por el MVP sin Auth.

**Antes de tráfico real:**
1. Activar Firebase Auth.
2. Quitar el `match /{document=**}` abierto.
3. `allow create` de analytics solo si `request.auth != null`.
4. Preferir **custom claim** `admin: true` en el token.

Deploy de reglas:

```bash
firebase deploy --only firestore:rules
```

## Índice
Para la consola: índice simple en `analytics_events` por `client_ts` DESC.

## Costos
- Buffer de hasta 20 eventos / flush ~8s
- Rate limit ~40 eventos/min por cliente
- Consola lee máx. 400 eventos por refresh

## Próximo paso recomendado
Cloud Function nocturna que agregue a `stats/prox_diario` (vistas, p95, drop-off) y la consola lea solo agregados admin.
