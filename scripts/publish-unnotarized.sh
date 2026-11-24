#!/bin/bash
# Publish the current VERSION as a clearly labelled unnotarized GitHub release:
# universal DMG, checksum and a signed appcast. Existing installs (2.2.1 and later)
# then offer the new version and install it in the app after the user agrees.
# Notarized releases use release.sh instead.
set -euo pipefail
root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$root"
repo_url="https://github.com/ponasObuolys/POM-Ponas-Obuolys-Metrics"
version="$(tr -d '[:space:]' < VERSION)"
tag="v$version"
notes="docs/releases/$version.md"
fail() { echo "Publication stopped: $1" >&2; exit 1; }

[[ "$version" =~ ^[0-9]+\.[0-9]+\.[0-9]+$ ]] || fail "VERSION must look like X.Y.Z."
[[ -f "$notes" ]] || fail "$notes is missing."
[[ "$(git branch --show-current)" == main ]] || fail "switch to main first."
[[ -z "$(git status --porcelain)" ]] || fail "commit or discard local changes first."
git fetch --quiet --tags origin
if git ls-remote --exit-code --tags origin "refs/tags/$tag" >/dev/null 2>&1; then
  fail "$tag is already published. Raise VERSION instead of replacing a release."
fi
# The download pages must describe the version people actually receive.
for doc in README.md README.lt.md docs/INSTALL.txt; do
  grep -q "$version" "$doc" || fail "$doc does not mention $version."
done
if grep -qiE 'have not been published|no public release' "$notes"; then
  fail "$notes still says the version is unpublished."
fi

# A Developer ID identity belongs to release.sh; this path is always ad-hoc signed.
unset POM_RELEASE POM_SIGN_IDENTITY POM_SIGN_KEYCHAIN
build_args=()
if [[ -n "${POM_BUILD_SDK:-}" ]]; then build_args+=(--sdk "$POM_BUILD_SDK"); fi
if [[ -n "${POM_BUILD_SYSTEM:-}" ]]; then build_args+=(--build-system "$POM_BUILD_SYSTEM"); fi
swift run ${build_args[@]+"${build_args[@]}"} pom-tests
python3 tests/bridge_tests.py
bash scripts/bundle.sh
built="$(/usr/libexec/PlistBuddy -c 'Print :CFBundleShortVersionString' dist/POM.app/Contents/Info.plist)"
[[ "$built" == "$version" ]] || fail "the built app reports $built, expected $version."
POM_PUBLIC_UNNOTARIZED=1 bash scripts/make-dmg.sh
dmg="dist/POM-$version.dmg"

updates="$root/dist/updates"
rm -rf "$updates"
mkdir -p "$updates"
trap 'rm -rf "$updates"' EXIT
cp "$dmg" "$updates/"
python3 - "$notes" "$updates/POM-$version.html" <<'PY'
import html, sys
title = open(sys.argv[1], encoding="utf-8").readline().lstrip("# ").strip()
open(sys.argv[2], "w", encoding="utf-8").write(
    f"<h2>{html.escape(title)}</h2>"
    "<p>Install Update downloads the new version, verifies its signature and restarts POM. "
    "Your settings and history stay. This release is not Apple-notarized.</p>"
    "<p><strong>Lietuviškai:</strong> paspaudus Install Update, POM atsisiunčia naują versiją, "
    "patikrina jos parašą ir pasileidžia iš naujo. Nustatymai ir istorija išlieka. "
    "Leidimas Apple nenotarizuotas.</p>")
PY
.build/artifacts/sparkle/Sparkle/bin/generate_appcast --account lt.ponasobuolys.pom \
  --download-url-prefix "$repo_url/releases/download/$tag/" --link "$repo_url/releases/tag/$tag" \
  --embed-release-notes --maximum-deltas 0 "$updates"
cp "$updates/appcast.xml" dist/appcast.xml
python3 scripts/verify-appcast.py "$root/dist/appcast.xml" "$root/$dmg" "$version"
# An informational feed only opens the release page; users then stay on old versions.
if grep -q '<sparkle:informationalUpdate>' dist/appcast.xml; then fail "the feed must offer in-app installation."; fi
(cd dist && shasum -a 256 "POM-$version.dmg" > "POM-$version.dmg.sha256")

git tag -a "$tag" -m "POM $version"
git push origin main "$tag"
gh release create "$tag" "$dmg" "$dmg.sha256" dist/appcast.xml \
  --verify-tag --latest --title "POM $version" --notes-file "$notes"

# Installed copies read this address; publication is complete only when it serves the new version.
for _ in $(seq 1 12); do
  if curl -fsSL --max-time 20 "$repo_url/releases/latest/download/appcast.xml" \
      | grep -q "<sparkle:version>$version</sparkle:version>"; then
    echo "Published: $repo_url/releases/tag/$tag — the live update feed now offers $version."
    exit 0
  fi
  sleep 10
done
fail "the release exists, but the live update feed does not offer $version yet."
