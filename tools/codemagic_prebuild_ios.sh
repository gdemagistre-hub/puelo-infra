#!/usr/bin/env bash
# Pre-build Codemagic: crea ios/ si falta, fija bundle app.puelo, plist + permisos.
set -euo pipefail

IOS_MIN='15.5'

flutter config --no-enable-swift-package-manager

if [ ! -d ios ]; then
  flutter create --platforms=ios --org app --project-name life_wallet_puelo .
fi

if [ -f ios/Runner.xcodeproj/project.pbxproj ]; then
  sed -i '' 's/PRODUCT_BUNDLE_IDENTIFIER = [^;]*/PRODUCT_BUNDLE_IDENTIFIER = app.puelo/g' \
    ios/Runner.xcodeproj/project.pbxproj || true
  sed -i '' "s/IPHONEOS_DEPLOYMENT_TARGET = [0-9.]*/IPHONEOS_DEPLOYMENT_TARGET = ${IOS_MIN}/g" \
    ios/Runner.xcodeproj/project.pbxproj || true
fi

if [ -n "${GOOGLESERVICE_INFO_PLIST:-}" ]; then
  printf '%s\n' "$GOOGLESERVICE_INFO_PLIST" > ios/Runner/GoogleService-Info.plist
fi

PLIST=ios/Runner/Info.plist
if [ -f "$PLIST" ]; then
  /usr/libexec/PlistBuddy -c "Add :CFBundleDisplayName string PROX" "$PLIST" 2>/dev/null || true
  /usr/libexec/PlistBuddy -c "Set :CFBundleDisplayName PROX" "$PLIST" 2>/dev/null || true
  /usr/libexec/PlistBuddy -c "Add :MinimumOSVersion string ${IOS_MIN}" "$PLIST" 2>/dev/null || \
    /usr/libexec/PlistBuddy -c "Set :MinimumOSVersion ${IOS_MIN}" "$PLIST" || true
  /usr/libexec/PlistBuddy -c "Add :ITSAppUsesNonExemptEncryption bool false" "$PLIST" 2>/dev/null || \
    /usr/libexec/PlistBuddy -c "Set :ITSAppUsesNonExemptEncryption false" "$PLIST" || true
  /usr/libexec/PlistBuddy -c "Add :NSCameraUsageDescription string PROX usa la cámara para tu foto de perfil y para leer el documento." "$PLIST" 2>/dev/null || true
  /usr/libexec/PlistBuddy -c "Add :NSPhotoLibraryUsageDescription string PROX accede a tus fotos para el perfil y los trabajos realizados." "$PLIST" 2>/dev/null || true
  /usr/libexec/PlistBuddy -c "Add :NSPhotoLibraryAddUsageDescription string PROX guarda imágenes en tu galería solo si vos lo pedís." "$PLIST" 2>/dev/null || true
fi

if [ -f ios/Podfile ]; then
  if grep -q "platform :ios" ios/Podfile; then
    sed -i '' "s/^# *platform :ios.*/platform :ios, '${IOS_MIN}'/" ios/Podfile
    sed -i '' "s/^platform :ios.*/platform :ios, '${IOS_MIN}'/" ios/Podfile
  else
    printf '%s\n%s\n' "platform :ios, '${IOS_MIN}'" "$(cat ios/Podfile)" > ios/Podfile
  fi
fi
