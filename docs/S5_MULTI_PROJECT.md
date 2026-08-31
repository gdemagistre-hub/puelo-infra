# S5 — Multi-proyecto Firebase

Prod no se toca. `lifewalletpuelo` sigue con el deploy automático de `main`.

| Alias | projectId | Hosting | Functions |
|---|---|---|---|
| prod | lifewalletpuelo | push `main` | push `functions/**` |
| desa | puelo-desa | Deploy Desa (manual) | Deploy Functions Desa (manual) |
| test | puelo-test | Deploy Test (manual) | aún no |

URLs: https://lifewalletpuelo.web.app · https://puelo-desa.web.app · https://puelo-test.web.app

## Secret Manager en desa (antes de Functions)

Valores **nuevos**, no copies prod.

```bash
echo -n "desa-hmac-$(openssl rand -hex 16)" | gcloud secrets create RECIBO_HMAC_SECRET --data-file=- --project=puelo-desa
echo -n "desa-vault-$(openssl rand -hex 16)" | gcloud secrets create VAULT_RECOVERY_SECRET --data-file=- --project=puelo-desa
```

Si ya existen: `gcloud secrets versions add ...`

Grant al compute SA no hace falta si el rol Firebase Admin ya cubre el bind en deploy.

## Test

En `puelo-test`: Firestore + Storage Get started + dominio Auth `puelo-test.web.app`.
