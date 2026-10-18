import AppKit
import SwiftUI
import POMCore

/// Nustatymų meniu apatiniame langelio kampe.
struct SettingsMenu: View {
    @ObservedObject var model: UsageViewModel
    @ObservedObject var codex: CodexViewModel
    @ObservedObject var settings: Settings
    @ObservedObject var additional: AdditionalUsageViewModel
    var updater: UpdateService? = nil

    var body: some View {
        Menu {
            Menu(settings.text("Rodomos paslaugos", "Visible services")) {
                ProviderVisibilityOptions(codex: codex, settings: settings, additional: additional)
            }
            Toggle(settings.text("Ikonoje rodyti, kiek liko", "Show remaining usage in menu bar"), isOn: $settings.showRemaining)
            Divider()
            Toggle(settings.text("Perspėti apie besibaigiantį limitą", "Warn when a limit is running low"), isOn: $settings.notificationsEnabled)
            Picker(settings.text("Perspėti", "Alert thresholds"), selection: $settings.alertPreset) {
                ForEach(AlertPreset.allCases) { preset in Text(preset.title(settings.language)).tag(preset) }
            }.disabled(!settings.notificationsEnabled)
            Toggle(settings.text("Pranešti, kai limitas atsistato", "Notify when a limit recovers"), isOn: $settings.recoveryNotifications)
            Divider()
            Picker(settings.text("Kalba", "Language"), selection: $settings.language) {
                Text(settings.text("Pagal sistemą", "System default")).tag(AppLanguage.system)
                Text("Lietuvių").tag(AppLanguage.lt)
                Text("English").tag(AppLanguage.en)
            }
            Toggle(settings.text("Klausti serverio, kai duomenys pasenę", "Use server fallback for stale data"), isOn: $settings.serverFallbackEnabled)
            Toggle(settings.text("Cursor metrikos (esamu prisijungimu)", "Cursor metrics (existing sign-in)"), isOn: $settings.cursorMetricsEnabled)
            Button(settings.text("Prisijungti prie Claude…", "Sign in to Claude…")) {
                Task { await model.signInToClaude() }
            }
            .disabled(model.isSigningIn || !model.canSignInToClaude)
            Button(settings.text("Prisijungti prie ChatGPT…", "Sign in to ChatGPT…")) {
                Task { await codex.signInToChatGPT() }
            }
            .disabled(codex.isSigningIn || !codex.canSignIn)
            Toggle(settings.text("Paleisti prisijungus prie kompiuterio", "Launch at login"), isOn: $settings.launchAtLogin)
            if let updater {
                Divider()
                UpdateMenuItems(updater: updater, settings: settings)
            }

            if let warning = settings.launchAtLoginError ?? model.notifications.statusNote(settings.language) {
                Divider()
                Text(warning)
            }

            Divider()

            Link(destination: ProjectLinks.support) {
                Label(settings.text("Paremti POM…", "Support POM…"), systemImage: "heart")
            }

            Divider()
            Button(settings.text("Baigti POM darbą", "Quit POM")) { NSApplication.shared.terminate(nil) }
        } label: {
            Image(systemName: "gearshape")
                .font(.system(size: 12, weight: .medium))
        }
        .menuStyle(.borderlessButton)
        .menuIndicator(.hidden)
        .frame(width: 26)
    }

}

/// Tie patys jungikliai lango viršuje ir nustatymuose valdo korteles bei indikatorius.
struct ProviderVisibilityOptions: View {
    @ObservedObject var codex: CodexViewModel
    @ObservedObject var settings: Settings
    @ObservedObject var additional: AdditionalUsageViewModel

    var body: some View {
        ForEach(MenuBarSource.allCases) { source in
            Toggle(isOn: Binding(
                get: { settings.menuBarSources.contains(source) },
                set: { settings.setSource(source, enabled: $0) })) {
                    Label {
                        Text(source.title)
                    } icon: {
                        ProviderMarkView(source: source).frame(width: 16, height: 16)
                    }
                }
                .disabled(settings.menuBarSources == [source]
                          || (!isAvailable(source) && !settings.menuBarSources.contains(source)))
        }
    }

    private func isAvailable(_ source: MenuBarSource) -> Bool {
        switch source {
        case .claude, .fable: return true
        case .codex: return codex.isPresent
        case .cursor: return additional.cursorPresent && settings.cursorMetricsEnabled
        case .grokBot: return additional.grokBotPresent
        }
    }
}

/// Apvalus mygtukas be rėmelio, pasišviečiantis užvedus pelę.
struct IconButtonStyle: ButtonStyle {
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

private struct UpdateMenuItems: View {
    @ObservedObject var updater: UpdateService
    @ObservedObject var settings: Settings
    var body: some View {
        Button(settings.text("Ieškoti naujinimų…", "Check for Updates…")) { updater.check() }
            .disabled(!updater.canCheck)
        Toggle(settings.text("Automatiškai ieškoti naujinimų", "Automatically check for updates"), isOn: Binding(
            get: { updater.automaticallyChecks }, set: { updater.setAutomatic($0) }))
            .disabled(!updater.configured)
        if !updater.configured {
            Text(settings.text("Šis kūrimo paketas neturi naujinimų konfigūracijos.", "Updates are not configured in this development build."))
        }
        Text("POM \(Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "dev")")
    }
}
