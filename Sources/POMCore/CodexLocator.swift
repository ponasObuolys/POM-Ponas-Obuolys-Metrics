import Foundation

/// Ar Codex apskritai yra šiame kompiuteryje ir ar juo galima pasinaudoti.
public enum CodexAvailability: Equatable, Sendable {
    /// Codex nerastas. Sekcija nerodoma visai: tuščias langas be paaiškinimo tik glumintų.
    case notInstalled
    /// Codex yra, bet prie paskyros neprisijungta, tad limitų jis nežino.
    case signedOut
    /// Viskas paruošta, žinomas ir vykdomojo failo kelias.
    case ready(URL)
}

/// Randa Codex ir pasako, ar jis prisijungęs.
public enum CodexLocator {
    /// Kur ieškoma `codex`.
    ///
    /// Meniu juostos programa nepaveldi terminalo `PATH`, todėl keliai surašomi tiesiogiai.
    /// Tuo pačiu principu programa jau ieško `jq`.
    public static var defaultSearchPaths: [String] {
        let home = FileManager.default.homeDirectoryForCurrentUser.path
        return [
            "/opt/homebrew/bin/codex",
            "/usr/local/bin/codex",
            "\(home)/.local/bin/codex",
            "\(home)/.bun/bin/codex",
            "\(home)/.volta/bin/codex",
        ]
    }

    /// Kur Codex laiko prisijungimo duomenis.
    public static func defaultAuthFile(home: URL) -> URL {
        home.appendingPathComponent(".codex/auth.json")
    }

    public static func availability(
        searchPaths: [String]? = nil,
        authFile: URL? = nil,
        fileManager: FileManager = .default
    ) -> CodexAvailability {
        let paths = searchPaths ?? defaultSearchPaths
        let auth = authFile ?? defaultAuthFile(home: fileManager.homeDirectoryForCurrentUser)

        guard let executable = executableURL(searchPaths: paths, fileManager: fileManager) else {
            return .notInstalled
        }
        guard isSignedIn(authFile: auth) else { return .signedOut }
        return .ready(executable)
    }

    public static func executableURL(
        searchPaths: [String], fileManager: FileManager = .default
    ) -> URL? {
        for path in searchPaths where fileManager.isExecutableFile(atPath: path) {
            return URL(fileURLWithPath: path)
        }
        return nil
    }

    /// Prisijungimas atpažįstamas iš rakto buvimo, o ne iš klausimo Codex.
    ///
    /// Taip išvengiama proceso paleidimo vien tam, kad sužinotume, jog atsakymo nebus.
    /// Tuščia rakto reikšmė prilyginama neprisijungimui: toks failas lieka po `codex logout`.
    public static func isSignedIn(authFile: URL) -> Bool {
        guard let data = try? Data(contentsOf: authFile),
            let json = try? JSONSerialization.jsonObject(with: data, options: []),
            let root = json as? [String: Any]
        else {
            return false
        }

        if let key = root["OPENAI_API_KEY"] as? String, !key.isEmpty { return true }
        if let tokens = root["tokens"] as? [String: Any],
            let token = tokens["access_token"] as? String, !token.isEmpty
        {
            return true
        }
        return false
    }
}
