---
type: synthesis
created: 2026-09-06
updated: 2026-10-18
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

## 2026-10-18 · Versija 2.3.0

Vartotojo nurodymu `VERSION` pakelta iš 2.2.3 į 2.3.0. Pridėtos kūrimo
versijos pastabos `docs/releases/2.3.0.md` ir atnaujintos nuorodos abiejuose
README. Viešo 2.2.3 leidimo nuorodos paliktos kaip paskelbto leidimo istorija.
Vien numerio pakeitimas nesukuria GitHub leidimo ar notarizacijos.
Universalus 2.3.0 paketas įdiegtas į `/Applications/POM.app`, patikrinti abu
versijos laukai ir programos parašas. Paleistos programos atnaujinimo lange
gyvai perskaityta „POM 2.3.0“. Ankstesnė programa ir nustatymai išsaugoti
`dist/backups/`.

## 2026-11-03 · Suvestinė ir istorija

Įgyvendinti vartotojo patvirtinti septyni patobulinimai. Pridėta nustatymų migracija,
kompaktiškas režimas, rankinė tvarka, būsenų veiksmai, vietinis atsistatymo laikas,
užbaigtų dienų statistika ir laikotarpio JSON/CSV eksportas. Leidimas nepublikuotas.
Šaltinis: [[wiki/synthesis/usage-interface]].

## 2026-11-03 · Grok Bot serverio režimas

Pridėtas tiesioginis savaitės limito gavimas per esamą Cursor prisijungimą,
nes vietinei suvestinei atnaujinti reikėjo veikiančios Grok Bot programos.
Gyvas serveris dabartinę Cursor sesiją atmetė (401); tai atskirta nuo sintetinės
kliento patikros. Žr. [[wiki/synthesis/cursor-grok-metrics]].

## 2026-11-03 · Planų pavadinimų patikra

Oficialiuose šaltiniuose patikrinti Claude, ChatGPT, Cursor ir Grok Bot vardai.
Pašalinti išgalvojami seni daugikliai; Claude Max 20x/5x identifikatoriai rodomi
kaip Ultra/Max. Išsaugomi būsimi šaltinio vardai ir bendro Grok plano vardas.
Į leidimo tvarką įtraukta oficialių vardų patikra; žr. `docs/PLAN-NAMES.md`.

Planų pataisoms praėjo 400 pagrindinių patikrų ir SwiftUI integracijų rinkinys.
Atnaujintos nuotraukos. Universalus paketas įdiegtas į `/Applications/POM.app`
ir paleistas, patikrinus parašą bei vykdomojo failo atitikimą naujam paketui.

## 2026-11-03 · Cursor užšifruotos sesijos pataisymas

Ankstesnė 401 interpretacija buvo klaidinga: POM siuntė Cursor safeStorage
apvalkalą vietoj iššifruotos sesijos. Pridėtas macOS v10 dekodavimas per tikslų
Cursor raktinės įrašą, atskira vietinės saugyklos klaida ir apsauga nuo kartotinių
leidimo dialogų po atsisakymo. Tikros serverio užklausos 00:34 Vilniaus laiku
sėkmingai grąžino Grok Bot (1 limitas) ir Cursor (2 limitai). Sesijos neatnaujinome,
prisijungimo duomenys nebuvo spausdinami. 411 branduolio patikrų praėjo.

SwiftUI regresinės patikros praėjo. Universalus paketas įdiegtas į
`/Applications/POM.app`, parašas patikrintas, vykdomojo failo SHA-256 sutampa
su sukurtu paketu, procesas paleistas. Po sėkmingų tikrų užklausų įjungtas
Grok serverio režimas. Atsarginė kopija:
`dist/backups/POM-before-cursor-storage-6f7f62aa.app`.
Gyvos sąsajos patikros per kompiuterio valdymo įrankį nepavyko atlikti dėl
timeout; sėkmingos serverio užklausos tikrintos atskiru to paties POMCore klientu.

## 2026-11-03 · Automatinis Grok gavimas uždarius programas

Cursor uždarytas įprastu Quit, Grok Bot jau neveikė. Diagnostinis procesas
naudojo nepakeistus `AdditionalUsageViewModel`, `Settings`, tikrą Cursor sesiją
ir serverio klientą. Kviestas tik `start()`, ne rankinis refresh; intervalai
nekeisti. Sėkmingi gavimai: 00:42:45 ir 00:47:46 Europe/Vilnius (301 s).
Kas sekundę tikrinta, kad Cursor ir Grok Bot procesai neveikia. Patikra praėjo.
Įdiegtas POM liko paleistas, jo binaro SHA-256 sutapo su dist paketu. Tai
realaus atnaujinimo modulio patikra atskirame procese, ne gyvo POM lango
stebėjimas. Diagnostikos failai: `.build/grok-auto-check.swift`,
`.build/grok-auto-check.log` (be prisijungimo duomenų).

## 2026-11-03 · POM 2.4.0 vietinis įdiegimas

Versija pakelta iš 2.3.1 į 2.4.0; atnaujinti LT/EN README ir pridėtas
`docs/releases/2.4.0.md`. Universalus paketas įdiegtas į `/Applications/POM.app`
ir paleistas, versija bei parašas patikrinti, binaras sutampa su dist paketu.
Patikros: 411 branduolio, SwiftUI, 24 Companion duomenų patikros, 7/30 dienų
JSON importas, 5 bridge ir 9 Apple preflight testai. Viešas leidimas ir žyma
nekuriami; vartotojas patvirtino šių pakeitimų commit ir push.
