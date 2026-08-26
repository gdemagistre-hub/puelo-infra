# Compila el AAB prod. Uso: powershell -File tools\build_aab.ps1
$ErrorActionPreference = "Stop"
Set-Location (Split-Path $PSScriptRoot -Parent)

function Fail([string]$m) {
  Write-Host $m
  exit 1
}

$flutter = Join-Path $env:USERPROFILE "flutter\bin\flutter.bat"
if (-not (Test-Path -LiteralPath $flutter)) {
  Fail "No encuentro flutter.bat en $flutter"
}
$flutterBin = Split-Path -Parent $flutter
$env:Path = "$flutterBin;" + $env:Path

$jbr = "C:\Program Files\Android\Android Studio\jbr"
if (Test-Path -LiteralPath $jbr) {
  $env:JAVA_HOME = $jbr
  $env:Path = "$jbr\bin;" + $env:Path
  Write-Host "JAVA_HOME=$jbr"
} else {
  Write-Host "WARN: no esta Android Studio JBR; Flutter puede usar un Java incompatible"
}

Write-Host "Usando Flutter: $flutter"

$json = "android\app\google-services.json"
$props = "android\key.properties"
$jks = "android\upload-keystore.jks"
if (-not (Test-Path -LiteralPath $json)) { Fail "Falta google-services.json" }
if (-not (Test-Path -LiteralPath $props)) { Fail "Falta key.properties (etapa 3)" }
if (-not (Test-Path -LiteralPath $jks)) { Fail "Falta upload-keystore.jks (etapa 3)" }

$gs = Get-Content -LiteralPath $json -Raw | ConvertFrom-Json
$androidKey = $env:FIREBASE_API_KEY_ANDROID
if (-not $androidKey) {
  $androidKey = $gs.client[0].api_key[0].current_key
}
if (-not $androidKey) { Fail "No hay API key Android" }
$webKey = $env:FIREBASE_API_KEY_WEB
if (-not $webKey) { $webKey = $androidKey }

Write-Host "Compilando AAB app.puelo (puede tardar varios minutos)..."
& $flutter pub get
if ($LASTEXITCODE -ne 0) { Fail "flutter pub get fallo" }
& $flutter build appbundle --release --dart-define=PUELLO_ENV=prod --dart-define=FIREBASE_API_KEY_WEB="$webKey" --dart-define=FIREBASE_API_KEY_ANDROID="$androidKey"
if ($LASTEXITCODE -ne 0) { Fail "flutter build appbundle fallo" }

$aab = "build\app\outputs\bundle\release\app-release.aab"
if (-not (Test-Path -LiteralPath $aab)) { Fail "No se genero el AAB" }
Get-Item -LiteralPath $aab | Format-List FullName, Length, LastWriteTime
Write-Host "OK. Ese archivo se sube a Play Console."
