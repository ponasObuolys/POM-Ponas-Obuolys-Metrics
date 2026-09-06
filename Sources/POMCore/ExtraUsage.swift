import Foundation

/// Preserve source units. Currency amounts are displayed only when both the currency
/// and its decimal scale are supplied; a missing balance never becomes zero.
public struct ClaudeExtraUsage: Codable, Equatable, Sendable {
    public let enabled: Bool
    public let used: Double?
    public let limit: Double?
    public let percentage: Double?
    public let currency: String?
    public let decimalPlaces: Int?
    public let limitReached: Bool?

    public init(enabled: Bool, used: Double? = nil, limit: Double? = nil,
                percentage: Double? = nil, currency: String? = nil,
                decimalPlaces: Int? = nil, limitReached: Bool? = nil) {
        self.enabled = enabled; self.used = used; self.limit = limit
        self.percentage = percentage; self.currency = currency
        self.decimalPlaces = decimalPlaces; self.limitReached = limitReached
    }

    static func parse(_ object: Any?) -> Self? {
        guard let dict = object as? [String: Any], let enabled = dict["is_enabled"] as? Bool else { return nil }
        let scale = (dict["decimal_places"] as? NSNumber)?.intValue
        return Self(enabled: enabled, used: finiteNumber(dict["used_credits"]),
                    limit: finiteNumber(dict["monthly_limit"]), percentage: finiteNumber(dict["utilization"]).flatMap { $0 <= 100_000 ? $0 : nil },
                    currency: dict["currency"] as? String,
                    decimalPlaces: scale.flatMap { (0...6).contains($0) ? $0 : nil },
                    limitReached: dict["spend_limit_reached"] as? Bool)
    }

    var json: [String: Any] {
        var result: [String: Any] = ["is_enabled": enabled]
        result["used_credits"] = used; result["monthly_limit"] = limit
        result["utilization"] = percentage; result["currency"] = currency
        result["decimal_places"] = decimalPlaces; result["spend_limit_reached"] = limitReached
        return result
    }
}

public struct CodexCredits: Codable, Equatable, Sendable {
    public let hasCredits: Bool
    public let unlimited: Bool
    public let balance: String?
    public init(hasCredits: Bool, unlimited: Bool, balance: String?) {
        self.hasCredits = hasCredits; self.unlimited = unlimited; self.balance = balance
    }
}

public struct CodexSpendLimit: Codable, Equatable, Sendable {
    public let limit: String
    public let used: String
    public let remainingPercent: Double
    public let resetsAt: Date?
    public init(limit: String, used: String, remainingPercent: Double, resetsAt: Date?) {
        self.limit = limit; self.used = used; self.remainingPercent = remainingPercent; self.resetsAt = resetsAt
    }
}

public struct CodexAdditionalUsage: Codable, Equatable, Sendable {
    public var credits: CodexCredits?
    public var spendLimit: CodexSpendLimit?
    public var spendControlReached: Bool?
    public var resetCredits: Int?
    public var nextResetCreditExpiry: Date?
    public init(credits: CodexCredits? = nil, spendLimit: CodexSpendLimit? = nil,
                spendControlReached: Bool? = nil, resetCredits: Int? = nil,
                nextResetCreditExpiry: Date? = nil) {
        self.credits = credits; self.spendLimit = spendLimit; self.spendControlReached = spendControlReached
        self.resetCredits = resetCredits; self.nextResetCreditExpiry = nextResetCreditExpiry
    }
    public var isAvailable: Bool {
        credits != nil || spendLimit != nil || resetCredits != nil || spendControlReached != nil
    }
}

func finiteNumber(_ value: Any?) -> Double? {
    let number: Double?
    if let value = value as? NSNumber { number = value.doubleValue }
    else if let value = value as? String { number = Double(value) }
    else { number = nil }
    return number.flatMap { $0.isFinite && $0 >= 0 ? $0 : nil }
}
