import SwiftUI
import Charts
import UniformTypeIdentifiers
import POMUsageKit
import POMCompanionData

@MainActor
public struct CompanionRootView: View {
    @StateObject private var model: CompanionModel
    @AppStorage("pomCompanionLanguage") private var language = "system"
    @State private var days = 7
    @State private var importing = false
    @State private var exporting = false
    @State private var confirmingClear = false
    @State private var document: ReportDocument?
    private var copy: CompanionLanguage { CompanionLanguage(value: language) }

    public init(model: CompanionModel? = nil) {
        _model = StateObject(wrappedValue: model ?? CompanionModel())
    }

    public var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    if let report = model.report {
                        ReportDashboard(report: report, isExample: model.isExample, days: $days, language: language)
                    } else {
                        emptyState
                    }
                }
                .padding(24)
                .frame(maxWidth: 1000)
                .frame(maxWidth: .infinity)
            }
            .navigationTitle("POM Companion")
            #if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
            #endif
            .toolbar {
                ToolbarItemGroup(placement: .primaryAction) {
                    Button { importing = true } label: {
                        Label(copy.text("Open report", "Atidaryti suvestinę"), systemImage: "folder")
                    }
                    .disabled(model.busy)
                    .accessibilityIdentifier("openReport")
                    Menu {
                        Picker(copy.text("Language", "Kalba"), selection: $language) {
                            Text(copy.text("System language", "Sistemos kalba")).tag("system")
                            Text("English").tag("en")
                            Text("Lietuvių").tag("lt")
                        }
                        if model.report != nil {
                            Divider()
                            Button(copy.text("Export report…", "Eksportuoti suvestinę…"), systemImage: "square.and.arrow.up") {
                                do {
                                    document = try model.report.map { try ReportDocument(report: $0) }
                                    exporting = true
                                } catch { model.failure = .save }
                            }
                            .disabled(model.busy || model.isExample)
                            Button(copy.text("Remove report…", "Pašalinti suvestinę…"), systemImage: "trash", role: .destructive) {
                                confirmingClear = true
                            }
                            .disabled(model.busy)
                        }
                    } label: { Image(systemName: "ellipsis.circle") }
                    .accessibilityLabel(copy.text("Options and language", "Parinktys ir kalba"))
                    .accessibilityIdentifier("options")
                }
            }
            .overlay { if model.busy { ProgressView(copy.text("Opening…", "Atidaroma…")).padding(20).background(.regularMaterial, in: RoundedRectangle(cornerRadius: 16)) } }
        }
        .environment(\.locale, copy.locale)
        .onOpenURL { url in
            guard url.isFileURL else { return }
            Task { await model.open(url) }
        }
        .fileImporter(isPresented: $importing, allowedContentTypes: [.json]) { result in
            switch result {
            case .success(let url): Task { await model.open(url) }
            case .failure: model.failure = .open
            }
        }
        .fileExporter(isPresented: $exporting, document: document, contentType: .json,
                      defaultFilename: "POM-usage-\(model.report.map { UsageDay.key($0.generatedAt) } ?? "report")") { result in
            if case .failure = result { model.failure = .save }
        }
        .confirmationDialog(copy.text("Remove the saved report?", "Pašalinti išsaugotą suvestinę?"), isPresented: $confirmingClear, titleVisibility: .visible) {
            Button(copy.text("Remove report", "Pašalinti suvestinę"), role: .destructive) { model.clear() }
        } message: {
            Text(copy.text("This removes the copy saved in POM Companion. The original file stays in Files.", "Bus pašalinta „POM Companion“ išsaugota kopija. Pradinis failas liks savo vietoje."))
        }
        .alert(copy.text("Report unavailable", "Suvestinė nepasiekiama"), isPresented: Binding(
            get: { model.failure != nil }, set: { if !$0 { model.failure = nil } })) {
                Button("OK") { model.failure = nil }
            } message: { Text(failureText) }
    }

    private var emptyState: some View {
        VStack(spacing: 24) {
            Image(systemName: "chart.bar.xaxis").font(.system(size: 52)).foregroundStyle(.mint)
            VStack(spacing: 10) {
                Text(copy.text("Your usage, in view", "Naudojimo istorija vienoje vietoje"))
                    .font(.largeTitle.bold()).multilineTextAlignment(.center)
                Text(copy.text("Open a POM report to explore daily Claude Code and Codex token totals.", "Atidaryk POM suvestinę ir peržiūrėk kasdienį „Claude Code“ bei „Codex“ tokenų naudojimą."))
                    .foregroundStyle(.secondary).multilineTextAlignment(.center)
            }
            Button { importing = true } label: {
                Label(copy.text("Open report", "Atidaryti suvestinę"), systemImage: "folder")
                    .padding(.horizontal, 8).padding(.vertical, 4)
            }
            .buttonStyle(.borderedProminent)
            Button(copy.text("Explore an example", "Peržiūrėti pavyzdį")) { model.showExample() }
                .buttonStyle(.plain).foregroundStyle(.secondary)
                .accessibilityIdentifier("showExample")
            VStack(alignment: .leading, spacing: 12) {
                Label(copy.text("On your Mac", "Tavo „Mac“ kompiuteryje"), systemImage: "desktopcomputer").font(.headline)
                Text(copy.text("In POM, open Usage history → Export. Save the JSON report in iCloud Drive or send it with AirDrop, then open it here.", "POM programoje atidaryk Naudojimo istorija → Eksportuoti. Išsaugok JSON suvestinę „iCloud Drive“ arba persiųsk per „AirDrop“ ir atidaryk čia."))
                    .foregroundStyle(.secondary)
                Text(copy.text("Reports contain totals and capture dates. Conversations and sign-in details stay out of the report.", "Suvestinėse yra sumos ir duomenų surinkimo laikas. Pokalbių bei prisijungimo duomenų jose nėra."))
                    .font(.footnote).foregroundStyle(.secondary)
            }
            .padding(20).background(.quaternary.opacity(0.5), in: RoundedRectangle(cornerRadius: 20))
        }
        .frame(maxWidth: 520)
        .padding(.vertical, 32)
        .frame(maxWidth: .infinity)
    }

    private var failureText: String {
        switch model.failure {
        case .save: return copy.text("The report could not be saved. Choose a writable location and try again.", "Suvestinės išsaugoti nepavyko. Pasirink vietą, kurioje galima įrašyti failus, ir bandyk dar kartą.")
        case .remove: return copy.text("The saved report could not be removed. Try again.", "Išsaugotos suvestinės pašalinti nepavyko. Bandyk dar kartą.")
        case .restore: return copy.text("The saved copy could not be opened. Open the original POM report again.", "Išsaugotos kopijos atidaryti nepavyko. Dar kartą atidaryk pradinę POM suvestinę.")
        default: return copy.text("Choose a valid POM JSON report up to 256 KB. Check that the file is downloaded and its location is available. Your previous report has been kept.", "Pasirink tinkamą POM JSON suvestinę iki 256 KB. Patikrink, ar failas atsiųstas ir jo vieta pasiekiama. Ankstesnė suvestinė išsaugota.")
        }
    }
}

public struct ReportDashboard: View {
    let report: UsageHistoryReport
    let isExample: Bool
    @Binding var days: Int
    let language: String
    @Environment(\.colorScheme) private var scheme
    @State private var selectedDay: String?
    @State private var availableWidth: CGFloat = 0
    private var copy: CompanionLanguage { CompanionLanguage(value: language) }
    private var period: ReportPeriod { ReportPeriod(report: report, days: days) }

    public init(report: UsageHistoryReport, isExample: Bool, days: Binding<Int>, language: String) {
        self.report = report; self.isExample = isExample; _days = days; self.language = language
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: 24) {
            VStack(alignment: .leading, spacing: 8) {
                Text(copy.text("Usage history", "Naudojimo istorija")).font(.largeTitle.bold())
                Text(copy.text("Report exported", "Suvestinė eksportuota") + " · " + copy.captured(report.generatedAt))
                    .font(.subheadline).foregroundStyle(.secondary)
            }
            if isExample {
                Label(copy.text("Example · fictional data", "Pavyzdys · išgalvoti duomenys"), systemImage: "sparkle")
                    .font(.subheadline.weight(.medium)).padding(12)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(.blue.opacity(0.10), in: RoundedRectangle(cornerRadius: 12))
            }
            Picker(copy.text("Period ending on the export date", "Laikotarpis iki eksporto datos"), selection: $days) {
                Text(copy.text("7 days", "7 dienos")).tag(7)
                Text(copy.text("30 days", "30 dienų")).tag(30)
            }
            .pickerStyle(.segmented).labelsHidden().frame(maxWidth: 300)
            .accessibilityIdentifier("historyPeriod")
            .onChange(of: days) { _, _ in selectedDay = nil }
            Text(copy.day(period.keys[0]) + " – " + copy.day(period.keys[period.keys.count - 1]))
                .font(.caption).foregroundStyle(.secondary)

            LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 16, alignment: .top),
                                     count: availableWidth >= 570 ? min(2, period.entries.count) : 1), spacing: 16) {
                ForEach(period.entries, id: \.source) { entry in providerCard(entry) }
            }

            VStack(alignment: .leading, spacing: 16) {
                Text(copy.text("Daily tokens", "Tokenai per dieną")).font(.headline)
                HStack(spacing: 18) {
                    ForEach(period.entries, id: \.source) { entry in
                        Label { Text(name(entry.source)) } icon: { Circle().fill(color(entry.source)).frame(width: 8, height: 8) }
                    }
                }.font(.caption)
                Chart {
                    ForEach(period.entries, id: \.source) { entry in
                        ForEach(period.records(for: entry)) { record in
                            BarMark(x: .value("Day", record.day), y: .value("Tokens", record.tokens))
                                .foregroundStyle(by: .value("Provider", name(entry.source)))
                                .position(by: .value("Provider", name(entry.source)))
                                .cornerRadius(3)
                                .accessibilityLabel("\(name(entry.source)), \(copy.day(record.day))")
                                .accessibilityValue(copy.number(record.tokens))
                        }
                    }
                }
                .chartForegroundStyleScale(["Claude": color(.claudeCodeLocal), "Codex": color(.codexAccount)])
                .chartLegend(.hidden)
                .chartXScale(domain: period.keys)
                .chartXSelection(value: $selectedDay)
                .chartXAxis {
                    AxisMarks(values: axisDays) { value in
                        if let key = value.as(String.self) { AxisValueLabel { Text(copy.day(key)) } }
                    }
                }
                .chartYAxis {
                    AxisMarks(position: .leading, values: .automatic(desiredCount: 4)) { value in
                        AxisGridLine()
                        if let amount = value.as(Double.self) {
                            AxisValueLabel { Text(amount.formatted(.number.notation(.compactName).locale(copy.locale))) }
                        }
                    }
                }
                .frame(height: 230)
                .overlay {
                    if period.entries.allSatisfy({ period.records(for: $0).isEmpty }) {
                        Text(copy.text("No readings for this period", "Šio laikotarpio duomenų nėra"))
                            .foregroundStyle(.secondary).padding().background(.regularMaterial, in: RoundedRectangle(cornerRadius: 12))
                    }
                }
                if let selectedDay, period.keys.contains(selectedDay) {
                    dayRow(selectedDay)
                } else {
                    Text(copy.text("Select a day to inspect its readings.", "Pasirink dieną ir peržiūrėk jos duomenis."))
                        .font(.caption).foregroundStyle(.secondary)
                }
            }
            .padding(20).background(.quaternary.opacity(0.4), in: RoundedRectangle(cornerRadius: 20))

            DisclosureGroup(copy.text("All daily readings", "Visi dienų duomenys")) {
                VStack(spacing: 0) {
                    ForEach(period.keys.reversed(), id: \.self) { key in
                        dayRow(key).padding(.vertical, 12)
                        Divider()
                    }
                }.padding(.top, 8)
            }
            .font(.subheadline)
            VStack(alignment: .leading, spacing: 8) {
                Label(copy.text("Saved report · updates when you open a newer file", "Išsaugota suvestinė · atsinaujina atidarius naujesnį failą"), systemImage: "doc")
                Text(copy.text("Includes input, output and cached tokens. Missing readings are shown as —. Claude days use UTC; Codex dates come from the service. The final day may be incomplete.", "Įtraukti įvesties, išvesties ir podėlio tokenai. Trūkstami duomenys žymimi —. „Claude“ dienos skaičiuojamos pagal UTC, „Codex“ datas pateikia paslauga. Paskutinės dienos duomenys gali būti nepilni."))
                Text(copy.text("Claude covers Claude Code on the exporting Mac. Claude web and other devices are not included. Opening another report replaces this one.", "„Claude“ duomenys apima „Claude Code“ naudojimą eksportavusiame „Mac“. „Claude“ naršyklėje ir kituose įrenginiuose neįtrauktas. Atidarius kitą suvestinę, ši bus pakeista."))
            }
            .font(.caption).foregroundStyle(.secondary)
        }
        .onGeometryChange(for: CGFloat.self) { $0.size.width } action: { availableWidth = $0 }
        .environment(\.locale, copy.locale)
    }

    private var axisDays: [String] {
        return period.keys.enumerated().compactMap {
            (days == 7 ? $0.offset % 2 == 0 : $0.offset % 7 == 3) ? $0.element : nil
        }
    }
    private func name(_ source: UsageHistoryReport.Source) -> String { source == .claudeCodeLocal ? "Claude" : "Codex" }
    private func color(_ source: UsageHistoryReport.Source) -> Color {
        if scheme == .dark { return source == .claudeCodeLocal ? .orange : .mint }
        // Keep the totals and chart marks readable against a light background.
        return source == .claudeCodeLocal ? Color(red: 0.70, green: 0.30, blue: 0.01)
            : Color(red: 0, green: 0.45, blue: 0.38)
    }
    private func providerCard(_ entry: UsageHistoryReport.Entry) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 8) {
                ProviderMark(claude: entry.source == .claudeCodeLocal)
                Text(name(entry.source)).font(.headline)
                Spacer()
            }
            Text(period.total(for: entry).map(copy.number) ?? "—")
                .font(.system(.largeTitle, design: .rounded, weight: .bold))
                .foregroundStyle(color(entry.source)).lineLimit(1).minimumScaleFactor(0.5)
                .accessibilityLabel(copy.text("Recorded tokens", "Užfiksuoti tokenai"))
                .accessibilityValue(period.total(for: entry).map(copy.number) ?? copy.text("No readings", "Duomenų nėra"))
            Text(copy.text("Recorded tokens ·", "Užfiksuoti tokenai ·") + " \(period.records(for: entry).count)/\(days) " + copy.text("days", "dienų"))
                .font(.caption).foregroundStyle(.secondary)
            Text(entry.source == .claudeCodeLocal
                 ? copy.text("Claude Code · exporting Mac", "Claude Code · eksportavęs „Mac“")
                 : copy.text("Codex account", "Codex paskyra"))
                .font(.subheadline.weight(.medium))
            Text(copy.text("Captured", "Surinkta") + " " + copy.captured(entry.snapshot.updatedAt))
                .font(.caption).foregroundStyle(.secondary)
            if entry.collectionStatus != .complete {
                Label(entry.collectionStatus == .partial
                      ? copy.text("Collection incomplete", "Surinkti ne visi duomenys")
                      : copy.text("Last refresh failed", "Paskutinį kartą atnaujinti nepavyko"), systemImage: "exclamationmark.circle")
                    .font(.caption).foregroundStyle(.orange)
            } else if Date().timeIntervalSince(entry.snapshot.updatedAt) > 86400 {
                Label(copy.text("Snapshot older than 24 hours", "Duomenys senesni nei 24 val."), systemImage: "clock")
                    .font(.caption).foregroundStyle(.secondary)
            }
            if let change = period.previousWeekChange(for: entry) {
                Text((change >= 0 ? "+" : "") + change.formatted(.percent.precision(.fractionLength(0)).locale(copy.locale))
                     + " " + copy.text("vs previous 7 days", "palyginti su ankstesnėmis 7 dienomis"))
                    .font(.caption).foregroundStyle(.secondary)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(18).background(color(entry.source).opacity(0.09), in: RoundedRectangle(cornerRadius: 20))
    }
    private func dayRow(_ day: String) -> some View {
        ViewThatFits(in: .horizontal) {
            HStack {
                Text(copy.day(day)).fontWeight(.medium)
                Spacer(minLength: 16)
                readings(day)
            }
            VStack(alignment: .leading, spacing: 8) {
                Text(copy.day(day)).fontWeight(.medium)
                readings(day)
            }
        }
        .font(.caption)
    }
    private func readings(_ day: String) -> some View {
        HStack(spacing: 16) {
            ForEach(period.entries, id: \.source) { entry in
                Text(name(entry.source) + " " + (period.tokens(for: entry, day: day).map(copy.number) ?? "—"))
                    .monospacedDigit().foregroundStyle(color(entry.source))
                    .accessibilityLabel(name(entry.source) + ": " + (period.tokens(for: entry, day: day).map(copy.number) ?? copy.text("No reading", "Duomenų nėra")))
            }
        }
    }
}
