import Foundation
import POMCore
import SwiftUI

/// Codex sekcijos būsena: ar Codex apskritai yra, kiek limito sunaudota ir kada klausti vėl.
///
/// Laikoma atskirai nuo Claude, nes tai visiškai kitas duomenų kelias: Claude reikšmės ateina
/// pačios per tiltą, o Codex klausiama pačiam. Sujungus abu į vieną vietą, kiekvienas gedimas
/// vienoje pusėje painiotųsi su kita.
@MainActor
final class CodexViewModel: ObservableObject {
    @Published private(set) var now = Date()
    @Published private(set) var snapshot: CodexSnapshot?
    @Published private(set) var availability: CodexAvailability = .notInstalled
    @Published private(set) var note: String?

    private let settings: Settings
    private let notifications: NotificationService
    private let store = CodexStore()
    private let client = CodexClient()

    /// Codex klausiama kas penkias minutes. Jis gyvena tame pačiame kompiuteryje ir užklausų
    /// neriboja, bet limitai keičiasi ne sekundėmis, tad dažniau būtų tik tuščias darbas.
    private var gate = ServerFetchGate(
        enabled: true,
        staleThreshold: 5 * 60,
        manualFloor: 30,
        retryInterval: 2 * 60,
        maxRetryInterval: 30 * 60)
    private var tracker: AlertTracker
    private var isFetching = false
    private var timer: Timer?

    /// Codex limitai matuojami dienomis, tad dažnesnio laikrodžio nereikia.
    private let tickInterval: TimeInterval = 30

    init(settings: Settings, notifications: NotificationService) {
        self.settings = settings
        self.notifications = notifications
        self.tracker = AlertTracker(thresholds: settings.alertPreset.thresholds)
        self.snapshot = store.load()
        self.availability = CodexLocator.availability()
    }

    // MARK: - Rodomos reikšmės

    /// Ar Codex šiame kompiuteryje apskritai yra. Nesant jo sekcija nerodoma.
    var isPresent: Bool { availability != .notInstalled }

    var isSignedOut: Bool { availability == .signedOut }

    var hasData: Bool { snapshot != nil }

    var window: DisplayWindow {
        guard let snapshot else { return .empty }
        return UsageDisplay.resolve(snapshot.window, now: now)
    }

    /// Lango pavadinimas imamas iš paties atsakymo, o ne rašomas kietai: Codex planai
    /// skiriasi, ir savaitės langas ne visur yra vienintelis įmanomas.
    var title: String {
        guard let snapshot else { return "7 dienų" }
        return LTFormat.windowTitle(minutes: snapshot.windowMinutes)
    }

    var freshness: Freshness {
        UsageDisplay.freshness(capturedAt: snapshot?.capturedAt, now: now)
    }

    /// Trumpas amžius sekcijos antraštei: „prieš 2 min“.
    var ageShort: String {
        guard let snapshot else { return "" }
        return LTFormat.age(from: snapshot.capturedAt, now: now)
    }

    var signedOutNote: String {
        "Codex neprisijungęs prie paskyros. Terminale paleisk: codex login"
    }

    // MARK: - Ciklas

    func start() {
        let timer = Timer(timeInterval: tickInterval, repeats: true) { [weak self] _ in
            Task { @MainActor in self?.tick() }
        }
        timer.tolerance = 5
        RunLoop.main.add(timer, forMode: .common)
        self.timer = timer
        tick()
    }

    func stop() {
        timer?.invalidate()
        timer = nil
    }

    /// Iškviečiama atidarant langelį.
    func refreshNow() {
        now = Date()
        // Codex galėjo būti įdiegtas arba atjungtas programai veikiant, tad būsena
        // tikrinama iš naujo, o ne tik paleidžiant.
        availability = CodexLocator.availability()
        fetch(manual: false)
    }

    /// Atnaujinimo mygtukas.
    func requestRefresh() {
        now = Date()
        availability = CodexLocator.availability()
        fetch(manual: true)
    }

    private func tick() {
        now = Date()
        availability = CodexLocator.availability()
        deliverAlerts()
        fetch(manual: false)
    }

    // MARK: - Klausimas

    private func fetch(manual: Bool) {
        guard !isFetching else { return }
        guard case .ready(let executable) = availability else {
            // Neįdiegtą ar neprisijungusį Codex paaiškina pati sekcija, ne pastaba.
            note = nil
            return
        }

        let decision = gate.decide(localCapturedAt: snapshot?.capturedAt, now: now, manual: manual)
        guard decision == .fetch else {
            if manual, decision == .skipManualFloor {
                note = "Per dažnai. Codex galima klausti kartą per pusę minutės."
            }
            return
        }

        isFetching = true
        gate.recordAttempt(at: now)

        let client = self.client
        Task {
            do {
                let fresh = try await Task.detached(priority: .utility) {
                    try client.fetch(executable: executable)
                }.value
                handleSuccess(fresh)
            } catch {
                handleFailure(error)
            }
        }
    }

    private func handleSuccess(_ fresh: CodexSnapshot) {
        isFetching = false
        gate.recordSuccess()
        snapshot = fresh
        try? store.save(fresh)
        note = nil
        deliverAlerts()
    }

    private func handleFailure(_ error: Error) {
        isFetching = false
        gate.recordFailure()

        let reason: String
        switch error {
        case CodexClient.ClientError.timedOut:
            reason = "Codex neatsakė laiku"
        case CodexClient.ClientError.launchFailed:
            reason = "nepavyko paleisti Codex"
        case CodexParser.ParseError.rpcError(let message):
            // Dažniausia priežastis – senesnė Codex versija, kuri tokio klausimo nesupranta.
            reason = message.isEmpty ? "Codex atsakė klaida" : "Codex atsakė: \(message)"
        case CodexParser.ParseError.noLimits:
            reason = "Codex limitų reikšmių nepateikė"
        default:
            reason = "nepavyko gauti Codex limitų"
        }

        let retryAt = now.addingTimeInterval(gate.backoffInterval)
        note = "\(reason). Bandoma vėl \(LTFormat.absolute(retryAt, now: now))."
    }

    // MARK: - Perspėjimai

    private func deliverAlerts() {
        guard notifications.isReady else { return }

        tracker.updateThresholds(settings.alertPreset.thresholds)
        guard settings.notificationsEnabled, hasData else { return }

        let display = window
        guard
            tracker.check(
                window: .codexWeekly, percentage: display.usedPercentage,
                resetsAt: display.resetsAt) != nil
        else { return }

        let used = Int(display.usedPercentage.rounded())
        let remaining = Int(display.remainingPercentage.rounded())
        var body = "Sunaudota \(used) %, liko \(remaining) %."
        if let resetsAt = display.resetsAt {
            let countdown = LTFormat.countdown(to: resetsAt, now: now)
            body += " Atsistato " + LTFormat.endingWithPeriod(countdown)
        }
        notifications.post(subtitle: "Codex \(title) limitas baigiasi", body: body)
    }
}
