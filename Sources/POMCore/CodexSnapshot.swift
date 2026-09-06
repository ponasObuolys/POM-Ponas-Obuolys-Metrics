import Foundation

/// Codex limito būsena viename momente.
///
/// Codex grąžina kelis limitų rinkinius (bendrą ir atskirų modelių), o kiekvienas jų turi
/// iki dviejų langų. POM rodo vieną skaičių: ilgiausią pagrindinio rinkinio langą.
/// Praktiškai tai savaitės limitas, tas pats, kurį ChatGPT programa vadina „Weekly usage limit“.
public struct CodexSnapshot: Equatable, Sendable {
    public let window: UsageWindow
    /// Lango trukmė minutėmis: 10080 yra savaitė, 300 – penkios valandos.
    public let windowMinutes: Int
    public let capturedAt: Date
    public let planType: String?
    public let additionalUsage: CodexAdditionalUsage
    public let ordinaryUsageAllowed: Bool?

    public init(window: UsageWindow, windowMinutes: Int, capturedAt: Date, planType: String? = nil,
                additionalUsage: CodexAdditionalUsage = .init(), ordinaryUsageAllowed: Bool? = nil) {
        self.window = window
        self.windowMinutes = windowMinutes
        self.capturedAt = capturedAt
        self.planType = planType
        self.additionalUsage = additionalUsage
        self.ordinaryUsageAllowed = ordinaryUsageAllowed
    }
}

/// Skaito `codex app-server` atsakymą į `account/rateLimits/read` ir POM išsaugotą failą.
///
/// Raktų pavadinimai imami dviem atmainomis (`usedPercent` ir `used_percent`), nes ta pati
/// reikšmė Codex viduje keliauja abiem pavidalais, o POM savo failą rašo trečiuoju.
/// Vieno rakto laikytis būtų trapu: pasikeitus Codex versijai skaičiai tyliai dingtų.
public enum CodexParser {
    public enum ParseError: Error, Equatable {
        case notAnObject
        /// Codex atsakė klaida, pavyzdžiui, tokio metodo nėra.
        case rpcError(String)
        /// Atsakymas geras, bet limitų reikšmių jame nėra.
        case noLimits
    }

    public static func parse(data: Data, capturedAt: Date) throws -> CodexSnapshot {
        let raw = try JSONSerialization.jsonObject(with: data, options: [])
        guard let root = raw as? [String: Any] else { throw ParseError.notAnObject }

        if let error = root["error"] as? [String: Any] {
            let message = error["message"] as? String ?? "nežinoma klaida"
            throw ParseError.rpcError(message)
        }

        guard let limits = rateLimits(in: root) else { throw ParseError.noLimits }
        guard let (window, minutes) = longestWindow(in: limits) else { throw ParseError.noLimits }

        let captured = decodeDate(firstValue(root, ["captured_at", "capturedAt"])) ?? capturedAt
        return CodexSnapshot(window: window, windowMinutes: minutes, capturedAt: captured,
                             planType: firstValue(limits, ["planType", "plan_type"]) as? String,
                             additionalUsage: additionalUsage(in: root, limits: limits),
                             ordinaryUsageAllowed: (root["result"] as? [String: Any] ?? root)["ordinaryUsageAllowed"] as? Bool)
    }

    private static func additionalUsage(in root: [String: Any], limits: [String: Any]) -> CodexAdditionalUsage {
        let body = root["result"] as? [String: Any] ?? root
        if let cached = root["pomAdditionalUsage"],
           let data = try? JSONSerialization.data(withJSONObject: cached),
           let value = try? JSONDecoder().decode(CodexAdditionalUsage.self, from: data) { return value }
        var extra = CodexAdditionalUsage()
        if let credits = limits["credits"] as? [String: Any],
           let has = credits["hasCredits"] as? Bool, let unlimited = credits["unlimited"] as? Bool {
            extra.credits = CodexCredits(hasCredits: has, unlimited: unlimited, balance: credits["balance"] as? String)
        }
        if let cap = limits["individualLimit"] as? [String: Any],
           let limit = cap["limit"] as? String, let used = cap["used"] as? String,
           let remaining = finiteNumber(cap["remainingPercent"]), remaining <= 100 {
            extra.spendLimit = CodexSpendLimit(limit: limit, used: used, remainingPercent: remaining,
                                             resetsAt: decodeDate(cap["resetsAt"]))
        }
        extra.spendControlReached = limits["spendControlReached"] as? Bool
        if let resets = body["rateLimitResetCredits"] as? [String: Any] {
            if let count = resets["availableCount"] as? Int, count >= 0 { extra.resetCredits = count }
            let credits = resets["credits"] as? [[String: Any]] ?? []
            extra.nextResetCreditExpiry = credits.filter { ($0["status"] as? String)?.lowercased() == "available" }
                .compactMap { decodeDate($0["expiresAt"]) }.min()
        }
        return extra
    }

    // MARK: - Pagalbinės

    /// Limitų objektas gali gulėti trijose vietose: JSON-RPC atsakyme, jo viduje esančiame
    /// `rateLimits` lauke arba pačiame POM išsaugotame faile.
    private static func rateLimits(in root: [String: Any]) -> [String: Any]? {
        let body = root["result"] as? [String: Any] ?? root
        if let buckets = body["rateLimitsByLimitId"] as? [String: Any],
            let codex = buckets["codex"] as? [String: Any] {
            return codex
        }
        if let result = root["result"] as? [String: Any],
            let limits = result["rateLimits"] as? [String: Any] ?? result["rate_limits"]
                as? [String: Any]
        {
            return limits
        }
        if let limits = root["rateLimits"] as? [String: Any] ?? root["rate_limits"] as? [String: Any]
        {
            return limits
        }
        // POM savo failą rašo be apvalkalo, todėl langas gulti gali ir šaknyje.
        if root["used_percentage"] != nil || root["primary"] != nil { return root }
        return nil
    }

    /// Iš pagrindinio rinkinio langų renkamas ilgiausias.
    ///
    /// Papildomi `rateLimitsByLimitId` rinkiniai sąmoningai praleidžiami: jų atsiranda ir
    /// dingsta priklausomai nuo naudoto modelio, tad skaičius meniu juostoje šokinėtų be
    /// jokios vartotojui matomos priežasties.
    private static func longestWindow(in limits: [String: Any]) -> (UsageWindow, Int)? {
        var best: (UsageWindow, Int)?

        for key in ["primary", "secondary"] {
            guard let dict = limits[key] as? [String: Any] else { continue }
            guard let window = decodeWindow(dict) else { continue }
            let minutes = decodeMinutes(dict)
            if best == nil || minutes > best!.1 { best = (window, minutes) }
        }

        if best == nil, let window = decodeWindow(limits) {
            best = (window, decodeMinutes(limits))
        }
        return best
    }

    private static func decodeWindow(_ dict: [String: Any]) -> UsageWindow? {
        let percentValue = firstValue(
            dict, ["usedPercent", "used_percent", "used_percentage", "usedPercentage"])
        guard let percent = finiteNumber(percentValue), percent <= 100_000 else { return nil }
        let resets = decodeDate(firstValue(dict, ["resetsAt", "resets_at"]))
        return UsageWindow(usedPercentage: percent, resetsAt: resets)
    }

    private static func decodeMinutes(_ dict: [String: Any]) -> Int {
        let value = firstValue(
            dict, ["windowDurationMins", "window_duration_mins", "windowMinutes", "window_minutes"])
        guard let value = finiteNumber(value), value <= 10_000_000 else { return 0 }
        return Int(value)
    }

    private static func firstValue(_ dict: [String: Any], _ keys: [String]) -> Any? {
        for key in keys {
            guard let value = dict[key], !(value is NSNull) else { continue }
            return value
        }
        return nil
    }

    private static func decodeNumber(_ any: Any?) -> Double? {
        switch any {
        case let number as NSNumber: return number.doubleValue
        case let string as String: return Double(string)
        default: return nil
        }
    }

    private static func decodeDate(_ any: Any?) -> Date? {
        switch any {
        case let number as NSNumber:
            let seconds = number.doubleValue
            guard seconds > 0 else { return nil }
            return Date(timeIntervalSince1970: seconds > 1_000_000_000_000 ? seconds / 1000 : seconds)
        case let string as String:
            guard let seconds = Double(string) else { return nil }
            return Date(timeIntervalSince1970: seconds > 1_000_000_000_000 ? seconds / 1000 : seconds)
        default:
            return nil
        }
    }
}

/// Laiko paskutinę gerą Codex reikšmę, kad po perkrovimo skaičiai būtų matomi iš karto,
/// dar prieš pirmą naują atsakymą.
public struct CodexStore: Sendable {
    public let fileURL: URL

    public init(fileURL: URL) {
        self.fileURL = fileURL
    }

    public init() {
        self.init(fileURL: POMPaths.codexCacheFile)
    }

    public func load(now: Date = Date()) -> CodexSnapshot? {
        guard let data = try? Data(contentsOf: fileURL) else { return nil }
        return try? CodexParser.parse(data: data, capturedAt: now)
    }

    /// Atominis įrašymas: pirma laikinas failas, tada pervadinimas.
    public func save(_ snapshot: CodexSnapshot) throws {
        let directory = fileURL.deletingLastPathComponent()
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)

        var payload: [String: Any] = [
            "schema": 1,
            "captured_at": snapshot.capturedAt.timeIntervalSince1970,
            "window_minutes": snapshot.windowMinutes,
            "used_percentage": snapshot.window.usedPercentage,
        ]
        if let resetsAt = snapshot.window.resetsAt {
            payload["resets_at"] = resetsAt.timeIntervalSince1970
        }
        if let planType = snapshot.planType { payload["planType"] = planType }
        payload["ordinaryUsageAllowed"] = snapshot.ordinaryUsageAllowed
        payload["pomAdditionalUsage"] = try JSONSerialization.jsonObject(with: JSONEncoder().encode(snapshot.additionalUsage))
        let data = try JSONSerialization.data(withJSONObject: payload, options: [])

        let temporary = directory.appendingPathComponent("\(fileURL.lastPathComponent).\(getpid()).tmp")
        try data.write(to: temporary, options: .atomic)
        _ = try FileManager.default.replaceItemAt(fileURL, withItemAt: temporary)
    }
}
