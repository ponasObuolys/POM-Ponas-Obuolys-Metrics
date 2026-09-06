import Foundation

public enum AppLanguage: String, CaseIterable, Identifiable, Sendable {
    case system, lt, en
    public var id: String { rawValue }
    public func resolved(preferredLanguages: [String] = Locale.preferredLanguages) -> Self {
        guard self == .system else { return self }
        return preferredLanguages.first?.lowercased().hasPrefix("lt") == true ? .lt : .en
    }
    public var locale: Locale { Locale(identifier: resolved() == .lt ? "lt_LT" : "en_US") }
    public func text(_ lt: String, _ en: String) -> String { resolved() == .lt ? lt : en }
    public func age(from: Date, now: Date) -> String {
        guard resolved() == .en else { return LTFormat.age(from: from, now: now) }
        let seconds = max(0, Int(now.timeIntervalSince(from)))
        if seconds < 5 { return "just now" }
        if seconds < 60 { return "\(seconds)s ago" }
        if seconds < 3600 { return "\(seconds / 60)m ago" }
        if seconds < 86400 { return "\(seconds / 3600)h ago" }
        return "\(seconds / 86400)d ago"
    }
    public func countdown(to date: Date, now: Date) -> String {
        guard resolved() == .en else { return LTFormat.countdown(to: date, now: now) }
        let seconds = Int(date.timeIntervalSince(now))
        if seconds <= 0 { return "reset due" }
        if seconds < 60 { return "in <1m" }
        if seconds < 3600 { return "in \(seconds / 60)m" }
        if seconds < 86400 { return "in \(seconds / 3600)h \((seconds % 3600) / 60)m" }
        return "in \(seconds / 86400)d \((seconds % 86400) / 3600)h"
    }
    public func windowTitle(minutes: Int) -> String {
        guard resolved() == .en else { return LTFormat.windowTitle(minutes: minutes) }
        if minutes <= 0 { return "Usage limit" }
        if minutes % 1440 == 0 { return "\(minutes / 1440)-day" }
        if minutes % 60 == 0 { return "\(minutes / 60)-hour" }
        return "\(minutes)-minute"
    }
    public func absolute(_ date: Date, now: Date = Date()) -> String {
        let formatter = DateFormatter(); formatter.locale = locale
        formatter.setLocalizedDateFormatFromTemplate(Calendar.current.isDate(date, inSameDayAs: now) ? "j:mm" : "MMM d j:mm")
        return formatter.string(from: date)
    }
}
