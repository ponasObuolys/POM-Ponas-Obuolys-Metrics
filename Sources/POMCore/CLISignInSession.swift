import Foundation

/// A Terminal command and a non-secret completion receipt for one browser sign-in.
public struct CLISignInSession: Sendable {
    public enum Provider: Sendable {
        case claude, codex
        var title: String { self == .claude ? "Claude" : "ChatGPT" }
        var arguments: String { self == .claude ? "auth login" : "login" }
    }
    public let directory: URL
    public let provider: Provider
    public var commandURL: URL { directory.appendingPathComponent("Sign in to \(provider.title).command") }
    public var resultURL: URL { directory.appendingPathComponent("result") }

    public static func prepare(executable: URL, provider: Provider = .claude, parent: URL = FileManager.default.temporaryDirectory) throws -> Self {
        let session = Self(directory: parent.appendingPathComponent("pom-sign-in-\(UUID().uuidString)"), provider: provider)
        try FileManager.default.createDirectory(at: session.directory, withIntermediateDirectories: true,
                                               attributes: [.posixPermissions: 0o700])
        do {
            // No credentials are passed to POM. Only the CLI exit status is recorded.
            // Single quotes prevent spaces, quotes or shell syntax in paths being executed.
            let script = """
            #!/bin/bash
            \(quote(executable.path)) \(provider.arguments)
            pom_login_status=$?
            if [ -d \(quote(session.directory.path)) ]; then
                printf '%s\\n' "$pom_login_status" > \(quote(session.resultURL.path + ".tmp"))
                mv \(quote(session.resultURL.path + ".tmp")) \(quote(session.resultURL.path))
            fi
            exit "$pom_login_status"

            """
            try script.write(to: session.commandURL, atomically: true, encoding: .utf8)
            try FileManager.default.setAttributes([.posixPermissions: 0o700], ofItemAtPath: session.commandURL.path)
            return session
        } catch {
            session.cleanUp()
            throw error
        }
    }

    public func completionStatus() -> Int? {
        guard let data = try? Data(contentsOf: resultURL), data.count <= 4,
              let text = String(data: data, encoding: .utf8),
              let status = Int(text.trimmingCharacters(in: .whitespacesAndNewlines)),
              (0...255).contains(status) else { return nil }
        return status
    }

    public func cleanUp() { try? FileManager.default.removeItem(at: directory) }

    private static func quote(_ value: String) -> String {
        "'" + value.replacingOccurrences(of: "'", with: "'\\''") + "'"
    }
}
