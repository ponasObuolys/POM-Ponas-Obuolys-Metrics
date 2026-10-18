import POMCore
import SwiftUI

struct ExtraUsageDisclosure: View {
    @ObservedObject var settings: Settings
    var claude: ClaudeExtraUsage?
    var codex: CodexAdditionalUsage?
    var capturedAt: Date?
    @State private var showingDetails = false
    var body: some View {
        Button { showingDetails.toggle() } label: {
            HStack(spacing: 6) {
                Label(settings.text("Papildomas naudojimas", "Extra usage"), systemImage: "creditcard")
                Spacer(minLength: 6)
                Text(summary).foregroundStyle(.secondary)
                Image(systemName: "chevron.right").font(.system(size: 8, weight: .semibold))
                    .foregroundStyle(.tertiary)
            }
            .font(.system(size: 11))
        }
        .buttonStyle(.plain)
        .help(settings.text("Rodyti kreditų ir išlaidų informaciją", "Show credit and spending details"))
        .popover(isPresented: $showingDetails) {
            ExtraUsageView(settings: settings, claude: claude, codex: codex, capturedAt: capturedAt)
                .frame(width: 320).padding(8)
                .environment(\.locale, settings.locale)
        }
    }
    private var summary: String {
        if let claude {
            if !claude.enabled { return settings.text("Išjungta", "Disabled") }
            if let percent = claude.percentage { return "\(Int(percent.rounded()))%" }
            return settings.text("Įjungta", "Enabled")
        }
        if let credits = codex?.credits {
            if credits.unlimited { return settings.text("Neribojama", "Unlimited") }
            if let balance = credits.balance { return balance + settings.text(" kr.", " credits") }
        }
        if let count = codex?.resetCredits { return settings.text("Atkūrimų: \(count)", "Resets: \(count)") }
        return settings.text("Nepateikta", "Not reported")
    }
}

struct ExtraUsageView: View {
    @ObservedObject var settings: Settings
    var claude: ClaudeExtraUsage?
    var codex: CodexAdditionalUsage?
    var capturedAt: Date?

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Label(settings.text("Papildomas naudojimas", "Extra usage"), systemImage: "creditcard")
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(.secondary)
            if let claude {
                if !claude.enabled {
                    row(settings.text("Būsena", "Status"), settings.text("Išjungta", "Disabled"))
                } else {
                    if let percent = claude.percentage {
                        ProgressView(value: min(100, percent), total: 100).tint(.orange)
                        row(settings.text("Mėnesio limito sunaudota", "Monthly limit used"), "\(Int(percent.rounded()))%")
                    }
                    if let used = money(claude.used, extra: claude) { row(settings.text("Sunaudota", "Spent"), used) }
                    if let limit = money(claude.limit, extra: claude) { row(settings.text("Mėnesio limitas", "Monthly limit"), limit) }
                    if claude.limitReached == true { Text(settings.text("Išlaidų limitas pasiektas", "Spending limit reached")).foregroundStyle(.orange) }
                    if claude.percentage == nil && money(claude.used, extra: claude) == nil {
                        Text(settings.text("Įjungta · sumos nepateiktos", "Enabled · amounts unavailable")).foregroundStyle(.secondary)
                    }
                }
            } else if let codex, codex.isAvailable {
                if let credits = codex.credits {
                    row(settings.text("Kreditų likutis", "Credit balance"), credits.unlimited
                        ? settings.text("Neribojama", "Unlimited")
                        : credits.balance ?? (credits.hasCredits ? settings.text("Yra · suma nepateikta", "Available · amount unknown") : "0"))
                }
                if let cap = codex.spendLimit {
                    ProgressView(value: 100 - cap.remainingPercent, total: 100).tint(.green)
                    row(settings.text("Sunaudota / limitas", "Used / limit"), "\(cap.used) / \(cap.limit)")
                    row(settings.text("Liko", "Remaining"), "\(Int(cap.remainingPercent))%")
                }
                if let count = codex.resetCredits {
                    row(settings.text("Limito atkūrimai", "Limit resets available"), "\(count)")
                    if let expiry = codex.nextResetCreditExpiry {
                        row(settings.text("Artimiausias galiojimas", "Next expiry"), settings.language.absolute(expiry))
                    }
                }
                if codex.spendControlReached == true { Text(settings.text("Išlaidų limitas pasiektas", "Spending limit reached")).foregroundStyle(.orange) }
            } else {
                Text(settings.text("Šaltinis kreditų duomenų nepateikė.", "Credit details were not provided by the source."))
                    .foregroundStyle(.secondary)
            }
            if let capturedAt {
                Text(settings.language.age(from: capturedAt, now: Date()))
                    .font(.system(size: 10)).foregroundStyle(.tertiary)
            }
        }
        .font(.system(size: 11))
        .padding(11)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.primary.opacity(0.035), in: RoundedRectangle(cornerRadius: 10))
    }

    private func row(_ title: String, _ value: String) -> some View {
        HStack(alignment: .firstTextBaseline) {
            Text(title).foregroundStyle(.secondary)
            Spacer(minLength: 8)
            Text(value).fontWeight(.medium).multilineTextAlignment(.trailing).textSelection(.enabled)
        }
    }

    private func money(_ raw: Double?, extra: ClaudeExtraUsage) -> String? {
        guard let raw, let scale = extra.decimalPlaces, let currency = extra.currency, currency.count == 3 else { return nil }
        let formatter = NumberFormatter(); formatter.locale = settings.locale
        formatter.numberStyle = .currency; formatter.currencyCode = currency.uppercased()
        return formatter.string(from: NSNumber(value: raw / pow(10, Double(scale))))
    }
}
