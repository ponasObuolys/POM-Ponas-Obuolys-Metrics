import Foundation

/// Grok Bot reports each day's share of the weekly limit, never tokens, and only for
/// the running weekly period. POM keeps those shares so finished weeks stay visible.
/// Response shape verified against the installed Grok Bot's DashboardService definitions
/// and one live reading on 2026-11-25.
public struct GrokBotDailyUsage: Codable, Equatable, Sendable {
    public static let maximumBytes = 64 * 1024
    private static let millionth = 1_000_000.0

    /// One weekly period as the server reports it: parts per million of the limit per UTC day.
    public struct Period: Equatable, Sendable {
        public let startMs: Int64
        public let days: [String: Int64]
        public init(startMs: Int64, days: [String: Int64]) { self.startMs = startMs; self.days = days }
    }

    public struct Share: Codable, Equatable, Sendable {
        public let periodStartMs: Int64
        public let day: String
        public let ppm: Int64
    }

    /// Account fingerprint; another account's shares are never mixed in.
    public let identity: String
    public private(set) var shares: [Share]
    public private(set) var updatedAt: Date

    public init(identity: String, updatedAt: Date) {
        self.identity = identity; self.updatedAt = updatedAt; shares = []
    }

    private struct Response: Decodable { let weeklyLimitPpm: Splits? }
    private struct Splits: Decodable { let periodStartMs: Milliseconds?; let bySource: [Row]? }
    private struct Row: Decodable { let dayMs: Milliseconds?; let ppm: Int64? }
    /// Connect JSON writes 64-bit integers as strings.
    private struct Milliseconds: Decodable {
        let value: Int64
        init(from decoder: Decoder) throws {
            let container = try decoder.singleValueContainer()
            if let text = try? container.decode(String.self) {
                guard let number = Int64(text) else {
                    throw DecodingError.dataCorruptedError(in: container, debugDescription: "not an integer")
                }
                value = number
            } else { value = try container.decode(Int64.self) }
        }
    }

    /// Plans billed in money or by billing-cycle share use other units and stay unavailable.
    public static func parse(_ data: Data, now: Date = Date()) throws -> Period {
        guard data.count <= CursorUsageParser.maximumBytes,
              let response = try? JSONDecoder().decode(Response.self, from: data),
              let splits = response.weeklyLimitPpm, let start = splits.periodStartMs?.value,
              start > 0, Double(start) / 1000 <= now.timeIntervalSince1970 + 60 else {
            throw CursorClient.ClientError.invalidResponse
        }
        var days: [String: Int64] = [:]
        for row in splits.bySource ?? [] {
            let ppm = row.ppm ?? 0
            // The reset day belongs to two periods, so a day may start before its period.
            guard let day = row.dayMs?.value, day > start - 86_400_000,
                  Double(day) / 1000 <= now.timeIntervalSince1970 + 86400,
                  (0...1_000_000_000).contains(ppm) else { throw CursorClient.ClientError.invalidResponse }
            days[UsageDay.key(Date(timeIntervalSince1970: Double(day) / 1000)), default: 0] += ppm
        }
        return Period(startMs: start, days: days)
    }

    /// The server's latest view of a period replaces the saved one; other periods are kept for 30 days.
    public mutating func merge(_ period: Period, now: Date = Date()) {
        let oldest = UsageDay.keys(days: 30, now: now).first!
        shares.removeAll { $0.periodStartMs == period.startMs || $0.day < oldest }
        shares += period.days.filter { $0.key >= oldest }
            .map { Share(periodStartMs: period.startMs, day: $0.key, ppm: $0.value) }
        shares.sort { ($0.day, $0.periodStartMs) < ($1.day, $1.periodStartMs) }
        updatedAt = now
    }

    /// Percent of the weekly limit per day. A reset day adds the parts of both periods.
    public func percentages(days count: Int, now: Date = Date()) -> [String: Double] {
        let keys = Set(UsageDay.keys(days: count, now: now))
        var result: [String: Double] = [:]
        for share in shares where keys.contains(share.day) {
            result[share.day, default: 0] += Double(share.ppm) / Self.millionth * 100
        }
        return result
    }

    public func total(days count: Int, now: Date = Date()) -> Double {
        percentages(days: count, now: now).values.reduce(0, +)
    }

    /// Earlier days were never collected; they are unknown, not zero.
    public var firstDay: String? { shares.first?.day }

    public static func load(from url: URL) -> Self? {
        guard let size = try? url.resourceValues(forKeys: [.fileSizeKey]).fileSize, size <= maximumBytes,
              let data = try? Data(contentsOf: url) else { return nil }
        return try? JSONDecoder().decode(Self.self, from: data)
    }
}
