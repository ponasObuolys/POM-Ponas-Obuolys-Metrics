import Foundation

/// Kiek limito sunaudota, žiūrint spalvų ribomis.
public enum UsageLevel: Equatable, Sendable {
    case normal
    case warning
    case critical

    public init(percentage: Double) {
        if percentage < 70 {
            self = .normal
        } else if percentage < 90 {
            self = .warning
        } else {
            self = .critical
        }
    }
}

/// Kiek duomenys švieži.
public enum Freshness: Equatable, Sendable {
    /// Claude Code sesija ką tik atnaujino reikšmes.
    case live
    /// Sesija uždaryta neseniai, reikšmės tebegalioja.
    case recent
    /// Duomenys seni, verta pabandyti serverį.
    case stale
    /// Duomenų dar nėra.
    case none
}

/// Rodoma lango būsena po atsistatymo patikros.
public struct DisplayWindow: Equatable, Sendable {
    public let usedPercentage: Double
    public let resetsAt: Date?
    /// Reikšmė gauta ne iš duomenų, o iš to, kad atsistatymo laikas jau praėjo.
    public let didReset: Bool

    public var remainingPercentage: Double { max(0, 100 - usedPercentage) }
    public var level: UsageLevel { UsageLevel(percentage: usedPercentage) }
    public var fraction: Double { min(max(usedPercentage / 100, 0), 1) }

    public init(usedPercentage: Double, resetsAt: Date?, didReset: Bool) {
        self.usedPercentage = usedPercentage
        self.resetsAt = resetsAt
        self.didReset = didReset
    }
}

public enum UsageDisplay {
    public static let liveWindow: TimeInterval = 90
    public static let recentWindow: TimeInterval = 30 * 60

    /// Jei atsistatymo laikas praėjo, langas jau nunulintas, nors naujų duomenų ir negavome.
    public static func resolve(_ window: UsageWindow, now: Date) -> DisplayWindow {
        if let resetsAt = window.resetsAt, now >= resetsAt {
            return DisplayWindow(usedPercentage: 0, resetsAt: nil, didReset: true)
        }
        return DisplayWindow(
            usedPercentage: window.usedPercentage, resetsAt: window.resetsAt, didReset: false)
    }

    public static func freshness(capturedAt: Date?, now: Date) -> Freshness {
        guard let capturedAt else { return .none }
        let age = now.timeIntervalSince(capturedAt)
        if age < liveWindow { return .live }
        if age < recentWindow { return .recent }
        return .stale
    }
}
