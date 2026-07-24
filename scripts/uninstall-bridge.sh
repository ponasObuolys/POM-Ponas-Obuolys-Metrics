#!/bin/bash
# Pašalina POM tiltą iš Claude Code statusline scenarijaus.
# Pats statusline lieka veikti taip, kaip veikė prieš diegimą.

set -euo pipefail

settings="$HOME/.claude/settings.json"
marker_start="# >>> POM (Ponas Obuolys Metrika) >>>"
marker_end="# <<< POM (Ponas Obuolys Metrika) <<<"

statusline=""
if [ -f "$settings" ] && command -v jq >/dev/null 2>&1; then
  raw=$(jq -r '.statusLine.command // ""' "$settings" 2>/dev/null || echo "")
  [ -n "$raw" ] && statusline="${raw/#\~/$HOME}"
fi
[ -n "$statusline" ] || statusline="$HOME/.claude/statusline.sh"

if [ ! -f "$statusline" ]; then
  echo "Statusline scenarijus nerastas ($statusline). Nėra ko šalinti."
  exit 0
fi

if ! grep -qF "$marker_start" "$statusline"; then
  echo "Tiltas neprikabintas. Niekas nekeista."
  exit 0
fi

backup="$statusline.bak-$(date +%Y%m%d%H%M%S)"
cp "$statusline" "$backup"

tmp=$(mktemp)
awk -v start="$marker_start" -v end="$marker_end" '
  index($0, start) { skipping = 1 }
  !skipping { print }
  index($0, end) { skipping = 0 }
' "$statusline" >"$tmp"

if ! bash -n "$tmp"; then
  rm -f "$tmp"
  echo "Klaida: rezultatas nepraėjo sintaksės patikros. Niekas nepakeista."
  exit 1
fi

cat "$tmp" >"$statusline"
rm -f "$tmp"
chmod +x "$statusline"

echo "Tiltas pašalintas. Atsarginė kopija: $backup"
