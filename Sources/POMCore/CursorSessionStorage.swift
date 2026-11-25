import CommonCrypto
import Foundation

/// Cursor's macOS Electron safeStorage envelope. Secrets remain in memory only.
public enum CursorSessionStorage {
    private static let prefix = "cursor-safe-storage:v1:"
    private static let keychain = KeychainReader(service: "Cursor Safe Storage", account: "Cursor Key")
    private static let grokBotKeychain = KeychainReader(service: "Grok Bot Safe Storage", account: "Grok Bot Key")

    public static func decode(_ stored: String, password: () throws -> String = readPassword) throws -> String {
        guard !stored.isEmpty, stored.utf8.count <= 32768 else { throw CursorClient.ClientError.credentialStorage }
        if !stored.hasPrefix("cursor-safe-storage:") { return try validate(stored) }
        guard stored.hasPrefix(prefix) else { throw CursorClient.ClientError.credentialStorage }
        return try decrypt(base64: String(stored.dropFirst(prefix.count)), password: password)
    }

    /// Electron safeStorage on macOS: "v10" + AES-128-CBC with a Keychain-derived key.
    /// Shared by Cursor and Grok Bot, which differ only in the Keychain item.
    public static func decrypt(base64: String, password: () throws -> String) throws -> String {
        guard base64.utf8.count <= 32768, let envelope = Data(base64Encoded: base64),
              envelope.starts(with: Data("v10".utf8)), envelope.count > 3,
              (envelope.count - 3) % 16 == 0 else { throw CursorClient.ClientError.credentialStorage }
        let secret = try password()
        guard !secret.isEmpty else { throw CursorClient.ClientError.credentialStorage }
        var key = [UInt8](repeating: 0, count: 16)
        defer { _ = key.withUnsafeMutableBytes { $0.initializeMemory(as: UInt8.self, repeating: 0) } }
        let salt = Array("saltysalt".utf8)
        let derived = secret.withCString { pointer in
            CCKeyDerivationPBKDF(CCPBKDFAlgorithm(kCCPBKDF2), pointer, secret.utf8.count,
                                salt, salt.count, CCPseudoRandomAlgorithm(kCCPRFHmacAlgSHA1), 1003, &key, key.count)
        }
        guard derived == kCCSuccess else { throw CursorClient.ClientError.credentialStorage }
        let ciphertext = Array(envelope.dropFirst(3))
        let iv = [UInt8](repeating: 32, count: 16)
        var output = [UInt8](repeating: 0, count: ciphertext.count + 16)
        defer { _ = output.withUnsafeMutableBytes { $0.initializeMemory(as: UInt8.self, repeating: 0) } }
        var count = 0
        let status = CCCrypt(CCOperation(kCCDecrypt), CCAlgorithm(kCCAlgorithmAES), CCOptions(kCCOptionPKCS7Padding),
                             key, key.count, iv, ciphertext, ciphertext.count, &output, output.count, &count)
        guard status == kCCSuccess, let token = String(bytes: output.prefix(count), encoding: .utf8) else {
            throw CursorClient.ClientError.credentialStorage
        }
        return try validate(token)
    }

    private static func validate(_ token: String) throws -> String {
        guard !token.isEmpty, !token.contains(where: { $0.isWhitespace || $0.isNewline }),
              !token.contains(":"), !token.contains(where: { $0.asciiValue.map { $0 < 33 || $0 > 126 } ?? true }) else {
            throw CursorClient.ClientError.credentialStorage
        }
        return token
    }

    public static func readPassword() throws -> String { try keychain.read() }
    public static func readGrokBotPassword() throws -> String { try grokBotKeychain.read() }

    /// Serializes access to one Keychain item. A denial is remembered until restart,
    /// so background timers cannot repeatedly present Keychain permission prompts.
    private final class KeychainReader: @unchecked Sendable {
        private let service: String
        private let account: String
        private let lock = NSLock()
        init(service: String, account: String) {
            self.service = service
            self.account = account
        }
        private var result: Result<String, CursorClient.ClientError>?
        func read() throws -> String {
            lock.lock()
            defer { lock.unlock() }
            if let result { return try result.get() }
            let process = Process()
            process.executableURL = URL(fileURLWithPath: "/usr/bin/security")
            process.arguments = ["find-generic-password", "-s", service, "-a", account, "-w"]
            let output = Pipe()
            process.standardOutput = output
            process.standardError = FileHandle.nullDevice
            do {
                try process.run()
                let data = output.fileHandleForReading.readDataToEndOfFile()
                process.waitUntilExit()
                let secret = String(decoding: data, as: UTF8.self).trimmingCharacters(in: .newlines)
                if process.terminationStatus == 0 && !secret.isEmpty {
                    result = .success(secret)
                } else { result = .failure(.credentialStorage) }
            } catch { result = .failure(.credentialStorage) }
            return try result!.get()
        }
    }
}
