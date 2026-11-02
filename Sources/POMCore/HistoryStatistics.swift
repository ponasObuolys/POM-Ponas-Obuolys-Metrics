import Foundation

/// Uses provider date labels unchanged. Missing buckets in completed collections are zero.
public struct HistoryStatistics: Equatable, Sendable {
    public let average: Double
    public let recentKeys: [String]
    public let previousKeys: [String]
    public let recentTotal: Int64
    public let previousTotal: Int64
    public var change: Int64 { recentTotal - previousTotal }
    public var percentageChange: Double? {
        previousTotal == 0 ? nil : Double(change) / Double(previousTotal) * 100
    }

    public init(snapshot: TokenUsageSnapshot, days: Int, now: Date = Date()) {
        let yesterday = UsageDay.calendar.date(byAdding: .day, value: -1, to: now)!
        recentKeys = UsageDay.keys(days: 7, now: yesterday)
        previousKeys = UsageDay.keys(days: 7, now: UsageDay.calendar.date(byAdding: .day, value: -7, to: yesterday)!)
        let values = Dictionary(snapshot.days.map { ($0.day, $0.tokens) }, uniquingKeysWith: max)
        func sum(_ keys: [String]) -> Int64 { keys.reduce(0) { $0 + (values[$1] ?? 0) } }
        let completed = Array(UsageDay.keys(days: days, now: now).dropLast())
        average = completed.isEmpty ? 0 : Double(sum(completed)) / Double(completed.count)
        recentTotal = sum(recentKeys)
        previousTotal = sum(previousKeys)
    }

    public static func isAvailable(snapshot: TokenUsageSnapshot?, busy: Bool, unavailable: Bool,
                                   skippedLines: Int = 0, now: Date = Date()) -> Bool {
        guard let snapshot, !busy, !unavailable, skippedLines == 0 else { return false }
        return UsageDay.key(snapshot.updatedAt) == UsageDay.key(now)
    }
}
