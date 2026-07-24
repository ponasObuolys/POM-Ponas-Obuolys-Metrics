import Foundation

/// Lietuviški laiko užrašai. Trumpiniai pagal bendrinės kalbos normą:
/// „val.“ ir „d.“ su tašku, matavimo simboliai „min“ ir „s“ be taško.
public enum LTFormat {
    public static func countdown(to target: Date, now: Date) -> String {
        let remaining = target.timeIntervalSince(now)
        guard remaining > 0 else { return "atsistatė" }

        let total = Int(remaining.rounded(.down))
        if total < 60 { return "po mažiau nei min." }
        if total < 3600 { return "po \(total / 60) min" }

        if total < 86400 {
            let hours = total / 3600
            let minutes = (total % 3600) / 60
            return minutes == 0 ? "po \(hours) val." : "po \(hours) val. \(minutes) min"
        }

        let days = total / 86400
        let hours = (total % 86400) / 3600
        return hours == 0 ? "po \(days) d." : "po \(days) d. \(hours) val."
    }

    public static func age(from: Date, now: Date) -> String {
        let elapsed = max(0, now.timeIntervalSince(from))
        let total = Int(elapsed.rounded(.down))

        if total < 5 { return "ką tik" }
        if total < 60 { return "prieš \(total) s" }
        if total < 3600 { return "prieš \(total / 60) min" }
        if total < 86400 { return "prieš \(total / 3600) val." }
        return "prieš \(total / 86400) d."
    }

    /// Tikslus atsistatymo momentas: šiandienai – tik laikas, kitoms dienoms – ir data.
    public static func absolute(_ date: Date, now: Date = Date(), calendar: Calendar = .current) -> String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "lt_LT")

        if calendar.isDate(date, inSameDayAs: now) {
            formatter.setLocalizedDateFormatFromTemplate("HH:mm")
        } else {
            formatter.setLocalizedDateFormatFromTemplate("MMM d HH:mm")
        }
        return formatter.string(from: date)
    }
}
