#!/bin/bash
# Read-only checks. Never creates certificates, buys membership or prints secrets.
set -euo pipefail
verify_notary=0
app_store=0
for option in "$@"; do
  case "$option" in
    --verify-notary) verify_notary=1 ;;
    --app-store) app_store=1 ;;
    --help)
      echo 'Usage: bash scripts/apple-preflight.sh [--verify-notary] [--app-store]'
      echo 'Default: local Developer ID checks. --verify-notary adds a read-only Apple request.'
      echo '--app-store also requires full Xcode with macOS and iOS SDKs; it does not certify App Store eligibility.'
      exit 0 ;;
    *) echo "Unknown option: $option" >&2; exit 2 ;;
  esac
done
failures=0
ok() { echo "OK: $*"; }
missing() { echo "MISSING: $*"; failures=$((failures + 1)); }

for name in codesign security xcrun; do
  command -v "$name" >/dev/null 2>&1 || missing "$name is not available."
done
if xcrun --find notarytool >/dev/null 2>&1; then
  ok 'notarytool is available.'
else
  missing 'notarytool is unavailable. Install current Apple developer tools.'
fi
if xcrun --find stapler >/dev/null 2>&1; then
  ok 'stapler is available.'
else
  missing 'stapler is unavailable. Install current Apple developer tools.'
fi

identity_args=(-v -p codesigning)
if [[ -n "${POM_SIGN_KEYCHAIN:-}" ]]; then identity_args+=("$POM_SIGN_KEYCHAIN"); fi
identities="$(security find-identity "${identity_args[@]}" 2>/dev/null || true)"
count=0
matched=0
while IFS= read -r line; do
  if [[ "$line" == *'"Developer ID Application:'* ]]; then
    candidate="${line#*\"}"
    candidate="${candidate%%\"*}"
    count=$((count + 1))
    if [[ "$candidate" == "${POM_SIGN_IDENTITY:-}" ]]; then matched=1; fi
  fi
done <<< "$identities"
if [[ "$count" == 0 ]]; then
  missing 'No valid Developer ID Application identity with private key. Complete membership and certificate setup.'
elif [[ -z "${POM_SIGN_IDENTITY:-}" ]]; then
  missing "$count Developer ID identity/identities available; set POM_SIGN_IDENTITY to the exact name."
elif [[ "$matched" == 1 ]]; then
  ok 'The configured Developer ID Application identity is available.'
else
  missing 'POM_SIGN_IDENTITY does not match a valid Developer ID Application identity in the selected Keychain.'
fi

if [[ "$verify_notary" == 1 ]]; then
  if [[ -z "${POM_NOTARY_PROFILE:-}" ]]; then
    missing 'Set POM_NOTARY_PROFILE after storing notarization credentials in Keychain.'
  else
    notary_args=(--keychain-profile "$POM_NOTARY_PROFILE")
    if [[ -n "${POM_NOTARY_KEYCHAIN:-}" ]]; then notary_args+=(--keychain "$POM_NOTARY_KEYCHAIN"); fi
    # Discard account data and credential error details. No keys enter logs.
    if xcrun notarytool history "${notary_args[@]}" --output-format json >/dev/null 2>&1; then
      ok 'Apple accepted the stored notarization credentials.'
    else
      missing 'Cannot verify notarization credentials. Check the Keychain profile, membership and network.'
    fi
  fi
else
  echo 'NOT CHECKED: Apple membership and notarization access; use --verify-notary after setup.'
fi

if [[ "$app_store" == 1 ]]; then
  if xcodebuild -version >/dev/null 2>&1; then
    ok 'Full Xcode is selected.'
    if xcodebuild -checkFirstLaunchStatus >/dev/null 2>&1; then
      ok 'Xcode first-launch setup is complete.'
    else
      missing 'Complete Xcode first launch: review the license and install required components in Xcode.'
    fi
    for sdk in macosx iphoneos iphonesimulator; do
      if xcrun --sdk "$sdk" --show-sdk-path >/dev/null 2>&1; then
        ok "$sdk SDK is available."
      else
        missing "$sdk SDK is unavailable. Install the platform in Xcode Settings."
      fi
    done
  else
    missing 'Full Xcode is not selected. Command Line Tools alone cannot build/test iPhone and iPad apps.'
  fi
  echo 'NOT CHECKED: App Store distribution profiles, registered app IDs, CloudKit container, device tests or App Review.'
fi

if [[ "$failures" -gt 0 ]]; then
  echo "Not ready: $failures required check(s) failed. See docs/APPLE-DISTRIBUTION.md."
  exit 1
fi
echo 'Requested preflight checks passed. No build was signed, notarized or published.'
