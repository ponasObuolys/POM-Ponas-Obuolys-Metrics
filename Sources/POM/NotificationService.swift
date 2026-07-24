import Foundation
import POMCore
import UserNotifications

/// macOS pranešimai apie besibaigiantį limitą.
///
/// Pranešimai siunčiami dviem keliais. Pirmenybė teikiama įprastam macOS keliui
/// (`UNUserNotificationCenter`) – tada pranešimas rodomas POM vardu su jos ikona.
/// Tačiau savo kompiuteryje surinktos ir vietiniu parašu pasirašytos programos
/// pranešimų sistemoje neužsiregistruoja: užklausa priimama, bet niekas nerodoma.
/// Tokiu atveju pereinama prie sisteminės `osascript` komandos, kuri veikia visada.
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
        delivery = await requestAuthorization() ? .system : .script
        isReady = true
    }

    func post(title: String, body: String) {
        switch delivery {
        case .system:
            let content = UNMutableNotificationContent()
            content.title = title
            content.body = body
            content.sound = .default
            let request = UNNotificationRequest(
                identifier: UUID().uuidString, content: content, trigger: nil)
            UNUserNotificationCenter.current().add(request)

        case .script:
            postViaScript(title: title, body: body)

        case .unavailable:
            break
        }
    }

    var statusNote: String? {
        switch delivery {
        case .system:
            return nil
        case .script:
            return "Pranešimus rodo macOS scenarijų įrankis (POM pasirašyta vietiniu parašu)."
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
                let granted = try? await UNUserNotificationCenter.current()
                    .requestAuthorization(options: [.alert, .sound])
                return granted ?? false
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

    private func postViaScript(title: String, body: String) {
        let script = "display notification \(AppleScriptString.quoted(body)) "
            + "with title \(AppleScriptString.quoted(title))"

        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/osascript")
        process.arguments = ["-e", script]
        process.standardOutput = Pipe()
        process.standardError = Pipe()
        try? process.run()
    }
}
