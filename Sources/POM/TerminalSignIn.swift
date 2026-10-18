import AppKit
import POMCore

/// Both providers keep authentication in their own CLI. POM observes only completion.
@MainActor
enum TerminalSignIn {
    enum Outcome { case completed, failed, timedOut }

    static func open(_ url: URL) async throws {
        guard let terminal = NSWorkspace.shared.urlForApplication(withBundleIdentifier: "com.apple.Terminal") else {
            throw CocoaError(.fileNoSuchFile)
        }
        _ = try await NSWorkspace.shared.open([url], withApplicationAt: terminal,
                                             configuration: NSWorkspace.OpenConfiguration())
    }

    static func run(executable: URL, provider: CLISignInSession.Provider,
                    timeout: TimeInterval, open: (URL) async throws -> Void) async throws -> Outcome {
        let session = try CLISignInSession.prepare(executable: executable, provider: provider)
        defer { session.cleanUp() }
        try await open(session.commandURL)
        let deadline = Date().addingTimeInterval(timeout)
        while Date() < deadline {
            if let status = session.completionStatus() { return status == 0 ? .completed : .failed }
            try await Task.sleep(for: .seconds(1))
        }
        return .timedOut
    }
}
