import POMCore
import SwiftUI

/// Ikona prie laikrodžio: dvi juostelės viena virš kitos.
/// Viršutinė – 5 valandų limitas, apatinė – 7 dienų.
struct MenuBarLabelView: View {
    let fiveHour: DisplayWindow
    let sevenDay: DisplayWindow
    let showRemaining: Bool
    let hasData: Bool

    private let barWidth: CGFloat = 20
    private let barHeight: CGFloat = 3.5
    private let numberWidth: CGFloat = 27

    static let width: CGFloat = 53
    static let height: CGFloat = 22

    var body: some View {
        VStack(alignment: .leading, spacing: 3) {
            row(fiveHour)
            row(sevenDay)
        }
        .frame(width: Self.width, height: Self.height, alignment: .center)
        .allowsHitTesting(false)
    }

    private func row(_ window: DisplayWindow) -> some View {
        HStack(spacing: 5) {
            ZStack(alignment: .leading) {
                Capsule().fill(Theme.track)
                if hasData && fillFraction(window) > 0 {
                    Capsule()
                        .fill(Theme.gradient(for: window.level))
                        .frame(width: max(2, barWidth * fillFraction(window)))
                }
            }
            .frame(width: barWidth, height: barHeight)

            Text(numberText(window))
                .font(.system(size: 9, weight: .semibold, design: .rounded))
                .monospacedDigit()
                .foregroundStyle(hasData ? Theme.color(for: window.level) : Color.secondary)
                .frame(width: numberWidth, alignment: .leading)
        }
    }

    private func numberText(_ window: DisplayWindow) -> String {
        guard hasData else { return "–" }
        let value = showRemaining ? window.remainingPercentage : window.usedPercentage
        return "\(Int(value.rounded()))%"
    }

    /// Juostelė visada rodo tą patį dydį kaip ir skaičius šalia jos.
    /// Rodant sunaudotą dalį ji pildosi, rodant likutį – tuštėja, kaip degalų matuoklis.
    /// Spalva abiem atvejais imama pagal sunaudotą dalį, kad pavojus būtų matomas vienodai.
    private func fillFraction(_ window: DisplayWindow) -> Double {
        showRemaining ? 1 - window.fraction : window.fraction
    }
}
