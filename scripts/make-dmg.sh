#!/bin/bash
set -euo pipefail
root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
version="$(tr -d '[:space:]' < "$root/VERSION")"
app="$root/dist/POM.app"
staging="$root/dist/dmg-staging"
dmg="$root/dist/POM-$version.dmg"
[[ -d "$app" ]] || { echo 'Run scripts/bundle.sh first.' >&2; exit 1; }
if [[ "${POM_RELEASE:-0}" == 1 ]]; then
  [[ "${POM_SIGN_IDENTITY:-}" == "Developer ID Application:"* ]] || { echo 'Developer ID required.' >&2; exit 1; }
  xcrun stapler validate "$app"
  spctl --assess --type execute --verbose=2 "$app"
fi
rm -rf "$staging"
mkdir -p "$staging"
trap 'rm -rf "$staging"' EXIT
ditto "$app" "$staging/POM.app"
ln -s /Applications "$staging/Applications"
cp "$root/docs/INSTALL.txt" "$staging/Read Me - Skaityk mane.txt"
if [[ "${POM_RELEASE:-0}" != 1 ]]; then
  printf '%s\n' 'DEVELOPMENT BUILD — not notarized. For local testing only.' > "$staging/DEVELOPMENT BUILD.txt"
fi
hdiutil create -volname "POM $version" -srcfolder "$staging" -ov -format UDZO "$dmg" >/dev/null
if [[ "${POM_SIGN_IDENTITY:-}" == "Developer ID Application:"* ]]; then
  sign_args=(--force --sign "$POM_SIGN_IDENTITY" --timestamp)
  if [[ -n "${POM_SIGN_KEYCHAIN:-}" ]]; then sign_args+=(--keychain "$POM_SIGN_KEYCHAIN"); fi
  codesign "${sign_args[@]}" "$dmg"
else
  codesign --force --sign - --timestamp=none "$dmg"
fi
hdiutil verify "$dmg" >/dev/null
echo "Created: $dmg"
