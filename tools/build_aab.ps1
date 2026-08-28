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

$jdk17 = Get-ChildItem "C:\Program Files\Microsoft" -Directory -ErrorAction SilentlyContinue |
  Where-Object { $_.Name -like "jdk-17*" } |
  Select-Object -First 1
if ($jdk17) {
  $env:JAVA_HOME = $jdk17.FullName
  $env:Path = "$($jdk17.FullName)\bin;" + $env:Path
  Write-Host "JAVA_HOME=$($jdk17.FullName)"
} else {
  Write-Host "WARN: no esta JDK 17 de Microsoft"
}

Write-Host "Usando Flutter: $flutter"

$json = "android\app\google-services.json"
$props = "android\key.properties"
$jks = "android\upload-keystore.jks"
$p12 = "android\upload-keystore.p12"
if (-not (Test-Path -LiteralPath $json)) { Fail "Falta google-services.json" }
if (-not (Test-Path -LiteralPath $props)) { Fail "Falta key.properties (etapa 3)" }
if (-not (Test-Path -LiteralPath $jks) -and -not (Test-Path -LiteralPath $p12)) {
  Fail "Falta upload-keystore.jks o upload-keystore.p12 (etapa 3)"
}

$gs = Get-Content -LiteralPath $json -Raw | ConvertFrom-Json
$pueloClient = @($gs.client) | Where-Object {
  $_.client_info.android_client_info.package_name -eq "app.puelo"
} | Select-Object -First 1
if (-not $pueloClient) {
  Fail "google-services.json no tiene client package app.puelo. Descarga el JSON desde Firebase app.puelo."
}

$androidKey = $env:FIREBASE_API_KEY_ANDROID
if (-not $androidKey) {
  $androidKey = $pueloClient.api_key[0].current_key
}
if (-not $androidKey) { Fail "No hay API key Android en el client app.puelo" }

$webKey = $env:FIREBASE_API_KEY_WEB
if (-not $webKey) { $webKey = $androidKey }

$webClientId = $env:GOOGLE_WEB_CLIENT_ID
if (-not $webClientId) {
  $webOauth = @($pueloClient.oauth_client) | Where-Object { [int]$_.client_type -eq 3 } | Select-Object -First 1
  if (-not $webOauth) {
    foreach ($c in @($gs.client)) {
      $webOauth = @($c.oauth_client) | Where-Object { [int]$_.client_type -eq 3 } | Select-Object -First 1
      if ($webOauth) { break }
    }
  }
  if ($webOauth) { $webClientId = $webOauth.client_id }
}
if (-not $webClientId) {
  Fail "Falta oauth_client tipo 3 (Web) en google-services.json. Descarga el JSON otra vez desde Firebase."
}

Write-Host "package=app.puelo"
Write-Host "appId=$($pueloClient.client_info.mobilesdk_app_id)"
Write-Host "androidKey=...$($androidKey.Substring($androidKey.Length-6))"
Write-Host "webClientId=$webClientId"

Write-Host "Compilando AAB app.puelo (puede tardar varios minutos)..."
& $flutter pub get
if ($LASTEXITCODE -ne 0) { Fail "flutter pub get fallo" }
$gp = "android\gradle.properties"
$raw = Get-Content -LiteralPath $gp -Raw
$raw = $raw -replace "android.newDsl\s*=\s*true","android.newDsl=false"
if ($raw -notmatch "android.newDsl=false") { $raw = $raw.TrimEnd() + "`r`nandroid.newDsl=false`r`n" }
Set-Content -LiteralPath $gp -Value $raw -NoNewline
& $flutter build appbundle --release --dart-define=PUELLO_ENV=prod --dart-define=FIREBASE_API_KEY_WEB="$webKey" --dart-define=FIREBASE_API_KEY_ANDROID="$androidKey" --dart-define=GOOGLE_WEB_CLIENT_ID="$webClientId"
if ($LASTEXITCODE -ne 0) { Fail "flutter build appbundle fallo" }

$aab = "build\app\outputs\bundle\release\app-release.aab"
if (-not (Test-Path -LiteralPath $aab)) { Fail "No se genero el AAB" }
Get-Item -LiteralPath $aab | Format-List FullName, Length, LastWriteTime
Write-Host "OK. Ese archivo se sube a Play Console (versionCode 9)."
