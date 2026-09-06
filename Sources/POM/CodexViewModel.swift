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
    @Published private var message: LocalizedNote?
    var note: String? { message?.text(settings.language) }
    var onSnapshot: ((CodexSnapshot) -> Void)?

    private let settings: Settings
    private let notifications: NotificationService
    private let store: CodexStore
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

    init(settings: Settings, notifications: NotificationService,
         store: CodexStore = CodexStore(), availability: CodexAvailability? = nil) {
        self.store = store
        self.settings = settings
        self.notifications = notifications
        self.tracker = AlertTracker(thresholds: settings.alertPreset.thresholds)
        self.snapshot = store.load()
        self.availability = availability ?? CodexLocator.availability()
    }

    // MARK: - Rodomos reikšmės

    /// Ar Codex šiame kompiuteryje apskritai yra. Nesant jo sekcija nerodoma.
    var isPresent: Bool { availability != .notInstalled }

    var isSignedOut: Bool { availability == .signedOut }

    var hasData: Bool { snapshot != nil }

    var planTitle: String? { SubscriptionPlan.codex(snapshot?.planType) }

    var window: DisplayWindow {
        guard let snapshot else { return .empty }
        return UsageDisplay.resolve(snapshot.window, now: now)
    }

    /// Lango pavadinimas imamas iš paties atsakymo, o ne rašomas kietai: Codex planai
    /// skiriasi, ir savaitės langas ne visur yra vienintelis įmanomas.
    var title: String {
        guard let snapshot else { return settings.language.windowTitle(minutes: 10080) }
        return settings.language.windowTitle(minutes: snapshot.windowMinutes)
    }

    var freshness: Freshness {
        UsageDisplay.freshness(capturedAt: snapshot?.capturedAt, now: now)
    }

    /// Trumpas amžius sekcijos antraštei: „prieš 2 min“.
    var ageShort: String {
        guard let snapshot else { return "" }
        return settings.language.age(from: snapshot.capturedAt, now: now)
    }

    var signedOutNote: String {
        settings.text("Codex neprisijungęs prie paskyros. Terminale paleisk: codex login", "Codex is signed out. Run in Terminal: codex login")
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
            message = nil
            return
        }

        let decision = gate.decide(localCapturedAt: snapshot?.capturedAt, now: now, manual: manual)
        guard decision == .fetch else {
            if manual, decision == .skipManualFloor {
                message = .init("Codex galima klausti kartą per pusę minutės.", "Codex can be refreshed once every 30 seconds.")
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
        now = Date()
        onSnapshot?(fresh)
        try? store.save(fresh)
        message = nil
        deliverAlerts()
    }

    private func handleFailure(_ error: Error) {
        isFetching = false
        gate.recordFailure()

        let reason: LocalizedNote
        switch error {
        case CodexClient.ClientError.timedOut:
            reason = .init("Codex neatsakė laiku", "Codex did not respond in time")
        case CodexClient.ClientError.launchFailed:
            reason = .init("nepavyko paleisti Codex", "could not start Codex")
        case CodexParser.ParseError.rpcError:
            reason = .init("Codex atsakė klaida; patikrink prisijungimą ir versiją", "Codex returned an error; check your sign-in and version")
        case CodexParser.ParseError.noLimits:
            reason = .init("Codex limitų reikšmių nepateikė", "Codex did not report usage limits")
        default:
            reason = .init("nepavyko gauti Codex limitų", "could not read Codex limits")
        }
        let retry = now.addingTimeInterval(gate.backoffInterval)
        message = .init("\(reason.lt). Bandoma vėl \(AppLanguage.lt.absolute(retry, now: now)).",
                        "\(reason.en). Retrying \(AppLanguage.en.absolute(retry, now: now)).")
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
        var body = settings.text("Sunaudota \(used) %, liko \(remaining) %.", "Used \(used)%, remaining \(remaining)%.")
        if let resetsAt = display.resetsAt {
            let countdown = settings.language.countdown(to: resetsAt, now: now)
            body += settings.text(" Atsistato ", " Resets ") + LTFormat.endingWithPeriod(countdown)
        }
        notifications.post(subtitle: settings.text("Codex \(title) limitas baigiasi", "Codex \(title) limit is running low"), body: body)
    }
}
