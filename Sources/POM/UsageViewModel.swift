import Foundation
import POMCore
import SwiftUI

@MainActor
final class UsageViewModel: ObservableObject {
    @Published private(set) var now = Date()
    @Published private(set) var snapshot: UsageSnapshot?
    @Published private(set) var serverNote: String?

    let settings: Settings
    let notifications: NotificationService

    private let localStore = SnapshotStore()
    private let serverStore = SnapshotStore(fileURL: POMPaths.serverCacheFile, source: .server)
    private let client = OAuthUsageClient()

    private var localSnapshot: UsageSnapshot?
    private var serverSnapshot: UsageSnapshot?
    private var lastLocalFileDate: Date?
    private var gate = ServerFetchGate(enabled: true)
    private var tracker: AlertTracker
    private var isFetching = false
    private var timer: Timer?

    /// Kas kiek tikrinamas failas ir perpiešiama ikona.
    private let tickInterval: TimeInterval = 5

    init(settings: Settings, notifications: NotificationService) {
        self.settings = settings
        self.notifications = notifications
        self.tracker = AlertTracker(thresholds: settings.alertPreset.thresholds)

        serverSnapshot = serverStore.load()
        reloadLocal(force: true)
        recompute()
    }

    // MARK: - Rodomos reikšmės

    var hasData: Bool { snapshot != nil }

    var fiveHour: DisplayWindow {
        guard let snapshot else { return .empty }
        return UsageDisplay.resolve(snapshot.fiveHour, now: now)
    }

    var sevenDay: DisplayWindow {
        guard let snapshot else { return .empty }
        return UsageDisplay.resolve(snapshot.sevenDay, now: now)
    }

    var freshness: Freshness {
        UsageDisplay.freshness(capturedAt: snapshot?.capturedAt, now: now)
    }

    var ageText: String {
        guard let snapshot else { return "duomenų dar nėra" }
        return "Atnaujinta " + LTFormat.age(from: snapshot.capturedAt, now: now)
    }

    var sourceText: String {
        switch snapshot?.source {
        case .statusline: return "iš Claude Code"
        case .server: return "iš serverio"
        case nil: return ""
        }
    }

    // MARK: - Ciklas

    func start() {
        let timer = Timer(timeInterval: tickInterval, repeats: true) { [weak self] _ in
            Task { @MainActor in self?.tick() }
        }
        timer.tolerance = 1
        RunLoop.main.add(timer, forMode: .common)
        self.timer = timer
        tick()
    }

    func stop() {
        timer?.invalidate()
        timer = nil
    }

    /// Iškviečiama atidarant langelį, kad skaičiai būtų kuo šviežesni.
    func refreshNow() {
        tick()
    }

    func requestServerRefresh() {
        fetchFromServer(manual: true)
    }

    private func tick() {
        now = Date()
        reloadLocal(force: false)
        recompute()
        deliverAlerts()
        fetchFromServer(manual: false)
    }

    private func reloadLocal(force: Bool) {
        let fileDate = localStore.modificationDate
        if !force, fileDate == lastLocalFileDate, localSnapshot != nil { return }
        lastLocalFileDate = fileDate
        if let loaded = localStore.load() {
            localSnapshot = loaded
        }
    }

    private func recompute() {
        let candidates = [localSnapshot, serverSnapshot].compactMap { $0 }
        snapshot = candidates.max { $0.capturedAt < $1.capturedAt }
    }

    // MARK: - Perspėjimai

    private func deliverAlerts() {
        // Kol pranešimų kelias nepasirinktas, žymų neliečiame: kitaip pirmasis
        // ribos peržengimas būtų pažymėtas kaip praneštas, o vartotojas nieko nepamatytų.
        guard notifications.isReady else { return }

        tracker.updateThresholds(settings.alertPreset.thresholds)
        guard settings.notificationsEnabled, hasData else { return }

        alert(window: .fiveHour, display: fiveHour, name: "5 valandų")
        alert(window: .sevenDay, display: sevenDay, name: "7 dienų")
    }

    private func alert(window: AlertTracker.Window, display: DisplayWindow, name: String) {
        guard
            let threshold = tracker.check(
                window: window, percentage: display.usedPercentage, resetsAt: display.resetsAt)
        else { return }

        let remaining = Int(display.remainingPercentage.rounded())
        var body = "Sunaudota \(threshold) % ar daugiau, liko \(remaining) %."
        if let resetsAt = display.resetsAt {
            let countdown = LTFormat.countdown(to: resetsAt, now: now)
            body += " Atsistato " + LTFormat.endingWithPeriod(countdown)
        }
        notifications.post(title: "\(name) limitas baigiasi", body: body)
    }

    // MARK: - Serveris

    private func fetchFromServer(manual: Bool) {
        guard !isFetching else { return }

        gate.enabled = settings.serverFallbackEnabled
        let decision = gate.decide(localCapturedAt: snapshot?.capturedAt, now: now, manual: manual)

        guard decision == .fetch else {
            if manual { serverNote = note(for: decision) }
            return
        }

        isFetching = true
        gate.recordAttempt(at: now)
        if manual { serverNote = "Klausiama serverio…" }

        let client = self.client
        Task {
            do {
                let token = try await Task.detached(priority: .utility) {
                    try KeychainToken.claudeCodeAccessToken()
                }.value
                let fresh = try await client.fetch(token: token)
                handleSuccess(fresh)
            } catch {
                handleFailure(error, manual: manual)
            }
        }
    }

    private func handleSuccess(_ fresh: UsageSnapshot) {
        isFetching = false
        gate.recordSuccess()
        serverSnapshot = fresh
        try? serverStore.save(fresh)
        serverNote = nil
        recompute()
        deliverAlerts()
    }

    private func handleFailure(_ error: Error, manual: Bool) {
        isFetching = false
        gate.recordFailure()

        let reason: String
        switch error {
        case OAuthUsageClient.ClientError.rateLimited:
            reason = "serveris atmetė užklausą (per dažnai)"
        case OAuthUsageClient.ClientError.http(let code):
            reason = "serveris atsakė klaida \(code)"
        case KeychainToken.TokenError.expired:
            reason = "prisijungimo raktas nebegalioja"
        case KeychainToken.TokenError.claudeAccountNotFound:
            // Šiame kompiuteryje Claude prenumeratos rakto raktinėje nėra, tad serverio
            // klausti neįmanoma. Skaičiai toliau imami iš Claude Code, ir to pakanka.
            serverNote =
                "Serverio klausti nepavyksta: raktinėje nėra Claude prisijungimo rakto. "
                + "Skaičiai imami iš Claude Code."
            return
        case KeychainToken.TokenError.commandFailed, KeychainToken.TokenError.unreadableSecret:
            reason = "nepavyko perskaityti raktinės"
        default:
            reason = "nepavyko susisiekti su serveriu"
        }

        let retryAt = now.addingTimeInterval(gate.backoffInterval)
        serverNote = "Serveris: \(reason). Bandoma vėl \(LTFormat.absolute(retryAt, now: now))."
        _ = manual
    }

    private func note(for decision: ServerFetchGate.Decision) -> String? {
        switch decision {
        case .fetch:
            return nil
        case .skipDisabled:
            return "Serverio klausimas išjungtas nustatymuose."
        case .skipLocalFresh:
            return "Duomenys jau švieži, serverio klausti nereikia."
        case .skipBackoff:
            return "Serveris neseniai atmetė užklausą, laukiama."
        case .skipManualFloor:
            return "Per dažnai. Serverio galima klausti kartą per 5 min."
        }
    }
}

extension DisplayWindow {
    static let empty = DisplayWindow(usedPercentage: 0, resetsAt: nil, didReset: false)
}
