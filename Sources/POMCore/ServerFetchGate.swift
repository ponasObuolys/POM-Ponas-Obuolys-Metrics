import Foundation

/// Sprendžia, ar galima kreiptis į serverį.
///
/// Serveris limitų užklausas riboja labai griežtai: nuo 30–60 sek. dažnio jis pradeda
/// atsakinėti klaida HTTP 429 ir nebeatsileidžia. Todėl automatiškai kreipiamasi tik tada,
/// kai vietiniai duomenys pasenę, o po kiekvienos nesėkmės pauzė dvigubinama.
public struct ServerFetchGate: Equatable, Sendable {
    public enum Decision: Equatable, Sendable {
        case fetch
        case skipDisabled
        /// Serveris atsakė, kad taip niekada nepavyks (pvz., raktui trūksta teisių).
        /// Kartoti nėra prasmės, o be reikalo blaškyti serverį – žalinga.
        case skipBlocked
        case skipLocalFresh
        case skipBackoff
        case skipManualFloor
    }

    public static let baseInterval: TimeInterval = 30 * 60
    public static let maxInterval: TimeInterval = 2 * 60 * 60

    public var enabled: Bool
    public var staleThreshold: TimeInterval
    public var manualFloor: TimeInterval
    /// Pauzė po pirmos nesėkmės ir jos lubos. Anthropic serveris užklausas riboja griežtai,
    /// o vietinis Codex – ne, todėl pauzės ilgis paliktas nustatomas.
    public var retryInterval: TimeInterval
    public var maxRetryInterval: TimeInterval

    public private(set) var failures: Int = 0
    public private(set) var lastAttempt: Date?
    public private(set) var isBlocked = false

    public init(
        enabled: Bool,
        staleThreshold: TimeInterval = 30 * 60,
        manualFloor: TimeInterval = 5 * 60,
        retryInterval: TimeInterval = ServerFetchGate.baseInterval,
        maxRetryInterval: TimeInterval = ServerFetchGate.maxInterval
    ) {
        self.enabled = enabled
        self.staleThreshold = staleThreshold
        self.manualFloor = manualFloor
        self.retryInterval = retryInterval
        self.maxRetryInterval = maxRetryInterval
    }

    public var backoffInterval: TimeInterval {
        guard failures > 0 else { return retryInterval }
        let doubled = retryInterval * pow(2, Double(failures - 1))
        return min(doubled, maxRetryInterval)
    }

    public func decide(localCapturedAt: Date?, now: Date, manual: Bool) -> Decision {
        guard enabled else { return .skipDisabled }
        guard !isBlocked else { return .skipBlocked }

        if manual {
            if let lastAttempt, now.timeIntervalSince(lastAttempt) < manualFloor {
                return .skipManualFloor
            }
            return .fetch
        }

        if let localCapturedAt, now.timeIntervalSince(localCapturedAt) < staleThreshold {
            return .skipLocalFresh
        }
        if let lastAttempt, now.timeIntervalSince(lastAttempt) < backoffInterval {
            return .skipBackoff
        }
        return .fetch
    }

    public mutating func recordAttempt(at date: Date) {
        lastAttempt = date
    }

    public mutating func recordSuccess() {
        failures = 0
        isBlocked = false
    }

    public mutating func recordFailure() {
        failures += 1
    }

    /// Nuolatinė kliūtis: daugiau nebandoma, kol vartotojas nepakeis nustatymų.
    public mutating func block() {
        isBlocked = true
    }

    public mutating func unblock() {
        isBlocked = false
    }
}
