import Foundation

/// Automatinis paleidimas prisijungus.
///
/// Naudojamas LaunchAgent aprašas, o ne `SMAppService`, nes pastarasis patikimai veikia
/// tik su tikru Apple kūrėjo parašu. Aprašas įsigalioja kitą kartą prisijungus prie macOS.
enum LoginItem {
    enum LoginItemError: LocalizedError {
        case executableNotFound

        var errorDescription: String? {
            switch self {
            case .executableNotFound:
                return "Nepavyko rasti programos vietos. Įdiek POM į /Applications ir bandyk vėl."
            }
        }
    }

    static let label = "lt.ponasobuolys.pom"

    static var plistURL: URL {
        FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent("Library/LaunchAgents/\(label).plist")
    }

    static var isEnabled: Bool {
        FileManager.default.fileExists(atPath: plistURL.path)
    }

    static func setEnabled(_ enabled: Bool) throws {
        if enabled {
            try install()
        } else {
            try remove()
        }
    }

    private static func install() throws {
        guard let executable = Bundle.main.executablePath, !executable.isEmpty else {
            throw LoginItemError.executableNotFound
        }

        let plist: [String: Any] = [
            "Label": label,
            "ProgramArguments": [executable],
            "RunAtLoad": true,
            "KeepAlive": false,
            "ProcessType": "Interactive",
        ]

        let directory = plistURL.deletingLastPathComponent()
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)

        let data = try PropertyListSerialization.data(
            fromPropertyList: plist, format: .xml, options: 0)
        try data.write(to: plistURL, options: .atomic)
    }

    private static func remove() throws {
        // Jei aprašas jau įkeltas, iškart jį išregistruojame; klaidos čia nesvarbios,
        // nes gali būti tiesiog neįkeltas.
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/bin/launchctl")
        process.arguments = ["bootout", "gui/\(getuid())/\(label)"]
        process.standardOutput = Pipe()
        process.standardError = Pipe()
        try? process.run()
        process.waitUntilExit()

        if FileManager.default.fileExists(atPath: plistURL.path) {
            try FileManager.default.removeItem(at: plistURL)
        }
    }
}
