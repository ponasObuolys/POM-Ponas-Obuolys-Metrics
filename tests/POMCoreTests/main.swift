import Foundation
import POMCore

// Paprasta testų paleidyklė. XCTest su komandinės eilutės įrankiais neprieinamas,
// tad patikros rašomos tiesiogiai. Radus klaidą, procesas grąžina ne nulį.

private var failures: [String] = []
private var passed = 0

private func check(_ name: String, _ condition: Bool, _ detail: @autoclosure () -> String = "") {
    if condition {
        passed += 1
    } else {
        let extra = detail()
        failures.append(extra.isEmpty ? name : "\(name) — \(extra)")
    }
}

private func checkEqual<T: Equatable>(_ name: String, _ actual: T, _ expected: T) {
    check(name, actual == expected, "gauta \(actual), laukta \(expected)")
}

private func checkClose(_ name: String, _ actual: Double, _ expected: Double, tolerance: Double = 0.0001) {
    check(name, abs(actual - expected) < tolerance, "gauta \(actual), laukta \(expected)")
}

private func date(_ epoch: TimeInterval) -> Date { Date(timeIntervalSince1970: epoch) }

// MARK: - Skaitymas: tilto formatas

do {
    let json = """
    {"schema":1,"source":"statusline","captured_at":1753387200,
     "five_hour":{"used_percentage":23.5,"resets_at":1753401600},
     "seven_day":{"used_percentage":41.2,"resets_at":1753833600}}
    """
    let snapshot = try UsageParser.parse(
        data: Data(json.utf8), source: .statusline, capturedAt: date(0))
    checkClose("tiltas: 5 val. procentai", snapshot.fiveHour.usedPercentage, 23.5)
    checkClose("tiltas: 7 d. procentai", snapshot.sevenDay.usedPercentage, 41.2)
    checkEqual("tiltas: 5 val. atsistatymas", snapshot.fiveHour.resetsAt, date(1753401600))
    checkEqual("tiltas: 7 d. atsistatymas", snapshot.sevenDay.resetsAt, date(1753833600))
    checkEqual("tiltas: fiksavimo laikas", snapshot.capturedAt, date(1753387200))
    checkEqual("tiltas: šaltinis", snapshot.source, UsageSnapshot.Source.statusline)
} catch {
    failures.append("tilto formato skaitymas metė klaidą: \(error)")
}

// MARK: - Skaitymas: serverio formatas su objektais ir ISO datomis

do {
    let json = """
    {"five_hour":{"utilization":17.0,"resets_at":"2026-02-08T18:59:59Z"},
     "seven_day":{"utilization":11.0,"resets_at":"2026-02-14T16:59:59Z"},
     "seven_day_opus":{"utilization":5.0,"resets_at":null}}
    """
    let snapshot = try UsageParser.parse(
        data: Data(json.utf8), source: .server, capturedAt: date(1000))
    checkClose("serveris/objektas: 5 val.", snapshot.fiveHour.usedPercentage, 17.0)
    checkClose("serveris/objektas: 7 d.", snapshot.sevenDay.usedPercentage, 11.0)
    checkEqual("serveris/objektas: ISO data", snapshot.fiveHour.resetsAt, date(1770577199))
    checkEqual("serveris/objektas: fiksavimo laikas iš išorės", snapshot.capturedAt, date(1000))
    checkEqual("serveris/objektas: šaltinis", snapshot.source, UsageSnapshot.Source.server)
} catch {
    failures.append("serverio objektų formatas metė klaidą: \(error)")
}

// MARK: - Skaitymas: serverio formatas su masyvu

do {
    let json = """
    {"limits":[
      {"type":"seven_day_opus","utilization":5.0,"resets_at":null},
      {"type":"fiveHour","utilization":62.5,"resets_at":1753401600},
      {"type":"seven_day","utilization":88.0,"resets_at":1753833600}
    ]}
    """
    let snapshot = try UsageParser.parse(
        data: Data(json.utf8), source: .server, capturedAt: date(1000))
    checkClose("serveris/masyvas: 5 val.", snapshot.fiveHour.usedPercentage, 62.5)
    checkClose("serveris/masyvas: 7 d.", snapshot.sevenDay.usedPercentage, 88.0)
    checkEqual("serveris/masyvas: atsistatymas", snapshot.sevenDay.resetsAt, date(1753833600))
} catch {
    failures.append("serverio masyvo formatas metė klaidą: \(error)")
}

// MARK: - Skaitymas: seven_day_opus nepainiojamas su seven_day

do {
    let json = """
    {"five_hour":{"utilization":1.0},"seven_day_opus":{"utilization":99.0}}
    """
    _ = try UsageParser.parse(data: Data(json.utf8), source: .server, capturedAt: date(0))
    failures.append("trūkstamas seven_day turėjo mesti klaidą, bet nemetė")
} catch UsageParser.ParseError.missingWindow(let name) {
    checkEqual("trūkstamas langas įvardytas", name, "seven_day")
} catch {
    failures.append("netikėta klaida trūkstamam langui: \(error)")
}

// MARK: - Skaitymas: netinkami duomenys

do {
    _ = try UsageParser.parse(data: Data("ne json".utf8), source: .server, capturedAt: date(0))
    failures.append("blogas JSON turėjo mesti klaidą, bet nemetė")
} catch {
    check("blogas JSON metė klaidą", true)
}

// MARK: - Atsistatymo logika

let window = UsageWindow(usedPercentage: 73.0, resetsAt: date(2000))

let beforeReset = UsageDisplay.resolve(window, now: date(1999))
checkClose("prieš atsistatymą rodoma reikšmė", beforeReset.usedPercentage, 73.0)
checkEqual("prieš atsistatymą žyma neuždėta", beforeReset.didReset, false)

let afterReset = UsageDisplay.resolve(window, now: date(2001))
checkClose("po atsistatymo rodomas nulis", afterReset.usedPercentage, 0.0)
checkEqual("po atsistatymo žyma uždėta", afterReset.didReset, true)

let noReset = UsageDisplay.resolve(UsageWindow(usedPercentage: 50, resetsAt: nil), now: date(9999))
checkClose("be atsistatymo laiko reikšmė nekeičiama", noReset.usedPercentage, 50.0)
checkEqual("be atsistatymo laiko žyma neuždėta", noReset.didReset, false)

// MARK: - Šviežumas

checkEqual("nėra duomenų", UsageDisplay.freshness(capturedAt: nil, now: date(0)), Freshness.none)
checkEqual("gyva", UsageDisplay.freshness(capturedAt: date(0), now: date(60)), Freshness.live)
checkEqual("neseniai", UsageDisplay.freshness(capturedAt: date(0), now: date(600)), Freshness.recent)
checkEqual("pasenę", UsageDisplay.freshness(capturedAt: date(0), now: date(7200)), Freshness.stale)

// MARK: - Spalvų ribos

checkEqual("69 % yra ramu", UsageLevel(percentage: 69), UsageLevel.normal)
checkEqual("70 % yra įspėjimas", UsageLevel(percentage: 70), UsageLevel.warning)
checkEqual("89 % yra įspėjimas", UsageLevel(percentage: 89), UsageLevel.warning)
checkEqual("90 % yra kritinis", UsageLevel(percentage: 90), UsageLevel.critical)

// MARK: - Serverio užklausų vartai

var gate = ServerFetchGate(enabled: true)

checkEqual("išjungus – neklausiama", ServerFetchGate(enabled: false)
    .decide(localCapturedAt: nil, now: date(0), manual: false), ServerFetchGate.Decision.skipDisabled)

checkEqual("švieži vietiniai duomenys – neklausiama",
    gate.decide(localCapturedAt: date(0), now: date(60), manual: false),
    ServerFetchGate.Decision.skipLocalFresh)

checkEqual("pasenę vietiniai duomenys – klausiama",
    gate.decide(localCapturedAt: date(0), now: date(3600), manual: false),
    ServerFetchGate.Decision.fetch)

checkEqual("nėra vietinių duomenų – klausiama",
    gate.decide(localCapturedAt: nil, now: date(0), manual: false),
    ServerFetchGate.Decision.fetch)

gate.recordAttempt(at: date(3600))
gate.recordFailure()
checkEqual("po klaidos laukiama 30 min.", gate.backoffInterval, 30 * 60)
checkEqual("pauzės metu neklausiama",
    gate.decide(localCapturedAt: date(0), now: date(3600 + 600), manual: false),
    ServerFetchGate.Decision.skipBackoff)
checkEqual("pasibaigus pauzei klausiama vėl",
    gate.decide(localCapturedAt: date(0), now: date(3600 + 1801), manual: false),
    ServerFetchGate.Decision.fetch)

gate.recordAttempt(at: date(7200))
gate.recordFailure()
checkEqual("antra klaida – 60 min.", gate.backoffInterval, 60 * 60)
gate.recordAttempt(at: date(10800))
gate.recordFailure()
checkEqual("trečia klaida – 120 min.", gate.backoffInterval, 120 * 60)
gate.recordAttempt(at: date(14400))
gate.recordFailure()
checkEqual("ketvirta klaida – riba 120 min.", gate.backoffInterval, 120 * 60)
gate.recordSuccess()
checkEqual("po sėkmės pauzė nunulinama", gate.backoffInterval, 30 * 60)

var manualGate = ServerFetchGate(enabled: true)
checkEqual("rankinis mygtukas veikia net su šviežiais duomenimis",
    manualGate.decide(localCapturedAt: date(0), now: date(10), manual: true),
    ServerFetchGate.Decision.fetch)
manualGate.recordAttempt(at: date(10))
checkEqual("rankinis mygtukas per dažnai – stabdomas",
    manualGate.decide(localCapturedAt: date(0), now: date(100), manual: true),
    ServerFetchGate.Decision.skipManualFloor)
checkEqual("praėjus 5 min. rankinis mygtukas vėl veikia",
    manualGate.decide(localCapturedAt: date(0), now: date(10 + 301), manual: true),
    ServerFetchGate.Decision.fetch)

manualGate.recordAttempt(at: date(1000))
manualGate.recordFailure()
checkEqual("rankinis mygtukas nepaiso pauzės",
    manualGate.decide(localCapturedAt: date(0), now: date(1000 + 301), manual: true),
    ServerFetchGate.Decision.fetch)

// MARK: - Perspėjimų sekimas

var tracker = AlertTracker(thresholds: [80, 95])

checkEqual("žemiau ribos – nepranešama",
    tracker.check(window: .fiveHour, percentage: 50, resetsAt: date(5000)), nil)
checkEqual("kertant 80 % – pranešama",
    tracker.check(window: .fiveHour, percentage: 81, resetsAt: date(5000)), 80)
checkEqual("ta pati riba antrą kartą – tylima",
    tracker.check(window: .fiveHour, percentage: 85, resetsAt: date(5000)), nil)
checkEqual("kertant 95 % – pranešama",
    tracker.check(window: .fiveHour, percentage: 96, resetsAt: date(5000)), 95)
checkEqual("virš 95 % – tylima",
    tracker.check(window: .fiveHour, percentage: 99, resetsAt: date(5000)), nil)
checkEqual("kitas langas turi savo žymas",
    tracker.check(window: .sevenDay, percentage: 82, resetsAt: date(9000)), 80)
checkEqual("langui atsistačius žymos nunulinamos",
    tracker.check(window: .fiveHour, percentage: 81, resetsAt: date(6000)), 80)

var jumpTracker = AlertTracker(thresholds: [80, 95])
checkEqual("šuolis iš karto per abi ribas – praneša tik aukščiausią",
    jumpTracker.check(window: .fiveHour, percentage: 97, resetsAt: date(5000)), 95)
checkEqual("po šuolio žemesnė riba nebekartojama",
    jumpTracker.check(window: .fiveHour, percentage: 98, resetsAt: date(5000)), nil)

// MARK: - Lietuviškas laiko formatavimas

checkEqual("sekundės", LTFormat.countdown(to: date(40), now: date(0)), "po mažiau nei min.")
checkEqual("minutės", LTFormat.countdown(to: date(14 * 60), now: date(0)), "po 14 min")
checkEqual("valandos ir minutės", LTFormat.countdown(to: date(2 * 3600 + 14 * 60), now: date(0)), "po 2 val. 14 min")
checkEqual("lygios valandos", LTFormat.countdown(to: date(3 * 3600), now: date(0)), "po 3 val.")
checkEqual("dienos ir valandos", LTFormat.countdown(to: date(3 * 86400 + 5 * 3600), now: date(0)), "po 3 d. 5 val.")
checkEqual("lygios dienos", LTFormat.countdown(to: date(2 * 86400), now: date(0)), "po 2 d.")
checkEqual("praėjęs laikas", LTFormat.countdown(to: date(0), now: date(10)), "atsistatė")

checkEqual("amžius sekundėmis", LTFormat.age(from: date(0), now: date(12)), "prieš 12 s")
checkEqual("amžius minutėmis", LTFormat.age(from: date(0), now: date(5 * 60)), "prieš 5 min")
checkEqual("amžius valandomis", LTFormat.age(from: date(0), now: date(2 * 3600)), "prieš 2 val.")
checkEqual("amžius dienomis", LTFormat.age(from: date(0), now: date(3 * 86400)), "prieš 3 d.")
checkEqual("ką tik", LTFormat.age(from: date(0), now: date(0)), "ką tik")

// MARK: - Failo saugykla

do {
    let tmp = URL(fileURLWithPath: NSTemporaryDirectory())
        .appendingPathComponent("pom-tests-\(UUID().uuidString)", isDirectory: true)
    try FileManager.default.createDirectory(at: tmp, withIntermediateDirectories: true)
    defer { try? FileManager.default.removeItem(at: tmp) }

    let file = tmp.appendingPathComponent("snapshot.json")
    let store = SnapshotStore(fileURL: file)

    checkEqual("nesant failo grąžinamas nulinis rezultatas", store.load() == nil, true)

    let payload = """
    {"schema":1,"source":"statusline","captured_at":1753387200,
     "five_hour":{"used_percentage":10,"resets_at":1753401600},
     "seven_day":{"used_percentage":20,"resets_at":1753833600}}
    """
    try Data(payload.utf8).write(to: file)
    let loaded = store.load()
    checkClose("failas perskaitomas", loaded?.fiveHour.usedPercentage ?? -1, 10)
    checkEqual("šaltinis pažymimas kaip tiltas", loaded?.source, UsageSnapshot.Source.statusline)

    try Data("sugadinta".utf8).write(to: file)
    checkEqual("sugadintas failas negriauna programos", store.load() == nil, true)
} catch {
    failures.append("failo saugyklos testas metė klaidą: \(error)")
}

// MARK: - Rezultatas

print("")
if failures.isEmpty {
    print("✓ Visos patikros praėjo (\(passed))")
    exit(0)
} else {
    print("✗ Nepavyko \(failures.count) iš \(passed + failures.count):")
    for failure in failures { print("  · \(failure)") }
    exit(1)
}
