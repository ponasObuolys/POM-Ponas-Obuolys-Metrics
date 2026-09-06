import Foundation

/// Evaluated only on launch. No timer, usage counter or network activity.
public struct SupportReminderPolicy: Codable, Equatable {
    public enum Occasion: Equatable { case welcome, update }
    public private(set) var latestVersion: String?
    public private(set) var lastPresentedAt: Date?

    public init() {}

    public mutating func recordLaunch(version: String, now: Date) -> Occasion? {
        guard version.range(of: #"^\d+\.\d+\.\d+$"#, options: .regularExpression) != nil else { return nil }
        let previous = latestVersion
        // Retain the highest version so downgrading and reinstalling cannot cause a repeat.
        if let previous, version.compare(previous, options: .numeric) != .orderedDescending { return nil }
        latestVersion = version
        // Consume skipped versions too: no delayed reminder after a cooldown.
        if let lastPresentedAt, now.timeIntervalSince(lastPresentedAt) < 7 * 86400 { return nil }
        lastPresentedAt = now
        return previous == nil ? .welcome : .update
    }
}
