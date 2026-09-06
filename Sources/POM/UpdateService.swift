import Combine
import Foundation
import Sparkle

/// Sparkle verifies update archives before installation. Development bundles without
/// a feed/key do not start an updater and expose their configuration state to the UI.
@MainActor
final class UpdateService: ObservableObject {
    private let controller = SPUStandardUpdaterController(startingUpdater: false, updaterDelegate: nil, userDriverDelegate: nil)
    @Published private(set) var canCheck = false
    @Published private(set) var automaticallyChecks = false
    @Published private(set) var configured = false
    private var observations: Set<AnyCancellable> = []

    func start() {
        guard let key = Bundle.main.object(forInfoDictionaryKey: "SUPublicEDKey") as? String,
              Data(base64Encoded: key)?.count == 32,
              let feed = Bundle.main.object(forInfoDictionaryKey: "SUFeedURL") as? String,
              URL(string: feed)?.scheme == "https" else { return }
        configured = true
        controller.updater.publisher(for: \.canCheckForUpdates)
            .receive(on: RunLoop.main).sink { [weak self] in self?.canCheck = $0 }.store(in: &observations)
        controller.updater.publisher(for: \.automaticallyChecksForUpdates)
            .receive(on: RunLoop.main).sink { [weak self] in self?.automaticallyChecks = $0 }.store(in: &observations)
        controller.startUpdater()
    }
    func check() { controller.checkForUpdates(nil) }
    func setAutomatic(_ value: Bool) { controller.updater.automaticallyChecksForUpdates = value }
}
