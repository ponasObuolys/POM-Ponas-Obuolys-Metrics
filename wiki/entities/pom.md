---
type: entity
created: 2026-09-06
updated: 2026-09-06
sources:
  - Package.swift
  - Sources/POMCore/ClaudeClient.swift
  - Sources/POMCore/CodexClient.swift
  - Sources/POM/UsageViewModel.swift
  - Sources/POM/ProviderMarkView.swift
  - scripts/bundle.sh
  - .github/workflows/leidimas.yml
---

# POM

macOS 14 ir naujesnėms sistemoms skirta SwiftUI meniu juostos programa.
`POMCore` apdoroja duomenis; `POM` valdo langą, nustatymus ir pranešimus.

Claude šaltiniai: būsenos juostos failas, Claude CLI ir pasirenkamas serverio
atsarginis šaltinis. `ClaudeClient` siunčia tik `initialize` ir `get_usage`
valdymo užklausas. Modeliui pokalbio žinutė nesiunčiama. Prisijungimo
atnaujinimu pasirūpina Claude Code. Sąsaja priklauso nuo Claude Code versijos;
gyvai patikrinta 2.1.263. Automatinio sėkmingų užklausų ciklo intervalas – 5 minutės.

Codex duomenys gaunami per vietinio `codex app-server` metodą
`account/rateLimits/read`. Šaltiniai turi atskirus paskutinių duomenų failus.

`ProviderMarkView` bendras meniu juostai ir lango antraštėms. Anthropic bei
ChatGPT SVG ir jų licencija įdedami į `POM_POM.bundle`. Supakuota programa
juos randa savo `Contents/Resources`, todėl kūrimo katalogas jai nereikalingas.

`scripts/bundle.sh` sukuria programą; `scripts/make-dmg.sh` – DMG.
Versija skaitoma iš `VERSION`. Nuo 2.2 paketas universalus (arm64 + x86_64), į jį įdedama
Sparkle biblioteka. `release.sh` reikalauja Developer ID, notarizuoja programą ir DMG,
patikrina Gatekeeper, pasirašo appcast. Tik po to GitHub `v*` žymės eiga leidžia publikavimą.

Viešasis Sparkle raktas saugomas config/sparkle-public-key.txt; privatus yra macOS raktinėje,
account lt.ponasobuolys.pom. Privatūs raktai į Git neįtraukiami.

Susiję: [[wiki/concepts/naudojimo-limitai]], [[wiki/synthesis/pom-2-1-2]].
