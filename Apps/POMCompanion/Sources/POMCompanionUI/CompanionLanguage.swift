import Foundation
import POMUsageKit

struct CompanionLanguage {
    let value: String
    var isLithuanian: Bool {
        value == "lt" || (value == "system" && Locale.preferredLanguages.first?.hasPrefix("lt") == true)
    }
    var locale: Locale { Locale(identifier: isLithuanian ? "lt_LT" : "en_US") }
    func text(_ en: String, _ lt: String) -> String { isLithuanian ? lt : en }
    func day(_ key: String) -> String {
        let formatter = DateFormatter()
        formatter.locale = locale
        formatter.timeZone = TimeZone(secondsFromGMT: 0)
        formatter.setLocalizedDateFormatFromTemplate("MMM d")
        return UsageDay.date(key).map(formatter.string) ?? key
    }
    func captured(_ date: Date) -> String {
        date.formatted(.dateTime.locale(locale).year().month(.abbreviated).day().hour().minute())
    }
    func number(_ value: Int64) -> String { value.formatted(.number.locale(locale)) }
}
