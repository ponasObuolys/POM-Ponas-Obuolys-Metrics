#!/bin/bash
# POM (Ponas Obuolys Metrika) tiltas.
#
# Gauna per stdin tą patį JSON, kurį Claude Code paduoda statusline scenarijui,
# ir išsaugo limitų reikšmes ten, kur jas skaito meniu juostos programa.
# Paleidžiamas fone, todėl statusline greičio nestabdo.

export LC_ALL=C

pom_home="${POM_HOME:-$HOME}"
target_dir="$pom_home/Library/Application Support/POM"
target="$target_dir/snapshot.json"

input=$(cat)
[ -n "$input" ] || exit 0
command -v jq >/dev/null 2>&1 || exit 0

# Failą sudeda pats jq, o ne printf. Taip kabutės atsiranda ten, kur reikia, ir failas
# lieka taisyklingas net tada, kai atsistatymo laikas ateina ne skaičiumi, o tekstu.
#
# Be limitų reikšmių nerašoma nieko, kad nedingtų paskutinė gera reikšmė. Taip būna
# prieš pirmą atsakymą arba dirbant su API raktu.
snapshot=$(printf '%s' "$input" | jq -c '
  def window($w):
    if ($w | type) != "object" then null
    elif ($w.used_percentage // $w.utilization // $w.percent) == null then null
    else {used_percentage: ($w.used_percentage // $w.utilization // $w.percent)}
      + (if $w.resets_at == null then {} else {resets_at: $w.resets_at} end)
    end;
  (.rate_limits // {}) as $r
  | window($r.five_hour) as $five
  | window($r.seven_day) as $seven
  | window($r.seven_day_fable // $r.seven_day_overage_included //
      ([$r.model_scoped[]? | select(.display_name | ascii_downcase | test("^fable( |$)"))][0]) //
      ([$r.limits[]? | select(.kind == "weekly_scoped") |
        select(.scope.model.display_name | ascii_downcase | test("^fable( |$)"))][0])) as $fable
  | if $five == null or $seven == null then empty
    else {
      schema: 1,
      source: "statusline",
      captured_at: (now | floor),
      five_hour: $five,
      seven_day: $seven
    } + (if $fable == null then {} else {seven_day_fable: $fable} end)
      + (if .subscription_type == null then {} else {plan: .subscription_type} end)
    end
' 2>/dev/null) || exit 0

[ -n "$snapshot" ] || exit 0

mkdir -p "$target_dir" 2>/dev/null || exit 0

# Atominis įrašymas: pirma laikinas failas, tada pervadinimas. Taip programa
# niekada neperskaito pusiau įrašyto failo, net kai rašo kelios sesijos vienu metu.
tmp="$target.$$.tmp"
if printf '%s\n' "$snapshot" >"$tmp" 2>/dev/null; then
  mv -f "$tmp" "$target" 2>/dev/null
fi
rm -f "$tmp" 2>/dev/null

exit 0
