import Foundation

/// Observes raw replies, never the UI's timer-derived percentages. Persisting the
/// last observation lets a reset be detected after a restart without duplicate alerts.
public struct RecoveryTracker: Codable, Sendable {
    private struct State: Codable, Sendable {
        var percentage: Double
        var reset: Date?
        var captured: Date
    }
    private var states: [String: State] = [:]
    public init() {}

    public mutating func observe(id: String, window: UsageWindow, capturedAt: Date,
                                 now: Date, ordinaryUsageAllowed: Bool? = nil,
                                 requiresAvailability: Bool = false) -> Bool {
        guard window.usedPercentage.isFinite, window.usedPercentage >= 0,
              capturedAt <= now.addingTimeInterval(60),
              now.timeIntervalSince(capturedAt) <= 600 else { return false }
        let old = states[id]
        guard old.map({ capturedAt > $0.captured }) ?? true else { return false }
        // An unknown/blocked backend permission must not erase a pending exhausted
        // Codex observation. A later explicit success can still confirm recovery.
        let available = !requiresAvailability || ordinaryUsageAllowed == true
        let confirmed = old.map {
            $0.percentage >= 100 && window.usedPercentage < 100 && available
                && ($0.reset.map { capturedAt >= $0 } ?? true)
        } ?? false
        if !(old?.percentage ?? 0 >= 100 && window.usedPercentage < 100 && !available) {
            states[id] = State(percentage: window.usedPercentage, reset: window.resetsAt, captured: capturedAt)
        }
        return confirmed
    }
}
