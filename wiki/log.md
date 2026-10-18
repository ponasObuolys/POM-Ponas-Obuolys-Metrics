---
type: synthesis
created: 2026-09-06
updated: 2026-09-18
sources:
  - 43f082be7f37b145c7705700c2793e2ac419bf09
---

# Žinyno pakeitimai

## 2026-09-06 – manual

**Šaltinis:** `43f082be7f37b145c7705700c2793e2ac419bf09` (`v2.1.2`).

**Veiksmas:** užfiksuotas paskelbtas leidimas ir dabartinė programos elgsena.

**Paveikti puslapiai:** [[wiki/concepts/naudojimo-limitai]],
[[wiki/entities/pom]], [[wiki/synthesis/pom-2-1-2]], [[wiki/index]].

**Naujos įžvalgos:** Fable gavimo laikas atskiras nuo bendrų duomenų;
Claude `get_usage` priklauso nuo CLI versijos; SVG paketas turi veikti
be vietinio kūrimo katalogo; vietinio ir GitHub DMG įrodymai yra atskiri.

## 2026-09-06 · POM 2.2

Įgyvendintos vartotojo pasirinktos funkcijos ir kalbos, atnaujinta dokumentacija.
Patikrinti testai, universalus vietinis paketas, istorijos įrašymas ir Sparkle parašai.
Viešas leidimas laukia Developer ID/notarizacijos. Šaltinis: [[wiki/synthesis/pom-2-2]].

## 2026-09-06 · POM 2.2.1

Procentų istorija pakeista bendromis Claude ir Codex tokenų sumomis.
Pridėtas inkrementinis vietinių įrašų indeksas, išmatuota atmintis ir I/O,
sumos palygintos su nepriklausomu perskaičiavimu.
Šaltinis: [[wiki/synthesis/pom-2-2-1]].

## 2026-09-06 · 2.2.1 viešas leidimas

Vartotojas aiškiai nurodė „paskelbk“, žinodamas apie notarizacijos trūkumą.
Paruoštas viešas nenotarizuotas DMG, checksum ir pasirašytas informacinis appcast.
README LT/EN ir diegimo instrukcijose aiškiai nurodyta būsena. Automatinio
notarizuoto leidimo patikros lieka galioti.

## 2026-09-06 · 2.2.2 parama

Stripe sukurta aktyvi vienkartinė EUR paramos nuoroda Ponas Obuolys, MB paskyroje.
Pridėti lokalizuoti programos mygtukai, GitHub Sponsor ir README nuorodos.
Šaltinis: [[wiki/synthesis/pom-2-2-2]].

## 2026-09-06 · 2.2.3 matomi priminimai

Pridėtas ramus pirmo paleidimo ir atnaujinimo langas, 7 dienų riba ir laikinas užvėrimas.
Vartotojo patikslinimu nuolatinio priminimų išjungimo pasirinkimas pašalintas.
Paramos mygtukas su tekstu pagrindiniame lange, nuoroda DMG bei LT/EN diegimo aprašymas.
Šaltinis: [[wiki/synthesis/pom-2-2-3]].

## 2026-09-18 · Apple registracija ir Companion parengtis

**Šaltiniai:** `2d8358e`, 2026-09-17 Apple laiškas ir 2026-09-18 gyvai patikrintas
[registracijos puslapis](https://developer.apple.com/enroll/agree).

**Veiksmas:** užregistruota ankstesnio commit techninė parengtis ir atnaujinta registracijos būsena.
Gavus konkretų vartotojo patvirtinimą Apple sutartis priimta. Atverta US$99 vienų metų narystės
mokėjimo forma; kortelės duomenys neįvesti ir mokėjimas nepateiktas.
Mokėjimas, aktyvi narystė, sertifikatai ir notarizuotas leidimas dar nepatvirtinti.
Ankstesni bandymai aiškiai atskirti nuo šiandien patikrintos registracijos.

**Paveikti puslapiai:** [[wiki/synthesis/apple-distribution-preparation]], [[wiki/index]], [[wiki/log]].

**Tęsimas:** vartotojui užbaigus mokėjimą, patikrinti narystės aktyvavimą.
Tik po to ruošti Developer ID bei notarizaciją.

## 2026-10-16 · Cursor ir Grok Bot metrikos

Pridėtos vietinės kūrimo versijos skiltys ir pasirenkami indikatoriai.
Cursor naudoja esamą sesiją tik vartotojui įjungus; Grok Bot skaito aktyvios
paskyros vietinę suvestinę. 332 branduolio patikros ir SwiftUI patikros praėjo,
tikros Grok Bot suvestinės nuskaitymas patvirtintas. Gyvas Cursor patikrinimas
laukia konkretaus leidimo. Applications ir viešas leidimas neatnaujinti.
Šaltinis: [[wiki/synthesis/cursor-grok-metrics]].

## 2026-10-18 · Bento tinklelis, segtukas ir Fable ženklas

Vietinė sąsaja pertvarkyta į 744 taškų pločio Bento tinklelį. Didžiausios
kortelės prioritetas nustatomas pagal limito procentą arba vieną išsaugotą
prisegimą. Paslaugų jungikliai keičia korteles ir meniu juostą. Fable naudoja
Claude simbolį. Praėjo 31 pasirinkimo derinio, penkių prisegimo variantų,
geometrijos ir LT/EN būsenų patikros. Universalus paketas įdiegtas vietoje,
patikrinti ištekliai ir parašas; ankstesnė programa bei nustatymai išsaugoti
`dist/backups/`. Viešas leidimas nesukurtas.
Šaltinis: [[wiki/synthesis/bento-dashboard]].

## 2026-10-18 · Gyva patikra ir vietinis įdiegimas

Gavus aiškų vartotojo leidimą tikras POM Cursor klientas sėkmingai gavo
planą, limitus ir atsistatymo laiką iš Cursor. Pakartotinai perskaityta
tikra Grok Bot vietinė suvestinė. Universalus arm64/x86_64 paketas
patikrintas ir įdiegtas į `/Applications/POM.app`; ankstesnė programa ir
nustatymai išsaugoti `dist/backups/`. Cursor integracija ir abu indikatoriai
įjungti. Paleistos programos lange gyvai patvirtinti abiejų skilties rodmenys.
Viešas leidimas nesukurtas; Git pakeitimai liko vietiniai.
Šaltinis: [[wiki/synthesis/cursor-grok-metrics]].

## 2026-10-18 · Tikros paslaugų piktogramos

Cursor ir Grok Bot raidiniai pakaitalai pakeisti oficialiais ištekliais:
Cursor 2D kubu ir nepakeista Grok Bot programos piktograma. Bendras komponentas
naudojamas meniu juostoje, skilčių antraštėse ir šaltinių pasirinkimo meniu.
SwiftUI vaizdai patikrinti abiejose temose; universalus paketas įdiegtas,
patikrintos įdiegtų išteklių kopijos ir programos parašas. POM procesas veikia.
Ankstesnis paketas išsaugotas `dist/backups/POM-replaced-icons-20261018.app`.
Šaltinis: [[wiki/synthesis/cursor-grok-metrics]].
