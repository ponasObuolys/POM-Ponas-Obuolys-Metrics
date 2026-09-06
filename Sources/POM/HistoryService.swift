import Foundation
import POMCore

@MainActor
final class HistoryService: ObservableObject {
    @Published private(set) var history: UsageHistory
    @Published private(set) var saveFailed = false
    private var recovery: RecoveryTracker
    private let historyURL: URL
    private let recoveryURL: URL
    private let settings: Settings
    private let notifications: NotificationService
    private var lastObserved: [HistorySeries: Date] = [:]
    private var pending: [(HistorySeries, Double)] = []

    init(settings: Settings, notifications: NotificationService,
         directory: URL = POMPaths.supportDirectory) {
        self.settings = settings; self.notifications = notifications
        historyURL = directory.appendingPathComponent("usage-history.json")
        recoveryURL = directory.appendingPathComponent("recovery-state.json")
        history = UsageHistory.load(from: historyURL)
        recovery = (try? Data(contentsOf: recoveryURL)).flatMap {
            try? JSONDecoder().decode(RecoveryTracker.self, from: $0)
        } ?? RecoveryTracker()
    }

    func record(_ snapshot: UsageSnapshot) {
        record(.claudeSession, window: snapshot.fiveHour, at: snapshot.capturedAt)
        record(.claudeWeekly, window: snapshot.sevenDay, at: snapshot.capturedAt)
        if let fable = snapshot.fable { record(.fableWeekly, window: fable, at: snapshot.capturedAt) }
    }

    func record(_ snapshot: CodexSnapshot) {
        record(.codexWeekly, window: snapshot.window, at: snapshot.capturedAt,
               allowed: snapshot.ordinaryUsageAllowed)
    }

    private func record(_ series: HistorySeries, window: UsageWindow, at captured: Date, allowed: Bool? = nil) {
        deliverPending()
        guard captured <= Date().addingTimeInterval(60), window.usedPercentage.isFinite,
              (0...100_000).contains(window.usedPercentage) else { return }
        guard lastObserved[series].map({ captured > $0 }) ?? true else { return }
        lastObserved[series] = captured
        let now = Date()
        let changed = history.append(HistoryPoint(series: series, capturedAt: captured,
                                                  percentage: window.usedPercentage, resetsAt: window.resetsAt), now: now)
        let recovered = recovery.observe(id: series.rawValue, window: window, capturedAt: captured,
                                         now: now, ordinaryUsageAllowed: allowed,
                                         requiresAvailability: series == .codexWeekly)
        do {
            if changed { try history.save(to: historyURL) }
            try FileManager.default.createDirectory(at: recoveryURL.deletingLastPathComponent(), withIntermediateDirectories: true)
            try JSONEncoder().encode(recovery).write(to: recoveryURL, options: .atomic)
            saveFailed = false
        } catch { saveFailed = true }
        if recovered { pending.append((series, window.usedPercentage)) }
        deliverPending()
    }

    func deliverPending() {
        guard notifications.isReady else { return }
        defer { pending.removeAll() }
        guard settings.recoveryNotifications else { return }
        for (series, percentage) in pending {
            notifications.post(subtitle: settings.text("Limitas vėl prieinamas", "Your limit is available again"),
                               body: settings.text("\(series.title(settings.language)): gauti nauji duomenys, liko \(Int(max(0, 100 - percentage))) %.",
                                                   "\(series.title(settings.language)): fresh data confirms \(Int(max(0, 100 - percentage)))% remaining."))
        }
    }

    func clear() {
        do {
            try UsageHistory().save(to: historyURL)
            history = UsageHistory()
            saveFailed = false
        } catch { saveFailed = true }
    }
}

extension HistorySeries {
    func title(_ language: AppLanguage) -> String {
        switch self {
        case .claudeSession: return "Claude · " + language.windowTitle(minutes: 300)
        case .claudeWeekly: return "Claude · " + language.windowTitle(minutes: 10080)
        case .fableWeekly: return "Fable · " + language.windowTitle(minutes: 10080)
        case .codexWeekly: return language.text("Codex · pagrindinis limitas", "Codex · main limit")
        }
    }
}

struct LocalizedNote {
    let lt: String
    let en: String
    init(_ lt: String, _ en: String) { self.lt = lt; self.en = en }
    func text(_ language: AppLanguage) -> String { language.text(lt, en) }
}
