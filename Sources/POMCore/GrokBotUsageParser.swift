import Foundation

/// Connect JSON / protobuf Timestamp format verified in Grok Bot's DashboardService definitions.
public enum GrokBotUsageParser {
    private struct Response: Decodable {
        let usagePercent: Double?
        let nextResetTimestampUtc: String?
        let sandTrialExpiresAt: String?
        let hasNonZeroIncludedLimit: Bool?
        let usesPooledEnterpriseAllowance: Bool?
        let isUnified: Bool?
        let cursorPlanName: String?
        let grokPlanLabel: String?
    }

    public static func parse(_ data: Data, capturedAt: Date) throws -> ProviderUsageSnapshot {
        guard data.count <= CursorUsageParser.maximumBytes else { throw CursorClient.ClientError.invalidResponse }
        let response: Response
        do { response = try JSONDecoder().decode(Response.self, from: data) }
        catch { throw CursorClient.ClientError.invalidResponse }
        guard response.usesPooledEnterpriseAllowance != true,
              let percent = response.usagePercent, percent.isFinite, (0...10_000).contains(percent) else {
            throw CursorClient.ClientError.invalidResponse
        }
        let trial = try timestamp(response.sandTrialExpiresAt)
        guard response.hasNonZeroIncludedLimit == true || trial.map({ $0 > capturedAt }) == true else {
            throw CursorClient.ClientError.invalidResponse
        }
        let reset = try timestamp(response.nextResetTimestampUtc)
        let name = response.isUnified == true ? response.cursorPlanName : response.grokPlanLabel
        let label = SubscriptionPlan.providedName(name)
        // Do not attach Cursor monthly on-demand spend to a unified prepaid-credit pool.
        return ProviderUsageSnapshot(meters: [.init(kind: .weekly, usedPercentage: percent, resetsAt: reset)],
                                     capturedAt: capturedAt, planName: label)
    }

    private static func timestamp(_ value: String?) throws -> Date? {
        guard let value else { return nil }
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        let fractional = formatter.date(from: value)
        formatter.formatOptions = [.withInternetDateTime]
        guard let date = fractional ?? formatter.date(from: value),
              date.timeIntervalSince1970 > 0, date.timeIntervalSince1970 < 32_503_680_000 else {
            throw CursorClient.ClientError.invalidResponse
        }
        return date
    }
}
