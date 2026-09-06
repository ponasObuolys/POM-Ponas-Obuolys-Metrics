import Foundation
import POMCore

@MainActor
final class HistoryService: ObservableObject {
    @Published private(set) var claude: TokenUsageSnapshot?
    @Published private(set) var codex: TokenUsageSnapshot?
    @Published private(set) var importing = false
    @Published private(set) var fetchingCodex = false
    @Published private(set) var claudeUnavailable = false
    @Published private(set) var codexUnavailable = false
    @Published private(set) var skippedLines = 0
    private let worker: TokenHistoryWorker
    private var timer: Timer?
    private var claudeTask: Task<Void, Never>?
    private var codexTask: Task<Void, Never>?
    private var lastAttempt: Date?
    @Published private(set) var saveFailed = false
    private var recovery: RecoveryTracker
    private let recoveryURL: URL
    private let settings: Settings
    private let notifications: NotificationService
    private var lastObserved: [HistorySeries: Date] = [:]
    private var pending: [(HistorySeries, Double)] = []

    init(settings: Settings, notifications: NotificationService,
         directory: URL = POMPaths.supportDirectory,
         home: URL = FileManager.default.homeDirectoryForCurrentUser,
         previewClaude: TokenUsageSnapshot? = nil, previewCodex: TokenUsageSnapshot? = nil) {
        self.settings = settings; self.notifications = notifications
        worker = TokenHistoryWorker(directory: directory, root: home.appendingPathComponent(".claude/projects"))
        claude = previewClaude; codex = previewCodex
        recoveryURL = directory.appendingPathComponent("recovery-state.json")
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
        let recovered = recovery.observe(id: series.rawValue, window: window, capturedAt: captured,
                                         now: now, ordinaryUsageAllowed: allowed,
                                         requiresAvailability: series == .codexWeekly)
        do {
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

    func start() {
        guard timer == nil else { return }
        timer = Timer.scheduledTimer(withTimeInterval: 15 * 60, repeats: true) { [weak self] _ in
            Task { @MainActor in self?.refresh() }
        }
        timer?.tolerance = 60
        refresh()
    }

    func stop() {
        timer?.invalidate(); timer = nil
        claudeTask?.cancel(); codexTask?.cancel()
    }

    func refresh() {
        guard lastAttempt.map({ Date().timeIntervalSince($0) >= 60 }) ?? true else { return }
        lastAttempt = Date()
        if claudeTask == nil {
            importing = true
            claudeTask = Task(priority: .background) {
                defer { importing = false; claudeTask = nil }
                do {
                    if claude == nil { claude = await worker.cached(provider: "claude") }
                    try await worker.begin()
                    while !Task.isCancelled {
                        let batch = try await worker.batch()
                        claude = batch.available || !batch.snapshot.days.isEmpty ? batch.snapshot : nil
                        claudeUnavailable = !batch.available
                        skippedLines = batch.skippedLines
                        if batch.complete { break }
                        // Cooperative sleep: no thread or process remains busy while waiting.
                        try await Task.sleep(for: .seconds(ProcessInfo.processInfo.isLowPowerModeEnabled ? 2 : 0.5))
                    }
                } catch is CancellationError { }
                catch { claudeUnavailable = true }
            }
        }
        if codexTask == nil {
            fetchingCodex = true
            codexTask = Task(priority: .background) {
                defer { fetchingCodex = false; codexTask = nil }
                if codex == nil { codex = await worker.cached(provider: "codex") }
                do {
                    codex = try await worker.fetchCodex()
                    codexUnavailable = false
                } catch { codexUnavailable = true }
            }
        }
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


/// All transcript discovery, SQLite work and CLI waiting run away from the UI.
private actor TokenHistoryWorker {
    let directory: URL
    let root: URL
    var indexer: ClaudeTokenIndexer?
    init(directory: URL, root: URL) { self.directory = directory; self.root = root }
    func cached(provider: String) -> TokenUsageSnapshot? {
        let url = directory.appendingPathComponent("\(provider)-tokens.json")
        guard let size = try? url.resourceValues(forKeys: [.fileSizeKey]).fileSize, size <= 64 * 1024,
              let data = try? Data(contentsOf: url) else { return nil }
        return try? JSONDecoder().decode(TokenUsageSnapshot.self, from: data)
    }
    func begin() throws {
        if indexer == nil { indexer = try ClaudeTokenIndexer(root: root, database: directory.appendingPathComponent("claude-token-index.sqlite")) }
        try indexer!.begin()
    }
    func batch() throws -> ClaudeTokenIndexer.Batch {
        let batch = try indexer!.scanBatch(maxSeconds: 0.05)
        // Save only a completed import; a crash must not turn partial totals into a complete history.
        if batch.complete, batch.available { try save(batch.snapshot, provider: "claude") }
        return batch
    }
    func fetchCodex() throws -> TokenUsageSnapshot {
        guard case let .ready(executable) = CodexLocator.availability() else { throw CodexClient.ClientError.noResponse }
        let snapshot = try CodexClient().fetchUsage(executable: executable)
        try save(snapshot, provider: "codex")
        return snapshot
    }
    private func save(_ snapshot: TokenUsageSnapshot, provider: String) throws {
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        try JSONEncoder().encode(snapshot).write(to: directory.appendingPathComponent("\(provider)-tokens.json"), options: .atomic)
    }
}
