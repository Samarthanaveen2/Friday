import Foundation

/// Which transcript to use once ✓ is tapped (PLAN §5.5).
public enum SpeechChoice: Equatable, Sendable {
    case cloud(String)
    case device(String)
    /// No speech at all: insert nothing and say "Didn't catch that".
    case nothing
}

public enum SpeechRace {
    /// The cloud waits this long after ✓ before the on-device text is used instead.
    public static let cloudBudget: TimeInterval = 1.2

    /// - cloud: Whisper's text if it arrived within the budget, else nil.
    /// - device: Apple's on-device text, if any.
    /// - heardSpeech: the speech detector found speech in the audio.
    public static func pick(cloud: String?, device: String?, heardSpeech: Bool) -> SpeechChoice {
        let deviceText = device?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        let deviceHeard = !deviceText.isEmpty
        guard heardSpeech || deviceHeard else { return .nothing }
        if let cloud {
            let cleaned = PhantomFilter.clean(cloud, deviceHeardSpeech: heardSpeech || deviceHeard)
            if !cleaned.isEmpty { return .cloud(cleaned) }
        }
        return deviceHeard ? .device(deviceText) : .nothing
    }
}

/// Milliseconds per stage, shown in the timing line (PLAN §5.7).
public struct Timings: Equatable, Sendable {
    public var speechMs: Int?
    public var cleanupMs: Int?
    public var totalMs: Int
    public var speechBy: Provider
    public var cleanupBy: Provider

    public init(speechMs: Int?, cleanupMs: Int?, totalMs: Int, speechBy: Provider, cleanupBy: Provider) {
        self.speechMs = speechMs
        self.cleanupMs = cleanupMs
        self.totalMs = totalMs
        self.speechBy = speechBy
        self.cleanupBy = cleanupBy
    }

    /// "Speech 310 ms (Groq) · cleanup 240 ms (Groq) · total 640 ms"
    public var line: String {
        var parts: [String] = []
        parts.append("Speech \(speechMs.map { "\($0) ms " } ?? "")(\(speechBy.label))")
        parts.append("cleanup \(cleanupMs.map { "\($0) ms " } ?? "")(\(cleanupBy.label))")
        parts.append("total \(totalMs) ms")
        return parts.joined(separator: " · ")
    }
}
