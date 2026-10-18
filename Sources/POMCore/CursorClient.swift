import CryptoKit
import Foundation
import SQLite3

/// Uses Cursor's existing session only after the user enables this integration.
/// No refresh tokens, browser cookies or session credentials are saved by POM.
public struct CursorClient: Sendable {
    public enum ClientError: Error, Equatable {
        case signedOut, unavailable, invalidResponse, rateLimited
    }

    public static func databaseURL(home: URL = FileManager.default.homeDirectoryForCurrentUser) -> URL {
        home.appendingPathComponent("Library/Application Support/Cursor/User/globalStorage/state.vscdb")
    }

    public struct Session: Sendable, CustomStringConvertible {
        private let token: String
        public let fingerprint: String
        public var description: String { "Cursor session (redacted)" }

        public init(accessToken: String) {
            token = accessToken
            fingerprint = SHA256.hash(data: Data(accessToken.utf8)).map { String(format: "%02x", $0) }.joined()
        }

        fileprivate func request(method: String) -> URLRequest {
            var request = URLRequest(url: URL(string: "https://api2.cursor.sh/aiserver.v1.DashboardService/\(method)")!)
            request.httpMethod = "POST"
            request.httpBody = Data("{}".utf8)
            request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
            request.setValue("application/json", forHTTPHeaderField: "Content-Type")
            request.setValue("1", forHTTPHeaderField: "Connect-Protocol-Version")
            request.timeoutInterval = 15
            return request
        }
    }

    public init() {}

    public static func readSession(database: URL) throws -> Session {
        var db: OpaquePointer?
        guard sqlite3_open_v2(database.path, &db, SQLITE_OPEN_READONLY | SQLITE_OPEN_NOMUTEX, nil) == SQLITE_OK else {
            sqlite3_close(db)
            throw ClientError.signedOut
        }
        defer { sqlite3_close(db) }
        sqlite3_busy_timeout(db, 200)
        var statement: OpaquePointer?
        guard sqlite3_prepare_v2(db, "SELECT value FROM ItemTable WHERE key='cursorAuth/accessToken'", -1, &statement, nil) == SQLITE_OK else {
            throw ClientError.unavailable
        }
        defer { sqlite3_finalize(statement) }
        guard sqlite3_step(statement) == SQLITE_ROW, let bytes = sqlite3_column_text(statement, 0) else {
            throw ClientError.signedOut
        }
        let length = Int(sqlite3_column_bytes(statement, 0))
        guard (1...32768).contains(length),
              let token = String(bytes: UnsafeBufferPointer(start: bytes, count: length), encoding: .utf8),
              !token.contains(where: { $0.isWhitespace || $0.isNewline }) else { throw ClientError.signedOut }
        return Session(accessToken: token)
    }

    public func fetch(session: Session, now: Date = Date()) async throws -> ProviderUsageSnapshot {
        let configuration = URLSessionConfiguration.ephemeral
        configuration.httpCookieStorage = nil
        configuration.httpShouldSetCookies = false
        configuration.urlCache = nil
        let transport = URLSession(configuration: configuration, delegate: CursorRedirectBlocker(), delegateQueue: nil)
        defer { transport.invalidateAndCancel() }
        do {
            async let metadata = try? read(method: "GetPlanInfo", session: session, transport: transport)
            let data = try await read(method: "GetCurrentPeriodUsage", session: session, transport: transport)
            return try await CursorUsageParser.parse(data, planData: metadata, capturedAt: now)
        } catch let error as ClientError { throw error }
        catch is CancellationError { throw CancellationError() }
        catch { throw ClientError.unavailable }
    }

    private func read(method: String, session: Session, transport: URLSession) async throws -> Data {
        let (bytes, response) = try await transport.bytes(for: session.request(method: method))
        guard let response = response as? HTTPURLResponse else { throw ClientError.invalidResponse }
        switch response.statusCode {
        case 200: break
        case 401, 403: throw ClientError.signedOut
        case 429: throw ClientError.rateLimited
        default: throw ClientError.unavailable
        }
        var data = Data()
        for try await byte in bytes {
            guard data.count < CursorUsageParser.maximumBytes else { throw ClientError.invalidResponse }
            data.append(byte)
        }
        return data
    }
}

private final class CursorRedirectBlocker: NSObject, URLSessionTaskDelegate {
    func urlSession(_ session: URLSession, task: URLSessionTask,
                    willPerformHTTPRedirection response: HTTPURLResponse,
                    newRequest request: URLRequest, completionHandler: @escaping (URLRequest?) -> Void) {
        completionHandler(nil)
    }
}

/// JSON shape verified against the installed Cursor DashboardService definitions.
/// This is an internal endpoint; an unknown or missing allowance stays unknown.
public enum CursorUsageParser {
    public static let maximumBytes = 256 * 1024

    private struct Response: Decodable {
        let billingCycleEnd: JSONNumber?
        let planUsage: Plan?
        let spendLimitUsage: Spend?
    }
    private struct Plan: Decodable {
        let includedSpend: Double?
        let limit: Double?
        let autoPercentUsed: Double?
        let apiPercentUsed: Double?
        let totalPercentUsed: Double?
    }
    private struct PlanResponse: Decodable { let planInfo: PlanInfo? }
    private struct PlanInfo: Decodable {
        let planName: String?
        let includedUsagePeriod: Period?
        let includedUsageResetsAt: JSONNumber?
        let billingCycleEnd: JSONNumber?
    }
    private enum Period: Decodable {
        case monthly, weekly, unknown
        init(from decoder: Decoder) throws {
            let value = try decoder.singleValueContainer()
            if let name = try? value.decode(String.self) {
                switch name {
                case "INCLUDED_USAGE_PERIOD_MONTHLY": self = .monthly
                case "INCLUDED_USAGE_PERIOD_WEEKLY": self = .weekly
                default: self = .unknown
                }
            } else {
                switch try value.decode(Int.self) {
                case 1: self = .monthly
                case 2: self = .weekly
                default: self = .unknown
                }
            }
        }
    }
    private struct Spend: Decodable {
        let individualUsed: Double?
        let individualLimit: JSONNumber?
    }
    private struct JSONNumber: Decodable {
        let value: Double
        init(from decoder: Decoder) throws {
            let container = try decoder.singleValueContainer()
            if let string = try? container.decode(String.self), let number = Double(string) { value = number }
            else { value = try container.decode(Double.self) }
        }
    }

    public static func parse(_ data: Data, planData: Data? = nil, capturedAt: Date) throws -> ProviderUsageSnapshot {
        guard data.count <= maximumBytes, (planData?.count ?? 0) <= maximumBytes else { throw CursorClient.ClientError.invalidResponse }
        let response: Response
        do { response = try JSONDecoder().decode(Response.self, from: data) }
        catch { throw CursorClient.ClientError.invalidResponse }
        let info = planData.flatMap { try? JSONDecoder().decode(PlanResponse.self, from: $0) }?.planInfo
        let reset: Date?
        switch info?.includedUsagePeriod {
        case .weekly: reset = resetDate(milliseconds: info?.includedUsageResetsAt?.value)
        case .monthly: reset = resetDate(milliseconds: response.billingCycleEnd?.value ?? info?.billingCycleEnd?.value)
        default: reset = nil
        }
        var meters: [ProviderUsageSnapshot.Meter] = []
        if let plan = response.planUsage {
            if let auto = percentage(plan.autoPercentUsed), let api = percentage(plan.apiPercentUsed) {
                meters = [.init(kind: .auto, usedPercentage: auto, resetsAt: reset),
                          .init(kind: .api, usedPercentage: api, resetsAt: reset)]
            } else {
                let ratio: Double?
                if let limit = nonnegative(plan.limit), limit > 0, let used = nonnegative(plan.includedSpend ?? 0) {
                    ratio = used / limit * 100
                } else { ratio = plan.totalPercentUsed }
                if let value = percentage(ratio) {
                    meters = [.init(kind: .included, usedPercentage: value, resetsAt: reset)]
                }
            }
        }
        let onDemand: ProviderUsageSnapshot.Spend?
        if let spend = response.spendLimitUsage, let used = nonnegative(spend.individualUsed ?? 0) {
            onDemand = .init(usedCents: used, limitCents: nonnegative(spend.individualLimit?.value))
        } else { onDemand = nil }
        guard !meters.isEmpty || onDemand != nil else { throw CursorClient.ClientError.invalidResponse }
        let planName = info?.planName.flatMap { $0.isEmpty || $0.count > 100 ? nil : $0 }
        return .init(meters: meters, capturedAt: capturedAt, planName: planName, onDemand: onDemand)
    }

    private static func nonnegative(_ value: Double?) -> Double? {
        guard let value, value.isFinite, value >= 0, value < 1e12 else { return nil }
        return value
    }
    private static func percentage(_ value: Double?) -> Double? {
        guard let value = nonnegative(value), value <= 10_000 else { return nil }
        return value
    }
    private static func resetDate(milliseconds value: Double?) -> Date? {
        // Cursor's protobuf int64 timestamp uses milliseconds since the epoch.
        guard let value, value.isFinite, value > 0, value < 32_503_680_000_000 else { return nil }
        return Date(timeIntervalSince1970: value / 1000)
    }
}
