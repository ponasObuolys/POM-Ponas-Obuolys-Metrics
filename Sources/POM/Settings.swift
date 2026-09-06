import Foundation
import POMCore
import SwiftUI

/// Kada perspėti apie besibaigiantį limitą.
enum AlertPreset: String, CaseIterable, Identifiable {
    case early
    case standard
    case late

    var id: String { rawValue }

    var thresholds: [Int] {
        switch self {
        case .early: return [70, 90]
        case .standard: return [80, 95]
        case .late: return [90, 98]
        }
    }

    func title(_ language: AppLanguage) -> String {
        switch self {
        case .early: return language.text("Anksti (70 % ir 90 %)", "Early (70% and 90%)")
        case .standard: return language.text("Įprastai (80 % ir 95 %)", "Standard (80% and 95%)")
        case .late: return language.text("Vėlai (90 % ir 98 %)", "Late (90% and 98%)")
        }
    }
}

/// Kurio įrankio skaičiai rodomi prie laikrodžio. Vietos ten tiek, kad telpa vienas.
enum MenuBarSource: String, CaseIterable, Identifiable {
    case claude
    case fable
    case codex

    var id: String { rawValue }

    var title: String {
        switch self {
        case .claude: return "Claude"
        case .fable: return "Fable"
        case .codex: return "Codex"
        }
    }
}

@MainActor
final class Settings: ObservableObject {
    private enum Key {
        static let showRemaining = "showRemaining"
        static let serverFallback = "serverFallbackEnabled"
        static let notifications = "notificationsEnabled"
        static let alertPreset = "alertPreset"
        static let menuBarSource = "menuBarSource"
    }

    private let defaults: UserDefaults

    @Published var showRemaining: Bool {
        didSet { defaults.set(showRemaining, forKey: Key.showRemaining) }
    }

    @Published var serverFallbackEnabled: Bool {
        didSet { defaults.set(serverFallbackEnabled, forKey: Key.serverFallback) }
    }

    @Published var notificationsEnabled: Bool {
        didSet { defaults.set(notificationsEnabled, forKey: Key.notifications) }
    }

    @Published var alertPreset: AlertPreset {
        didSet { defaults.set(alertPreset.rawValue, forKey: Key.alertPreset) }
    }

    @Published private(set) var menuBarSources: [MenuBarSource]
    @Published var language: AppLanguage {
        didSet { defaults.set(language.rawValue, forKey: "language") }
    }
    @Published var recoveryNotifications: Bool {
        didSet { defaults.set(recoveryNotifications, forKey: "recoveryNotifications") }
    }
    var locale: Locale { language.locale }
    func text(_ lt: String, _ en: String) -> String { language.text(lt, en) }
    func setSource(_ source: MenuBarSource, enabled: Bool) {
        var selected = Set(menuBarSources)
        if enabled { selected.insert(source) } else { selected.remove(source) }
        guard !selected.isEmpty else { return }
        menuBarSources = MenuBarSource.allCases.filter { selected.contains($0) }
        defaults.set(menuBarSources.map(\.rawValue), forKey: "menuBarSources")
    }


    private let loginItem = LoginItem()

    @Published var launchAtLogin: Bool {
        didSet {
            guard launchAtLogin != loginItem.isEnabled else { return }
            do {
                try loginItem.setEnabled(launchAtLogin)
                launchAtLoginFailed = false
            } catch {
                launchAtLoginFailed = true
                launchAtLogin = loginItem.isEnabled
            }
        }
    }

    @Published private var launchAtLoginFailed = false
    var launchAtLoginError: String? {
        launchAtLoginFailed ? text("Nepavyko pakeisti automatinio paleidimo. Įdiek POM į Applications ir bandyk vėl.",
                                  "Could not change launch at login. Install POM in Applications and try again.") : nil
    }

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        // Serverio klausimas išjungtas iš pradžių sąmoningai. Pirma, jam reikia rakto su
        // „user:profile“ teise, kurios įprastai nėra. Antra, vien bandymas perskaityti
        // raktinę iššauktų macOS leidimo langelį – per pirmą paleidimą tai tik gąsdintų.
        defaults.register(defaults: [
            Key.showRemaining: false,
            Key.serverFallback: false,
            Key.notifications: true,
            Key.alertPreset: AlertPreset.standard.rawValue,
            Key.menuBarSource: MenuBarSource.claude.rawValue,
            "language": AppLanguage.system.rawValue,
            "recoveryNotifications": true,
        ])

        showRemaining = defaults.bool(forKey: Key.showRemaining)
        serverFallbackEnabled = defaults.bool(forKey: Key.serverFallback)
        notificationsEnabled = defaults.bool(forKey: Key.notifications)
        alertPreset =
            AlertPreset(rawValue: defaults.string(forKey: Key.alertPreset) ?? "") ?? .standard
        let oldSource = MenuBarSource(rawValue: defaults.string(forKey: Key.menuBarSource) ?? "") ?? .claude
        let sources = defaults.stringArray(forKey: "menuBarSources")?.compactMap(MenuBarSource.init(rawValue:)) ?? [oldSource]
        menuBarSources = sources.isEmpty ? [.claude] : MenuBarSource.allCases.filter { sources.contains($0) }
        language = AppLanguage(rawValue: defaults.string(forKey: "language") ?? "") ?? .system
        recoveryNotifications = defaults.bool(forKey: "recoveryNotifications")
        launchAtLogin = loginItem.isEnabled
    }
}
