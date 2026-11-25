import CryptoKit
import Foundation
import SQLite3

/// Owned by one background worker. Bounded reads, durable offsets and a disk-backed
/// message index: no transcript contents or raw message/file identifiers are saved.
public final class ClaudeTokenIndexer {
    public struct Batch: Sendable {
        public let snapshot: TokenUsageSnapshot
        /// The part of `snapshot` used by Fable and Mythos models.
        public let fable: TokenUsageSnapshot
        public let complete: Bool
        public let available: Bool
        public let bytesRead: Int
        public let skippedLines: Int
    }
    public enum IndexError: Error { case database, unreadableDirectory }
    private struct FileEntry { let url: URL; let key: String; let inode: Int64; let size: Int64; let modified: Double }
    private let root: URL
    private var db: OpaquePointer?
    private var files: [FileEntry] = []
    private var nextFile = 0
    private var handle: FileHandle?
    private var position: Int64 = 0
    private var line = Data()
    private var discarding = false
    /// Unreadable records of the file being read; saved per file so a warning ends with its file.
    private var skipped = 0
    private var available = false
    private var cutoff = ""
    private var today = ""
    private let timestamp = ISO8601DateFormatter()
    private let plainTimestamp = ISO8601DateFormatter()
    public static let maximumLineBytes = 4 * 1024 * 1024
    private static let schema = 2
    private let transient = unsafeBitCast(-1, to: sqlite3_destructor_type.self)

    public init(root: URL, database: URL) throws {
        self.root = root
        timestamp.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        try FileManager.default.createDirectory(at: database.deletingLastPathComponent(), withIntermediateDirectories: true)
        guard sqlite3_open(database.path, &db) == SQLITE_OK else { throw IndexError.database }
        try execute("PRAGMA cache_size=-1024; PRAGMA journal_mode=DELETE; PRAGMA secure_delete=ON;")
        try execute("CREATE TABLE IF NOT EXISTS metadata (key TEXT PRIMARY KEY, value INTEGER);")
        if try count("SELECT value FROM metadata WHERE key='schema'") != Self.schema {
            // Earlier indexes hold neither the model nor which file warned; sessions are read again.
            try execute("""
                DROP TABLE IF EXISTS files; DROP TABLE IF EXISTS messages; DELETE FROM metadata;
                INSERT INTO metadata(key,value) VALUES('schema',\(Self.schema));
                """)
        }
        try execute("""
            CREATE TABLE IF NOT EXISTS files (key TEXT PRIMARY KEY, inode INTEGER, offset INTEGER, size INTEGER, modified REAL, discarding INTEGER, skipped INTEGER NOT NULL DEFAULT 0);
            CREATE TABLE IF NOT EXISTS messages (key TEXT PRIMARY KEY, day TEXT NOT NULL, tokens INTEGER NOT NULL, fable INTEGER NOT NULL DEFAULT 0);
            CREATE INDEX IF NOT EXISTS message_day ON messages(day);
            """)
    }

    /// Fable and Mythos draw on the same separate weekly limit.
    public static func isFableFamily(_ model: String?) -> Bool {
        guard let model = model?.lowercased() else { return false }
        return model.contains("fable") || model.contains("mythos")
    }
    deinit { try? handle?.close(); sqlite3_close(db) }

    /// Metadata discovery once per refresh, never for every import batch. Symlinks
    /// are excluded; copied/forked messages deduplicate globally by message ID.
    public func begin(now: Date = Date()) throws {
        try autoreleasepool { try discover(now: now) }
    }

    private func discover(now: Date) throws {
        try? handle?.close(); handle = nil; line.removeAll(keepingCapacity: false)
        files = []; nextFile = 0
        cutoff = UsageDay.keys(days: 30, now: now).first!; today = UsageDay.key(now)
        try execute("DELETE FROM messages WHERE day < '\(cutoff)'; DELETE FROM files WHERE modified < \(UsageDay.date(cutoff)!.timeIntervalSince1970);")
        available = FileManager.default.fileExists(atPath: root.path)
        guard available else { return }
        var failed = false
        let keys: [URLResourceKey] = [.isRegularFileKey, .isSymbolicLinkKey, .fileSizeKey, .contentModificationDateKey, .fileResourceIdentifierKey]
        guard let enumerator = FileManager.default.enumerator(at: root, includingPropertiesForKeys: keys,
            options: [.skipsHiddenFiles, .skipsPackageDescendants], errorHandler: { _, _ in failed = true; return true }) else {
            throw IndexError.unreadableDirectory
        }
        for case let url as URL in enumerator where url.pathExtension == "jsonl" {
            let values = try url.resourceValues(forKeys: Set(keys))
            guard values.isRegularFile == true, values.isSymbolicLink != true,
                  let modified = values.contentModificationDate, modified >= UsageDay.date(cutoff)!,
                  let size = values.fileSize else { continue }
            let attributes = try FileManager.default.attributesOfItem(atPath: url.path)
            let inode = (attributes[.systemFileNumber] as? NSNumber)?.int64Value ?? 0
            let entry = FileEntry(url: url, key: Self.hash(url.path), inode: inode, size: Int64(size), modified: modified.timeIntervalSince1970)
            let previous = try cursor(entry.key)
            if previous?.inode == inode, previous?.size == Int64(size), previous?.modified == entry.modified { continue }
            files.append(entry)
        }
        if failed { throw IndexError.unreadableDirectory }
        // Today's data appears first while older sessions continue importing.
        files.sort { $0.modified > $1.modified }
    }

    /// At most 2 MiB / ~80 ms of parsing per pass (one 64 KiB chunk may overrun).
    /// Caller leaves a quiet interval between passes, including first import.
    public func scanBatch(now: Date = Date(), maxBytes: Int = 2 * 1024 * 1024, maxSeconds: Double = 0.08) throws -> Batch {
        try autoreleasepool { try scan(now: now, maxBytes: maxBytes, maxSeconds: maxSeconds) }
    }

    private func scan(now: Date, maxBytes: Int, maxSeconds: Double) throws -> Batch {
        guard nextFile < files.count else { return try batch(now: now, bytes: 0) }
        let started = ProcessInfo.processInfo.systemUptime
        var bytes = 0
        try execute("BEGIN IMMEDIATE")
        do {
            let insert = try prepare("INSERT INTO messages(key,day,tokens,fable) VALUES(?,?,?,?) ON CONFLICT(key) DO UPDATE SET day=min(day,excluded.day),tokens=max(tokens,excluded.tokens),fable=max(fable,excluded.fable)")
            defer { sqlite3_finalize(insert) }
            while nextFile < files.count, bytes < maxBytes,
                  ProcessInfo.processInfo.systemUptime - started < maxSeconds {
                let file = files[nextFile]
                if handle == nil {
                    let old = try cursor(file.key)
                    // Replaced, truncated or same-size rewritten files restart safely.
                    let append = old?.inode == file.inode && (old?.offset ?? 0) <= file.size &&
                        (old?.size != file.size || old?.modified == file.modified)
                    position = append ? old!.offset : 0
                    discarding = append ? old!.discarding : false
                    skipped = append ? old!.skipped : 0
                    line.removeAll(keepingCapacity: true)
                    handle = try FileHandle(forReadingFrom: file.url)
                    try handle!.seek(toOffset: UInt64(position))
                }
                let remaining = max(0, file.size - position)
                let data = try handle!.read(upToCount: min(64 * 1024, maxBytes - bytes, Int(remaining))) ?? Data()
                if data.isEmpty {
                    try saveCursor(file, offset: position - Int64(line.count), finished: true)
                    try handle!.close(); handle = nil; line.removeAll(keepingCapacity: true); nextFile += 1
                    continue
                }
                bytes += data.count; position += Int64(data.count)
                var start = data.startIndex
                while start < data.endIndex {
                    let end = data[start...].firstIndex(of: 10) ?? data.endIndex
                    if !discarding {
                        if line.count + end - start <= Self.maximumLineBytes { line.append(data[start..<end]) }
                        else { line.removeAll(keepingCapacity: false); discarding = true; skipped += 1 }
                    }
                    if end < data.endIndex {
                        if !discarding { try autoreleasepool { try consume(line, statement: insert) } }
                        line.removeAll(keepingCapacity: true); discarding = false
                        start = end + 1
                    } else { start = end }
                }
                try saveCursor(file, offset: position - Int64(line.count), finished: false)
            }
            try execute("COMMIT")
        } catch {
            try? execute("ROLLBACK"); try? handle?.close(); handle = nil; line.removeAll(); throw error
        }
        return try batch(now: now, bytes: bytes)
    }

    private func batch(now: Date, bytes: Int) throws -> Batch {
        Batch(snapshot: TokenUsageSnapshot(days: try totals(), updatedAt: now),
              fable: TokenUsageSnapshot(days: try totals(fableOnly: true), updatedAt: now),
              complete: nextFile == files.count, available: available, bytesRead: bytes,
              skippedLines: try count("SELECT COALESCE(SUM(skipped),0) FROM files") ?? 0)
    }

    private func consume(_ data: Data, statement: OpaquePointer) throws {
        // Most large transcript records contain tool/user content. Reject cheaply
        // before JSON decoding; never persist or log that content.
        guard data.range(of: Data("\"usage\"".utf8)) != nil else { return }
        guard let root = (try? JSONSerialization.jsonObject(with: data)) as? [String: Any] else { skipped += 1; return }
        guard root["type"] as? String == "assistant", let message = root["message"] as? [String: Any],
              let usage = message["usage"] as? [String: Any] else { return }
        guard let id = message["id"] as? String, !id.isEmpty,
              let time = root["timestamp"] as? String,
              let date = timestamp.date(from: time) ?? plainTimestamp.date(from: time) else { skipped += 1; return }
        let day = UsageDay.key(date)
        guard day >= cutoff, day <= today else { return }
        var total: Int64 = 0
        for key in ["input_tokens", "output_tokens", "cache_creation_input_tokens", "cache_read_input_tokens"] {
            guard let value = usage[key] else { continue }
            guard let number = value as? NSNumber, CFGetTypeID(number) != CFBooleanGetTypeID(),
                  number.doubleValue >= 0, number.doubleValue <= 1_000_000_000_000,
                  number.doubleValue.rounded(.towardZero) == number.doubleValue else { skipped += 1; return }
            total += number.int64Value
        }
        guard total > 0 else { return }
        sqlite3_reset(statement); sqlite3_clear_bindings(statement)
        bind(Self.hash(id), to: statement, at: 1); bind(day, to: statement, at: 2)
        sqlite3_bind_int64(statement, 3, total)
        sqlite3_bind_int(statement, 4, Self.isFableFamily(message["model"] as? String) ? 1 : 0)
        guard sqlite3_step(statement) == SQLITE_DONE else { throw IndexError.database }
    }

    private struct Cursor { let inode: Int64; let offset: Int64; let size: Int64; let modified: Double; let discarding: Bool; let skipped: Int }
    private func cursor(_ key: String) throws -> Cursor? {
        let query = try prepare("SELECT inode,offset,size,modified,discarding,skipped FROM files WHERE key=?")
        defer { sqlite3_finalize(query) }; bind(key, to: query, at: 1)
        guard sqlite3_step(query) == SQLITE_ROW else { return nil }
        return Cursor(inode: sqlite3_column_int64(query, 0), offset: sqlite3_column_int64(query, 1), size: sqlite3_column_int64(query, 2),
                      modified: sqlite3_column_double(query, 3), discarding: sqlite3_column_int(query, 4) != 0,
                      skipped: Int(sqlite3_column_int64(query, 5)))
    }
    private func saveCursor(_ file: FileEntry, offset: Int64, finished: Bool) throws {
        let query = try prepare("INSERT OR REPLACE INTO files VALUES(?,?,?,?,?,?,?)")
        defer { sqlite3_finalize(query) }; bind(file.key, to: query, at: 1)
        sqlite3_bind_int64(query, 2, file.inode); sqlite3_bind_int64(query, 3, offset)
        // -1 ensures an interrupted batch is rediscovered on restart.
        sqlite3_bind_int64(query, 4, finished ? file.size : -1)
        sqlite3_bind_double(query, 5, file.modified); sqlite3_bind_int(query, 6, discarding ? 1 : 0)
        sqlite3_bind_int64(query, 7, Int64(skipped))
        guard sqlite3_step(query) == SQLITE_DONE else { throw IndexError.database }
    }
    private func totals(fableOnly: Bool = false) throws -> [TokenDay] {
        let query = try prepare("SELECT day,SUM(tokens) FROM messages WHERE day >= '\(cutoff)' AND day <= '\(today)'\(fableOnly ? " AND fable=1" : "") GROUP BY day ORDER BY day")
        defer { sqlite3_finalize(query) }
        var days: [TokenDay] = []
        var status = sqlite3_step(query)
        while status == SQLITE_ROW {
            days.append(TokenDay(day: String(cString: sqlite3_column_text(query, 0)), tokens: sqlite3_column_int64(query, 1)))
            status = sqlite3_step(query)
        }
        guard status == SQLITE_DONE else { throw IndexError.database }
        return days
    }
    private func count(_ sql: String) throws -> Int? {
        let query = try prepare(sql)
        defer { sqlite3_finalize(query) }
        let status = sqlite3_step(query)
        guard status == SQLITE_ROW || status == SQLITE_DONE else { throw IndexError.database }
        return status == SQLITE_ROW ? Int(sqlite3_column_int64(query, 0)) : nil
    }
    private func prepare(_ sql: String) throws -> OpaquePointer {
        var statement: OpaquePointer?
        guard sqlite3_prepare_v2(db, sql, -1, &statement, nil) == SQLITE_OK, let statement else { throw IndexError.database }
        return statement
    }
    private func execute(_ sql: String) throws {
        guard sqlite3_exec(db, sql, nil, nil, nil) == SQLITE_OK else { throw IndexError.database }
    }
    private func bind(_ text: String, to statement: OpaquePointer, at index: Int32) {
        _ = text.withCString { sqlite3_bind_text(statement, index, $0, -1, transient) }
    }
    private static func hash(_ text: String) -> String {
        SHA256.hash(data: Data(text.utf8)).map { String(format: "%02x", $0) }.joined()
    }
}
