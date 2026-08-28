# Sign in with Apple — checklist owner

Código en `lib/auth_service.dart` + botón en `lib/loginScreen.dart`.
Firebase Auth 5.x: popup en web, `signInWithProvider` en Android/iOS.
**No commitear** la key `.p8` ni el Team ID en el repo.

Hoy el repo tiene `android/` (package `app.puelo`) y `web/`. **No hay carpeta `ios/` todavía.**
Apple nativo (App Store) requiere crear el módulo iOS en una etapa siguiente.
Web + Android funcionan con Services ID + Key en Firebase.

## 1. Apple Developer (ya tenés el usuario autorizado)

1. Identifiers → **App IDs** → New
   - Description: `Puelo`
   - Bundle ID explícito: `app.puelo` (mismo que Android / Play)
   - Capability: **Sign In with Apple**
2. Identifiers → **Services IDs** → New
   - Description: `Puelo Sign in with Apple`
   - Identifier sugerido: `app.puelo.signin`
   - Configure → Enable Sign In with Apple
   - Primary App ID: el App ID `app.puelo`
   - Domains:
     - `lifewalletpuelo.firebaseapp.com`
     - `lifewalletpuelo.web.app`
     - `puelo.app` (si Auth también corre ahí)
   - Return URLs:
     - `https://lifewalletpuelo.firebaseapp.com/__/auth/handler`
     - `https://lifewalletpuelo.web.app/__/auth/handler`
3. Keys → **Create a key**
   - Enable **Sign In with Apple**
   - Associate al App ID `app.puelo`
   - Descargar el `.p8` **una sola vez**. Guardarlo fuera del repo.
   - Anotar **Key ID** (10 chars) y **Team ID** (Membership).

## 2. Firebase Console (proyecto `lifewalletpuelo`)

Authentication → Sign-in method → **Apple** → Enable

Campos (obligatorios para web/Android):

- Services ID = `app.puelo.signin` (el identifier del paso 1.2)
- Apple Team ID
- Key ID
- Private Key = contenido del `.p8`

Guardar. Sin esto el botón en prod falla con `operation-not-allowed` o `invalid-credential`.

## 3. Probar

1. Deploy Hosting (push a `main` dispara CI).
2. Abrir `https://lifewalletpuelo.web.app/login` en Safari o Chrome.
3. Continuar con Apple → popup de Apple → vuelve a Puelo → Home o Elige camino.
4. Firestore `usuarios/{uid}`: `auth_provider: apple`, email (real o `privaterelay.appleid.com`).
5. En Android (Play interno): mismo botón; abre Custom Tab de Apple.

## 4. Después: módulo iOS (App Store)

Cuando se agregue `ios/` al repo:

- Bundle ID `app.puelo`
- Xcode → Signing & Capabilities → **Sign in with Apple**
- `GoogleService-Info.plist` de la app iOS de Firebase
- App Store Connect: app nueva + capability Sign in with Apple

Apple exige Sign in with Apple si hay otros social login (Google). Por eso el botón ya está en login.

## Notas

- Apple manda nombre **solo la primera vez**. El código lo guarda en Firestore.
- Hide My Email es válido. No exigir otro mail.
- Si el mismo mail ya existe con Google/password: Firebase tira `account-exists-with-different-credential`. Entrar con el método original.
- Facebook sigue oculto en beta (`showFacebookLogin = false`).
