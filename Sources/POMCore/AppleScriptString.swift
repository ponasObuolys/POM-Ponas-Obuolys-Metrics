import Foundation

/// Teksto paruošimas AppleScript eilutei.
/// Kabutės ir pasvirieji brūkšniai turi būti pridengti, kitaip scenarijus nutrūktų
/// arba į jį patektų nenumatytos komandos.
public enum AppleScriptString {
    public static func quoted(_ text: String) -> String {
        let escaped =
            text
            .replacingOccurrences(of: "\\", with: "\\\\")
            .replacingOccurrences(of: "\"", with: "\\\"")
        return "\"\(escaped)\""
    }
}
