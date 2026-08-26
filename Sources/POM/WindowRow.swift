import POMCore
import SwiftUI

/// Vieno limito eilutė: pavadinimas, procentai, juostelė ir atsistatymo laikas.
/// Vienoda ir Claude, ir Codex sekcijoje, kad skaičiai būtų skaitomi tuo pačiu įpročiu.
struct WindowRow: View {
    let title: String
    let window: DisplayWindow
    let now: Date

    var body: some View {
        VStack(alignment: .leading, spacing: 9) {
            HStack(alignment: .firstTextBaseline, spacing: 6) {
                Text(title)
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(.secondary)

                Spacer()

                Text("\(Int(window.usedPercentage.rounded()))")
                    .font(.system(size: 26, weight: .semibold, design: .rounded))
                    .monospacedDigit()
                    .foregroundStyle(Theme.color(for: window.level))
                    .contentTransition(.numericText())
                Text("%")
                    .font(.system(size: 13, weight: .medium))
                    .foregroundStyle(.secondary)
            }

            bar

            HStack(spacing: 6) {
                Text("liko \(Int(window.remainingPercentage.rounded())) %")
                Spacer()
                Text(resetText)
            }
            .font(.system(size: 11))
            .foregroundStyle(.secondary)
        }
        .animation(.spring(response: 0.5, dampingFraction: 0.85), value: window.usedPercentage)
    }

    private var bar: some View {
        GeometryReader { geometry in
            ZStack(alignment: .leading) {
                Capsule().fill(Theme.track)
                if window.fraction > 0 {
                    Capsule()
                        .fill(Theme.gradient(for: window.level))
                        .frame(width: max(9, geometry.size.width * window.fraction))
                        .shadow(
                            color: Theme.color(for: window.level).opacity(0.35), radius: 4, y: 1)
                }
            }
        }
        .frame(height: 9)
    }

    private var resetText: String {
        if window.didReset { return "limitas atsistatė" }
        guard let resetsAt = window.resetsAt else { return "atsistatymo laikas nežinomas" }
        return "atsistato " + LTFormat.countdown(to: resetsAt, now: now)
    }
}

/// Sekcijos antraštė su šviežumo žyma. Kiekviena sekcija turi savo, nes Claude ir Codex
/// duomenys ateina skirtingu metu ir vienas gali būti šviežias, kai kitas jau pasenęs.
struct SectionHeader: View {
    let title: String
    let freshness: Freshness
    let detail: String

    var body: some View {
        HStack(spacing: 8) {
            Text(title)
                .font(.system(size: 11, weight: .semibold))
                .kerning(0.6)
                .foregroundStyle(.secondary)

            Spacer()

            Circle()
                .fill(Theme.freshnessColor(freshness))
                .frame(width: 6, height: 6)
            Text(detail)
                .font(.system(size: 10))
                .foregroundStyle(.tertiary)
        }
    }
}
