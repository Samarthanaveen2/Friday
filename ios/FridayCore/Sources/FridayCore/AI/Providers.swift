import Foundation

/// Every model and endpoint in one place (PLAN §4). Check console.groq.com/docs/models before
/// changing: the catalogue moves.
public enum Models {
    public static let groqBase = URL(string: "https://api.groq.com/openai/v1")!
    public static let geminiBase = URL(string: "https://generativelanguage.googleapis.com/v1beta/openai")!

    public static let whisper = "whisper-large-v3-turbo"
    public static let groqCleanup = "openai/gpt-oss-20b"
    public static let groqDecision = "openai/gpt-oss-120b"
    public static let geminiCleanup = "gemini-flash-lite-latest"
    public static let geminiDecision = "gemini-flash-latest"
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

    public static func from(status: Int) -> CallOutcome {
        switch status {
        case 200..<300: .ok
        case 429: .useBackup(coolDown: 60)
        case 408, 500..<600: .useBackup(coolDown: 20)
        case 401, 403: .badKey
        default: .failed
        }
    }
}
