import AppKit
import SwiftUI
import POMCore

@main struct POMVisualCheck {
    @MainActor static func main() async throws {
        setbuf(stdout, nil)
        _ = NSApplication.shared
        let output = URL(fileURLWithPath: CommandLine.arguments[1])
        try FileManager.default.createDirectory(at: output, withIntermediateDirectories: true)
        let root = FileManager.default.temporaryDirectory.appendingPathComponent("pom-ui-\(UUID().uuidString)")
        defer { try? FileManager.default.removeItem(at: root) }
        let support = root.appendingPathComponent("Library/Application Support/POM")
        try FileManager.default.createDirectory(at: support, withIntermediateDirectories: true)
        let cli = UsageSnapshot(fiveHour: UsageWindow(usedPercentage: 7, resetsAt: Date().addingTimeInterval(3600)), sevenDay: UsageWindow(usedPercentage: 3, resetsAt: Date().addingTimeInterval(3*86400)), capturedAt: Date().addingTimeInterval(-20), source: .claudeCLI, fable: UsageWindow(usedPercentage: 4, resetsAt: Date().addingTimeInterval(3*86400)), plan: "max")
        try SnapshotStore(fileURL: support.appendingPathComponent("claude-snapshot.json"), source: .claudeCLI).save(cli)
        try Data(#"{"oauthAccount":{"organizationRateLimitTier":"default_claude_max_20x"}}"#.utf8).write(to: root.appendingPathComponent(".claude.json"))
        let codexStore = CodexStore(fileURL: support.appendingPathComponent("codex-snapshot.json"))
        try codexStore.save(CodexSnapshot(window: UsageWindow(usedPercentage: 51, resetsAt: Date().addingTimeInterval(86400)), windowMinutes: 10080, capturedAt: Date(), planType: "prolite"))
        let suite = "pom-ui-\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suite)!
        defer { defaults.removePersistentDomain(forName: suite) }
        defaults.set("codex", forKey: "menuBarSource")
        let settings = Settings(defaults: defaults)
        let reminderDate = Date(timeIntervalSince1970: 1_800_000_000)
        precondition(settings.supportReminderForLaunch(version: "2.2.3", now: reminderDate) == .welcome)
        precondition(Settings(defaults: defaults).supportReminderForLaunch(version: "2.2.3", now: reminderDate.addingTimeInterval(30 * 86400)) == nil)
        precondition(settings.menuBarSources == [.codex], "Existing source preference must migrate")
        settings.setSource(.codex, enabled: false)
        precondition(settings.menuBarSources == [.codex], "At least one source must remain")
        settings.setSource(.claude, enabled: true)
        precondition(Settings(defaults: defaults).menuBarSources == [.claude, .codex])
        settings.togglePin(.codex)
        precondition(Settings(defaults: defaults).pinnedSource == .codex, "Pin must survive relaunch")
        settings.togglePin(.claude)
        precondition(settings.pinnedSource == .claude, "A second pin replaces the first")
        settings.setSource(.claude, enabled: false)
        precondition(settings.pinnedSource == nil && Settings(defaults: defaults).pinnedSource == nil,
                     "Hiding the pinned provider must restore automatic ordering")
        settings.togglePin(.claude)
        precondition(settings.pinnedSource == nil, "A hidden provider cannot be pinned")
        settings.setSource(.claude, enabled: true)
        settings.togglePin(.codex); settings.togglePin(.codex)
        precondition(settings.pinnedSource == nil, "Clicking the same pin again unpins it")
        settings.language = .lt
        precondition(Settings(defaults: defaults).language == .lt)
        let notifications = NotificationService()
        let codex = CodexViewModel(settings: settings, notifications: notifications, store: codexStore, availability: .ready(URL(fileURLWithPath: "/example/codex")))
        let disconnected = UsageViewModel(settings: settings, notifications: notifications, home: root, supportDirectory: support)
        precondition(disconnected.hasData && !disconnected.isBridgeConnected)
        precondition(disconnected.fable?.usedPercentage == 4 && disconnected.planTitle == "Max 20x")
        precondition(codex.planTitle == "ChatGPT Pro 5x")
        try render(UsagePanelView(model: disconnected, codex: codex, settings: settings), name: "reconnect", directory: output, scheme: .light)
        let claude = root.appendingPathComponent(".claude")
        try FileManager.default.createDirectory(at: claude, withIntermediateDirectories: true)
        try Data("#!/bin/bash\n\(Bridge.marker)\n".utf8).write(to: claude.appendingPathComponent("statusline.sh"))
        let bridge = Bridge.scriptURL(home: root)
        try Data("#!/bin/bash\n".utf8).write(to: bridge)
        try FileManager.default.setAttributes([.posixPermissions: 0o755], ofItemAtPath: bridge.path)
        let connected = UsageViewModel(settings: settings, notifications: notifications, home: root, supportDirectory: support)
        precondition(connected.isBridgeConnected)
        try render(UsagePanelView(model: connected, codex: codex, settings: settings), name: "normal-light", directory: output, scheme: .light)
        try render(UsagePanelView(model: connected, codex: codex, settings: settings), name: "normal-dark", directory: output, scheme: .dark)
        settings.language = .en
        try render(SupportReminderView(settings: settings, occasion: .welcome, version: "2.2.3", dismiss: {}), name: "support-welcome-en", directory: output, scheme: .light)
        try render(SupportReminderView(settings: settings, occasion: .update, version: "2.2.3", dismiss: {}), name: "support-update-en", directory: output, scheme: .dark)
        settings.language = .lt
        try render(SupportReminderView(settings: settings, occasion: .welcome, version: "2.2.3", dismiss: {}), name: "support-welcome-lt", directory: output, scheme: .light)
        try render(SupportReminderView(settings: settings, occasion: .update, version: "2.2.3", dismiss: {}), name: "support-update-lt", directory: output, scheme: .dark)
        settings.language = .en
        try render(UsagePanelView(model: connected, codex: codex, settings: settings), name: "english-light", directory: output, scheme: .light)
        try render(ExtraUsageView(settings: settings, claude: ClaudeExtraUsage(enabled: true, used: 1234, limit: 5000, percentage: 24.68, currency: "USD", decimalPlaces: 2)).frame(width: 310), name: "claude-credits", directory: output, scheme: .light)
        let extras = CodexAdditionalUsage(credits: CodexCredits(hasCredits: true, unlimited: false, balance: "240"), spendLimit: CodexSpendLimit(limit: "500", used: "260", remainingPercent: 48, resetsAt: nil), resetCredits: 2)
        try render(ExtraUsageView(settings: settings, codex: extras).frame(width: 310), name: "codex-credits", directory: output, scheme: .dark)
        let historyDirectory = root.appendingPathComponent("history")
        let emptyHistory = HistoryService(settings: settings, notifications: notifications, directory: historyDirectory)
        try render(HistoryView(service: emptyHistory, settings: settings), name: "history-empty", directory: output, scheme: .light)
        let now = Date()
        let keys = UsageDay.keys(days: 30, now: now)
        let claudeDays = keys.enumerated().map { TokenDay(day: $0.element, tokens: Int64([320000, 1450000, 820000, 2600000, 1800000, 960000, 2100000][$0.offset % 7])) }
        let codexDays = keys.enumerated().map { TokenDay(day: $0.element, tokens: Int64([780000, 920000, 1700000, 1200000, 2900000, 2300000, 3600000][$0.offset % 7])) }
        let populated = HistoryService(settings: settings, notifications: notifications, directory: historyDirectory,
            previewClaude: TokenUsageSnapshot(days: claudeDays, updatedAt: now), previewCodex: TokenUsageSnapshot(days: codexDays, updatedAt: now))
        let reportData = try populated.exportReportData(now: now)
        let report = try UsageHistoryReport.decode(reportData)
        precondition(report.entries.map(\.source) == [.claudeCodeLocal, .codexAccount])
        precondition(report.entries[0].snapshot.days == claudeDays)
        precondition(report.entries[1].snapshot.days == codexDays)
        precondition(!FileManager.default.fileExists(atPath: historyDirectory.path), "Export must not scan or save history caches")
        // Synthetic data only; a reviewable example of the exact export format.
        try reportData.write(to: output.appendingPathComponent("history-export-example.json"), options: .atomic)
        try render(HistoryView(service: populated, settings: settings), name: "history-english", directory: output, scheme: .light)
        settings.language = .lt
        try render(HistoryView(service: populated, settings: settings), name: "history-lithuanian", directory: output, scheme: .dark)
        try render(HistoryView(service: populated, settings: settings, days: 30), name: "history-thirty-days", directory: output, scheme: .light)
        let group = MenuBarGroupView(entries: [MenuBarEntry(source: .claude, windows: [connected.fiveHour, connected.sevenDay], hasData: true), MenuBarEntry(source: .codex, windows: [codex.window], hasData: true)], showRemaining: false)
        try render(group, name: "menubar-together", directory: output, scheme: .light)
        let newer = UsageSnapshot(fiveHour: UsageWindow(usedPercentage: 9, resetsAt: nil), sevenDay: UsageWindow(usedPercentage: 5, resetsAt: nil), capturedAt: Date(), source: .statusline)
        try SnapshotStore(fileURL: support.appendingPathComponent("snapshot.json")).save(newer)
        let merged = UsageViewModel(settings: settings, notifications: notifications, home: root, supportDirectory: support)
        precondition(merged.sevenDay.usedPercentage == 5 && merged.fable?.usedPercentage == 4)
        precondition(merged.fableSnapshot?.capturedAt == connected.fableSnapshot?.capturedAt)
        precondition(merged.fableSnapshot!.capturedAt < newer.capturedAt)
        let server = UsageSnapshot(fiveHour: newer.fiveHour, sevenDay: newer.sevenDay, capturedAt: Date(), source: .server)
        try SnapshotStore(fileURL: support.appendingPathComponent("server-snapshot.json"), source: .server).save(server)
        let serverMerged = UsageViewModel(settings: settings, notifications: notifications, home: root, supportDirectory: support)
        precondition(serverMerged.snapshot?.source == .server && serverMerged.fable?.usedPercentage == 4)
        precondition(serverMerged.fableSnapshot?.capturedAt == connected.fableSnapshot?.capturedAt)
        let noFable = UsageSnapshot(fiveHour: newer.fiveHour, sevenDay: newer.sevenDay, capturedAt: Date(), source: .claudeCLI, plan: "max")
        try SnapshotStore(fileURL: support.appendingPathComponent("claude-snapshot.json"), source: .claudeCLI).save(noFable)
        let removed = UsageViewModel(settings: settings, notifications: notifications, home: root, supportDirectory: support)
        precondition(removed.snapshot?.source == .claudeCLI && removed.fable == nil)
        for (name, suffix) in [("anthropic", "svg"), ("claude", "svg"), ("chatgpt", "svg"), ("cursor", "svg"), ("grok-bot", "png")] {
            let url = Bundle.module.url(forResource: name, withExtension: suffix)!
            let image = NSImage(contentsOf: url)
            precondition(image != nil, "Logotipas neperskaitomas: \(name)")
            precondition(image!.size.width >= 16 && image!.size.height >= 16,
                         "Logo needs explicit image dimensions for AppKit: \(name)")
        }
        for scheme in [ColorScheme.light, .dark] {
            for source in MenuBarSource.allCases {
                let windows = source == .claude ? [connected.fiveHour, connected.sevenDay]
                    : [source == .fable ? connected.fable! : codex.window]
                let label = MenuBarLabelView(source: source, windows: windows, showRemaining: false, hasData: true)
                try renderMenuBar(label, name: "\(source.rawValue)-menubar-\(scheme)", directory: output, scheme: scheme)
            }
        }

        // Reproduce expired cached limits, failed refresh and a complete interactive sign-in.
        let loginSupport = root.appendingPathComponent("login-support")
        let expired = UsageSnapshot(fiveHour: UsageWindow(usedPercentage: 97, resetsAt: Date().addingTimeInterval(-60)),
                                    sevenDay: UsageWindow(usedPercentage: 33, resetsAt: Date().addingTimeInterval(-60)),
                                    capturedAt: Date().addingTimeInterval(-9 * 3600), source: .claudeCLI,
                                    fable: UsageWindow(usedPercentage: 56, resetsAt: Date().addingTimeInterval(-60)), plan: "max")
        try SnapshotStore(fileURL: loginSupport.appendingPathComponent("claude-snapshot.json"), source: .claudeCLI).save(expired)
        let fakeCLI = root.appendingPathComponent("fake claude")
        try "#!/bin/bash\n[ \"$1\" = auth ] && [ \"$2\" = login ] || exit 91\nexit 0\n".write(to: fakeCLI, atomically: true, encoding: .utf8)
        try FileManager.default.setAttributes([.posixPermissions: 0o700], ofItemAtPath: fakeCLI.path)
        let signedIn = root.appendingPathComponent("signed-in")
        let recovery = UsageViewModel(settings: settings, notifications: notifications, home: root, supportDirectory: loginSupport,
            claudeExecutable: fakeCLI, fetchClaude: { _ in
                guard FileManager.default.fileExists(atPath: signedIn.path) else { throw ClaudeClient.ClientError.unavailable }
                return UsageSnapshot(fiveHour: cli.fiveHour, sevenDay: cli.sevenDay, capturedAt: Date(), source: .claudeCLI, fable: cli.fable)
            }, openClaudeSignIn: { url in
                try Data().write(to: signedIn)
                let process = Process()
                process.executableURL = URL(fileURLWithPath: "/bin/bash")
                process.arguments = [url.path]
                try process.run(); process.waitUntilExit()
            })
        recovery.requestServerRefresh()
        await waitForClaude(recovery)
        precondition(recovery.canReconnectClaude && recovery.isAwaitingClaudeUpdate)
        precondition(recovery.sevenDay.usedPercentage == 33 && recovery.sevenDay.didReset)
        for language in [AppLanguage.en, .lt] {
            settings.language = language
            try render(UsagePanelView(model: recovery, codex: codex, settings: settings), name: "expired-\(language)", directory: output, scheme: .dark)
        }
        try renderMenuBar(MenuBarLabelView(source: .claude, windows: [recovery.fiveHour, recovery.sevenDay], showRemaining: true, hasData: true),
                          name: "expired-menubar", directory: output, scheme: .dark)
        await recovery.signInToClaude()
        await waitForClaude(recovery)
        precondition(!recovery.isSigningIn && !recovery.canReconnectClaude && !recovery.isAwaitingClaudeUpdate,
                     "Successful sign-in must bypass the 30-second refresh floor and failure backoff")
        precondition(recovery.sevenDay.usedPercentage == 3)
        precondition(SnapshotStore(fileURL: loginSupport.appendingPathComponent("claude-snapshot.json"), source: .claudeCLI).load()?.sevenDay.usedPercentage == 3)

        let failedLogin = UsageViewModel(settings: settings, notifications: notifications, home: root, supportDirectory: loginSupport,
            claudeExecutable: fakeCLI, fetchClaude: { _ in preconditionFailure("Failed sign-in must not fetch usage") },
            openClaudeSignIn: { url in try "7\n".write(to: url.deletingLastPathComponent().appendingPathComponent("result"), atomically: true, encoding: .utf8) })
        await failedLogin.signInToClaude()
        precondition(failedLogin.canReconnectClaude && !failedLogin.isSigningIn && failedLogin.claudeNote != nil)

        let launchFailure = UsageViewModel(settings: settings, notifications: notifications, home: root, supportDirectory: loginSupport,
            claudeExecutable: fakeCLI, openClaudeSignIn: { _ in throw CocoaError(.fileNoSuchFile) })
        await launchFailure.signInToClaude()
        precondition(launchFailure.canReconnectClaude && !launchFailure.isSigningIn)
        precondition(launchFailure.claudeNote?.contains("claude auth login") == true)

        let pendingLogin = UsageViewModel(settings: settings, notifications: notifications, home: root, supportDirectory: loginSupport,
            claudeExecutable: fakeCLI, openClaudeSignIn: { _ in })
        await pendingLogin.signInToClaude(timeout: 0)
        precondition(!pendingLogin.isSigningIn && pendingLogin.canReconnectClaude)

        let fakeCodex = root.appendingPathComponent("fake codex")
        try "#!/bin/bash\n[ \"$#\" -eq 1 ] && [ \"$1\" = login ] || exit 91\nexit 0\n".write(to: fakeCodex, atomically: true, encoding: .utf8)
        try FileManager.default.setAttributes([.posixPermissions: 0o700], ofItemAtPath: fakeCodex.path)
        let codexSignedIn = root.appendingPathComponent("codex-signed-in")
        let freshCodex = CodexSnapshot(window: UsageWindow(usedPercentage: 12, resetsAt: Date().addingTimeInterval(86400)),
                                      windowMinutes: 10080, capturedAt: Date(), planType: "prolite")
        let codexRecovery = CodexViewModel(settings: settings, notifications: notifications, store: codexStore,
            availability: .ready(fakeCodex), executable: fakeCodex, readAvailability: { .ready(fakeCodex) },
            fetchUsage: { _ in
                guard FileManager.default.fileExists(atPath: codexSignedIn.path) else { throw CodexParser.ParseError.rpcError("Sign-in expired") }
                return freshCodex
            }, openSignIn: { url in
                try Data().write(to: codexSignedIn)
                let process = Process()
                process.executableURL = URL(fileURLWithPath: "/bin/bash")
                process.arguments = [url.path]
                try process.run(); process.waitUntilExit()
            })
        codexRecovery.requestRefresh()
        await waitForCodex(codexRecovery)
        precondition(codexRecovery.canReconnect, "Expired credentials must offer ChatGPT sign-in even when the auth file exists")
        await codexRecovery.signInToChatGPT()
        await waitForCodex(codexRecovery)
        precondition(!codexRecovery.isSigningIn && !codexRecovery.canReconnect && !codexRecovery.isSignedOut)
        precondition(codexRecovery.window.usedPercentage == 12 && codexStore.load()?.window.usedPercentage == 12,
                     "ChatGPT sign-in must refresh immediately despite the manual floor and backoff")
        precondition(recovery.sevenDay.usedPercentage == 3, "ChatGPT sign-in must not change Claude readings")

        let signedOutCodex = CodexViewModel(settings: settings, notifications: notifications,
            store: CodexStore(fileURL: root.appendingPathComponent("empty-codex.json")), availability: .signedOut,
            executable: fakeCodex, readAvailability: { .signedOut }, fetchUsage: { _ in freshCodex },
            openSignIn: { url in try "0\n".write(to: url.deletingLastPathComponent().appendingPathComponent("result"), atomically: true, encoding: .utf8) })
        let emptyClaude = UsageViewModel(settings: settings, notifications: notifications, home: root, supportDirectory: root.appendingPathComponent("empty-claude"))
        for language in [AppLanguage.en, .lt] {
            settings.language = language
            try render(UsagePanelView(model: emptyClaude, codex: signedOutCodex, settings: settings), name: "chatgpt-sign-in-\(language)", directory: output, scheme: .light)
        }
        await signedOutCodex.signInToChatGPT()
        await waitForCodex(signedOutCodex)
        precondition(!signedOutCodex.isSignedOut && signedOutCodex.window.usedPercentage == 12)

        for outcome in ["failed", "launch-error", "timeout"] {
            let failure = CodexViewModel(settings: settings, notifications: notifications, store: codexStore,
                availability: .signedOut, executable: fakeCodex, readAvailability: { .signedOut },
                fetchUsage: { _ in preconditionFailure("Unfinished ChatGPT sign-in must not fetch usage") },
                openSignIn: { url in
                    if outcome == "launch-error" { throw CocoaError(.fileNoSuchFile) }
                    if outcome == "failed" { try "7\n".write(to: url.deletingLastPathComponent().appendingPathComponent("result"), atomically: true, encoding: .utf8) }
                })
            await failure.signInToChatGPT(timeout: outcome == "timeout" ? 0 : 10)
            precondition(failure.canReconnect && !failure.isSigningIn && failure.isSignedOut && failure.note != nil)
            if outcome == "launch-error" { precondition(failure.note?.contains("codex login") == true) }
        }

        // Opt-in real Terminal handoff with a harmless local fixture, never a real account.
        if ProcessInfo.processInfo.environment["POM_TERMINAL_TEST"] == "1" {
            let terminalLogin = UsageViewModel(settings: settings, notifications: notifications, home: root, supportDirectory: loginSupport,
                claudeExecutable: fakeCLI, fetchClaude: { _ in
                    UsageSnapshot(fiveHour: cli.fiveHour, sevenDay: cli.sevenDay, capturedAt: Date(), source: .claudeCLI, fable: cli.fable)
                })
            await terminalLogin.signInToClaude(timeout: 45)
            await waitForClaude(terminalLogin)
            precondition(!terminalLogin.canReconnectClaude && terminalLogin.claudeNote == nil, "Real Terminal handoff failed")
            print("Terminal handoff passed with a synthetic CLI")
            let terminalCodex = CodexViewModel(settings: settings, notifications: notifications, store: codexStore,
                availability: .signedOut, executable: fakeCodex, readAvailability: { .signedOut }, fetchUsage: { _ in freshCodex })
            await terminalCodex.signInToChatGPT(timeout: 45)
            await waitForCodex(terminalCodex)
            precondition(!terminalCodex.isSignedOut && !terminalCodex.canReconnect && terminalCodex.window.usedPercentage == 12,
                         "ChatGPT Terminal handoff failed")
            print("ChatGPT Terminal handoff passed with a synthetic CLI")
        }
        print("Claude sign-in recovery: success, failed login, launch failure, timeout and expired displays passed")
        print("ChatGPT sign-in recovery: signed-out, expired credentials, success, failure, launch failure and timeout passed")
        try await checkAdditionalUsage(settings: settings, root: root, output: output, claude: disconnected, codex: codex)
    }

    @MainActor static func checkAdditionalUsage(settings: Settings, root: URL, output: URL,
                                               claude: UsageViewModel, codex: CodexViewModel) async throws {
        precondition(!settings.cursorMetricsEnabled, "Cursor network access must default to off")
        let database = CursorClient.databaseURL(home: root)
        try FileManager.default.createDirectory(at: database.deletingLastPathComponent(), withIntermediateDirectories: true)
        try Data().write(to: database)
        try FileManager.default.createDirectory(at: GrokBotCache(home: root).directory, withIntermediateDirectories: true)
        let sessionFile = root.appendingPathComponent("synthetic-cursor-session")
        let requestStarted = root.appendingPathComponent("synthetic-cursor-request")
        let sessionRead = root.appendingPathComponent("synthetic-cursor-read")
        let failureFile = root.appendingPathComponent("synthetic-cursor-failure")
        let grokSignOut = root.appendingPathComponent("synthetic-grok-signout")
        try "fixture-A".write(to: sessionFile, atomically: true, encoding: .utf8)
        let now = Date()
        let cursor = ProviderUsageSnapshot(meters: [.init(kind: .auto, usedPercentage: 14, resetsAt: now.addingTimeInterval(86400)),
                                                   .init(kind: .api, usedPercentage: 73, resetsAt: now.addingTimeInterval(86400))],
                                           capturedAt: now, planName: "Premium", onDemand: .init(usedCents: 125, limitCents: 5000))
        let grok = ProviderUsageSnapshot(meters: [.init(kind: .weekly, usedPercentage: 2, resetsAt: now.addingTimeInterval(5 * 86400))],
                                         capturedAt: now.addingTimeInterval(-3600), planName: "Grok Bot Plan")
        let additional = AdditionalUsageViewModel(settings: settings, home: root,
            readCursorSession: {
                try Data().write(to: sessionRead)
                return CursorClient.Session(accessToken: try String(contentsOf: sessionFile, encoding: .utf8))
            },
            fetchCursor: { _ in
                try Data().write(to: requestStarted)
                try? await Task.sleep(for: .milliseconds(100))
                if FileManager.default.fileExists(atPath: failureFile.path) { throw CursorClient.ClientError.unavailable }
                return cursor
            }, readGrokBot: {
                if FileManager.default.fileExists(atPath: grokSignOut.path) { throw GrokBotCache.CacheError.signedOut }
                return grok
            })
        additional.refreshNow()
        for _ in 0..<100 where additional.grokBot == nil { try await Task.sleep(for: .milliseconds(10)) }
        precondition(additional.grokBot == grok && additional.cursor == nil)
        precondition(!FileManager.default.fileExists(atPath: requestStarted.path), "Disabled Cursor integration must never request the server")
        precondition(!FileManager.default.fileExists(atPath: sessionRead.path), "Disabled Cursor integration must not read session credentials")
        precondition(additional.grokBot?.capturedAt == grok.capturedAt, "Local polling must not make old readings fresh")
        settings.language = .en
        try render(AdditionalUsageSections(model: additional, settings: settings).frame(width: 344),
                   name: "cursor-grok-disabled-en", directory: output, scheme: .light)
        try render(UsagePanelView(model: claude, codex: codex, settings: settings, additional: additional),
                   name: "dashboard-cursor-disabled", directory: output, scheme: .light, dashboard: true)

        settings.cursorMetricsEnabled = true
        additional.refreshNow(manual: true)
        for _ in 0..<100 where additional.cursor == nil { try await Task.sleep(for: .milliseconds(10)) }
        precondition(additional.cursor == cursor && !additional.isFetchingCursor)
        precondition(additional.menuWindows(for: .cursor).count == 2)
        settings.setSource(.cursor, enabled: true)
        settings.setSource(.grokBot, enabled: true)
        let dashboard = UsagePanelView(model: claude, codex: codex, settings: settings, additional: additional)
        precondition(dashboard.orderedSources == [.cursor, .codex, .claude, .grokBot],
                     "The highest individual limit, including Cursor's second meter, must lead")
        for language in [AppLanguage.en, .lt] {
            settings.language = language
            try render(AdditionalUsageSections(model: additional, settings: settings).frame(width: 344),
                       name: "cursor-grok-\(language)", directory: output, scheme: language == .lt ? .dark : .light)
            for scheme in [ColorScheme.light, .dark] {
                try render(UsagePanelView(model: claude, codex: codex, settings: settings, additional: additional),
                           name: "dashboard-\(language)-\(scheme)", directory: output, scheme: scheme, dashboard: true)
            }
            for source in [MenuBarSource.cursor, .grokBot] {
                try renderMenuBar(MenuBarLabelView(source: source, windows: additional.menuWindows(for: source),
                                                   showRemaining: true, hasData: true),
                                  name: "\(source.rawValue)-remaining-\(language)", directory: output, scheme: .dark)
            }
        }

        settings.setSource(.fable, enabled: true)
        precondition(dashboard.orderedSources == [.cursor, .codex, .claude, .fable, .grokBot])
        for source in MenuBarSource.allCases {
            settings.togglePin(source)
            precondition(dashboard.orderedSources.first == source)
            try render(dashboard, name: "bento-pinned-\(source.rawValue)", directory: output, scheme: .light, dashboard: true)
            settings.togglePin(source)
        }
        let expiredSupport = root.appendingPathComponent("bento-expired-support")
        let expiredSnapshot = UsageSnapshot(
            fiveHour: UsageWindow(usedPercentage: 97, resetsAt: now.addingTimeInterval(-60)),
            sevenDay: UsageWindow(usedPercentage: 90, resetsAt: now.addingTimeInterval(-60)),
            capturedAt: now.addingTimeInterval(-9 * 3600), source: .claudeCLI,
            fable: UsageWindow(usedPercentage: 95, resetsAt: now.addingTimeInterval(-60)), plan: "max")
        try SnapshotStore(fileURL: expiredSupport.appendingPathComponent("claude-snapshot.json"), source: .claudeCLI).save(expiredSnapshot)
        let expiredClaude = UsageViewModel(settings: settings, notifications: NotificationService(),
            home: root.appendingPathComponent("bento-disconnected-home"), supportDirectory: expiredSupport,
            claudeExecutable: root.appendingPathComponent("fake claude"), fetchClaude: { _ in throw ClaudeClient.ClientError.unavailable })
        expiredClaude.requestServerRefresh()
        await waitForClaude(expiredClaude)
        let expiredDashboard = UsagePanelView(model: expiredClaude, codex: codex, settings: settings, additional: additional)
        precondition(expiredDashboard.orderedSources.first == .cursor, "Expired cached percentages cannot win automatic priority")
        settings.togglePin(.grokBot)
        for language in [AppLanguage.en, .lt] {
            settings.language = language
            try render(expiredDashboard, name: "bento-expired-all-\(language)", directory: output, scheme: .light, dashboard: true)
        }
        settings.togglePin(.grokBot)
        // Render every non-empty subset, including removal of the automatic leader.
        for mask in 1..<(1 << MenuBarSource.allCases.count) {
            let selected = MenuBarSource.allCases.enumerated().compactMap { index, source in
                mask & (1 << index) != 0 ? source : nil
            }
            for source in selected { settings.setSource(source, enabled: true) }
            for source in MenuBarSource.allCases where !selected.contains(source) {
                settings.setSource(source, enabled: false)
            }
            precondition(Set(dashboard.orderedSources) == Set(selected), "Hidden services must leave the grid")
            try render(dashboard, name: "bento-subset-\(mask)", directory: output, scheme: .light, dashboard: true)
        }
        precondition(UsageBentoOrder.sorted([.claude, .codex, .cursor], usage: [.claude: 0, .codex: 0]) == [.claude, .codex, .cursor],
                     "Known zero readings precede missing data; equal values keep a stable order")
        precondition(UsageBentoOrder.sorted([.claude, .codex], usage: [.claude: 8, .codex: 90], pinned: .grokBot) == [.codex, .claude],
                     "An obsolete pin cannot insert a hidden card")
        for heights: [CGFloat] in [[180], [180, 260], [180, 120, 310], [180, 200, 120, 240], [180, 190, 120, 300, 100]] {
            let frames = BentoCardLayout.frames(heights: heights)
            precondition(frames.count == heights.count)
            let heroArea = frames[0].width * frames[0].height
            for index in frames.indices {
                precondition(frames[index].height >= heights[index], "Card content must never be clipped")
                if index > 0 {
                    precondition(heroArea > frames[index].width * frames[index].height, "The selected hero must have the largest area")
                }
                for other in frames.indices where other > index {
                    precondition(!frames[index].intersects(frames[other]), "Bento cards must never overlap")
                }
            }
        }
        print("Bento: all 31 visibility combinations, five exclusive pins, persistence, unpinning and automatic order passed")

        // Changing the session forces a fresh request; failure cannot show the old account.
        try Data().write(to: failureFile)
        try "fixture-B".write(to: sessionFile, atomically: true, encoding: .utf8)
        additional.refreshNow()
        for _ in 0..<100 where additional.cursorError == nil { try await Task.sleep(for: .milliseconds(10)) }
        precondition(additional.cursor == nil && additional.cursorError == .unavailable)
        try Data().write(to: grokSignOut)
        additional.refreshNow()
        for _ in 0..<100 where additional.grokBot != nil { try await Task.sleep(for: .milliseconds(10)) }
        precondition(additional.grokBot == nil, "Grok sign-out must clear the previous account's readings")
        try render(AdditionalUsageSections(model: additional, settings: settings).frame(width: 344),
                   name: "cursor-grok-unavailable", directory: output, scheme: .light)
        for language in [AppLanguage.en, .lt] {
            settings.language = language
            try render(UsagePanelView(model: claude, codex: codex, settings: settings, additional: additional),
                       name: "dashboard-unavailable-\(language)", directory: output, scheme: .light, dashboard: true)
        }

        // A different account selected during a request invalidates that result.
        try FileManager.default.removeItem(at: failureFile)
        try "fixture-C".write(to: sessionFile, atomically: true, encoding: .utf8)
        additional.refreshNow()
        for _ in 0..<100 where !additional.isFetchingCursor { try await Task.sleep(for: .milliseconds(5)) }
        precondition(additional.isFetchingCursor)
        try "fixture-D".write(to: sessionFile, atomically: true, encoding: .utf8)
        for _ in 0..<100 where additional.isFetchingCursor { try await Task.sleep(for: .milliseconds(10)) }
        precondition(additional.cursor == nil, "A request for the previous account must not populate the new account")

        // Even a transport that ignores cancellation cannot restore disabled metrics.
        additional.refreshNow()
        for _ in 0..<100 where !additional.isFetchingCursor { try await Task.sleep(for: .milliseconds(5)) }
        precondition(additional.isFetchingCursor)
        settings.cursorMetricsEnabled = false
        additional.refreshNow()
        try await Task.sleep(for: .milliseconds(150))
        precondition(additional.cursor == nil && !additional.isFetchingCursor && additional.cursorError == nil,
                     "A completed request must not re-enable a disabled integration")
        print("Cursor/Grok: opt-in, separate meters, cache age, account switch, missing readings and cancellation passed")
    }

    @MainActor static func waitForClaude(_ model: UsageViewModel) async {
        for _ in 0..<100 where model.isFetchingClaude { try? await Task.sleep(for: .milliseconds(20)) }
        precondition(!model.isFetchingClaude, "Fixture fetch did not finish")
    }
    @MainActor static func waitForCodex(_ model: CodexViewModel) async {
        for _ in 0..<100 where model.isFetching { try? await Task.sleep(for: .milliseconds(20)) }
        precondition(!model.isFetching, "Codex fixture fetch did not finish")
    }
    @MainActor static func renderMenuBar(_ view: MenuBarLabelView, name: String, directory: URL, scheme: ColorScheme) throws {
        let renderer = ImageRenderer(content: view.environment(\.colorScheme, scheme)
            .background(scheme == .dark ? Color.black : Color.white))
        renderer.scale = 2
        guard let image = renderer.cgImage else { throw NSError(domain: "menubar-render", code: 1) }
        precondition(image.width == Int(MenuBarLabelView.width * 2) && image.height == 44)
        let bitmap = NSBitmapImageRep(cgImage: image)
        try bitmap.representation(using: .png, properties: [:])!.write(to: directory.appendingPathComponent(name + ".png"))
        print("\(name): \(image.width) × \(image.height) px (Retina)")
    }
    @MainActor static func render<V: View>(_ view: V, name: String, directory: URL, scheme: ColorScheme,
                                         dashboard: Bool = false) throws {
        let hosting = NSHostingView(rootView: view.environment(\.colorScheme, scheme).background(scheme == .dark ? Color.black : Color.white))
        hosting.frame = NSRect(origin: .zero, size: hosting.fittingSize)
        hosting.layoutSubtreeIfNeeded()
        if dashboard {
            precondition(hosting.frame.width == 744, "Dashboard must have two readable columns")
            func containsScrollView(_ view: NSView) -> Bool {
                view is NSScrollView || view.subviews.contains(where: containsScrollView)
            }
            precondition(!containsScrollView(hosting), "All provider cards must fit without a scroll container")
        }
        guard let bitmap = hosting.bitmapImageRepForCachingDisplay(in: hosting.bounds) else { throw NSError(domain: "render", code: 1) }
        hosting.cacheDisplay(in: hosting.bounds, to: bitmap)
        guard let data = bitmap.representation(using: .png, properties: [:]) else { throw NSError(domain: "png", code: 2) }
        try data.write(to: directory.appendingPathComponent(name + ".png"))
        print("\(name): \(Int(hosting.frame.width)) × \(Int(hosting.frame.height))")
        precondition(hosting.frame.height < 740, "Popover too tall")
    }
}
