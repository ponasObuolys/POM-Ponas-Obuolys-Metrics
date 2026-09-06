#!/bin/bash
# Sign nested Sparkle components from the inside out; never use --deep to sign.
set -euo pipefail
app="${1:?Pass the path to POM.app}"
identity="${POM_SIGN_IDENTITY:--}"
args=(--force --sign "$identity")
if [[ -n "${POM_SIGN_KEYCHAIN:-}" ]]; then args+=(--keychain "$POM_SIGN_KEYCHAIN"); fi
if [[ "$identity" == "Developer ID Application:"* ]]; then
  args+=(--options runtime --timestamp)
else
  if [[ "${POM_RELEASE:-0}" == 1 ]]; then
    echo "Public releases require POM_SIGN_IDENTITY='Developer ID Application: …'." >&2
    exit 1
  fi
  args+=(--timestamp=none)
fi
framework="$app/Contents/Frameworks/Sparkle.framework"
for part in XPCServices/Installer.xpc XPCServices/Downloader.xpc Autoupdate Updater.app; do
  target="$framework/Versions/B/$part"
  if [[ -e "$target" ]]; then
    codesign "${args[@]}" --preserve-metadata=entitlements "$target"
  fi
done
codesign "${args[@]}" "$framework"
codesign "${args[@]}" "$app"
codesign --verify --deep --strict "$app"
