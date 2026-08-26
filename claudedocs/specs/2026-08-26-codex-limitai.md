# Codex limitai POM programoje

Data: 2026-08-26. Versija po įgyvendinimo: 1.4.0.

## Tikslas

POM meniu juostoje rodo Claude 5 valandų ir 7 dienų limitus. Šis darbas prideda antrą
šaltinį: OpenAI Codex savaitės limitą, tą patį, kurį ChatGPT programa rodo skiltyje
„Usage & billing“ kaip „General usage limits → Weekly usage limit“.

## Duomenų šaltinis

Codex CLI turi vietinį JSON-RPC režimą `codex app-server` su metodu
`account/rateLimits/read`. Jis grąžina paruoštas reikšmes ir pats tvarko prisijungimą,
todėl POM nereikia nei rakto iš raktinės, nei tinklo užklausų, nei `jq`.

Patikrinta 2026-08-26 su Codex CLI 0.149.1: pilnas ciklas (proceso paleidimas, `initialize`,
`initialized`, `account/rateLimits/read`, atsakymas) truko 0,84 s.

Atsakymo forma:

```json
{"id":7,"result":{
  "rateLimits":{
    "limitId":"codex",
    "primary":{"usedPercent":5,"windowDurationMins":10080,"resetsAt":1788292169},
    "secondary":null,
    "credits":{"hasCredits":false,"unlimited":false,"balance":"0"},
    "planType":"prolite"},
  "rateLimitsByLimitId":{"codex":{...},"codex_bengalfox":{...}}}}
```

Rodomas vienas skaičius: **ilgiausias `rateLimits` rinkinio langas**. Praktiškai tai
savaitės langas (`windowDurationMins` 10080), rodomas pavadinimu „7 dienų“, kad sutaptų su
Claude sekcijos terminologija. Imamas ilgiausias, o ne fiksuotas 10080, nes plano struktūra
gali skirtis; `rateLimitsByLimitId` papildomi rinkiniai (pvz., `codex_bengalfox` =
GPT-5.3-Codex-Spark) šioje versijoje nerodomi.

### Kodėl ne sesijų žurnalai

`~/.codex/sessions/**/rollout-*.jsonl` faile yra `token_count` įvykiai su tais pačiais
`rate_limits`. Atmesta: naujose sesijose laukas dažnai būna `null`, reikšmės atsinaujina tik
tada, kai Codex aktyviai dirba, o failų yra virš tūkstančio, tad paiešką tektų kartoti.
Duomenys prastesni, kodo daugiau.

### Kodėl ne nuolatinis ryšys

`account/rateLimits/updated` pranešimai leistų sekti pokyčius realiu laiku, bet reikalautų
visą parą veikiančio proceso. Limitai keičiasi retai, tad pasirinktas trumpas klausimas.

## Elgesys

| Būsena | Kaip aptinkama | Ką mato vartotojas |
|---|---|---|
| Codex neįdiegtas | `codex` vykdomojo failo nėra žinomuose keliuose | Codex sekcijos nėra |
| Neprisijungęs | nėra `~/.codex/auth.json` arba jame nėra rakto | Sekcija su tekstu „Codex neprisijungęs prie paskyros. Terminale paleisk: `codex login`“ |
| Neatsako | procesas grąžino klaidą arba viršijo 10 s | Paskutinė žinoma reikšmė su žyma „pasenę“ |
| Veikia | gautas `result.rateLimits` | Sunaudota, likutis, atsistatymo laikas |

Atnaujinimo dažnis: automatiškai kas 5 min; atidarant langelį, jei duomenys senesni nei
60 s; rankiniu mygtuku (jis atnaujina ir Claude, ir Codex). Po nesėkmės pauzė dvigubinama
kaip `ServerFetchGate`, riba 30 min.

Paskutinė reikšmė saugoma faile `~/Library/Application Support/POM/codex-snapshot.json`,
kad po perkrovimo skaičiai būtų matomi iš karto.

## Sąsaja

### Langelis

Antraštė „Claude limitai“ keičiama į „Limitai“. Po ja dvi sekcijos, atskirtos linija:
„CLAUDE“ (5 valandų ir 7 dienų eilutės) ir „CODEX“ (7 dienų eilutė). Kiekviena sekcija turi
savo šviežumo tašką, nes duomenys ateina skirtingu metu. Apačioje lieka atnaujinimo mygtukas
ir nustatymų meniu.

### Ikona

Nustatymuose atsiranda pasirinkimas „Ikonoje rodyti: Claude / Codex“. Kairėje nuo juostelių
piešiama raidė: `C` (Claude) arba `X` (Codex). Claude režimu lieka dvi juostelių eilutės,
Codex režimu rodoma viena, vertikaliai centruota.

Kai Codex nepasiekiamas, o nustatymuose pasirinktas Codex, ikona rodo Claude: tuščia ikona be
jokio paaiškinimo būtų blogiau nei kito įrankio skaičiai. Pats nustatymas neperrašomas, tad
grįžus Codex viskas atsistato savaime. Pasirinkimo punktas meniu rodomas tik tada, kai Codex
kompiuteryje yra.

### Pranešimai

Tie patys slenksčiai (`AlertPreset`). Codex perspėjimo tekstas: „Codex 7 dienų limitas
baigiasi“. `AlertTracker.Window` papildomas reikšme `codexWeekly`.

## Kodo sandara

Nauja bendrojoje bibliotekoje (padengiama testais):

| Failas | Atsakomybė |
|---|---|
| `Sources/POMCore/CodexSnapshot.swift` | Modelis `CodexSnapshot` ir atsakymo skaitymas `CodexParser` |
| `Sources/POMCore/CodexLocator.swift` | `codex` vykdomojo failo paieška ir prisijungimo patikra, `CodexAvailability` |
| `Sources/POMCore/CodexClient.swift` | Proceso paleidimas, JSON-RPC apsikeitimas, laiko limitas |

Sąsajos pusėje:

| Failas | Atsakomybė |
|---|---|
| `Sources/POM/CodexViewModel.swift` | Codex sekcijos būsena, savas laikmatis ir perspėjimai |
| `Sources/POM/UsagePanelView.swift` | Karkasas ir sekcijos (sumažėja) |
| `Sources/POM/WindowRow.swift` | Vienos limito eilutės vaizdas, bendras abiem sekcijoms |
| `Sources/POM/ConnectView.swift` | Claude prijungimo langas (iškeliamas) |
| `Sources/POM/SettingsMenu.swift` | Nustatymų meniu (iškeliamas) |

Claude duomenų kelias (`Bridge`, `UsageParser`, `OAuthUsageClient`, `UsageViewModel`)
nekeičiamas, išskyrus antraštės tekstą ir naują nustatymą.

Bendros dalys papildomos: `AlertTracker.Window` gauna reikšmę `codexWeekly`,
`LTFormat` – `windowTitle(minutes:)`, o `ServerFetchGate` pauzės ilgis tampa nustatomas
(Anthropic serveris užklausas riboja griežtai, vietinis Codex – ne).

Iškėlimo priežastis: `UsagePanelView.swift` jau dabar 297 eilučių, o su Codex sekcija
peraugtų ribą, po kurios failą sunku skaityti ir saugiai taisyti.

### Vykdomojo failo paieška

GUI programa nepaveldi terminalo `PATH`, todėl `codex` ieškoma fiksuotuose keliuose
(`/opt/homebrew/bin`, `/usr/local/bin`, `~/.local/bin`, `~/.bun/bin`), o procesui
paduodamas `PATH`, kuriame yra `/opt/homebrew/bin` ir `/usr/local/bin`: npm įdiegtas
`codex` yra Node scenarijus su `#!/usr/bin/env node`, tad be to jis nepasileistų.

## Testai

Prie `tests/POMCoreTests/main.swift` pridedama:

- pilnas atsakymas su `rateLimits` ir `rateLimitsByLimitId`;
- atsakymas, kuriame tėra vienas langas;
- atsakymas su `primary` ir `secondary` (imamas ilgesnis langas);
- `rateLimits: null` ir JSON-RPC klaidos atsakymas (grąžinama klaida, ne griūtis);
- sugadintas JSON (grąžinama klaida);
- `CodexAvailability` sprendimai pagal failų buvimą.

## Kas dar keičiama

- README perrašomas, kad minėtų abu įrankius;
- ikonos paaiškinimas: „Claude ir Codex limitai“;
- `VERSION`: 1.3.3 → 1.4.0.
