import SwiftUI
import POMUsageKit
import POMCompanionData

@MainActor
public final class CompanionModel: ObservableObject {
    @Published public private(set) var report: UsageHistoryReport?
    @Published public private(set) var isExample = false
    @Published public private(set) var busy = false
    @Published public var failure: Failure?
    public enum Failure { case open, save, remove, restore }
    private let cacheURL: URL?

    public init(cacheURL: URL? = ReportFiles.cacheURL, preview: UsageHistoryReport? = nil) {
        self.cacheURL = cacheURL
        report = preview
        if preview == nil, let cacheURL, FileManager.default.fileExists(atPath: cacheURL.path) {
            do { report = try ReportFiles.read(cacheURL) } catch { failure = .restore }
        }
    }

    public func open(_ url: URL) async {
        guard !busy else { return }
        busy = true
        defer { busy = false }
        do {
            let imported = try await Task.detached(priority: .userInitiated) { try ReportFiles.read(url) }.value
            // A new report replaces the previous one. Account/session data are never added together.
            if let cacheURL { try ReportFiles.save(imported, to: cacheURL) }
            report = imported
            isExample = false
        } catch { failure = .open }
    }

    public func showExample() {
        guard !busy else { return }
        report = ExampleReport.make()
        isExample = true
        // The example never overwrites a user's cached report.
    }

    public func clear() {
        guard !busy else { return }
        do {
            if let cacheURL { try ReportFiles.remove(cacheURL) }
            report = nil
            isExample = false
        } catch { failure = .remove }
    }
}
