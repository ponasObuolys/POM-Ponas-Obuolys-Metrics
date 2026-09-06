import Foundation

/// Claude CLI pati atnaujina prisijungimą. Siunčiamos tik valdymo užklausos,
/// be vartotojo žinutės modeliui, be įrankių ir be išsaugotos pokalbio sesijos.
public struct ClaudeClient: Sendable {
    public enum ClientError: Error, Equatable {
        case timedOut
        case noResponse
        case unavailable
        case rejected(String)
    }

    public let timeout: TimeInterval
    public init(timeout: TimeInterval = 25) { self.timeout = timeout }

    public static var executable: URL? {
        let home = FileManager.default.homeDirectoryForCurrentUser.path
        return CodexLocator.executableURL(searchPaths: [
            "/opt/homebrew/bin/claude", "/usr/local/bin/claude", "\(home)/.local/bin/claude",
            "\(home)/.bun/bin/claude", "\(home)/.volta/bin/claude",
        ])
    }

    public func fetch(executable: URL, now: Date = Date()) throws -> UsageSnapshot {
        let process = Process()
        process.executableURL = executable
        process.arguments = ["--print", "--input-format", "stream-json", "--output-format", "stream-json",
                             "--verbose", "--no-session-persistence", "--safe-mode",
                             "--setting-sources", "", "--strict-mcp-config", "--mcp-config",
                             "{\"mcpServers\":{}}", "--tools", ""]
        var environment = ProcessInfo.processInfo.environment
        environment["PATH"] = "/opt/homebrew/bin:/usr/local/bin:/usr/bin:/bin:"
            + (environment["PATH"] ?? "")
        process.environment = environment
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent("pom-claude-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: directory) }
        process.currentDirectoryURL = directory
        let input = Pipe(), output = Pipe()
        process.standardInput = input
        process.standardOutput = output
        process.standardError = FileHandle.nullDevice
        try process.run()

        let watchdog = DispatchWorkItem {
            if process.isRunning { process.terminate() }
        }
        let killSwitch = DispatchWorkItem {
            if process.isRunning { kill(process.processIdentifier, SIGKILL) }
        }
        DispatchQueue.global(qos: .utility).asyncAfter(deadline: .now() + timeout, execute: watchdog)
        DispatchQueue.global(qos: .utility).asyncAfter(deadline: .now() + timeout + 1, execute: killSwitch)
        defer {
            watchdog.cancel()
            try? input.fileHandleForWriting.close()
            if process.isRunning { process.terminate() }
            // Laiko riba galioja ir proceso uždarymui.
            process.waitUntilExit()
            killSwitch.cancel()
        }

        func send(_ subtype: String, id: String) throws {
            let request: [String: Any] = ["type": "control_request", "request_id": id,
                                          "request": ["subtype": subtype]]
            var data = try JSONSerialization.data(withJSONObject: request)
            data.append(10)
            try input.fileHandleForWriting.write(contentsOf: data)
        }
        try send("initialize", id: "pom-init")
        var buffer = Data()
        while true {
            let chunk = output.fileHandleForReading.availableData
            if chunk.isEmpty { break }
            buffer.append(chunk)
            guard buffer.count < 4 * 1024 * 1024 else { throw ClientError.noResponse }
            while let newline = buffer.firstIndex(of: 10) {
                let line = Data(buffer[..<newline])
                buffer.removeSubrange(...newline)
                guard let root = try? JSONSerialization.jsonObject(with: line) as? [String: Any],
                    root["type"] as? String == "control_response",
                    let response = root["response"] as? [String: Any],
                    let id = response["request_id"] as? String,
                    ["pom-init", "pom-usage"].contains(id)
                else { continue }
                if response["subtype"] as? String == "error" {
                    throw ClientError.rejected(response["error"] as? String ?? "")
                }
                if id == "pom-init" { try send("get_usage", id: "pom-usage"); continue }
                guard let payload = response["response"] as? [String: Any],
                    payload["rate_limits_available"] as? Bool == true
                else { throw ClientError.unavailable }
                let data = try JSONSerialization.data(withJSONObject: payload)
                return try UsageParser.parse(data: data, source: .claudeCLI, capturedAt: now)
            }
        }
        if Date().timeIntervalSince(now) >= timeout { throw ClientError.timedOut }
        throw ClientError.noResponse
    }
}
