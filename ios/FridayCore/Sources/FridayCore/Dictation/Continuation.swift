import Foundation

/// Makes a dictation continue naturally from the text already before the cursor:
/// no capital mid-sentence, a space where one is needed, no doubled word at the join.
public enum Continuation {
    public static func apply(_ text: String, after before: String, keepCase: Set<String> = []) -> String {
        guard !text.isEmpty else { return text }
        var t = text
        let trimmedBefore = before.trimmingCharacters(in: CharacterSet(charactersIn: " \t\"'”’)"))
        let atSentenceStart = trimmedBefore.isEmpty
            || before.hasSuffix("\n")
            || ".?!:".contains(trimmedBefore.last!)

        // Drop a word that repeats the last word already typed ("I want to" + "to go").
        let lastBefore = Words.split(before).last
        let firstWords = t.split(separator: " ", maxSplits: 1, omittingEmptySubsequences: false)
        if let lastBefore, lastBefore.count > 1, let first = firstWords.first,
           Words.split(String(first)).first == lastBefore, firstWords.count == 2,
           !before.hasSuffix("\n"), !".?!".contains(trimmedBefore.last ?? " ") {
            t = String(firstWords[1])
        }

        if !atSentenceStart {
            t = lowercaseFirstWord(t, keepCase: keepCase)
        }

        let needsSpace = !before.isEmpty
            && !(before.last!.isWhitespace)
            && !(t.first.map { ",.;:?!)%".contains($0) || $0 == "\n" } ?? true)
        if needsSpace { t = " " + t }
        if before.last?.isWhitespace == true, before.last != "\n" {
            t = String(t.drop(while: { $0 == " " }))
        }
        return t
    }

    private static func lowercaseFirstWord(_ text: String, keepCase: Set<String>) -> String {
        let word = text.prefix(while: { $0.isLetter || $0 == "'" })
        guard let first = word.first, first.isUppercase else { return text }
        let plain = String(word)
        let lower = plain.lowercased()
        // Keep "I", acronyms, names from the dictionary, and words capitalised beyond the first letter.
        if lower == "i" || lower.hasPrefix("i'") { return text }
        if keepCase.contains(lower) || keepCase.contains(plain) { return text }
        // Only lowercase everyday words; anything else may be a name.
        guard commonWords.contains(lower) else { return text }
        return first.lowercased() + text.dropFirst()
    }

    static let commonWords: Set<String> = [
        "a", "an", "the", "and", "but", "or", "so", "because", "then", "also", "if", "when", "while",
        "to", "of", "in", "on", "at", "for", "with", "from", "by", "about", "after", "before", "as",
        "it", "it's", "its", "this", "that", "these", "those", "there", "here", "we", "you", "he",
        "she", "they", "me", "him", "her", "us", "them", "my", "your", "our", "their", "his",
        "is", "are", "was", "were", "be", "been", "am", "do", "does", "did", "have", "has", "had",
        "will", "would", "can", "could", "should", "might", "may", "must", "not", "no", "yes",
        "just", "really", "very", "maybe", "probably", "actually", "basically", "even", "still",
        "too", "only", "all", "some", "any", "more", "most", "much", "many", "few", "every",
        "what", "which", "who", "how", "why", "where", "now", "today", "tomorrow", "tonight",
        "yesterday", "later", "soon", "again", "already", "yet", "ok", "okay", "like", "get", "got",
        "go", "going", "come", "coming", "make", "made", "take", "see", "know", "think", "want",
        "need", "let", "let's", "please", "thanks", "sure", "right", "well", "though", "until",
        "since", "than", "into", "out", "up", "down", "over", "off", "back", "around", "both",
        "each", "other", "another", "something", "anything", "nothing", "everything", "one", "two",
        "don't", "didn't", "can't", "won't", "isn't", "wasn't", "i'll", "we'll", "you'll", "that's",
        "there's", "what's", "send", "call", "tell", "ask", "meet", "bring", "buy", "check",
    ]
}
