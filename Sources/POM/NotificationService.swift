import AppKit
import Foundation
import POMCore
import UserNotifications

/// macOS pranešimai apie besibaigiantį limitą.
///
/// Pranešimai siunčiami dviem keliais. Pirmenybė teikiama įprastam macOS keliui
/// (`UNUserNotificationCenter`) – tada pranešimas rodomas POM vardu su jos ikona.
///
/// Tačiau macOS pranešimų registracijai reikalauja Apple išduoto kūrėjo parašo.
/// Patikrinta: nei laikinas (ad-hoc), nei savadarbis pastovus parašas nepadeda,
/// net ir pažymėjus sertifikatą kaip patikimą – atsakoma „Notifications are not
/// allowed for this application“. Todėl naudojamas atsarginis kelias per sisteminę
/// `osascript` komandą, kuri veikia visada. Pranešime POM nurodoma antrašte,
/// kad būtų aišku, kas praneša.
@MainActor
final class NotificationService: NSObject, UNUserNotificationCenterDelegate {
    enum Delivery {
        /// Įprastas macOS kelias, pranešimas rodomas POM vardu.
        case system
        /// Atsarginis kelias per sisteminį scenarijų.
        case script
        /// Programa paleista be paketo, pranešimai negalimi.
        case unavailable
    }

    private(set) var delivery: Delivery = .unavailable
    /// Kol kelias nepasirinktas, perspėjimų siųsti negalima – jie tiesiog dingtų.
    private(set) var isReady = false
    private var didPrepare = false

    /// Kiek laukiama macOS atsakymo. Kai kuriose sistemose atsakymo neateina niekada,
    /// todėl laukiama ribotai ir pereinama prie atsarginio kelio.
    private let authorizationTimeout: TimeInterval = 4

    func prepare() async {
        guard !didPrepare else { return }
        didPrepare = true

        guard Bundle.main.bundleIdentifier != nil else {
            delivery = .unavailable
            isReady = true
            return
        }

        UNUserNotificationCenter.current().delegate = self
        // Leidimo langelį macOS rodo tik aktyviai programai. POM gyvena meniu juostoje ir
        // priekiniame plane nebūna niekada, todėl užklausos metu ji trumpam aktyvuojama.
        NSApplication.shared.activate(ignoringOtherApps: true)
        delivery = await requestAuthorization() ? .system : .script
        isReady = true
    }

    func post(subtitle: String, body: String) {
        switch delivery {
        case .system:
            let content = UNMutableNotificationContent()
            content.title = subtitle
            content.body = body
            content.sound = .default
            let request = UNNotificationRequest(
                identifier: UUID().uuidString, content: content, trigger: nil)
            UNUserNotificationCenter.current().add(request)

        case .script:
            postViaScript(title: "POM", subtitle: subtitle, body: body)

        case .unavailable:
            break
        }
    }

    var statusNote: String? {
        switch delivery {
        case .system, .script:
            return nil
        case .unavailable:
            return "Pranešimai veikia tik įdiegus programą į /Applications."
        }
    }

    /// Rodyti pranešimą net tada, kai POM yra priekiniame plane.
    nonisolated func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        willPresent notification: UNNotification
    ) async -> UNNotificationPresentationOptions {
        [.banner, .sound]
    }

    // MARK: - Pagalbinės

    private func requestAuthorization() async -> Bool {
        let timeout = authorizationTimeout
        return await withTaskGroup(of: Bool?.self) { group in
            group.addTask {
                (try? await UNUserNotificationCenter.current()
                    .requestAuthorization(options: [.alert, .sound])) ?? false
            }
            group.addTask {
                try? await Task.sleep(nanoseconds: UInt64(timeout * 1_000_000_000))
                return nil
            }

            let first = await group.next() ?? nil
            group.cancelAll()
            return first ?? false
        }
    }

    private func postViaScript(title: String, subtitle: String, body: String) {
        let script = "display notification \(AppleScriptString.quoted(body)) "
            + "with title \(AppleScriptString.quoted(title)) "
            + "subtitle \(AppleScriptString.quoted(subtitle))"

        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/osascript")
        process.arguments = ["-e", script]
        process.standardOutput = Pipe()
        process.standardError = Pipe()
        try? process.run()
    }
}
