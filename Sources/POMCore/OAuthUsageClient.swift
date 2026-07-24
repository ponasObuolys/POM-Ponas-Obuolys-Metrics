import Foundation

/// Atsarginis duomenų šaltinis: Anthropic limitų adresas, kurį naudoja ir Claude Code `/usage`.
/// Adresas viešai neaprašytas ir gali nustoti veikti, todėl programa be jo veikia visiškai normaliai.
public struct OAuthUsageClient: Sendable {
    public enum ClientError: Error, Equatable {
        case rateLimited
        case http(Int)
        case invalidResponse
    }

    public let endpoint: URL
    public let session: URLSession

    public init(
        endpoint: URL = URL(string: "https://api.anthropic.com/api/oauth/usage")!,
        session: URLSession = .shared
    ) {
        self.endpoint = endpoint
        self.session = session
    }

    public func fetch(token: String, now: Date = Date()) async throws -> UsageSnapshot {
        var request = URLRequest(url: endpoint)
        request.httpMethod = "GET"
        request.timeoutInterval = 15
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        request.setValue("oauth-2025-04-20", forHTTPHeaderField: "anthropic-beta")
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        request.setValue("claude-code/1.0 (external, cli)", forHTTPHeaderField: "User-Agent")

        let (data, response) = try await session.data(for: request)
        guard let http = response as? HTTPURLResponse else { throw ClientError.invalidResponse }

        if http.statusCode == 429 { throw ClientError.rateLimited }
        guard (200..<300).contains(http.statusCode) else { throw ClientError.http(http.statusCode) }

        return try UsageParser.parse(data: data, source: .server, capturedAt: now)
    }
}
