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

    var title: String {
        switch self {
        case .early: return "Anksti (70 % ir 90 %)"
        case .standard: return "Įprastai (80 % ir 95 %)"
        case .late: return "Vėlai (90 % ir 98 %)"
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

    private let loginItem = LoginItem()

    @Published var launchAtLogin: Bool {
        didSet {
            guard launchAtLogin != loginItem.isEnabled else { return }
            do {
                try loginItem.setEnabled(launchAtLogin)
                launchAtLoginError = nil
            } catch {
                launchAtLoginError = error.localizedDescription
                launchAtLogin = loginItem.isEnabled
            }
        }
    }

    @Published var launchAtLoginError: String?
    @Published var notificationsUnavailable: String?

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
        ])

        showRemaining = defaults.bool(forKey: Key.showRemaining)
        serverFallbackEnabled = defaults.bool(forKey: Key.serverFallback)
        notificationsEnabled = defaults.bool(forKey: Key.notifications)
        alertPreset =
            AlertPreset(rawValue: defaults.string(forKey: Key.alertPreset) ?? "") ?? .standard
        launchAtLogin = loginItem.isEnabled
    }
}
