import Combine
import Foundation
import POMCore

@MainActor
final class AdditionalUsageViewModel: ObservableObject {
    @Published private(set) var cursor: ProviderUsageSnapshot?
    @Published private(set) var grokBot: ProviderUsageSnapshot?
    @Published private(set) var now = Date()
    @Published private(set) var cursorPresent = false
    @Published private(set) var grokBotPresent = false
    @Published private(set) var isFetchingCursor = false
    @Published private(set) var cursorError: CursorClient.ClientError?
    @Published private(set) var grokBotError: GrokBotCache.CacheError?

    private let settings: Settings
    private let home: URL
    private let readCursorSession: @Sendable () throws -> CursorClient.Session
    private let fetchCursor: @Sendable (CursorClient.Session) async throws -> ProviderUsageSnapshot
    private let readGrokBot: @Sendable () throws -> ProviderUsageSnapshot
    private var cursorIdentity: String?
    private var generation = 0
    private var cursorTask: Task<Void, Never>?
    private var grokBotTask: Task<Void, Never>?
    private var timer: Timer?
    private var gate = ServerFetchGate(enabled: true, staleThreshold: 5 * 60, manualFloor: 30,
                                       retryInterval: 5 * 60, maxRetryInterval: 60 * 60)

    init(settings: Settings, home: URL = FileManager.default.homeDirectoryForCurrentUser,
         readCursorSession: (@Sendable () throws -> CursorClient.Session)? = nil,
         fetchCursor: @escaping @Sendable (CursorClient.Session) async throws -> ProviderUsageSnapshot = { try await CursorClient().fetch(session: $0) },
         readGrokBot: (@Sendable () throws -> ProviderUsageSnapshot)? = nil) {
        self.settings = settings
        self.home = home
        self.readCursorSession = readCursorSession ?? { try CursorClient.readSession(database: CursorClient.databaseURL(home: home)) }
        self.fetchCursor = fetchCursor
        self.readGrokBot = readGrokBot ?? { try GrokBotCache(home: home).read() }
        cursorPresent = FileManager.default.fileExists(atPath: CursorClient.databaseURL(home: home).path)
        grokBotPresent = FileManager.default.fileExists(atPath: GrokBotCache(home: home).directory.path)
    }

    func start() {
        guard timer == nil else { return }
        refreshNow()
        timer = Timer.scheduledTimer(withTimeInterval: 30, repeats: true) { [weak self] _ in
            Task { @MainActor in self?.refreshNow() }
        }
        timer?.tolerance = 5
    }

    func refreshNow(manual: Bool = false) {
        now = Date()
        cursorPresent = FileManager.default.fileExists(atPath: CursorClient.databaseURL(home: home).path)
        grokBotPresent = FileManager.default.fileExists(atPath: GrokBotCache(home: home).directory.path)
        refreshGrokBot()
        guard settings.cursorMetricsEnabled else {
            generation += 1
            cursorTask?.cancel(); cursorTask = nil
            isFetchingCursor = false
            cursor = nil; cursorIdentity = nil; cursorError = nil
            gate = ServerFetchGate(enabled: true, staleThreshold: 5 * 60, manualFloor: 30,
                                   retryInterval: 5 * 60, maxRetryInterval: 60 * 60)
            return
        }
        refreshCursor(manual: manual)
    }

    func snapshot(for source: MenuBarSource) -> ProviderUsageSnapshot? {
        switch source {
        case .cursor: return cursor
        case .grokBot: return grokBot
        default: return nil
        }
    }

    func menuWindows(for source: MenuBarSource) -> [DisplayWindow] {
        let windows = snapshot(for: source)?.meters.prefix(2).map { UsageDisplay.resolve($0.window, now: now) } ?? []
        return windows.isEmpty ? [.empty] : windows
    }

    private func refreshGrokBot() {
        guard grokBotTask == nil else { return }
        let read = readGrokBot
        grokBotTask = Task { [weak self] in
            let result = await Task.detached(priority: .utility) { Result { try read() } }.value
            guard let self else { return }
            switch result {
            case .success(let snapshot): self.grokBot = snapshot; self.grokBotError = nil
            case .failure(let error):
                // A missing/changed selected account must never keep another account's quota.
                self.grokBot = nil
                self.grokBotError = error as? GrokBotCache.CacheError ?? .unavailable
            }
            self.grokBotTask = nil
        }
    }

    private func refreshCursor(manual: Bool) {
        guard cursorTask == nil else { return }
        let revision = generation
        let read = readCursorSession
        let fetch = fetchCursor
        cursorTask = Task { [weak self] in
            guard let self else { return }
            defer {
                if self.generation == revision { self.isFetchingCursor = false; self.cursorTask = nil }
            }
            do {
                let session = try await Task.detached(priority: .utility) { try read() }.value
                guard self.generation == revision, self.settings.cursorMetricsEnabled else { return }
                if self.cursorIdentity != session.fingerprint {
                    self.cursor = nil
                    self.cursorIdentity = session.fingerprint
                    self.gate = ServerFetchGate(enabled: true, staleThreshold: 5 * 60, manualFloor: 30,
                                                retryInterval: 5 * 60, maxRetryInterval: 60 * 60)
                }
                guard self.gate.decide(localCapturedAt: self.cursor?.capturedAt, now: self.now, manual: manual) == .fetch else { return }
                self.gate.recordAttempt(at: self.now)
                self.isFetchingCursor = true
                let snapshot = try await fetch(session)
                let current = try await Task.detached(priority: .utility) { try read() }.value
                guard self.generation == revision, self.settings.cursorMetricsEnabled else { return }
                guard current.fingerprint == session.fingerprint else {
                    self.cursor = nil; self.cursorIdentity = nil
                    return
                }
                self.cursor = snapshot; self.cursorError = nil
                self.gate.recordSuccess()
            } catch {
                guard self.generation == revision, self.settings.cursorMetricsEnabled else { return }
                let failure = error as? CursorClient.ClientError ?? .unavailable
                self.cursorError = failure
                self.gate.recordFailure()
                if failure == .signedOut { self.cursor = nil; self.cursorIdentity = nil }
            }
        }
    }
}
