import Foundation
import POMCompanionData
import POMUsageKit

var passed = 0
func check(_ condition: @autoclosure () -> Bool, _ name: String) {
    guard condition() else { fatalError("FAIL: \(name)") }
    passed += 1
}
func rejects(_ name: String, _ body: () throws -> Void) {
    do { try body(); fatalError("FAIL: \(name)") } catch { passed += 1 }
}
let date = UsageDay.date("2026-09-06")!.addingTimeInterval(12 * 3600)
let report = ExampleReport.make(now: date)
let week = ReportPeriod(report: report, days: 7)
check(week.keys.first == "2026-08-31" && week.keys.last == "2026-09-06", "Historical report stays anchored to export date")
check(week.entries.count == 2, "Both sources preserved")
check(week.records(for: week.entries[0]).count == 7, "Seven-day filter")
check(week.total(for: week.entries[0]) == 3_520_000, "Token totals preserved")
check(week.previousWeekChange(for: week.entries[0]) == 0, "Same complete weeks compare equally")
let month = ReportPeriod(report: report, days: 30)
check(month.keys.count == 30 && month.keys.first == "2026-08-08", "Thirty-day period")
check(month.previousWeekChange(for: month.entries[0]) == nil, "No invented preceding month")

let partial = UsageHistoryReport.Entry(source: .claudeCodeLocal, collectionStatus: .partial,
    snapshot: TokenUsageSnapshot(days: [TokenDay(day: "2026-09-06", tokens: 0)], updatedAt: date))
let partialReport = try UsageHistoryReport(generatedAt: date, entries: [partial])
let partialWeek = ReportPeriod(report: partialReport, days: 7)
check(partialWeek.tokens(for: partial, day: "2026-09-06") == 0, "Measured zero retained")
check(partialWeek.tokens(for: partial, day: "2026-09-05") == nil, "Missing is not zero")
check(partialWeek.records(for: partial).count == 1, "Missing days are not fabricated")
check(partialWeek.previousWeekChange(for: partial) == nil, "Partial collection not compared")
let empty = UsageHistoryReport.Entry(source: .codexAccount, collectionStatus: .refreshFailed,
    snapshot: TokenUsageSnapshot(days: [], updatedAt: date))
check(partialWeek.total(for: empty) == nil, "No readings has no total")
let old = try UsageHistoryReport(generatedAt: date.addingTimeInterval(60 * 86400), entries: report.entries)
check(ReportPeriod(report: old, days: 7).total(for: old.entries[0]) == nil, "Stale source outside period is missing")

let directory = FileManager.default.temporaryDirectory.appendingPathComponent("pom-companion-\(UUID().uuidString)")
defer { try? FileManager.default.removeItem(at: directory) }
let file = directory.appendingPathComponent("report.json")
try ReportFiles.save(report, to: file)
let restored = try ReportFiles.read(file)
check(restored == report, "Report round trip")
try ReportFiles.save(report, to: file)
let repeated = try ReportFiles.read(file)
check(repeated == report, "Repeated import never doubles totals")
try ReportFiles.save(partialReport, to: file)
let replaced = try ReportFiles.read(file)
check(replaced == partialReport, "New report replaces old sources")
try ReportFiles.remove(file)
check(!FileManager.default.fileExists(atPath: file.path), "Local copy removable")
try ReportFiles.remove(file)
check(true, "Removal is idempotent")
rejects("Missing file rejected") { _ = try ReportFiles.read(file) }
try Data(repeating: 0x20, count: UsageHistoryReport.maximumBytes + 1).write(to: file)
rejects("External read rejects oversized report") { _ = try ReportFiles.read(file) }
var padded = try report.encoded()
padded.append(Data(repeating: 0x20, count: UsageHistoryReport.maximumBytes))
try padded.write(to: file)
rejects("Valid JSON prefix does not bypass size bound") { _ = try ReportFiles.read(file) }
try Data("{broken json".utf8).write(to: file)
rejects("Malformed JSON rejected") { _ = try ReportFiles.read(file) }
rejects("Directories cannot be imported") { _ = try ReportFiles.read(directory) }
rejects("Remote URLs cannot trigger network requests") { _ = try ReportFiles.read(URL(string: "https://example.invalid/report.json")!) }
print("\(passed) companion data checks passed")
