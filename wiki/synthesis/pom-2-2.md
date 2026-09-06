---
type: synthesis
created: 2026-09-06
updated: 2026-09-06
sources:
  - claudedocs/2.2-plan.md
  - Sources/POM/HistoryService.swift
  - Sources/POM/HistoryView.swift
  - Sources/POM/UpdateService.swift
  - scripts/release.sh
  - docs/RELEASING.md
  - tests/POMCoreTests/main.swift
  - tests/POMViewTests/main.swift
---

# POM 2.2: įgyvendinimas ir leidimo kliūtis

Įgyvendinta: keli indikatoriai meniu juostoje, 7/30 dienų vietinė istorija,
pranešimas apie patvirtintą išnaudoto limito atsistatymą, papildomas Claude/Codex
naudojimas, automatinė bei rankinė LT/EN kalba ir Sparkle naujintuvas.
Prognozė vartotojo prašymu neįtraukta.

Pagrindinis README angliškas, yra README.lt.md, diegimo instrukcija, produkto
aprašymai ir pavyzdinių duomenų sąsajos vaizdai. GitHub aprašymas ir temos atnaujinti.

## Patikrinta

- 212 vietinių patikrų; su realių Claude/Codex atsakymų testais – 218.
- 4 izoliuoti būsenos juostos tilto testai.
- LT/EN, šviesūs/tamsūs langai, tuščia ir užpildyta istorija, kreditų kortelės,
  keli meniu indikatoriai atvaizduoti tikru SwiftUI su testiniais duomenimis.
- Universalus arm64 + x86_64 paketas; abiejų architektūrų kompiliavimas ir parašo patikra.
- Sukurtas vietinis kūrimo DMG; hdiutil kontrolinė suma teisinga.
- POM 2.2.0 įdiegta /Applications, procesas veikia, sukurtas istorijos failas su
  Claude session/weekly, Fable ir Codex įrašais. Ankstesnės programos kopija dist/POM-before-2.2.app.
- Vietinis bandomasis Sparkle naujinimas ir appcast pasirašyti; archyvas patikrintas
  pagal į programą įdėtą viešąjį raktą. Pakeistas archyvas atmetamas.
- Viešo leidimo scenarijus be Developer ID sustoja dar prieš kompiliavimą.

## Dar neatlikta

Nėra galiojančio Developer ID Application sertifikato, GitHub pasirašymo paslapčių
ir Apple notarizacijos duomenų. Vartotojo paklausta apie Apple Developer paskyrą.
Viešas 2.2 leidimas neturi būti žymimas ar skelbiamas iki notarizacijos; paskelbtas
leidimas tebėra 2.1.2. Vietinis ad-hoc DMG nėra tinkamas Gatekeeper perspėjimui išspręsti.
Pilnas atnaujinimas tarp notarizuotų leidimų ir diegimas kitame Mac dar nepatikrinti.

Codex CLI gyvai pateikia kreditų likutį ir 3 atkūrimo kreditus, bet nepateikia
`ordinaryUsageAllowed`. Tokioje versijoje atsistatymo pranešimas nesiunčiamas vien
pagal procentus. Tai aiškiai aprašyta README. Naujesnis protokolas su aiškiu
patvirtinimu palaikomas ir padengtas testais.

Susiję: [[wiki/entities/pom]], [[wiki/concepts/naudojimo-limitai]], [[wiki/synthesis/pom-2-1-2]].
