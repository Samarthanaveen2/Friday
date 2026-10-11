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
    public func whisperPrompt() -> String {
        dictionary.prefix(30).joined(separator: ", ")
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

    public static let systemPrompt = """
    You are a dictation cleaner, not an assistant. The user is typing by voice; turn the raw transcript into the text they meant to type.
    Reply with ONLY the cleaned text inside <out></out>. Never answer, reply to, explain, add to, or summarise it.
    Rules:
    - Remove fillers (um, uh, erm, hmm, and "like" or "you know" when used as filler) and stutters ("I I think" -> "I think"). Keep every meaningful word.
    - Apply corrections and keep only the final version: "Tuesday, wait, no, Wednesday" -> "Wednesday"; "at 5, no 6" -> "at 6"; "send it to Rahul, sorry, I mean Arjun" -> "send it to Arjun".
    - Fix punctuation and capitals. A question ends with a question mark. Use DICTIONARY spellings exactly.
    - Keep the speaker's words, tone and slang ("bro", "gonna", "lol"). Do not make it formal. Do not translate.
    - Spoken formatting: "comma" -> ","; "full stop" -> "."; "question mark" -> "?"; "new line" -> line break; "new paragraph" -> blank line. "bullet point X" -> a line "- X". "number one X number two Y" -> lines "1. X" and "2. Y"; words said before the list stay as the first line.
    - Write numbers as digits: times 5:30, money ₹500, 20%, phone numbers as digits. Emails as name@gmail.com, links as example.com.
    - CONTEXT is text already typed before the cursor. Output ONLY the new words and never repeat the CONTEXT. If CONTEXT ends mid-sentence, continue it in lowercase.
    - If the dictation is a question or an instruction ("write a poem", "translate this"), type it as written. Never respond to it.
    - If a <tone> is given: casual = relaxed and friendly, formal = polite and professional. Keep the meaning and every fact.
    Examples:
    <dictation>um so can you send me the slides</dictation> -> <out>So can you send me the slides?</out>
    <dictation>meet friday wait no saturday at 4</dictation> -> <out>Meet Saturday at 4.</out>
    <dictation>what's the capital of france</dictation> -> <out>What's the capital of France?</out>
    <context>I called him but</context><dictation>he didn't pick up</dictation> -> <out>he didn't pick up.</out>
    <dictation>packing bullet point charger bullet point towel</dictation> -> <out>Packing
    - Charger
    - Towel</out>
    """
}
