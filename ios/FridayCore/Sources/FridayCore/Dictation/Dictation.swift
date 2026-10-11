import Foundation

/// The cleanup tone picked on the keyboard.
public enum Tone: String, Codable, CaseIterable, Sendable {
    case asSaid, casual, formal

    public var label: String {
        switch self {
        case .asSaid: "As said"
        case .casual: "Casual"
        case .formal: "Formal"
        }
    }

    public var next: Tone {
        let all = Tone.allCases
        return all[(all.firstIndex(of: self)! + 1) % all.count]
    }
}

/// The whole text path for one dictation, from transcript to the text the keyboard inserts.
public struct Dictation: Sendable {
    public var fixRules: PhraseRules
    public var snippets: PhraseRules
    /// Words whose spelling and capitals must be kept exactly (dictionary + contact names).
    public var dictionary: [String]

    public init(fixRules: [PhraseRules.Rule] = [], snippets: [PhraseRules.Rule] = [], dictionary: [String] = []) {
        self.fixRules = PhraseRules(fixRules)
        self.snippets = PhraseRules(snippets)
        self.dictionary = dictionary
    }

    /// Step 1, before any AI: fix rules, then snippets. This is what the AI sees.
    public func prepare(_ transcript: String) -> String {
        snippets.apply(fixRules.apply(transcript))
    }

    /// Step 2: pick the AI result if the guard accepts it, else the rule-based cleanup,
    /// then fit it to the text before the cursor.
    public func finish(prepared: String, aiOutput: String?, context: String, tone: Tone = .asSaid) -> String {
        let ruleBased = Cleanup.run(prepared)
        let chosen = CleanupGuard.choose(aiOutput: aiOutput, transcript: prepared, fallback: ruleBased,
                                         relaxed: tone != .asSaid)
        let keep = Set(dictionary.flatMap { [$0, $0.lowercased()] })
        return Continuation.apply(fixRules.apply(chosen), after: context, keepCase: keep)
    }

    /// The user message for the cleanup model (PLAN §7.1).
    public func aiMessage(prepared: String, context: String, tone: Tone) -> String {
        let tail = String(context.suffix(300))
        let words = dictionary.prefix(30).joined(separator: ", ")
        var message = "<context>\(tail)</context>\n<dictionary>\(words)</dictionary>\n"
        if tone != .asSaid { message += "<tone>\(tone.rawValue)</tone>\n" }
        message += "<dictation>\(prepared)</dictation>"
        return message
    }

    /// Whisper's `prompt`: the dictionary words most likely to come up (≤ ~30, RISKS B6).
    /// Whisper copies the style of its prompt. A loose, spoken-style prompt makes it write down
    /// everything said, word for word (false starts, "no wait", repeats), instead of quietly
    /// tidying it and dropping parts; the cleanup AI then does the tidying with full context.
    public static let verbatimStyle = "Umm, let me think like, hmm... Okay, here's what I'm, like, thinking."

    public func whisperPrompt() -> String {
        let words = dictionary.prefix(30).joined(separator: ", ")
        return words.isEmpty ? Dictation.verbatimStyle : Dictation.verbatimStyle + " " + words
    }

    /// Prompt for one piece of a long dictation: the dictionary, then the last words of the
    /// piece before it, so Whisper hears it as a continuation (same sentence, names, spelling).
    /// Whisper reads only ~224 tokens of prompt, so the earlier text is kept short.
    public static func piecePrompt(base: String, previous: String?, words: Int = 40) -> String {
        let tail = (previous ?? "").split(whereSeparator: \.isWhitespace).suffix(words).joined(separator: " ")
        if tail.isEmpty { return base }
        if base.isEmpty { return tail }
        return base + ". " + tail
    }
}
