# Performance y concurrencia (Puelo)

## Hecho en código
- Campos de listado desnormalizados (`list_*`, `categorias_servicio`, `zona_ids`)
- Índices compuestos (`firestore.indexes.json`)
- Buscador: query por categoría en servidor + fallback cliente
- Cache de sesión Home (TTL ~45s)
- Skeletons en buscador / home prestador
- Imágenes de perfil y portfolio más livianas
- Cache-Control en Hosting para assets
- Storage rules: max 5MB image/*
- Backfill: Actions → **Backfill list fields**
- Seed oficios: Actions → **Seed catálogo oficios**

## Pendiente manual (consola / producto)
1. Deploy de índices (CI o `firebase deploy --only firestore:indexes`) y esperar a que queden **Enabled**
2. Deploy storage rules si no van en el pipeline de Hosting
3. Cerrar TEMP writes en `firestore.rules` al apagar el dropdown
4. App Check + monitoreo de lecturas en Firebase console
5. Load test opcional (50–200 sesiones)

## Cómo verificar
- `stats/list_fields_backfill` → usuarios_actualizados
- Buscador por categoría sin error de índice
- Home prestador no re-fetchea al volver en <45s
