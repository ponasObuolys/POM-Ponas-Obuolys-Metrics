import AppKit
import Combine
import POMCore
import SwiftUI

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    private let settings = Settings()
    private let notifications = NotificationService()
    private var model: UsageViewModel!
    private var codex: CodexViewModel!

    private var statusItem: NSStatusItem!
    private var popover: NSPopover!
    private var cancellables: Set<AnyCancellable> = []

    func applicationDidFinishLaunching(_ notification: Notification) {
        model = UsageViewModel(settings: settings, notifications: notifications)
        codex = CodexViewModel(settings: settings, notifications: notifications)

        setUpStatusItem()
        setUpPopover()

        // Ikona perpiešiama, kai pasikeičia reikšmės arba nustatymai.
        model.objectWillChange
            .sink { [weak self] _ in
                Task { @MainActor in self?.updateLabel() }
            }
            .store(in: &cancellables)

        codex.objectWillChange
            .sink { [weak self] _ in
                Task { @MainActor in self?.updateLabel() }
            }
            .store(in: &cancellables)

        settings.objectWillChange
            .sink { [weak self] _ in
                Task { @MainActor in self?.updateLabel() }
            }
            .store(in: &cancellables)

        // Persijungus tarp šviesios ir tamsios išvaizdos ikoną reikia perpiešti iškart.
        DistributedNotificationCenter.default.addObserver(
            forName: Notification.Name("AppleInterfaceThemeChangedNotification"),
            object: nil, queue: .main
        ) { [weak self] _ in
            Task { @MainActor in self?.updateLabel() }
        }

        model.start()
        codex.start()
        updateLabel()

        Task { await notifications.prepare() }
    }

    func applicationWillTerminate(_ notification: Notification) {
        model.stop()
        codex.stop()
    }

    // MARK: - Meniu juostos elementas

    private func setUpStatusItem() {
        statusItem = NSStatusBar.system.statusItem(withLength: MenuBarLabelView.width)
        guard let button = statusItem.button else { return }
        button.target = self
        button.action = #selector(togglePopover)
        button.toolTip = "Claude ir Codex limitai"
    }

    /// Viskas, nuo ko priklauso piešinys. Sutampant su ankstesniu kartu piešti nereikia.
    private struct LabelKey: Equatable {
        var badge: String
        var values: [Int]
        var levels: [UsageLevel]
        var showRemaining: Bool
        var hasData: Bool
        var isDark: Bool
        var scale: CGFloat
    }

    private var lastLabelKey: LabelKey?

    /// Kurio įrankio skaičiai piešiami. Pasirinkus Codex, bet jo kompiuteryje neradus,
    /// rodomas Claude: tuščia ikona be jokio paaiškinimo būtų blogiau nei kito įrankio
    /// skaičiai. Pats nustatymas neperrašomas, tad grįžus Codex viskas atsistato savaime.
    private var effectiveSource: MenuBarSource {
        settings.menuBarSource == .codex && codex.isPresent ? .codex : .claude
    }

    /// SwiftUI vaizdas paverčiamas paveikslėliu, o ne dedamas į mygtuką kaip atskiras vaizdas.
    /// Taip išvengiama išsidėstymo ir paspaudimų problemų, o piešinys lieka aštrus.
    ///
    /// Laikrodis tiksi kas kelias sekundes, o skaičiai keičiasi retai. Todėl piešiama tik tada,
    /// kai iš tikrųjų yra kas pakeisti: programa veikia visą dieną, ir bereikalingas piešimas
    /// be jokios naudos eikvotų bateriją.
    private func updateLabel() {
        guard let button = statusItem?.button else { return }

        let isDark = button.effectiveAppearance.bestMatch(from: [.aqua, .darkAqua]) == .darkAqua
        let scale = button.window?.backingScaleFactor ?? 2
        let source = effectiveSource
        let windows = source == .codex ? [codex.window] : [model.fiveHour, model.sevenDay]
        let hasData = source == .codex ? codex.hasData : model.hasData

        let key = LabelKey(
            badge: source.badge,
            values: windows.map { Int($0.usedPercentage.rounded()) },
            levels: windows.map(\.level),
            showRemaining: settings.showRemaining,
            hasData: hasData,
            isDark: isDark,
            scale: scale
        )
        guard key != lastLabelKey else { return }
        lastLabelKey = key

        let label = MenuBarLabelView(
            badge: source.badge,
            windows: windows,
            showRemaining: settings.showRemaining,
            hasData: hasData
        )
        .environment(\.colorScheme, isDark ? .dark : .light)

        let renderer = ImageRenderer(content: label)
        renderer.scale = scale
        guard let cgImage = renderer.cgImage else { return }

        let image = NSImage(
            cgImage: cgImage,
            size: NSSize(width: MenuBarLabelView.width, height: MenuBarLabelView.height))
        image.isTemplate = false
        button.image = image
        button.imagePosition = .imageOnly
    }

    // MARK: - Langelis

    private func setUpPopover() {
        popover = NSPopover()
        popover.behavior = .transient
        popover.animates = true
        popover.contentViewController = NSHostingController(
            rootView: UsagePanelView(model: model, codex: codex, settings: settings))
    }

    @objc private func togglePopover() {
        guard let button = statusItem.button else { return }

        if popover.isShown {
            popover.performClose(nil)
            return
        }

        model.refreshNow()
        codex.refreshNow()
        // Be aktyvavimo langelis kartais užsidaro tą pačią akimirką, nes programa
        // gyvena tik meniu juostoje ir neturi savo lango.
        NSApp.activate(ignoringOtherApps: true)
        popover.show(relativeTo: button.bounds, of: button, preferredEdge: .minY)
        popover.contentViewController?.view.window?.makeKey()
    }
}
