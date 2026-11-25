import Foundation

/// Grok Bot's own sign-in, read so the quota refreshes while Grok Bot is in use
/// and Cursor is closed. Layout verified against the installed app's secret store.
/// POM never renews a token: refresh tokens are single-use and bound to the owning
/// app, so spending one would sign that app out.
public enum GrokBotSession {
    private static let maximumBytes = 256 * 1024
    private static let tokenKey = "cursor-access-token"
    private static let scopedPrefix = "scoped:v1:"

    public static func secretsURL(home: URL = FileManager.default.homeDirectoryForCurrentUser) -> URL {
        home.appendingPathComponent("Library/Application Support/Grok Bot/sand-secrets.json")
    }

    private struct Accounts: Decodable {
        let active: String?
        let accounts: [String: [String: String]]
    }

    public static func read(file: URL, password: () throws -> String = CursorSessionStorage.readGrokBotPassword) throws -> CursorClient.Session {
        guard let size = try? file.resourceValues(forKeys: [.fileSizeKey]).fileSize, size <= maximumBytes,
              let data = try? Data(contentsOf: file), data.count <= maximumBytes else { throw CursorClient.ClientError.signedOut }
        guard let root = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            throw CursorClient.ClientError.credentialStorage
        }
        if let version = root["version"] {
            guard (version as? NSNumber)?.intValue == 1 else { throw CursorClient.ClientError.credentialStorage }
        }
        var stored = root[tokenKey] as? String
        if let saved = root["cursor-accounts"] as? String,
           let record = try? JSONDecoder().decode(Accounts.self, from: Data(saved.utf8)),
           let active = record.active, let value = record.accounts[active]?[tokenKey] {
            stored = value
        }
        // Grok Bot itself refuses values it could not encrypt.
        guard var ciphertext = stored, !ciphertext.hasPrefix("plaintext:v1:") else { throw CursorClient.ClientError.signedOut }
        if ciphertext.hasPrefix(scopedPrefix) {
            let rest = ciphertext.dropFirst(scopedPrefix.count)
            guard let separator = rest.firstIndex(of: ":"), rest.distance(from: rest.startIndex, to: separator) == 64 else {
                throw CursorClient.ClientError.credentialStorage
            }
            ciphertext = String(rest[rest.index(after: separator)...])
        }
        return CursorClient.Session(accessToken: try CursorSessionStorage.decrypt(base64: ciphertext, password: password))
    }

    /// Grok Bot's own sign-in comes first. Cursor's stands in only for the same
    /// account, so the card can never switch to another account's quota.
    public static func choose(grokBot: CursorClient.Session?, cursor: CursorClient.Session?, now: Date) -> CursorClient.Session? {
        if let grokBot, grokBot.isUsable(at: now) { return grokBot }
        guard let cursor, cursor.isUsable(at: now) else { return nil }
        if let grokBot, grokBot.fingerprint != cursor.fingerprint { return nil }
        return cursor
    }

    public static func resolve(grokBot: () throws -> CursorClient.Session, cursor: () throws -> CursorClient.Session,
                               now: Date = Date()) throws -> CursorClient.Session {
        let own = try? grokBot()
        if let own, own.isUsable(at: now) { return own }
        let fallback = Result { try cursor() }
        if let chosen = choose(grokBot: own, cursor: try? fallback.get(), now: now) { return chosen }
        if own != nil { throw CursorClient.ClientError.sessionExpired }
        _ = try fallback.get()
        throw CursorClient.ClientError.sessionExpired
    }
}
