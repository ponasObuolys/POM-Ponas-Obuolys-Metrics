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

# 0. Be jq tiltas duomenų neišrinktų ir tyliai nieko nerašytų, tad tikrinama iš karto.
if ! command -v jq >/dev/null 2>&1; then
  echo "Klaida: reikalinga jq komanda, be jos tiltas duomenų neperduotų."
  echo "Įdiek ją: brew install jq"
  exit 1
fi

# Iš nustatymuose įrašytos komandos ištraukia scenarijaus kelią. Komandoje gali būti ne tik
# pats scenarijus, bet ir vykdyklė su argumentais („bash ~/.claude/juosta.sh --trumpai“),
# todėl imamas pirmas į kelią panašus žodis, kuris tikrai yra esamas failas.
resolve_script() {
  local command="$1" token expanded
  for token in $command; do
    token="${token%\"}"; token="${token#\"}"
    token="${token%\'}"; token="${token#\'}"
    case "$token" in
      */* | "~"*) ;;
      *) continue ;;
    esac
    expanded="${token/#\~/$HOME}"
    if [ -f "$expanded" ]; then
      printf '%s' "$expanded"
      return 0
    fi
  done
  return 1
}

# Komanda iš vieno žodžio, panašaus į kelią. Tokį failą sukurti saugu: nustatymai
# į jį jau rodo, tad nieko svetimo nepakeisime.
single_path() {
  local command="$1" token count=0 candidate=""
  for token in $command; do
    count=$((count + 1))
    candidate="$token"
  done
  [ "$count" -eq 1 ] || return 1
  candidate="${candidate%\"}"; candidate="${candidate#\"}"
  candidate="${candidate%\'}"; candidate="${candidate#\'}"
  case "$candidate" in
    */* | "~"*)
      printf '%s' "${candidate/#\~/$HOME}"
      return 0
      ;;
  esac
  return 1
}

# 1. Surandamas statusline scenarijus
configured=""
if [ -f "$settings" ]; then
  configured=$(jq -r '.statusLine.command // ""' "$settings" 2>/dev/null || echo "")
fi

statusline=""
create_target=""
register=false

if [ -z "$configured" ]; then
  # Būsenos juostos nėra visai. Be jos Claude Code limitų reikšmių niekam neperduoda,
  # tad kitokio kelio prie duomenų nėra: susikuriame savo ir užregistruojame.
  create_target="$HOME/.claude/statusline.sh"
  register=true
elif statusline=$(resolve_script "$configured"); then
  : # rastas esamas scenarijus, prie jo ir kabinsimės
elif create_target=$(single_path "$configured"); then
  echo "Nustatymuose nurodytas scenarijus dar nesukurtas, sukuriamas: $create_target"
else
  echo "Klaida: nustatymuose nurodyta būsenos juostos komanda, bet jos scenarijaus rasti nepavyko:"
  echo "  $configured"
  echo
  echo "Nieko nekeičiu, kad nesugadinčiau tavo nustatymų. Prikabink tiltą ranka:"
  echo "savo scenarijuje, iškart po eilutės, kurioje nuskaitomi duomenys iš Claude Code, įrašyk"
  echo
  echo "  $marker_start"
  echo "  printf '%s' \"\$input\" | \"\$HOME/Library/Application Support/POM/pom-bridge.sh\" >/dev/null 2>&1 &"
  echo "  $marker_end"
  exit 1
fi

if [ -n "$create_target" ]; then
  statusline="$create_target"
  echo "Statusline dar nėra, sukuriamas: $statusline"
  mkdir -p "$(dirname "$statusline")"

  cat >"$statusline" <<'STATUSLINE'
#!/bin/bash
# Statusline Claude Code juostai. Sukūrė POM (Ponas Obuolys Metrika).
# Rodo modelį, katalogą, konteksto užpildymą ir plano limitus.
export LC_ALL=C

input=$(cat)

{
  IFS= read -r model
  IFS= read -r dir
  IFS= read -r context
  IFS= read -r five
  IFS= read -r seven
} < <(
  echo "$input" | jq -r '[
    (.model.display_name // "Claude"),
    (.workspace.current_dir // "."),
    ((.context_window.used_percentage // "") | tostring),
    ((.rate_limits.five_hour.used_percentage // "") | tostring),
    ((.rate_limits.seven_day.used_percentage // "") | tostring)
  ] | .[]'
)

color() {
  if [ "$1" -lt 70 ]; then printf '\033[32m'
  elif [ "$1" -lt 90 ]; then printf '\033[33m'
  else printf '\033[31m'
  fi
}

line="\033[36m[$model]\033[0m 📁 $(basename "$dir")"

if [ -n "$context" ]; then
  used=$(printf "%.0f" "$context")
  line+=" | $(color "$used")${used}%\033[0m konteksto"
fi

limits=""
if [ -n "$five" ]; then
  v=$(printf "%.0f" "$five")
  limits+="5h $(color "$v")${v}%\033[0m"
fi
if [ -n "$seven" ]; then
  v=$(printf "%.0f" "$seven")
  [ -n "$limits" ] && limits+=" · "
  limits+="7d $(color "$v")${v}%\033[0m"
fi
[ -n "$limits" ] && line+=" | ⏳ $limits"

printf "%b" "$line"
STATUSLINE

  chmod +x "$statusline"

  # Užregistruojama Claude Code nustatymuose, prieš tai pasidarius kopiją.
  if $register; then
    mkdir -p "$HOME/.claude"
    if [ -f "$settings" ]; then
      cp "$settings" "$settings.bak-$(date +%Y%m%d%H%M%S)"
      tmp_settings=$(mktemp)
      jq '.statusLine = {"type":"command","command":"~/.claude/statusline.sh","refreshInterval":30}' \
        "$settings" >"$tmp_settings" && mv "$tmp_settings" "$settings"
    else
      printf '%s\n' '{"statusLine":{"type":"command","command":"~/.claude/statusline.sh","refreshInterval":30}}' >"$settings"
    fi
    echo "Užregistruota Claude Code nustatymuose."
  fi
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
