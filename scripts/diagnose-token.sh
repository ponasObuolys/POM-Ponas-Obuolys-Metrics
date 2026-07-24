#!/bin/bash
# Išbando kelis užklausos variantus ir parodo, kaip į juos atsako Anthropic serveris.
#
# Reikalinga tada, kai `set-token.sh` gauna HTTP 403: raktas atpažįstamas, bet užklausa
# atmetama. Priežastis gali būti antraštės arba rakto teisės, o serverio atsakymas
# dažniausiai tai pasako tiesiai.
#
# Raktas niekur nerodomas ir neįrašomas. Rodomi tik atsakymo kodai ir tekstai.

set -uo pipefail

if [ -t 0 ]; then
  printf "Raktas (nebus rodomas): "
  read -r -s token
  echo
else
  read -r token || true
fi
token=$(printf '%s' "$token" | tr -d '[:space:]')

if [ -z "$token" ]; then
  echo "Rakto negauta."
  exit 1
fi

echo "Rakto pradžia: ${token:0:12}… (ilgis ${#token})"
echo

probe() {
  local label="$1"
  local url="$2"
  shift 2

  local body status
  body=$(mktemp)
  status=$(curl -sS -o "$body" -w '%{http_code}' --max-time 20 "$@" "$url" 2>/dev/null) || status="000"

  echo "── $label"
  echo "   HTTP $status"
  if [ -s "$body" ]; then
    # Atsakyme rakto nebūna, tad rodyti saugu.
    head -c 400 "$body" | tr -d '\n' | sed 's/^/   /'
    echo
  fi
  echo
  rm -f "$body"
}

AUTH="Authorization: Bearer $token"
UA="User-Agent: claude-cli/2.0.0 (external, cli)"

probe "1. Bearer + beta oauth-2025-04-20" \
  "https://api.anthropic.com/api/oauth/usage" \
  -H "$AUTH" -H "anthropic-beta: oauth-2025-04-20" -H "Accept: application/json" -H "$UA"

probe "2. Tas pats + anthropic-version" \
  "https://api.anthropic.com/api/oauth/usage" \
  -H "$AUTH" -H "anthropic-beta: oauth-2025-04-20" -H "anthropic-version: 2023-06-01" \
  -H "Accept: application/json" -H "$UA"

probe "3. Bearer be beta antraštės" \
  "https://api.anthropic.com/api/oauth/usage" \
  -H "$AUTH" -H "Accept: application/json" -H "$UA"

probe "4. x-api-key vietoj Bearer" \
  "https://api.anthropic.com/api/oauth/usage" \
  -H "x-api-key: $token" -H "anthropic-version: 2023-06-01" -H "Accept: application/json" -H "$UA"

probe "5. Profilio adresas (ar raktas apskritai veikia)" \
  "https://api.anthropic.com/api/oauth/profile" \
  -H "$AUTH" -H "anthropic-beta: oauth-2025-04-20" -H "Accept: application/json" -H "$UA"

probe "6. Įprastas API adresas (ar raktas tinka pokalbiams)" \
  "https://api.anthropic.com/v1/models?limit=1" \
  -H "$AUTH" -H "anthropic-version: 2023-06-01" -H "Accept: application/json" -H "$UA"

echo "Baigta. Raktas niekur neįrašytas."
