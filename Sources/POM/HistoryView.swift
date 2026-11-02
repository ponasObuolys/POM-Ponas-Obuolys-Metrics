import AppKit
import Charts
import POMCore
import SwiftUI
import UniformTypeIdentifiers

struct HistoryView: View {
    @ObservedObject var service: HistoryService
    @ObservedObject var settings: Settings
    @State private var days = 7
    @State private var selected: Date?
    @State private var visibleProviders: Set<String> = ["Claude", "Codex"]
    @State private var exporting = false
    @State private var exportFailed = false

    init(service: HistoryService, settings: Settings, days: Int = 7) {
        self.service = service; self.settings = settings
        _days = State(initialValue: days == 30 ? 30 : 7)
    }

    private var keys: [String] { UsageDay.keys(days: days) }
    private var selectedKey: String? { selected.map(UsageDay.key).flatMap { keys.contains($0) ? $0 : nil } }
    private let green = Color(red: 0.15, green: 0.68, blue: 0.47)

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 6) {
                    Text(settings.text("Naudojimo istorija", "Usage history"))
                        .font(.system(size: 25, weight: .semibold, design: .rounded))
                    Text(settings.text("Dienos tokenai · visi modeliai", "Daily tokens · all models"))
                        .foregroundStyle(.secondary)
                }
                Spacer()
                Picker(settings.text("Laikotarpis", "Period"), selection: $days) {
                    Text(settings.text("7 dienos", "7 days")).tag(7)
                    Text(settings.text("30 dienų", "30 days")).tag(30)
                }
                .pickerStyle(.segmented).frame(width: 240)
            }

            HStack(spacing: 16) {
                totalCard(name: "Claude", source: .claude, snapshot: service.claude, color: .orange,
                          coverage: settings.text("Claude Code · šiame Mac", "Claude Code · this Mac"),
                          busy: service.importing, unavailable: service.claudeUnavailable)
                totalCard(name: "Codex", source: .codex, snapshot: service.codex, color: green,
                          coverage: settings.text("Codex paskyra", "Codex account"),
                          busy: service.fetchingCodex, unavailable: service.codexUnavailable)
            }

            HStack(spacing: 16) {
                ForEach(["Claude", "Codex"], id: \.self) { provider in
                    Toggle(provider, isOn: Binding(get: { visibleProviders.contains(provider) }, set: { enabled in
                        if enabled { visibleProviders.insert(provider) }
                        else if visibleProviders.count > 1 { visibleProviders.remove(provider) }
                    }))
                    .disabled(visibleProviders == [provider])
                }
                Spacer()
            }.toggleStyle(.checkbox)

            if service.claude == nil && service.codex == nil {
                ContentUnavailableView {
                    Label(settings.text("Laukiama naudojimo duomenų", "Waiting for usage data"), systemImage: "chart.xyaxis.line")
                } description: {
                    Text(settings.text("Claude tokenai skaitomi iš vietinių Claude Code įrašų, Codex — iš prisijungtos paskyros.",
                                       "Claude tokens come from local Claude Code sessions; Codex tokens come from your signed-in account."))
                }.frame(maxWidth: .infinity, minHeight: 270)
            } else {
                chart.frame(height: 220).padding(18)
                    .background(Color.primary.opacity(0.025), in: RoundedRectangle(cornerRadius: 16))
            }

            HStack {
                Text(selectedKey.map(dayTitle) ?? settings.text("Pasirink dieną grafike", "Select a day in the chart"))
                    .foregroundStyle(.secondary)
                Spacer()
                if let key = selectedKey {
                    if visibleProviders.contains("Claude") { Text("Claude  \(dayTokens(service.claude, key))").foregroundStyle(.orange) }
                    if visibleProviders.contains("Codex") { Text("Codex  \(dayTokens(service.codex, key))").foregroundStyle(green).padding(.leading, 16) }
                }
            }.font(.system(size: 12, weight: .medium)).monospacedDigit()
                }
            }
            HStack(alignment: .bottom) {
                VStack(alignment: .leading, spacing: 5) {
                    Text(settings.text("Įvestis, išvestis ir podėlio tokenai. Šiandienos duomenys dar pildomi.",
                                       "Input, output and cached tokens. Today's totals are still growing."))
                    Text(settings.text("Claude dienos — UTC; Codex dienos — kaip pateikia paslauga.",
                                       "Claude days use UTC; Codex dates are supplied by the service."))
                    Text(settings.text("Atnaujinama kas 15 min. Claude naršyklės ir kitų įrenginių naudojimas neįtrauktas.",
                                       "Updates every 15 min. Claude web and other devices are not included."))
                    if service.skippedLines > 0 {
                        Text(settings.text("Dalies Claude įrašų nepavyko perskaityti — suma gali būti mažesnė.",
                                           "Some Claude records could not be read; the total may be incomplete.")).foregroundStyle(.orange)
                    }
                }.font(.system(size: 11)).foregroundStyle(.secondary)
                Spacer(minLength: 12)
                Menu(settings.text("Eksportuoti…", "Export…")) {
                    Button("JSON…") { exportHistory(csv: false) }
                    Button("CSV…") { exportHistory(csv: true) }
                }
                    .help(settings.text("Išsaugoti pasirinkto laikotarpio abiejų paslaugų suvestines.",
                                        "Save both providers for the selected period."))
                    .disabled(exporting || (service.claude == nil && service.codex == nil))
                Button(settings.text("Atnaujinti", "Refresh")) { service.refresh() }
                    .disabled(service.importing || service.fetchingCodex)
            }
        }
        .padding(24)
        .frame(minWidth: 780, idealWidth: 840, minHeight: 660)
        .environment(\.locale, settings.locale)
        .environment(\.timeZone, TimeZone(secondsFromGMT: 0)!)
        .onChange(of: days) { _, _ in selected = nil }
        .alert(settings.text("Nepavyko eksportuoti", "Export failed"), isPresented: $exportFailed) {
            Button(settings.text("Gerai", "OK"), role: .cancel) { }
        } message: {
            Text(settings.text("Patikrink, ar galima rašyti į pasirinktą aplanką ir ar naudojimo duomenys atnaujinti.",
                               "Check that the destination is writable and your usage data is up to date."))
        }
    }

    private func exportHistory(csv: Bool) {
        do {
            let now = Date()
            let data = try csv ? service.exportCSVData(days: days, now: now) : service.exportReportData(days: days, now: now)
            let panel = NSSavePanel()
            panel.allowedContentTypes = [csv ? .commaSeparatedText : .json]
            let interval = UsageDay.keys(days: days, now: now)
            panel.nameFieldStringValue = "POM-usage-\(interval.first!)-\(interval.last!).\(csv ? "csv" : "json")"
            panel.message = settings.text("\(days) dienų abiejų paslaugų suvestinės su šaltiniu ir atnaujinimo laiku. Pokalbių ir prisijungimo duomenų nėra.",
                                          "\(days)-day summaries for both providers with source and update time. No conversations or credentials.")
            exporting = true
            panel.begin { response in
                defer { exporting = false }
                guard response == .OK, let url = panel.url else { return }
                do { try data.write(to: url, options: .atomic) }
                catch { exportFailed = true }
            }
        } catch { exportFailed = true }
    }

    private func totalCard(name: String, source: MenuBarSource, snapshot: TokenUsageSnapshot?, color: Color,
                           coverage: String, busy: Bool, unavailable: Bool) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 8) {
                ProviderMarkView(source: source).frame(width: 17, height: 17)
                Text(name).font(.system(size: 14, weight: .semibold))
                Spacer()
                if busy { ProgressView().controlSize(.small) }
            }
            Text(snapshot.map { number($0.total(days: days)) } ?? "—")
                .font(.system(size: 30, weight: .semibold, design: .rounded)).foregroundStyle(color)
                .monospacedDigit().lineLimit(1).minimumScaleFactor(0.65)
            Text(settings.text("tokenų per \(days) d.", "tokens over \(days) days"))
                .font(.system(size: 11)).foregroundStyle(.secondary)
            statistics(snapshot: snapshot, source: source, busy: busy, unavailable: unavailable)
            Text(coverage).font(.system(size: 12, weight: .medium))
            Text(status(snapshot: snapshot, source: source, busy: busy, unavailable: unavailable))
                .font(.system(size: 10)).foregroundStyle(unavailable ? .orange : .secondary)
                .lineLimit(2).frame(minHeight: 14, alignment: .top)
        }
        .padding(16).frame(maxWidth: .infinity, alignment: .leading)
        .background(color.opacity(0.07), in: RoundedRectangle(cornerRadius: 14))
    }

    @ViewBuilder private func statistics(snapshot: TokenUsageSnapshot?, source: MenuBarSource,
                                         busy: Bool, unavailable: Bool) -> some View {
        if let snapshot, HistoryStatistics.isAvailable(snapshot: snapshot, busy: busy, unavailable: unavailable,
                                                       skippedLines: source == .claude ? service.skippedLines : 0) {
            let stats = HistoryStatistics(snapshot: snapshot, days: days)
            Text(settings.text("Vidurkis: ", "Average: ") + number(Int64(stats.average.rounded()))
                 + settings.text(" tokenų / užbaigtą dieną", " tokens / completed day"))
                .font(.system(size: 11)).foregroundStyle(.secondary)
            if days == 7 {
                Text(comparisonText(stats)).font(.system(size: 12, weight: .medium))
                Text("\(dayTitle(stats.recentKeys.first!))–\(dayTitle(stats.recentKeys.last!)) / \(dayTitle(stats.previousKeys.first!))–\(dayTitle(stats.previousKeys.last!))")
                    .font(.system(size: 10)).foregroundStyle(.secondary)
                Text(settings.text("Pagal prieinamus įrašus · be šiandienos", "Based on available records · excludes today"))
                    .font(.system(size: 10)).foregroundStyle(.secondary)
            }
        } else {
            Text(settings.text("Vidurkiui ir palyginimui reikia užbaigto, šiandien atnaujinto duomenų surinkimo.",
                               "Average and comparison need a completed collection refreshed today."))
                .font(.system(size: 11)).foregroundStyle(.secondary)
        }
    }

    private func comparisonText(_ stats: HistoryStatistics) -> String {
        let prefix = settings.text("7 užbaigtos dienos: ", "7 completed days: ")
        if let percent = stats.percentageChange {
            return prefix + (percent > 0 ? "+" : "") + percent.formatted(.number.precision(.fractionLength(1)).locale(settings.locale)) + " %"
        }
        return prefix + (stats.change > 0 ? "+" : "") + number(stats.change) + settings.text(" tokenų", " tokens")
    }

    private func status(snapshot: TokenUsageSnapshot?, source: MenuBarSource, busy: Bool, unavailable: Bool) -> String {
        if busy { return source == .claude
            ? settings.text("Importuojama mažomis porcijomis… Suma dar negalutinė.", "Importing in small batches… Totals are partial.")
            : settings.text("Gaunami paskyros duomenys…", "Fetching account usage…") }
        if unavailable { return snapshot == nil
            ? settings.text("Duomenys neprieinami", "Data unavailable")
            : settings.text("Atnaujinti nepavyko · rodomi išsaugoti duomenys", "Update unavailable · showing saved data") }
        return snapshot.map { settings.text("Atnaujinta ", "Updated ") + settings.language.absolute($0.updatedAt) }
            ?? settings.text("Duomenų dar nėra", "No data yet")
    }

    private struct Sample: Identifiable {
        let provider: String; let day: String; let tokens: Int64
        var id: String { provider + day }
        var date: Date { UsageDay.date(day)! }
    }
    private var samples: [Sample] {
        [("Claude", service.claude), ("Codex", service.codex)].flatMap { name, snapshot -> [Sample] in
            guard let snapshot, visibleProviders.contains(name) else { return [] }
            let values = Dictionary(snapshot.days.map { ($0.day, $0.tokens) }, uniquingKeysWith: max)
            return keys.filter { $0 <= UsageDay.key(snapshot.updatedAt) }
                .map { Sample(provider: name, day: $0, tokens: values[$0] ?? 0) }
        }
    }
    private var chart: some View {
        Chart {
            ForEach(samples) { sample in
                LineMark(x: .value("Day", sample.date), y: .value("Tokens", sample.tokens))
                    .foregroundStyle(by: .value("Provider", sample.provider))
                    .lineStyle(StrokeStyle(lineWidth: 2, dash: sample.provider == "Codex" ? [6, 4] : [])).interpolationMethod(.linear)
                PointMark(x: .value("Day", sample.date), y: .value("Tokens", sample.tokens))
                    .foregroundStyle(by: .value("Provider", sample.provider)).symbolSize(18)
                    .accessibilityLabel("\(sample.provider), \(dayTitle(sample.day))")
                    .accessibilityValue(number(sample.tokens))
            }
            if let key = selectedKey {
                RuleMark(x: .value("Selected", UsageDay.date(key)!))
                    .foregroundStyle(Color.secondary.opacity(0.4)).lineStyle(StrokeStyle(dash: [4, 4]))
            }
        }
        .chartForegroundStyleScale(["Claude": Color.orange, "Codex": green])
        .chartLegend(position: .bottom)
        .chartXScale(domain: UsageDay.date(keys.first!)!...UsageDay.date(keys.last!)!, range: .plotDimension(padding: 12))
        .chartYScale(domain: 0...max(1, samples.map(\.tokens).max() ?? 1))
        .chartYAxis { AxisMarks(position: .leading) { value in
            AxisGridLine().foregroundStyle(Color.secondary.opacity(0.1))
            AxisValueLabel { if let value = value.as(Int64.self) { Text(value, format: .number.notation(.compactName)) } }
        } }
        .chartXAxis { AxisMarks(values: keys.enumerated().filter { days == 7 || $0.offset % 5 == 0 || $0.offset == days - 1 }.compactMap { UsageDay.date($0.element) }) { value in
            AxisValueLabel(anchor: .top, collisionResolution: .disabled) {
                if let date = value.as(Date.self) { Text(dayTitle(UsageDay.key(date))).fixedSize() }
            }
        } }
        .chartXSelection(value: $selected)
    }
    private func number(_ value: Int64) -> String { value.formatted(.number.locale(settings.locale)) }
    private func dayTokens(_ snapshot: TokenUsageSnapshot?, _ key: String) -> String {
        guard let snapshot, key <= UsageDay.key(snapshot.updatedAt) else { return "—" }
        return number(snapshot.days.first { $0.day == key }?.tokens ?? 0)
    }
    private func dayTitle(_ key: String) -> String {
        var style = Date.FormatStyle().month(.abbreviated).day().locale(settings.locale)
        style.timeZone = TimeZone(secondsFromGMT: 0)!
        return UsageDay.date(key)!.formatted(style)
    }
}
