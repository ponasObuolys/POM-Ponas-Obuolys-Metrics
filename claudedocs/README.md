# POM (Ponas Obuolys Metrika)

Claude ir Codex limitai macOS meniu juostoje, prie laikrodžio.

Prie laikrodžio matyti vieno įrankio skaičiai: Claude žymi Anthropic logotipas,
Codex – ChatGPT logotipas, o Fable – `F`. Claude rodo dvi juosteles (5 valandų ir 7 dienų limitus),
Fable ir Codex – po vieną (savaitės). Kuris įrankis rodomas, pasirenkama nustatymuose.
Vienspalviai SVG yra programos pakete ir prisitaiko prie meniu juostos fono.

Paspaudus atsidaro langelis su abiejų įrankių skaičiais, likučiu ir laiku iki atsistatymo.
Priartėjus prie ribos ateina pranešimas.

## Dalinimasis su kitais

```bash
./scripts/bundle.sh && ./scripts/make-dmg.sh
```

Gaunamas `dist/POM-<versija>.dmg`: programa, nuoroda į `/Applications` ir paaiškinimas.
Versija abiem scenarijams imama iš failo `VERSION`, tad programos viduje ir failo
pavadinime ji visada sutampa.

Gavėjui terminalo nereikia. Įsidėjęs programą į `/Applications`, jis paspaudžia ikoną
prie laikrodžio ir mygtuką **„Prijungti“** – POM pati prisikabina prie Claude Code
būsenos juostos, o jos neradusi susikuria naują ir užregistruoja Claude Code
nustatymuose. Tilto scenarijai keliauja programos pakete (`Contents/Resources`).

Vienas nepatogumas lieka: programa pasirašyta savadarbiu parašu, todėl pirmą kartą
macOS ją užblokuos. Reikia paleisti dešiniu pelės mygtuku → **Open**, o jei ir tada
neleidžia – **System Settings → Privacy & Security → Open Anyway**. Tai vienkartinis
veiksmas. Išvengti jo galima tik su pirkta Apple kūrėjo paskyra ir notarizacija.

## Įdiegimas iš kodo

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

Claude bei Fable duomenis POM gauna per vietinę Claude Code komandą.
Neprisijungus prie paskyros, terminale paleidžiama `claude auth login`.

Jei ikonos prie laikrodžio nematyti, kalta gali būti meniu juostos tvarkyklė
(**Ice**, Bartender ar panaši): naujus elementus jos paslepia. Ice nustatymuose
POM reikia perkelti į matomą dalį arba, laikant nuspaudus `⌘`, ikoną nutempti į kairę.

## Iš kur imami Claude ir Fable skaičiai

**Pagrindinis šaltinis:** trumpas vietinės Claude Code komandos procesas. POM siunčia
`initialize`, tada `get_usage` valdymo užklausą (patikrinta su Claude Code 2.1.263). Pokalbio žinutė modeliui nesiunčiama;
įrankiai, papildiniai, projekto nustatymai ir pokalbio išsaugojimas išjungti.
Claude Code pati tvarko prisijungimą ir rakto atnaujinimą. Tikrinama kas 5 minutes,
rankiniu būdu ne dažniau nei kas 30 sekundžių. Po klaidos pauzė ilgėja nuo 2 iki 30 minučių.
Procesui skirtos 25 sekundės; nereaguojantis procesas priverstinai uždaromas.

`five_hour` ir `seven_day` aprašo bendrus limitus. Fable ateina atskirai: `limits`
masyve kaip `weekly_scoped` su `scope.model.display_name: "Fable"`, arba
`model_scoped` masyve. Priimami ir `seven_day_fable` bei ankstesnis
`seven_day_overage_included` formatas. Fable nėra painiojamas su Opus ar bendru limitu.
Trūkstamas Fable skaičius nelaikomas nuliu.

Paskutinis atsakymas saugomas:

```
~/Library/Application Support/POM/claude-snapshot.json
```

**Papildomas vietinis šaltinis:** Claude Code būsenos juosta. `install-bridge.sh`
prie jos scenarijaus prideda duomenų perdavimą į `snapshot.json`. Tilto failui sudaryti
reikia `jq`. Jei būsimos Claude Code versijos būsenos juostoje pateiks Fable duomenis,
POM tiltas juos irgi perduos. Šviežesni bendri duomenys nepanaikina atskiro Fable skaičiaus;
jiems saugomi atskiri gavimo laikai.

Prijungimas atpažįsta scenarijų su tarpais kelyje, kabutėmis ir aiškiai nurodyta vykdykle,
pavyzdžiui, `/bin/bash "/Users/vardas/.claude/mano juosta.sh"`. Komandos tekstas niekada nevykdomas
kelio paieškai. Sudėtinės ir neatpažintos komandos paliekamos naudotojui.
Prieš pakeičiant scenarijų sukuriama atsarginė kopija. Nutrūkus tiltui, mygtukas
„Prijungti“ rodomas ir tada, kai išlikę ankstesni skaičiai.

**Pasirenkamas atsarginis šaltinis:** tiesioginis Anthropic `/api/oauth/usage` adresas.
Jis iš pradžių išjungtas. Užklausos ribojamos, o po HTTP 401 ar HTTP 403 klaidos
nebekartojamos iki kito POM paleidimo. Šio kelio Fable rodymui įjungti nereikia.
POM savas raktinės įrašas turi pirmenybę; Claude Code įrašas parenkamas pagal
paslaugą ir macOS naudotojo vardą, kad nebūtų paimtas kitos paskyros įrašas.

## Planų pavadinimai

Claude bendras plano tipas gaunamas iš `get_usage`, o tikslus Max daugiklis iš vietinio
`.claude.json` paskyros aprašo (`userRateLimitTier` arba `organizationRateLimitTier`).
Skaitomi plano laukai, ne pokalbių turinys. Max 5x ir Max 20x atskiriami pagal aiškią
reikšmę; nežinant daugiklio rodoma tik „Max“.

Codex `planType` išsaugomas kartu su limitu. `prolite` rodomas kaip „ChatGPT Pro 5x“,
`pro` kaip „ChatGPT Pro 20x“. Tai paskyros planas; laikinos papildomo vartojimo akcijos
iš šio kodo nenustatomos. Nežinomas plano kodas nėra pakeičiamas spėjimu.

## Iš kur imami Codex skaičiai

Codex CLI turi vietinį JSON-RPC režimą `codex app-server`. POM trumpam jį paleidžia,
pasisveikina (`initialize`), paklausia `account/rateLimits/read` ir uždaro. Visas ciklas
trunka apie sekundę, tad nuolat veikiančio proceso laikyti nereikia.

Prisijungimu rūpinasi pats Codex, todėl POM nereikia nei rakto iš raktinės, nei tinklo
užklausų, nei `jq`. Klausiama kas 5 minutes, po nesėkmės pauzė didinama 2 min. → 4 min. →
… iki 30 min. Mygtukas „Atnaujinti“ veikia ne dažniau kaip kartą per pusę minutės.

Rodomas ilgiausias pagrindinio rinkinio langas, praktiškai savaitės. Pirmenybė teikiama
`rateLimitsByLimitId.codex`; senesniems atsakymams naudojamas `rateLimits`. Papildomi
modelių rinkiniai (pavyzdžiui, GPT-5.3-Codex-Spark) praleidžiami: jie
atsiranda ir dingsta priklausomai nuo naudoto modelio, tad skaičius meniu juostoje šokinėtų
be jokios vartotojui matomos priežasties.

Paskutinė reikšmė saugoma faile:

```
~/Library/Application Support/POM/codex-snapshot.json
```

**Įvestis lieka atvira, kol gaunamas atsakymas.** Tai ne smulkmena: pamatęs įvesties pabaigą
Codex pokalbį užbaigia ir nespėja nieko atsakyti. Kol taip buvo, POM gaudavo tuščią atsakymą.

**Kaip randamas Codex.** Meniu juostos programa nepaveldi terminalo `PATH`, todėl `codex`
ieškoma fiksuotuose keliuose (`/opt/homebrew/bin`, `/usr/local/bin`, `~/.local/bin`,
`~/.bun/bin`, `~/.volta/bin`), o procesui paduodamas `PATH` su Homebrew katalogais: npm
įdiegtas `codex` yra Node scenarijus, kuris be to nepasileistų.

**Kaip atpažįstama, ar prisijungta.** Tikrinamas `~/.codex/auth.json`: jame turi būti
netuščias `tokens.access_token` arba `OPENAI_API_KEY`. Taip išvengiama proceso paleidimo
vien tam, kad sužinotume, jog atsakymo nebus. Tuščia reikšmė prilyginama neprisijungimui:
toks failas lieka po `codex logout`.

Nesant Codex sekcija langelyje nerodoma visai. Yra jis, bet neprisijungęs – rodomas
paaiškinimas su komanda `codex login`.

## Nustatymai

Krumpliaračio mygtukas langelio apačioje:

| Nustatymas | Ką daro |
|---|---|
| Ikonoje rodyti (Claude / Fable / Codex) | Kurio įrankio skaičiai matomi prie laikrodžio; rodomas, kai prieinamas Codex arba Fable |
| Ikonoje rodyti, kiek liko | Vietoj sunaudotos dalies rodomas likutis; juostelė ima veikti kaip degalų matuoklis |
| Perspėti apie besibaigiantį limitą | Pranešimai kertant ribas |
| Perspėti (anksti / įprastai / vėlai) | 70 % ir 90 %, 80 % ir 95 % arba 90 % ir 98 % |
| Klausti serverio, kai duomenys pasenę | Atsarginis kelias |
| Paleisti prisijungus prie kompiuterio | Aprašas `~/Library/LaunchAgents/lt.ponasobuolys.pom.plist`, įsigalioja kitą kartą prisijungus |

Spalvos: žalia iki 70 %, geltona iki 90 %, raudona nuo 90 %.

## Patikra

```bash
python3 tests/bridge_tests.py  # tikras tilto diegimas ir pašalinimas laikinuose kataloguose
swift run pom-tests      # POMCore patikros, skaičių parodo pati paleidyklė
swift build -c release   # be įspėjimų
bash scripts/check-ui.sh  # tikri SwiftUI vaizdai ir atkuriamo ryšio patikra
POM_CLAUDE_TEST=1 POM_CODEX_TEST=1 swift run pom-tests  # tikros paskyrų užklausos
```

Tą patį po kiekvieno pakeitimo padaro ir GitHub (`.github/workflows/patikra.yml`),
todėl sulaužytas kodas pastebimas iškart, o ne tada, kai kas nors atsisiunčia DMG.

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
- **Claude `get_usage` priklauso nuo Claude Code versijos.** Tai vietinė valdymo
  sąsaja. Pasikeitus jos protokolui POM išlaiko paskutinius duomenis ir parodo
  atnaujinimo klaidą. Būsenos juostos tiltas toliau gali perduoti bendrus limitus.
- **Neprisijungus prie Claude Code, Fable reikšmės nebus.** Pats tiltas negali
  papildyti duomenų, kurių Claude Code į jo įvestį neįtraukia.
- **Codex `app-server` pažymėtas kaip eksperimentinis.** Metodas gali pasikeisti kartu su
  Codex versija. Tokiu atveju POM parodo Codex grąžintą klaidos tekstą ir toliau rodo
  paskutinę žinomą reikšmę; Claude dalis veikia nepriklausomai.
- **Codex rodo vieną limitą.** Atskirų modelių rinkiniai (pavyzdžiui, Spark) nerodomi.
