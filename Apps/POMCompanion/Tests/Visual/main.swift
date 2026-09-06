import AppKit
import SwiftUI
import POMCompanionUI
import POMCompanionData
import POMUsageKit

@main struct CompanionVisualChecks {
    @MainActor static func main() async throws {
        _ = NSApplication.shared
        let output = URL(fileURLWithPath: CommandLine.arguments[1])
        try FileManager.default.createDirectory(at: output, withIntermediateDirectories: true)
        let root = FileManager.default.temporaryDirectory.appendingPathComponent("pom-companion-ui-\(UUID().uuidString)")
        defer { try? FileManager.default.removeItem(at: root) }
        let report = try UsageHistoryReport.decode(ExampleReport.make().encoded())
        let input = root.appendingPathComponent("input.json")
        let cache = root.appendingPathComponent("cache/report.json")
        try ReportFiles.save(report, to: input)
        let model = CompanionModel(cacheURL: cache)
        precondition(model.report == nil)
        await model.open(input)
        precondition(model.report?.entries == report.entries && !model.isExample)
        await model.open(input)
        precondition(model.report?.entries == report.entries, "Repeated imports replace, not sum")
        let restored = CompanionModel(cacheURL: cache)
        precondition(restored.report?.entries == report.entries)
        try Data("invalid".utf8).write(to: input)
        await model.open(input)
        precondition(model.failure != nil && model.report?.entries == report.entries, "Invalid input preserves report")
        model.failure = nil
        model.showExample()
        precondition(model.isExample)
        let afterExample = try ReportFiles.read(cache)
        precondition(afterExample.entries == report.entries, "Example does not overwrite user's cache")
        model.clear()
        precondition(model.report == nil && !FileManager.default.fileExists(atPath: cache.path))

        for (name, width, language, scheme, days) in [
            ("mac-en", 940.0, "en", ColorScheme.light, 7),
            ("compact-en", 375.0, "en", ColorScheme.dark, 7),
            ("compact-lt", 375.0, "lt", ColorScheme.light, 30),
            ("tablet-lt", 820.0, "lt", ColorScheme.dark, 7)
        ] {
            let view = ReportDashboard(report: report, isExample: true, days: .constant(days), language: language)
                .padding(24).frame(width: width).environment(\.colorScheme, scheme)
                .background(scheme == .dark ? Color.black : Color.white)
            try render(view, name: name, output: output)
        }
        print("Companion import, cache, replacement, example and removal checks passed; four layouts rendered.")
    }
    @MainActor static func render<V: View>(_ view: V, name: String, output: URL) throws {
        let host = NSHostingView(rootView: view)
        host.frame = NSRect(origin: .zero, size: host.fittingSize)
        let window = NSWindow(contentRect: host.frame, styleMask: [.borderless], backing: .buffered, defer: false)
        window.contentView = host
        // Geometry observations settle after the view joins a window hierarchy.
        host.layoutSubtreeIfNeeded()
        RunLoop.main.run(until: Date().addingTimeInterval(0.1))
        host.frame = NSRect(origin: .zero, size: host.fittingSize)
        host.layoutSubtreeIfNeeded()
        guard let bitmap = host.bitmapImageRepForCachingDisplay(in: host.bounds) else { fatalError("No bitmap") }
        host.cacheDisplay(in: host.bounds, to: bitmap)
        try bitmap.representation(using: .png, properties: [:])!.write(to: output.appendingPathComponent(name + ".png"))
        print("\(name): \(host.frame.width) x \(host.frame.height)")
    }
}
