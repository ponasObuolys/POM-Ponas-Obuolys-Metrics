import AppKit
import Combine
import POMCore
import SwiftUI

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    private let settings = Settings()
    private let notifications = NotificationService()
    private var model: UsageViewModel!

    private var statusItem: NSStatusItem!
    private var popover: NSPopover!
    private var cancellables: Set<AnyCancellable> = []

    func applicationDidFinishLaunching(_ notification: Notification) {
        model = UsageViewModel(settings: settings, notifications: notifications)

        setUpStatusItem()
        setUpPopover()

        // Ikona perpiešiama, kai pasikeičia reikšmės arba nustatymai.
        model.objectWillChange
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
        updateLabel()

        Task { await notifications.prepare() }
    }

    func applicationWillTerminate(_ notification: Notification) {
        model.stop()
    }

    // MARK: - Meniu juostos elementas

    private func setUpStatusItem() {
        statusItem = NSStatusBar.system.statusItem(withLength: MenuBarLabelView.width)
        guard let button = statusItem.button else { return }
        button.target = self
        button.action = #selector(togglePopover)
        button.toolTip = "Claude limitai"
    }

    /// Viskas, nuo ko priklauso piešinys. Sutampant su ankstesniu kartu piešti nereikia.
    private struct LabelKey: Equatable {
        var five: Int
        var seven: Int
        var fiveLevel: UsageLevel
        var sevenLevel: UsageLevel
        var showRemaining: Bool
        var hasData: Bool
        var isDark: Bool
        var scale: CGFloat
    }

    private var lastLabelKey: LabelKey?

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
        let key = LabelKey(
            five: Int(model.fiveHour.usedPercentage.rounded()),
            seven: Int(model.sevenDay.usedPercentage.rounded()),
            fiveLevel: model.fiveHour.level,
            sevenLevel: model.sevenDay.level,
            showRemaining: settings.showRemaining,
            hasData: model.hasData,
            isDark: isDark,
            scale: scale
        )
        guard key != lastLabelKey else { return }
        lastLabelKey = key

        let label = MenuBarLabelView(
            fiveHour: model.fiveHour,
            sevenDay: model.sevenDay,
            showRemaining: settings.showRemaining,
            hasData: model.hasData
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
            rootView: UsagePanelView(model: model, settings: settings))
    }

    @objc private func togglePopover() {
        guard let button = statusItem.button else { return }

        if popover.isShown {
            popover.performClose(nil)
            return
        }

        model.refreshNow()
        // Be aktyvavimo langelis kartais užsidaro tą pačią akimirką, nes programa
        // gyvena tik meniu juostoje ir neturi savo lango.
        NSApp.activate(ignoringOtherApps: true)
        popover.show(relativeTo: button.bounds, of: button, preferredEdge: .minY)
        popover.contentViewController?.view.window?.makeKey()
    }
}
