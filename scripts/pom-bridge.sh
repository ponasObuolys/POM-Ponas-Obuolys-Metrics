#!/bin/bash
# POM (Ponas Obuolys Metrika) tiltas.
#
# Gauna per stdin tą patį JSON, kurį Claude Code paduoda statusline scenarijui,
# ir išsaugo limitų reikšmes ten, kur jas skaito meniu juostos programa.
# Paleidžiamas fone, todėl statusline greičio nestabdo.

export LC_ALL=C

target_dir="$HOME/Library/Application Support/POM"
target="$target_dir/snapshot.json"

input=$(cat)
[ -n "$input" ] || exit 0
command -v jq >/dev/null 2>&1 || exit 0

# Trūkstamos reikšmės pažymimos brūkšneliu, kad @tsv negrąžintų tuščių stulpelių.
fields=$(printf '%s' "$input" | jq -r '[
  (.rate_limits.five_hour.used_percentage // "-"),
  (.rate_limits.five_hour.resets_at // "-"),
  (.rate_limits.seven_day.used_percentage // "-"),
  (.rate_limits.seven_day.resets_at // "-")
] | @tsv' 2>/dev/null) || exit 0

IFS=$'\t' read -r five_used five_reset seven_used seven_reset <<< "$fields"

# Be limitų duomenų nerašoma nieko, kad nedingtų paskutinė gera reikšmė.
# Taip būna prieš pirmą atsakymą iš serverio arba naudojantis API raktu.
if [ -z "$five_used" ] || [ "$five_used" = "-" ] \
  || [ -z "$seven_used" ] || [ "$seven_used" = "-" ]; then
  exit 0
fi

five_reset_json=""
if [ -n "$five_reset" ] && [ "$five_reset" != "-" ]; then
  five_reset_json=",\"resets_at\":$five_reset"
fi

seven_reset_json=""
if [ -n "$seven_reset" ] && [ "$seven_reset" != "-" ]; then
  seven_reset_json=",\"resets_at\":$seven_reset"
fi

mkdir -p "$target_dir" 2>/dev/null || exit 0

# Atominis įrašymas: pirma laikinas failas, tada pervadinimas. Taip programa
# niekada neperskaito pusiau įrašyto failo, net kai rašo kelios sesijos vienu metu.
tmp="$target.$$.tmp"
if printf '{"schema":1,"source":"statusline","captured_at":%s,"five_hour":{"used_percentage":%s%s},"seven_day":{"used_percentage":%s%s}}\n' \
  "$(date +%s)" \
  "$five_used" "$five_reset_json" \
  "$seven_used" "$seven_reset_json" >"$tmp" 2>/dev/null; then
  mv -f "$tmp" "$target" 2>/dev/null
fi
rm -f "$tmp" 2>/dev/null

exit 0
