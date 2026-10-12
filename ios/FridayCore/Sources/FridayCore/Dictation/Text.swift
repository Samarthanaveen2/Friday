import Foundation

/// Small regex and word helpers shared by the dictation rules.
enum Rx {
    /// Matches when not touching a letter, digit or apostrophe on either side.
    static let wordStart = "(?<![\\p{L}\\p{N}'])"
    static let wordEnd = "(?![\\p{L}\\p{N}'])"

    static func make(_ pattern: String, caseInsensitive: Bool = true) -> NSRegularExpression {
        // Patterns are compile-time constants or escaped user text, so this can't fail.
        try! NSRegularExpression(pattern: pattern, options: caseInsensitive ? [.caseInsensitive] : [])
    }

    static func replace(_ text: String, _ pattern: String, with template: String, caseInsensitive: Bool = true) -> String {
        let regex = make(pattern, caseInsensitive: caseInsensitive)
        return regex.stringByReplacingMatches(in: text, range: NSRange(text.startIndex..., in: text), withTemplate: template)
    }

    /// Replaces each match with whatever `transform` returns for it.
    static func replace(_ text: String, _ regex: NSRegularExpression, transform: (String) -> String) -> String {
        let ns = text as NSString
        var out = ""
        var last = 0
        for match in regex.matches(in: text, range: NSRange(location: 0, length: ns.length)) {
            out += ns.substring(with: NSRange(location: last, length: match.range.location - last))
            out += transform(ns.substring(with: match.range))
            last = match.range.location + match.range.length
        }
        out += ns.substring(from: last)
        return out
    }

    static func contains(_ text: String, _ pattern: String) -> Bool {
        make(pattern).firstMatch(in: text, range: NSRange(text.startIndex..., in: text)) != nil
    }

    /// The first text matching the pattern, if any.
    static func firstMatch(_ text: String, _ pattern: String) -> String? {
        matches(text, pattern).first
    }

    /// Every text matching the pattern, in order.
    static func matches(_ text: String, _ pattern: String) -> [String] {
        make(pattern).matches(in: text, range: NSRange(text.startIndex..., in: text)).compactMap {
            Range($0.range, in: text).map { String(text[$0]) }
        }
    }

    /// Escapes a phrase and lets any run of spaces in it match any whitespace.
    static func phrase(_ text: String) -> String {
        text.split(whereSeparator: \.isWhitespace)
            .map { NSRegularExpression.escapedPattern(for: String($0)) }
            .joined(separator: "\\s+")
    }
}

enum Words {
    static let numberWords: Set<String> = [
        "zero", "one", "two", "three", "four", "five", "six", "seven", "eight", "nine", "ten",
        "eleven", "twelve", "thirteen", "fourteen", "fifteen", "sixteen", "seventeen", "eighteen",
        "nineteen", "twenty", "thirty", "forty", "fifty", "sixty", "seventy", "eighty", "ninety",
        "hundred", "thousand", "lakh", "million", "half", "quarter",
    ]

    static let fillers: Set<String> = ["um", "umm", "uh", "uhh", "uhm", "erm", "er", "ah", "ahh", "hmm", "hm", "mm", "mhm"]

    static let spokenMarks: Set<String> = ["comma", "full", "stop", "question", "mark", "exclamation", "point",
                                           "new", "line", "paragraph", "colon", "semicolon", "bullet"]

    /// Lowercased words with punctuation stripped. Digits stay inside their token.
    static func split(_ text: String) -> [String] {
        text.lowercased()
            .split(whereSeparator: { !($0.isLetter || $0.isNumber || $0 == "'") })
            .map(String.init)
    }
}
