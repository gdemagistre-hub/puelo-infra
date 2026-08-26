# Compila el AAB prod. Desde la raiz:  powershell -File tools\build_aab.ps1
$ErrorActionPreference = "Stop"
Set-Location (Split-Path $PSScriptRoot -Parent)

function Fail($m) { Write-Host $m; exit 1 }

$json = "android\app\google-services.json"
$props = "android\key.properties"
$jks = "android\upload-keystore.jks"
if (-not (Test-Path $json)) { Fail "Falta $json" }
if (-not (Test-Path $props)) { Fail "Falta $props — etapa 3" }
if (-not (Test-Path $jks)) { Fail "Falta $jks — etapa 3" }
if (-not (Get-Command flutter -ErrorAction SilentlyContinue)) { Fail "Flutter no esta en PATH" }

$gs = Get-Content $json -Raw | ConvertFrom-Json
$androidKey = $env:FIREBASE_API_KEY_ANDROID
if (-not $androidKey) {
  $androidKey = $gs.client[0].api_key[0].current_key
}
if (-not $androidKey) { Fail "No hay FIREBASE_API_KEY_ANDROID ni current_key en el JSON" }
$webKey = $env:FIREBASE_API_KEY_WEB
if (-not $webKey) { $webKey = $androidKey }

Write-Host "applicationId app.puelo — compilando AAB (puede tardar varios minutos)..."
flutter pub get
flutter build appbundle --release `
  --dart-define=PUELLO_ENV=prod `
  --dart-define=FIREBASE_API_KEY_WEB="$webKey" `
  --dart-define=FIREBASE_API_KEY_ANDROID="$androidKey"

$aab = "build\app\outputs\bundle\release\app-release.aab"
if (-not (Test-Path $aab)) { Fail "No se genero $aab" }
Get-Item $aab | Format-List FullName, Length, LastWriteTime
Write-Host "OK. Subi ese AAB a Play Console (Internal testing o Production)."
