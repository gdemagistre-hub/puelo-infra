# Compila el AAB prod. Uso: powershell -File tools\build_aab.ps1
$ErrorActionPreference = "Stop"
Set-Location (Split-Path $PSScriptRoot -Parent)

function Fail([string]$m) {
  Write-Host $m
  exit 1
}

$flutterCandidates = @(
  (Get-Command flutter -ErrorAction SilentlyContinue | Select-Object -ExpandProperty Source),
  "$env:USERPROFILE\flutter\bin\flutter.bat",
  "$env:USERPROFILE\dev\flutter\bin\flutter.bat",
  "$env:LOCALAPPDATA\flutter\bin\flutter.bat",
  "C:\flutter\bin\flutter.bat",
  "C:\src\flutter\bin\flutter.bat"
) | Where-Object { $_ -and (Test-Path $_) }

if (-not $flutterCandidates) { Fail "No encuentro flutter.bat" }
$flutter = $flutterCandidates[0]
$flutterBin = Split-Path $flutter -Parent
if ($env:Path -notlike ("*" + $flutterBin + "*")) {
  $env:Path = $flutterBin + ";" + $env:Path
}
Write-Host ("Usando Flutter: " + $flutter)

$json = "android\app\google-services.json"
$props = "android\key.properties"
$jks = "android\upload-keystore.jks"
if (-not (Test-Path $json)) { Fail "Falta google-services.json" }
if (-not (Test-Path $props)) { Fail "Falta key.properties (etapa 3)" }
if (-not (Test-Path $jks)) { Fail "Falta upload-keystore.jks (etapa 3)" }

$gs = Get-Content $json -Raw | ConvertFrom-Json
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
if (-not (Test-Path $aab)) { Fail "No se genero el AAB" }
Get-Item $aab | Format-List FullName, Length, LastWriteTime
Write-Host "OK. Ese archivo se sube a Play Console."
