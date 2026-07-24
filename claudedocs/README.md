# POM (Ponas Obuolys Metrika)

Claude 5 valandų ir 7 dienų limitai macOS meniu juostoje, prie laikrodžio.

Prie laikrodžio matyti dvi juostelės: viršutinė – 5 valandų limitas, apatinė – 7 dienų.
Paspaudus atsidaro langelis su tiksliais skaičiais, likučiu ir laiku iki atsistatymo.
Priartėjus prie ribos ateina pranešimas.

## Įdiegimas

```bash
./scripts/create-signing-cert.sh   # vieną kartą: pastovus savadarbis parašas
./scripts/install-bridge.sh        # prijungia duomenų šaltinį prie Claude Code
./scripts/bundle.sh                # surenka POM.app
./scripts/install.sh               # įdiegia į /Applications ir paleidžia
```

Xcode nereikia, užtenka komandinės eilutės įrankių (`xcode-select --install`).

Pirmas žingsnis nebūtinas, bet naudingas: laikinas (ad-hoc) parašas keičiasi po kiekvieno
perkompiliavimo, todėl macOS kaskart mato tarsi kitą programą ir raktinės leidimo
„Visada leisti“ neįsimena. Pastovus savadarbis parašas tą išsprendžia.

Neprivalomas žingsnis, jei nori atsarginio serverio kelio:

```bash
claude setup-token        # gauni raktą
./scripts/set-token.sh    # įklijuoji; scenarijus iškart patikrina, ar serveris jį priima
```

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

Raktas ieškomas dviejose vietose, tokia tvarka:

1. **POM savas įrašas** `POM-claude-token` – jį užpildo `./scripts/set-token.sh`.
2. **Claude Code įrašas** `Claude Code-credentials`, laukas `claudeAiOauth.accessToken`.

Antrasis kelias veikia ne visur: kai kuriuose kompiuteriuose tame įraše guli tik MCP
serverių raktai (Notion, Linear, Vercel), o Claude prenumeratos rakto nėra. Todėl POM
ima **tik tiksliai nurodytą lauką** ir niekada neieško „bet kokio rakto“: svetimo
paslaugos rakto išsiuntimas Anthropic serveriui būtų rimta klaida.

Raktas skaitomas per sisteminę komandą `/usr/bin/security` ir tik skaitomas, niekada
nekeičiamas. Nė vieno rakto neradus, langelyje apie tai pranešama, o skaičiai toliau
imami iš Claude Code. Programa dėl to neveikia blogiau.

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
./scripts/set-token.sh --remove        # pašalina raktą iš raktinės
rm -rf /Applications/POM.app
rm -f ~/Library/LaunchAgents/lt.ponasobuolys.pom.plist
rm -rf ~/Library/Application\ Support/POM
security delete-certificate -c "POM Self-Signed"   # jei nebereikia parašo
```

`install-bridge.sh` prieš keisdamas visada pasidaro `statusline.sh.bak-<data>` kopiją.

## Žinomi apribojimai

- **Pranešimus perduoda macOS scenarijų įrankis.** Registruotis pranešimų sistemoje gali
  tik Apple išduotu kūrėjo parašu pasirašytos programos. Patikrinta trimis būdais –
  laikinas (ad-hoc) parašas, pastovus savadarbis parašas ir savadarbis parašas, pažymėtas
  kaip patikimas kodo pasirašymui: visais atvejais atsakoma „Notifications are not allowed
  for this application“. Todėl POM pirma bando įprastą kelią, o nepavykus siunčia pranešimą
  per sisteminį `osascript`. Pranešimas ateina normaliai ir antraštėje nurodo POM, tik
  ikona lieka scenarijų įrankio. Turint Apple kūrėjo parašą programa pati pereitų
  prie įprasto kelio, kodo keisti nereikėtų.
- **Widget'ų nėra.** Jiems reikia Xcode ir kūrėjo parašo, o atsinaujintų jie retai.
- **Serverio adresas neoficialus.** Gali nustoti veikti bet kada; POM be jo veikia normaliai.
- **Duomenys atsiranda tik po pirmo Claude Code atsakymo.** Iki tol rodoma „Duomenų dar nėra“.
