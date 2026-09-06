import Foundation

/// Paklausia Codex, kiek limito sunaudota.
///
/// Codex CLI turi vietinį režimą `codex app-server`: tai JSON-RPC pokalbis per standartinę
/// įvestį ir išvestį. Metodas `account/rateLimits/read` grąžina tas pačias reikšmes, kurias
/// ChatGPT programa rodo skiltyje „Usage & billing“. Prisijungimu pasirūpina pats Codex,
/// todėl POM nereikia nei rakto, nei tinklo užklausų.
///
/// Procesas paleidžiamas trumpam ir iškart uždaromas: visas ciklas trunka apie sekundę,
/// o nuolat gyvas procesas be jokios naudos kabotų atmintyje visą parą.
public struct CodexClient: Sendable {
    public enum ClientError: Error, Equatable {
        case launchFailed(String)
        /// Codex neatsakė per skirtą laiką. Dažniausiai tai reiškia, kad jis užstrigo,
        /// o ne kad limitų nėra.
        case timedOut
        case noResponse
    }

    /// Užklausos numeris. JSON-RPC atsakymai ateina maišyti su pranešimais, todėl
    /// atsakymas atpažįstamas pagal jį.
    private static let requestID = 7

    public let timeout: TimeInterval

    public init(timeout: TimeInterval = 10) {
        self.timeout = timeout
    }

    /// Blokuojanti operacija: paleidžia procesą ir laukia atsakymo. Kviesti reikia iš fono.
    public func fetch(executable: URL, now: Date = Date()) throws -> CodexSnapshot {
        let process = Process()
        process.executableURL = executable
        process.arguments = ["app-server"]
        process.environment = Self.environment
        process.currentDirectoryURL = FileManager.default.homeDirectoryForCurrentUser

        let input = Pipe()
        let output = Pipe()
        process.standardInput = input
        process.standardOutput = output
        process.standardError = FileHandle.nullDevice

        do {
            try process.run()
        } catch {
            throw ClientError.launchFailed(error.localizedDescription)
        }

        // Užstrigusį procesą nutraukia laikmatis. Be jo skaitymas lauktų amžinai,
        // o POM langelis liktų kaboti ties užrašu „klausiama“.
        let watchdog = DispatchWorkItem {
            if process.isRunning { process.terminate() }
        }
        let killSwitch = DispatchWorkItem {
            if process.isRunning { kill(process.processIdentifier, SIGKILL) }
        }
        DispatchQueue.global(qos: .utility).asyncAfter(deadline: .now() + timeout, execute: watchdog)
        DispatchQueue.global(qos: .utility).asyncAfter(deadline: .now() + timeout + 1, execute: killSwitch)

        defer {
            watchdog.cancel()
            try? input.fileHandleForWriting.close()
            if process.isRunning { process.terminate() }
            process.waitUntilExit()
            killSwitch.cancel()
        }

        // Įvestis lieka atvira, kol gaunamas atsakymas: pamatęs jos pabaigą Codex
        // pokalbį užbaigia ir nespėja nieko atsakyti.
        try? input.fileHandleForWriting.write(contentsOf: Data(Self.requestLines.utf8))

        let reader = output.fileHandleForReading
        var buffer = Data()
        let newline = UInt8(ascii: "\n")

        while true {
            let chunk = reader.availableData
            if chunk.isEmpty { break }
            buffer.append(chunk)
            guard buffer.count <= 4 * 1024 * 1024 else { throw ClientError.noResponse }

            while let index = buffer.firstIndex(of: newline) {
                let line = buffer[buffer.startIndex..<index]
                buffer.removeSubrange(buffer.startIndex...index)
                guard isAnswer(line) else { continue }
                return try CodexParser.parse(data: Data(line), capturedAt: now)
            }
        }

        // Procesas baigėsi neatsakęs. Laikmačio nutrauktas procesas neturi kodo 0.
        process.waitUntilExit()
        if watchdog.isCancelled == false, process.terminationReason == .uncaughtSignal {
            throw ClientError.timedOut
        }
        throw ClientError.noResponse
    }

    // MARK: - Užklausa

    /// Trys eilutės iš karto: pasisveikinimas, patvirtinimas ir pats klausimas.
    /// Codex atsako paeiliui, tad laukti tarp jų nereikia.
    private static var requestLines: String {
        let client = #"{"name":"POM","title":"POM","version":"\#(version)"}"#
        return [
            #"{"jsonrpc":"2.0","id":1,"method":"initialize","params":{"clientInfo":\#(client)}}"#,
            #"{"jsonrpc":"2.0","method":"initialized","params":{}}"#,
            #"{"jsonrpc":"2.0","id":\#(requestID),"method":"account/rateLimits/read"}"#,
        ].joined(separator: "\n") + "\n"
    }

    private static var version: String {
        Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "dev"
    }

    /// npm įdiegtas `codex` yra Node scenarijus su eilute `#!/usr/bin/env node`, tad be
    /// tinkamo `PATH` jis nepasileistų: meniu juostos programa terminalo kelių nepaveldi.
    private static var environment: [String: String] {
        var environment = ProcessInfo.processInfo.environment
        let extra = ["/opt/homebrew/bin", "/usr/local/bin", "/usr/bin", "/bin"]
        let existing = environment["PATH"].map { $0.split(separator: ":").map(String.init) } ?? []
        let merged = extra + existing.filter { !extra.contains($0) }
        environment["PATH"] = merged.joined(separator: ":")
        return environment
    }

    /// Ar tai atsakymas į mūsų klausimą. Tuo pačiu kanalu ateina ir pranešimai apie
    /// visai kitus dalykus, pavyzdžiui, nuotolinio valdymo būseną.
    private func isAnswer(_ line: Data.SubSequence) -> Bool {
        guard let json = try? JSONSerialization.jsonObject(with: Data(line), options: []),
            let root = json as? [String: Any]
        else {
            return false
        }
        guard let id = root["id"] as? NSNumber else { return false }
        return id.intValue == Self.requestID
    }
}
