# iOS / Codemagic — primera versión PROX

Bundle ID: `app.puelo`
App Store Connect Apple ID: `6808655489`
SKU: `prox-ios`

## Variables en Codemagic (Secure)

- `FIREBASE_API_KEY_IOS` ← `API_KEY` del `GoogleService-Info.plist`
- `FIREBASE_APP_ID_IOS` ← `GOOGLE_APP_ID` (`1:74624927314:ios:…`)
- `GOOGLESERVICE_INFO_PLIST` ← contenido entero del plist (opcional pero útil)

No commitear el `.p8` ni el plist.

## Build arguments (workflow editor)

```
--dart-define=FIREBASE_API_KEY_IOS=$FIREBASE_API_KEY_IOS --dart-define=FIREBASE_APP_ID_IOS=$FIREBASE_APP_ID_IOS
```

## Pre-build script

```
bash tools/codemagic_prebuild_ios.sh
```
