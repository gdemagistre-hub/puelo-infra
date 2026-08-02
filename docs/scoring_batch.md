# Batch de scoring — operación (cloud)

## Cómo ejecutarlo **sin consola local** (recomendado)

### GitHub Actions (1 clic)

1. Abrí el repo: https://github.com/gdemagistre-hub/puelo-infra  
2. Pestaña **Actions**  
3. Workflow **“Run scoring batch”** (columna izquierda)  
4. Botón **Run workflow** → branch `main`  
5. Opcional: marcar **force** si la corrida anterior quedó trabada  
6. **Run workflow**  
7. Esperá el job verde  
8. En Firebase → Firestore → `stats/scoring_job` y `stats/scoring_job/runs/...`

El job usa el secret ya existente `FIREBASE_SERVICE_ACCOUNT_LIFEWALLETPUELO` (el mismo del deploy de Hosting).

### Cloud Shell (navegador Google, si preferís terminal en la nube)

1. https://console.cloud.google.com → proyecto `lifewalletpuelo`  
2. Ícono **Cloud Shell** (arriba a la derecha)  
3. ```bash
   git clone https://github.com/gdemagistre-hub/puelo-infra.git
   cd puelo-infra/functions && npm install
   # autenticación: Cloud Shell ya está en el proyecto
   gcloud auth application-default login   # solo la 1ª vez
   node run_once.js
   ```

## Pipeline (F0–F5)

1. Lock → 2. Publicar evals >7d → 3. Indexar → 4. Cache identidad → 5. Score → 6. Stats/runs  

## Cloud Functions (opcional, cron 02:30 ART)

Workflow **Deploy Cloud Functions** (Actions) o:

```bash
firebase deploy --only functions --project lifewalletpuelo
```

Requiere plan Blaze. Tras deploy: `scoringBatchDaily` + HTTP `scoringBatchHttp`.

## App (solo debug/staging)

Home → “Correr batch scoring (dev)” — no aparece en prod release.
