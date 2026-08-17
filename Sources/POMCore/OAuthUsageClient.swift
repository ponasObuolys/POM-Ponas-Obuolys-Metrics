import Foundation

/// Atsarginis duomenų šaltinis: Anthropic limitų adresas, kurį naudoja ir Claude Code `/usage`.
/// Adresas viešai neaprašytas ir gali nustoti veikti, todėl programa be jo veikia visiškai normaliai.
public struct OAuthUsageClient: Sendable {
    public enum ClientError: Error, Equatable {
        case rateLimited
        /// Raktas galioja, bet neturi teisės skaityti paskyros duomenų.
        /// Taip atsako `claude setup-token` raktas: jis skirtas pokalbiams su modeliu,
        /// o limitams reikia `user:profile` teisės. Klaida nuolatinė, kartoti nėra prasmės.
        case forbidden(String)
        case unauthorized
        case http(Int)
        case invalidResponse
    }

    public let endpoint: URL
    public let session: URLSession
    public let userAgent: String

    public init(
        endpoint: URL = URL(string: "https://api.anthropic.com/api/oauth/usage")!,
        session: URLSession = .shared,
        userAgent: String = Self.defaultUserAgent
    ) {
        self.endpoint = endpoint
        self.session = session
        self.userAgent = userAgent
    }

    /// POM prisistato savo vardu. Dėtis kitu įrankiu būtų nesąžininga serverio atžvilgiu
    /// ir apsunkintų klaidų aiškinimąsi abiem pusėms.
    public static var defaultUserAgent: String {
        let version = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "dev"
        return "POM/\(version) (+https://github.com/ponasObuolys/POM-Ponas-Obuolys-Metrics)"
    }

    public func fetch(token: String, now: Date = Date()) async throws -> UsageSnapshot {
        var request = URLRequest(url: endpoint)
        request.httpMethod = "GET"
        request.timeoutInterval = 15
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        request.setValue("oauth-2025-04-20", forHTTPHeaderField: "anthropic-beta")
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        request.setValue(userAgent, forHTTPHeaderField: "User-Agent")

        let (data, response) = try await session.data(for: request)
        guard let http = response as? HTTPURLResponse else { throw ClientError.invalidResponse }

        switch http.statusCode {
        case 200..<300:
            return try UsageParser.parse(data: data, source: .server, capturedAt: now)
        case 429:
            throw ClientError.rateLimited
        case 401:
            throw ClientError.unauthorized
        case 403:
            throw ClientError.forbidden(Self.serverMessage(from: data))
        default:
            throw ClientError.http(http.statusCode)
        }
    }

    /// Ištraukia serverio paaiškinimą iš klaidos atsakymo, kad būtų ką parodyti vartotojui.
    public static func serverMessage(from data: Data) -> String {
        guard let json = try? JSONSerialization.jsonObject(with: data, options: []),
            let root = json as? [String: Any],
            let error = root["error"] as? [String: Any],
            let message = error["message"] as? String
        else {
            return ""
        }
        return message
    }
}
