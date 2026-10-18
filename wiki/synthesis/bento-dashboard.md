---
type: synthesis
created: 2026-10-18
updated: 2026-10-18
sources:
  - Sources/POM/UsageBentoGrid.swift
  - Sources/POM/UsagePanelView.swift
  - Sources/POM/Settings.swift
  - Sources/POM/ProviderMarkView.swift
  - tests/POMViewTests/main.swift
  - docs/CURSOR-GROK-METRICS.md
---

# Bento suvestinė ir prisegimas

Vietinis POM langas išplėstas iki 744 taškų. Slinkimo konteineris pašalintas;
rodoma viena pagrindinė kortelė ir dvi mažesnių kortelių skiltys. Paskutinė
neporinė kortelė užima visą eilutę. `BentoCardLayout` matuoja turinį, sulygina
eilutės aukščius ir užtikrina, kad pagrindinės kortelės plotas didžiausias.
Stable provider IDs ir SwiftUI animacija leidžia kortelėms persidėlioti.

Paslaugų pasirinkimas valdo ir korteles, ir meniu juostos indikatorius.
Jis pasiekiamas lango viršuje ir nustatymuose. Fable atskirtas nuo Claude
kortelės ir pažymėtas Claude simboliu iš Lobe Icons; mažos F raidės nebėra.
SVG matmenys aiškiai nustatyti 24×24, nes AppKit netinka pradiniai em vienetai.

Pagrindinę kortelę parenka didžiausias galiojantis sunaudoto limito
procentas, ne tokenų suma. Claude vertinami 5 valandų ir bendras savaitės
langai; Cursor vertinami abu atskiri langai. Nežinomi ir pasibaigę rodmenys
nelaimi prioriteto; lygybės išlaiko stabilią šaltinių eilę.

`Settings.pinnedSource` yra vienas pasirenkamas šaltinis. Segtukas pakeičia
ankstesnį prisegimą, pakartotinis paspaudimas atsega. Paslėpus prisegtą
paslaugą pin pašalinamas. Nustatymas išsaugomas UserDefaults.

Patikrinta: visi 31 netuščias pasirinkimo derinys, penki prisegimo variantai,
persistencija, atsegimas, klaidos ir pasibaigę limitai, LT/EN ir abi temos,
įskaitomos piktogramos. Sintetinėse SwiftUI patikrose lango aukštis mažesnis
nei 740 taškų. Atskiros geometrijos patikros tikrina plotų prioritetą,
turinio aukštį ir nepersidengimą.

2026-10-18 universalus arm64/x86_64 paketas įdiegtas į `/Applications/POM.app`.
Patikrintas parašas ir įdiegtų išteklių atitikimas. Ankstesnis paketas ir
nustatymai išsaugoti `dist/backups/`. Tai vietinė kūrimo versija, viešas
leidimas nepaskelbtas. Programos lango sintetinė patikra atskiriama nuo
įdiegto meniu juostos langelio gyvos patikros.

Susiję: [[wiki/synthesis/cursor-grok-metrics]], [[wiki/concepts/naudojimo-limitai]].
