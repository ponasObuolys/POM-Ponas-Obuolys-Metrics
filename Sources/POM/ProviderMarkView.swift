import SwiftUI

/// Tas pats paslaugos ženklas meniu juostoje ir limitų langelyje.
struct ProviderMarkView: View {
    let source: MenuBarSource

    // Ženklai įkeliami vieną kartą ir supakuojami su programa.
    private static let anthropic = logo(named: "anthropic")
    private static let claude = logo(named: "claude")
    private static let chatGPT = logo(named: "chatgpt")
    private static let cursor = logo(named: "cursor")
    private static let grokBot = logo(named: "grok-bot", extension: "png")

    private static func logo(named name: String, extension suffix: String = "svg") -> NSImage? {
        // Rankomis supakuotoje macOS programoje ištekliai yra Contents/Resources.
        // SwiftPM modulis naudojamas tik paleidžiant iš kodo ar vaizdų patikroje.
        let bundle = Bundle.main.url(forResource: "POM_POM", withExtension: "bundle")
            .flatMap(Bundle.init(url:)) ?? Bundle.module
        guard let url = bundle.url(forResource: name, withExtension: suffix) else { return nil }
        return NSImage(contentsOf: url)
    }

    private var image: NSImage? {
        switch source {
        case .claude: return Self.anthropic
        case .codex: return Self.chatGPT
        case .cursor: return Self.cursor
        case .grokBot: return Self.grokBot
        case .fable: return Self.claude
        }
    }

    var body: some View {
        if let image {
            Image(nsImage: image)
                .renderingMode(source == .grokBot ? .original : .template)
                .resizable()
                .scaledToFit()
                .foregroundStyle(.primary)
        } else {
            Image(systemName: "questionmark.square.dashed")
                .foregroundStyle(.secondary)
        }
    }
}
