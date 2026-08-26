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
                title: "CLAUDE", freshness: model.freshness,
                detail: model.hasData ? model.ageShort : "")

            if model.hasData {
                WindowRow(title: "5 valandų", window: model.fiveHour, now: model.now)
                WindowRow(title: "7 dienų", window: model.sevenDay, now: model.now)
            } else {
                claudeEmptyState
            }

            // Pastaba apie serverį rodoma ir tada, kai skaičių dar nėra: kaip tik tada
            // vartotojas spaudžia atnaujinimo mygtuką ir laukia paaiškinimo.
            if let text = model.serverNote { note(text) }
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
                Text("Padirbėk su Claude Code, ir per pusę minutės skaičiai atsiras čia.")
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
                title: "CODEX", freshness: codex.freshness,
                detail: codex.hasData ? codex.ageShort : "")

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
