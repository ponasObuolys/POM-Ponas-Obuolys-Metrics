---
type: concept
created: 2026-09-06
updated: 2026-10-18
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

Nuo 2.2.1 istorijoje rodomi dienos tokenai: Claude Code šiame Mac ir Codex paskyra,
visi modeliai kartu, 7/30 dienų sumos. Limitų atsistatymas jų nenulina. Skaitymas
inkrementinis, fone. Senas procentų istorijos failas nebenaudojamas.
Atsistatymo pranešimams reikia naujo atsakymo; Codex papildomai
reikia aiškaus ordinaryUsageAllowed patvirtinimo.

Vietinėje 2026-09-09 pataisoje pasibaigęs laikmatis nebepaverčia paskutinės
reikšmės nuliu. Lange ir meniu juostoje rodoma „–“, laukiant naujų duomenų.
„Prisijungti prie Claude“ mygtukas ir toks pat nustatymų meniu veiksmas
atidaro Terminal su `claude auth login`. Sėkmingas komandos rezultatas
inicijuoja naują limitų užklausą be ankstesnės klaidos laukimo intervalo.
Prisijungimo duomenis tvarko Claude CLI; POM skaito tik komandos baigimo kodą.
ChatGPT/Codex turi tokį pat atskirą prisijungimo veiksmą su `codex login`.
Abi eigos naudoja bendrą `CLISignInSession` ir `TerminalSignIn`; po sėkmės
atnaujinami tik atitinkamos paslaugos limitai.

Vietinė 2026-10-18 sąsaja naudoja Bento tinklelį be slinkimo. Paslaugų
jungikliai valdo ir korteles, ir meniu juostą; Fable turi atskirą kortelę
su Claude modelių šeimos ženklu. Didžiausia automatiškai tampa daugiausiai
limito procentų išnaudojusi paslauga. Vieną kortelę galima prisegti segtuku;
atsegus arba išjungus prisegtą paslaugą grįžtama prie automatinio prioriteto.
Pasibaigę rodmenys šiame palyginime nedalyvauja. Daugiau:
[[wiki/synthesis/bento-dashboard]].

Susiję: [[wiki/synthesis/pom-2-2]], [[wiki/entities/pom]], [[wiki/synthesis/pom-2-1-2]].
