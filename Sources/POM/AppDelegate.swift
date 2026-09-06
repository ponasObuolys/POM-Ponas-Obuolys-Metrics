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
    private var history: HistoryService!
    private let updater = UpdateService()
    private var historyWindow: NSWindow?

    private var statusItem: NSStatusItem!
    private var popover: NSPopover!
    private var cancellables: Set<AnyCancellable> = []
    /// Paspaudimų šalia langelio klausytojas. Gyvas tik tol, kol langelis atviras.
    private var outsideClickMonitor: Any?

    func applicationDidFinishLaunching(_ notification: Notification) {
        model = UsageViewModel(settings: settings, notifications: notifications)
        codex = CodexViewModel(settings: settings, notifications: notifications)

        history = HistoryService(settings: settings, notifications: notifications)
        model.onSnapshot = { [weak self] in self?.history.record($0) }
        codex.onSnapshot = { [weak self] in self?.history.record($0) }
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
                Task { @MainActor in
                    self?.updateLabel()
                    self?.historyWindow?.title = self?.settings.text("POM · Naudojimo istorija", "POM · Usage history") ?? "POM"
                }
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
        history.start()
        updateLabel()

        updater.start()
        Task {
            await notifications.prepare()
            history.deliverPending()
            if let snapshot = model.snapshot { history.record(snapshot) }
            if let snapshot = codex.snapshot { history.record(snapshot) }
        }
    }

    func applicationWillTerminate(_ notification: Notification) {
        model.stop()
        codex.stop()
        history.stop()
    }

    // MARK: - Meniu juostos elementas

    private func setUpStatusItem() {
        statusItem = NSStatusBar.system.statusItem(withLength: MenuBarLabelView.width)
        guard let button = statusItem.button else { return }
        button.target = self
        button.action = #selector(togglePopover)
        button.toolTip = "Claude ir Codex limitai"
    }

    private struct LabelKey: Equatable {
        let sources: [MenuBarSource]
        let values: [Int]
        let levels: [UsageLevel]
        let hasData: [Bool]
        let remaining: Bool
        let dark: Bool
        let scale: CGFloat
        let language: AppLanguage
    }
    private var lastLabelKey: LabelKey?
    private var entries: [MenuBarEntry] {
        settings.menuBarSources.map { source in
            switch source {
            case .claude: return MenuBarEntry(source: source, windows: [model.fiveHour, model.sevenDay], hasData: model.hasData)
            case .fable: return MenuBarEntry(source: source, windows: [model.fable ?? .empty], hasData: model.fable != nil)
            case .codex: return MenuBarEntry(source: source, windows: [codex.window], hasData: codex.hasData)
            }
        }
    }
    private func updateLabel() {
        guard let button = statusItem?.button else { return }
        let dark = button.effectiveAppearance.bestMatch(from: [.aqua, .darkAqua]) == .darkAqua
        let scale = button.window?.backingScaleFactor ?? 2
        let entries = entries
        let windows = entries.flatMap(\.windows)
        let key = LabelKey(sources: entries.map(\.source), values: windows.map { Int($0.usedPercentage.rounded()) },
                           levels: windows.map(\.level), hasData: entries.map(\.hasData), remaining: settings.showRemaining,
                           dark: dark, scale: scale, language: settings.language.resolved())
        guard key != lastLabelKey else { return }
        lastLabelKey = key
        let label = MenuBarGroupView(entries: entries, showRemaining: settings.showRemaining)
            .environment(\.colorScheme, dark ? .dark : .light)
        let renderer = ImageRenderer(content: label); renderer.scale = scale
        guard let cgImage = renderer.cgImage else { return }
        let width = MenuBarGroupView.width(count: entries.count)
        let image = NSImage(cgImage: cgImage, size: NSSize(width: width, height: MenuBarLabelView.height))
        image.isTemplate = false
        statusItem.length = width
        button.image = image; button.imagePosition = .imageOnly
        let tooltip = entries.map { entry in
            let values = entry.hasData ? entry.windows.map {
                "\(Int((settings.showRemaining ? $0.remainingPercentage : $0.usedPercentage).rounded()))%"
            }.joined(separator: " / ") : settings.text("duomenų nėra", "no data")
            return "\(entry.source.title): \(values)"
        }.joined(separator: " · ")
        button.toolTip = tooltip
        button.setAccessibilityLabel(tooltip)
    }

    private func showHistory() {
        closePopover()
        if historyWindow == nil {
            let controller = NSHostingController(rootView: HistoryView(service: history, settings: settings))
            let window = NSWindow(contentViewController: controller)
            window.styleMask = [.titled, .closable, .miniaturizable, .resizable]
            window.setContentSize(NSSize(width: 840, height: 700))
            window.contentMinSize = NSSize(width: 780, height: 700)
            window.isReleasedWhenClosed = false
            window.center()
            historyWindow = window
        }
        historyWindow?.title = settings.text("POM · Naudojimo istorija", "POM · Usage history")
        NSApp.activate(ignoringOtherApps: true)
        historyWindow?.makeKeyAndOrderFront(nil)
    }

    // MARK: - Langelis

    private func setUpPopover() {
        popover = NSPopover()
        popover.behavior = .transient
        popover.animates = true

        let controller = NSHostingController(
            rootView: UsagePanelView(model: model, codex: codex, settings: settings, updater: updater,
                                     showHistory: { [weak self] in self?.showHistory() }))
        // Be šito langelio aukštis užsifiksuotų tą akimirką, kai jis sukuriamas.
        // Codex sekcija atsiranda maždaug sekunde vėliau, gavus atsakymą, ir turinys
        // nebetelptų: viršuje liktų nukirsta antraštė, o virš jos – nematoma lango dalis.
        controller.sizingOptions = [.preferredContentSize]
        popover.contentViewController = controller
        popover.delegate = self
    }

    @objc private func togglePopover() {
        guard let button = statusItem.button else { return }

        if popover.isShown {
            closePopover()
            return
        }

        model.refreshNow()
        codex.refreshNow()
        // Be aktyvavimo langelis kartais užsidaro tą pačią akimirką, nes programa
        // gyvena tik meniu juostoje ir neturi savo lango.
        NSApp.activate(ignoringOtherApps: true)
        popover.show(relativeTo: button.bounds, of: button, preferredEdge: .minY)
        popover.contentViewController?.view.window?.makeKey()
        watchForClicksOutside()
    }

    /// Langelis turi užsidaryti paspaudus bet kur šalia jo.
    ///
    /// Vien `NSPopover` savybės `.transient` nepakanka: programa gyvena tik meniu juostoje
    /// ir kitų langų neturi, tad paspaudimas kitoje vietoje jos ne visada pasiekia.
    /// Todėl paspaudimų klausomasi tiesiogiai; klausomasi tik tol, kol langelis atviras.
    private func watchForClicksOutside() {
        guard outsideClickMonitor == nil else { return }
        outsideClickMonitor = NSEvent.addGlobalMonitorForEvents(
            matching: [.leftMouseDown, .rightMouseDown, .otherMouseDown]
        ) { [weak self] _ in
            Task { @MainActor in self?.closePopover() }
        }
    }

    private func closePopover() {
        stopWatchingClicks()
        if popover.isShown { popover.performClose(nil) }
    }

    private func stopWatchingClicks() {
        guard let monitor = outsideClickMonitor else { return }
        NSEvent.removeMonitor(monitor)
        outsideClickMonitor = nil
    }
}

extension AppDelegate: NSPopoverDelegate {
    /// Langelis gali užsidaryti ir pats, be mūsų komandos. Tada klausytojas turi dingti
    /// kartu su juo, kitaip jis liktų kabėti ir be reikalo gaudytų kiekvieną paspaudimą.
    func popoverDidClose(_ notification: Notification) {
        stopWatchingClicks()
    }
}
