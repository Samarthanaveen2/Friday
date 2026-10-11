import Foundation

/// Keeps the AI cleanup honest (RISKS C1): it may tidy what you said, never answer or rewrite it.
public enum CleanupGuard {
    public struct Verdict: Equatable, Sendable {
        public var accepted: Bool
        /// Share of the output's words that were in the transcript.
        public var overlap: Double
        public var lengthRatio: Double
    }

    /// `relaxed` is for the Casual/Formal tones, which are allowed to reword more.
    public static func check(output: String, transcript: String, relaxed: Bool = false) -> Verdict {
        let o = normalized(output)
        let t = normalized(transcript)
        guard !o.isEmpty else {
            return Verdict(accepted: false, overlap: 0, lengthRatio: 0)
        }
        var pool: [String: Int] = [:]
        for word in t { pool[word, default: 0] += 1 }
        var matched = 0
        for word in o where (pool[word] ?? 0) > 0 {
            pool[word]! -= 1
            matched += 1
        }
        let overlap = Double(matched) / Double(o.count)
        let recall = t.isEmpty ? 1 : Double(matched) / Double(t.count)
        // Never add facts: no new numbers, and a question keeps its question word.
        let addsNumbers = o.filter { $0 == "#" }.count > t.filter { $0 == "#" }.count
        let questionWords: Set<String> = ["what", "when", "where", "why", "who", "how", "which"]
        let dropsQuestion = t.contains(where: questionWords.contains) && !o.contains(where: questionWords.contains)
        let outChars = Double(output.trimmingCharacters(in: .whitespacesAndNewlines).count)
        let inChars = Double(max(1, transcript.trimmingCharacters(in: .whitespacesAndNewlines).count))
        let ratio = outChars / inChars
        let minOverlap = relaxed ? 0.5 : 0.7
        let maxLength = (relaxed ? 1.5 : 1.3) * inChars + 12
        let accepted = overlap >= minOverlap && recall >= (relaxed ? 0.35 : 0.45) && outChars <= maxLength
            && !addsNumbers && (relaxed || !dropsQuestion)
        return Verdict(accepted: accepted, overlap: overlap, lengthRatio: ratio)
    }

    /// The text to insert: the AI's version if it passes, otherwise the rule-based one.
    public static func choose(aiOutput: String?, transcript: String, fallback: String, relaxed: Bool = false) -> String {
        guard let raw = aiOutput, let text = extractOut(raw),
              check(output: text, transcript: transcript, relaxed: relaxed).accepted
        else { return fallback }
        return text
    }

    /// Words for comparison: lowercase, no punctuation, fillers and spoken marks dropped,
    /// every number (digits or words) treated as the same token so "five thirty" ≈ "5:30".
    static func normalized(_ text: String) -> [String] {
        var words: [String] = []
        var lastWasNumber = false
        for word in Words.split(text) {
            if Words.fillers.contains(word) || Words.spokenMarks.contains(word) { continue }
            let isNumber = word.first?.isNumber == true || Words.numberWords.contains(word)
                || ["am", "pm", "rupees", "rupee", "percent", "rs"].contains(word)
            if isNumber {
                if !lastWasNumber { words.append("#") }
                lastWasNumber = true
                continue
            }
            lastWasNumber = false
            words.append(word)
        }
        return words
    }
}

/// The model is told to answer inside <out></out>. Returns what's inside, or the whole reply
/// if it forgot the tags but otherwise looks like plain text.
public func extractOut(_ reply: String) -> String? {
    if let start = reply.range(of: "<out>"), let end = reply.range(of: "</out>", range: start.upperBound..<reply.endIndex) {
        return String(reply[start.upperBound..<end.lowerBound]).trimmingCharacters(in: .whitespacesAndNewlines)
    }
    let trimmed = reply.trimmingCharacters(in: .whitespacesAndNewlines)
    if trimmed.isEmpty || trimmed.contains("<out") || trimmed.contains("</") { return nil }
    return trimmed
}

/// Whisper invents subtitles on silence (RISKS B1).
public enum PhantomFilter {
    static let phrases = [
        "thank you for watching", "thanks for watching", "thank you so much for watching",
        "thank you very much for watching", "please subscribe", "like and subscribe",
        "don't forget to subscribe", "subtitles by the amara.org community", "see you in the next video",
        "thanks for listening", "thank you for listening",
    ]

    /// `deviceHeardSpeech`: whether Apple's on-device recogniser heard any words in this audio.
    public static func clean(_ text: String, deviceHeardSpeech: Bool) -> String {
        guard deviceHeardSpeech else { return "" }
        var t = text.trimmingCharacters(in: .whitespacesAndNewlines)
        for phrase in phrases {
            let pattern = "[ ,]*" + Rx.wordStart + Rx.phrase(phrase) + Rx.wordEnd + "[.!]*\\s*$"
            t = Rx.replace(t, pattern, with: "")
        }
        return t.trimmingCharacters(in: .whitespacesAndNewlines)
    }
}

/// Joins two pause-chunked transcripts, dropping words repeated across the join (RISKS B3).
public func joinChunks(_ first: String, _ second: String) -> String {
    let a = first.trimmingCharacters(in: .whitespacesAndNewlines)
    let b = second.trimmingCharacters(in: .whitespacesAndNewlines)
    if a.isEmpty { return b }
    if b.isEmpty { return a }
    let aWords = a.split(separator: " ").map(String.init)
    let bWords = b.split(separator: " ").map(String.init)
    let normalize = { (w: String) in Words.split(w).joined() }
    var drop = 0
    for k in stride(from: min(4, aWords.count, bWords.count), through: 1, by: -1) {
        if aWords.suffix(k).map(normalize) == bWords.prefix(k).map(normalize) {
            drop = k
            break
        }
    }
    return ([a] + bWords.dropFirst(drop)).joined(separator: " ")
}
