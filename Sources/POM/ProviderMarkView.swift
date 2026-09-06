import SwiftUI

/// Tas pats paslaugos ženklas meniu juostoje ir limitų langelyje.
struct ProviderMarkView: View {
    let source: MenuBarSource

    // SVG įkeliami vieną kartą. Jie supakuoti su programa, tad tinklo nereikia.
    private static let anthropic = logo(named: "anthropic")
    private static let chatGPT = logo(named: "chatgpt")

    private static func logo(named name: String) -> NSImage? {
        // Rankomis supakuotoje macOS programoje ištekliai yra Contents/Resources.
        // SwiftPM modulis naudojamas tik paleidžiant iš kodo ar vaizdų patikroje.
        let bundle = Bundle.main.url(forResource: "POM_POM", withExtension: "bundle")
            .flatMap(Bundle.init(url:)) ?? Bundle.module
        guard let url = bundle.url(forResource: name, withExtension: "svg") else { return nil }
        return NSImage(contentsOf: url)
    }

    var body: some View {
        if source == .fable {
            Text("F")
                .font(.system(size: 9, weight: .bold, design: .rounded))
                .foregroundStyle(.secondary)
        } else if let image = source == .claude ? Self.anthropic : Self.chatGPT {
            Image(nsImage: image)
                .renderingMode(.template)
                .resizable()
                .scaledToFit()
                .foregroundStyle(.primary)
        } else {
            Image(systemName: "questionmark.square.dashed")
                .foregroundStyle(.secondary)
        }
    }
}
