# POM — Claude ir Codex limitai macOS meniu juostoje

**Matyk, kiek naudojimo liko, neatsitraukdamas nuo darbo.**
POM viename lange parodo Claude ir Codex prenumeratos limitus, jų atsistatymo laiką
bei papildomus kreditus.

[English](README.md) · [Atsisiųsti](https://github.com/ponasObuolys/POM-Ponas-Obuolys-Metrics/releases) · [Diegimo pagalba](docs/INSTALL.txt)

> **[POM 2.2.1 paskelbta](https://github.com/ponasObuolys/POM-Ponas-Obuolys-Metrics/releases/tag/v2.2.1)** Apple silicon ir Intel kompiuteriams.
> Šis leidimas **Apple nenotarizuotas**, programos parašas — ad-hoc. macOS gali
> blokuoti pirmą paleidimą. „Developer ID“ pasirašymas ir notarizacija dar neatlikti.

<img src="docs/images/usage-lt.png" width="344" alt="POM lietuviškai: Claude ir Codex limitai, planai ir papildomas naudojimas">

## Galimybės

- **Claude limitai:** 5 valandų, bendras 7 dienų ir atskiras Fable savaitės limitas, kai šaltinis jį pateikia.
- **Codex limitas:** ilgiausias pagrindinio Codex rinkinio laikotarpis ir ChatGPT plano pavadinimas.
- **Papildomas naudojimas:** Claude mėnesio naudojimas bei sumos, kai pateikiama valiuta ir jos tikslumas; Codex kreditų likutis, mėnesio kreditų limitas ir galimi limito atkūrimai. Kreditai automatiškai neperkami ir nenaudojami.
- **Keli indikatoriai meniu juostoje:** galima atskirai pasirinkti Claude, Fable ir Codex. Rodoma sunaudota dalis arba likutis.
- **Pranešimai:** pasirenkamos perspėjimų ribos ir pranešimas, kai nauji duomenys patvirtina išnaudoto limito atsistatymą.
- **7 ir 30 dienų tokenų istorija:** dvi dienos kreivės — Claude ir Codex — bei visų modelių sumos. Claude Code naudojimas skaitomas iš šio Mac, Codex — iš paskyros.
- **Lietuvių ir anglų kalbos:** automatinis parinkimas pagal kompiuterio pagrindinę kalbą ir perjungimas nustatymuose. Kitoms sistemos kalboms parenkama anglų.
- **Naujinimų patikra:** Sparkle skaito pasirašytą naujinimų sąrašą. Šiam nenotarizuotam leidimui atveriamas atsisiuntimo puslapis; tiesioginis diegimas programoje numatytas būsimiems notarizuotiems leidimams.

![POM naudojimo istorija](docs/images/history-lt.png)

*Vaizduose naudojami pavyzdiniai duomenys. Tokenų sumos nenulinamos atsistačius limitui. Claude suma apima įvestį, išvestį, podėlio skaitymą ir rašymą; pasikartojantys sesijų ir subagentų įrašai skaičiuojami vieną kartą. Claude naudojimas naršyklėje ir kituose įrenginiuose neįtrauktas. Codex pateikia paskyros tokenų sumas. Claude dienos skaičiuojamos pagal UTC; Codex dienas pateikia paslauga, nenurodydama laiko juostos. Šiandienos duomenys dar pildomi. Tai nėra išlaidų suma ar prognozė.*

Istorija atnaujinama kas 15 minučių. Pirmas Claude importas vyksta mažomis porcijomis
fone, vėliau skaitomi tik papildyti failai. Nepakeistų failų turinys neskaitomas.
Papildomas CLI procesas nuolat nelaikomas paleistas.

## Diegimas

1. Atsisiųsk DMG iš [GitHub leidimų](https://github.com/ponasObuolys/POM-Ponas-Obuolys-Metrics/releases).
2. Nutempk POM į **Applications** ir paleisk iš šio aplanko.
3. Prisijunk prie įdiegtos Claude Code ir (arba) Codex CLI. POM limitus perskaitys pati.
4. Paspausk indikatorius meniu juostoje. Kalbą pakeisi krumpliaračio meniu, grafiką atversi paspaudęs **Istorija**.

Reikia macOS 14 ar naujesnės ir bent vienos įdiegtos bei prie paskyros prijungtos CLI.
Pasirenkamam Claude būsenos juostos tiltui reikia `jq`. Claude sąsaja priklauso nuo
CLI versijos; patikrinta su 2.1.263.

**macOS perspėjimas:** leidimai iki 2.2.1 imtinai nenotarizuoti, todėl kitame
kompiuteryje juos gali blokuoti Gatekeeper. Savadarbis sertifikatas to neišsprendžia.
Neišjunk Gatekeeper apsaugos. Tikslų perspėjimą įvertink pagal
[Apple paaiškinimą](https://support.apple.com/en-us/102445).

2.1.2 versijoje naujintuvo nėra: atsisiųsk 2.2.1 DMG ir pakeisk POM programą
Applications aplanke. **Ieškoti naujinimų…** tikrina pasirašytą sąrašą; šiam
leidimui pateikiama rankinio atsisiuntimo nuoroda. EdDSA parašai patvirtina failų
vientisumą, tačiau neatstoja Apple notarizacijos.

Codex atsistatymo pranešimui reikia aiškaus serverio patvirtinimo, kad įprastas naudojimas vėl leidžiamas. Jei tavo CLI šio lauko nepateikia, POM nesiunčia tokio pranešimo vien pagal procentus.

## Duomenys ir privatumas

POM prašo vietinių CLI naudojimo duomenų ir nesiunčia pokalbio žinutės modeliui.
Prisijungimu ir jo atnaujinimu pasirūpina pačios CLI. Atskiro API rakto nereikia.
Pasirenkamas atsarginis Claude serverio šaltinis iš pradžių išjungtas.

Paskutiniai limitai ir 30 dienų tokenų metaduomenys saugomi `~/Library/Application Support/POM`.
Claude sesijos skaitomos vietoje, iš jų paimami tik skaitikliai. Indekse yra maišos
funkcija paslėpti įrašų bei failų identifikatoriai, skaitymo pozicijos, datos ir sumos.
Pokalbių tekstas ir prieigos raktai nesaugomi. Codex istorija gaunama per prisijungtą
CLI ir išsaugoma šiame Mac. POM nesiunčia istorijos ir neturi analitikos.
Norint pašalinti podėlį, reikia uždaryti POM ir iš šio aplanko pašalinti tik
`claude-token-index.sqlite`, `claude-tokens.json` bei `codex-tokens.json`.
Kitą kartą paleidus programą, duomenys bus surinkti iš naujo.

## Kūrimas

Žr. [kūrėjo aprašymą](claudedocs/README.md) ir [pasirašymo instrukciją](docs/RELEASING.md).
Universaliame pakete yra Apple silicon ir Intel versijos. Vietinis kūrimo DMG
nėra notarizuotas viešas leidimas.

[MIT licencija](LICENSE). Nepriklausomas Ponas Obuolys projektas, nesusijęs su
Anthropic ar OpenAI. Ženklai priklauso jų savininkams; [išteklių licencijos](Sources/POM/Resources/THIRD-PARTY-NOTICES.txt).
