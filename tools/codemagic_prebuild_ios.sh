#!/usr/bin/env bash
# Pre-build Codemagic: ios/, bundle, plist, Apple entitlement, Google URL scheme.
set -euo pipefail

IOS_MIN='15.5'

flutter config --no-enable-swift-package-manager

if [ ! -d ios ]; then
  flutter create --platforms=ios --org app --project-name life_wallet_puelo .
fi

ENT=ios/Runner/Runner.entitlements
cat > "$ENT" <<'EOF'
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
	<key>com.apple.developer.applesignin</key>
	<array>
		<string>Default</string>
	</array>
</dict>
</plist>
EOF

if [ -f ios/Runner.xcodeproj/project.pbxproj ]; then
  sed -i '' 's/PRODUCT_BUNDLE_IDENTIFIER = [^;]*/PRODUCT_BUNDLE_IDENTIFIER = app.puelo/g' \
    ios/Runner.xcodeproj/project.pbxproj || true
  sed -i '' "s/IPHONEOS_DEPLOYMENT_TARGET = [0-9.]*/IPHONEOS_DEPLOYMENT_TARGET = ${IOS_MIN}/g" \
    ios/Runner.xcodeproj/project.pbxproj || true
  if ! grep -q 'CODE_SIGN_ENTITLEMENTS' ios/Runner.xcodeproj/project.pbxproj; then
    sed -i '' "s#IPHONEOS_DEPLOYMENT_TARGET = ${IOS_MIN};#IPHONEOS_DEPLOYMENT_TARGET = ${IOS_MIN};\n\t\t\t\tCODE_SIGN_ENTITLEMENTS = Runner/Runner.entitlements;#g" \
      ios/Runner.xcodeproj/project.pbxproj || true
  fi
fi

if [ -n "${GOOGLESERVICE_INFO_PLIST:-}" ]; then
  printf '%s\n' "$GOOGLESERVICE_INFO_PLIST" > ios/Runner/GoogleService-Info.plist
fi

PLIST=ios/Runner/Info.plist
GS=ios/Runner/GoogleService-Info.plist
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

  if [ -f "$GS" ]; then
    CLIENT_ID=$(/usr/libexec/PlistBuddy -c 'Print :CLIENT_ID' "$GS" 2>/dev/null || true)
    REVERSED=$(/usr/libexec/PlistBuddy -c 'Print :REVERSED_CLIENT_ID' "$GS" 2>/dev/null || true)
    if [ -n "${CLIENT_ID:-}" ]; then
      /usr/libexec/PlistBuddy -c "Add :GIDClientID string $CLIENT_ID" "$PLIST" 2>/dev/null || \
        /usr/libexec/PlistBuddy -c "Set :GIDClientID $CLIENT_ID" "$PLIST" || true
    fi
    if [ -n "${REVERSED:-}" ]; then
      /usr/libexec/PlistBuddy -c 'Add :CFBundleURLTypes array' "$PLIST" 2>/dev/null || true
      /usr/libexec/PlistBuddy -c 'Add :CFBundleURLTypes:0 dict' "$PLIST" 2>/dev/null || true
      /usr/libexec/PlistBuddy -c "Add :CFBundleURLTypes:0:CFBundleURLSchemes array" "$PLIST" 2>/dev/null || true
      /usr/libexec/PlistBuddy -c "Add :CFBundleURLTypes:0:CFBundleURLSchemes:0 string $REVERSED" "$PLIST" 2>/dev/null || \
        /usr/libexec/PlistBuddy -c "Set :CFBundleURLTypes:0:CFBundleURLSchemes:0 $REVERSED" "$PLIST" || true
    fi
  fi
fi

if [ -f ios/Podfile ]; then
  if grep -q "platform :ios" ios/Podfile; then
    sed -i '' "s/^# *platform :ios.*/platform :ios, '${IOS_MIN}'/" ios/Podfile
    sed -i '' "s/^platform :ios.*/platform :ios, '${IOS_MIN}'/" ios/Podfile
  else
    printf '%s\n%s\n' "platform :ios, '${IOS_MIN}'" "$(cat ios/Podfile)" > ios/Podfile
  fi
fi

# Ícono PROX (P) — reemplaza el Flutter default. Sin alpha (Apple 1024).
ICON_SRC=""
for cand in \
  assets/brand/app_icon_ios_1024.png \
  assets/images/logo_prox_icon.png.png \
  assets/images/logo_prox_icon.png; do
  if [ -f "$cand" ]; then
    ICON_SRC="$cand"
    break
  fi
done
ICON_DIR=ios/Runner/Assets.xcassets/AppIcon.appiconset
if [ -n "$ICON_SRC" ] && [ -d "$ICON_DIR" ] && command -v sips >/dev/null 2>&1; then
  SQ=/tmp/prox_icon_sq.png
  JPG=/tmp/prox_icon.jpg
  MASTER=/tmp/prox_icon_1024.png
  sips --resampleHeightWidthMax 1024 "$ICON_SRC" --out /tmp/prox_icon_in.png >/dev/null
  # recorte cuadrado centrado
  sips --cropToHeightWidth 1024 1024 /tmp/prox_icon_in.png --out "$SQ" >/dev/null || cp /tmp/prox_icon_in.png "$SQ"
  # aplastar alpha → JPEG → PNG (requisito App Store)
  sips -s format jpeg -s formatOptions 90 "$SQ" --out "$JPG" >/dev/null
  sips -s format png "$JPG" --out "$MASTER" >/dev/null
  sips -z 1024 1024 "$MASTER" --out "$MASTER" >/dev/null
  shopt -s nullglob
  for f in "$ICON_DIR"/*.png; do
    w=$(sips -g pixelWidth "$f" 2>/dev/null | awk '/pixelWidth/{print $2}')
    h=$(sips -g pixelHeight "$f" 2>/dev/null | awk '/pixelHeight/{print $2}')
    if [ -n "${w:-}" ] && [ -n "${h:-}" ]; then
      sips -z "$h" "$w" "$MASTER" --out "$f" >/dev/null
    fi
  done
  echo "AppIcon PROX aplicado desde $ICON_SRC"
else
  echo "AppIcon: no se aplicó (src='$ICON_SRC' dir='$ICON_DIR')"
fi
