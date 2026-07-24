import Foundation

/// Skaito Claude Code prisijungimo raktą iš macOS raktinės.
///
/// Naudojama sisteminė komanda `/usr/bin/security`, o ne tiesioginė raktinės sąsaja.
/// Priežastis praktinė: leidimas „Visada leisti“ prisiriša prie konkretaus programos parašo.
/// Nurodžius stabilią Apple komandą, leidimas išlieka ir perkūrus POM, kitaip macOS
/// klaustų iš naujo po kiekvieno perkompiliavimo.
///
/// Raktas tik skaitomas. POM jo niekada nekeičia ir neatnaujina, kad nesutrikdytų Claude Code.
public enum KeychainToken {
    public enum TokenError: Error, Equatable {
        case commandFailed(Int32)
        case notFound
        case expired(Date)
    }

    public static let service = "Claude Code-credentials"

    public static func claudeCodeAccessToken(now: Date = Date()) throws -> String {
        let raw = try readSecret()

        guard let data = raw.data(using: .utf8),
            let json = try? JSONSerialization.jsonObject(with: data, options: []),
            let token = findString(keys: ["accessToken", "access_token"], in: json)
        else {
            throw TokenError.notFound
        }

        if let expiry = findDate(keys: ["expiresAt", "expires_at"], in: json), expiry <= now {
            throw TokenError.expired(expiry)
        }
        return token
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

    // MARK: - Paieška JSON medyje

    /// Rakto tiksli vieta JSON struktūroje neaprašyta, todėl ieškoma per visą medį.
    private static func findString(keys: [String], in json: Any) -> String? {
        if let dict = json as? [String: Any] {
            for key in keys {
                if let value = dict[key] as? String, !value.isEmpty { return value }
            }
            for value in dict.values {
                if let found = findString(keys: keys, in: value) { return found }
            }
        } else if let array = json as? [Any] {
            for value in array {
                if let found = findString(keys: keys, in: value) { return found }
            }
        }
        return nil
    }

    private static func findDate(keys: [String], in json: Any) -> Date? {
        if let dict = json as? [String: Any] {
            for key in keys {
                guard let number = dict[key] as? NSNumber else { continue }
                let value = number.doubleValue
                guard value > 0 else { continue }
                // Claude Code laiką saugo milisekundėmis.
                return Date(timeIntervalSince1970: value > 1_000_000_000_000 ? value / 1000 : value)
            }
            for value in dict.values {
                if let found = findDate(keys: keys, in: value) { return found }
            }
        } else if let array = json as? [Any] {
            for value in array {
                if let found = findDate(keys: keys, in: value) { return found }
            }
        }
        return nil
    }
}
