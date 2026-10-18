---
type: synthesis
created: 2026-09-06
updated: 2026-09-18
sources:
  - https://developer.apple.com/enroll/agree
  - 2d8358e
  - docs/APPLE-DISTRIBUTION.md
  - docs/architecture/001-apple-platforms.md
  - Packages/POMUsageKit/Package.swift
  - scripts/apple-preflight.sh
  - Sources/POM/HistoryService.swift
  - tests/apple_preflight_tests.py
---

# Pasiruošimas Apple leidimams

Vartotojas nori Apple Developer narystės, notarizuoto Mac leidimo ir Mac App Store / iPhone / iPad versijų.
Organizacijos registracija „Ponas Obuolys, MB“ vardu pateikta 2026-09-07. Apple paieškoje rastas
esamas D-U-N-S numeris priimtas, darbo el. paštas patvirtintas. Iki 2026-09-09 buvo rodoma
„Your enrollment is being processed“. 2026-09-17 gautas Apple laiškas „Complete your Apple Developer
Program enrollment.“; 2026-09-18 gyvai patikrintas registracijos puslapis jau rodo „Review and Accept“.
2026-09-18 gavus konkretų vartotojo leidimą priimta Apple Developer Program License Agreement.
Apple atvėrė „Complete Your Order“ mokėjimo formą: vienų metų narystė, bendra rodoma suma US$99.
Forma prašo kortelės ir jos sąskaitos adreso duomenų; mokėjimas nepateiktas, aktyvi narystė
dar nepatvirtinta. Vartotojui palikta atverta mokėjimo forma. Kontaktai, patvirtinimo kodai ir paraiškos numeris Git nesaugomi.
Per ankstesnę techninę patikrą galiojančių Developer ID tapatybių nebuvo; 2026-09-18 jos netikrintos.

Toliau aprašyta techninė parengtis ir patikrų rezultatai yra 2026-09-07 būsena, įtraukta į `2d8358e`. Vartotojas įdiegė Xcode 26.6 ir užbaigė pirmo paleidimo veiksmus;
SDK ir iOS simuliatorius 26.5 prieinami. Agentas įdiegė XcodeGen 2.46.0.

Oficiali Anthropic dokumentacija nurodo, kad Pro/Max paskyroms Claude Code naudojimo analitika
neprieinama. Enterprise ir Console API nėra Max istorijos pakaitalas. iCloud perdavimas taip pat
nepaverstų vietinių Claude Code sumų visos Anthropic paskyros sumomis.

Vietiniame kode paruošta: atskiras POMUsageKit be CLI priklausomybių, aiškios kilmės JSON suvestinių
eksportas iš istorijos lango, riboto formato importo patikros ir leidimo parengties scenarijus.
Release scenarijus tikrina Developer ID ir notarizacijos prieigą dar prieš kompiliavimą.

273 branduolio, 9 izoliuotos Apple preflight ir 4 CLI tilto patikros praėjo.
Apple Silicon ir Intel leidimo kompiliacijos sėkmingos; atskiras POMUsageKit taip pat kompiliuojasi.
LT/EN istorijos langai atvaizduoti, su sintetiniais duomenimis patikrintas tikras istorijos paslaugos eksportas.

`Apps/POMCompanion` turi atskirą SwiftUI peržiūros programą ir generuojamą macOS/iOS Xcode projektą.
Veikia 7/30 dienų grafikai, parinktas kalbos režimas, ribotas ir koordinuojamas JSON importas, vienos
suvestinės išsaugojimas/pašalinimas, eksportas bei aiškiai pažymėtas pavyzdys. CLI, Sparkle ir prieigos
duomenys neįtraukti. 24 duomenų patikros bei tikro modelio importo, pakartotinio atidarymo, netinkamo failo,
podėlio ir pašalinimo patikros praėjo; keturi LT/EN langų pločiai atvaizduoti macOS aplinkoje.
Tikros Xcode Mac/iOS kompiliacijos taip pat pavyko. UI scenarijus praėjo iPhone 17e ir iPad (A16)
simuliatoriuose: pavyzdys, 7/30 dienos, EN→LT ir pašalinimas. Ad hoc pasirašytas Mac sandbox paketas
atidaro sintetinį desktop eksportą ir savo konteineryje išsaugo tikslią 5 846 baitų kopiją.
Vienas ramaus Debug proceso matavimas su atidarytu grafiku: 0,0 % CPU, apie 123 MiB RSS; tai nėra baterijos
ar Release našumo bandymas. CloudKit, StoreKit, fizinių įrenginių QA ir App Store pateikimas dar neįgyvendinti.
EN/LT parduotuvės tekstų bei privatumo juodraštis paruoštas `docs/app-store/companion-metadata-draft.md`.
Instrukcijos ir patikros ribos surašytos `Apps/POMCompanion/README.md`.

Ši šaka paruošia atskirą kūrimo peržiūrą; ji neįdiegta į Applications kaip viešas leidimas.
Pagal 2026-09-07 patikrą viešas 2.2.3 leidimas nenotarizuotas; 2026-09-18 leidimas pakartotinai netikrintas.
