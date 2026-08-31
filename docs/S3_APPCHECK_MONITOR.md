# S3 — App Check en modo monitor

**No enforce.** Los requests sin token siguen pasando. Solo medimos cobertura.

## Código (ya en main)

- `lib/config/app_check_bootstrap.dart` se llama después de `Firebase.initializeApp`.
- Web: activa solo si existe `--dart-define=APPCHECK_RECAPTCHA_SITE_KEY=...`.
- Android release: Play Integrity. Debug: `AndroidProvider.debug`.
- Si activate falla, la app **sigue** (fail-open).

## Qué tenés que hacer vos (consola)

### 1. reCAPTCHA v3 (web)

1. https://www.google.com/recaptcha/admin → Create (reCAPTCHA v3).
2. Dominios:
   - `lifewalletpuelo.web.app`
   - `lifewalletpuelo.firebaseapp.com`
   - `puelo.app`
   - `www.puelo.app`
   - `localhost`
3. Copiá el **site key** (público) y el **secret**.
4. Firebase Console → App Check → app Web → reCAPTCHA v3 → pegá el **secret**.
5. GitHub repo → Settings → Secrets → Actions → secret `APPCHECK_RECAPTCHA_SITE_KEY` = site key.
6. Re-deploy Hosting (push vacío o *Run workflow*) para inyectar la key.

### 2. Play Integrity (Android `app.puelo`)

1. Firebase Console → App Check → app Android `app.puelo` → Play Integrity.
2. Dejá **enforcement OFF** (Monitor).
3. Debug APK: en Logcat buscá `DebugAppCheckProvider` / `App Check debug token` y registralo en App Check → Apps → Manage debug tokens.

### 3. Enforcement — NO tocar todavía

En App Check → APIs:

- Cloud Firestore → Unenforced
- Cloud Functions → Unenforced
- Cloud Storage → Unenforced
- Authentication → Unenforced

Cuando el panel muestre >90 % requests válidos por 7 días, evaluamos enforce (etapa posterior).

## QA rápido

1. Hard refresh web → login Google → Home → buscador → Doy un pago.
2. Si no hay site key aún: en consola del browser no debe haber crash; puede figurar el log `sin APPCHECK_RECAPTCHA_SITE_KEY`.
3. Tras cargar el secret y redeploy: Firebase Console → App Check debe empezar a mostrar requests de la app Web.

## Rollback

```powershell
git checkout resguardo/2026-08-31-pre-s3 -- lib/main.dart lib/config/app_check_bootstrap.dart pubspec.yaml .github/workflows/firebase-deploy.yml
git rm -f lib/config/app_check_bootstrap.dart docs/S3_APPCHECK_MONITOR.md
git add -A
git commit -m "revert(s3): App Check monitor"
git push origin main
```
