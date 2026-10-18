import SwiftUI

/// Viena plati pagrindinė kortelė ir glaudžiai sudėtos mažesnės kortelės.
/// Nelyginė paskutinė kortelė užima visą eilutę, todėl tuščių langelių nelieka.
struct UsageBentoGrid<Card: View>: View {
    let sources: [MenuBarSource]
    @ViewBuilder var card: (MenuBarSource, Bool, Bool) -> Card
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Namespace private var positions

    var body: some View {
        BentoCardLayout {
            ForEach(sources) { source in
                let featured = source == sources.first
                let wide = featured || (sources.count.isMultiple(of: 2) && source == sources.last)
                tile(source, featured: featured, wide: wide)
            }
        }
        .frame(maxWidth: .infinity)
        .animation(reduceMotion ? nil : .spring(response: 0.4, dampingFraction: 0.88), value: sources)
    }

    private func tile(_ source: MenuBarSource, featured: Bool = false, wide: Bool = false) -> some View {
        card(source, featured, wide)
            .providerCard(featured: featured)
            .frame(width: wide ? 712 : 350)
            .matchedGeometryEffect(id: source, in: positions)
            .transition(.opacity.combined(with: .scale(scale: reduceMotion ? 1 : 0.97)))
            .accessibilityElement(children: .contain)
            .accessibilityIdentifier("usage-card-\(source.rawValue)")
    }
}

/// Matuojamas tikras kortelių turinys. Pagrindinės kortelės plotas visada didžiausias,
/// net jei kitoje kortelėje atsiranda ilgesnis prisijungimo ar klaidos paaiškinimas.
struct BentoCardLayout: Layout {
    static let width: CGFloat = 712
    static let gap: CGFloat = 12
    static let column: CGFloat = 350

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let frames = measuredFrames(subviews)
        return CGSize(width: Self.width, height: frames.map(\.maxY).max() ?? 0)
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        for (index, frame) in measuredFrames(subviews).enumerated() {
            subviews[index].place(at: CGPoint(x: bounds.minX + frame.minX, y: bounds.minY + frame.minY),
                                  anchor: .topLeading, proposal: ProposedViewSize(frame.size))
        }
    }

    private func measuredFrames(_ subviews: Subviews) -> [CGRect] {
        Self.frames(heights: subviews.indices.map { index in
            let wide = index == 0 || (subviews.count.isMultiple(of: 2) && index == subviews.count - 1)
            return subviews[index].sizeThatFits(.init(width: wide ? Self.width : Self.column, height: nil)).height
        })
    }

    static func frames(heights: [CGFloat]) -> [CGRect] {
        guard let firstHeight = heights.first else { return [] }
        var others: [CGRect] = []
        var y: CGFloat = 0
        var index = 1
        while index < heights.count {
            let single = index == heights.count - 1
            let rowHeight = single ? heights[index] : max(heights[index], heights[index + 1])
            others.append(CGRect(x: 0, y: y, width: single ? width : column, height: rowHeight))
            if !single { others.append(CGRect(x: column + gap, y: y, width: column, height: rowHeight)) }
            y += rowHeight + gap
            index += 2
        }
        let largestArea = others.map { $0.width * $0.height }.max() ?? 0
        let featuredHeight = max(firstHeight, largestArea / width + gap)
        return [CGRect(x: 0, y: 0, width: width, height: featuredHeight)]
            + others.map { $0.offsetBy(dx: 0, dy: featuredHeight + gap) }
    }
}

/// Nežinomi ir pasibaigę rodmenys gauna nil. Lygybės išlaiko šaltinių eilę.
enum UsageBentoOrder {
    static func sorted(_ sources: [MenuBarSource], usage: [MenuBarSource: Double],
                       pinned: MenuBarSource? = nil) -> [MenuBarSource] {
        sources.enumerated().sorted { lhs, rhs in
            if lhs.element == pinned { return rhs.element != pinned }
            if rhs.element == pinned { return false }
            switch (usage[lhs.element], usage[rhs.element]) {
            case let (left?, right?) where left != right: return left > right
            case (_?, nil): return true
            case (nil, _?): return false
            default: return lhs.offset < rhs.offset
            }
        }.map(\.element)
    }
}

extension View {
    func providerCard(featured: Bool = false) -> some View {
        self
            .fixedSize(horizontal: false, vertical: true)
            .frame(maxWidth: .infinity, minHeight: featured ? 152 : nil,
                   maxHeight: .infinity, alignment: .topLeading)
            .padding(14)
            .background(featured ? Color.accentColor.opacity(0.035) : Color.primary.opacity(0.025),
                        in: RoundedRectangle(cornerRadius: 12))
            .overlay {
                RoundedRectangle(cornerRadius: 12)
                    .strokeBorder(featured ? Color.accentColor.opacity(0.18) : Color.primary.opacity(0.07), lineWidth: 1)
            }
    }
}
