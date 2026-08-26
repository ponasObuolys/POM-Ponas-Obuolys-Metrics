import SwiftUI

/// Pirmas paleidimas: POM dar neprikabinta prie Claude Code būsenos juostos.
struct ConnectView: View {
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
        .padding(.horizontal, 6)
        .padding(.vertical, 14)
    }
}
