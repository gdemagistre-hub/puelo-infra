# Sprint 0 — Seguridad (menú “Modo prueba” se mantiene)

**Fecha:** 2026-08-06  
**Backup pre-cambio:** tag `backup/pre-sprint0-*` + `/workspace/backups/`

## Política

- **Menú TEMP del login se conserva** para el equipo.
- Lectura de `usuarios` abierta (dropdown + buscador).
- **Campos privilegiados bloqueados** en client writes: `es_admin`, `scoring`, badges, fraude.
- `stats/*` y `validaciones*` solo Admin SDK (Functions).
- Storage: write solo con Auth bajo `usuarios/{uid}/…`.
- Batch HTTP: **BATCH_SECRET obligatorio** (fail-closed).
- `mintDevSession`: custom token si `DEV_LOGIN_SECRET` está configurado.
- `aplicarValidacionPendiente`: prefiere Bearer; fallback `validadorId` si `ALLOW_DEV_VALIDACION=1` (default).

## Deploy checklist

```bash
# 1) Rules + indexes
firebase deploy --only firestore:rules,firestore:indexes --project lifewalletpuelo

# 2) Storage (requiere API habilitada + permisos SA)
firebase deploy --only storage --project lifewalletpuelo
# o: gsutil cors set cors.json gs://lifewalletpuelo.firebasestorage.app

# 3) Functions
firebase deploy --only functions --project lifewalletpuelo

# 4) Secrets (recomendado en consola / CLI)
# firebase functions:secrets:set BATCH_SECRET
# firebase functions:secrets:set DEV_LOGIN_SECRET
# Luego re-deploy functions con secrets bindeados si se usan.

# 5) Hosting (app)
flutter build web --release
# Equipo con mint:
# flutter build web --release \
#   --dart-define=PUELLO_ENV=staging \
#   --dart-define=DEV_LOGIN_SECRET=...secreto...
firebase deploy --only hosting --project lifewalletpuelo
```

## GitHub Actions

- Push a `main` con cambios en `firestore.rules` → `deploy-firestore-indexes.yml`
- Push a `main` en `functions/**` → `deploy-functions.yml`
- Push a `main` (resto) → `firebase-deploy.yml` (Hosting)

## Cómo ocultar el menú en un build público

```bash
flutter build web --release --dart-define=HIDE_DEV_LOGIN=1
```

## Go-live (siguiente sprint)

1. `ALLOW_DEV_VALIDACION=0` en Functions  
2. Auth obligatorio en writes de `usuarios` / `trabajos` / `contactos`  
3. Custom claim `admin` (quitar confianza en `es_admin` del doc)  
4. EmailJS al backend  
5. App Check  

## Rollback

```bash
git checkout backup/pre-sprint0-YYYYMMDDTHHMMSSZ
# o
git checkout backup/pre-sprint0-YYYYMMDDTHHMMSSZ-df00470
```

## Estado de deploy (2026-08-06)

| Pipeline | Resultado |
|----------|-----------|
| Hosting | **OK** |
| Storage rules | **OK** |
| Firestore rules (CLI) | Falló: SA sin `serviceusage.services.get` |
| Firestore rules (REST) | Ruleset **creado** (`86c8f723-…`); release falló por payload/permisos SA |
| Cloud Functions | Falló: SA sin `iam.serviceAccounts.ActAs` sobre `lifewalletpuelo@appspot.gserviceaccount.com` |

### Acción manual (Owner GCP)

1. Dar al SA de GitHub el rol **Service Account User** sobre `lifewalletpuelo@appspot.gserviceaccount.com`.
2. Roles útiles: Firebase Rules Admin / Cloud Datastore Index Admin / Service Usage Consumer.
3. Re-ejecutar workflows: Deploy Functions + Deploy Firestore rules (REST).
4. Configurar en Functions: `BATCH_SECRET`, `DEV_LOGIN_SECRET`.

