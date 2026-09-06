import Foundation

/// Rodomi tik paskyros pateikti plano duomenys. Daugiklis nėra apskaičiuojamas iš procentų.
public enum SubscriptionPlan {
    public static func claude(type: String?, tier: String?) -> String? {
        switch tier {
        case "default_claude_max_20x": return "Max 20x"
        case "default_claude_max_5x": return "Max 5x"
        default: break
        }
        switch type?.lowercased() {
        case "max": return "Max"
        case "pro": return "Pro"
        case "team": return "Team"
        case "enterprise": return "Enterprise"
        default: return nil
        }
    }

    public static func claudeLocal(home: URL = FileManager.default.homeDirectoryForCurrentUser) -> String? {
        guard let data = try? Data(contentsOf: home.appendingPathComponent(".claude.json")),
            let root = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
            let account = root["oauthAccount"] as? [String: Any]
        else { return nil }
        return claude(type: account["organizationType"] as? String,
                      tier: account["userRateLimitTier"] as? String
                        ?? account["organizationRateLimitTier"] as? String)
    }

    public static func codex(_ raw: String?) -> String? {
        switch raw?.lowercased() {
        case "prolite": return "ChatGPT Pro 5x"
        case "pro": return "ChatGPT Pro 20x"
        case "plus": return "ChatGPT Plus"
        case "free": return "ChatGPT Free"
        case "go": return "ChatGPT Go"
        case "team", "business": return "ChatGPT Business"
        case "enterprise": return "ChatGPT Enterprise"
        case "edu": return "ChatGPT Edu"
        default: return nil
        }
    }
}
