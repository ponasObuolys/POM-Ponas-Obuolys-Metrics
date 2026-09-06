import POMCore
import SwiftUI

/// Langelis, atsiveriantis paspaudus ikoną: Claude sekcija viršuje, Codex apačioje.
struct UsagePanelView: View {
    @ObservedObject var model: UsageViewModel
    @ObservedObject var codex: CodexViewModel
    @ObservedObject var settings: Settings

    var body: some View {
        VStack(spacing: 0) {
            header
            separator
            claudeSection

            if codex.isPresent {
                separator
                codexSection
            }

            separator
            footer
        }
        .frame(width: 324)
    }

    // MARK: - Bendros dalys

    private var header: some View {
        HStack {
            Text("Limitai")
                .font(.system(size: 13, weight: .semibold))
            Spacer()
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
                WindowRow(title: "5 valandų", window: model.fiveHour, now: model.now)
                WindowRow(title: "Visi modeliai · 7 dienų", window: model.sevenDay, now: model.now)
                if let fable = model.fable {
                    WindowRow(title: "Fable · 7 dienų", window: fable, now: model.now)
                    if model.fableSnapshot?.capturedAt != model.snapshot?.capturedAt {
                        note("Fable atnaujinta \(model.fableAge).")
                    }
                }
                if !model.isBridgeConnected {
                    note(model.snapshot?.source == .claudeCLI
                         ? "Būsenos juosta neprijungta. Limitus POM gauna tiesiogiai iš Claude Code."
                         : "Ryšys su būsenos juosta nutrūko. Rodomi paskutiniai gauti skaičiai.", highlighted: true)
                    ConnectView(model: model, compact: true)
                }
            } else {
                claudeEmptyState
            }

            // Pastaba apie serverį rodoma ir tada, kai skaičių dar nėra: kaip tik tada
            // vartotojas spaudžia atnaujinimo mygtuką ir laukia paaiškinimo.
            if let text = model.serverNote { note(text) }
            if let text = model.claudeNote { note(text) }
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
                Text("Duomenų dar nėra")
                    .font(.system(size: 13, weight: .medium))
                Text("POM klausia Claude Code. Skaičiai atsiras prisijungus prie paskyros.")
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
                WindowRow(title: codex.title, window: codex.window, now: codex.now)
            } else if !codex.isSignedOut {
                note("Skaičių dar nėra. POM klausia Codex kas kelias minutes.")
            }

            if let text = codex.note { note(text) }
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
            }

            Spacer()

            Button(action: refreshEverything) {
                Image(systemName: "arrow.clockwise")
                    .font(.system(size: 12, weight: .medium))
            }
            .buttonStyle(IconButtonStyle())
            .help("Atnaujinti dabar")

            SettingsMenu(model: model, codex: codex, settings: settings)
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
