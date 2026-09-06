import SwiftUI

/// Pirmas paleidimas: POM dar neprikabinta prie Claude Code būsenos juostos.
struct ConnectView: View {
    @ObservedObject var model: UsageViewModel
    @ObservedObject private var settings: Settings
    var compact = false
    @State private var error: String?

    init(model: UsageViewModel, compact: Bool = false) {
        self.model = model; self.settings = model.settings; self.compact = compact
    }

    var body: some View {
        VStack(spacing: 12) {
            if !compact {
                Image(systemName: "link.badge.plus")
                    .font(.system(size: 26, weight: .light))
                    .foregroundStyle(.secondary)

                Text(settings.text("Dar neprijungta prie Claude Code", "Connect the Claude Code status line"))
                    .font(.system(size: 13, weight: .medium))

                Text(
                    settings.text("Būsenos juosta papildomai atnaujina bendrus limitus dirbant su Claude Code. Senoji juosta išsaugoma atsargai.", "The status line also updates usage while you work in Claude Code. Your existing status line is backed up.")
                )
                .font(.system(size: 11))
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)
            }

            Button {
                Task { error = await model.connectToClaudeCode() }
            } label: {
                if model.isConnecting {
                    Text(settings.text("Jungiamasi…", "Connecting…"))
                } else {
                    Text(settings.text("Prijungti", "Connect"))
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
        .padding(.vertical, compact ? 0 : 14)
    }
}
