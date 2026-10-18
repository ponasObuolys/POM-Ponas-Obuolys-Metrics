import Foundation

/// Reads just the selected account and its usage cache, without opening secrets
/// or conversations. Grok Bot itself refreshes this cache from its backend.
public struct GrokBotCache: Sendable {
    public enum CacheError: Error, Equatable { case unavailable, signedOut, expired, invalidFormat }
    public static let maximumBytes = 64 * 1024
    public let directory: URL

    public init(home: URL = FileManager.default.homeDirectoryForCurrentUser) {
        directory = home.appendingPathComponent("Library/Application Support/Grok Bot/sand-client-persistence")
    }

    private struct Envelope<Value: Decodable>: Decodable {
        let schemaVersion: Int
        let value: Value
    }
    private struct Cache: Decodable {
        let kind: String
        let selectedTeamId: Int?
        let reading: Reading?
        let expiresAtMs: Double
    }
    private struct Reading: Decodable {
        let usage: Usage
        let readAtMs: Double
    }
    private struct Usage: Decodable {
        let percentUsed: Double
        let nextResetMs: Double?
        let isSandTrial: Bool
        let hasNonZeroIncludedLimit: Bool
        let grokPlanLabel: String?
        let onDemand: Spend?
    }
    private struct Spend: Decodable {
        let usedCents: Double
        let limitCents: Double
    }

    public func read(now: Date = Date()) throws -> ProviderUsageSnapshot {
        let metadata: Envelope<String?>
        do { metadata = try JSONDecoder().decode(Envelope<String?>.self, from: readBlob(key: "sand.client.slice.client-meta.account-slot")) }
        catch { throw CacheError.signedOut }
        guard metadata.schemaVersion == 1, let slot = metadata.value, !slot.isEmpty, slot.utf8.count <= 512 else {
            throw CacheError.signedOut
        }
        let allowed = CharacterSet(charactersIn: "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789-_.!~*'()")
        guard let encodedSlot = slot.addingPercentEncoding(withAllowedCharacters: allowed) else { throw CacheError.invalidFormat }
        let data = try readBlob(key: "sand.client.slice.account.\(encodedSlot).weekly-usage.cache")
        return try Self.parse(data, now: now)
    }

    public static func parse(_ data: Data, now: Date = Date()) throws -> ProviderUsageSnapshot {
        guard data.count <= maximumBytes else { throw CacheError.invalidFormat }
        let envelope: Envelope<Cache>
        do { envelope = try JSONDecoder().decode(Envelope<Cache>.self, from: data) }
        catch { throw CacheError.invalidFormat }
        guard envelope.schemaVersion == 2 else { throw CacheError.invalidFormat }
        let cache = envelope.value
        guard cache.expiresAtMs.isFinite, cache.expiresAtMs / 1000 > now.timeIntervalSince1970 else { throw CacheError.expired }
        guard cache.kind == "present", let reading = cache.reading else { throw CacheError.unavailable }
        let usage = reading.usage
        guard reading.readAtMs > 0, reading.readAtMs / 1000 <= now.timeIntervalSince1970 + 60,
              cache.expiresAtMs >= reading.readAtMs,
              usage.percentUsed.isFinite, (0...10_000).contains(usage.percentUsed),
              usage.hasNonZeroIncludedLimit || usage.isSandTrial else { throw CacheError.invalidFormat }
        let reset: Date?
        if let value = usage.nextResetMs {
            guard value > 0, value < 32_503_680_000_000 else { throw CacheError.invalidFormat }
            reset = Date(timeIntervalSince1970: value / 1000)
        } else { reset = nil }
        let onDemand: ProviderUsageSnapshot.Spend?
        if let spend = usage.onDemand {
            guard spend.usedCents >= 0, spend.usedCents < 1e12, spend.limitCents >= 0, spend.limitCents < 1e12 else {
                throw CacheError.invalidFormat
            }
            onDemand = .init(usedCents: spend.usedCents, limitCents: spend.limitCents)
        } else { onDemand = nil }
        let plan = usage.grokPlanLabel.flatMap { $0.isEmpty || $0.count > 100 ? nil : $0 }
        return .init(meters: [.init(kind: .weekly, usedPercentage: usage.percentUsed, resetsAt: reset)],
                     capturedAt: Date(timeIntervalSince1970: reading.readAtMs / 1000),
                     planName: plan, onDemand: onDemand)
    }

    private func readBlob(key: String) throws -> Data {
        let url = directory.appendingPathComponent(Self.blobName(for: key))
        guard let size = try? url.resourceValues(forKeys: [.fileSizeKey]).fileSize,
              size <= Self.maximumBytes, let data = try? Data(contentsOf: url), data.count <= Self.maximumBytes else {
            throw CacheError.unavailable
        }
        return data
    }

    public static func blobName(for key: String) -> String {
        let alphabet = Array("abcdefghijklmnopqrstuvwxyz234567")
        var buffer: UInt32 = 0, bits = 0
        var output = ""
        for byte in key.utf8 {
            buffer = (buffer << 8) | UInt32(byte)
            bits += 8
            while bits >= 5 {
                bits -= 5
                output.append(alphabet[Int((buffer >> bits) & 31)])
            }
        }
        if bits > 0 { output.append(alphabet[Int((buffer << (5 - bits)) & 31)]) }
        return output + ".blob"
    }
}
