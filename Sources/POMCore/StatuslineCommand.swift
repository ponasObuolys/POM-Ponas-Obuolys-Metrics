import Foundation

/// Perskaito paprastą shell komandą jos nevykdydama. Sudėtinių komandų nekeičia.
public enum StatuslineCommand {
    public static func script(in command: String, home: URL) -> URL? {
        guard let words = words(in: command), !words.isEmpty else { return nil }
        var index = 0
        if URL(fileURLWithPath: words[0]).lastPathComponent == "env" {
            index += 1
            while index < words.count, words[index].contains("=") { index += 1 }
        }
        guard index < words.count else { return nil }
        let shells = ["bash", "sh", "zsh", "dash", "ksh"]
        if shells.contains(URL(fileURLWithPath: words[index]).lastPathComponent) {
            index += 1
            while index < words.count, words[index].hasPrefix("-") {
                let option = words[index]
                if option == "--" { index += 1; break }
                // -c vykdo tekstą, o -s skaito stdin: tolesnis žodis nėra scenarijus.
                guard !option.hasPrefix("--"), !option.contains("c"),
                    !option.contains("s"), !option.contains("o"), !option.contains("O")
                else { return nil }
                index += 1
            }
        }
        guard index < words.count else { return nil }
        var path = words[index]
        guard path.hasPrefix("/") || path.hasPrefix("~/") else { return nil }
        if path.hasPrefix("~/") { path = home.path + path.dropFirst() }
        return URL(fileURLWithPath: path)
    }

    private static func words(in command: String) -> [String]? {
        var result: [String] = []
        var word = ""
        var quote: Character?
        var escaped = false
        var started = false
        for character in command {
            if escaped {
                if quote == "\"", !["\"", "\\", "$", "`"].contains(character) {
                    word.append("\\")
                }
                word.append(character)
                escaped = false
                started = true
            } else if character == "\\", quote != "'" {
                escaped = true
                started = true
            } else if let current = quote {
                if character == current { quote = nil }
                else {
                    guard current == "'" || !["$", "`"].contains(character) else { return nil }
                    word.append(character)
                }
            } else if character == "\"" || character == "'" {
                quote = character
                started = true
            } else if character.isWhitespace {
                if started { result.append(word); word = ""; started = false }
            } else {
                guard !";|&<>$`(){}*?[]#".contains(character) else { return nil }
                word.append(character)
                started = true
            }
        }
        guard quote == nil, !escaped else { return nil }
        if started { result.append(word) }
        return result
    }
}
