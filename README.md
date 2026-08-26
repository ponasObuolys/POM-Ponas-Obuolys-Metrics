# POM (Ponas Obuolys Metrika)

Claude ir Codex limitai macOS meniu juostoje.

![meniu juosta](https://img.shields.io/badge/macOS-14%2B-black) ![swift](https://img.shields.io/badge/Swift-6-orange) ![licencija](https://img.shields.io/badge/licencija-MIT-blue)

## Ką rodo

Claude: 5 valandų ir 7 dienų limitai. Reikšmės ateina iš Claude Code būsenos juostos,
o prireikus POM paklausia ir Anthropic serverio.

Codex: savaitės limitas, tas pats, kurį ChatGPT programa rodo skiltyje „Usage & billing“.
Nieko jungti nereikia: POM paklausia vietinio Codex ir gauna atsakymą per sekundę.
Nesant Codex ši dalis tiesiog nerodoma.

Prie laikrodžio telpa vieno įrankio skaičiai. Kurio – pasirenkama nustatymuose, o raidė
šalia juostelių primena, kuris tai: `C` arba `X`.

## Atsisiuntimas

Paruošta programa: [naujausias leidimas](https://github.com/ponasObuolys/POM-Ponas-Obuolys-Metrics/releases/latest).

Atsisiuntus DMG failą, POM nutempiamas į `Applications`. Pirmą kartą jį reikia
paleisti dešiniu pelės mygtuku → **Open**, nes programa pasirašyta savadarbiu parašu.
Terminalo nereikia: prie Claude Code POM prisijungia pati, paspaudus mygtuką „Prijungti“.

Reikia macOS 14 ar naujesnės. Claude limitams – įdiegtos Claude Code ir `jq` komandos
(`brew install jq`), Codex limitams – įdiegto ir prie paskyros prijungto Codex CLI.
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
