import POMCore
import SwiftUI

struct AdditionalUsageSections: View {
    @ObservedObject var model: AdditionalUsageViewModel
    @ObservedObject var settings: Settings

    var body: some View {
        VStack(spacing: 12) {
            if model.cursorPresent || settings.cursorMetricsEnabled {
                AdditionalUsageCard(model: model, settings: settings, source: .cursor).providerCard()
            }
            if model.grokBotPresent {
                AdditionalUsageCard(model: model, settings: settings, source: .grokBot).providerCard()
            }
        }
    }
}

struct AdditionalUsageCard: View {
    @ObservedObject var model: AdditionalUsageViewModel
    @ObservedObject var settings: Settings
    let source: MenuBarSource
    var featured = false
    var wide = false

    var body: some View {
        VStack(alignment: .leading, spacing: featured ? 12 : 10) {
            let snapshot = model.snapshot(for: source)
            SectionHeader(source: source,
                          freshness: UsageDisplay.freshness(capturedAt: snapshot?.capturedAt, now: model.now),
                          detail: snapshot.map { settings.language.age(from: $0.capturedAt, now: model.now) } ?? "",
                          plan: snapshot?.planName, pinSettings: settings)
            if let snapshot {
                let layout = wide ? AnyLayout(HStackLayout(alignment: .top, spacing: 20))
                    : AnyLayout(VStackLayout(alignment: .leading, spacing: 10))
                layout {
                    ForEach(Array(snapshot.meters.enumerated()), id: \.offset) { _, meter in
                        WindowRow(title: title(meter.kind), window: UsageDisplay.resolve(meter.window, now: model.now),
                                  now: model.now, language: settings.language, prominent: featured)
                            .frame(maxWidth: .infinity)
                    }
                }
                if let spend = snapshot.onDemand {
                    HStack {
                        Text(settings.text("Papildomas naudojimas", "On-demand usage"))
                        Spacer()
                        Text(spendText(spend))
                            .monospacedDigit()
                    }
                    .font(.system(size: 11)).foregroundStyle(.secondary)
                }
            }
            if source == .cursor {
                cursorStatus
            } else if model.grokBot == nil {
                Text(settings.text("Atverk Grok Bot paskyros meniu arba Usage & Billing. POM laukia tos programos išsaugotos naudojimo suvestinės.",
                                   "Open the Grok Bot account menu or Usage & Billing. POM is waiting for the usage summary saved by that app."))
                    .font(.system(size: 11)).foregroundStyle(.secondary)
            } else {
                Label(settings.text("Vietinė Grok Bot suvestinė", "Local Grok Bot summary"), systemImage: "internaldrive")
                    .font(.system(size: 10)).foregroundStyle(.secondary)
                    .help(settings.text("Naujausius duomenis išsaugo pati Grok Bot programa; POM jos serverio neklausia.",
                                        "Grok Bot refreshes these readings; POM does not query its server."))
            }
        }
    }

    @ViewBuilder
    private var cursorStatus: some View {
        if !settings.cursorMetricsEnabled {
            Text(settings.text("Įjungus POM nuskaitys esamą Cursor prisijungimą šiame Mac ir juo klaus naudojimo limitų Cursor serveryje. Prisijungimo raktas neišsaugomas.",
                               "When enabled, POM reads your existing Cursor sign-in on this Mac and uses it to request usage limits from Cursor. The session token is not saved."))
                .font(.system(size: 11)).foregroundStyle(.secondary)
            Button(settings.text("Įjungti Cursor metrikas", "Enable Cursor metrics")) {
                settings.cursorMetricsEnabled = true
                model.refreshNow(manual: true)
            }.controlSize(.small)
        } else if model.isFetchingCursor && model.cursor == nil {
            ProgressView(settings.text("Gaunami Cursor limitai…", "Fetching Cursor usage…"))
                .controlSize(.small).font(.system(size: 11))
        } else if let error = model.cursorError {
            Text(cursorError(error)).font(.system(size: 11)).foregroundStyle(.orange)
        } else if model.cursor == nil {
            Text(settings.text("Cursor naudojimo duomenų dar nėra.", "No Cursor usage readings yet."))
                .font(.system(size: 11)).foregroundStyle(.secondary)
        }
    }

    private func title(_ kind: ProviderUsageSnapshot.Meter.Kind) -> String {
        switch kind {
        case .included: return settings.text("Plano naudojimas", "Included usage")
        case .auto: return "Auto"
        case .api: return settings.text("Kiti modeliai", "Other models")
        case .weekly: return settings.text("Savaitės naudojimas", "Weekly usage")
        }
    }

    private func cursorError(_ error: CursorClient.ClientError) -> String {
        switch error {
        case .signedOut: return settings.text("Prisijunk prie Cursor programos ir atnaujink POM.", "Sign in to the Cursor app, then refresh POM.")
        case .invalidResponse: return settings.text("Cursor nepateikė atpažįstamos naudojimo suvestinės. Paskyrų ir planų formatai gali skirtis.", "Cursor did not return a recognized usage summary. Account and plan formats may differ.")
        case .rateLimited: return settings.text("Cursor laikinai riboja užklausas. POM vėliau bandys dar kartą.", "Cursor is limiting requests. POM will try again later.")
        case .unavailable: return settings.text("Nepavyko atnaujinti Cursor limitų. Jei yra ankstesnių duomenų, rodomas jų gavimo laikas.", "Could not refresh Cursor usage. Previous readings show their original update time.")
        }
    }

    private func spendText(_ spend: ProviderUsageSnapshot.Spend) -> String {
        let used = (spend.usedCents / 100).formatted(.currency(code: "USD").locale(settings.locale))
        guard let limit = spend.limitCents else { return used }
        return used + " / " + (limit / 100).formatted(.currency(code: "USD").locale(settings.locale))
    }
}
