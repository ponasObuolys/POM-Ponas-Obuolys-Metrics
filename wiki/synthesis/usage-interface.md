---
type: synthesis
created: 2026-11-03
updated: 2026-11-03
sources:
  - Sources/POM/Settings.swift
  - Sources/POM/UsagePanelView.swift
  - Sources/POM/HistoryService.swift
  - Sources/POMCore/HistoryStatistics.swift
  - docs/USAGE-INTERFACE.md
---

# Suvestinės ir istorijos patobulinimai

Vienodas „Liko / Sunaudota“ režimas visiems limitams. Meniu indikatoriai ir
suvestinės paslaugos valdomi atskirai; migracija vieną kartą nukopijuoja esamą
pasirinkimą. Kortelės ir automatinė tvarka lieka numatytosios; papildomai galima
rinktis 420 pt kompaktišką sąrašą ir rankinę tvarką. Skydelio turinys slenka, kai
netelpa ekrane. Prisegimas galioja automatiniame režime.

Paspaudus šviežumo žymą rodomas šaltinis, gavimo laikas ir atnaujinimo ar
prisijungimo veiksmas. Grok Bot veiksmas skaito tik vietinę suvestinę. Atsistatymo
laikas pateikiamas ir vietine data, o laikmačio pabaiga nepatvirtina atkūrimo.

Istorijoje yra užbaigtų dienų vidurkis ir dviejų užbaigtų savaičių palyginimas,
grafiko filtrai bei skirtingi linijų stiliai. Daliniai ar neatnaujinti duomenys
nelyginami. Esama trūkstamų dienų nulio interpretacija taikoma tik desktop
skaičiavimams; eksportas dienų neišgalvoja. Datos neperkeliamos tarp laiko juostų.

JSON v1 ir CSV eksportuoja pasirinktą 7/30 dienų intervalą iš atminties. Originalūs
atnaujinimo laikai išlaikomi; 7 dienų JSON neturi ankstesnės savaitės duomenų.
Companion importo suderinamumas tikrinamas tikrais desktop eksporto testų failais.

Tai vietiniai kodo pakeitimai, ne paskelbtas leidimas. Žr. [[docs/USAGE-INTERFACE]].

Patikra 2026-11-03: 365 pagrindinės patikros, SwiftUI vaizdai ir integracijos,
24 Companion patikros bei 7/30 dienų desktop importai, 5 bridge ir 9 Apple
preflight testai praėjo. Kompiliuota su macOS 26.5 SDK. Atnaujintos pavyzdinės
nuotraukos `docs/images/`.
