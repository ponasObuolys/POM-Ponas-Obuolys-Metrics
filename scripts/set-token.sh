#!/bin/bash
# Įrašo Claude prisijungimo raktą į POM raktinės įrašą ir iškart patikrina,
# ar Anthropic serveris jį priima.
#
# Kam to reikia. POM skaičius ima iš Claude Code ir be šito veikia visiškai normaliai.
# Raktas praverčia tik atsarginiam keliui: kai Claude Code ilgai neįjungtas, POM gali
# pati paklausti serverio, kokie limitai dabar.
#
# Kur gauti raktą: paleisk `claude setup-token` ir nukopijuok gautą reikšmę.
#
# Raktas lieka tik tavo raktinėje. Ekrane jis nerodomas, saugykloje neatsiduria.

set -euo pipefail

SERVICE="POM-claude-token"
ENDPOINT="https://api.anthropic.com/api/oauth/usage"

if [ "${1:-}" = "--remove" ]; then
  security delete-generic-password -s "$SERVICE" >/dev/null 2>&1 &&
    echo "Raktas pašalintas." || echo "Rakto nebuvo."
  exit 0
fi

echo "POM: Claude prisijungimo raktas"
echo

if [ -t 0 ]; then
  echo "Raktą gausi paleidęs: claude setup-token"
  echo "Įklijuok jį žemiau (ekrane nebus matomas) ir spausk Enter."
  echo
  printf "Raktas: "
  read -r -s token
  echo
else
  # Paleista be tikro terminalo (pvz., iš kito įrankio). Klaviatūros laukti nėra prasmės,
  # todėl raktas imamas iš įvesties srauto: echo "raktas" | ./scripts/set-token.sh
  if ! read -r token; then
    echo "Nėra terminalo, o įvesties srautu raktas neperduotas."
    echo
    echo "Paleisk šį scenarijų įprastame Terminalo lange arba perduok raktą taip:"
    echo "  echo \"tavo-raktas\" | ./scripts/set-token.sh"
    exit 1
  fi
fi

token=$(printf '%s' "$token" | tr -d '[:space:]')

if [ -z "$token" ]; then
  echo "Nieko neįvesta, nieko ir nedarau."
  exit 1
fi

# Dažna klaida: iškarpinėje lieka ne raktas, o paskutinė nukopijuota komanda.
case "$token" in
  sk-ant-*) ;;
  *)
    echo "Tai nepanašu į raktą: pradžia „${token:0:12}…“, ilgis ${#token}."
    echo "Tikras raktas prasideda „sk-ant-“. Nieko neįrašiau."
    exit 1
    ;;
esac

echo "Tikrinama, ar serveris raktą priima..."
body=$(mktemp)
trap 'rm -f "$body"' EXIT

status=$(curl -sS -o "$body" -w '%{http_code}' --max-time 20 \
  -H "Authorization: Bearer $token" \
  -H "anthropic-beta: oauth-2025-04-20" \
  -H "Accept: application/json" \
  -H "User-Agent: claude-code/1.0 (external, cli)" \
  "$ENDPOINT" 2>/dev/null) || status="000"

store_it=0
case "$status" in
  200)
    echo "Serveris atsakė teigiamai."
    echo "Atsakymo laukai:"
    jq -r 'paths(scalars) | join(".")' "$body" 2>/dev/null | head -12 ||
      echo "  (atsakymas ne JSON)"
    store_it=1
    ;;
  429)
    echo "Serveris šiuo metu riboja užklausas (HTTP 429)."
    echo "Tai nereiškia, kad raktas blogas, tad jis bus išsaugotas."
    store_it=1
    ;;
  401 | 403)
    echo "Serveris rakto nepriėmė (HTTP $status). Raktas neišsaugotas."
    echo 'Patikrink, ar nukopijavai visą "claude setup-token" išvestį.'
    ;;
  000)
    echo "Nepavyko susisiekti su serveriu. Raktas neišsaugotas."
    ;;
  *)
    echo "Serveris atsakė HTTP $status. Raktas neišsaugotas."
    ;;
esac

if [ "$store_it" -ne 1 ]; then
  exit 1
fi

# -U perrašo esamą įrašą, -T leidžia POM jį perskaityti per sisteminę komandą.
security add-generic-password -U \
  -s "$SERVICE" -a "$USER" -w "$token" \
  -T /usr/bin/security \
  -j "Claude prisijungimo raktas, kurį naudoja POM (Ponas Obuolys Metrika)"

echo
echo "Raktas išsaugotas raktinėje ($SERVICE)."
echo "Pašalinti galima taip: ./scripts/set-token.sh --remove"
