#!/bin/bash
# Sukompiliuoja POM ir supakuoja į POM.app.
#
# Xcode nereikia: naudojama tik Swift Package Manager ir komandinės eilutės įrankiai.
# Paketas pasirašomas vietiniu parašu (ad-hoc), to pakanka savo kompiuteriui.

set -euo pipefail

root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
app_name="POM"
bundle_id="lt.ponasobuolys.pom"
version="1.0.0"

dist="$root/dist"
app="$dist/$app_name.app"
contents="$app/Contents"

echo "1/4 Kompiliuojama"
swift build --package-path "$root" -c release

echo "2/4 Piešiama ikona"
iconset="$dist/$app_name.iconset"
rm -rf "$iconset"
mkdir -p "$iconset"
swift "$root/scripts/make-icon.swift" "$iconset" >/dev/null
iconutil -c icns "$iconset" -o "$dist/$app_name.icns"
rm -rf "$iconset"

echo "3/4 Dedamas paketas"
rm -rf "$app"
mkdir -p "$contents/MacOS" "$contents/Resources"
cp "$root/.build/release/$app_name" "$contents/MacOS/$app_name"
cp "$dist/$app_name.icns" "$contents/Resources/$app_name.icns"

cat >"$contents/Info.plist" <<PLIST
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>CFBundleName</key>
    <string>$app_name</string>
    <key>CFBundleDisplayName</key>
    <string>POM</string>
    <key>CFBundleIdentifier</key>
    <string>$bundle_id</string>
    <key>CFBundleExecutable</key>
    <string>$app_name</string>
    <key>CFBundleIconFile</key>
    <string>$app_name</string>
    <key>CFBundlePackageType</key>
    <string>APPL</string>
    <key>CFBundleShortVersionString</key>
    <string>$version</string>
    <key>CFBundleVersion</key>
    <string>$version</string>
    <key>LSMinimumSystemVersion</key>
    <string>14.0</string>
    <key>LSUIElement</key>
    <true/>
    <key>NSHumanReadableCopyright</key>
    <string>Ponas Obuolys</string>
</dict>
</plist>
PLIST

plutil -lint "$contents/Info.plist" >/dev/null

echo "4/4 Pasirašoma"
# Pastovus savadarbis parašas leidžia macOS atpažinti POM kaip tą pačią programą po
# kiekvieno perkompiliavimo. Be jo neveikia nei pranešimai, nei raktinės leidimo įsiminimas.
identity="POM Self-Signed"
if security find-identity -p codesigning 2>/dev/null | grep -q "$identity"; then
  codesign --force --sign "$identity" --timestamp=none "$app"
  echo "    parašas: $identity"
else
  codesign --force --sign - --timestamp=none "$app" >/dev/null 2>&1
  echo "    parašas: laikinas (ad-hoc)"
  echo "    Patarimas: ./scripts/create-signing-cert.sh įjungtų pranešimus POM vardu."
fi
codesign --verify "$app"

echo
echo "Paruošta: $app"
