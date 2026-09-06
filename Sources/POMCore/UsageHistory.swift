import Foundation

public enum HistorySeries: String, Codable, CaseIterable, Sendable {
    case claudeSession, claudeWeekly, fableWeekly, codexWeekly
}

public struct HistoryPoint: Codable, Equatable, Identifiable, Sendable {
    public let series: HistorySeries
    public let capturedAt: Date
    public let percentage: Double
    public let resetsAt: Date?
    public var id: String { "\(series.rawValue):\(capturedAt.timeIntervalSince1970)" }
    public init(series: HistorySeries, capturedAt: Date, percentage: Double, resetsAt: Date?) {
        self.series = series; self.capturedAt = capturedAt; self.percentage = percentage; self.resetsAt = resetsAt
    }
}

/// Raw samples, at most one per minute per series, retained for 30 days. No model
/// content, account identifiers, tokens or inferred post-reset points are stored.
public struct UsageHistory: Sendable {
    public static let retention: TimeInterval = 30 * 86400
    public static let maximumPoints = 180_000
    public private(set) var points: [HistoryPoint]
    public init(points: [HistoryPoint] = [], now: Date = Date()) {
        var latest: [HistorySeries: HistoryPoint] = [:]
        self.points = points.sorted { $0.capturedAt < $1.capturedAt }.filter { point in
            guard point.percentage.isFinite, (0...100_000).contains(point.percentage),
                  point.capturedAt <= now.addingTimeInterval(60),
                  point.capturedAt >= now.addingTimeInterval(-Self.retention) else { return false }
            if let old = latest[point.series], point.capturedAt <= old.capturedAt { return false }
            latest[point.series] = point
            return true
        }
        self.points = Array(self.points.suffix(Self.maximumPoints))
    }

    @discardableResult
    public mutating func append(_ point: HistoryPoint, now: Date = Date()) -> Bool {
        guard point.percentage.isFinite, (0...100_000).contains(point.percentage),
              point.capturedAt <= now.addingTimeInterval(60),
              point.capturedAt >= now.addingTimeInterval(-Self.retention) else { return false }
        if let previous = points.last(where: { $0.series == point.series }) {
            guard point.capturedAt > previous.capturedAt else { return false }
            // Preserve within-minute changes of reset cycle / exhausted state.
            if point.capturedAt.timeIntervalSince(previous.capturedAt) < 60,
               previous.resetsAt == point.resetsAt,
               (previous.percentage >= 100) == (point.percentage >= 100) { return false }
        }
        points.removeAll { $0.capturedAt < now.addingTimeInterval(-Self.retention) }
        points.append(point)
        if points.count > Self.maximumPoints { points.removeFirst(points.count - Self.maximumPoints) }
        return true
    }

    public static func load(from url: URL, now: Date = Date()) -> Self {
        guard let data = try? Data(contentsOf: url), data.count <= 40_000_000,
              let points = try? JSONDecoder().decode([HistoryPoint].self, from: data) else { return Self() }
        return Self(points: points, now: now)
    }

    public func save(to url: URL) throws {
        try FileManager.default.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
        try JSONEncoder().encode(points).write(to: url, options: .atomic)
    }

    /// A new line segment after a reset, a downward jump or an hour without data.
    public func segments(for series: HistorySeries, since: Date) -> [[HistoryPoint]] {
        var segments: [[HistoryPoint]] = []
        for point in points.filter({ $0.series == series && $0.capturedAt >= since }) {
            if let previous = segments.last?.last,
               previous.resetsAt == point.resetsAt,
               point.percentage >= previous.percentage,
               point.capturedAt.timeIntervalSince(previous.capturedAt) <= 3600 {
                segments[segments.count - 1].append(point)
            } else { segments.append([point]) }
        }
        return segments
    }
}
