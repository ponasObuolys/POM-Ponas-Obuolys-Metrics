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

    /// Kur POM įsirašo tilto scenarijų.
    public static func scriptURL(home: URL) -> URL {
        home.appendingPathComponent("Library/Application Support/POM/pom-bridge.sh")
    }

    /// Kur Claude Code laiko statusline scenarijų, jei nenurodyta kitaip.
    public static func defaultStatuslineURL(home: URL) -> URL {
        home.appendingPathComponent(".claude/statusline.sh")
    }

    /// Kur guli Claude Code statusline scenarijus. Pirmiausia žiūrima į nustatymus,
    /// nes vartotojas gali būti nurodęs savo vietą.
    public static func statuslineURL(home: URL, fileManager: FileManager = .default) -> URL {
        guard let command = configuredCommand(home: home),
            let script = scriptPath(in: command, home: home, fileManager: fileManager)
        else {
            return defaultStatuslineURL(home: home)
        }
        return script
    }

    /// Claude Code nustatymuose įrašyta būsenos juostos komanda.
    public static func configuredCommand(home: URL) -> String? {
        let settings = home.appendingPathComponent(".claude/settings.json")
        guard let data = try? Data(contentsOf: settings),
            let json = try? JSONSerialization.jsonObject(with: data, options: []),
            let root = json as? [String: Any],
            let statusLine = root["statusLine"] as? [String: Any],
            let command = statusLine["command"] as? String,
            !command.trimmingCharacters(in: .whitespaces).isEmpty
        else {
            return nil
        }
        return command
    }

    /// Iš komandos ištraukia scenarijaus kelią.
    ///
    /// Komandoje gali būti ne tik pats scenarijus, bet ir vykdyklė su argumentais
    /// („bash ~/.claude/juosta.sh --trumpai“). Todėl imamas pirmas į kelią panašus žodis,
    /// kuris tikrai yra esamas failas. Neradus nė vieno grąžinama `nil`: spėlioti pavojinga,
    /// nes tada būtų keičiamas visai ne tas failas.
    public static func scriptPath(
        in command: String, home: URL, fileManager: FileManager = .default
    ) -> URL? {
        for token in tokens(in: command) {
            guard token.contains("/") || token.hasPrefix("~") else { continue }
            let url = expand(token, home: home)
            if fileManager.fileExists(atPath: url.path) { return url }
        }
        return nil
    }

    /// Ryšys laikomas veikiančiu tik tada, kai yra abi jo pusės: žymė statusline scenarijuje
    /// ir pats tilto scenarijus. Vien žymės neužtenka – ištrynus scenarijų POM be šios
    /// patikros amžinai rodytų „Duomenų dar nėra“ ir nesiūlytų prisijungti iš naujo.
    public static func isConnected(home: URL, fileManager: FileManager = .default) -> Bool {
        guard fileManager.isExecutableFile(atPath: scriptURL(home: home).path) else { return false }
        let url = statuslineURL(home: home, fileManager: fileManager)
        guard let contents = try? String(contentsOf: url, encoding: .utf8) else { return false }
        return contents.contains(marker)
    }

    /// Tiltas duomenis išrenka su `jq`. macOS 14 ir naujesnėse ji būna sisteminė,
    /// bet pasitaiko kompiuterių, kuriuose jos nėra, ir tada tiltas tyliai nieko nerašo.
    public static let jqSearchPaths = ["/usr/bin/jq", "/opt/homebrew/bin/jq", "/usr/local/bin/jq"]

    public static func isJQAvailable(
        searchPaths: [String] = jqSearchPaths, fileManager: FileManager = .default
    ) -> Bool {
        searchPaths.contains { fileManager.isExecutableFile(atPath: $0) }
    }

    // MARK: - Komandos skaidymas

    /// Komanda suskaidoma į žodžius, nuimant kabutes. Visa kabutėmis apgaubta komanda
    /// laikoma vienu keliu: taip tvarkomi keliai su tarpais.
    static func tokens(in command: String) -> [String] {
        let trimmed = command.trimmingCharacters(in: .whitespaces)
        if let unquoted = unquote(trimmed) { return [unquoted] }
        return trimmed.split(whereSeparator: \.isWhitespace).map { unquote(String($0)) ?? String($0) }
    }

    private static func unquote(_ text: String) -> String? {
        for quote in ["\"", "'"] where text.hasPrefix(quote) && text.hasSuffix(quote) && text.count > 1 {
            return String(text.dropFirst().dropLast())
        }
        return nil
    }

    private static func expand(_ token: String, home: URL) -> URL {
        if token == "~" { return home }
        if token.hasPrefix("~/") {
            return URL(fileURLWithPath: home.path + String(token.dropFirst(1)))
        }
        return URL(fileURLWithPath: token)
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
