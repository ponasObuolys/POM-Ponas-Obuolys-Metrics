import AppKit
import POMCore
import SwiftUI

/// Spalvos parinktos taip, kad vienodai skaitytųsi ir šviesioje, ir tamsioje aplinkoje.
enum Theme {
    static func color(for level: UsageLevel) -> Color {
        switch level {
        case .normal:
            return dynamic(light: rgb(0.11, 0.60, 0.36), dark: rgb(0.29, 0.84, 0.55))
        case .warning:
            return dynamic(light: rgb(0.80, 0.51, 0.04), dark: rgb(0.98, 0.75, 0.25))
        case .critical:
            return dynamic(light: rgb(0.80, 0.18, 0.20), dark: rgb(1.00, 0.42, 0.40))
        }
    }

    static func gradient(for level: UsageLevel) -> LinearGradient {
        let base = color(for: level)
        return LinearGradient(
            colors: [base.opacity(0.78), base],
            startPoint: .leading,
            endPoint: .trailing
        )
    }

    static var track: Color {
        dynamic(light: rgb(0.09, 0.11, 0.13, alpha: 0.10), dark: rgb(1, 1, 1, alpha: 0.14))
    }

    static func freshnessColor(_ freshness: Freshness) -> Color {
        switch freshness {
        case .live: return dynamic(light: rgb(0.11, 0.60, 0.36), dark: rgb(0.29, 0.84, 0.55))
        case .recent: return dynamic(light: rgb(0.45, 0.50, 0.55), dark: rgb(0.62, 0.67, 0.72))
        case .stale: return dynamic(light: rgb(0.80, 0.51, 0.04), dark: rgb(0.98, 0.75, 0.25))
        case .none: return dynamic(light: rgb(0.62, 0.64, 0.66), dark: rgb(0.45, 0.47, 0.50))
        }
    }

    static func freshnessLabel(_ freshness: Freshness) -> String {
        switch freshness {
        case .live: return "gyva"
        case .recent: return "neseniai"
        case .stale: return "pasenę"
        case .none: return "nėra duomenų"
        }
    }

    // MARK: - Pagalbinės

    private static func rgb(_ r: Double, _ g: Double, _ b: Double, alpha: Double = 1) -> NSColor {
        NSColor(srgbRed: r, green: g, blue: b, alpha: alpha)
    }

    private static func dynamic(light: NSColor, dark: NSColor) -> Color {
        Color(
            nsColor: NSColor(name: nil) { appearance in
                appearance.bestMatch(from: [.aqua, .darkAqua]) == .darkAqua ? dark : light
            })
    }
}
