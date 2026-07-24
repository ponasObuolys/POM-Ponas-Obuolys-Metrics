import Foundation

/// Kur programa laiko savo duomenis.
public enum POMPaths {
    public static var supportDirectory: URL {
        let base = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
        return base.appendingPathComponent("POM", isDirectory: true)
    }

    /// Failas, į kurį rašo statusline tiltas.
    public static var snapshotFile: URL {
        supportDirectory.appendingPathComponent("snapshot.json")
    }

    /// Paskutinis serverio atsakymas, kad išliktų ir po perkrovimo.
    public static var serverCacheFile: URL {
        supportDirectory.appendingPathComponent("server-snapshot.json")
    }
}

/// Skaito tilto įrašytą failą. Sugadintas failas grąžina `nil`, o ne griauna programą.
public struct SnapshotStore: Sendable {
    public let fileURL: URL
    public let source: UsageSnapshot.Source

    public init(fileURL: URL, source: UsageSnapshot.Source = .statusline) {
        self.fileURL = fileURL
        self.source = source
    }

    public init() {
        self.init(fileURL: POMPaths.snapshotFile)
    }

    public func load(now: Date = Date()) -> UsageSnapshot? {
        guard let data = try? Data(contentsOf: fileURL) else { return nil }
        return try? UsageParser.parse(data: data, source: source, capturedAt: now)
    }

    public var modificationDate: Date? {
        let attributes = try? FileManager.default.attributesOfItem(atPath: fileURL.path)
        return attributes?[.modificationDate] as? Date
    }

    /// Atominis įrašymas: pirma laikinas failas, tada pervadinimas.
    public func save(_ snapshot: UsageSnapshot) throws {
        let directory = fileURL.deletingLastPathComponent()
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)

        let payload: [String: Any] = [
            "schema": 1,
            "source": snapshot.source.rawValue,
            "captured_at": snapshot.capturedAt.timeIntervalSince1970,
            "five_hour": encode(snapshot.fiveHour),
            "seven_day": encode(snapshot.sevenDay),
        ]
        let data = try JSONSerialization.data(withJSONObject: payload, options: [])

        let temporary = directory.appendingPathComponent("\(fileURL.lastPathComponent).\(getpid()).tmp")
        try data.write(to: temporary, options: .atomic)
        _ = try FileManager.default.replaceItemAt(fileURL, withItemAt: temporary)
    }

    private func encode(_ window: UsageWindow) -> [String: Any] {
        var dict: [String: Any] = ["used_percentage": window.usedPercentage]
        if let resetsAt = window.resetsAt {
            dict["resets_at"] = resetsAt.timeIntervalSince1970
        }
        return dict
    }
}
