import Foundation

/// Rule-based dictation cleanup. Runs instantly and offline. It is the fallback when the
/// cloud cleanup is slow or rejected by the guard, and the pre-pass before it.
/// It only removes and formats: it never adds words or changes meaning.
public enum Cleanup {
    public static func run(_ text: String) -> String {
        var t = text.replacingOccurrences(of: "\r", with: "")
        t = Rx.replace(t, "[ \\t]+", with: " ")
        t = removeFillers(t)
        t = applyBacktracks(t)
        t = collapseStutters(t)
        t = spokenFormatting(t)
        t = lists(t)
        t = formats(t)
        t = tidy(t)
        t = capitalize(t)
        t = finish(t)
        return t
    }

    // MARK: Fillers

    static func removeFillers(_ text: String) -> String {
        let fillers = "(?:u+m+|u+h+|uhm|erm|er|a+h+|h+m+|mm+|mhm)"
        return Rx.replace(text, Rx.wordStart + fillers + Rx.wordEnd + "[,.]?", with: "")
    }

    // MARK: Backtracking ("Tuesday, wait, Wednesday" → "Wednesday")

    private enum Kind { case weekday, month, relativeDay, number }

    private static let weekdays: Set<String> = [
        "monday", "tuesday", "wednesday", "thursday", "friday", "saturday", "sunday",
    ]
    private static let months: Set<String> = [
        "january", "february", "march", "april", "may", "june", "july", "august",
        "september", "october", "november", "december",
    ]
    private static let relativeDays: Set<String> = ["today", "tomorrow", "tonight", "yesterday"]
    private static let markers: Set<String> = ["wait", "no", "sorry", "actually"]
    private static let glue: Set<String> = [
        "it's", "it", "is", "its", "actually", "on", "at", "the", "make", "that", "i", "mean", "sorry", "no", "wait",
        "rather", "like", "um", "uh",
    ]

    private static func core(_ token: String) -> String {
        token.lowercased().trimmingCharacters(in: CharacterSet.letters.union(.decimalDigits).union(CharacterSet(charactersIn: ":'")).inverted)
    }

    private static func kind(_ token: String) -> Kind? {
        let word = core(token)
        if weekdays.contains(word) { return .weekday }
        if months.contains(word) && word != "may" { return .month }
        if relativeDays.contains(word) { return .relativeDay }
        if Words.numberWords.contains(word) { return .number }
        if let first = word.first, first.isNumber { return .number }
        return nil
    }

    static func applyBacktracks(_ text: String) -> String {
        var lines: [String] = []
        for line in text.components(separatedBy: "\n") {
            var tokens = line.split(separator: " ").map(String.init)
            var i = 0
            while i < tokens.count {
                // A marker run: "wait", "no wait", "sorry", "I mean", "actually".
                var markerEnd = i
                while markerEnd < tokens.count {
                    let word = core(tokens[markerEnd])
                    if markers.contains(word) {
                        markerEnd += 1
                    } else if word == "i", markerEnd + 1 < tokens.count, core(tokens[markerEnd + 1]) == "mean" {
                        markerEnd += 2
                    } else {
                        break
                    }
                }
                // Allow a few glue words before the correction: "no wait, it's actually on Wednesday".
                var target = markerEnd
                while target < tokens.count, target - markerEnd < 4, kind(tokens[target]) == nil,
                      glue.contains(core(tokens[target])) {
                    target += 1
                }
                guard markerEnd > i, target < tokens.count, let newKind = kind(tokens[target]) else {
                    i += 1
                    continue
                }
                // The thing being corrected: same kind, at most 4 words back.
                var replaced: Int?
                var j = i - 1
                while j >= max(0, i - 4) {
                    if kind(tokens[j]) == newKind { replaced = j; break }
                    j -= 1
                }
                if let replaced {
                    tokens.removeSubrange(replaced..<target)
                    i = replaced + 1
                } else {
                    i += 1
                }
            }
            lines.append(tokens.joined(separator: " "))
        }
        return lines.joined(separator: "\n")
    }

    // MARK: Stutters ("I I think" → "I think")

    private static let emphasis: Set<String> = [
        "very", "really", "so", "no", "bye", "ha", "haha", "yes", "yeah", "please", "go", "more",
        "far", "much", "long", "ok", "okay", "hi", "hey", "that", "had",
    ]

    static func collapseStutters(_ text: String) -> String {
        text.components(separatedBy: "\n").map { line in
            var out: [String] = []
            for token in line.split(separator: " ").map(String.init) {
                if let previous = out.last {
                    let a = core(previous), b = core(token)
                    let previousEndsClause = previous.last.map { ",.?!;:".contains($0) } ?? false
                    if !a.isEmpty, a == b, !emphasis.contains(a), !(a.first?.isNumber ?? false), !previousEndsClause {
                        out.removeLast()
                    }
                }
                out.append(token)
            }
            return out.joined(separator: " ")
        }.joined(separator: "\n")
    }

    // MARK: Spoken punctuation and formatting

    static func spokenFormatting(_ text: String) -> String {
        let marks: [(String, String)] = [
            ("new paragraph", "\n\n"), ("new line", "\n"), ("next line", "\n"),
            ("full stop", "."), ("question mark", "?"), ("exclamation mark", "!"),
            ("exclamation point", "!"), ("semicolon", ";"), ("comma", ","), ("colon", ":"),
        ]
        var t = text
        for (spoken, mark) in marks {
            let pattern = "[ ,.]*" + Rx.wordStart + Rx.phrase(spoken) + Rx.wordEnd + "[,.]?"
            let template = NSRegularExpression.escapedTemplate(for: mark)
            t = Rx.replace(t, pattern, with: mark.hasPrefix("\n") ? template : template + " ")
        }
        return t
    }

    private static let ordinalWords = ["one", "two", "three", "four", "five", "six", "seven", "eight", "nine", "ten"]

    static func lists(_ text: String) -> String {
        var t = Rx.replace(text, "[ ,.]*" + Rx.wordStart + "bullet\\s+point" + Rx.wordEnd + "[,:.]?\\s*", with: "\n- ")
        let numbered = Rx.make(Rx.wordStart + "number\\s+(" + ordinalWords.joined(separator: "|") + "|\\d{1,2})" + Rx.wordEnd + "[,:.]?\\s*")
        if numbered.numberOfMatches(in: t, range: NSRange(t.startIndex..., in: t)) >= 2 {
            t = Rx.replace(t, numbered) { match in
                let word = Words.split(match).dropFirst().first ?? ""
                let n = ordinalWords.firstIndex(of: word).map { $0 + 1 } ?? Int(word) ?? 1
                return "\n\(n). "
            }
            t = Rx.replace(t, "[ ,.]+\\n", with: "\n")
        }
        t = Rx.replace(t, "[ ,.]+\\n- ", with: "\n- ")
        return t
    }

    static func formats(_ text: String) -> String {
        var t = text
        t = Rx.replace(t, "(\\d+(?:[.,]\\d+)?)\\s*rupees?" + Rx.wordEnd, with: "₹$1")
        t = Rx.replace(t, Rx.wordStart + "rupees?\\s+(\\d+(?:[.,]\\d+)?)", with: "₹$1")
        t = Rx.replace(t, "(\\d+(?:\\.\\d+)?)\\s*per\\s?cent" + Rx.wordEnd, with: "$1%")
        let mail = "(?:gmail|yahoo|outlook|hotmail|icloud|proton|protonmail)"
        t = Rx.replace(t, Rx.wordStart + "([a-z0-9._%+-]+)\\s+at\\s+(" + mail + ")\\s+dot\\s+com" + Rx.wordEnd, with: "$1@$2.com")
        t = Rx.replace(t, Rx.wordStart + "([a-z0-9-]+)\\s+dot\\s+(com|in|org|net|io|ai|co|edu|dev|app)" + Rx.wordEnd, with: "$1.$2")
        return Rx.replace(t, Rx.make("[A-Za-z0-9._%+-]+@[A-Za-z0-9-]+\\.[A-Za-z]+")) { $0.lowercased() }
    }

    // MARK: Spacing, capitals, final mark

    static func tidy(_ text: String) -> String {
        var t = text
        t = Rx.replace(t, "[ \\t]+([,.;:?!%])", with: "$1")
        t = Rx.replace(t, ",+", with: ",")
        t = Rx.replace(t, ",([.?!])", with: "$1")
        t = Rx.replace(t, "([.?!]),", with: "$1")
        t = Rx.replace(t, "\\.([?!])", with: "$1")
        t = Rx.replace(t, "([?!])\\.", with: "$1")
        t = Rx.replace(t, "\\.{2}(?!\\.)", with: ".")
        t = Rx.replace(t, "([,;!?])(?=\\p{L})", with: "$1 ")
        t = Rx.replace(t, "\\.(?=\\p{Lu})", with: ". ", caseInsensitive: false)
        t = Rx.replace(t, "[ \\t]*\\n[ \\t]*", with: "\n")
        t = Rx.replace(t, "\\n{3,}", with: "\n\n")
        t = Rx.replace(t, "(^|\\n)[,.;:]+[ ]*", with: "$1")
        t = Rx.replace(t, " {2,}", with: " ")
        return t.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    static func capitalize(_ text: String) -> String {
        // Standalone "i", "i'm", "i'll", "i've", "i'd".
        var t = Rx.replace(text, Rx.make("(?<![\\p{L}\\p{N}'])i(?=(?:'m|'ll|'ve|'d)?(?![\\p{L}\\p{N}]))", caseInsensitive: false)) { _ in "I" }
        var out = ""
        var needCapital = true
        var previous: Character = " "
        for char in t {
            if needCapital, char.isLetter {
                out += char.uppercased()
                needCapital = false
            } else {
                out.append(char)
                if char.isNumber { needCapital = false }
            }
            if char == "\n" { needCapital = true }
            if " \n".contains(char), ".?!".contains(previous) { needCapital = true }
            previous = char
        }
        t = out
        return t
    }

    private static let questionWords: Set<String> = ["what", "when", "where", "why", "who", "whom", "whose", "which", "how"]
    private static let auxiliaries: Set<String> = [
        "is", "are", "am", "was", "were", "do", "does", "did", "can", "could", "will", "would",
        "should", "shall", "may", "might", "have", "has", "had", "isn't", "aren't", "don't",
        "doesn't", "didn't", "can't", "won't", "wouldn't", "shouldn't", "couldn't",
    ]
    private static let subjects: Set<String> = [
        "you", "i", "we", "they", "he", "she", "it", "this", "that", "there", "anyone", "someone",
        "everyone", "u", "ya",
    ]

    static func finish(_ text: String) -> String {
        guard let last = text.last, last.isLetter || last.isNumber else { return text }
        let lastLine = text.components(separatedBy: "\n").last ?? text
        if lastLine.hasPrefix("- ") || Rx.contains(lastLine, "^\\d{1,2}\\. ") { return text }
        guard Words.split(lastLine).count >= 4 else { return text }
        let sentence = lastLine.components(separatedBy: CharacterSet(charactersIn: ".?!")).last ?? lastLine
        let words = Words.split(sentence)
        let isQuestion: Bool
        if let first = words.first, questionWords.contains(first) {
            isQuestion = true
        } else if words.count >= 2, auxiliaries.contains(words[0]), subjects.contains(words[1]) {
            isQuestion = true
        } else {
            isQuestion = false
        }
        return text + (isQuestion ? "?" : ".")
    }
}
