# POM Companion — App Store draft

Not submitted. This copy describes the report viewer that exists locally, not the proposed CloudKit
or live-quota functionality. Recheck it against the final tested archive before submission. Organization
enrollment has been submitted; the active team and a published app privacy-policy URL remain pending.

## English

- **Name:** POM Companion
- **Subtitle:** Claude & Codex usage reports
- **Category:** Developer Tools
- **Keywords:** tokens,AI,Claude,Codex,usage,history,developer,analytics,reports

Explore your Claude Code and Codex token usage on Mac, iPhone and iPad.

Open a usage report exported from POM on your Mac. Review daily totals, switch between 7 and 30 days,
and compare weeks with readings for each day. The final day may still be incomplete. Each source shows when its data was captured, so you can see what
the report covers and when it needs updating.

- Daily charts and a readable list of recorded totals.
- Claude and Codex provider marks with clear source labels.
- English and Lithuanian, selected automatically or manually.
- An offline copy you can export or remove.
- A built-in example to explore before opening your own report.

Claude reports cover Claude Code sessions collected on the exporting Mac. Codex reports contain
account history obtained by POM's Mac collector. Input, output and cached tokens are included; quota
percentages and plan multipliers are different measurements. Missing readings remain marked as missing.

Save a POM export in iCloud Drive or send it with AirDrop, then open it in POM Companion. Opening another
report replaces the saved copy. This version updates from files; automatic synchronization is planned.

POM Companion processes reports on your device. Reports contain daily totals and capture dates, without
conversation text or sign-in credentials. POM is an independent project and is not affiliated with
Anthropic or OpenAI.

## Lietuviškai

- **Pavadinimas:** POM Companion
- **Paantraštė:** Claude ir Codex suvestinės
- **Kategorija:** Kūrėjų įrankiai

Peržiūrėk „Claude Code“ ir „Codex“ tokenų naudojimą „Mac“, „iPhone“ ir „iPad“.

Atidaryk iš POM programos „Mac“ kompiuteryje eksportuotą suvestinę. Peržiūrėk dienų sumas, pasirink
7 ar 30 dienų laikotarpį ir palygink savaites, kurių kiekvienai dienai yra duomenų. Paskutinės dienos
duomenys gali būti nepilni. Prie kiekvieno šaltinio
rodomas duomenų surinkimo laikas, kad būtų aišku, kokį naudojimą suvestinė apima.

- Dienų grafikai ir patogus užfiksuotų sumų sąrašas.
- „Claude“ bei „Codex“ ženklai ir aiškiai įvardyti duomenų šaltiniai.
- Lietuvių ir anglų kalbos, parenkamos automatiškai arba rankiniu būdu.
- Išsaugota kopija, kurią gali eksportuoti arba pašalinti.
- Integruotas pavyzdys, padedantis susipažinti su programa.

„Claude“ duomenys apima „Claude Code“ sesijas, surinktas suvestinę eksportavusiame „Mac“. „Codex“
duomenys gaunami iš paskyros per POM rinkiklį „Mac“ kompiuteryje. Skaičiuojami įvesties, išvesties ir
podėlio tokenai. Limitų procentai ir plano daugikliai yra kiti rodikliai. Trūkstami duomenys aiškiai pažymėti.

Išsaugok POM eksportą „iCloud Drive“ arba persiųsk per „AirDrop“ ir atidaryk „POM Companion“.
Kita suvestinė pakeičia išsaugotą kopiją. Ši versija atnaujinama atidarant failus; automatinis
sinchronizavimas planuojamas.

POM Companion apdoroja suvestines tavo įrenginyje. Jose saugomos dienų sumos ir surinkimo datos,
be pokalbių ar prisijungimo duomenų. POM yra nepriklausomas projektas, nesusijęs su „Anthropic“ ar „OpenAI“.

## Reviewer notes draft

Launch the app and choose **Explore an example** to inspect the clearly labelled fictional dataset
without a provider login or another device. Select 7/30 days, inspect a day in the chart, expand All daily
readings, and change the interface language from the options menu.

For file import/export, use a synthetic report produced by the desktop visual check at
`.build/ui-checks/history-export-example.json`. Provide it as a clearly labelled review attachment only
after regenerating it for the submitted build. Import it through Open report, export a copy from the
options menu, and remove the local copy. Importing twice replaces data instead of adding totals.

The store target contains no CLI execution, provider credential access, transcript scanning, Sparkle,
payments or network client. macOS uses App Sandbox and user-selected file access. iPhone/iPad use
the system file picker. The app's function is viewing, comparing and managing exported usage summaries.
Review acceptance, including minimum functionality, remains Apple's decision.

## Privacy disclosure draft

POM Companion does not send reports, usage metrics, identifiers or diagnostics to the developer and
does not include advertising or analytics SDKs. It stores one imported report in its application storage
and the chosen interface language in its own preferences. Removing the report deletes that local copy.

Opening or exporting a file in iCloud Drive or another file provider uses Apple's file interfaces and
the storage service chosen by the user. Original files and any system-managed backups are controlled
separately. POM Companion has no automatic CloudKit synchronization in this version.

The intended App Store privacy response is **Data Not Collected**, subject to final archive inspection.
Publish a stable privacy-policy and support page under the confirmed publisher before submission;
this draft is not a live policy URL. Reassess disclosures when adding CloudKit, StoreKit or diagnostics.
