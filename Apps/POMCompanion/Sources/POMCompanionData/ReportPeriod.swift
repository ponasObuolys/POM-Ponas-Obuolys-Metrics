import Foundation
import POMUsageKit

/// Periods end at the report's export date, so an old report never silently becomes zero today.
public struct ReportPeriod: Sendable {
    public let keys: [String]
    public let entries: [UsageHistoryReport.Entry]
    public init(report: UsageHistoryReport, days: Int) {
        keys = UsageDay.keys(days: days == 7 ? 7 : 30, now: report.generatedAt)
        entries = report.entries.sorted { $0.source.rawValue < $1.source.rawValue }
    }
    public func records(for entry: UsageHistoryReport.Entry) -> [TokenDay] {
        let included = Set(keys)
        return entry.snapshot.days.filter { included.contains($0.day) }.sorted { $0.day < $1.day }
    }
    public func total(for entry: UsageHistoryReport.Entry) -> Int64? {
        let values = records(for: entry)
        return values.isEmpty ? nil : values.reduce(0) { $0 + $1.tokens }
    }
    public func tokens(for entry: UsageHistoryReport.Entry, day: String) -> Int64? {
        entry.snapshot.days.first { $0.day == day && keys.contains(day) }?.tokens
    }

    /// Compare only when both weeks have readings for every day. The latest day may still be growing.
    public func previousWeekChange(for entry: UsageHistoryReport.Entry) -> Double? {
        guard keys.count == 7, entry.collectionStatus == .complete,
              let end = keys.last.flatMap(UsageDay.date),
              let previousEnd = UsageDay.calendar.date(byAdding: .day, value: -7, to: end) else { return nil }
        let previous = Set(UsageDay.keys(days: 7, now: previousEnd))
        let currentRecords = records(for: entry)
        let previousRecords = entry.snapshot.days.filter { previous.contains($0.day) }
        guard currentRecords.count == 7, previousRecords.count == 7 else { return nil }
        let before = previousRecords.reduce(Int64(0)) { $0 + $1.tokens }
        let after = currentRecords.reduce(Int64(0)) { $0 + $1.tokens }
        guard before > 0 else { return nil }
        return Double(after - before) / Double(before)
    }
}

public enum ExampleReport {
    /// Fictional data, generated locally and labelled as an example in every view.
    public static func make(now: Date = Date()) -> UsageHistoryReport {
        let keys = UsageDay.keys(days: 30, now: now)
        let entries = [UsageHistoryReport.Source.claudeCodeLocal, .codexAccount].enumerated().map { index, source in
            let values = keys.enumerated().map { offset, day in
                TokenDay(day: day, tokens: Int64([240_000, 620_000, 180_000, 960_000, 480_000, 720_000, 320_000][(offset + index * 2) % 7]))
            }
            return UsageHistoryReport.Entry(source: source, collectionStatus: .complete,
                snapshot: TokenUsageSnapshot(days: values, updatedAt: now))
        }
        // Generated values satisfy the same public format as actual exports.
        return try! UsageHistoryReport(generatedAt: now, entries: entries)
    }
}
