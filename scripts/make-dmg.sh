#!/bin/bash
# Supakuoja POM.app į DMG atvaizdą, kurį galima persiųsti kolegoms.
#
# DMG viduje: pati programa, nuoroda į /Applications ir trumpas paaiškinimas.
# Programa pasirašyta savo parašu, todėl svetimame kompiuteryje macOS pirmą kartą
# ją užblokuos. Kaip tai apeiti, parašyta pridedamame paaiškinime.

set -euo pipefail

root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
app_name="POM"
version="1.0.0"

dist="$root/dist"
app="$dist/$app_name.app"
staging="$dist/dmg-staging"
dmg="$dist/$app_name-$version.dmg"

if [ ! -d "$app" ]; then
  echo "Nerastas $app. Pirma paleisk: ./scripts/bundle.sh"
  exit 1
fi

echo "1/3 Ruošiamas turinys"
rm -rf "$staging" "$dmg"
mkdir -p "$staging"
cp -R "$app" "$staging/$app_name.app"
ln -s /Applications "$staging/Applications"

cat >"$staging/Skaityk mane.txt" <<'READ'
POM (Ponas Obuolys Metrika)
Claude 5 valandų ir 7 dienų limitai macOS meniu juostoje.


KAIP ĮDIEGTI

1. Nutempk POM į Applications aplanką (šalia yra jo nuoroda).

2. Pirmą kartą paleisk taip: Applications aplanke spustelk POM
   DEŠINIU pelės mygtuku ir pasirink „Open“, tada patvirtink.

   Jei macOS vis tiek neleidžia, atsidaryk
   System Settings → Privacy & Security, nuslink žemyn ir prie
   pranešimo apie POM spausk „Open Anyway“.

   Taip yra todėl, kad programa nėra pirkta per Apple kūrėjo
   paskyrą. Vienas patvirtinimas, ir daugiau to nebeprašys.

3. Prie laikrodžio atsiras dvi juostelės. Paspausk jas ir
   spausk „Prijungti“ – POM prisikabins prie Claude Code
   būsenos juostos. Senoji juosta išsaugoma atsargai.

4. Padirbėk su Claude Code. Per pusę minutės pasirodys skaičiai.


KAIP SKAITYTI

Viršutinė juostelė – 5 valandų limitas.
Apatinė juostelė – 7 dienų limitas.

Žalia iki 70 %, geltona iki 90 %, raudona nuo 90 %.

Paspaudus ikoną matyti tikslūs skaičiai, kiek liko ir po kiek
laiko limitas atsistato.


NEMATAI IKONOS?

Jei naudoji meniu juostos tvarkyklę (Ice, Bartender ar panašią),
ji naujus elementus paslepia. Susirask POM jos nustatymuose arba,
laikydamas Cmd, nutempk ikoną į matomą vietą.


NUSTATYMAI

Krumpliaračio mygtukas apatiniame dešiniame kampe:
rodyti likutį vietoj sunaudotos dalies, perspėjimai, paleidimas
prisijungus prie kompiuterio.


KAIP PAŠALINTI

Ištrink POM iš Applications. Būsenos juostą grąžinti į pradinę
būklę galima jos atsargine kopija: ~/.claude/statusline.sh.bak-*
READ

echo "2/3 Kuriamas atvaizdas"
hdiutil create \
  -volname "$app_name $version" \
  -srcfolder "$staging" \
  -ov -format UDZO \
  "$dmg" >/dev/null

rm -rf "$staging"

echo "3/3 Pasirašoma"
identity="POM Self-Signed"
if security find-identity -p codesigning 2>/dev/null | grep -q "$identity"; then
  codesign --force --sign "$identity" "$dmg"
else
  codesign --force --sign - "$dmg"
fi

size=$(du -h "$dmg" | cut -f1)
echo
echo "Paruošta: $dmg ($size)"
echo
echo "Kolegos pirmą kartą turės paleisti dešiniu pelės mygtuku → Open,"
echo "nes programa nėra pasirašyta pirkta Apple kūrėjo paskyra."
