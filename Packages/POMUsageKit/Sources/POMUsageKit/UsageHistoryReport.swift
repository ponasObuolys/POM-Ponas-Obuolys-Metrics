import Foundation

/// A bounded transfer format containing only usage summaries, never prompts,
/// credentials, account identifiers or filesystem paths. Import does not expand
/// the original source's coverage. Reports must not be blindly added together.
public struct UsageHistoryReport: Codable, Equatable, Sendable {
    public static let maximumBytes = 256 * 1024
    public let schemaVersion: Int
    public let generatedAt: Date
    public let entries: [Entry]

    public enum Source: String, Codable, Sendable {
        /// Claude Code sessions on the exporting Mac, not all Claude use.
        case claudeCodeLocal = "claude_code_local"
        /// Account buckets obtained through the signed-in Codex CLI on the Mac.
        case codexAccount = "codex_account"
    }

    public enum CollectionStatus: String, Codable, Sendable {
        /// Collection completed. Coverage is still determined by source.
        case complete
        case partial
        case refreshFailed = "refresh_failed"
    }

    public struct Entry: Codable, Equatable, Sendable {
        public let source: Source
        public let collectionStatus: CollectionStatus
        public let snapshot: TokenUsageSnapshot
        public init(source: Source, collectionStatus: CollectionStatus, snapshot: TokenUsageSnapshot) {
            self.source = source
            self.collectionStatus = collectionStatus
            self.snapshot = snapshot
        }
    }

    public enum ReportError: Error, Equatable {
        case unsupportedSchema, tooLarge, invalidDate, invalidEntries, invalidTokens
    }

    public init(generatedAt: Date = Date(), entries: [Entry]) throws {
        schemaVersion = 1
        self.generatedAt = generatedAt
        self.entries = entries
        try validate()
    }

    private enum CodingKeys: String, CodingKey { case schemaVersion, generatedAt, entries }

    public init(from decoder: Decoder) throws {
        let values = try decoder.container(keyedBy: CodingKeys.self)
        schemaVersion = try values.decode(Int.self, forKey: .schemaVersion)
        guard schemaVersion == 1 else { throw ReportError.unsupportedSchema }
        generatedAt = try values.decode(Date.self, forKey: .generatedAt)
        entries = try values.decode([Entry].self, forKey: .entries)
        try validate()
    }

    public static func decode(_ data: Data) throws -> Self {
        guard data.count <= maximumBytes else { throw ReportError.tooLarge }
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .custom { decoder in
            let value = try decoder.singleValueContainer().decode(String.self)
            let formatter = ISO8601DateFormatter()
            // Foundation otherwise normalizes impossible dates such as Feb 30.
            guard value.utf8.count == 20, let date = formatter.date(from: value),
                  formatter.string(from: date) == value else { throw ReportError.invalidDate }
            return date
        }
        return try decoder.decode(Self.self, from: data)
    }

    public func encoded() throws -> Data {
        try validate()
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        let data = try encoder.encode(self)
        guard data.count <= Self.maximumBytes else { throw ReportError.tooLarge }
        return data
    }

    private func validate() throws {
        guard schemaVersion == 1 else { throw ReportError.unsupportedSchema }
        let validDates: ClosedRange<TimeInterval> = 0...253_402_214_400 // 9999-12-31 UTC
        guard validDates.contains(generatedAt.timeIntervalSince1970) else { throw ReportError.invalidDate }
        guard (1...2).contains(entries.count), Set(entries.map(\.source)).count == entries.count else {
            throw ReportError.invalidEntries
        }
        for entry in entries {
            let snapshot = entry.snapshot
            guard validDates.contains(snapshot.updatedAt.timeIntervalSince1970),
                  snapshot.updatedAt <= generatedAt.addingTimeInterval(60) else { throw ReportError.invalidDate }
            let allowedDays = Set(UsageDay.keys(days: 30, now: snapshot.updatedAt))
            guard snapshot.days.count <= 30,
                  Set(snapshot.days.map(\.day)).count == snapshot.days.count else { throw ReportError.invalidEntries }
            for day in snapshot.days {
                guard allowedDays.contains(day.day) else { throw ReportError.invalidDate }
                guard (0...1_000_000_000_000_000).contains(day.tokens) else { throw ReportError.invalidTokens }
            }
        }
    }
}
