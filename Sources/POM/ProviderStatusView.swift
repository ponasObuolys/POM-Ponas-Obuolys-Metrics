import SwiftUI
import POMCore

struct ProviderStatus {
    var language: AppLanguage = .system
    var capturedAt: Date? = nil
    var source = ""
    var note: String? = nil
    var busy = false
    var refresh: () -> Void = {}
    var signIn: (() -> Void)? = nil
}

private struct ProviderStatusKey: EnvironmentKey {
    static let defaultValue = ProviderStatus()
}

extension EnvironmentValues {
    var providerStatus: ProviderStatus {
        get { self[ProviderStatusKey.self] }
        set { self[ProviderStatusKey.self] = newValue }
    }
}

struct ProviderStatusView: View {
    let status: ProviderStatus
    let freshness: Freshness

    private var description: String {
        switch freshness {
        case .live: return status.language.text("Gauti nauji duomenys.", "Fresh readings received.")
        case .recent: return status.language.text("Rodomi neseniai gauti duomenys.", "Showing recent readings.")
        case .stale: return status.language.text("Duomenys pasenę. Rodomi paskutiniai gauti skaičiai.", "Readings are stale. Showing the last received values.")
        case .none: return status.language.text("Duomenų dar nėra.", "No readings yet.")
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(description).font(.system(size: 12, weight: .medium))
            Text(status.source)
            if let date = status.capturedAt { Text(status.language.fullResetTime(date)) }
            if let note = status.note { Text(note) }
            HStack {
                if status.busy {
                    ProgressView().controlSize(.small)
                    Text(status.language.text("Atnaujinama…", "Updating…"))
                }
                Button(status.language.text("Atnaujinti", "Refresh"), action: status.refresh).disabled(status.busy)
                if let signIn = status.signIn {
                    Button(status.language.text("Prisijungti…", "Sign in…"), action: signIn).disabled(status.busy)
                }
            }.controlSize(.small)
        }
        .font(.system(size: 11)).foregroundStyle(.secondary)
        .fixedSize(horizontal: false, vertical: true)
        .padding(16).frame(width: 300)
    }
}

extension AdditionalUsageViewModel {
    func status(for source: MenuBarSource, language: AppLanguage = .system) -> ProviderStatus {
        ProviderStatus(language: language, capturedAt: snapshot(for: source)?.capturedAt,
            source: source == .grokBot ? (grokBotUsesServer ? language.text("Grok Bot · Cursor paskyra · serveris", "Grok Bot · Cursor account · server") : language.text("Vietinė Grok Bot suvestinė", "Local Grok Bot summary"))
                : language.text("Cursor paskyra", "Cursor account"),
            note: source == .grokBot
                ? (grokBotUsesServer
                    ? (grokBotServerError == .signedOut
                       ? language.text("Cursor sesija atmesta. Prisijunk iš naujo Cursor programoje ir atnaujink POM.", "Cursor session rejected. Sign in again in Cursor and refresh POM.")
                       : language.text("Savaitės limitas gaunamas tiesiai iš serverio pagal Cursor paskyrą. Grok Bot paleisti nereikia.", "Weekly quota comes directly from the server for the Cursor account. Grok Bot need not be running."))
                    : language.text("POM perskaito vietinę suvestinę. Naujausius duomenis iš serverio gauna pati Grok Bot programa — atverk jos paskyros meniu arba Usage & Billing.", "POM reads a local summary. Grok Bot itself fetches new server readings — open its account menu or Usage & Billing."))
                : cursorError.map { _ in language.text("Atnaujinti nepavyko. Patikrink prisijungimą Cursor programoje.", "Refresh failed. Check your sign-in in Cursor.") },
            busy: source == .grokBot ? isFetchingGrokBot : isFetchingCursor,
            refresh: { self.refresh(source: source) })
    }
}
