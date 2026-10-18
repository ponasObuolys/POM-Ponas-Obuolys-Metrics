import Foundation
import POMCore
import SQLite3

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

// Explicit opt-in benchmark. Prints only aggregate resource statistics, never log content.
if ProcessInfo.processInfo.environment["POM_TOKEN_BENCHMARK"] == "1" {
    do {
        let dir = URL(fileURLWithPath: FileManager.default.currentDirectoryPath).appendingPathComponent(".build/token-benchmark")
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        let index = try ClaudeTokenIndexer(root: FileManager.default.homeDirectoryForCurrentUser.appendingPathComponent(".claude/projects"), database: dir.appendingPathComponent("index.sqlite"))
        let start = ProcessInfo.processInfo.systemUptime
        try index.begin()
        var read = 0, batches = 0
        while true {
            let batch = try index.scanBatch()
            read += batch.bytesRead; batches += 1
            if batch.complete { print("BENCH import bytes=\(read) batches=\(batches) seconds=\(ProcessInfo.processInfo.systemUptime-start) days=\(batch.snapshot.days.count) skipped=\(batch.skippedLines)"); break }
        }
        let idleStart = ProcessInfo.processInfo.systemUptime
        try index.begin()
        let idle = try index.scanBatch()
        print("BENCH unchanged bytes=\(idle.bytesRead) seconds=\(ProcessInfo.processInfo.systemUptime-idleStart) complete=\(idle.complete)")
    } catch { print("token benchmark failed: \(error)"); exit(1) }
    exit(0)
}


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
checkClose("pasibaigęs laikmatis neišgalvoja nulio", afterReset.usedPercentage, 73.0)
checkEqual("pasibaigęs laikmatis išsaugo paskutinį atsistatymo laiką", afterReset.resetsAt, date(2000))
checkEqual("po atsistatymo žyma uždėta", afterReset.didReset, true)

let atReset = UsageDisplay.resolve(window, now: date(2000))
checkClose("ties atsistatymo riba paskutinė reikšmė išsaugoma", atReset.usedPercentage, 73.0)
checkEqual("ties atsistatymo riba laukiama naujų duomenų", atReset.didReset, true)
let confirmedReset = UsageDisplay.resolve(UsageWindow(usedPercentage: 2, resetsAt: date(3000)), now: date(2001))
checkEqual("naujas langas panaikina laukimo būseną", confirmedReset.didReset, false)
checkClose("naujas langas rodo gautą naudojimą", confirmedReset.usedPercentage, 2)

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

// Nuolatinė kliūtis: raktui trūksta teisių, tad kartoti nėra prasmės.
var blockedGate = ServerFetchGate(enabled: true)
checkEqual("iš pradžių neužblokuota", blockedGate.isBlocked, false)
blockedGate.block()
checkEqual("užblokavus – neklausiama",
    blockedGate.decide(localCapturedAt: nil, now: date(0), manual: false),
    ServerFetchGate.Decision.skipBlocked)
checkEqual("net rankinis mygtukas neapeina blokavimo",
    blockedGate.decide(localCapturedAt: nil, now: date(0), manual: true),
    ServerFetchGate.Decision.skipBlocked)
blockedGate.unblock()
checkEqual("atblokavus klausiama vėl",
    blockedGate.decide(localCapturedAt: nil, now: date(0), manual: false),
    ServerFetchGate.Decision.fetch)

// Serverio klaidos paaiškinimas rodomas vartotojui, tad turi būti perskaitomas.
checkEqual(
    "serverio paaiškinimas ištraukiamas",
    OAuthUsageClient.serverMessage(
        from: Data(
            #"{"type":"error","error":{"type":"permission_error","message":"OAuth token does not meet scope requirement any_of(user:profile, user:office)"}}"#
                .utf8)),
    "OAuth token does not meet scope requirement any_of(user:profile, user:office)")
checkEqual(
    "netinkamas atsakymas negriauna programos",
    OAuthUsageClient.serverMessage(from: Data("ne json".utf8)), "")

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

// Perjungus perspėjimų nustatymą pranešimai neturi prasidėti iš naujo.
var presetTracker = AlertTracker(thresholds: [90, 98])
checkEqual("kertant 90 % – pranešama",
    presetTracker.check(window: .fiveHour, percentage: 92, resetsAt: date(5000)), 90)
presetTracker.updateThresholds([70, 90])
checkEqual("perjungus į ankstesnį perspėjimą sena riba nekartojama",
    presetTracker.check(window: .fiveHour, percentage: 92, resetsAt: date(5000)), nil)
presetTracker.updateThresholds([80, 95])
checkEqual("dar kartą perjungus taip pat tylima",
    presetTracker.check(window: .fiveHour, percentage: 92, resetsAt: date(5000)), nil)
checkEqual("aukštesnė nauja riba vis tiek suveikia",
    presetTracker.check(window: .fiveHour, percentage: 96, resetsAt: date(5000)), 95)
checkEqual("langui atsistačius naujos ribos veikia iš pradžių",
    presetTracker.check(window: .fiveHour, percentage: 85, resetsAt: date(7000)), 80)

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

checkEqual("taškas pridedamas", LTFormat.endingWithPeriod("po 14 min"), "po 14 min.")
checkEqual("antras taškas nededamas", LTFormat.endingWithPeriod("po 3 d. 5 val."), "po 3 d. 5 val.")

// MARK: - AppleScript eilutės pridengimas

checkEqual("paprastas tekstas", AppleScriptString.quoted("Liko 12 %"), "\"Liko 12 %\"")
checkEqual(
    "kabutės pridengiamos", AppleScriptString.quoted("sako \"labas\""),
    "\"sako \\\"labas\\\"\"")
checkEqual(
    "pasvirasis brūkšnys pridengiamas", AppleScriptString.quoted("a\\b"), "\"a\\\\b\"")

// MARK: - Prisijungimo rakto skaitymas

do {
    let secret = """
    {"claudeAiOauth":{"accessToken":"sk-teisingas","expiresAt":4102444800000}}
    """
    let token = try KeychainToken.parseAccessToken(from: secret, now: date(0))
    checkEqual("paimamas Claude raktas", token, "sk-teisingas")
} catch {
    failures.append("teisingo rakto skaitymas metė klaidą: \(error)")
}

// Tame pačiame įraše guli ir svetimų paslaugų raktai. Jų imti negalima.
do {
    let secret = """
    {"mcpOAuth":{"plugin:engineering:notion|abc":{"accessToken":"svetimas-raktas"}}}
    """
    _ = try KeychainToken.parseAccessToken(from: secret, now: date(0))
    failures.append("PAVOJUS: paimtas svetimos paslaugos raktas")
} catch KeychainToken.TokenError.claudeAccountNotFound {
    check("svetimi MCP raktai neimami", true)
} catch {
    failures.append("netikėta klaida be Claude rakto: \(error)")
}

// Claude Code galiojimo laiką saugo milisekundėmis.
do {
    let secret = """
    {"claudeAiOauth":{"accessToken":"sk-senas","expiresAt":1700000000000},
     "mcpOAuth":{"plugin:x|y":{"accessToken":"svetimas"}}}
    """
    _ = try KeychainToken.parseAccessToken(from: secret, now: date(1_800_000_000))
    failures.append("pasibaigęs raktas turėjo mesti klaidą")
} catch KeychainToken.TokenError.expired(let when) {
    checkEqual("milisekundės paverčiamos sekundėmis", when, date(1_700_000_000))
} catch {
    failures.append("netikėta klaida pasibaigusiam raktui: \(error)")
}

do {
    let secret = """
    {"claudeAiOauth":{"accessToken":"sk-galiojantis","expiresAt":1900000000000}}
    """
    let token = try KeychainToken.parseAccessToken(from: secret, now: date(1_800_000_000))
    checkEqual("galiojantis raktas priimamas", token, "sk-galiojantis")
} catch {
    failures.append("galiojantis raktas atmestas: \(error)")
}

do {
    _ = try KeychainToken.parseAccessToken(from: "ne json", now: date(0))
    failures.append("blogas raktinės turinys turėjo mesti klaidą")
} catch KeychainToken.TokenError.unreadableSecret {
    check("blogas raktinės turinys atmestas", true)
} catch {
    failures.append("netikėta klaida blogam turiniui: \(error)")
}

// POM savame įraše laikomas grynas raktas, be JSON apvalkalo.
do {
    let token = try KeychainToken.parseAccessToken(
        from: "  sk-ant-oat01-abc123\n", now: date(0))
    checkEqual("grynas raktas priimamas ir apkarpomas", token, "sk-ant-oat01-abc123")
} catch {
    failures.append("gryno rakto skaitymas metė klaidą: \(error)")
}

do {
    _ = try KeychainToken.parseAccessToken(from: "   ", now: date(0))
    failures.append("tuščias įrašas turėjo mesti klaidą")
} catch KeychainToken.TokenError.unreadableSecret {
    check("tuščias įrašas atmestas", true)
} catch {
    failures.append("netikėta klaida tuščiam įrašui: \(error)")
}

// MARK: - Ryšys su Claude Code

do {
    let home = URL(fileURLWithPath: NSTemporaryDirectory())
        .appendingPathComponent("pom-bridge-\(UUID().uuidString)", isDirectory: true)
    let claude = home.appendingPathComponent(".claude", isDirectory: true)
    try FileManager.default.createDirectory(at: claude, withIntermediateDirectories: true)
    defer { try? FileManager.default.removeItem(at: home) }

    checkEqual(
        "be nustatymų imamas numatytasis kelias",
        Bridge.statuslineURL(home: home).path,
        claude.appendingPathComponent("statusline.sh").path)

    checkEqual("nesant failo – neprijungta", Bridge.isConnected(home: home), false)

    let custom = claude.appendingPathComponent("mano-juosta.sh")
    try #"{"statusLine":{"type":"command","command":"~/.claude/mano-juosta.sh"}}"#
        .write(to: claude.appendingPathComponent("settings.json"), atomically: true, encoding: .utf8)
    try "#!/bin/bash\necho labas\n".write(to: custom, atomically: true, encoding: .utf8)
    checkEqual(
        "banguotė pakeičiama namų katalogu",
        Bridge.statuslineURL(home: home).path, custom.path)

    // Tilto scenarijus – antroji ryšio pusė. Be jo duomenys nepasiekia programos.
    let bridgeScript = Bridge.scriptURL(home: home)
    func createBridgeScript() throws {
        try FileManager.default.createDirectory(
            at: bridgeScript.deletingLastPathComponent(), withIntermediateDirectories: true)
        try "#!/bin/bash\n".write(to: bridgeScript, atomically: true, encoding: .utf8)
        try FileManager.default.setAttributes(
            [.posixPermissions: 0o755], ofItemAtPath: bridgeScript.path)
    }

    try createBridgeScript()
    checkEqual("be žymos – neprijungta", Bridge.isConnected(home: home), false)

    try "#!/bin/bash\n\(Bridge.marker)\necho labas\n"
        .write(to: custom, atomically: true, encoding: .utf8)
    checkEqual("su žyma ir scenarijumi – prijungta", Bridge.isConnected(home: home), true)

    try FileManager.default.removeItem(at: bridgeScript)
    checkEqual(
        "dingus tilto scenarijui – neprijungta, nors žymė liko",
        Bridge.isConnected(home: home), false)
    try createBridgeScript()

    // Komandoje gali būti vykdyklė ir argumentai. Anksčiau tokia komanda būdavo laikoma
    // failo keliu, todėl POM nerasdavo juostos, o diegimo scenarijus ją perrašydavo.
    checkEqual(
        "kelias ištraukiamas iš komandos su argumentais",
        Bridge.scriptPath(in: "bash ~/.claude/mano-juosta.sh --trumpai", home: home)?.path,
        custom.path)
    checkEqual(
        "kabutėmis apgaubtas kelias atpažįstamas",
        Bridge.scriptPath(in: "\"\(custom.path)\"", home: home)?.path, custom.path)
    checkEqual(
        "neegzistuojančio scenarijaus nespėliojama",
        Bridge.scriptPath(in: "node /nera/tokio/failo.js --x", home: home) == nil, true)
    checkEqual(
        "vien vykdyklės vardas keliu nelaikomas",
        Bridge.scriptPath(in: "bash", home: home) == nil, true)

    checkEqual(
        "jq randama pagal nurodytą kelią",
        Bridge.isJQAvailable(searchPaths: [bridgeScript.path]), true)
    checkEqual(
        "jq nerandama, kai jos nėra",
        Bridge.isJQAvailable(searchPaths: ["/nera/tokio/jq"]), false)

    do {
        _ = try Bridge.install(scriptURL: nil)
        failures.append("be scenarijaus turėjo mesti klaidą")
    } catch Bridge.InstallError.scriptMissing {
        check("trūkstamas scenarijus atpažįstamas", true)
    }

    let failing = home.appendingPathComponent("blogas.sh")
    try "echo 'nepavyko'\nexit 1\n".write(to: failing, atomically: true, encoding: .utf8)
    do {
        _ = try Bridge.install(scriptURL: failing)
        failures.append("nepavykęs scenarijus turėjo mesti klaidą")
    } catch Bridge.InstallError.failed(let output) {
        checkEqual("grąžinama scenarijaus išvestis", output, "nepavyko")
    }
} catch {
    failures.append("ryšio testas metė klaidą: \(error)")
}

// MARK: - Paleidimas prisijungus

do {
    let tmp = URL(fileURLWithPath: NSTemporaryDirectory())
        .appendingPathComponent("pom-login-\(UUID().uuidString)", isDirectory: true)
    try FileManager.default.createDirectory(at: tmp, withIntermediateDirectories: true)
    defer { try? FileManager.default.removeItem(at: tmp) }

    let plist = tmp.appendingPathComponent("lt.ponasobuolys.pom.plist")
    let item = LoginItem(
        plistURL: plist, executablePath: "/Applications/POM.app/Contents/MacOS/POM",
        bootoutOnRemove: false)

    checkEqual("iš pradžių išjungta", item.isEnabled, false)

    try item.setEnabled(true)
    checkEqual("įjungus aprašas atsiranda", item.isEnabled, true)

    let data = try Data(contentsOf: plist)
    let parsed =
        try PropertyListSerialization.propertyList(from: data, options: [], format: nil)
        as? [String: Any]
    checkEqual("aprašo pavadinimas", parsed?["Label"] as? String, "lt.ponasobuolys.pom")
    checkEqual(
        "nurodyta programos vieta", (parsed?["ProgramArguments"] as? [String])?.first,
        "/Applications/POM.app/Contents/MacOS/POM")
    checkEqual("paleidžiama prisijungus", parsed?["RunAtLoad"] as? Bool, true)

    try item.setEnabled(false)
    checkEqual("išjungus aprašas dingsta", item.isEnabled, false)

    let broken = LoginItem(plistURL: plist, executablePath: nil, bootoutOnRemove: false)
    do {
        try broken.setEnabled(true)
        failures.append("be programos vietos turėjo mesti klaidą")
    } catch LoginItem.LoginItemError.executableNotFound {
        check("be programos vietos metama aiški klaida", true)
    }
} catch {
    failures.append("paleidimo prisijungus testas metė klaidą: \(error)")
}

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

// MARK: - Limito lango pavadinimas

checkEqual("lango pavadinimas: savaitė", LTFormat.windowTitle(minutes: 10080), "7 dienų")
checkEqual("lango pavadinimas: penkios valandos", LTFormat.windowTitle(minutes: 300), "5 valandų")
checkEqual("lango pavadinimas: viena diena", LTFormat.windowTitle(minutes: 1440), "1 dienos")
checkEqual("lango pavadinimas: vienuolika dienų", LTFormat.windowTitle(minutes: 11 * 1440), "11 dienų")
checkEqual("lango pavadinimas: dvidešimt viena diena", LTFormat.windowTitle(minutes: 21 * 1440), "21 dienos")
checkEqual("lango pavadinimas: minutės", LTFormat.windowTitle(minutes: 45), "45 minučių")
checkEqual("lango pavadinimas: nežinoma trukmė", LTFormat.windowTitle(minutes: 0), "limitas")

// MARK: - Codex: atsakymo skaitymas

do {
    let json = """
    {"id":7,"result":{"rateLimits":{
      "limitId":"codex","limitName":null,
      "primary":{"usedPercent":5,"windowDurationMins":10080,"resetsAt":1788292169},
      "secondary":null,
      "credits":{"hasCredits":false,"unlimited":false,"balance":"0"},
      "planType":"prolite"},
     "rateLimitsByLimitId":{"codex_bengalfox":{
      "limitId":"codex_bengalfox",
      "primary":{"usedPercent":90,"windowDurationMins":300,"resetsAt":1787786496}}}}}
    """
    let snapshot = try CodexParser.parse(data: Data(json.utf8), capturedAt: date(500))
    checkClose("codex: procentai", snapshot.window.usedPercentage, 5)
    checkEqual("codex: lango trukmė", snapshot.windowMinutes, 10080)
    checkEqual("codex: atsistatymas", snapshot.window.resetsAt, date(1788292169))
    checkEqual("codex: fiksavimo laikas", snapshot.capturedAt, date(500))
} catch {
    failures.append("codex atsakymo skaitymas metė klaidą: \(error)")
}

// MARK: - Codex: papildomi rinkiniai nepainiojami su pagrindiniu

do {
    // `rateLimitsByLimitId` gali turėti didesnių reikšmių, bet rodomas tik pagrindinis
    // rinkinys. Kitaip skaičius šokinėtų priklausomai nuo to, kurį modelį naudojai.
    let json = """
    {"result":{"rateLimits":{"primary":{"usedPercent":5,"windowDurationMins":10080}},
     "rateLimitsByLimitId":{"kitas":{"primary":{"usedPercent":99,"windowDurationMins":10080}}}}}
    """
    let snapshot = try CodexParser.parse(data: Data(json.utf8), capturedAt: date(0))
    checkClose("codex: imamas pagrindinis rinkinys", snapshot.window.usedPercentage, 5)
    checkEqual("codex: atsistatymo laikas gali būti nežinomas", snapshot.window.resetsAt, nil)
} catch {
    failures.append("codex papildomų rinkinių testas metė klaidą: \(error)")
}

// MARK: - Codex: iš dviejų langų imamas ilgesnis

do {
    let json = """
    {"result":{"rateLimits":{
      "primary":{"usedPercent":12,"windowDurationMins":300,"resetsAt":1788000000},
      "secondary":{"usedPercent":34,"windowDurationMins":10080,"resetsAt":1788292169}}}}
    """
    let snapshot = try CodexParser.parse(data: Data(json.utf8), capturedAt: date(0))
    checkClose("codex: imamas ilgesnis langas", snapshot.window.usedPercentage, 34)
    checkEqual("codex: ilgesnio lango trukmė", snapshot.windowMinutes, 10080)
} catch {
    failures.append("codex dviejų langų testas metė klaidą: \(error)")
}

// MARK: - Codex: netinkami duomenys

do {
    _ = try CodexParser.parse(data: Data("sugadinta".utf8), capturedAt: date(0))
    failures.append("codex: sugadintas JSON turėjo mesti klaidą")
} catch {
    passed += 1
}

do {
    let json = #"{"result":{"rateLimits":null}}"#
    _ = try CodexParser.parse(data: Data(json.utf8), capturedAt: date(0))
    failures.append("codex: tuščios reikšmės turėjo mesti klaidą")
} catch CodexParser.ParseError.noLimits {
    passed += 1
} catch {
    failures.append("codex: tuščioms reikšmėms laukta noLimits, gauta \(error)")
}

do {
    let json = #"{"error":{"code":-32601,"message":"Method not found"}}"#
    _ = try CodexParser.parse(data: Data(json.utf8), capturedAt: date(0))
    failures.append("codex: klaidos atsakymas turėjo mesti klaidą")
} catch CodexParser.ParseError.rpcError(let message) {
    checkEqual("codex: klaidos žinutė perduodama", message, "Method not found")
} catch {
    failures.append("codex: klaidos atsakymui laukta rpcError, gauta \(error)")
}

do {
    // Langas be procentų yra bevertis: geriau klaida negu nulis, kurį vartotojas
    // palaikytų tikru skaičiumi.
    let json = #"{"result":{"rateLimits":{"primary":{"windowDurationMins":10080}}}}"#
    _ = try CodexParser.parse(data: Data(json.utf8), capturedAt: date(0))
    failures.append("codex: langas be procentų turėjo mesti klaidą")
} catch CodexParser.ParseError.noLimits {
    passed += 1
} catch {
    failures.append("codex: langui be procentų laukta noLimits, gauta \(error)")
}

// MARK: - Codex: išsaugotas failas

do {
    let tmp = URL(fileURLWithPath: NSTemporaryDirectory())
        .appendingPathComponent("pom-codex-\(UUID().uuidString)", isDirectory: true)
    try FileManager.default.createDirectory(at: tmp, withIntermediateDirectories: true)
    defer { try? FileManager.default.removeItem(at: tmp) }

    let file = tmp.appendingPathComponent("codex-snapshot.json")
    let store = CodexStore(fileURL: file)
    checkEqual("codex: nesant failo grąžinamas nulinis rezultatas", store.load() == nil, true)

    let original = CodexSnapshot(
        window: UsageWindow(usedPercentage: 7.5, resetsAt: date(1788292169)),
        windowMinutes: 10080,
        capturedAt: date(1787000000))
    try store.save(original)
    checkEqual("codex: išsaugota reikšmė perskaitoma", store.load(), original)

    try Data("sugadinta".utf8).write(to: file)
    checkEqual("codex: sugadintas failas negriauna programos", store.load() == nil, true)
} catch {
    failures.append("codex saugyklos testas metė klaidą: \(error)")
}

// MARK: - Codex: prieinamumas

do {
    let tmp = URL(fileURLWithPath: NSTemporaryDirectory())
        .appendingPathComponent("pom-codex-vieta-\(UUID().uuidString)", isDirectory: true)
    try FileManager.default.createDirectory(at: tmp, withIntermediateDirectories: true)
    defer { try? FileManager.default.removeItem(at: tmp) }

    let binary = tmp.appendingPathComponent("codex")
    let auth = tmp.appendingPathComponent("auth.json")

    checkEqual(
        "codex: be vykdomojo failo laikomas neįdiegtu",
        CodexLocator.availability(searchPaths: [binary.path], authFile: auth),
        CodexAvailability.notInstalled)

    try Data("#!/bin/bash\n".utf8).write(to: binary)
    try FileManager.default.setAttributes([.posixPermissions: 0o755], ofItemAtPath: binary.path)

    checkEqual(
        "codex: be rakto laikomas neprisijungusiu",
        CodexLocator.availability(searchPaths: [binary.path], authFile: auth),
        CodexAvailability.signedOut)

    try Data(#"{"auth_mode":"chatgpt","tokens":{"access_token":""}}"#.utf8).write(to: auth)
    checkEqual(
        "codex: tuščias raktas neprilygsta prisijungimui",
        CodexLocator.availability(searchPaths: [binary.path], authFile: auth),
        CodexAvailability.signedOut)

    try Data(#"{"auth_mode":"chatgpt","tokens":{"access_token":"abc"}}"#.utf8).write(to: auth)
    checkEqual(
        "codex: su raktu viskas paruošta",
        CodexLocator.availability(searchPaths: [binary.path], authFile: auth),
        CodexAvailability.ready(binary))

    try Data(#"{"OPENAI_API_KEY":"sk-abc"}"#.utf8).write(to: auth)
    checkEqual(
        "codex: API raktas taip pat tinka",
        CodexLocator.availability(searchPaths: [binary.path], authFile: auth),
        CodexAvailability.ready(binary))
} catch {
    failures.append("codex prieinamumo testas metė klaidą: \(error)")
}

// MARK: - Codex: tikras ryšys

// Ši patikra paleidžia tikrą Codex procesą, todėl priklauso nuo kompiuterio būklės.
// Įprastame paleidime ji praleidžiama, o rankiniu būdu įjungiama taip:
//   POM_CODEX_TEST=1 swift run pom-tests
if ProcessInfo.processInfo.environment["POM_CODEX_TEST"] == "1" {
    switch CodexLocator.availability() {
    case .notInstalled:
        print("· Codex nerastas, tikro ryšio patikra praleista")
    case .signedOut:
        print("· Codex neprisijungęs, tikro ryšio patikra praleista")
    case .ready(let executable):
        do {
            let snapshot = try CodexClient().fetch(executable: executable)
            check(
                "codex: tikras atsakymas turi procentus",
                snapshot.window.usedPercentage >= 0 && snapshot.window.usedPercentage <= 100,
                "gauta \(snapshot.window.usedPercentage)")
            check(
                "codex: tikras atsakymas turi lango trukmę", snapshot.windowMinutes > 0,
                "gauta \(snapshot.windowMinutes)")
            check("codex: tikras atsakymas turi planą", snapshot.planType != nil)
            let tokenUsage = try CodexClient().fetchUsage(executable: executable)
            check("codex: real account token buckets bounded", tokenUsage.days.count <= 30)
            check("codex: real token counts valid", tokenUsage.days.allSatisfy { $0.tokens >= 0 && UsageDay.date($0.day) != nil })
            print(
                "· Codex atsakė: \(Int(snapshot.window.usedPercentage)) % iš "
                    + LTFormat.windowTitle(minutes: snapshot.windowMinutes) + " lango; planas: "
                    + (SubscriptionPlan.codex(snapshot.planType) ?? snapshot.planType ?? "nežinomas"))
        } catch {
            failures.append("codex: tikras ryšys nepavyko: \(error)")
        }
    }
}


// MARK: - POM 2.1: scenarijų keliai, Fable ir planai

do {
    let home = FileManager.default.temporaryDirectory.appendingPathComponent("pom-command-\(UUID().uuidString)")
    try FileManager.default.createDirectory(at: home, withIntermediateDirectories: true)
    defer { try? FileManager.default.removeItem(at: home) }
    let script = home.appendingPathComponent("mano juosta.sh")
    try "#!/bin/bash\ninput=$(cat)\n".write(to: script, atomically: true, encoding: .utf8)
    for command in ["/bin/bash \"\(script.path)\" --trumpai", "bash '\(script.path)'",
                    "/usr/bin/env MODE=test /bin/bash -- \"\(script.path)\"", "\"\(script.path)\""] {
        checkEqual("scenarijus su kabutėmis ir vykdykle: \(command)",
                   Bridge.scriptPath(in: command, home: home), script)
    }
    checkEqual("kelias su pridengtu tarpu", Bridge.scriptPath(in: script.path.replacingOccurrences(of: " ", with: "\\ "), home: home), script)
    for command in ["/bin/bash", "/bin/bash -c '\(script.path)'", "bash \"\(script.path)",
                    "/bin/bash \"\(script.path)\"; echo blogai", "node /bin/bash", "$(echo /bin/bash)"] {
        checkEqual("neatpažinta komanda nevirsta svetimu failu: \(command)",
                   Bridge.scriptPath(in: command, home: home), nil)
    }
} catch { failures.append("komandos skaidymas: \(error)") }

do {
    let json = #"{"subscription_type":"max","rate_limits":{"five_hour":{"utilization":7},"seven_day":{"utilization":3},"limits":[{"kind":"weekly_scoped","percent":4,"resets_at":"2026-09-09T01:59:59.787952+00:00","scope":{"model":{"display_name":"Fable"}}},{"kind":"weekly_scoped","percent":90,"scope":{"model":{"display_name":"Opus"}}}]}}"#
    let snapshot = try UsageParser.parse(data: Data(json.utf8), source: .claudeCLI, capturedAt: date(10))
    checkClose("bendras savaitės limitas nepakeistas Fable", snapshot.sevenDay.usedPercentage, 3)
    checkClose("atskiras Fable iš limits masyvo", snapshot.fable?.usedPercentage ?? -1, 4)
    check("Fable ISO atsistatymo laikas perskaitytas", snapshot.fable?.resetsAt != nil)
    checkEqual("Claude plano tipas", snapshot.plan, "max")
    let modelScoped = #"{"five_hour":{"utilization":7},"seven_day":{"utilization":3},"model_scoped":[{"display_name":"Fable 5.1","utilization":6,"resets_at":null}]}"#
    let scoped = try UsageParser.parse(data: Data(modelScoped.utf8), source: .server, capturedAt: date(20))
    checkClose("Fable iš model_scoped", scoped.fable?.usedPercentage ?? -1, 6)
    let legacy = #"{"five_hour":{"used_percentage":7},"seven_day":{"used_percentage":3}}"#
    let without = try UsageParser.parse(data: Data(legacy.utf8), source: .statusline, capturedAt: date(30))
    checkEqual("nesantis Fable nėra nulis", without.fable, nil)
    let direct = #"{"five_hour":{"used_percentage":7},"seven_day":{"used_percentage":3},"seven_day_fable":{"used_percentage":0}}"#
    let zero = try UsageParser.parse(data: Data(direct.utf8), source: .statusline, capturedAt: date(30))
    checkClose("tikras Fable nulis išlieka", zero.fable?.usedPercentage ?? -1, 0)
    let folder = FileManager.default.temporaryDirectory.appendingPathComponent("pom-fable-\(UUID().uuidString)")
    defer { try? FileManager.default.removeItem(at: folder) }
    let store = SnapshotStore(fileURL: folder.appendingPathComponent("usage.json"), source: .claudeCLI)
    try store.save(snapshot)
    checkEqual("Fable ir planas išlieka po išsaugojimo", store.load(), snapshot)
} catch { failures.append("Fable skaitymas ir išsaugojimas: \(error)") }

checkEqual("Claude Max 20x", SubscriptionPlan.claude(type: "max", tier: "default_claude_max_20x"), "Max 20x")
checkEqual("Claude Max 5x", SubscriptionPlan.claude(type: "max", tier: "default_claude_max_5x"), "Max 5x")
checkEqual("nežinomas Max daugiklis neišgalvojamas", SubscriptionPlan.claude(type: "max", tier: nil), "Max")
checkEqual("ChatGPT Pro 5x", SubscriptionPlan.codex("prolite"), "ChatGPT Pro 5x")
checkEqual("ChatGPT Pro 20x", SubscriptionPlan.codex("pro"), "ChatGPT Pro 20x")
checkEqual("nežinomas planas neišgalvojamas", SubscriptionPlan.codex("new-plan"), nil)

do {
    let data = Data(#"{"result":{"rateLimits":{"primary":{"usedPercent":99,"windowDurationMins":10080}},"rateLimitsByLimitId":{"codex":{"planType":"prolite","primary":{"usedPercent":12,"windowDurationMins":10080}},"spark":{"primary":{"usedPercent":80,"windowDurationMins":10080}}}}}"#.utf8)
    let snapshot = try CodexParser.parse(data: data, capturedAt: date(10))
    checkClose("Codex renkamas įvardytas pagrindinis rinkinys", snapshot.window.usedPercentage, 12)
    checkEqual("Codex planas perskaitomas", snapshot.planType, "prolite")
    let folder = FileManager.default.temporaryDirectory.appendingPathComponent("pom-plan-\(UUID().uuidString)")
    defer { try? FileManager.default.removeItem(at: folder) }
    let store = CodexStore(fileURL: folder.appendingPathComponent("codex.json"))
    try store.save(snapshot)
    checkEqual("Codex planas išlieka po perkrovimo", store.load(), snapshot)
} catch { failures.append("Codex plano išsaugojimas: \(error)") }

var fableTracker = AlertTracker(thresholds: [80, 95])
checkEqual("bendro limito perspėjimas", fableTracker.check(window: .sevenDay, percentage: 81, resetsAt: date(500)), 80)
checkEqual("Fable perspėjimas atskiras", fableTracker.check(window: .fable, percentage: 81, resetsAt: date(500)), 80)
checkEqual("Fable perspėjimas nekartojamas", fableTracker.check(window: .fable, percentage: 82, resetsAt: date(500)), nil)

if ProcessInfo.processInfo.environment["POM_CLAUDE_TEST"] == "1" {
    if let executable = ClaudeClient.executable {
        do {
            let snapshot = try ClaudeClient().fetch(executable: executable)
            check("Claude gyvas atsakymas", snapshot.fiveHour.usedPercentage >= 0)
            check("Fable gyvas atsakymas", snapshot.fable != nil)
            check("Claude planas gyvame atsakyme", snapshot.plan != nil)
            print("· Claude ir Fable limitai gauti; planas: \(SubscriptionPlan.claudeLocal() ?? snapshot.plan ?? "nežinomas")")
        } catch { failures.append("Claude gyvas ryšys: \(error)") }
    } else { failures.append("Claude gyvai patikrai nerasta") }
}


// MARK: - Claude valdymo protokolas ir proceso uždarymas

do {
    let root = FileManager.default.temporaryDirectory.appendingPathComponent("pom-client-\(UUID().uuidString)")
    try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
    defer { try? FileManager.default.removeItem(at: root) }
    let executable = root.appendingPathComponent("claude")
    let fixture = #"""
    #!/bin/bash
    IFS= read -r first
    case "$first" in *initialize*) ;; *) exit 1 ;; esac
    printf '%s\n' '{"type":"control_response","response":{"subtype":"success","request_id":"pom-init","response":{}}}'
    IFS= read -r second
    case "$second" in *get_usage*) ;; *) exit 1 ;; esac
    printf '%s\n' '{"type":"control_response","response":{"subtype":"success","request_id":"pom-usage","response":{"rate_limits_available":true,"subscription_type":"max","rate_limits":{"five_hour":{"utilization":7},"seven_day":{"utilization":3},"model_scoped":[{"display_name":"Fable","utilization":4}]}}}}'
    while IFS= read -r line; do :; done
    """#
    try fixture.write(to: executable, atomically: true, encoding: .utf8)
    try FileManager.default.setAttributes([.posixPermissions: 0o755], ofItemAtPath: executable.path)
    let snapshot = try ClaudeClient(timeout: 2).fetch(executable: executable)
    checkClose("Claude protokolas gauna Fable", snapshot.fable?.usedPercentage ?? -1, 4)
    let rejected = "#!/bin/bash\nIFS= read -r line\nprintf '%s\\n' '{\"type\":\"control_response\",\"response\":{\"subtype\":\"error\",\"request_id\":\"pom-init\",\"error\":\"unsupported\"}}'\n"
    try rejected.write(to: executable, atomically: true, encoding: .utf8)
    do {
        _ = try ClaudeClient(timeout: 2).fetch(executable: executable)
        failures.append("Claude protokolo klaida turėjo būti perduota")
    } catch ClaudeClient.ClientError.rejected(let message) {
        checkEqual("Claude protokolo klaida perduota", message, "unsupported")
    }
    try "#!/bin/bash\ntrap '' TERM\nwhile true; do :; done\n".write(to: executable, atomically: true, encoding: .utf8)
    let started = Date()
    do {
        _ = try ClaudeClient(timeout: 0.2).fetch(executable: executable)
        failures.append("užstrigęs Claude turėjo būti nutrauktas")
    } catch ClaudeClient.ClientError.timedOut {
        check("Claude proceso laiko riba galioja net ignoruojant TERM", Date().timeIntervalSince(started) < 3)
    }
} catch { failures.append("Claude proceso patikra: \(error)") }

// MARK: - Claude prisijungimas per Terminal

do {
    let root = FileManager.default.temporaryDirectory.appendingPathComponent("pom-login-\(UUID().uuidString)")
    try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
    defer { try? FileManager.default.removeItem(at: root) }
    let executable = root.appendingPathComponent("claude ' $(touch injected)")
    let fixture = "#!/bin/bash\n[ \"$#\" -eq 2 ] && [ \"$1\" = auth ] && [ \"$2\" = login ] || exit 91\nexit 0\n"
    try fixture.write(to: executable, atomically: true, encoding: .utf8)
    try FileManager.default.setAttributes([.posixPermissions: 0o700], ofItemAtPath: executable.path)
    let session = try CLISignInSession.prepare(executable: executable, parent: root)
    checkEqual("prisijungimas laukia tikro komandos rezultato", session.completionStatus(), nil)
    let permissions = try FileManager.default.attributesOfItem(atPath: session.directory.path)[.posixPermissions] as? Int
    checkEqual("prisijungimo katalogas privatus", permissions, 0o700)
    let process = Process()
    process.executableURL = URL(fileURLWithPath: "/bin/bash")
    process.arguments = [session.commandURL.path]
    process.currentDirectoryURL = root
    process.standardOutput = FileHandle.nullDevice
    process.standardError = FileHandle.nullDevice
    try process.run(); process.waitUntilExit()
    checkEqual("prisijungimo komanda sėkminga su sudėtingu keliu", process.terminationStatus, 0)
    checkEqual("sėkmingas prisijungimas patvirtinamas", session.completionStatus(), 0)
    check("prisijungimo kelias nevykdomas kaip shell kodas", !FileManager.default.fileExists(atPath: root.appendingPathComponent("injected").path))
    session.cleanUp()
    check("prisijungimo laikini failai pašalinami", !FileManager.default.fileExists(atPath: session.directory.path))

    try "#!/bin/bash\nexit 7\n".write(to: executable, atomically: true, encoding: .utf8)
    let failed = try CLISignInSession.prepare(executable: executable, parent: root)
    let failure = Process()
    failure.executableURL = URL(fileURLWithPath: "/bin/bash")
    failure.arguments = [failed.commandURL.path]
    failure.standardOutput = FileHandle.nullDevice
    failure.standardError = FileHandle.nullDevice
    try failure.run(); failure.waitUntilExit()
    checkEqual("nepavykęs prisijungimas nelaikomas sėkme", failed.completionStatus(), 7)
    checkEqual("nepavykęs prisijungimas išsaugo exit code", failure.terminationStatus, 7)
    try "invalid".write(to: failed.resultURL, atomically: true, encoding: .utf8)
    checkEqual("blogas prisijungimo rezultatas nelaikomas sėkme", failed.completionStatus(), nil)

    try "#!/bin/bash\n[ \"$#\" -eq 1 ] && [ \"$1\" = login ] || exit 91\nexit 0\n".write(to: executable, atomically: true, encoding: .utf8)
    let codexSession = try CLISignInSession.prepare(executable: executable, provider: .codex, parent: root)
    checkEqual("ChatGPT prisijungimas turi atskirą Terminal pavadinimą", codexSession.commandURL.lastPathComponent, "Sign in to ChatGPT.command")
    let codexLogin = Process()
    codexLogin.executableURL = URL(fileURLWithPath: "/bin/bash")
    codexLogin.arguments = [codexSession.commandURL.path]
    codexLogin.standardOutput = FileHandle.nullDevice
    codexLogin.standardError = FileHandle.nullDevice
    try codexLogin.run(); codexLogin.waitUntilExit()
    checkEqual("Codex prisijungimas naudoja login be Claude auth argumento", codexLogin.terminationStatus, 0)
    checkEqual("ChatGPT prisijungimo sėkmė patvirtinama", codexSession.completionStatus(), 0)
} catch { failures.append("Claude prisijungimo eiga: \(error)") }

// MARK: - Extra usage, history and recovery

do {
    let now = date(1_800_000_000)
    let json = #"{"rate_limits":{"five_hour":{"utilization":8},"seven_day":{"utilization":15},"extra_usage":{"is_enabled":true,"used_credits":1234,"monthly_limit":5000,"utilization":24.68,"currency":"USD","decimal_places":2}}}"#
    let extra = try UsageParser.parse(data: Data(json.utf8), source: .claudeCLI, capturedAt: now)
    checkEqual("extra: preserve minor units", extra.extraUsage?.used, 1234)
    checkEqual("extra: explicit currency scale", extra.extraUsage?.decimalPlaces, 2)
    let unknownJSON = json.replacingOccurrences(of: "1234", with: "null").replacingOccurrences(of: "\"decimal_places\":2", with: "\"decimal_places\":null")
    let unknown = try UsageParser.parse(data: Data(unknownJSON.utf8), source: .claudeCLI, capturedAt: now)
    checkEqual("extra: null amount stays unknown", unknown.extraUsage?.used, nil)
    checkEqual("extra: missing scale not guessed", unknown.extraUsage?.decimalPlaces, nil)
    let dir = FileManager.default.temporaryDirectory.appendingPathComponent("pom-extra-tests-\(UUID())")
    defer { try? FileManager.default.removeItem(at: dir) }
    let store = SnapshotStore(fileURL: dir.appendingPathComponent("claude.json"), source: .claudeCLI)
    try store.save(extra)
    checkEqual("extra: Claude cache round trip", store.load()?.extraUsage, extra.extraUsage)
    let codexJSON = #"{"result":{"ordinaryUsageAllowed":true,"rateLimitsByLimitId":{"codex":{"primary":{"usedPercent":20,"windowDurationMins":300},"secondary":{"usedPercent":55,"windowDurationMins":10080},"credits":{"balance":"125.5","hasCredits":true,"unlimited":false},"individualLimit":{"limit":"500","used":"100","remainingPercent":80,"resetsAt":1800001000},"spendControlReached":false}},"rateLimitResetCredits":{"availableCount":2,"credits":[{"status":"available","expiresAt":1800002000},{"status":"redeemed","expiresAt":1800000500}]}}}"#
    let codex = try CodexParser.parse(data: Data(codexJSON.utf8), capturedAt: now)
    checkEqual("extra: Codex credit balance is not currency", codex.additionalUsage.credits?.balance, "125.5")
    checkEqual("extra: monthly spend limit", codex.additionalUsage.spendLimit?.remainingPercent, 80)
    checkEqual("extra: reset credits", codex.additionalUsage.resetCredits, 2)
    checkEqual("extra: only available expiry", codex.additionalUsage.nextResetCreditExpiry, date(1800002000))
    checkEqual("extra: backend availability", codex.ordinaryUsageAllowed, true)
    let cs = CodexStore(fileURL: dir.appendingPathComponent("codex.json"))
    try cs.save(codex)
    checkEqual("extra: Codex cache round trip", cs.load()?.additionalUsage, codex.additionalUsage)
    checkEqual("extra: availability survives restart", cs.load()?.ordinaryUsageAllowed, true)

    var history = UsageHistory()
    func point(_ time: Date, _ percent: Double, _ reset: Date? = nil) -> HistoryPoint {
        HistoryPoint(series: .claudeSession, capturedAt: time, percentage: percent, resetsAt: reset)
    }
    check("history: old samples rejected", !history.append(point(now.addingTimeInterval(-31*86400), 25), now: now))
    check("history: future samples rejected", !history.append(point(now.addingTimeInterval(3600), 25), now: now))
    check("history: non-finite samples rejected", !history.append(point(now, .infinity), now: now))
    check("history: fresh sample saved", history.append(point(now.addingTimeInterval(-120), 95, now), now: now))
    check("history: duplicate timestamp rejected", !history.append(point(now.addingTimeInterval(-120), 95, now), now: now))
    check("history: older source rejected", !history.append(point(now.addingTimeInterval(-150), 99, now), now: now))
    check("history: within-minute exhaustion preserved", history.append(point(now.addingTimeInterval(-100), 100, now), now: now))
    check("history: reset preserved", history.append(point(now, 0, now.addingTimeInterval(18000)), now: now))
    checkEqual("history: reset breaks chart line", history.segments(for: .claudeSession, since: now.addingTimeInterval(-86400)).count, 2)
    try history.save(to: dir.appendingPathComponent("history.json"))
    checkEqual("history: survives restart", UsageHistory.load(from: dir.appendingPathComponent("history.json"), now: now).points, history.points)
    checkEqual("history: expired history pruned on load", UsageHistory.load(from: dir.appendingPathComponent("history.json"), now: now.addingTimeInterval(31*86400)).points.count, 0)
    try Data("corrupt".utf8).write(to: dir.appendingPathComponent("history.json"))
    checkEqual("history: corrupt file is safe", UsageHistory.load(from: dir.appendingPathComponent("history.json")).points.count, 0)
    var recovery = RecoveryTracker()
    let exhausted = UsageWindow(usedPercentage: 100, resetsAt: now)
    let fresh = UsageWindow(usedPercentage: 4, resetsAt: now.addingTimeInterval(18000))
    check("recovery: initial exhausted does not notify", !recovery.observe(id: "claude", window: exhausted, capturedAt: now.addingTimeInterval(-60), now: now))
    check("recovery: no notification from cached response", !recovery.observe(id: "claude", window: fresh, capturedAt: now.addingTimeInterval(-60), now: now))
    var restored = try JSONDecoder().decode(RecoveryTracker.self, from: JSONEncoder().encode(recovery))
    check("recovery: persisted exhausted state recovers", restored.observe(id: "claude", window: fresh, capturedAt: now, now: now))
    check("recovery: no duplicate notification", !restored.observe(id: "claude", window: fresh, capturedAt: now.addingTimeInterval(60), now: now.addingTimeInterval(60)))
    _ = recovery.observe(id: "codex", window: exhausted, capturedAt: now.addingTimeInterval(-60), now: now)
    check("recovery: unknown Codex permission is not recovery", !recovery.observe(id: "codex", window: fresh, capturedAt: now, now: now, requiresAvailability: true))
    check("recovery: blocked Codex is not recovery", !recovery.observe(id: "codex", window: fresh, capturedAt: now.addingTimeInterval(10), now: now.addingTimeInterval(10), ordinaryUsageAllowed: false, requiresAvailability: true))
    check("recovery: later explicit Codex recovery", recovery.observe(id: "codex", window: fresh, capturedAt: now.addingTimeInterval(20), now: now.addingTimeInterval(20), ordinaryUsageAllowed: true, requiresAvailability: true))
    check("recovery: stale data does not notify", !recovery.observe(id: "stale", window: exhausted, capturedAt: now.addingTimeInterval(-3600), now: now))
    checkEqual("language: Lithuanian system", AppLanguage.system.resolved(preferredLanguages: ["lt-LT", "en-US"]), .lt)
    checkEqual("language: unsupported system falls back to English", AppLanguage.system.resolved(preferredLanguages: ["fr-FR"]), .en)
    checkEqual("language: explicit overrides system", AppLanguage.en.resolved(preferredLanguages: ["lt-LT"]), .en)
    checkEqual("language: English period", AppLanguage.en.windowTitle(minutes: 300), "5-hour")
    checkEqual("language: Lithuanian period", AppLanguage.lt.windowTitle(minutes: 10080), "7 dienų")
} catch { failures.append("2.2 usage tests: \(error)") }

// MARK: - Daily tokens and incremental local indexing

do {
    let now = UsageDay.date("2026-09-06")!.addingTimeInterval(12 * 3600)
    checkEqual("tokens: seven calendar dates including today", UsageDay.keys(days: 7, now: now).first, "2026-08-31")
    checkEqual("tokens: thirty calendar dates including today", UsageDay.keys(days: 30, now: now).first, "2026-08-08")
    check("tokens: impossible date rejected", UsageDay.date("2026-02-30") == nil)
    let response = Data(#"{"result":{"dailyUsageBuckets":[{"startDate":"2026-09-06","tokens":42},{"startDate":"2026-08-08","tokens":25},{"startDate":"2026-08-07","tokens":90},{"startDate":"2026-09-07","tokens":80}]}}"#.utf8)
    let parsed = try TokenUsageSnapshot.parseCodex(response, now: now)
    checkEqual("tokens: Codex only retained days", parsed.days.count, 2)
    checkEqual("tokens: period total independent of limits", parsed.total(days: 7, now: now), 42)
    checkEqual("tokens: thirty day sum", parsed.total(days: 30, now: now), 67)
    for invalid in [#"{"error":{"code":-32601}}"#, #"{"result":{}}"#,
                    #"{"result":{"dailyUsageBuckets":[{"startDate":"2026-09-06","tokens":-1}]}}"#,
                    #"{"result":{"dailyUsageBuckets":[{"startDate":"2026-09-06","tokens":2},{"startDate":"2026-09-06","tokens":3}]}}"#] {
        check("tokens: invalid account data stays unavailable", (try? TokenUsageSnapshot.parseCodex(Data(invalid.utf8), now: now)) == nil)
    }
    let empty = try TokenUsageSnapshot.parseCodex(Data(#"{"result":{"dailyUsageBuckets":[]}}"#.utf8), now: now)
    checkEqual("tokens: successful empty account means zero", empty.total(days: 7, now: now), 0)

    let dir = FileManager.default.temporaryDirectory.appendingPathComponent("pom-tokens-\(UUID().uuidString)")
    defer { try? FileManager.default.removeItem(at: dir) }
    let root = dir.appendingPathComponent("projects")
    try FileManager.default.createDirectory(at: root.appendingPathComponent("child/subagents"), withIntermediateDirectories: true)
    let file = root.appendingPathComponent("session.jsonl")
    let database = dir.appendingPathComponent("index.sqlite")
    func record(_ id: String, output: Int, time: String = "2026-09-06T10:00:00.000Z") -> Data {
        Data("{\"type\":\"assistant\",\"timestamp\":\"\(time)\",\"message\":{\"id\":\"\(id)\",\"content\":\"PRIVATE-PROMPT-NEVER-SAVE\",\"usage\":{\"input_tokens\":10,\"output_tokens\":\(output),\"cache_creation_input_tokens\":20,\"cache_read_input_tokens\":30,\"cache_creation\":{\"ephemeral_5m_input_tokens\":20}}}}\n".utf8)
    }
    func append(_ data: Data, to url: URL) throws {
        let h = try FileHandle(forWritingTo: url); defer { try? h.close() }
        try h.seekToEnd(); try h.write(contentsOf: data)
    }
    func finish(_ index: ClaudeTokenIndexer, budget: Int = 1024) throws -> ClaudeTokenIndexer.Batch {
        var batch = try index.scanBatch(now: now, maxBytes: budget, maxSeconds: 1)
        var passes = 0
        while !batch.complete {
            check("tokens: byte budget bounded", batch.bytesRead <= budget)
            batch = try index.scanBatch(now: now, maxBytes: budget, maxSeconds: 1)
            passes += 1
            if passes > 10000 { throw ClaudeTokenIndexer.IndexError.database }
        }
        return batch
    }
    try (record("one", output: 1) + record("one", output: 7) + record("two", output: 3)).write(to: file)
    try record("one", output: 7).write(to: root.appendingPathComponent("copy.jsonl"))
    try record("subagent", output: 5).write(to: root.appendingPathComponent("child/subagents/agent.jsonl"))
    var index: ClaudeTokenIndexer? = try ClaudeTokenIndexer(root: root, database: database)
    try index!.begin(now: now)
    let first = try finish(index!)
    checkEqual("tokens: duplicates, streaming maxima, caches and subagents", first.snapshot.total(days: 7, now: now), 195)
    try index!.begin(now: now)
    let idle = try index!.scanBatch(now: now)
    checkEqual("tokens: unchanged logs cause zero content reads", idle.bytesRead, 0)
    check("tokens: idle discovery complete", idle.complete)
    index = nil
    index = try ClaudeTokenIndexer(root: root, database: database)
    try index!.begin(now: now)
    checkEqual("tokens: restart reuses offsets", try index!.scanBatch(now: now).bytesRead, 0)
    let partial = record("partial", output: 4)
    try append(partial.prefix(80), to: file)
    try index!.begin(now: now)
    checkEqual("tokens: incomplete JSON is deferred", try finish(index!).snapshot.total(days: 7, now: now), 195)
    try append(partial.dropFirst(80), to: file)
    try index!.begin(now: now)
    checkEqual("tokens: completed append counted once", try finish(index!).snapshot.total(days: 7, now: now), 259)
    try record("replacement", output: 6).write(to: file, options: .atomic)
    try index!.begin(now: now)
    checkEqual("tokens: replacement preserves previously observed usage", try finish(index!).snapshot.total(days: 7, now: now), 325)
    try record("truncate", output: 2).write(to: file)
    try index!.begin(now: now)
    checkEqual("tokens: truncated file reindexed", try finish(index!).snapshot.total(days: 7, now: now), 387)
    try append(record("utc", output: 1, time: "2026-09-07T01:00:00+03:00"), to: file)
    try append(record("expired", output: 99, time: "2026-08-07T23:00:00Z"), to: file)
    try index!.begin(now: now)
    checkEqual("tokens: UTC bucket and retention", try finish(index!).snapshot.total(days: 7, now: now), 448)
    let long = root.appendingPathComponent("long.jsonl")
    try (Data(repeating: 65, count: ClaudeTokenIndexer.maximumLineBytes + 1) + Data([10]) + record("after-long", output: 9)).write(to: long)
    try index!.begin(now: now)
    let oversized = try finish(index!, budget: 1024 * 1024)
    checkEqual("tokens: oversized line warned", oversized.skippedLines, 1)
    checkEqual("tokens: valid data after large line retained", oversized.snapshot.total(days: 7, now: now), 517)
    // Restart while reading a record, before the newline has been committed.
    try append(record("restart-mid-line", output: 11), to: file)
    try index!.begin(now: now)
    _ = try index!.scanBatch(now: now, maxBytes: 40, maxSeconds: 1)
    index = nil; index = try ClaudeTokenIndexer(root: root, database: database)
    try index!.begin(now: now)
    checkEqual("tokens: interrupted import resumes without loss or duplication", try finish(index!).snapshot.total(days: 7, now: now), 588)
    let bytes = try Data(contentsOf: database)
    check("tokens: cache contains no prompts", bytes.range(of: Data("PRIVATE-PROMPT-NEVER-SAVE".utf8)) == nil)
    check("tokens: cache contains no raw identifiers", bytes.range(of: Data("restart-mid-line".utf8)) == nil)
    try index!.begin(now: now.addingTimeInterval(31 * 86400))
    checkEqual("tokens: expired counts removed", try index!.scanBatch(now: now.addingTimeInterval(31 * 86400)).snapshot.days.count, 0)
    let missing = try ClaudeTokenIndexer(root: dir.appendingPathComponent("absent"), database: dir.appendingPathComponent("missing.sqlite"))
    try missing.begin(now: now)
    check("tokens: missing sessions unavailable, not invented zero", try !missing.scanBatch(now: now).available)
} catch { failures.append("token history: \(error)") }

// MARK: - Paramos priminimų dažnis ir versijų kaita

do {
    let now = date(1_800_000_000)
    var policy = SupportReminderPolicy()
    checkEqual("support: first launch", policy.recordLaunch(version: "2.2.3", now: now), .welcome)
    policy = try JSONDecoder().decode(SupportReminderPolicy.self, from: JSONEncoder().encode(policy))
    check("support: relaunch after a month stays quiet", policy.recordLaunch(version: "2.2.3", now: now.addingTimeInterval(30 * 86400)) == nil)
    check("support: rapid patch is skipped", policy.recordLaunch(version: "2.2.4", now: now.addingTimeInterval(86400)) == nil)
    check("support: skipped patch never nags later", policy.recordLaunch(version: "2.2.4", now: now.addingTimeInterval(8 * 86400)) == nil)
    checkEqual("support: numeric version comparison and seven-day boundary", policy.recordLaunch(version: "2.2.10", now: now.addingTimeInterval(7 * 86400)), .update)
    check("support: downgrade stays quiet", policy.recordLaunch(version: "2.2.3", now: now.addingTimeInterval(40 * 86400)) == nil)
    check("support: reinstalling highest version stays quiet", policy.recordLaunch(version: "2.2.10", now: now.addingTimeInterval(40 * 86400)) == nil)
    check("support: clock moved backwards stays quiet", policy.recordLaunch(version: "2.3.1", now: now.addingTimeInterval(-86400)) == nil)
    checkEqual("support: later update recovers normally", policy.recordLaunch(version: "2.3.2", now: now.addingTimeInterval(50 * 86400)), .update)
    let saved = policy
    check("support: development builds ignored", policy.recordLaunch(version: "dev", now: now.addingTimeInterval(60 * 86400)) == nil)
    checkEqual("support: invalid version leaves state unchanged", policy, saved)
} catch { failures.append("support reminders: \(error)") }

// MARK: - Portable history reports: trust boundary for future store/mobile imports

do {
    let now = date(1_800_000_000)
    let key = UsageDay.key(now)
    let local = UsageHistoryReport.Entry(source: .claudeCodeLocal, collectionStatus: .complete,
                                        snapshot: .init(days: [.init(day: key, tokens: 123)], updatedAt: now))
    let account = UsageHistoryReport.Entry(source: .codexAccount, collectionStatus: .refreshFailed,
                                          snapshot: .init(days: [.init(day: key, tokens: 456)], updatedAt: now))
    let report = try UsageHistoryReport(generatedAt: now, entries: [local, account])
    let encoded = try report.encoded()
    let decoded = try UsageHistoryReport.decode(encoded)
    checkEqual("report: round trip preserves source and stale status", decoded, report)
    checkEqual("report: account totals are not added to local totals", decoded.entries[1].snapshot.total(days: 7, now: now), 456)
    check("report: small payload", encoded.count < 4096)
    let text = String(decoding: encoded, as: UTF8.self)
    check("report: dates are portable ISO strings", text.contains("2027-01-15T08:00:00Z"))
    check("report: local source is explicit", text.contains("claude_code_local"))

    func rejects(_ name: String, _ mutate: (inout [String: Any]) -> Void) throws {
        var object = try JSONSerialization.jsonObject(with: encoded) as! [String: Any]
        mutate(&object)
        do {
            _ = try UsageHistoryReport.decode(JSONSerialization.data(withJSONObject: object))
            check(name, false)
        } catch { check(name, true) }
    }
    try rejects("report: unknown schema rejected") { $0["schemaVersion"] = 2 }
    try rejects("report: no sources rejected") { $0["entries"] = [] }
    try rejects("report: duplicate account reports rejected") {
        let entry = ($0["entries"] as! [[String: Any]])[1]
        $0["entries"] = [entry, entry]
    }
    try rejects("report: unknown Claude account source rejected") {
        var entries = $0["entries"] as! [[String: Any]]
        entries[0]["source"] = "claude_account"
        $0["entries"] = entries
    }
    try rejects("report: invalid tokens rejected") {
        var entries = $0["entries"] as! [[String: Any]]
        var snapshot = entries[0]["snapshot"] as! [String: Any]
        snapshot["days"] = [["day": key, "tokens": -1]]
        entries[0]["snapshot"] = snapshot; $0["entries"] = entries
    }
    try rejects("report: overflow-sized totals rejected") {
        var entries = $0["entries"] as! [[String: Any]]
        var snapshot = entries[0]["snapshot"] as! [String: Any]
        snapshot["days"] = [["day": key, "tokens": Int64.max]]
        entries[0]["snapshot"] = snapshot; $0["entries"] = entries
    }
    try rejects("report: duplicate day rejected") {
        var entries = $0["entries"] as! [[String: Any]]
        var snapshot = entries[0]["snapshot"] as! [String: Any]
        snapshot["days"] = [["day": key, "tokens": 1], ["day": key, "tokens": 2]]
        entries[0]["snapshot"] = snapshot; $0["entries"] = entries
    }
    try rejects("report: impossible date rejected") { $0["generatedAt"] = "2027-02-30T00:00:00Z" }
    try rejects("report: snapshot after export rejected") { $0["generatedAt"] = "2026-01-01T00:00:00Z" }
    try rejects("report: missing collection status rejected") {
        var entries = $0["entries"] as! [[String: Any]]
        entries[0].removeValue(forKey: "collectionStatus"); $0["entries"] = entries
    }
    do {
        _ = try UsageHistoryReport.decode(Data(repeating: 32, count: UsageHistoryReport.maximumBytes + 1))
        check("report: oversized payload rejected before decoding", false)
    } catch { checkEqual("report: oversized payload rejected before decoding", error as? UsageHistoryReport.ReportError, .tooLarge) }
    var extra = try JSONSerialization.jsonObject(with: encoded) as! [String: Any]
    extra["prompt"] = "PRIVATE-EXTRA-FIELD"
    let sanitized = try UsageHistoryReport.decode(JSONSerialization.data(withJSONObject: extra)).encoded()
    check("report: unknown private content not retained", !String(decoding: sanitized, as: UTF8.self).contains("PRIVATE-EXTRA-FIELD"))
    let partial = UsageHistoryReport.Entry(source: .claudeCodeLocal, collectionStatus: .partial, snapshot: local.snapshot)
    let partialReport = try UsageHistoryReport(generatedAt: now, entries: [partial])
    checkEqual("report: partial collection remains partial after transfer", try UsageHistoryReport.decode(partialReport.encoded()).entries[0].collectionStatus, .partial)
} catch { failures.append("portable history reports: \(error)") }

// MARK: - Cursor and Grok Bot usage contracts (synthetic data only)

do {
    let captured = date(1_790_000_000)
    func parse(_ json: String) throws -> ProviderUsageSnapshot {
        try CursorUsageParser.parse(Data(json.utf8),
            planData: Data(#"{"planInfo":{"includedUsagePeriod":"INCLUDED_USAGE_PERIOD_MONTHLY"}}"#.utf8), capturedAt: captured)
    }
    let split = try parse("""
        {"billingCycleEnd":"1791000000000","planUsage":{"autoPercentUsed":0,"apiPercentUsed":73.5},
         "spendLimitUsage":{"individualUsed":125,"individualLimit":"5000"}}
        """)
    checkEqual("Cursor: independent buckets", split.meters.map(\.kind), [.auto, .api])
    checkClose("Cursor: explicit zero is valid", split.meters[0].window.usedPercentage, 0)
    checkClose("Cursor: model percentage", split.meters[1].window.usedPercentage, 73.5)
    checkEqual("Cursor: millisecond reset", split.meters[0].window.resetsAt, date(1_791_000_000))
    checkEqual("Cursor: original capture date", split.capturedAt, captured)
    checkEqual("Cursor: cents kept separate", split.onDemand, .init(usedCents: 125, limitCents: 5000))
    let legacy = try parse("""
        {"billingCycleEnd":1791000000000,"planUsage":{"includedSpend":500,"limit":2000}}
        """)
    checkClose("Cursor: amount-derived included usage", legacy.meters[0].window.usedPercentage, 25)
    checkEqual("Cursor: numeric protobuf timestamp", legacy.meters[0].window.resetsAt, date(1_791_000_000))
    let weekly = try CursorUsageParser.parse(Data(#"{"billingCycleEnd":"1791000000000","planUsage":{"totalPercentUsed":15}}"#.utf8),
        planData: Data(#"{"planInfo":{"planName":"Super","includedUsagePeriod":2,"includedUsageResetsAt":"1790500000000"}}"#.utf8), capturedAt: captured)
    checkEqual("Cursor: weekly reset is not monthly billing date", weekly.meters[0].window.resetsAt, date(1_790_500_000))
    checkEqual("Cursor: plan name from source", weekly.planName, "Super")
    let unknownPeriod = try CursorUsageParser.parse(Data(#"{"billingCycleEnd":"1791000000000","planUsage":{"totalPercentUsed":15}}"#.utf8), capturedAt: captured)
    checkEqual("Cursor: unknown period does not assume a billing-date reset", unknownPeriod.meters[0].window.resetsAt, nil)
    let zero = try parse(#"{"planUsage":{"limit":2000}}"#)
    checkClose("Cursor: omitted nonoptional protobuf spend defaults to zero", zero.meters[0].window.usedPercentage, 0)
    let percentOnly = try parse(#"{"planUsage":{"totalPercentUsed":103}}"#)
    checkClose("Cursor: overage retained", percentOnly.meters[0].window.usedPercentage, 103)
    checkEqual("Cursor: missing reset remains unknown", percentOnly.meters[0].window.resetsAt, nil)
    let spendOnly = try parse(#"{"spendLimitUsage":{"individualUsed":321}}"#)
    check("Cursor: spend does not invent an allowance", spendOnly.meters.isEmpty)
    checkEqual("Cursor: absent cap is not zero", spendOnly.onDemand?.limitCents, nil)
    for json in ["{}", "{\"planUsage\":{}}", "{\"planUsage\":{\"limit\":0}}",
                 "{\"planUsage\":{\"totalPercentUsed\":-1}}", "{\"planUsage\":{\"totalPercentUsed\":true}}",
                 "{\"planUsage\":{\"totalPercentUsed\":1e100}}", "[]"] {
        do { _ = try parse(json); check("Cursor: invalid/missing allowance rejected", false) }
        catch { check("Cursor: invalid/missing allowance rejected", true) }
    }
    do { _ = try CursorUsageParser.parse(Data(repeating: 32, count: CursorUsageParser.maximumBytes + 1), capturedAt: captured)
        check("Cursor: bounded response", false)
    } catch { check("Cursor: bounded response", true) }
    let session = CursorClient.Session(accessToken: "synthetic-session")
    check("Cursor: description redacts credentials", !String(describing: session).contains("synthetic-session"))
    check("Cursor: fingerprint changes with session", session.fingerprint != CursorClient.Session(accessToken: "other-synthetic-session").fingerprint)

    let root = FileManager.default.temporaryDirectory.appendingPathComponent("pom-cursor-\(UUID().uuidString)")
    try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
    defer { try? FileManager.default.removeItem(at: root) }
    let database = root.appendingPathComponent("state.vscdb")
    do { _ = try CursorClient.readSession(database: database); check("Cursor: missing session rejected", false) }
    catch { check("Cursor: missing session rejected", true) }
    check("Cursor: read never creates a database", !FileManager.default.fileExists(atPath: database.path))
    var db: OpaquePointer?
    precondition(sqlite3_open(database.path, &db) == SQLITE_OK)
    precondition(sqlite3_exec(db, "CREATE TABLE ItemTable (key TEXT PRIMARY KEY, value TEXT); INSERT INTO ItemTable VALUES ('cursorAuth/accessToken', 'synthetic-session');", nil, nil, nil) == SQLITE_OK)
    sqlite3_close(db)
    checkEqual("Cursor: reads selected key in read-only mode", try CursorClient.readSession(database: database).fingerprint, session.fingerprint)
} catch { failures.append("Cursor usage: \(error)") }

do {
    let now = date(1_790_000_000)
    var value: [String: Any] = ["kind": "present", "selectedTeamId": NSNull(), "expiresAtMs": (now.timeIntervalSince1970 + 86400) * 1000,
        "reading": ["readAtMs": (now.timeIntervalSince1970 - 180) * 1000,
                    "usage": ["percentUsed": 1.85, "nextResetMs": (now.timeIntervalSince1970 + 86400 * 5) * 1000,
                              "isSandTrial": false, "hasNonZeroIncludedLimit": true, "grokPlanLabel": "Grok Bot Plan",
                              "onDemand": ["usedCents": 50, "limitCents": 1000]]]]
    func data(_ input: [String: Any], schema: Int = 2) throws -> Data {
        try JSONSerialization.data(withJSONObject: ["schemaVersion": schema, "value": input])
    }
    let snapshot = try GrokBotCache.parse(data(value), now: now)
    checkEqual("Grok Bot: weekly meter", snapshot.meters.map(\.kind), [.weekly])
    checkClose("Grok Bot: percentage", snapshot.meters[0].window.usedPercentage, 1.85)
    checkEqual("Grok Bot: cache read does not refresh capture date", snapshot.capturedAt, now.addingTimeInterval(-180))
    checkEqual("Grok Bot: plan from source", snapshot.planName, "Grok Bot Plan")
    checkEqual("Grok Bot: on demand cents", snapshot.onDemand, .init(usedCents: 50, limitCents: 1000))
    for invalid in [try data(value, schema: 999), try data(["kind": "absent", "selectedTeamId": NSNull(), "expiresAtMs": (now.timeIntervalSince1970 + 1000) * 1000])] {
        do { _ = try GrokBotCache.parse(invalid, now: now); check("Grok Bot: incompatible/absent cache rejected", false) }
        catch { check("Grok Bot: incompatible/absent cache rejected", true) }
    }
    do { _ = try GrokBotCache.parse(data(value), now: now.addingTimeInterval(86401)); check("Grok Bot: expired cache rejected", false) }
    catch { check("Grok Bot: expired cache rejected", true) }
    var expiredReading = value["reading"] as! [String: Any]
    var usage = expiredReading["usage"] as! [String: Any]
    usage["nextResetMs"] = (now.timeIntervalSince1970 - 1) * 1000
    expiredReading["usage"] = usage
    var expiredReset = value; expiredReset["reading"] = expiredReading
    let expired = try GrokBotCache.parse(data(expiredReset), now: now)
    check("Grok Bot: elapsed reset awaits new data", UsageDisplay.resolve(expired.meters[0].window, now: now).didReset)

    let root = FileManager.default.temporaryDirectory.appendingPathComponent("pom-grok-\(UUID().uuidString)")
    defer { try? FileManager.default.removeItem(at: root) }
    let cache = GrokBotCache(home: root)
    try FileManager.default.createDirectory(at: cache.directory, withIntermediateDirectories: true)
    func select(_ account: String) throws {
        let metadata = try JSONSerialization.data(withJSONObject: ["schemaVersion": 1, "value": account])
        try metadata.write(to: cache.directory.appendingPathComponent(GrokBotCache.blobName(for: "sand.client.slice.client-meta.account-slot")))
    }
    try select("github|fixture")
    let blob = GrokBotCache.blobName(for: "sand.client.slice.account.github%7Cfixture.weekly-usage.cache")
    try data(value).write(to: cache.directory.appendingPathComponent(blob))
    checkEqual("Grok Bot: active account cache found with URI encoding", try cache.read(now: now), snapshot)
    try select("different-account")
    do { _ = try cache.read(now: now); check("Grok Bot: never borrows another account's quota", false) }
    catch { check("Grok Bot: never borrows another account's quota", true) }
    checkEqual("Grok Bot: base32 naming contract", GrokBotCache.blobName(for: "foo"), "mzxw6.blob")
    value["reading"] = ["readAtMs": (now.timeIntervalSince1970 + 3600) * 1000, "usage": usage]
    do { _ = try GrokBotCache.parse(data(value), now: now); check("Grok Bot: future readings rejected", false) }
    catch { check("Grok Bot: future readings rejected", true) }
} catch { failures.append("Grok Bot cache: \(error)") }

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
