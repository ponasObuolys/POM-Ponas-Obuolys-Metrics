#!/bin/bash
# Prepare a signed, notarized DMG and signed Sparkle feed. Does not publish.
set -euo pipefail
root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$root"
: "${POM_SIGN_IDENTITY:?Set a Developer ID Application identity}"
: "${POM_NOTARY_PROFILE:?Set a notarytool Keychain profile}"
bash scripts/apple-preflight.sh --verify-notary
export POM_RELEASE=1
notary_args=(--keychain-profile "$POM_NOTARY_PROFILE")
if [[ -n "${POM_NOTARY_KEYCHAIN:-}" ]]; then notary_args+=(--keychain "$POM_NOTARY_KEYCHAIN"); fi
version="$(tr -d '[:space:]' < VERSION)"
bash scripts/bundle.sh
zip="$root/dist/POM-notarization.zip"
ditto -c -k --keepParent dist/POM.app "$zip"
# --wait exits nonzero when Apple rejects a submission. Staple/assess must also pass.
xcrun notarytool submit "$zip" "${notary_args[@]}" --wait --timeout 30m
xcrun stapler staple dist/POM.app
xcrun stapler validate dist/POM.app
spctl --assess --type execute --verbose=2 dist/POM.app
bash scripts/make-dmg.sh
dmg="$root/dist/POM-$version.dmg"
xcrun notarytool submit "$dmg" "${notary_args[@]}" --wait --timeout 30m
xcrun stapler staple "$dmg"
xcrun stapler validate "$dmg"
spctl --assess --type open --context context:primary-signature --verbose=2 "$dmg"
bash scripts/make-appcast.sh
(cd dist && shasum -a 256 "POM-$version.dmg" > "POM-$version.dmg.sha256")
echo 'Ready for review and publication. Nothing has been uploaded.'
