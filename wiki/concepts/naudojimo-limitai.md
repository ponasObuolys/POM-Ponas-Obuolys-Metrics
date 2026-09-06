---
type: concept
created: 2026-09-06
updated: 2026-09-06
sources:
  - Sources/POM/UsageViewModel.swift
  - Sources/POMCore/UsageSnapshot.swift
  - Sources/POMCore/CodexSnapshot.swift
  - Sources/POMCore/SubscriptionPlan.swift
  - Sources/POM/SettingsMenu.swift
---

# Naudojimo limitai

POM rodo Claude 5 valandų, bendrą savaitės ir atskirą Fable savaitės limitą.
Codex skiltyje rodomas ilgiausias pagrindinio `codex` rinkinio langas.
Tai naudojimo procentai, o ne tikslus sunaudotų tokenų ar išlaidų skaičius.

Fable turi atskirą reikšmę ir gavimo laiką. Naujesni bendri duomenys be Fable
lauko jos nepaslepia. Naujas pilnas Claude CLI atsakymas be Fable pašalina
ankstesnę atskiro limito reikšmę. Trūkstamas limitas nelaikomas nuliu.

Claude Max daugiklis skaitomas iš vietinių paskyros metaduomenų. Codex `prolite`
rodomas kaip ChatGPT Pro 5x, `pro` – kaip ChatGPT Pro 20x. Nežinomas planas
nerodomas. Plano nustatymas nesprendžiamas iš naudojimo procentų.

Nuo 2.2 meniu juostoje galima pasirinkti kelis šaltinius: Claude, Fable ir Codex.
Galima rodyti sunaudotą dalį ar likutį, pasirinkti perspėjimų ribas ir įjungti
paleidimą prisijungus prie kompiuterio. Atidarytame lange matomos abi paslaugos.

Nuo 2.2 papildomi kreditai rodomi atskirai nuo prenumeratos procentų. Claude sumoms reikia
valiutos ir decimal_places; Codex sumos yra kreditai. Atkūrimo kreditai tik rodomi, nenaudojami.

Istorija saugo tik gautus procentus, ne laikmačio apskaičiuotus nulius. Duomenys lieka
kompiuteryje iki 30 dienų. Atsistatymo pranešimams reikia naujo atsakymo; Codex papildomai
reikia aiškaus ordinaryUsageAllowed patvirtinimo.

Susiję: [[wiki/synthesis/pom-2-2]], [[wiki/entities/pom]], [[wiki/synthesis/pom-2-1-2]].
