import Foundation

/// Vieno limito lango būsena.
public struct UsageWindow: Equatable, Sendable {
    public let usedPercentage: Double
    public let resetsAt: Date?

    public init(usedPercentage: Double, resetsAt: Date?) {
        self.usedPercentage = usedPercentage
        self.resetsAt = resetsAt
    }
}

/// Abiejų limitų būsena viename momente.
public struct UsageSnapshot: Equatable, Sendable {
    public enum Source: String, Equatable, Sendable {
        case statusline
        case server
    }

    public let fiveHour: UsageWindow
    public let sevenDay: UsageWindow
    public let capturedAt: Date
    public let source: Source

    public init(fiveHour: UsageWindow, sevenDay: UsageWindow, capturedAt: Date, source: Source) {
        self.fiveHour = fiveHour
        self.sevenDay = sevenDay
        self.capturedAt = capturedAt
        self.source = source
    }
}

/// Skaito ir tilto, ir serverio JSON. Serverio atsakymo forma neaprašyta viešai,
/// todėl priimamos abi žinomos atmainos: objektas su langų raktais ir masyvas `limits`.
public enum UsageParser {
    public enum ParseError: Error, Equatable {
        case notAnObject
        case missingWindow(String)
    }

    private static let fiveHourKey = "fivehour"
    private static let sevenDayKey = "sevenday"
    private static let wrapperKeys = ["rate_limits", "rateLimits", "usage", "data", "limits"]

    public static func parse(
        data: Data,
        source: UsageSnapshot.Source,
        capturedAt fallback: Date
    ) throws -> UsageSnapshot {
        let raw = try JSONSerialization.jsonObject(with: data, options: [])
        guard let root = raw as? [String: Any] else { throw ParseError.notAnObject }

        var windows = collectWindows(from: root)
        if windows[fiveHourKey] == nil && windows[sevenDayKey] == nil {
            for key in wrapperKeys {
                guard let nested = root[key] else { continue }
                let inner = collectWindows(from: nested)
                if !inner.isEmpty {
                    windows = inner
                    break
                }
            }
        }

        guard let fiveHour = windows[fiveHourKey] else { throw ParseError.missingWindow("five_hour") }
        guard let sevenDay = windows[sevenDayKey] else { throw ParseError.missingWindow("seven_day") }

        let captured = decodeDate(firstValue(root, ["captured_at", "capturedAt"])) ?? fallback
        return UsageSnapshot(
            fiveHour: fiveHour, sevenDay: sevenDay, capturedAt: captured, source: source)
    }

    // MARK: - Pagalbinės

    /// Surenka langus pagal normalizuotą pavadinimą: `five_hour`, `fiveHour` ir `FIVE-HOUR`
    /// suvedami į tą patį raktą, o `seven_day_opus` lieka atskiras.
    private static func collectWindows(from any: Any) -> [String: UsageWindow] {
        var result: [String: UsageWindow] = [:]

        if let array = any as? [Any] {
            for element in array {
                guard let dict = element as? [String: Any] else { continue }
                guard let name = firstValue(dict, ["type", "name", "key", "id", "window"]) as? String
                else { continue }
                guard let window = decodeWindow(dict) else { continue }
                result[normalize(name)] = window
            }
            return result
        }

        guard let dict = any as? [String: Any] else { return result }

        if let nested = dict["limits"] {
            let inner = collectWindows(from: nested)
            if !inner.isEmpty { return inner }
        }

        for (key, value) in dict {
            guard let window = decodeWindow(value) else { continue }
            result[normalize(key)] = window
        }
        return result
    }

    private static func normalize(_ name: String) -> String {
        name.lowercased().filter { $0.isLetter || $0.isNumber }
    }

    private static func decodeWindow(_ any: Any) -> UsageWindow? {
        guard let dict = any as? [String: Any] else { return nil }
        let percentValue = firstValue(
            dict, ["used_percentage", "usedPercentage", "utilization", "used_percent", "percent"])
        guard let percent = decodeNumber(percentValue) else { return nil }
        let resets = decodeDate(firstValue(dict, ["resets_at", "resetsAt", "reset_at"]))
        return UsageWindow(usedPercentage: percent, resetsAt: resets)
    }

    /// Grąžina pirmą raktą, kurio reikšmė egzistuoja ir nėra `null`.
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
            // Kai kurie šaltiniai laiką pateikia milisekundėmis.
            return Date(timeIntervalSince1970: seconds > 1_000_000_000_000 ? seconds / 1000 : seconds)
        case let string as String:
            return isoDate(from: string)
        default:
            return nil
        }
    }

    private static func isoDate(from string: String) -> Date? {
        if let seconds = Double(string) {
            return Date(timeIntervalSince1970: seconds > 1_000_000_000_000 ? seconds / 1000 : seconds)
        }
        let withFraction = ISO8601DateFormatter()
        withFraction.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        if let date = withFraction.date(from: string) { return date }

        let plain = ISO8601DateFormatter()
        plain.formatOptions = [.withInternetDateTime]
        return plain.date(from: string)
    }
}
