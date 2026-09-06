import Foundation
import POMCore
import SwiftUI

@MainActor
final class UsageViewModel: ObservableObject {
    @Published private(set) var now = Date()
    @Published private(set) var snapshot: UsageSnapshot?
    @Published private var serverMessage: LocalizedNote?
    var serverNote: String? { serverMessage?.text(settings.language) }
    /// Ar limitų reikšmės iš Claude Code apskritai pasiekia POM.
    @Published private(set) var isBridgeConnected = false
    @Published private(set) var isConnecting = false
    @Published private var claudeMessage: LocalizedNote?
    var claudeNote: String? { claudeMessage?.text(settings.language) }
    @Published private(set) var extraSnapshot: UsageSnapshot?
    var onSnapshot: ((UsageSnapshot) -> Void)?
    @Published private(set) var fableSnapshot: UsageSnapshot?
    @Published private(set) var planTitle: String?

    let settings: Settings
    let notifications: NotificationService

    private let localStore: SnapshotStore
    private let serverStore: SnapshotStore
    private let home: URL
    private let client = OAuthUsageClient()
    private let claudeStore: SnapshotStore
    private let claudeClient = ClaudeClient()
    private var claudeSnapshot: UsageSnapshot?
    private var isFetchingClaude = false
    private var claudeGate = ServerFetchGate(
        enabled: true, staleThreshold: 5 * 60, manualFloor: 30,
        retryInterval: 2 * 60, maxRetryInterval: 30 * 60)

    private var localSnapshot: UsageSnapshot?
    private var serverSnapshot: UsageSnapshot?
    private var lastLocalFileDate: Date?
    private var gate = ServerFetchGate(enabled: true)
    private var tracker: AlertTracker
    private var isFetching = false
    private var timer: Timer?

    /// Kas kiek tikrinamas failas ir perpiešiama ikona.
    private let tickInterval: TimeInterval = 5

    init(settings: Settings, notifications: NotificationService,
         home: URL = FileManager.default.homeDirectoryForCurrentUser,
         supportDirectory: URL = POMPaths.supportDirectory) {
        self.home = home
        self.localStore = SnapshotStore(fileURL: supportDirectory.appendingPathComponent("snapshot.json"))
        self.serverStore = SnapshotStore(fileURL: supportDirectory.appendingPathComponent("server-snapshot.json"), source: .server)
        self.claudeStore = SnapshotStore(fileURL: supportDirectory.appendingPathComponent("claude-snapshot.json"), source: .claudeCLI)
        self.settings = settings
        self.notifications = notifications
        self.tracker = AlertTracker(thresholds: settings.alertPreset.thresholds)
        self.hasJQ = Bridge.isJQAvailable()

        serverSnapshot = serverStore.load()
        claudeSnapshot = claudeStore.load()
        reloadLocal(force: true)
        recompute()
        isBridgeConnected = Bridge.isConnected(home: home)
    }

    /// Be `jq` tiltas duomenų neperduoda, todėl apie jos trūkumą pasakoma ten,
    /// kur vartotojas laukia skaičių, o ne tyliai.
    private let hasJQ: Bool

    var jqNote: String? {
        hasJQ ? nil : settings.text("Būsenos juostos tiltui reikia jq komandos. Įdiek ją terminale: brew install jq", "The status line bridge needs jq. Install it in Terminal: brew install jq")
    }

    /// Prikabina POM prie Claude Code statusline. Grąžina klaidos tekstą, jei nepavyko.
    func connectToClaudeCode() async -> String? {
        guard !isConnecting else { return nil }
        isConnecting = true
        defer { isConnecting = false }

        let script = Bundle.main.url(forResource: "install-bridge", withExtension: "sh")
        do {
            _ = try await Task.detached(priority: .userInitiated) {
                try Bridge.install(scriptURL: script)
            }.value
            isBridgeConnected = Bridge.isConnected(home: home)
            tick()
            return nil
        } catch {
            return settings.text("Nepavyko prijungti Claude Code. Patikrink, ar įdiegtas jq, ir pabandyk dar kartą.", "Could not connect Claude Code. Check that jq is installed and try again.")
        }
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

    var fable: DisplayWindow? {
        guard let window = fableSnapshot?.fable else { return nil }
        return UsageDisplay.resolve(window, now: now)
    }

    var fableAge: String {
        guard let fableSnapshot else { return "" }
        return settings.language.age(from: fableSnapshot.capturedAt, now: now)
    }

    var freshness: Freshness {
        UsageDisplay.freshness(capturedAt: snapshot?.capturedAt, now: now)
    }

    /// Trumpas amžius sekcijos antraštei: „prieš 2 min“.
    var ageShort: String {
        guard let snapshot else { return "" }
        return settings.language.age(from: snapshot.capturedAt, now: now)
    }

    var sourceText: String {
        switch snapshot?.source {
        case .statusline: return settings.text("iš Claude Code", "from Claude Code")
        case .server: return settings.text("iš serverio", "from server")
        case .claudeCLI: return settings.text("iš Claude Code", "from Claude Code")
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

    /// Atnaujinimo mygtukas. Vietiniai duomenys perskaitomi visada, o serverio klausiama tik
    /// tada, kai tai leidžia nustatymai: kitaip mygtukas atrodytų neveikiantis.
    func requestServerRefresh() {
        now = Date()
        reloadLocal(force: true)
        recompute()
        fetchFromClaude(manual: true)
        fetchFromServer(manual: true)
    }

    private func tick() {
        now = Date()
        // Tikrinama abiem kryptimis: ryšys gali ne tik atsirasti, bet ir dingti,
        // pavyzdžiui, ištrynus tilto scenarijų.
        let connected = Bridge.isConnected(home: home)
        if connected != isBridgeConnected { isBridgeConnected = connected }
        reloadLocal(force: false)
        recompute()
        deliverAlerts()
        fetchFromClaude(manual: false)
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
        let candidates = [localSnapshot, serverSnapshot, claudeSnapshot].compactMap { $0 }
        snapshot = candidates.max { $0.capturedAt < $1.capturedAt }
        // Bendri šaltiniai gali neturėti Fable lauko. Tik pilnas Claude CLI atsakymas
        // gali patvirtinti, kad atskiro limito nebėra; bendras atnaujinimas jo nepaslepia.
        fableSnapshot = candidates.filter { $0.source == .claudeCLI || $0.fable != nil }
            .max { $0.capturedAt < $1.capturedAt }
        extraSnapshot = candidates.filter { $0.source == .claudeCLI || $0.extraUsage != nil }
            .max { $0.capturedAt < $1.capturedAt }
        if let snapshot { onSnapshot?(snapshot) }
        if let fableSnapshot { onSnapshot?(fableSnapshot) }
        let type = claudeSnapshot?.plan
        let localPlan = SubscriptionPlan.claudeLocal(home: home)
        if type.map({ localPlan?.lowercased().hasPrefix($0.lowercased()) == true }) ?? true {
            planTitle = localPlan ?? SubscriptionPlan.claude(type: type, tier: nil)
        } else {
            planTitle = SubscriptionPlan.claude(type: type, tier: nil)
        }
    }

    private func fetchFromClaude(manual: Bool) {
        guard !isFetchingClaude else { return }
        guard let executable = ClaudeClient.executable else {
            claudeMessage = .init("Fable limitui reikia įdiegtos Claude Code komandos.", "Install Claude Code to see the Fable limit.")
            return
        }
        let decision = claudeGate.decide(localCapturedAt: claudeSnapshot?.capturedAt, now: now, manual: manual)
        guard decision == .fetch else {
            if manual, decision == .skipManualFloor {
                claudeMessage = .init("Claude galima atnaujinti kartą per pusę minutės.", "Claude can be refreshed once every 30 seconds.")
            }
            return
        }
        isFetchingClaude = true
        claudeGate.recordAttempt(at: now)
        let client = claudeClient
        Task {
            do {
                let fresh = try await Task.detached(priority: .utility) {
                    try client.fetch(executable: executable)
                }.value
                claudeSnapshot = fresh
                try? claudeStore.save(fresh)
                claudeGate.recordSuccess()
                claudeMessage = fresh.fable == nil ? .init("Claude nepateikė atskiro Fable limito.", "Claude did not report a separate Fable limit.") : nil
                now = Date()
                recompute()
                deliverAlerts()
            } catch {
                claudeGate.recordFailure()
                if case ClaudeClient.ClientError.unavailable = error {
                    claudeMessage = .init("Claude naudojimo duomenys nepasiekiami. Patikrink prisijungimą: claude auth login.", "Claude usage is unavailable. Check your sign-in: claude auth login.")
                } else {
                    let retry = now.addingTimeInterval(claudeGate.backoffInterval)
                    claudeMessage = .init("Nepavyko atnaujinti Claude limitų. Bandoma vėl \(AppLanguage.lt.absolute(retry, now: now)).",
                                          "Could not refresh Claude limits. Retrying \(AppLanguage.en.absolute(retry, now: now)).")
                }
            }
            isFetchingClaude = false
        }
    }

    // MARK: - Perspėjimai

    private func deliverAlerts() {
        // Kol pranešimų kelias nepasirinktas, žymų neliečiame: kitaip pirmasis
        // ribos peržengimas būtų pažymėtas kaip praneštas, o vartotojas nieko nepamatytų.
        guard notifications.isReady else { return }

        tracker.updateThresholds(settings.alertPreset.thresholds)
        guard settings.notificationsEnabled, hasData else { return }

        alert(window: .fiveHour, display: fiveHour, name: settings.language.windowTitle(minutes: 300))
        alert(window: .sevenDay, display: sevenDay, name: settings.language.windowTitle(minutes: 10080))
        if let fable { alert(window: .fable, display: fable, name: "Fable " + settings.language.windowTitle(minutes: 10080)) }
    }

    private func alert(window: AlertTracker.Window, display: DisplayWindow, name: String) {
        // Riba pasako tik tai, kad reikia pranešti. Tekste rodoma tikroji reikšmė.
        guard
            tracker.check(
                window: window, percentage: display.usedPercentage, resetsAt: display.resetsAt)
                != nil
        else { return }

        let used = Int(display.usedPercentage.rounded())
        let remaining = Int(display.remainingPercentage.rounded())
        var body = settings.text("Sunaudota \(used) %, liko \(remaining) %.", "Used \(used)%, remaining \(remaining)%.")
        if let resetsAt = display.resetsAt {
            let countdown = settings.language.countdown(to: resetsAt, now: now)
            body += settings.text(" Atsistato ", " Resets ") + LTFormat.endingWithPeriod(countdown)
        }
        notifications.post(subtitle: settings.text("\(name) limitas baigiasi", "\(name) limit is running low"), body: body)
    }

    // MARK: - Serveris

    private func fetchFromServer(manual: Bool) {
        guard !isFetching else { return }

        gate.enabled = settings.serverFallbackEnabled
        let decision = gate.decide(localCapturedAt: snapshot?.capturedAt, now: now, manual: manual)

        guard decision == .fetch else {
            if manual {
                // Paspaudus mygtuką visada atsakoma, kodėl serverio neklausiama.
                serverMessage = note(for: decision)
            } else if decision == .skipDisabled {
                // Išjungta pačiam vartotojui – aiškinti nėra ko, langelis lieka švarus.
                serverMessage = nil
            }
            return
        }

        isFetching = true
        gate.recordAttempt(at: now)
        if manual { serverMessage = .init("Klausiama serverio…", "Checking the server…") }

        let client = self.client
        Task {
            do {
                let token = try await Task.detached(priority: .utility) {
                    try KeychainToken.accessToken()
                }.value
                let fresh = try await client.fetch(token: token)
                handleSuccess(fresh)
            } catch {
                handleFailure(error)
            }
        }
    }

    private func handleSuccess(_ fresh: UsageSnapshot) {
        isFetching = false
        gate.recordSuccess()
        serverSnapshot = fresh
        try? serverStore.save(fresh)
        serverMessage = nil
        recompute()
        deliverAlerts()
    }

    private func handleFailure(_ error: Error) {
        isFetching = false
        gate.recordFailure()

        let reason: LocalizedNote
        switch error {
        case OAuthUsageClient.ClientError.forbidden:
            gate.block()
            serverMessage = .init("Serverio klausti neleidžiama: raktui reikia „user:profile“ teisės. Skaičiai imami iš Claude Code.",
                                  "Server access requires the user:profile permission. Using Claude Code data.")
            return
        case OAuthUsageClient.ClientError.unauthorized:
            gate.block()
            serverMessage = .init("Serveris rakto nebepriima. Prisijunk prie Claude Code iš naujo.",
                                  "The server rejected your credentials. Sign in to Claude Code again.")
            return
        case OAuthUsageClient.ClientError.rateLimited:
            reason = .init("serveris atmetė užklausą (per dažnai)", "the server rate limited the request")
        case OAuthUsageClient.ClientError.http(let code):
            reason = .init("serveris atsakė klaida \(code)", "the server returned error \(code)")
        case KeychainToken.TokenError.expired:
            reason = .init("prisijungimo raktas nebegalioja", "the sign-in token expired")
        case KeychainToken.TokenError.claudeAccountNotFound:
            serverMessage = .init("Raktinėje nėra Claude prisijungimo rakto. Skaičiai imami iš Claude Code.",
                                  "No Claude sign-in token in Keychain. Using Claude Code data.")
            return
        case KeychainToken.TokenError.commandFailed, KeychainToken.TokenError.unreadableSecret:
            reason = .init("nepavyko perskaityti raktinės", "could not read Keychain")
        default:
            reason = .init("nepavyko susisiekti su serveriu", "could not reach the server")
        }
        let retry = now.addingTimeInterval(gate.backoffInterval)
        serverMessage = .init("Serveris: \(reason.lt). Bandoma vėl \(AppLanguage.lt.absolute(retry, now: now)).",
                              "Server: \(reason.en). Retrying \(AppLanguage.en.absolute(retry, now: now)).")
    }

    private func note(for decision: ServerFetchGate.Decision) -> LocalizedNote? {
        switch decision {
        case .fetch: return nil
        case .skipDisabled: return .init("Serverio klausimas išjungtas nustatymuose.", "Server fallback is disabled in settings.")
        case .skipBlocked: return .init("Serverio klausti neleidžiama su turimu raktu.", "These credentials cannot access server usage.")
        case .skipLocalFresh: return .init("Duomenys jau švieži, serverio klausti nereikia.", "Data is already up to date.")
        case .skipBackoff: return .init("Serveris neseniai atmetė užklausą, laukiama.", "Waiting before retrying the server.")
        case .skipManualFloor: return .init("Serverio galima klausti kartą per 5 min.", "The server can be refreshed once every 5 minutes.")
        }
    }
}

extension DisplayWindow {
    static let empty = DisplayWindow(usedPercentage: 0, resetsAt: nil, didReset: false)
}
