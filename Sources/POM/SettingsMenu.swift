import AppKit
import SwiftUI

/// Nustatymų meniu apatiniame langelio kampe.
struct SettingsMenu: View {
    @ObservedObject var model: UsageViewModel
    @ObservedObject var codex: CodexViewModel
    @ObservedObject var settings: Settings

    var body: some View {
        Menu {
            // Rodyti pasirinkimą, kai Codex kompiuteryje nėra, būtų tuščias pažadas:
            // ikona vis tiek liktų su Claude skaičiais.
            if codex.isPresent {
                Picker("Ikonoje rodyti", selection: $settings.menuBarSource) {
                    ForEach(MenuBarSource.allCases) { source in
                        Text(source.title).tag(source)
                    }
                }
                Divider()
            }

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
