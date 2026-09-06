import Foundation
import POMUsageKit

/// All external reads are bounded before JSON decoding, including cache restores.
public enum ReportFiles {
    public static func read(_ url: URL) throws -> UsageHistoryReport {
        guard url.isFileURL else { throw CocoaError(.fileReadUnsupportedScheme) }
        let scoped = url.startAccessingSecurityScopedResource()
        defer { if scoped { url.stopAccessingSecurityScopedResource() } }
        var coordinationError: NSError?
        var result: Result<UsageHistoryReport, Error>?
        NSFileCoordinator().coordinate(readingItemAt: url, options: .withoutChanges, error: &coordinationError) { coordinatedURL in
            result = Result { try readRegularFile(coordinatedURL) }
        }
        if let coordinationError { throw coordinationError }
        guard let result else { throw CocoaError(.fileReadUnknown) }
        return try result.get()
    }

    private static func readRegularFile(_ url: URL) throws -> UsageHistoryReport {
        guard try url.resourceValues(forKeys: [.isRegularFileKey]).isRegularFile == true else {
            throw CocoaError(.fileReadUnsupportedScheme)
        }
        let handle = try FileHandle(forReadingFrom: url)
        defer { try? handle.close() }
        // Read one extra byte so a valid JSON prefix followed by a large payload is rejected.
        var data = Data()
        while data.count <= UsageHistoryReport.maximumBytes {
            let remaining = UsageHistoryReport.maximumBytes + 1 - data.count
            guard let chunk = try handle.read(upToCount: remaining), !chunk.isEmpty else { break }
            data.append(chunk)
        }
        return try UsageHistoryReport.decode(data)
    }

    public static func save(_ report: UsageHistoryReport, to url: URL) throws {
        let data = try report.encoded()
        try FileManager.default.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
        try data.write(to: url, options: .atomic)
    }

    public static func remove(_ url: URL) throws {
        if FileManager.default.fileExists(atPath: url.path) { try FileManager.default.removeItem(at: url) }
    }

    public static var cacheURL: URL {
        FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("POMCompanion", isDirectory: true).appendingPathComponent("report.json")
    }
}
