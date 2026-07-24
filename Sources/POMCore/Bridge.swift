import Foundation

/// Ryšys su Claude Code: ar limitų reikšmės iš viso pasiekia POM.
///
/// Claude Code limitus perduoda tik savo statusline scenarijui, todėl prie jo prikabinama
/// viena eilutė. Programa turi mokėti patikrinti, ar tai padaryta, ir prireikus padaryti
/// pati: kitaip naujame kompiuteryje ji amžinai rodytų „Duomenų dar nėra“.
public enum Bridge {
    public static let marker = "# >>> POM (Ponas Obuolys Metrika) >>>"

    public enum InstallError: LocalizedError {
        case scriptMissing
        case failed(String)

        public var errorDescription: String? {
            switch self {
            case .scriptMissing:
                return "Diegimo scenarijus nerastas programos pakete."
            case .failed(let output):
                return output.isEmpty ? "Prijungti nepavyko." : output
            }
        }
    }

    /// Kur guli Claude Code statusline scenarijus. Pirmiausia žiūrima į nustatymus,
    /// nes vartotojas gali būti nurodęs savo vietą.
    public static func statuslineURL(home: URL) -> URL {
        let settings = home.appendingPathComponent(".claude/settings.json")
        let fallback = home.appendingPathComponent(".claude/statusline.sh")

        guard let data = try? Data(contentsOf: settings),
            let json = try? JSONSerialization.jsonObject(with: data, options: []),
            let root = json as? [String: Any],
            let statusLine = root["statusLine"] as? [String: Any],
            var command = statusLine["command"] as? String,
            !command.isEmpty
        else {
            return fallback
        }

        if command.hasPrefix("~/") {
            command = home.path + String(command.dropFirst(1))
        }
        return URL(fileURLWithPath: command)
    }

    public static func isConnected(home: URL) -> Bool {
        let url = statuslineURL(home: home)
        guard let contents = try? String(contentsOf: url, encoding: .utf8) else { return false }
        return contents.contains(marker)
    }

    /// Paleidžia į paketą įdėtą diegimo scenarijų ir grąžina jo išvestį.
    public static func install(scriptURL: URL?) throws -> String {
        guard let scriptURL, FileManager.default.fileExists(atPath: scriptURL.path) else {
            throw InstallError.scriptMissing
        }

        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/bin/bash")
        process.arguments = [scriptURL.path]

        let output = Pipe()
        process.standardOutput = output
        process.standardError = output

        try process.run()
        let data = output.fileHandleForReading.readDataToEndOfFile()
        process.waitUntilExit()

        let text = String(decoding: data, as: UTF8.self)
            .trimmingCharacters(in: .whitespacesAndNewlines)

        guard process.terminationStatus == 0 else {
            throw InstallError.failed(text)
        }
        return text
    }
}
