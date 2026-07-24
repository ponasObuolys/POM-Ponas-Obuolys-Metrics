# POM (Ponas Obuolys Metrika)

Claude 5 valandų ir 7 dienų limitai macOS meniu juostoje, prie laikrodžio.

Prie laikrodžio matyti dvi juostelės: viršutinė – 5 valandų limitas, apatinė – 7 dienų.
Paspaudus atsidaro langelis su tiksliais skaičiais, likučiu ir laiku iki atsistatymo.
Priartėjus prie ribos ateina pranešimas.

## Įdiegimas

```bash
./scripts/install-bridge.sh    # prijungia duomenų šaltinį prie Claude Code
./scripts/bundle.sh            # surenka POM.app
./scripts/install.sh           # įdiegia į /Applications ir paleidžia
```

Xcode nereikia, užtenka komandinės eilutės įrankių (`xcode-select --install`).

Jei ikonos prie laikrodžio nematyti, kalta gali būti meniu juostos tvarkyklė
(**Ice**, Bartender ar panaši): naujus elementus jos paslepia. Ice nustatymuose
POM reikia perkelti į matomą dalį arba, laikant nuspaudus `⌘`, ikoną nutempti į kairę.

## Iš kur imami skaičiai

**Pagrindinis kelias.** Claude Code kas 30 sekundžių paduoda savo statusline scenarijui
JSON su limitų reikšmėmis. `install-bridge.sh` prie to scenarijaus prikabina vieną eilutę,
kuri tas reikšmes nurašo į failą:

```
~/Library/Application Support/POM/snapshot.json
```

Rašoma atomiškai (pirma laikinas failas, tada pervadinimas), tad kelios vienu metu
veikiančios Claude Code sesijos viena kitai netrukdo. Jei sesija limitų duomenų neturi,
nerašoma nieko, kad nedingtų paskutinė gera reikšmė.

**Kodėl seni duomenys vis tiek teisingi.** Limitas auga tik dirbant su Claude. Uždarius
Claude Code skaičius nebedidėja. Kartu su procentais saugomas ir atsistatymo laikas
(`resets_at`), tad praėjus tam momentui POM parodo „limitas atsistatė“, o ne pasenusį skaičių.

**Atsarginis kelias.** Kai vietiniai duomenys senesni nei 30 minučių, POM gali paklausti
Anthropic serverio (`/api/oauth/usage`). Kreipiamasi retai, nes serveris užklausas riboja
griežtai: po klaidos pauzė didinama 30 min. → 1 val. → 2 val. Mygtukas „Atnaujinti“ veikia
ne dažniau kaip kartą per 5 minutes.

Raktas skaitomas per sisteminę komandą `/usr/bin/security` ir tik skaitomas, niekada
nekeičiamas. Imamas tiksliai `claudeAiOauth.accessToken` – tame pačiame raktinės įraše
guli ir MCP serverių raktai (Notion, Linear, Vercel), kurių siųsti Anthropic serveriui negalima.

Jei raktinėje Claude prenumeratos rakto nėra, langelyje apie tai pranešama, o skaičiai
toliau imami iš Claude Code. Programa dėl to neveikia blogiau.

## Nustatymai

Krumpliaračio mygtukas langelio apačioje:

| Nustatymas | Ką daro |
|---|---|
| Ikonoje rodyti, kiek liko | Vietoj sunaudotos dalies rodomas likutis; juostelė ima veikti kaip degalų matuoklis |
| Perspėti apie besibaigiantį limitą | Pranešimai kertant ribas |
| Perspėti (anksti / įprastai / vėlai) | 70 % ir 90 %, 80 % ir 95 % arba 90 % ir 98 % |
| Klausti serverio, kai duomenys pasenę | Atsarginis kelias |
| Paleisti prisijungus prie kompiuterio | Aprašas `~/Library/LaunchAgents/lt.ponasobuolys.pom.plist`, įsigalioja kitą kartą prisijungus |

Spalvos: žalia iki 70 %, geltona iki 90 %, raudona nuo 90 %.

## Patikra

```bash
swift run pom-tests      # 87 patikros
swift build -c release   # be įspėjimų
```

XCTest su komandinės eilutės įrankiais neprieinamas (jis ateina tik su Xcode), todėl
testai parašyti kaip paleidžiama programa. Radus klaidą ji grąžina ne nulį.

## Pašalinimas

```bash
./scripts/uninstall-bridge.sh          # atkabina nuo statusline
rm -rf /Applications/POM.app
rm -f ~/Library/LaunchAgents/lt.ponasobuolys.pom.plist
rm -rf ~/Library/Application\ Support/POM
```

`install-bridge.sh` prieš keisdamas visada pasidaro `statusline.sh.bak-<data>` kopiją.

## Žinomi apribojimai

- **Pranešimus rodo macOS scenarijų įrankis.** Savo kompiuteryje surinkta ir vietiniu
  parašu pasirašyta programa pranešimų sistemoje neužsiregistruoja: užklausa priimama,
  bet niekas nerodoma. Todėl POM pirma bando įprastą kelią, o nepavykus siunčia pranešimą
  per sisteminį `osascript`. Pranešimas ateina, tik siuntėju nurodytas scenarijų įrankis.
  Turint Apple kūrėjo parašą programa automatiškai pereitų prie įprasto kelio.
- **Widget'ų nėra.** Jiems reikia Xcode ir kūrėjo parašo, o atsinaujintų jie retai.
- **Serverio adresas neoficialus.** Gali nustoti veikti bet kada; POM be jo veikia normaliai.
- **Duomenys atsiranda tik po pirmo Claude Code atsakymo.** Iki tol rodoma „Duomenų dar nėra“.
