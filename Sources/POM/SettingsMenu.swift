import AppKit
import SwiftUI
import POMCore

/// Nustatymų meniu apatiniame langelio kampe.
struct SettingsMenu: View {
    @ObservedObject var model: UsageViewModel
    @ObservedObject var codex: CodexViewModel
    @ObservedObject var settings: Settings
    var updater: UpdateService? = nil

    var body: some View {
        Menu {
            Menu(settings.text("Meniu juostoje rodyti", "Show in menu bar")) {
                ForEach(MenuBarSource.allCases) { source in
                    Toggle(source.title, isOn: Binding(
                        get: { settings.menuBarSources.contains(source) },
                        set: { settings.setSource(source, enabled: $0) }))
                        .disabled(settings.menuBarSources == [source]
                                  || (source == .codex && !codex.isPresent && !settings.menuBarSources.contains(source)))
                }
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
