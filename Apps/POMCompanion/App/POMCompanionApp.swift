import SwiftUI
import POMCompanionUI

@main
@MainActor
struct POMCompanionApp: App {
    @StateObject private var model: CompanionModel

    init() {
        #if DEBUG
        let testing = ProcessInfo.processInfo.arguments.contains("--ui-testing")
        if testing { UserDefaults.standard.set("en", forKey: "pomCompanionLanguage") }
        _model = StateObject(wrappedValue: testing ? CompanionModel(cacheURL: nil) : CompanionModel())
        #else
        _model = StateObject(wrappedValue: CompanionModel())
        #endif
    }

    var body: some Scene {
        WindowGroup("POM Companion") {
            CompanionRootView(model: model)
                #if os(macOS)
                .frame(minWidth: 640, minHeight: 540)
                #endif
        }
    }
}
