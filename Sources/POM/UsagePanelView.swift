import POMCore
import SwiftUI

/// Dviejų skilčių suvestinė: visi paslaugų limitai matomi be slinkimo.
struct UsagePanelView: View {
    @ObservedObject var model: UsageViewModel
    @ObservedObject var codex: CodexViewModel
    @ObservedObject var settings: Settings
    @ObservedObject var additional: AdditionalUsageViewModel
    var updater: UpdateService? = nil
    var showHistory: () -> Void = {}
    @State private var showingBridgeConnection = false

    init(model: UsageViewModel, codex: CodexViewModel, settings: Settings,
         additional: AdditionalUsageViewModel? = nil, updater: UpdateService? = nil,
         showHistory: @escaping () -> Void = {}) {
        self.model = model; self.codex = codex; self.settings = settings
        self.additional = additional ?? AdditionalUsageViewModel(settings: settings)
        self.updater = updater; self.showHistory = showHistory
    }

    private var usageScores: [MenuBarSource: Double] {
        var scores: [MenuBarSource: Double] = [:]
        func add(_ source: MenuBarSource, _ windows: [DisplayWindow]) {
            scores[source] = windows.filter { !$0.didReset && $0.usedPercentage.isFinite }
                .map(\.usedPercentage).max()
        }
        if model.hasData { add(.claude, [model.fiveHour, model.sevenDay]) }
        if let fable = model.fable { add(.fable, [fable]) }
        if codex.hasData { add(.codex, [codex.window]) }
        for source in [MenuBarSource.cursor, .grokBot] where additional.snapshot(for: source) != nil {
            add(source, additional.menuWindows(for: source))
        }
        return scores
    }

    var orderedSources: [MenuBarSource] {
        UsageBentoOrder.sorted(settings.menuBarSources, usage: usageScores, pinned: settings.pinnedSource)
    }

    var body: some View {
        VStack(spacing: 0) {
            header
            separator
            UsageBentoGrid(sources: orderedSources) { source, featured, wide in
                VStack(alignment: .leading, spacing: 10) {
                    if featured {
                        Text(settings.pinnedSource == source
                             ? settings.text("Prisegta", "Pinned")
                             : settings.text("Pagal sunaudotą limito procentą", "By limit used (%)"))
                            .font(.system(size: 10, weight: .medium)).foregroundStyle(.secondary)
                    }
                    providerContent(source, featured: featured, wide: wide)
                }
            }
            .padding(16)

            separator
            footer
        }
        .frame(width: 744)
        .environment(\.locale, settings.locale)
    }

    @ViewBuilder
    private func providerContent(_ source: MenuBarSource, featured: Bool, wide: Bool) -> some View {
        switch source {
        case .claude: claudeSection(featured: featured, wide: wide)
        case .fable: fableSection(featured: featured)
        case .codex: codexSection(featured: featured)
        case .cursor, .grokBot:
            AdditionalUsageCard(model: additional, settings: settings, source: source, featured: featured, wide: wide)
        }
    }

    // MARK: - Bendros dalys

    private var header: some View {
        HStack {
            Text(settings.text("Limitai", "Usage limits"))
                .font(.system(size: 13, weight: .semibold))
            Spacer()
            Menu {
                ProviderVisibilityOptions(codex: codex, settings: settings, additional: additional)
            } label: {
                Label(settings.text("Paslaugos", "Services"), systemImage: "square.grid.2x2")
                    .font(.system(size: 11, weight: .medium))
            }
            .menuStyle(.borderlessButton).fixedSize()
            .help(settings.text("Rodyti paslaugų korteles ir meniu juostos indikatorius", "Show service cards and menu bar indicators"))
            Button(action: showHistory) {
                Label(settings.text("Istorija", "History"), systemImage: "chart.xyaxis.line")
                    .font(.system(size: 11, weight: .medium))
            }.buttonStyle(.plain).foregroundStyle(.secondary)
        }
        .padding(.horizontal, 18)
        .padding(.top, 14)
        .padding(.bottom, 12)
    }

    private var separator: some View {
        Rectangle()
            .fill(Color.primary.opacity(0.08))
            .frame(height: 1)
    }

    private func note(_ text: String, highlighted: Bool = false) -> some View {
        Text(text)
            .font(.system(size: 11))
            .foregroundStyle(highlighted ? Color.orange : Color.secondary)
            .multilineTextAlignment(.leading)
            .fixedSize(horizontal: false, vertical: true)
            .frame(maxWidth: .infinity, alignment: .leading)
    }

    // MARK: - Claude

    private func claudeSection(featured: Bool, wide: Bool) -> some View {
        VStack(alignment: .leading, spacing: featured ? 12 : 10) {
            SectionHeader(
                source: .claude, freshness: model.freshness,
                detail: model.hasData ? model.ageShort : "", plan: model.planTitle, pinSettings: settings)

            if model.hasData {
                HStack(alignment: .top, spacing: wide ? 20 : 12) {
                    WindowRow(title: settings.language.windowTitle(minutes: 300), window: model.fiveHour,
                              now: model.now, language: settings.language, prominent: featured)
                        .frame(maxWidth: .infinity)
                    WindowRow(title: settings.text("Visi modeliai · 7 dienų", "All models · 7-day"), window: model.sevenDay,
                              now: model.now, language: settings.language, prominent: featured)
                        .frame(maxWidth: .infinity)
                }
                if !model.isBridgeConnected {
                    if model.snapshot?.source == .claudeCLI && !model.canReconnectClaude && !model.isAwaitingClaudeUpdate {
                        Button { showingBridgeConnection.toggle() } label: {
                            Label(settings.text("Prijungti būsenos juostą", "Connect status line"), systemImage: "link")
                                .font(.system(size: 10)).foregroundStyle(.secondary)
                        }
                        .buttonStyle(.plain)
                        .popover(isPresented: $showingBridgeConnection) {
                            VStack(alignment: .leading, spacing: 12) {
                                note(settings.text("Limitus POM gauna tiesiogiai iš Claude Code. Būsenos juosta gali juos papildomai atnaujinti dirbant.",
                                                   "POM reads limits directly from Claude Code. The status line can also update them while you work."))
                                ConnectView(model: model, compact: true)
                            }.padding(16).frame(width: 300)
                        }
                    } else if model.snapshot?.source != .claudeCLI {
                        note(settings.text("Ryšys su būsenos juosta nutrūko. Rodomi paskutiniai gauti skaičiai.",
                                           "The status line is disconnected. Showing the last received readings."), highlighted: true)
                        ConnectView(model: model, compact: true)
                    }
                }
            } else {
                claudeEmptyState
            }

            // Pastaba apie serverį rodoma ir tada, kai skaičių dar nėra: kaip tik tada
            // vartotojas spaudžia atnaujinimo mygtuką ir laukia paaiškinimo.
            if let text = model.claudeNote ?? model.serverNote {
                note(text).help([model.claudeNote, model.serverNote].compactMap { $0 }.joined(separator: "\n\n"))
            }
            if model.isSigningIn || model.canReconnectClaude || model.isAwaitingClaudeUpdate {
                claudeSignIn
            }
            if model.hasData {
                ExtraUsageDisclosure(settings: settings, claude: model.extraSnapshot?.extraUsage,
                               capturedAt: model.extraSnapshot?.capturedAt)
            }
        }
    }

    private func fableSection(featured: Bool) -> some View {
        VStack(alignment: .leading, spacing: featured ? 12 : 10) {
            SectionHeader(source: .fable,
                          freshness: UsageDisplay.freshness(capturedAt: model.fableSnapshot?.capturedAt, now: model.now),
                          detail: model.fable == nil ? "" : model.fableAge, plan: model.planTitle, pinSettings: settings)
            if let fable = model.fable {
                WindowRow(title: settings.text("Fable · 7 dienų", "Fable · 7-day"), window: fable,
                          now: model.now, language: settings.language, prominent: featured)
            } else {
                note(settings.text("Claude nepateikė atskiro Fable limito.", "Claude has not reported a separate Fable limit."))
            }
        }
    }

    @ViewBuilder
    private var claudeSignIn: some View {
        VStack(alignment: .leading, spacing: 8) {
            if model.isSigningIn {
                note(settings.text("Užbaik prisijungimą atidarytame Terminal lange ir naršyklėje. POM po to atnaujins limitus automatiškai.",
                                   "Finish signing in using the opened Terminal window and browser. POM will then refresh your limits automatically."))
                HStack(spacing: 8) {
                    ProgressView().controlSize(.small)
                    Text(settings.text("Laukiama prisijungimo…", "Waiting for sign-in…"))
                        .font(.system(size: 11))
                }
            } else {
                HStack {
                    if model.canSignInToClaude {
                        Button(settings.text("Prisijungti prie Claude", "Sign in to Claude")) {
                            Task { await model.signInToClaude() }
                        }
                        .buttonStyle(.borderedProminent)
                        .help(settings.text("Atidaro Terminal ir paleidžia prisijungimą naršyklėje", "Opens Terminal and starts browser sign-in"))
                    }
                    Button(settings.text("Atnaujinti", "Refresh")) { model.requestServerRefresh() }
                        .disabled(model.isFetchingClaude)
                }
                .controlSize(.small)
            }
        }
    }

    @ViewBuilder
    private var claudeEmptyState: some View {
        if model.isBridgeConnected {
            VStack(spacing: 8) {
                Image(systemName: "clock.badge.questionmark")
                    .font(.system(size: 26, weight: .light))
                    .foregroundStyle(.secondary)
                Text(settings.text("Duomenų dar nėra", "No readings yet"))
                    .font(.system(size: 13, weight: .medium))
                Text(settings.text("POM klausia Claude Code. Skaičiai atsiras prisijungus prie paskyros.", "POM is checking Claude Code. Readings will appear when you are signed in."))
                    .font(.system(size: 11))
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .fixedSize(horizontal: false, vertical: true)

                if let text = model.jqNote {
                    Text(text)
                        .font(.system(size: 11))
                        .foregroundStyle(.orange)
                        .multilineTextAlignment(.center)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 8)
        } else {
            ConnectView(model: model)
        }
    }

    // MARK: - Codex

    private func codexSection(featured: Bool) -> some View {
        VStack(alignment: .leading, spacing: featured ? 12 : 10) {
            SectionHeader(
                source: .codex, freshness: codex.freshness,
                detail: codex.hasData ? codex.ageShort : "", plan: codex.planTitle, pinSettings: settings)

            if codex.isSignedOut {
                note(codex.signedOutNote, highlighted: true)
            }

            if codex.hasData {
                WindowRow(title: codex.title, window: codex.window, now: codex.now, language: settings.language, prominent: featured)
            } else if !codex.isSignedOut {
                note(settings.text("Skaičių dar nėra. POM klausia Codex kas kelias minutes.", "No readings yet. POM checks Codex every few minutes."))
            }

            if let text = codex.note { note(text) }
            if codex.isSigningIn || codex.isSignedOut || codex.canReconnect || codex.window.didReset {
                codexSignIn
            }
            if codex.hasData {
                ExtraUsageDisclosure(settings: settings, codex: codex.snapshot?.additionalUsage,
                               capturedAt: codex.snapshot?.capturedAt)
            }
        }
    }

    // MARK: - Apačia

    private var codexSignIn: some View {
        VStack(alignment: .leading, spacing: 8) {
            if codex.isSigningIn {
                note(settings.text("Užbaik prisijungimą prie ChatGPT atidarytame Terminal lange ir naršyklėje. POM po to atnaujins Codex limitus automatiškai.",
                                   "Finish signing in to ChatGPT using the opened Terminal window and browser. POM will then refresh Codex limits automatically."))
                HStack(spacing: 8) {
                    ProgressView().controlSize(.small)
                    Text(settings.text("Laukiama prisijungimo…", "Waiting for sign-in…")).font(.system(size: 11))
                }
            } else {
                HStack {
                    if codex.canSignIn {
                        Button(settings.text("Prisijungti prie ChatGPT", "Sign in to ChatGPT")) {
                            Task { await codex.signInToChatGPT() }
                        }
                        .buttonStyle(.borderedProminent)
                        .help(settings.text("Atidaro Terminal ir paleidžia prisijungimą naršyklėje", "Opens Terminal and starts browser sign-in"))
                    }
                    Button(settings.text("Atnaujinti", "Refresh")) { codex.requestRefresh() }
                        .disabled(codex.isFetching)
                }
                .controlSize(.small)
            }
        }
    }

    private var footer: some View {
        HStack(spacing: 8) {
            if model.hasData {
                Text(model.sourceText)
                    .font(.system(size: 10))
                    .foregroundStyle(.tertiary)
                    .lineLimit(1)
                    .layoutPriority(-1)
            }

            Spacer()

            Link(destination: ProjectLinks.support) {
                Label(settings.text("Paremti POM", "Support POM"), systemImage: "heart")
                    .font(.system(size: 11, weight: .semibold))
                    .padding(.horizontal, 7)
                    .padding(.vertical, 5)
                    .background(Color.accentColor.opacity(0.08), in: RoundedRectangle(cornerRadius: 6))
            }
            .buttonStyle(.plain)
            .foregroundStyle(Color.accentColor)
            .fixedSize()
            .help(settings.text("Paremti POM kūrimą per Stripe", "Support POM development via Stripe"))

            Button(action: refreshEverything) {
                Image(systemName: "arrow.clockwise")
                    .font(.system(size: 12, weight: .medium))
            }
            .buttonStyle(IconButtonStyle())
            .help(settings.text("Atnaujinti dabar", "Refresh now"))

            SettingsMenu(model: model, codex: codex, settings: settings, additional: additional, updater: updater)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
        .focusEffectDisabled()
    }

    private func refreshEverything() {
        model.requestServerRefresh()
        codex.requestRefresh()
        additional.refreshNow(manual: true)
    }
}
