# Compila el AAB prod. Corre desde la raiz del repo (puelo-infra).
# Requiere: Flutter en PATH, google-services.json en android/app/, key.properties (etapa 3).
$ErrorActionPreference = "Stop"
Set-Location (Split-Path $PSScriptRoot -Parent)

$json = "android\app\google-services.json"
if (-not (Test-Path $json)) {
  Write-Host "Falta $json — copia el archivo que bajaste de Firebase a esa ruta."
  exit 1
}

if (-not $env:FIREBASE_API_KEY_WEB -or -not $env:FIREBASE_API_KEY_ANDROID) {
  Write-Host "Definí FIREBASE_API_KEY_WEB y FIREBASE_API_KEY_ANDROID (las mismas que usa CI)."
  exit 1
}

flutter pub get
flutter build appbundle --release `
  --dart-define=PUELLO_ENV=prod `
  --dart-define=FIREBASE_API_KEY_WEB="$env:FIREBASE_API_KEY_WEB" `
  --dart-define=FIREBASE_API_KEY_ANDROID="$env:FIREBASE_API_KEY_ANDROID"

Write-Host "AAB: build\app\outputs\bundle\release\app-release.aab"
