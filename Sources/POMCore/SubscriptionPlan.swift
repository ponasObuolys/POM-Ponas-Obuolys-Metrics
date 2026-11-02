import Foundation

/// Marketing names and legacy identifiers are different things.
/// Verified aliases: docs/PLAN-NAMES.md (2026-11-03). Never derive a tier from usage.
public enum SubscriptionPlan {
    /// Preserve source-supplied names, including future plans, without fabricating a tier.
    public static func providedName(_ raw: String?) -> String? {
        guard let raw else { return nil }
        let name = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !name.isEmpty, name.count <= 100,
              !name.unicodeScalars.contains(where: { CharacterSet.controlCharacters.contains($0) }) else { return nil }
        return name
    }

    public static func claude(type: String?, tier: String?) -> String? {
        let name = providedName(type)
        let key = name?.lowercased()
        // Explicit modern types beat stale local rate-limit metadata. The generic
        // legacy 'max' type needs the tier to distinguish former Max 5x from 20x.
        switch key {
        case "ultra", "claude_ultra", "claude ultra", "max 20x", "max_20x": return "Ultra"
        case "pro", "claude_pro", "claude pro": return "Pro"
        case "free", "claude_free", "claude free": return "Free"
        case "team", "claude_team", "claude team": return "Team"
        case "enterprise", "claude_enterprise", "claude enterprise": return "Enterprise"
        case "max 5x", "max_5x": return "Max"
        case nil, "max", "claude_max", "claude max":
            switch tier?.trimmingCharacters(in: .whitespacesAndNewlines).lowercased() {
            case "default_claude_max_20x": return "Ultra"
            case "default_claude_max_5x": return "Max"
            default: return key == nil ? nil : "Max"
            }
        default: return name
        }
    }

    public static func claudeLocal(home: URL = FileManager.default.homeDirectoryForCurrentUser,
                                   preferredType: String? = nil) -> String? {
        guard let data = try? Data(contentsOf: home.appendingPathComponent(".claude.json")),
            let root = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
            let account = root["oauthAccount"] as? [String: Any]
        else { return claude(type: preferredType, tier: nil) }
        return claude(type: providedName(preferredType) ?? account["organizationType"] as? String,
                      tier: account["userRateLimitTier"] as? String
                        ?? account["organizationRateLimitTier"] as? String)
    }

    public static func codex(_ raw: String?) -> String? {
        guard let name = providedName(raw) else { return nil }
        switch name.lowercased() {
        // These are API types, not a promise of a usage multiplier or price.
        case "prolite", "pro": return "ChatGPT Pro"
        case "pro_100", "pro100", "pro 100": return "ChatGPT Pro 100"
        case "pro_200", "pro200", "pro 200": return "ChatGPT Pro 200"
        case "pro_500", "pro500", "pro 500": return "ChatGPT Pro 500"
        case "plus": return "ChatGPT Plus"
        case "free": return "ChatGPT Free"
        case "go": return "ChatGPT Go"
        case "team", "business": return "ChatGPT Business"
        case "enterprise": return "ChatGPT Enterprise"
        case "edu": return "ChatGPT Edu"
        default: return name.lowercased().hasPrefix("chatgpt ") ? name : "ChatGPT " + name
        }
    }
}
