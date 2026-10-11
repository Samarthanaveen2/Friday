import Foundation

/// Every model and endpoint in one place (PLAN §4). Check console.groq.com/docs/models before
/// changing: the catalogue moves.
///
/// Groq free tier, checked 2026-10-11 (console.groq.com/docs/models, console.groq.com/docs/rate-limits).
/// Limits are per model, so each extra model is more daily room on the same free key.
///   model                          RPM  RPD  TPM  TPD
///   qwen/qwen3.8-27b (preview)      30   1K   8K  200K  main cleanup
///   openai/gpt-oss-120b             30   1K   8K  200K  backup (also the decision model)
///   openai/gpt-oss-20b              30   1K   8K  200K  backup 2
///   openai/gpt-oss-safeguard-20b     3   1K   2K  200K  not used: safety classifier, tiny TPM
/// llama-3.3-70b-versatile, llama-3.1-8b-instant and minimaxai/minimax-m2.7 are Enterprise-only now.
/// reasoning_effort: qwen3.8 takes none/low/medium/high; gpt-oss takes low/medium/high only.
/// Anything outside a model's set is a 400, so unknown models get no reasoning_effort at all.
public enum Models {
    public static let groqBase = URL(string: "https://api.groq.com/openai/v1")!
    public static let geminiBase = URL(string: "https://generativelanguage.googleapis.com/v1beta/openai")!

    public static let whisper = "whisper-large-v3-turbo"
    public static let groqCleanup = "qwen/qwen3.8-27b"
    /// Each Groq model has its own daily allowance, so when the main one runs out, try this.
    public static let groqCleanupBackup = "openai/gpt-oss-120b"
    /// Smaller, faster sibling with its own daily allowance: the last Groq try.
    public static let groqCleanupBackup2 = "openai/gpt-oss-20b"
    public static let groqDecision = "openai/gpt-oss-120b"
    public static let geminiCleanup = "gemini-flash-lite-latest"
    public static let geminiDecision = "gemini-flash-latest"

    /// One Groq try in the cleanup chain: the model, its quota counter, its name in the notes.
    public struct CleanupStep: Equatable, Sendable {
        public let model: String
        public let quota: String
        public let name: String
    }

    /// Groq models tried in order for cleanup, before Gemini and Apple. Each has its own quota
    /// key, so a model resting after its daily limit is skipped straight away.
    public static let groqCleanupChain: [CleanupStep] = [
        CleanupStep(model: groqCleanup, quota: "groq.chat", name: "Groq"),
        CleanupStep(model: groqCleanupBackup, quota: "groq.chat.backup", name: "Groq backup"),
        CleanupStep(model: groqCleanupBackup2, quota: "groq.chat.backup2", name: "Groq backup 2"),
    ]

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
