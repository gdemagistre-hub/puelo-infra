# Sprint 0 — closeout

**Region:** `us-east1` (cost)
**Secrets:** `BATCH_SECRET`, `DEV_LOGIN_SECRET` bound in Functions
**Backup:** `backup/pre-sprint0-20260806T152754Z-df00470`

## Production (manual, owner)

1. Functions already deployed to us-east1
2. Re-deploy functions after this commit to bind secrets:
   ```bash
   firebase deploy --only functions --project lifewalletpuelo
   ```
3. Hosting with new URLs:
   ```bash
   flutter build web --release
   firebase deploy --only hosting --project lifewalletpuelo
   ```
4. Listsync completar/datos:
   ```bash
   git apply scripts/patches/sprint5_completar_datos.patch
   ```

## Menú Modo prueba

Se mantiene (`HIDE_DEV_LOGIN` no seteado).
