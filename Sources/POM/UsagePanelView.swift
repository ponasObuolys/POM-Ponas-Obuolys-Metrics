import POMCore
import SwiftUI

/// Langelis, atsiveriantis paspaudus ikoną: Claude sekcija viršuje, Codex apačioje.
struct UsagePanelView: View {
    @ObservedObject var model: UsageViewModel
    @ObservedObject var codex: CodexViewModel
    @ObservedObject var settings: Settings
    var updater: UpdateService? = nil
    var showHistory: () -> Void = {}

    var body: some View {
        VStack(spacing: 0) {
            header
            separator
            ScrollView {
                VStack(spacing: 0) {
                    claudeSection
                    if codex.isPresent { separator; codexSection }
                }
            }
            .frame(height: codex.isPresent ? 580 : 440)

            separator
            footer
        }
        .frame(width: 344)
        .environment(\.locale, settings.locale)
    }

    // MARK: - Bendros dalys

    private var header: some View {
        HStack {
            Text(settings.text("Limitai", "Usage limits"))
                .font(.system(size: 13, weight: .semibold))
            Spacer()
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

    private var claudeSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            SectionHeader(
                source: .claude, freshness: model.freshness,
                detail: model.hasData ? model.ageShort : "")
            if let plan = model.planTitle { planLabel(plan) }

            if model.hasData {
                WindowRow(title: settings.language.windowTitle(minutes: 300), window: model.fiveHour, now: model.now, language: settings.language)
                WindowRow(title: settings.text("Visi modeliai · 7 dienų", "All models · 7-day"), window: model.sevenDay, now: model.now, language: settings.language)
                if let fable = model.fable {
                    WindowRow(title: settings.text("Fable · 7 dienų", "Fable · 7-day"), window: fable, now: model.now, language: settings.language)
                    if model.fableSnapshot?.capturedAt != model.snapshot?.capturedAt {
                        note(settings.text("Fable atnaujinta \(model.fableAge).", "Fable updated \(model.fableAge)."))
                    }
                }
                if !model.isBridgeConnected {
                    note(model.snapshot?.source == .claudeCLI
                         ? settings.text("Būsenos juosta neprijungta. Limitus POM gauna tiesiogiai iš Claude Code.", "The status line is not connected. POM reads limits directly from Claude Code.")
                         : settings.text("Ryšys su būsenos juosta nutrūko. Rodomi paskutiniai gauti skaičiai.", "The status line is disconnected. Showing the last received readings."), highlighted: true)
                    ConnectView(model: model, compact: true)
                }
            } else {
                claudeEmptyState
            }

            // Pastaba apie serverį rodoma ir tada, kai skaičių dar nėra: kaip tik tada
            // vartotojas spaudžia atnaujinimo mygtuką ir laukia paaiškinimo.
            if let text = model.serverNote { note(text) }
            if let text = model.claudeNote { note(text) }
            if model.hasData {
                ExtraUsageDisclosure(settings: settings, claude: model.extraSnapshot?.extraUsage,
                               capturedAt: model.extraSnapshot?.capturedAt)
            }
        }
        .padding(.horizontal, 18)
        .padding(.vertical, 16)
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

    private var codexSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            SectionHeader(
                source: .codex, freshness: codex.freshness,
                detail: codex.hasData ? codex.ageShort : "")
            if let plan = codex.planTitle { planLabel(plan) }

            if codex.isSignedOut {
                note(codex.signedOutNote, highlighted: true)
            }

            if codex.hasData {
                WindowRow(title: codex.title, window: codex.window, now: codex.now, language: settings.language)
            } else if !codex.isSignedOut {
                note(settings.text("Skaičių dar nėra. POM klausia Codex kas kelias minutes.", "No readings yet. POM checks Codex every few minutes."))
            }

            if let text = codex.note { note(text) }
            if codex.hasData {
                ExtraUsageDisclosure(settings: settings, codex: codex.snapshot?.additionalUsage,
                               capturedAt: codex.snapshot?.capturedAt)
            }
        }
        .padding(.horizontal, 18)
        .padding(.vertical, 16)
    }

    // MARK: - Apačia

    private func planLabel(_ title: String) -> some View {
        Text(title)
            .font(.system(size: 11, weight: .medium))
            .foregroundStyle(.secondary)
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(Color.primary.opacity(0.05), in: Capsule())
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

            SettingsMenu(model: model, codex: codex, settings: settings, updater: updater)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
        .focusEffectDisabled()
    }

    private func refreshEverything() {
        model.requestServerRefresh()
        codex.requestRefresh()
    }
}
