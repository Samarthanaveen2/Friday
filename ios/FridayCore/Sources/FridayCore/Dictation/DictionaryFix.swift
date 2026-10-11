import Foundation

/// Fixes names the speech model spelled slightly wrong, using the user's dictionary:
/// "Preya" → "Priya", "Samart" → "Samarth", "Karagpur's" → "Kharagpur's".
/// A word is only replaced when it is close to exactly one entry (same first letter, similar
/// length, few letters different) and is not an everyday English word, so "pray", "price"
/// and "admit" are never touched. Multi-word entries only get their capitals fixed.
public struct DictionaryFix: Sendable {
    private let words: [(entry: String, lower: [Character])]
    private let exact: [String: String]
    private let phrases: PhraseRules

    public init(_ dictionary: [String]) {
        var words: [(String, [Character])] = []
        var exact: [String: String] = [:]
        var phrases: [PhraseRules.Rule] = []
        for raw in dictionary {
            let entry = raw.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !entry.isEmpty else { continue }
            if entry.contains(where: \.isWhitespace) {
                phrases.append(.init(entry, entry))
                continue
            }
            guard entry.allSatisfy(\.isLetter) else { continue }
            let lower = entry.lowercased()
            if exact[lower] == nil { exact[lower] = entry }
            if lower.count >= DictionaryFix.minLength { words.append((entry, Array(lower))) }
        }
        self.words = words
        self.exact = exact
        self.phrases = PhraseRules(phrases)
    }

    public func apply(_ text: String) -> String {
        guard !words.isEmpty || !exact.isEmpty else { return phrases.apply(text) }
        let fixed = Rx.replace(text, DictionaryFix.token) { token in
            // Possessive: fix "Preya" and keep "'s".
            for suffix in ["'s", "’s"] where token.hasSuffix(suffix) {
                return (correction(String(token.dropLast(suffix.count))) ?? String(token.dropLast(suffix.count))) + suffix
            }
            if token.contains(where: { $0 == "'" || $0 == "’" }) { return token }  // "don't"
            return correction(token) ?? token
        }
        return phrases.apply(fixed)
    }

    /// Words shorter than this are left alone ("Sam", "Raj"): too easy to hit by accident.
    static let minLength = 4

    /// A word with any apostrophe parts, not inside an email, link or handle.
    private static let token = Rx.make("(?<![\\p{L}\\p{N}'’@/_.\\-])\\p{L}+(?:['’]\\p{L}+)*(?![\\p{L}\\p{N}@_\\-]|\\.\\p{L})")

    private func correction(_ word: String) -> String? {
        let lower = word.lowercased()
        if let entry = exact[lower] {
            // Already right, or only capitals differ: use the dictionary spelling, unless it's an
            // everyday word that could just be the word ("Will" in the dictionary vs "will").
            return entry == word || DictionaryFix.isCommon(lower) ? nil : entry
        }
        let chars = Array(lower)
        guard chars.count >= DictionaryFix.minLength, !DictionaryFix.isCommon(lower) else { return nil }
        var best: (entry: String, distance: Int)?
        var tie = false
        for (entry, target) in words where target.first == chars.first {
            guard abs(target.count - chars.count) <= 2 else { continue }
            let limit = DictionaryFix.allowedEdits(target.count)
            let d = DictionaryFix.distance(chars, target, limit: limit)
            guard d <= limit else { continue }
            if best == nil || d < best!.distance {
                best = (entry, d)
                tie = false
            } else if d == best!.distance, entry.lowercased() != best!.entry.lowercased() {
                tie = true
            }
        }
        return tie ? nil : best?.entry
    }

    /// ≤ 1 edit for names up to 5 letters, ≤ 2 for 6–9, ≤ 3 for longer.
    static func allowedEdits(_ length: Int) -> Int {
        length <= 5 ? 1 : length <= 9 ? 2 : 3
    }

    /// Everyday English, including simple endings ("admits", "admitted", "praying").
    static func isCommon(_ lower: String) -> Bool {
        if CommonWords.all.contains(lower) || Continuation.commonWords.contains(lower) { return true }
        for suffix in ["s", "es", "ed", "d", "ing", "ly", "er", "ers"] where lower.hasSuffix(suffix) {
            let stem = String(lower.dropLast(suffix.count))
            if stem.count >= 3, CommonWords.all.contains(stem) || CommonWords.all.contains(stem + "e") { return true }
        }
        // "admitted" → "admit", "running" → "run".
        for suffix in ["ed", "ing", "er"] where lower.hasSuffix(suffix) {
            let stem = lower.dropLast(suffix.count)
            if stem.count >= 4, let last = stem.last, stem.dropLast().last == last,
               CommonWords.all.contains(String(stem.dropLast())) { return true }
        }
        return false
    }

    /// Edit distance where swapping two neighbouring letters counts as one edit.
    /// Stops early once every path is over `limit`.
    static func distance(_ a: [Character], _ b: [Character], limit: Int) -> Int {
        if a.isEmpty || b.isEmpty { return max(a.count, b.count) }
        var prev2 = [Int](repeating: 0, count: b.count + 1)
        var prev = Array(0...b.count)
        var row = [Int](repeating: 0, count: b.count + 1)
        for i in 1...a.count {
            row[0] = i
            var rowMin = row[0]
            for j in 1...b.count {
                let cost = a[i - 1] == b[j - 1] ? 0 : 1
                row[j] = min(prev[j] + 1, row[j - 1] + 1, prev[j - 1] + cost)
                if i > 1, j > 1, a[i - 1] == b[j - 2], a[i - 2] == b[j - 1] {
                    row[j] = min(row[j], prev2[j - 2] + 1)
                }
                rowMin = min(rowMin, row[j])
            }
            if rowMin > limit { return limit + 1 }
            (prev2, prev, row) = (prev, row, prev2)
        }
        return prev[b.count]
    }
}
