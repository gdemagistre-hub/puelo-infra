# Sprint 1 — Cuota, cache y lecturas

**Fecha:** 2026-08-06  
**Backup pre-Sprint 0 (intacto):** `backup/pre-sprint0-20260806T152754Z-df00470` @ `75610a0c…`

## Objetivo
Bajar lecturas de Firestore y fugas de recursos sin romper el menú Modo prueba.

## Cambios

| Área | Cambio |
|------|--------|
| **Tarjeta digital** | `_fotosFuture` memoizado en `initState` (no re-query en cada rebuild) |
| **Home prestador** | `homeCacheIfFresh` / `setHomeCache` (TTL 45s); invalidación al editar perfil |
| **Buscador** | Query con `list_visible` / `zona_ids` / `categorias_servicio` (una arrayContains); soft-rank por zona del cliente; banner “cerca de…” |
| **Capacitaciones** | `dispose` de controllers del modal (try/finally) |
| **Completar perfil** | `mounted` antes de `setState` post-async |
| **Auth Google** | Mensaje claro en desktop nativo |
| **OCR DNI** | `isSupported` solo Android/iOS |

## Deploy
Hosting vía push a `main` (workflow `Deploy to Firebase Hosting`).

## No tocar
- Tag/branch de backup pre-Sprint 0
- Menú “Modo prueba (equipo)” del login
