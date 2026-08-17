import Foundation

/// Seka, ties kuriomis ribomis jau pranešta, kad tas pats perspėjimas nesikartotų.
/// Langui atsistačius (pasikeitus atsistatymo laikui) žymos nunulinamos.
public struct AlertTracker: Sendable {
    public enum Window: String, Hashable, CaseIterable, Sendable {
        case fiveHour
        case sevenDay
    }

    private struct State {
        var resetsAt: Date?
        var fired: Set<Int>
    }

    public private(set) var thresholds: [Int]
    private var states: [Window: State] = [:]

    public init(thresholds: [Int]) {
        self.thresholds = thresholds.sorted()
    }

    /// Pakeitus ribas žymos neišvalomos. Apie ką jau pranešta, antrą kartą pranešti nereikia,
    /// o kartu praneštomis laikomos ir žemesnės naujos ribos: apie didesnį užimtumą
    /// vartotojas jau žino, tad priminimas apie mažesnį būtų tik triukšmas.
    public mutating func updateThresholds(_ newValue: [Int]) {
        let sorted = newValue.sorted()
        guard sorted != thresholds else { return }
        thresholds = sorted

        for (window, state) in states {
            guard let highest = state.fired.max() else { continue }
            var updated = state
            updated.fired.formUnion(sorted.filter { $0 <= highest })
            states[window] = updated
        }
    }

    /// Grąžina aukščiausią ką tik peržengtą ribą arba `nil`, jei pranešti nereikia.
    public mutating func check(window: Window, percentage: Double, resetsAt: Date?) -> Int? {
        var state = states[window] ?? State(resetsAt: resetsAt, fired: [])
        if state.resetsAt != resetsAt {
            state = State(resetsAt: resetsAt, fired: [])
        }

        let crossed = thresholds.filter { Double($0) <= percentage }
        let fresh = crossed.filter { !state.fired.contains($0) }
        state.fired.formUnion(crossed)
        states[window] = state

        return fresh.max()
    }
}
