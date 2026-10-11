import Foundation

/// Every model and endpoint in one place (PLAN §4). Check console.groq.com/docs/models before
/// changing: the catalogue moves.
public enum Models {
    public static let groqBase = URL(string: "https://api.groq.com/openai/v1")!
    public static let geminiBase = URL(string: "https://generativelanguage.googleapis.com/v1beta/openai")!

    public static let whisper = "whisper-large-v3-turbo"
    public static let groqCleanup = "qwen/qwen3.8-27b"
    /// Each Groq model has its own daily allowance, so when the main one runs out, try this.
    public static let groqCleanupBackup = "openai/gpt-oss-120b"
    public static let groqDecision = "openai/gpt-oss-120b"
    public static let geminiCleanup = "gemini-flash-lite-latest"
    public static let geminiDecision = "gemini-flash-latest"

    /// Thinking off or minimal for cleanup: it's a copy-edit, not a puzzle.
    public static func reasoningEffort(for model: String) -> String? {
        if model.hasPrefix("qwen") { return "none" }
        if model.hasPrefix("openai/gpt-oss") { return "low" }
        if model.hasPrefix("gemini") { return "none" }
        return nil
    }
}

/// Who did a job, for the timing line and the quota tracker.
public enum Provider: String, Codable, Sendable, CaseIterable {
    case groq, gemini, apple, rules, device

    public var label: String {
        switch self {
        case .groq: "Groq"
        case .gemini: "Gemini"
        case .apple: "Apple AI"
        case .rules: "rules"
        case .device: "phone"
        }
    }
}

/// What to do after an HTTP status.
public enum CallOutcome: Equatable, Sendable {
    case ok
    /// Rate limit or server trouble: switch to the backup now and cool this one down.
    case useBackup(coolDown: TimeInterval)
    /// The key is wrong or revoked.
    case badKey
    case failed

    public static func from(status: Int, body: String = "") -> CallOutcome {
        switch status {
        case 200..<300: .ok
        // A daily cap won't lift in a minute: rest this model for an hour, then check again.
        case 429 where body.contains("per day"): .useBackup(coolDown: 3_600)
        case 429: .useBackup(coolDown: 60)
        case 408, 500..<600: .useBackup(coolDown: 20)
        case 401, 403: .badKey
        default: .failed
        }
    }
}
