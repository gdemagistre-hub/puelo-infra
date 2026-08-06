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
**Preferido (Sprint 0+):** custom claim en Auth:

```js
await admin.auth().setCustomUserClaims(uid, { admin: true });
```

Fallback (Firestore), documento `usuarios/{id}`:

```json
{ "es_admin": true }
```

Las rules **bloquean** que el cliente escriba `es_admin` (solo Admin SDK / claim).  
La opción **Consola Prox** aparece en Perfil si `es_admin` o `rol: admin`.

## Reglas Firestore (Sprint 0)
Archivo `firestore.rules`:

1. `analytics_events`: create con validación de keys; **read solo admin** (Auth).
2. `update/delete` de eventos: denegado.
3. `stats/*` y `validaciones*`: write/read client denegado (Functions).
4. Campos privilegiados de `usuarios` bloqueados en create/update client.
5. Menú “Modo prueba” sigue pudiendo **leer** usuarios y editar perfil no privilegiado sin Auth (TEMP).

Deploy:

```bash
firebase deploy --only firestore:rules
```

## Índice
Consola: índice simple en `analytics_events` por `client_ts` DESC.

## Costos
- Buffer de hasta 20 eventos / flush ~8s
- Rate limit ~40 eventos/min por cliente
- Consola lee máx. 400 eventos por refresh

## Próximo paso recomendado
Cloud Function nocturna que agregue a `stats/prox_diario` y la consola lea solo agregados admin.
