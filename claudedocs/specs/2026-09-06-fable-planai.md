# POM 2.1.2: Fable, planai, logotipai ir patikimumas

## Apimtis

- Claude prijungimas atpažįsta `/bin/bash` ir kabutėmis apgaubtus kelius su tarpais.
  Neatpažinta ar sudėtinė komanda nėra vykdoma ir nekeičia svetimo failo.
  Diegimui ir pašalinimui naudojamas bendras `statusline-command.sh`.
- Nutrūkus būsenos juostos ryšiui prijungimo mygtukas išlieka ir su išsaugotais skaičiais.
- GitHub tikrina kiekvieną shell scenarijų atskirai, taip pat tikrą diegimo ir pašalinimo ciklą.
- Fable savaitės limitas rodomas atskirai: procentai, likutis, atsistatymas ir savi perspėjimai.
  Jį galima pasirinkti meniu juostoje, kur naudojama raidė `F`.
- Claude Max 5x / 20x ir ChatGPT planai rodomi pagal paskyros duomenis.
- Anthropic ir ChatGPT logotipai rodomi meniu juostoje ir atidarytame lange.
  Vieną kartą įkeliamus SVG naudoja bendras `ProviderMarkView`; jie yra programos
  pakete ir prisitaiko prie šviesios bei tamsios temos.

## Duomenų kelias

Su Claude Code 2.1.263 praktiškai patikrinta seka:

1. Paleisti `claude --print --input-format stream-json --output-format stream-json`
   su išjungtais įrankiais, papildiniais, projekto nustatymais ir sesijos išsaugojimu.
2. Siųsti `control_request` su `subtype: initialize`.
3. Gavus sėkmę siųsti `control_request` su `subtype: get_usage`.
4. Perskaityti `control_response.response.response.rate_limits` ir uždaryti procesą.

Pokalbio žinutė ir modelio užklausa nesiunčiamos. Prisijungimo rakto atnaujinimas lieka
Claude Code atsakomybė. POM neturi atskiros prisijungimo rakto kopijos.
`get_usage` yra nuo Claude Code versijos priklausanti valdymo sąsaja, todėl klaidos
atveju išsaugomi paskutiniai skaičiai ir pateikiamas paaiškinimas.

Fable atsakymo forma: `limits[]` elementas su `kind: weekly_scoped`,
`scope.model.display_name: Fable`, `percent` ir `resets_at`. Taip pat priimama
`model_scoped[]` projekcija su `display_name`, `utilization` ir `resets_at`.
Bendri limitai yra atskiri `five_hour` ir `seven_day` objektai.

Kiekvienas šaltinis turi savo išsaugotą gavimo laiką. Nauji būsenos juostos duomenys,
neturintys Fable lauko, neperrašo Fable reikšmės ar jos amžiaus. Pasibaigęs atsistatymo
laikas tvarkomas ta pačia logika kaip kitų limitų. Trūkstama reikšmė nėra nulis.
Tas pats galioja bendram serverio atsakymui be Fable. Naujas pilnas Claude CLI
atsakymas be atskiro limito pašalina seną Fable reikšmę.

Claude tikslus Max daugiklis gaunamas iš `.claude.json` paskyros aprašo:
`userRateLimitTier`, o jo nesant `organizationRateLimitTier`.
Codex plano kodas paimamas iš `planType`, pirmiausia iš `rateLimitsByLimitId.codex`.
Seni išsaugoti failai be planų ir Fable lauko tebėra skaitomi.

## Patikra

```bash
swift run pom-tests
python3 tests/bridge_tests.py
bash scripts/check-ui.sh
POM_CLAUDE_TEST=1 POM_CODEX_TEST=1 swift run pom-tests
./scripts/bundle.sh
./scripts/make-dmg.sh
```

`check-ui.sh` atvaizduoja tikrus SwiftUI vaizdus per `NSHostingView`, tikrina
ryšio praradimo būseną ir tai, kad bendras atnaujinimas nepanaikina Fable.
Atvaizdai išsaugomi `.build/ui-checks`. Tai nėra paspaudimų gyvoje programoje patikra.

2026-09-06 patikrinta:

- 181 patikra su tikrais Claude ir Codex atsakymais, įskaitant abu planus.
- 4 diegimo, pašalinimo ir duomenų perdavimo patikros.
- Šviesus ir tamsus langas: 324 × 607; ryšio atkūrimo langas: 324 × 691.
- 2.1.2 paketas ir DMG sukurti, programos parašas patikrintas.
- Įdiegta ir paleista `/Applications/POM.app`; jos vykdomasis failas sutampa su paruoštu paketu.
- Paleista programa pati įrašė atskirą Fable limitą ir per automatinį atnaujinimą
  gavo Codex `planType: prolite` (ChatGPT Pro 5x) iš tikrų paskyrų.

GitHub leidimo eiga aprašyta `.github/workflows/leidimas.yml`: versijos žymė turi
atitikti `VERSION`, prieš publikavimą vykdomos patikros ir sukuriamas DMG.

## Šaltiniai

- [Claude Code būsenos juostos dokumentacija](https://code.claude.com/docs/en/statusline)
- [Codex valdymo serverio dokumentacija](https://github.com/openai/codex/blob/main/codex-rs/app-server/README.md)
- [ChatGPT Pro planai: 5x ir 20x](https://help.openai.com/en/articles/9793128-what-is-chatgpt-pro)
- Vietinio Claude Code 2.1.263 valdymo protokolas ir tikras `get_usage` atsakymas.

Šis aprašymas papildo 2026-08-26 Codex specifikaciją: įvardytas `codex` rinkinys
nuo šios versijos turi pirmenybę prieš senąjį bendrą `rateLimits` lauką.
