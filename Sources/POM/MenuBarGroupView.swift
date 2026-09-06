import POMCore
import SwiftUI

struct MenuBarEntry: Identifiable {
    let source: MenuBarSource
    let windows: [DisplayWindow]
    let hasData: Bool
    var id: MenuBarSource { source }
}

struct MenuBarGroupView: View {
    let entries: [MenuBarEntry]
    let showRemaining: Bool
    static func width(count: Int) -> CGFloat { CGFloat(count) * MenuBarLabelView.width + CGFloat(max(0, count - 1)) * 8 }
    var body: some View {
        HStack(spacing: 8) {
            ForEach(entries) { entry in
                MenuBarLabelView(source: entry.source, windows: entry.windows,
                                 showRemaining: showRemaining, hasData: entry.hasData)
            }
        }
        .frame(width: Self.width(count: entries.count), height: MenuBarLabelView.height)
    }
}
