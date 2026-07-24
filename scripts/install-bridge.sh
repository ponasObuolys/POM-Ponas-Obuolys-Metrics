#!/bin/bash
# Įdiegia POM tiltą į Claude Code statusline scenarijų.
#
# Prieš keisdamas pasidaro atsarginę kopiją. Paleistas antrą kartą nieko nedubliuoja,
# tik atnaujina patį tilto scenarijų.

set -euo pipefail

script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
support_dir="$HOME/Library/Application Support/POM"
bridge="$support_dir/pom-bridge.sh"
settings="$HOME/.claude/settings.json"
marker_start="# >>> POM (Ponas Obuolys Metrika) >>>"
marker_end="# <<< POM (Ponas Obuolys Metrika) <<<"

echo "POM tilto diegimas"
echo

# 1. Surandamas statusline scenarijus
statusline=""
if [ -f "$settings" ] && command -v jq >/dev/null 2>&1; then
  raw=$(jq -r '.statusLine.command // ""' "$settings" 2>/dev/null || echo "")
  if [ -n "$raw" ]; then
    statusline="${raw/#\~/$HOME}"
  fi
fi
[ -n "$statusline" ] || statusline="$HOME/.claude/statusline.sh"

if [ ! -f "$statusline" ]; then
  echo "Klaida: nerastas statusline scenarijus ($statusline)."
  echo "Claude Code nustatymuose turi būti nurodytas statusLine.command."
  exit 1
fi
echo "Statusline scenarijus: $statusline"

# 2. Įrašomas tilto scenarijus
mkdir -p "$support_dir"
cp "$script_dir/pom-bridge.sh" "$bridge"
chmod +x "$bridge"
echo "Tilto scenarijus: $bridge"

# 3. Ar jau prikabinta
if grep -qF "$marker_start" "$statusline"; then
  echo
  echo "Tiltas jau buvo prikabintas, atnaujintas tik jo scenarijus."
  exit 0
fi

# 4. Surandama vieta, kur scenarijus perskaito duomenis iš Claude Code
hook_line=$(grep -n -m1 -E '^[[:space:]]*[A-Za-z_][A-Za-z0-9_]*=\$\(cat\)' "$statusline" | cut -d: -f1 || true)
if [ -z "$hook_line" ]; then
  echo
  echo "Klaida: scenarijuje nerasta eilutė, kurioje nuskaitomi duomenys iš Claude Code"
  echo "(tikimasi pavidalo: input=\$(cat))."
  echo "Prikabink tiltą ranka, iškart po tos eilutės įrašydamas:"
  echo
  echo "  $marker_start"
  echo "  printf '%s' \"\$input\" | \"\$HOME/Library/Application Support/POM/pom-bridge.sh\" >/dev/null 2>&1 &"
  echo "  $marker_end"
  exit 1
fi

variable=$(sed -n "${hook_line}p" "$statusline" | sed -E 's/^[[:space:]]*([A-Za-z_][A-Za-z0-9_]*)=.*/\1/')

# 5. Atsarginė kopija
backup="$statusline.bak-$(date +%Y%m%d%H%M%S)"
cp "$statusline" "$backup"
echo "Atsarginė kopija: $backup"

# 6. Įterpiamas kablys
tmp=$(mktemp)
{
  sed -n "1,${hook_line}p" "$statusline"
  echo ""
  echo "$marker_start"
  echo "# Limitų reikšmės perduodamos meniu juostos programai. Veikia fone, todėl"
  echo "# statusline greičio nestabdo. Pašalinama: scripts/uninstall-bridge.sh"
  echo "printf '%s' \"\$$variable\" | \"\$HOME/Library/Application Support/POM/pom-bridge.sh\" >/dev/null 2>&1 &"
  echo "$marker_end"
  sed -n "$((hook_line + 1)),\$p" "$statusline"
} >"$tmp"

# 7. Patikra prieš perrašant: naujas scenarijus turi būti sintaksiškai teisingas
if ! bash -n "$tmp"; then
  rm -f "$tmp"
  echo "Klaida: pakeistas scenarijus nepraėjo sintaksės patikros. Niekas nepakeista."
  exit 1
fi

cat "$tmp" >"$statusline"
rm -f "$tmp"
chmod +x "$statusline"

echo
echo "Padaryta. Kitą kartą atnaujinus statusline (iki 30 sek.) atsiras failas:"
echo "  $support_dir/snapshot.json"
