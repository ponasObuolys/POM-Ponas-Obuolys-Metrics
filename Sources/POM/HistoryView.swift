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
    @State private var visibleProviders: Set<String> = ["Claude", HistoryView.fableName, "Codex"]
    @State private var exporting = false
    @State private var exportFailed = false

    init(service: HistoryService, settings: Settings, days: Int = 7) {
        self.service = service; self.settings = settings
        _days = State(initialValue: days == 30 ? 30 : 7)
    }

    private var keys: [String] { UsageDay.keys(days: days) }
    private var selectedKey: String? { selected.map(UsageDay.key).flatMap { keys.contains($0) ? $0 : nil } }
    private let green = Color(red: 0.15, green: 0.68, blue: 0.47)
    private let purple = Color(red: 0.62, green: 0.47, blue: 0.9)
    private let blue = Color(red: 0.33, green: 0.56, blue: 0.93)
    /// Both model families draw on the same separate weekly limit.
    private static let fableName = "Fable / Mythos"
    private static let axisLabelWidth: CGFloat = 52

    private struct Series: Identifiable {
        let name: String; let color: Color; let dash: [CGFloat]; let snapshot: TokenUsageSnapshot?
        var id: String { name }
    }
    private var series: [Series] {
        [Series(name: "Claude", color: .orange, dash: [], snapshot: service.claude),
         Series(name: Self.fableName, color: purple, dash: [2, 3], snapshot: service.claudeFable),
         Series(name: "Codex", color: green, dash: [6, 4], snapshot: service.codex)]
    }
    private var visibleSeries: [Series] { series.filter { visibleProviders.contains($0.name) } }
    /// Shown once there is something to show or the user asked for Grok Bot's server readings.
    private var showsGrokBot: Bool { service.grokBot != nil || settings.grokBotServerEnabled }

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
                          busy: service.importing, unavailable: service.claudeUnavailable, detail: fableShare)
                totalCard(name: "Codex", source: .codex, snapshot: service.codex, color: green,
                          coverage: settings.text("Codex paskyra", "Codex account"),
                          busy: service.fetchingCodex, unavailable: service.codexUnavailable)
                if showsGrokBot { grokBotCard }
            }.fixedSize(horizontal: false, vertical: true)

            HStack(spacing: 16) {
                ForEach(series.map(\.name), id: \.self) { provider in
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
                chart.frame(height: 190).padding(18)
                    .background(Color.primary.opacity(0.025), in: RoundedRectangle(cornerRadius: 16))
            }
            if showsGrokBot {
                VStack(alignment: .leading, spacing: 10) {
                    Text(settings.text("Grok Bot · savaitės limito dalis per dieną", "Grok Bot · share of the weekly limit per day"))
                        .font(.system(size: 12, weight: .medium))
                    grokBotChart.frame(height: 90)
                }
                .padding(18).background(Color.primary.opacity(0.025), in: RoundedRectangle(cornerRadius: 16))
            }

            HStack {
                Text(selectedKey.map(dayTitle) ?? settings.text("Pasirink dieną grafike", "Select a day in the chart"))
                    .foregroundStyle(.secondary)
                Spacer()
                if let key = selectedKey {
                    ForEach(visibleSeries) { item in
                        Text("\(item.name)  \(dayTokens(item.snapshot, key))").foregroundStyle(item.color).padding(.leading, 16)
                    }
                    if showsGrokBot {
                        Text("Grok Bot  \(service.grokBot?.percentages(days: days)[key].map(percent) ?? "—")")
                            .foregroundStyle(blue).padding(.leading, 16)
                    }
                }
            }.font(.system(size: 12, weight: .medium)).monospacedDigit()
                }
            }
            HStack(alignment: .bottom) {
                VStack(alignment: .leading, spacing: 5) {
                    Text(settings.text("Įvestis, išvestis ir podėlio tokenai. Šiandienos duomenys dar pildomi.",
                                       "Input, output and cached tokens. Today's totals are still growing."))
                    Text(settings.text("Claude dienos skaičiuojamos UTC laiku, Codex dienas pateikia pati paslauga.",
                                       "Claude days use UTC; Codex dates are supplied by the service."))
                    Text(settings.text("Atnaujinama kas 15 min. Claude naršyklės ir kitų įrenginių naudojimas neįtrauktas.",
                                       "Updates every 15 min. Claude web and other devices are not included."))
                    if showsGrokBot {
                        Text(settings.text("Grok Bot rodo tik einamąją savaitę, todėl ankstesnės kaupiamos šiame Mac.",
                                           "Grok Bot reports the current week only, so earlier weeks are kept on this Mac."))
                    }
                    if service.skippedLines > 0 {
                        Text(settings.text("Dalies Claude įrašų nepavyko perskaityti, todėl suma gali būti mažesnė.",
                                           "Some Claude records could not be read; the total may be incomplete.")).foregroundStyle(.orange)
                    }
                }.font(.system(size: 11)).foregroundStyle(.secondary)
                Spacer(minLength: 12)
                Menu(settings.text("Eksportuoti…", "Export…")) {
                    Button("JSON…") { exportHistory(csv: false) }
                    Button("CSV…") { exportHistory(csv: true) }
                }
                    .help(settings.text("Išsaugoti pasirinkto laikotarpio Claude ir Codex tokenų suvestines.",
                                        "Save Claude and Codex token summaries for the selected period."))
                    .disabled(exporting || (service.claude == nil && service.codex == nil))
                Button(settings.text("Atnaujinti", "Refresh")) { service.refresh() }
                    .disabled(service.importing || service.fetchingCodex || service.fetchingGrokBot)
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
            panel.message = settings.text("\(days) dienų Claude ir Codex tokenų suvestinės su šaltiniu ir atnaujinimo laiku. Pokalbių ir prisijungimo duomenų nėra.",
                                          "\(days)-day Claude and Codex token summaries with source and update time. No conversations or credentials.")
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
                           coverage: String, busy: Bool, unavailable: Bool, detail: String? = nil) -> some View {
        card(name: name, source: source, color: color, busy: busy, unavailable: unavailable,
             value: snapshot.map { number($0.total(days: days)) },
             caption: settings.text("tokenų per \(days) d.", "tokens over \(days) days"), coverage: coverage,
             status: status(snapshot: snapshot, source: source, busy: busy, unavailable: unavailable)) {
            if let detail { Text(detail).font(.system(size: 11, weight: .medium)).foregroundStyle(purple) }
            statistics(snapshot: snapshot, source: source, busy: busy, unavailable: unavailable)
        }
    }

    /// Cards in one row share the height of the tallest, so their edges line up.
    private func card<Details: View>(name: String, source: MenuBarSource, color: Color, busy: Bool, unavailable: Bool,
                                     value: String?, caption: String, coverage: String, status: String,
                                     @ViewBuilder details: () -> Details) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 8) {
                ProviderMarkView(source: source).frame(width: 17, height: 17)
                Text(name).font(.system(size: 14, weight: .semibold))
                Spacer()
                if busy { ProgressView().controlSize(.small) }
            }
            Text(value ?? "—")
                .font(.system(size: 30, weight: .semibold, design: .rounded)).foregroundStyle(color)
                .monospacedDigit().lineLimit(1).minimumScaleFactor(0.5)
            Text(caption).font(.system(size: 11)).foregroundStyle(.secondary)
            details()
            Spacer(minLength: 0)
            Text(coverage).font(.system(size: 12, weight: .medium))
            Text(status)
                .font(.system(size: 10)).foregroundStyle(unavailable ? .orange : .secondary)
                .lineLimit(2).frame(minHeight: 14, alignment: .top)
        }
        .padding(16).frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .background(color.opacity(0.07), in: RoundedRectangle(cornerRadius: 14))
    }

    private var fableShare: String? {
        guard let claude = service.claude, let fable = service.claudeFable else { return nil }
        let total = claude.total(days: days), part = fable.total(days: days)
        let share = total > 0 ? " (" + percent(Double(part) / Double(total) * 100) + ")" : ""
        return settings.text("Iš jų \(Self.fableName): ", "Of which \(Self.fableName): ") + number(part) + share
    }

    private var grokBotCard: some View {
        let usage = service.grokBot
        let failed = service.grokBotUnavailable && settings.grokBotServerEnabled
        let status: String
        if service.fetchingGrokBot { status = settings.text("Gaunami paskyros duomenys…", "Fetching account usage…") }
        else if !settings.grokBotServerEnabled {
            status = settings.text("Nepildoma, kol išjungta \"Grok Bot iš serverio\"", "Paused while \"Grok Bot from server\" is off")
        } else if failed {
            status = usage == nil ? settings.text("Duomenys neprieinami", "Data unavailable")
                : settings.text("Atnaujinti nepavyko · rodomi išsaugoti duomenys", "Update unavailable · showing saved data")
        } else {
            status = usage.map { settings.text("Atnaujinta ", "Updated ") + settings.language.absolute($0.updatedAt) }
                ?? settings.text("Duomenų dar nėra", "No data yet")
        }
        return card(name: "Grok Bot", source: .grokBot, color: blue, busy: service.fetchingGrokBot, unavailable: failed,
                    value: usage.map { percent($0.total(days: days)) },
                    caption: settings.text("savaitės limito per \(days) d.", "of the weekly limit over \(days) days"),
                    coverage: settings.text("Grok Bot paskyra", "Grok Bot account"), status: status) {
            Text(settings.text("Limito dalis, ne tokenai. 100 % yra visas savaitės limitas.",
                               "A share of the limit, not tokens. 100% is one full weekly limit."))
                .font(.system(size: 11)).foregroundStyle(.secondary)
            if let first = usage?.firstDay, first > keys.first! {
                Text(settings.text("Kaupiama nuo \(dayTitle(first))", "Collected since \(dayTitle(first))"))
                    .font(.system(size: 10)).foregroundStyle(.secondary)
            }
        }
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
        visibleSeries.flatMap { item -> [Sample] in
            guard let snapshot = item.snapshot else { return [] }
            let values = Dictionary(snapshot.days.map { ($0.day, $0.tokens) }, uniquingKeysWith: max)
            return keys.filter { $0 <= UsageDay.key(snapshot.updatedAt) }
                .map { Sample(provider: item.name, day: $0, tokens: values[$0] ?? 0) }
        }
    }
    private var chart: some View {
        Chart {
            ForEach(samples) { sample in
                LineMark(x: .value("Day", sample.date), y: .value("Tokens", sample.tokens))
                    .foregroundStyle(by: .value("Provider", sample.provider))
                    .lineStyle(StrokeStyle(lineWidth: 2, dash: series.first { $0.name == sample.provider }?.dash ?? [])).interpolationMethod(.linear)
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
        .chartForegroundStyleScale(domain: series.map(\.name), range: series.map(\.color))
        .chartLegend(position: .bottom)
        .chartXScale(domain: UsageDay.date(keys.first!)!...UsageDay.date(keys.last!)!, range: .plotDimension(padding: 24))
        .chartYScale(domain: 0...max(1, samples.map(\.tokens).max() ?? 1))
        .chartYAxis { AxisMarks(position: .leading) { value in
            AxisGridLine().foregroundStyle(Color.secondary.opacity(0.1))
            AxisValueLabel { if let value = value.as(Int64.self) {
                Text(value, format: .number.notation(.compactName)).frame(width: Self.axisLabelWidth, alignment: .trailing)
            } }
        } }
        .chartXAxis { dayAxis }
        .chartXSelection(value: $selected)
    }

    /// Bars instead of a line: the unit differs from the token chart above, and uncollected days stay empty.
    private var grokBotChart: some View {
        let values = service.grokBot?.percentages(days: days) ?? [:]
        return Chart {
            ForEach(keys.filter { values[$0] != nil }, id: \.self) { key in
                BarMark(x: .value("Day", UsageDay.date(key)!), y: .value("Share", values[key]!), width: .fixed(days == 7 ? 26 : 10))
                    .foregroundStyle(blue).cornerRadius(3)
                    .accessibilityLabel("Grok Bot, \(dayTitle(key))").accessibilityValue(percent(values[key]!))
            }
            if let key = selectedKey {
                RuleMark(x: .value("Selected", UsageDay.date(key)!))
                    .foregroundStyle(Color.secondary.opacity(0.4)).lineStyle(StrokeStyle(dash: [4, 4]))
            }
        }
        .chartXScale(domain: UsageDay.date(keys.first!)!...UsageDay.date(keys.last!)!, range: .plotDimension(padding: 24))
        .chartYScale(domain: 0...max(1, values.values.max() ?? 1))
        .chartYAxis { AxisMarks(position: .leading, values: .automatic(desiredCount: 3)) { value in
            AxisGridLine().foregroundStyle(Color.secondary.opacity(0.1))
            AxisValueLabel { if let value = value.as(Double.self) {
                Text(percent(value, fraction: 0)).frame(width: Self.axisLabelWidth, alignment: .trailing)
            } }
        } }
        .chartXAxis { dayAxis }
        .chartXSelection(value: $selected)
    }

    /// One label per point, centred under it; both charts share it so their days line up.
    private var dayAxis: some AxisContent {
        AxisMarks(values: keys.enumerated().filter { days == 7 || $0.offset % 5 == 0 || $0.offset == days - 1 }.compactMap { UsageDay.date($0.element) }) { value in
            AxisValueLabel(centered: false, anchor: .top, collisionResolution: .disabled) {
                if let date = value.as(Date.self) { Text(dayTitle(UsageDay.key(date))).fixedSize() }
            }
        }
    }
    private func percent(_ value: Double) -> String { percent(value, fraction: 1) }
    private func percent(_ value: Double, fraction: Int) -> String {
        value.formatted(.number.precision(.fractionLength(fraction)).locale(settings.locale)) + " %"
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
