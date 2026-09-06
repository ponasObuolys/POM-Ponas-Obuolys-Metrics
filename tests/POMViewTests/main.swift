import AppKit
import SwiftUI
import POMCore

@main struct POMVisualCheck {
    @MainActor static func main() throws {
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
        for name in ["anthropic", "chatgpt"] {
            let url = Bundle.module.url(forResource: name, withExtension: "svg")!
            precondition(NSImage(contentsOf: url) != nil, "Logotipas neperskaitomas: \(name)")
        }
        for scheme in [ColorScheme.light, .dark] {
            for source in MenuBarSource.allCases {
                let windows = source == .claude ? [connected.fiveHour, connected.sevenDay]
                    : [source == .fable ? connected.fable! : codex.window]
                let label = MenuBarLabelView(source: source, windows: windows, showRemaining: false, hasData: true)
                try renderMenuBar(label, name: "\(source.rawValue)-menubar-\(scheme)", directory: output, scheme: scheme)
            }
        }
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
    @MainActor static func render<V: View>(_ view: V, name: String, directory: URL, scheme: ColorScheme) throws {
        let hosting = NSHostingView(rootView: view.environment(\.colorScheme, scheme).background(scheme == .dark ? Color.black : Color.white))
        hosting.frame = NSRect(origin: .zero, size: hosting.fittingSize)
        hosting.layoutSubtreeIfNeeded()
        guard let bitmap = hosting.bitmapImageRepForCachingDisplay(in: hosting.bounds) else { throw NSError(domain: "render", code: 1) }
        hosting.cacheDisplay(in: hosting.bounds, to: bitmap)
        guard let data = bitmap.representation(using: .png, properties: [:]) else { throw NSError(domain: "png", code: 2) }
        try data.write(to: directory.appendingPathComponent(name + ".png"))
        print("\(name): \(Int(hosting.frame.width)) × \(Int(hosting.frame.height))")
        precondition(hosting.frame.height < 740, "Popover too tall")
    }
}
