#!/bin/bash
# Only for ephemeral GitHub-hosted runners. No login Keychain/search-list changes.
set -euo pipefail
[[ "${GITHUB_ACTIONS:-}" == true ]] || { echo 'This script is for GitHub Actions only.' >&2; exit 1; }
for name in POM_CERTIFICATE_P12 POM_CERTIFICATE_PASSWORD POM_SIGN_IDENTITY APPLE_API_KEY_P8 APPLE_API_KEY_ID APPLE_API_ISSUER POM_SPARKLE_PRIVATE_KEY; do
  [[ -n "${!name:-}" ]] || { echo "Missing required release secret: $name" >&2; exit 1; }
done
umask 077
keychain="$RUNNER_TEMP/pom-signing.keychain-db"
password="$(openssl rand -base64 32)"
cert="$RUNNER_TEMP/pom-certificate.p12"
api_key="$RUNNER_TEMP/pom-notary-key.p8"
trap 'rm -f "$cert" "$api_key"' EXIT
printf '%s' "$POM_CERTIFICATE_P12" | base64 --decode > "$cert"
printf '%s' "$APPLE_API_KEY_P8" > "$api_key"
security create-keychain -p "$password" "$keychain"
security set-keychain-settings -lut 21600 "$keychain"
security unlock-keychain -p "$password" "$keychain"
security import "$cert" -P "$POM_CERTIFICATE_PASSWORD" -k "$keychain" -T /usr/bin/codesign >/dev/null
security set-key-partition-list -S apple-tool:,apple: -s -k "$password" "$keychain" >/dev/null
xcrun notarytool store-credentials POM-notary --key "$api_key" --key-id "$APPLE_API_KEY_ID" --issuer "$APPLE_API_ISSUER" --keychain "$keychain"
printf 'POM_SIGN_KEYCHAIN=%s\nPOM_NOTARY_KEYCHAIN=%s\nPOM_NOTARY_PROFILE=POM-notary\n' "$keychain" "$keychain" >> "$GITHUB_ENV"
