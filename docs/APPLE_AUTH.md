# Sign in with Apple (Puelo)

## Estado app
- Código: Google + Apple + dropdown de prueba.
- Facebook / Twitter: no activos (botón FB muestra "aún no habilitado").

## Checklist Apple Developer (vos)
1. [developer.apple.com](https://developer.apple.com) → Account (programa pago).
2. **Certificates, Identifiers & Profiles**
   - **Identifiers → App IDs**: tu bundle iOS con capability **Sign In with Apple**.
   - **Identifiers → Services IDs** (para **web** / Hosting):
     - Crear Services ID (ej. `com.tuempresa.puelo.web`).
     - Enable **Sign In with Apple** → Configure:
       - Domains: dominio de Firebase Hosting y `PROJECT_ID.firebaseapp.com`
       - Return URLs: `https://PROJECT_ID.firebaseapp.com/__/auth/handler`
3. **Keys** → Create key con **Sign In with Apple** → descargar `.p8` (una sola vez).
   Anotar **Key ID** y **Team ID**.

## Checklist Firebase (vos)
1. Authentication → Sign-in method → **Apple** → Enable.
2. Completar:
   - Services ID (el de web)
   - Apple Team ID
   - Key ID
   - Private key (.p8 contenido)
3. Authorized domains: Hosting de Puelo + `PROJECT_ID.firebaseapp.com`.

## Prueba
1. Hard refresh del Hosting.
2. Login → Continuar con Apple (Safari / iOS ideal; en Chrome web a veces pide popup).
3. Pulldown de prueba sigue igual debajo.

## Notas
- Apple suele dar **nombre solo la primera vez**.
- Email puede ser relay `...@privaterelay.appleid.com`.
- Si falla, el mensaje de la app pide revisar Firebase + Apple Developer.
