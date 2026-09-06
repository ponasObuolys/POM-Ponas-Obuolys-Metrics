#!/bin/bash
# Universal Apple silicon + Intel bundle. Public releases require Developer ID.
set -euo pipefail
root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$root"
version="$(tr -d '[:space:]' < VERSION)"
if [[ "${POM_RELEASE:-0}" == 1 && "${POM_SIGN_IDENTITY:-}" != "Developer ID Application:"* ]]; then
  echo "Release stopped: a valid Developer ID Application identity is required." >&2
  exit 1
fi
key="$(tr -d '[:space:]' < config/sparkle-public-key.txt)"
if [[ ! "$key" =~ ^[A-Za-z0-9+/]{43}=$ ]]; then
  echo "Invalid Sparkle public key." >&2; exit 1
fi
for arch in arm64 x86_64; do
  swift build -c release --triple "$arch-apple-macosx14.0" --product POM
done
arm_dir="$(swift build -c release --triple arm64-apple-macosx14.0 --show-bin-path)"
intel_dir="$(swift build -c release --triple x86_64-apple-macosx14.0 --show-bin-path)"
app="$root/dist/POM.app"
contents="$app/Contents"
rm -rf "$app" "$root/dist/POM.iconset"
mkdir -p "$contents/MacOS" "$contents/Resources" "$contents/Frameworks" "$root/dist/POM.iconset"
lipo -create "$arm_dir/POM" "$intel_dir/POM" -output "$contents/MacOS/POM"
swift scripts/make-icon.swift "$root/dist/POM.iconset" >/dev/null
iconutil -c icns "$root/dist/POM.iconset" -o "$contents/Resources/POM.icns"
rm -rf "$root/dist/POM.iconset"
ditto "$arm_dir/POM_POM.bundle" "$contents/Resources/POM_POM.bundle"
ditto "$arm_dir/Sparkle.framework" "$contents/Frameworks/Sparkle.framework"
for script in install-bridge pom-bridge statusline-command; do
  cp "scripts/$script.sh" "$contents/Resources/"
  chmod +x "$contents/Resources/$script.sh"
done
cat > "$contents/Info.plist" <<PLIST
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0"><dict>
<key>CFBundleName</key><string>POM</string>
<key>CFBundleDisplayName</key><string>POM</string>
<key>CFBundleIdentifier</key><string>lt.ponasobuolys.pom</string>
<key>CFBundleExecutable</key><string>POM</string>
<key>CFBundleIconFile</key><string>POM</string>
<key>CFBundlePackageType</key><string>APPL</string>
<key>CFBundleShortVersionString</key><string>$version</string>
<key>CFBundleVersion</key><string>$version</string>
<key>CFBundleDevelopmentRegion</key><string>en</string>
<key>CFBundleLocalizations</key><array><string>en</string><string>lt</string></array>
<key>LSMinimumSystemVersion</key><string>14.0</string>
<key>LSUIElement</key><true/>
<key>NSHumanReadableCopyright</key><string>Ponas Obuolys</string>
<key>SUFeedURL</key><string>https://github.com/ponasObuolys/POM-Ponas-Obuolys-Metrics/releases/latest/download/appcast.xml</string>
<key>SUPublicEDKey</key><string>$key</string>
<key>SUEnableAutomaticChecks</key><true/>
<key>SUAutomaticallyUpdate</key><false/>
<key>SUEnableInstallerLauncherService</key><true/>
<key>SUVerifyUpdateBeforeExtraction</key><true/>
<key>SURequireSignedFeed</key><true/>
</dict></plist>
PLIST
plutil -lint "$contents/Info.plist"
bash scripts/sign-app.sh "$app"
lipo -info "$contents/MacOS/POM"
echo "Built: $app"
if [[ "${POM_RELEASE:-0}" != 1 ]]; then
  echo "Development build. Not notarized; do not distribute as a trusted release."
fi
