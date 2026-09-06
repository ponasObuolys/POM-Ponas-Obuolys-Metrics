# POM (Ponas Obuolys Metrika)

Claude ir Codex limitai macOS meniu juostoje.

![meniu juosta](https://img.shields.io/badge/macOS-14%2B-black) ![swift](https://img.shields.io/badge/Swift-6-orange) ![licencija](https://img.shields.io/badge/licencija-MIT-blue)

## Ką rodo

Claude: 5 valandų, bendras 7 dienų ir **atskiras Fable savaitės limitas**.
POM juos gauna iš vietinės Claude Code komandos, kuri pati pasirūpina prisijungimu.
Užklausa modeliui nesiunčiama. Claude Code būsenos juosta papildomai perduoda
bendrus limitus dirbant.

Codex: pagrindinis savaitės limitas. POM paklausia vietinio Codex ir gauna
paskyros limitus bei ChatGPT plano tipą.

Langelyje rodomi ir planai, kai paskyra juos pateikia, pavyzdžiui, **Max 20x**
arba **ChatGPT Pro 5x**. Nežinomas vartojimo daugiklis nėra spėjamas.

Prie laikrodžio telpa vieno pasirinkto įrankio skaičiai: Claude su Anthropic ženklu,
Fable (`F`) arba Codex su ChatGPT logotipu. Visi limitai matomi paspaudus ikoną.
Logotipai yra programoje ir prisitaiko prie šviesios bei tamsios meniu juostos.
Atidarytame lange jie rodomi ir šalia Claude bei Codex pavadinimų.

## Atsisiuntimas

Paruošta programa: [naujausias leidimas](https://github.com/ponasObuolys/POM-Ponas-Obuolys-Metrics/releases/latest).

Atsisiuntus DMG failą, POM nutempiamas į `Applications`. Pirmą kartą jį reikia
paleisti dešiniu pelės mygtuku → **Open**, nes programa pasirašyta savadarbiu parašu.
Prie Claude Code būsenos juostos POM prisikabina paspaudus „Prijungti“.
Fable duomenis ji gauna ir be šio tilto, jei Claude Code įdiegta bei prijungta prie paskyros.

Reikia macOS 14 ar naujesnės. Claude limitams – įdiegtos Claude Code ir `jq` komandos
(`brew install jq`) būsenos juostos tiltui. Fable limitui reikia Claude Code
versijos su `get_usage` valdymo užklausa (patikrinta su 2.1.263).
Codex limitams – įdiegto ir prie paskyros prijungto Codex CLI.
Užtenka ir vieno iš jų.

## Diegimas iš kodo

```bash
./scripts/install-bridge.sh && ./scripts/bundle.sh && ./scripts/install.sh
```

Dalinimuisi su kitais: `./scripts/make-dmg.sh` sukuria `dist/POM-<versija>.dmg`.
Versija imama iš failo [VERSION](VERSION).

Xcode nereikia. Pilnas aprašymas: [claudedocs/README.md](claudedocs/README.md).

## Licencija

[MIT](LICENSE).

Anthropic ir OpenAI ženklai priklauso jų savininkams. Logotipų SVG paimti iš
[Lobe Icons](https://github.com/lobehub/lobe-icons); jų licencija pateikta
[pranešime apie trečiųjų šalių išteklius](Sources/POM/Resources/THIRD-PARTY-NOTICES.txt).
