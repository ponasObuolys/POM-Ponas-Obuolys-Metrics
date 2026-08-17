import Foundation
import POMCore
import SwiftUI

@MainActor
final class UsageViewModel: ObservableObject {
    @Published private(set) var now = Date()
    @Published private(set) var snapshot: UsageSnapshot?
    @Published private(set) var serverNote: String?
    /// Ar limitų reikšmės iš Claude Code apskritai pasiekia POM.
    @Published private(set) var isBridgeConnected = false
    @Published private(set) var isConnecting = false

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
        self.hasJQ = Bridge.isJQAvailable()

        serverSnapshot = serverStore.load()
        reloadLocal(force: true)
        recompute()
        isBridgeConnected = Bridge.isConnected(home: Self.home)
    }

    /// Be `jq` tiltas duomenų neperduoda, todėl apie jos trūkumą pasakoma ten,
    /// kur vartotojas laukia skaičių, o ne tyliai.
    private let hasJQ: Bool

    var jqNote: String? {
        hasJQ ? nil : "Kompiuteryje nėra jq komandos, be jos duomenys POM nepasieks. "
            + "Įdiek ją terminale: brew install jq"
    }

    private static var home: URL {
        FileManager.default.homeDirectoryForCurrentUser
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
            isBridgeConnected = Bridge.isConnected(home: Self.home)
            tick()
            return nil
        } catch {
            return error.localizedDescription
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

    /// Atnaujinimo mygtukas. Vietiniai duomenys perskaitomi visada, o serverio klausiama tik
    /// tada, kai tai leidžia nustatymai: kitaip mygtukas atrodytų neveikiantis.
    func requestServerRefresh() {
        now = Date()
        reloadLocal(force: true)
        recompute()
        fetchFromServer(manual: true)
    }

    private func tick() {
        now = Date()
        // Tikrinama abiem kryptimis: ryšys gali ne tik atsirasti, bet ir dingti,
        // pavyzdžiui, ištrynus tilto scenarijų.
        let connected = Bridge.isConnected(home: Self.home)
        if connected != isBridgeConnected { isBridgeConnected = connected }
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
        // Riba pasako tik tai, kad reikia pranešti. Tekste rodoma tikroji reikšmė.
        guard
            tracker.check(
                window: window, percentage: display.usedPercentage, resetsAt: display.resetsAt)
                != nil
        else { return }

        let used = Int(display.usedPercentage.rounded())
        let remaining = Int(display.remainingPercentage.rounded())
        var body = "Sunaudota \(used) %, liko \(remaining) %."
        if let resetsAt = display.resetsAt {
            let countdown = LTFormat.countdown(to: resetsAt, now: now)
            body += " Atsistato " + LTFormat.endingWithPeriod(countdown)
        }
        notifications.post(subtitle: "\(name) limitas baigiasi", body: body)
    }

    // MARK: - Serveris

    private func fetchFromServer(manual: Bool) {
        guard !isFetching else { return }

        gate.enabled = settings.serverFallbackEnabled
        let decision = gate.decide(localCapturedAt: snapshot?.capturedAt, now: now, manual: manual)

        guard decision == .fetch else {
            if manual {
                // Paspaudus mygtuką visada atsakoma, kodėl serverio neklausiama.
                serverNote = note(for: decision)
            } else if decision == .skipDisabled {
                // Išjungta pačiam vartotojui – aiškinti nėra ko, langelis lieka švarus.
                serverNote = nil
            }
            return
        }

        isFetching = true
        gate.recordAttempt(at: now)
        if manual { serverNote = "Klausiama serverio…" }

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
        serverNote = nil
        recompute()
        deliverAlerts()
    }

    private func handleFailure(_ error: Error) {
        isFetching = false
        gate.recordFailure()

        let reason: String
        switch error {
        case OAuthUsageClient.ClientError.forbidden:
            // Nuolatinė kliūtis: raktas galioja, bet neturi teisės skaityti limitų.
            // Taip elgiasi `claude setup-token` raktas. Kartoti nėra prasmės.
            gate.block()
            serverNote =
                "Serverio klausti neleidžiama: raktas neturi teisės skaityti limitų "
                + "(reikia „user:profile“). Skaičiai imami iš Claude Code."
            return
        case OAuthUsageClient.ClientError.unauthorized:
            gate.block()
            serverNote =
                "Serveris rakto nebepriima. Įrašyk naują: ./scripts/set-token.sh"
            return
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
    }

    private func note(for decision: ServerFetchGate.Decision) -> String? {
        switch decision {
        case .fetch:
            return nil
        case .skipDisabled:
            return "Serverio klausimas išjungtas nustatymuose."
        case .skipBlocked:
            return "Serverio klausti neleidžiama su turimu raktu."
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
