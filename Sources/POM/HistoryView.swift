import Charts
import POMCore
import SwiftUI

struct HistoryView: View {
    @ObservedObject var service: HistoryService
    @ObservedObject var settings: Settings
    @State private var days = 7
    @State private var selected: Date?
    @State private var visible = Set(HistorySeries.allCases)
    @State private var confirmClear = false

    private var start: Date { Date().addingTimeInterval(-Double(days) * 86400) }
    private var points: [HistoryPoint] { service.history.points.filter { $0.capturedAt >= start && visible.contains($0.series) } }
    private var available: [HistorySeries] {
        HistorySeries.allCases.filter { series in service.history.points.contains { $0.series == series } }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 22) {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 6) {
                    Text(settings.text("Naudojimo istorija", "Usage history"))
                        .font(.system(size: 25, weight: .semibold, design: .rounded))
                    Text(settings.text("Tavo limitų ritmas. Šiame kompiuteryje.", "Your usage over time. On this Mac."))
                        .foregroundStyle(.secondary)
                }
                Spacer()
                Picker(settings.text("Laikotarpis", "Period"), selection: $days) {
                    Text(settings.text("7 dienos", "7 days")).tag(7)
                    Text(settings.text("30 dienų", "30 days")).tag(30)
                }
                .pickerStyle(.segmented)
                .frame(width: 190)
            }

            if service.history.points.isEmpty {
                ContentUnavailableView {
                    Label(settings.text("Istorija prasideda dabar", "Your history starts here"), systemImage: "chart.xyaxis.line")
                } description: {
                    Text(settings.text("POM išsaugos naujai gautus limitų duomenis. Ankstesnių dienų duomenys paslaugų atsakymuose nepateikiami.",
                                       "POM will save new usage readings. The providers do not include past days in their responses."))
                }
                .frame(maxWidth: .infinity, minHeight: 330)
            } else {
                HStack(spacing: 8) {
                    ForEach(available, id: \.self) { series in
                        Button {
                            if visible.contains(series) { if visible.intersection(available).count > 1 { visible.remove(series) } }
                            else { visible.insert(series) }
                        } label: {
                            HStack(spacing: 6) {
                                Circle().fill(series.color).frame(width: 7, height: 7)
                                Text(series.title(settings.language)).font(.system(size: 11, weight: .medium))
                            }
                            .padding(.horizontal, 10).padding(.vertical, 7)
                            .background(series.color.opacity(visible.contains(series) ? 0.13 : 0.03), in: Capsule())
                            .opacity(visible.contains(series) ? 1 : 0.5)
                        }
                        .buttonStyle(.plain)
                        .accessibilityAddTraits(visible.contains(series) ? .isSelected : [])
                    }
                }

                chart
                    .frame(height: 275)
                    .padding(18)
                    .background(Color.primary.opacity(0.025), in: RoundedRectangle(cornerRadius: 16))

                HStack(alignment: .top, spacing: 16) {
                    ForEach(available.filter { visible.contains($0) }, id: \.self) { series in
                        let seriesPoints = points.filter { $0.series == series }
                        let value = selected.flatMap { date in
                            seriesPoints.min { abs($0.capturedAt.timeIntervalSince(date)) < abs($1.capturedAt.timeIntervalSince(date)) }
                        } ?? seriesPoints.last
                        VStack(alignment: .leading, spacing: 6) {
                            Text(series.title(settings.language)).font(.system(size: 11)).foregroundStyle(.secondary)
                            Text(value.map { "\(Int($0.percentage.rounded()))%" } ?? "—")
                                .font(.system(size: 28, weight: .semibold, design: .rounded)).foregroundStyle(series.color)
                            Text(value.map { settings.language.absolute($0.capturedAt) } ?? settings.text("Duomenų nėra", "No readings"))
                                .font(.system(size: 10)).foregroundStyle(.secondary)
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                    }
                }
            }
            Spacer(minLength: 0)
            HStack(alignment: .bottom) {
                VStack(alignment: .leading, spacing: 4) {
                    Text(settings.text("Sunaudoto limito procentai · saugoma 30 dienų", "Percentage of limit used · stored for 30 days"))
                    Text(settings.text("Tarpai žymi laiką be duomenų arba naują limito laikotarpį.", "Gaps mark missing readings or a new limit period."))
                    if service.saveFailed {
                        Text(settings.text("Nepavyko išsaugoti istorijos. Patikrink laisvą vietą diske.", "Could not save history. Check available disk space.")).foregroundStyle(.orange)
                    }
                }
                .font(.system(size: 11)).foregroundStyle(.secondary)
                Spacer()
                Button(settings.text("Išvalyti istoriją…", "Clear history…")) { confirmClear = true }
                    .font(.system(size: 11))
                    .disabled(service.history.points.isEmpty)
            }
        }
        .padding(28)
        .frame(minWidth: 780, idealWidth: 840, minHeight: 660)
        .environment(\.locale, settings.locale)
        .onChange(of: days) { _, _ in selected = nil }
        .alert(settings.text("Išvalyti šiame kompiuteryje saugomą istoriją?", "Clear the usage history stored on this Mac?"), isPresented: $confirmClear) {
            Button(settings.text("Atšaukti", "Cancel"), role: .cancel) {}
            Button(settings.text("Išvalyti", "Clear"), role: .destructive) { service.clear(); selected = nil }
        }
    }

    private struct Sample: Identifiable {
        let point: HistoryPoint
        let segment: String
        var id: String { point.id }
    }

    private var chartSamples: [Sample] {
        available.filter { visible.contains($0) }.flatMap { series in
            service.history.segments(for: series, since: start).enumerated().flatMap { index, segment in
                // Keep first, last and peak per hour: bounded charts without losing spikes.
                let buckets = Dictionary(grouping: segment) { Int($0.capturedAt.timeIntervalSince1970 / 3600) }
                return buckets.keys.sorted().flatMap { hour -> [Sample] in
                    let values = buckets[hour]!
                    let candidates = [values.first!, values.max { $0.percentage < $1.percentage }!, values.last!]
                    var ids = Set<String>()
                    return candidates.sorted { $0.capturedAt < $1.capturedAt }.filter { ids.insert($0.id).inserted }
                        .map { Sample(point: $0, segment: "\(series.rawValue)-\(index)") }
                }
            }
        }
    }

    private var chart: some View {
        Chart {
            ForEach(chartSamples) { sample in
                LineMark(x: .value("Date", sample.point.capturedAt), y: .value("%", sample.point.percentage),
                         series: .value("Period", sample.segment))
                    .foregroundStyle(sample.point.series.color)
                    .lineStyle(StrokeStyle(lineWidth: 2))
                    .interpolationMethod(.linear)
                    .accessibilityLabel(sample.point.series.title(settings.language))
                    .accessibilityValue("\(Int(sample.point.percentage))%")
                PointMark(x: .value("Date", sample.point.capturedAt), y: .value("%", sample.point.percentage))
                    .foregroundStyle(sample.point.series.color).symbolSize(9)
            }
            if let selected {
                RuleMark(x: .value("Selected", selected))
                    .foregroundStyle(Color.secondary.opacity(0.4)).lineStyle(StrokeStyle(dash: [4, 4]))
            }
        }
        .chartXScale(domain: start...Date())
        .chartYScale(domain: 0...max(100, points.map(\.percentage).max() ?? 100))
        .chartYAxis { AxisMarks(position: .leading, values: [0, 25, 50, 75, 100]) { value in
            AxisGridLine().foregroundStyle(Color.secondary.opacity(0.1))
            AxisValueLabel { if let number = value.as(Int.self) { Text("\(number)%") } }
        } }
        .chartXAxis { AxisMarks(values: .stride(by: .day, count: days == 7 ? 1 : 5)) { _ in
            AxisValueLabel(format: .dateTime.month(.abbreviated).day())
        } }
        .chartXSelection(value: $selected)
        .chartLegend(.hidden)
    }
}

extension HistorySeries {
    var color: Color {
        switch self {
        case .claudeSession: return .orange
        case .claudeWeekly: return Color(red: 0.7, green: 0.4, blue: 0.95)
        case .fableWeekly: return .blue
        case .codexWeekly: return Color(red: 0.15, green: 0.68, blue: 0.47)
        }
    }
}
