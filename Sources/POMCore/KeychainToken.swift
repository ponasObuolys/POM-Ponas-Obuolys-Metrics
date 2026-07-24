import Foundation

/// Skaito Claude prenumeratos prisijungimo raktą iš macOS raktinės.
///
/// Naudojama sisteminė komanda `/usr/bin/security`, o ne tiesioginė raktinės sąsaja.
/// Priežastis praktinė: leidimas „Visada leisti“ prisiriša prie konkretaus programos parašo.
/// Nurodžius stabilią Apple komandą, leidimas išlieka ir perkūrus POM, kitaip macOS
/// klaustų iš naujo po kiekvieno perkompiliavimo.
///
/// Raktas tik skaitomas. POM jo niekada nekeičia ir neatnaujina, kad nesutrikdytų Claude Code.
///
/// Svarbu: imamas tik `claudeAiOauth.accessToken` ir niekas daugiau. Tame pačiame raktinės
/// įraše guli ir MCP serverių raktai (`mcpOAuth`), priklausantys visai kitoms paslaugoms.
/// Bendra paieška galėtų pačiupti svetimą raktą ir išsiųsti jį Anthropic serveriui,
/// todėl kelias nurodomas tiksliai.
public enum KeychainToken {
    public enum TokenError: Error, Equatable {
        case commandFailed(Int32)
        case unreadableSecret
        case claudeAccountNotFound
        case expired(Date)
    }

    public static let service = "Claude Code-credentials"

    public static func claudeCodeAccessToken(now: Date = Date()) throws -> String {
        try parseAccessToken(from: try readSecret(), now: now)
    }

    /// Atskirta nuo raktinės skaitymo, kad logiką būtų galima patikrinti testais.
    public static func parseAccessToken(from secret: String, now: Date) throws -> String {
        guard let data = secret.data(using: .utf8),
            let root = try? JSONSerialization.jsonObject(with: data, options: []),
            let dictionary = root as? [String: Any]
        else {
            throw TokenError.unreadableSecret
        }

        guard let oauth = dictionary["claudeAiOauth"] as? [String: Any],
            let token = oauth["accessToken"] as? String,
            !token.isEmpty
        else {
            throw TokenError.claudeAccountNotFound
        }

        if let expiry = expiryDate(oauth["expiresAt"]), expiry <= now {
            throw TokenError.expired(expiry)
        }
        return token
    }

    private static func expiryDate(_ value: Any?) -> Date? {
        guard let number = value as? NSNumber else { return nil }
        let raw = number.doubleValue
        guard raw > 0 else { return nil }
        // Claude Code laiką saugo milisekundėmis.
        return Date(timeIntervalSince1970: raw > 1_000_000_000_000 ? raw / 1000 : raw)
    }

    private static func readSecret() throws -> String {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/security")
        process.arguments = ["find-generic-password", "-s", service, "-w"]

        let output = Pipe()
        process.standardOutput = output
        process.standardError = Pipe()

        try process.run()
        let data = output.fileHandleForReading.readDataToEndOfFile()
        process.waitUntilExit()

        guard process.terminationStatus == 0 else {
            throw TokenError.commandFailed(process.terminationStatus)
        }
        return String(decoding: data, as: UTF8.self).trimmingCharacters(in: .whitespacesAndNewlines)
    }
}
