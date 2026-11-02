import SwiftUI

private struct ContentHeightKey: PreferenceKey {
    static var defaultValue: CGFloat = 0
    static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) { value = max(value, nextValue()) }
}

/// A scroll view that adopts its content's height until the available screen budget is reached.
struct ContentHeightScrollView<Content: View>: View {
    let maximumHeight: CGFloat
    @ViewBuilder var content: () -> Content
    @State private var contentHeight: CGFloat = 1

    var body: some View {
        ScrollView {
            content()
                .fixedSize(horizontal: false, vertical: true)
                .background(GeometryReader { geometry in
                    Color.clear.preference(key: ContentHeightKey.self, value: geometry.size.height)
                })
        }
        .frame(height: min(maximumHeight, max(1, contentHeight)))
        .onPreferenceChange(ContentHeightKey.self) { height in
            if abs(height - contentHeight) > 0.5 { contentHeight = height }
        }
    }
}
