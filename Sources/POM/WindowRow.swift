import POMCore
import SwiftUI

/// Vieno limito eilutė: pavadinimas, procentai, juostelė ir atsistatymo laikas.
/// Vienoda ir Claude, ir Codex sekcijoje, kad skaičiai būtų skaitomi tuo pačiu įpročiu.
struct WindowRow: View {
    let title: String
    let window: DisplayWindow
    let now: Date
    var language: AppLanguage = .system
    var prominent = false
    var showRemaining = false
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        VStack(alignment: .leading, spacing: prominent ? 5 : 2) {
            HStack(alignment: .firstTextBaseline, spacing: 6) {
                Text(title)
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(.secondary)

                Spacer()

                Text(showRemaining ? language.text("Liko", "Left") : language.text("Sunaudota", "Used"))
                    .font(.system(size: 10)).foregroundStyle(.secondary).fixedSize()
                Text(window.didReset ? "–" : "\(Int(window.percentage(showRemaining: showRemaining).rounded()))")
                    .font(.system(size: prominent ? 34 : 20, weight: .semibold, design: .rounded))
                    .monospacedDigit()
                    .foregroundStyle(window.didReset ? Color.secondary : Theme.color(for: window.level))
                    .contentTransition(.numericText())
                Text(window.didReset ? "" : "%")
                    .font(.system(size: 13, weight: .medium))
                    .foregroundStyle(.secondary)
            }

            bar

            ViewThatFits(in: .horizontal) {
                HStack(spacing: 6) {
                    Text(resetText)
                    if window.resetsAt != nil && !window.didReset { Text("·") }
                    if let date = window.resetsAt, !window.didReset { Text(language.resetTime(date, now: now)) }
                }.fixedSize(horizontal: true, vertical: false)
                VStack(alignment: .leading, spacing: 2) {
                    Text(resetText)
                    if let date = window.resetsAt, !window.didReset { Text(language.resetTime(date, now: now)) }
                }
            }
            .font(.system(size: 11))
            .foregroundStyle(.secondary)
            .help(window.resetsAt.map { language.fullResetTime($0) } ?? resetText)
        }
        .animation(reduceMotion ? nil : .spring(response: 0.5, dampingFraction: 0.85), value: window.usedPercentage)
    }

    private var displayFraction: Double { window.fillFraction(showRemaining: showRemaining) }

    private var bar: some View {
        GeometryReader { geometry in
            ZStack(alignment: .leading) {
                Capsule().fill(Theme.track)
                if !window.didReset && displayFraction > 0 {
                    Capsule()
                        .fill(Theme.gradient(for: window.level))
                        .frame(width: max(9, geometry.size.width * displayFraction))
                        .shadow(
                            color: Theme.color(for: window.level).opacity(0.35), radius: 4, y: 1)
                }
            }
        }
        .frame(height: prominent ? 6 : 5)
    }

    private var resetText: String {
        if window.didReset { return language.text("laukiama naujų duomenų", "waiting for new data") }
        guard let resetsAt = window.resetsAt else { return language.text("atsistatymo laikas nežinomas", "reset time unknown") }
        return language.text("atsistato ", "resets ") + language.countdown(to: resetsAt, now: now)
    }
}

/// Sekcijos antraštė su šviežumo žyma. Kiekviena sekcija turi savo, nes Claude ir Codex
/// duomenys ateina skirtingu metu ir vienas gali būti šviežias, kai kitas jau pasenęs.
struct SectionHeader: View {
    let source: MenuBarSource
    let freshness: Freshness
    let detail: String
    var plan: String? = nil
    var pinSettings: Settings? = nil
    @Environment(\.providerStatus) private var status
    @State private var showingStatus = false

    var body: some View {
        HStack(spacing: 8) {
            ProviderMarkView(source: source)
                .frame(width: 16, height: 16)
                .accessibilityHidden(true)
            Text(source.title.uppercased())
                .font(.system(size: 11, weight: .semibold))
                .kerning(0.6)
                .foregroundStyle(.secondary)
                .lineLimit(1)

            if let plan {
                Text(plan)
                    .font(.system(size: 10, weight: .medium))
                    .lineLimit(1)
                    .help(plan)
                    .foregroundStyle(.secondary)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 3)
                    .background(Color.primary.opacity(0.05), in: Capsule())
            }

            Spacer()

            Button { showingStatus.toggle() } label: {
                HStack(spacing: 4) {
                    if status.busy { ProgressView().controlSize(.mini) }
                    else { Circle().fill(Theme.freshnessColor(freshness)).frame(width: 6, height: 6) }
                    Text(detail.isEmpty ? "—" : detail).font(.system(size: 10)).foregroundStyle(.tertiary)
                }
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .accessibilityLabel(status.language.text("Duomenų būsena", "Data status"))
            .popover(isPresented: $showingStatus) { ProviderStatusView(status: status, freshness: freshness) }
            if let pinSettings, pinSettings.panelOrder == .automatic { ProviderPinButton(source: source, settings: pinSettings) }
        }
    }
}

struct ProviderPinButton: View {
    let source: MenuBarSource
    @ObservedObject var settings: Settings
    private var pinned: Bool { settings.pinnedSource == source }

    var body: some View {
        Button { settings.togglePin(source) } label: {
            Image(systemName: pinned ? "pin.fill" : "pin")
                .font(.system(size: 11, weight: .medium))
                .foregroundStyle(pinned ? Color.accentColor : Color.secondary)
                .frame(width: 24, height: 20)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel(pinned ? settings.text("Atsegti \(source.title)", "Unpin \(source.title)")
                            : settings.text("Prisegti \(source.title) kaip didžiausią kortelę", "Pin \(source.title) as the largest card"))
        .help(pinned ? settings.text("Atsegti ir grįžti prie automatinio išdėstymo", "Unpin and restore automatic ordering")
              : settings.text("Šią kortelę visada rodyti didžiausią. Prisegti galima tik vieną.", "Always show this card largest. Only one card can be pinned."))
    }
}
