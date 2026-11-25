---
type: synthesis
created: 2026-11-03
updated: 2026-11-25
sources:
  - Sources/POM/Settings.swift
  - Sources/POM/UsagePanelView.swift
  - Sources/POM/HistoryService.swift
  - Sources/POMCore/HistoryStatistics.swift
  - Sources/POMCore/ClaudeTokenIndexer.swift
  - Sources/POMCore/GrokBotDailyUsage.swift
  - Sources/POM/HistoryView.swift
  - docs/releases/2.4.2.md
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

## Istorija nuo 2.4.2

- **Fable / Mythos** yra Claude sumos dalis, ne atskira suma. Modelis atpažįstamas pagal pavadinime esantį `fable` arba `mythos`; indeksas (schema 2) saugo tik požymį, ne modelio vardą. Senas indeksas vieną kartą perkuriamas iš sesijų.
- **Grok Bot** istorija yra savaitės limito dalis procentais per dieną, ne tokenai. Serveris pateikia tik einamąją savaitę, ankstesnes POM kaupia `grok-bot-days.json`. Plačiau: [[wiki/synthesis/cursor-grok-metrics]].
- Neperskaitytų Claude įrašų skaitiklis saugomas kiekvienam sesijos failui. Iki 2.4.2 jis buvo amžinas, todėl viena bloga eilutė visam laikui paslėpdavo vidurkį ir savaičių palyginimą.
- Datų užrašai grafike centruojami po taškais (`AxisValueLabel(centered: false)`), abu grafikai naudoja tą pačią X ašį ir vienodo pločio Y ašies užrašus, kad dienos sutaptų.
