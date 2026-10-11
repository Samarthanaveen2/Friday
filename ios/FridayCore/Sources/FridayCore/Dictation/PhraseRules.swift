import Foundation

/// Whole-word, case-insensitive phrase replacement, longest phrase first.
/// Used for snippets ("my email" → address) and fix rules ("summer tha" → "Samartha").
/// A rule for "sam" never touches "same".
public struct PhraseRules: Sendable {
    public struct Rule: Equatable, Sendable {
        public var from: String
        public var to: String

        public init(_ from: String, _ to: String) {
            self.from = from
            self.to = to
        }
    }

    private let lookup: [String: String]
    private let pattern: String?

    public init(_ rules: [Rule]) {
        var lookup: [String: String] = [:]
        for rule in rules {
            let key = PhraseRules.key(rule.from)
            guard !key.isEmpty, lookup[key] == nil else { continue }
            lookup[key] = rule.to
        }
        self.lookup = lookup
        let alternatives = lookup.keys.sorted { $0.count > $1.count }.map(Rx.phrase)
        pattern = alternatives.isEmpty ? nil : Rx.wordStart + "(?:" + alternatives.joined(separator: "|") + ")" + Rx.wordEnd
    }

    public func apply(_ text: String) -> String {
        guard let pattern else { return text }
        return Rx.replace(text, Rx.make(pattern)) { match in lookup[PhraseRules.key(match)] ?? match }
    }

    private static func key(_ text: String) -> String {
        text.lowercased().split(whereSeparator: \.isWhitespace).joined(separator: " ")
    }
}
