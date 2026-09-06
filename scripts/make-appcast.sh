#!/bin/bash
# Never generate a public update feed from a development bundle.
set -euo pipefail
root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$root"
version="$(tr -d '[:space:]' < VERSION)"
dmg="$root/dist/POM-$version.dmg"
xcrun stapler validate "$dmg"
spctl --assess --type open --context context:primary-signature --verbose=2 "$dmg"
updates="$root/dist/updates"
rm -rf "$updates"
mkdir -p "$updates"
cp "$dmg" "$updates/"
tool="$root/.build/artifacts/sparkle/Sparkle/bin/generate_appcast"
args=(--download-url-prefix "https://github.com/ponasObuolys/POM-Ponas-Obuolys-Metrics/releases/download/v$version/" --maximum-deltas 0)
if [[ -n "${POM_SPARKLE_PRIVATE_KEY:-}" ]]; then
  printf '%s' "$POM_SPARKLE_PRIVATE_KEY" | "$tool" --ed-key-file - "${args[@]}" "$updates"
else
  "$tool" --account lt.ponasobuolys.pom "${args[@]}" "$updates"
fi
cp "$updates/appcast.xml" "$root/dist/appcast.xml"
python3 scripts/verify-appcast.py "$root/dist/appcast.xml" "$dmg" "$version"
