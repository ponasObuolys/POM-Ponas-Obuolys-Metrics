import POMCore
import SwiftUI

struct UsagePanelView: View {
    @ObservedObject var model: UsageViewModel
    @ObservedObject var settings: Settings

    var body: some View {
        VStack(spacing: 0) {
            header
            separator

            if model.hasData {
                VStack(spacing: 20) {
                    WindowRow(title: "5 valandų", window: model.fiveHour, now: model.now)
                    WindowRow(title: "7 dienų", window: model.sevenDay, now: model.now)
                }
                .padding(.horizontal, 18)
                .padding(.vertical, 18)
            } else {
                emptyState
            }

            if let note = model.serverNote {
                separator
                Text(note)
                    .font(.system(size: 11))
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.leading)
                    .fixedSize(horizontal: false, vertical: true)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.horizontal, 18)
                    .padding(.vertical, 10)
            }

            separator
            footer
        }
        .frame(width: 324)
    }

    // MARK: - Dalys

    private var header: some View {
        HStack(spacing: 8) {
            Text("Claude limitai")
                .font(.system(size: 13, weight: .semibold))

            Spacer()

            Circle()
                .fill(Theme.freshnessColor(model.freshness))
                .frame(width: 6, height: 6)
            Text(Theme.freshnessLabel(model.freshness))
                .font(.system(size: 11))
                .foregroundStyle(.secondary)
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

    @ViewBuilder
    private var emptyState: some View {
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

                if let note = model.jqNote {
                    Text(note)
                        .font(.system(size: 11))
                        .foregroundStyle(.orange)
                        .multilineTextAlignment(.center)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
            .padding(.horizontal, 26)
            .padding(.vertical, 26)
        } else {
            ConnectView(model: model)
        }
    }

    private var footer: some View {
        HStack(spacing: 8) {
            VStack(alignment: .leading, spacing: 1) {
                Text(model.ageText)
                    .font(.system(size: 11))
                    .foregroundStyle(.secondary)
                if model.hasData {
                    Text(model.sourceText)
                        .font(.system(size: 10))
                        .foregroundStyle(.tertiary)
                }
            }

            Spacer()

            Button(action: model.requestServerRefresh) {
                Image(systemName: "arrow.clockwise")
                    .font(.system(size: 12, weight: .medium))
            }
            .buttonStyle(IconButtonStyle())
            .help("Klausti serverio dabar")

            SettingsMenu(model: model, settings: settings)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
        .focusEffectDisabled()
    }
}

// MARK: - Pirmas paleidimas: prijungimas prie Claude Code

private struct ConnectView: View {
    @ObservedObject var model: UsageViewModel
    @State private var error: String?

    var body: some View {
        VStack(spacing: 12) {
            Image(systemName: "link.badge.plus")
                .font(.system(size: 26, weight: .light))
                .foregroundStyle(.secondary)

            Text("Dar neprijungta prie Claude Code")
                .font(.system(size: 13, weight: .medium))

            Text(
                "Kad matytum limitus, POM reikia prisikabinti prie Claude Code būsenos juostos. "
                    + "Tai vienas veiksmas, o senoji juosta išsaugoma atsargai."
            )
            .font(.system(size: 11))
            .foregroundStyle(.secondary)
            .multilineTextAlignment(.center)
            .fixedSize(horizontal: false, vertical: true)

            Button {
                Task { error = await model.connectToClaudeCode() }
            } label: {
                if model.isConnecting {
                    Text("Jungiamasi…")
                } else {
                    Text("Prijungti")
                }
            }
            .buttonStyle(.borderedProminent)
            .keyboardShortcut(.defaultAction)
            .disabled(model.isConnecting)

            if let error {
                Text(error)
                    .font(.system(size: 10))
                    .foregroundStyle(.red)
                    .multilineTextAlignment(.center)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .padding(.horizontal, 24)
        .padding(.vertical, 22)
    }
}

// MARK: - Vieno limito eilutė

private struct WindowRow: View {
    let title: String
    let window: DisplayWindow
    let now: Date

    var body: some View {
        VStack(alignment: .leading, spacing: 9) {
            HStack(alignment: .firstTextBaseline, spacing: 6) {
                Text(title)
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(.secondary)

                Spacer()

                Text("\(Int(window.usedPercentage.rounded()))")
                    .font(.system(size: 26, weight: .semibold, design: .rounded))
                    .monospacedDigit()
                    .foregroundStyle(Theme.color(for: window.level))
                    .contentTransition(.numericText())
                Text("%")
                    .font(.system(size: 13, weight: .medium))
                    .foregroundStyle(.secondary)
            }

            bar

            HStack(spacing: 6) {
                Text("liko \(Int(window.remainingPercentage.rounded())) %")
                Spacer()
                Text(resetText)
            }
            .font(.system(size: 11))
            .foregroundStyle(.secondary)
        }
        .animation(.spring(response: 0.5, dampingFraction: 0.85), value: window.usedPercentage)
    }

    private var bar: some View {
        GeometryReader { geometry in
            ZStack(alignment: .leading) {
                Capsule().fill(Theme.track)
                if window.fraction > 0 {
                    Capsule()
                        .fill(Theme.gradient(for: window.level))
                        .frame(width: max(9, geometry.size.width * window.fraction))
                        .shadow(
                            color: Theme.color(for: window.level).opacity(0.35), radius: 4, y: 1)
                }
            }
        }
        .frame(height: 9)
    }

    private var resetText: String {
        if window.didReset { return "limitas atsistatė" }
        guard let resetsAt = window.resetsAt else { return "atsistatymo laikas nežinomas" }
        return "atsistato " + LTFormat.countdown(to: resetsAt, now: now)
    }
}

// MARK: - Nustatymų meniu

private struct SettingsMenu: View {
    @ObservedObject var model: UsageViewModel
    @ObservedObject var settings: Settings

    var body: some View {
        Menu {
            Toggle("Ikonoje rodyti, kiek liko", isOn: $settings.showRemaining)
            Toggle("Perspėti apie besibaigiantį limitą", isOn: $settings.notificationsEnabled)

            Picker("Perspėti", selection: $settings.alertPreset) {
                ForEach(AlertPreset.allCases) { preset in
                    Text(preset.title).tag(preset)
                }
            }
            .disabled(!settings.notificationsEnabled)

            Divider()

            Toggle("Klausti serverio, kai duomenys pasenę", isOn: $settings.serverFallbackEnabled)
            Toggle("Paleisti prisijungus prie kompiuterio", isOn: $settings.launchAtLogin)

            if let warning = settings.launchAtLoginError ?? model.notifications.statusNote {
                Divider()
                Text(warning)
            }

            Divider()

            Button("Baigti POM darbą") { NSApplication.shared.terminate(nil) }
        } label: {
            Image(systemName: "gearshape")
                .font(.system(size: 12, weight: .medium))
        }
        .menuStyle(.borderlessButton)
        .menuIndicator(.hidden)
        .frame(width: 26)
    }
}

// MARK: - Mygtuko stilius

private struct IconButtonStyle: ButtonStyle {
    @State private var hovering = false

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .foregroundStyle(.secondary)
            .frame(width: 26, height: 22)
            .background(
                RoundedRectangle(cornerRadius: 6, style: .continuous)
                    .fill(Color.primary.opacity(configuration.isPressed ? 0.12 : (hovering ? 0.07 : 0)))
            )
            .onHover { hovering = $0 }
    }
}
