import Foundation

/// Subscription percentages and spend are separate from token history.
public struct ProviderUsageSnapshot: Equatable, Sendable {
    public struct Meter: Equatable, Sendable {
        public enum Kind: String, Sendable { case included, auto, api, weekly }
        public let kind: Kind
        public let window: UsageWindow

        public init(kind: Kind, usedPercentage: Double, resetsAt: Date?) {
            self.kind = kind
            window = UsageWindow(usedPercentage: usedPercentage, resetsAt: resetsAt)
        }
    }

    public struct Spend: Equatable, Sendable {
        public let usedCents: Double
        public let limitCents: Double?

        public init(usedCents: Double, limitCents: Double?) {
            self.usedCents = usedCents
            self.limitCents = limitCents
        }
    }

    public let meters: [Meter]
    public let capturedAt: Date
    public let planName: String?
    public let onDemand: Spend?

    public init(meters: [Meter], capturedAt: Date, planName: String? = nil, onDemand: Spend? = nil) {
        self.meters = meters
        self.capturedAt = capturedAt
        self.planName = planName
        self.onDemand = onDemand
    }
}
