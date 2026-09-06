import Foundation

public struct TokenDay: Codable, Equatable, Identifiable, Sendable {
    public let day: String
    public let tokens: Int64
    public var id: String { day }
    public init(day: String, tokens: Int64) { self.day = day; self.tokens = tokens }
}

/// Date-only buckets. Claude is grouped in UTC; Codex supplies its own day labels
/// without timezone metadata. Never shift a provider's date-only bucket locally.
public enum UsageDay {
    public static var calendar: Calendar {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 0)!
        return calendar
    }
    public static func key(_ date: Date) -> String {
        let c = calendar.dateComponents([.year, .month, .day], from: date)
        return String(format: "%04d-%02d-%02d", c.year!, c.month!, c.day!)
    }
    public static func date(_ key: String) -> Date? {
        let parts = key.split(separator: "-").compactMap { Int($0) }
        guard parts.count == 3, let date = calendar.date(from: DateComponents(year: parts[0], month: parts[1], day: parts[2])),
              Self.key(date) == key else { return nil }
        return date
    }
    public static func keys(days: Int, now: Date = Date()) -> [String] {
        (0..<days).reversed().map { key(calendar.date(byAdding: .day, value: -$0, to: now)!) }
    }
}

public struct TokenUsageSnapshot: Codable, Equatable, Sendable {
    public let days: [TokenDay]
    public let updatedAt: Date
    public init(days: [TokenDay], updatedAt: Date) { self.days = days; self.updatedAt = updatedAt }

    public enum ParseError: Error { case invalidResponse }
    public static func parseCodex(_ data: Data, now: Date = Date()) throws -> Self {
        struct Bucket: Decodable { let startDate: String; let tokens: Int64 }
        struct Result: Decodable { let dailyUsageBuckets: [Bucket] }
        struct Response: Decodable { let result: Result }
        let buckets = try JSONDecoder().decode(Response.self, from: data).result.dailyUsageBuckets
        var seen = Set<String>()
        for bucket in buckets {
            guard UsageDay.date(bucket.startDate) != nil, bucket.tokens >= 0, bucket.tokens <= 1_000_000_000_000_000,
                  seen.insert(bucket.startDate).inserted else { throw ParseError.invalidResponse }
        }
        let keys = Set(UsageDay.keys(days: 30, now: now))
        return Self(days: buckets.filter { keys.contains($0.startDate) }
            .map { TokenDay(day: $0.startDate, tokens: $0.tokens) }.sorted { $0.day < $1.day }, updatedAt: now)
    }

    public func total(days count: Int, now: Date = Date()) -> Int64 {
        let keys = Set(UsageDay.keys(days: count, now: now))
        return days.filter { keys.contains($0.day) }.reduce(0) { $0 + $1.tokens }
    }
}
