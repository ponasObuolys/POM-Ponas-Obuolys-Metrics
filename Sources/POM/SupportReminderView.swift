import AppKit
import POMCore
import SwiftUI

struct SupportReminderView: View {
    @ObservedObject var settings: Settings
    let occasion: SupportReminderPolicy.Occasion
    let version: String
    var dismiss: () -> Void
    @State private var openFailed = false

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            HStack(spacing: 12) {
                Image(systemName: "heart.fill")
                    .font(.system(size: 22))
                    .foregroundStyle(.pink)
                    .frame(width: 48, height: 48)
                    .background(Color.pink.opacity(0.1), in: RoundedRectangle(cornerRadius: 14))
                    .accessibilityHidden(true)
                VStack(alignment: .leading, spacing: 4) {
                    Text("POM \(version)").font(.system(size: 13, weight: .semibold))
                    Text(occasion == .update
                         ? settings.text("Programa atnaujinta", "Your app is up to date")
                         : settings.text("POM jau tavo meniu juostoje", "POM is ready in your menu bar"))
                        .font(.system(size: 12)).foregroundStyle(.secondary)
                }
            }
            VStack(alignment: .leading, spacing: 10) {
                Text(settings.text("Prisidėk prie POM kūrimo", "Support POM development"))
                    .font(.system(size: 24, weight: .bold))
                Text(settings.text(
                    "POM nemokama ir atvirojo kodo. Jei ji tau naudinga, gali prisidėti prie jos kūrimo vienkartine parama.",
                    "POM is free and open source. If you find it useful, you can support its development with a one-time contribution."))
                    .font(.system(size: 13)).foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
                Text(settings.text("Siūlomi 5 €. Sumą pasirenki pats.", "€5 suggested. Choose your own amount."))
                    .font(.system(size: 12, weight: .medium))
            }
            HStack(spacing: 10) {
                Button(action: openSupport) {
                    Label(settings.text("Paremti POM", "Support POM"), systemImage: "heart")
                }.buttonStyle(.borderedProminent)
                Button(settings.text("Gal vėliau", "Not now"), action: dismiss)
                    .keyboardShortcut(.cancelAction)
            }
            if openFailed {
                Text(settings.text("Nepavyko atverti naršyklės. Bandyk dar kartą.", "Could not open your browser. Please try again."))
                    .font(.system(size: 12)).foregroundStyle(.red)
            }
            Divider()
            Text(settings.text("POM gali naudoti nemokamai, nepriklausomai nuo paramos.", "All POM features remain free, whether you contribute or not."))
                .font(.system(size: 11)).foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(24)
        .frame(width: 410)
        .environment(\.locale, settings.locale)
    }

    private func openSupport() {
        if NSWorkspace.shared.open(ProjectLinks.support) { dismiss() }
        else { openFailed = true }
    }
}
