# S5 — Multi-proyecto Firebase (esqueleto)

Prod no se toca. `lifewalletpuelo` sigue recibiendo el deploy automático de `main`.

| Alias | projectId | Deploy |
|---|---|---|
| prod | lifewalletpuelo | push a `main` (workflows actuales) |
| desa | puelo-desa | Actions → Deploy Desa (manual) |
| test | puelo-test | aún sin workflow |

## Secrets GH

- `FIREBASE_SERVICE_ACCOUNT_PUELO_DESA`
- `FIREBASE_SERVICE_ACCOUNT_PUELO_TEST`
- `FIREBASE_API_KEY_WEB_DESA`
- `FIREBASE_API_KEY_WEB_TEST`

Prod: `FIREBASE_SERVICE_ACCOUNT_LIFEWALLETPUELO` + `FIREBASE_API_KEY_WEB`.

## Primera corrida desa

1. GitHub → Actions → **Deploy Desa (manual)** → Run workflow.
2. URL: https://puelo-desa.web.app
3. Functions a desa: todavía no (S5.2).

Rollback aliases: `git checkout resguardo/2026-08-31-pre-s5 -- .firebaserc`
