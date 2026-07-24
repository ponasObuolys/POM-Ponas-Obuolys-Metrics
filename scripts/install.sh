#!/bin/bash
# Įdiegia POM į /Applications ir paleidžia.
#
# Į /Applications dedama sąmoningai: macOS pranešimų sistema priima tik iš ten
# paleistas savo parašu pasirašytas programas.

set -euo pipefail

root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
app_name="POM"
source_app="$root/dist/$app_name.app"
target_app="/Applications/$app_name.app"

if [ ! -d "$source_app" ]; then
  echo "Nerastas $source_app. Pirma paleisk: ./scripts/bundle.sh"
  exit 1
fi

echo "1/4 Uždaroma sena versija"
pkill -f "/Applications/$app_name.app/Contents/MacOS/$app_name" 2>/dev/null || true
pkill -f "$root/dist/$app_name.app/Contents/MacOS/$app_name" 2>/dev/null || true
sleep 1

echo "2/4 Kopijuojama į /Applications"
rm -rf "$target_app"
cp -R "$source_app" "$target_app"
xattr -dr com.apple.quarantine "$target_app" 2>/dev/null || true

echo "3/4 Registruojama sistemoje"
/System/Library/Frameworks/CoreServices.framework/Frameworks/LaunchServices.framework/Support/lsregister \
  -f "$target_app" 2>/dev/null || true

echo "4/4 Paleidžiama"
open "$target_app"

echo
echo "Įdiegta: $target_app"
echo
echo "Jei ikonos prie laikrodžio nematai, patikrink meniu juostos tvarkyklę"
echo "(pvz., Ice arba Bartender) – naujus elementus ji dažnai paslepia."
