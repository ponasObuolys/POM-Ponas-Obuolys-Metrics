---
type: synthesis
created: 2026-10-16
updated: 2026-10-18
sources:
  - Sources/POMCore/CursorClient.swift
  - Sources/POMCore/GrokBotCache.swift
  - Sources/POM/AdditionalUsageViewModel.swift
  - Sources/POM/AdditionalUsageSection.swift
  - Sources/POM/ProviderMarkView.swift
  - Sources/POM/Resources/THIRD-PARTY-NOTICES.txt
  - docs/CURSOR-GROK-METRICS.md
  - tests/POMCoreTests/main.swift
  - tests/POMViewTests/main.swift
---

# Cursor ir Grok Bot metrikos

Kūrimo versijoje pridėtos skiltys ir pasirenkami meniu juostos indikatoriai.
Cursor integracija iš pradžių išjungta. Įjungus tik skaitymui atveriama vietinė
Cursor sesijos bazė; raktas naudojamas tik dviem Cursor DashboardService
užklausoms. Sesijos duomenys POM nesaugomi. Rodomi pateikti atskiri Auto/API
arba bendri limitai, pagal planą nustatytas atsistatymo laikas ir papildomos išlaidos.

Grok Bot neturi atskiros POM serverio užklausos. Skaitoma aktyvios paskyros
vietinė `weekly-usage.cache` suvestinė, išsaugant pirminį duomenų laiką.
Grok Bot programai neatnaujinus suvestinės, POM negali parodyti naujesnio
skaičiaus. Pasibaigęs laikmatis nelaikomas patvirtintu limito atsistatymu.
Šie šaltiniai nesumuojami su tokenų istorija ir neturi atskirų perspėjimų.

Sukompiliuota su vietiniu macOS 26.5 SDK ir SwiftPM native build system.
332 branduolio patikros praėjo. LT/EN SwiftUI skiltys ir indikatoriai atvaizduoti;
patikrintas pradinis išjungimas, paskyros pakeitimas, trūkstami duomenys ir
užklausos atšaukimas. Naujasis kodas sėkmingai perskaitė tikrą Grok Bot suvestinę.

2026-10-18 vartotojas aiškiai leido naudoti esamą Cursor sesiją tik Cursor
plano ir limitų užklausoms. Tikras POM klientas sėkmingai perskaitė planą,
atskirus procentus, savaitės atsistatymą ir papildomą naudojimą. Raktas
nebuvo rodomas ar išsaugotas. Tą pačią dieną pakartotinai sėkmingai
perskaityta tikra Grok Bot suvestinė.
2026-10-18 paruoštas universalus arm64/x86_64 kūrimo paketas, patikrintas
jo parašas ir įdiegtas į `/Applications/POM.app`. Įjungtos Cursor metrikos
ir abu nauji indikatoriai, išsaugant ankstesnius Claude/Codex pasirinkimus.
Paleistos programos SwiftUI lange gyvai perskaitytos abi naujos skiltys su
tikrais procentais ir atsistatymo laikais. Įdiegtas vykdomasis failas sutampa
su patikrinto vietinio paketo failu.

Ankstesnė programa ir nustatymai išsaugoti `dist/backups/`. Vietiniam pakavimui
naudotas macOS 26.5 SDK ir SwiftPM native build system; esama POM piktograma
pakartotinai panaudota, nes šioje aplinkoje iconutil atmetė naują iconset.
Šaltinio versija liko 2.2.3; tai vietinis papildymas, viešas leidimas nepaskelbtas.

2026-10-18 raidiniai Cursor/Grok Bot pakaitalai pakeisti tikrais ženklais:
oficialaus Cursor ženklų paketo 2D kubu ir oficialios Grok Bot programos
piktograma su veidu. Bendras `ProviderMarkView` naudojamas meniu juostoje,
skilčių antraštėse ir šaltinių pasirinkimo meniu. Cursor yra temos spalva
piešiamas šablonas, Grok Bot išlaiko originalias spalvas. Failai yra POM
pakete, jų kilmė nurodyta `THIRD-PARTY-NOTICES.txt`. SwiftUI vaizdai
patikrinti šviesioje ir tamsioje temoje.
Pataisytas universalus paketas įdiegtas ir paleistas. Įdiegtų piktogramų
baitai sutampa su originaliais ištekliais, programos parašas patikrintas.
Ankstesnis paketas išsaugotas `dist/backups/POM-replaced-icons-20261018.app`.

Detalės: [integracijų aprašymas](../../docs/CURSOR-GROK-METRICS.md).
