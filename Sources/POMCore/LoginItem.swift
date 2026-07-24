import Foundation

/// Automatinis paleidimas prisijungus prie macOS.
///
/// Naudojamas LaunchAgent aprašas, o ne `SMAppService`: pastarasis patikimai veikia tik su
/// tikru Apple kūrėjo parašu. Aprašas įsigalioja kitą kartą prisijungus prie kompiuterio.
public struct LoginItem: Sendable {
    public enum LoginItemError: LocalizedError, Equatable {
        case executableNotFound

        public var errorDescription: String? {
            switch self {
            case .executableNotFound:
                return "Nepavyko rasti programos vietos. Įdiek POM į /Applications ir bandyk vėl."
            }
        }
    }

    public static let label = "lt.ponasobuolys.pom"

    public let plistURL: URL
    public let executablePath: String?
    private let bootoutOnRemove: Bool

    public init(
        plistURL: URL? = nil,
        executablePath: String? = Bundle.main.executablePath,
        bootoutOnRemove: Bool = true
    ) {
        self.plistURL =
            plistURL
            ?? FileManager.default.homeDirectoryForCurrentUser
                .appendingPathComponent("Library/LaunchAgents/\(Self.label).plist")
        self.executablePath = executablePath
        self.bootoutOnRemove = bootoutOnRemove
    }

    public var isEnabled: Bool {
        FileManager.default.fileExists(atPath: plistURL.path)
    }

    public func setEnabled(_ enabled: Bool) throws {
        if enabled {
            try install()
        } else {
            try remove()
        }
    }

    private func install() throws {
        guard let executablePath, !executablePath.isEmpty else {
            throw LoginItemError.executableNotFound
        }

        let plist: [String: Any] = [
            "Label": Self.label,
            "ProgramArguments": [executablePath],
            "RunAtLoad": true,
            "KeepAlive": false,
            "ProcessType": "Interactive",
        ]

        try FileManager.default.createDirectory(
            at: plistURL.deletingLastPathComponent(), withIntermediateDirectories: true)
        let data = try PropertyListSerialization.data(
            fromPropertyList: plist, format: .xml, options: 0)
        try data.write(to: plistURL, options: .atomic)
    }

    private func remove() throws {
        if bootoutOnRemove {
            // Jei aprašas jau įkeltas, iškart išregistruojamas. Klaidos čia nesvarbios:
            // dažniausiai jis tiesiog dar neįkeltas.
            let process = Process()
            process.executableURL = URL(fileURLWithPath: "/bin/launchctl")
            process.arguments = ["bootout", "gui/\(getuid())/\(Self.label)"]
            process.standardOutput = Pipe()
            process.standardError = Pipe()
            try? process.run()
            process.waitUntilExit()
        }

        if FileManager.default.fileExists(atPath: plistURL.path) {
            try FileManager.default.removeItem(at: plistURL)
        }
    }
}
