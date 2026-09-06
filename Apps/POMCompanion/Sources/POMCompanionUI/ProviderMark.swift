import SwiftUI

struct ProviderMark: View {
    let claude: Bool
    #if os(macOS)
    private static let anthropic = Bundle.module.url(forResource: "anthropic", withExtension: "png").flatMap(NSImage.init(contentsOf:))
    private static let chatgpt = Bundle.module.url(forResource: "chatgpt", withExtension: "png").flatMap(NSImage.init(contentsOf:))
    #else
    private static let anthropic = Bundle.module.url(forResource: "anthropic", withExtension: "png").flatMap { UIImage(contentsOfFile: $0.path) }
    private static let chatgpt = Bundle.module.url(forResource: "chatgpt", withExtension: "png").flatMap { UIImage(contentsOfFile: $0.path) }
    #endif
    var body: some View {
        Group {
            if let mark = claude ? Self.anthropic : Self.chatgpt {
                #if os(macOS)
                Image(nsImage: mark).renderingMode(.template).resizable().scaledToFit()
                #else
                Image(uiImage: mark).renderingMode(.template).resizable().scaledToFit()
                #endif
            } else {
                Image(systemName: "questionmark.square.dashed")
            }
        }.foregroundStyle(.primary).frame(width: 20, height: 20).accessibilityHidden(true)
    }
}
