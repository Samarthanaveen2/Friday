import Foundation
import FoundationModels
import FridayCore

/// Dictation cleanup chain: Groq → Gemini → Apple's on-device model → rules (PLAN §4).
/// Every AI answer goes through the guard; if it answered or rewrote, the rule-based text wins.
@MainActor
final class Cleaner {
    static let shared = Cleaner()

    struct Result: Sendable {
        var text: String
        var by: Provider
        var ms: Int
    }

    func clean(_ prepared: String, dictation: Dictation, context: String, tone: Tone) async -> Result {
        let started = Date.now
        let message = dictation.aiMessage(prepared: prepared, context: context, tone: tone)
        let maxTokens = CloudRequests.cleanupMaxTokens(for: prepared)

        func accepted(_ reply: String?) -> String? {
            guard let reply, let text = extractOut(reply),
                  CleanupGuard.check(output: text, transcript: prepared, relaxed: tone != .asSaid).accepted
            else { return nil }
            return reply
        }
        func done(_ reply: String?, _ by: Provider) -> Result {
            let text = dictation.finish(prepared: prepared, aiOutput: reply, context: context, tone: tone)
            return Result(text: text, by: by, ms: Int(Date.now.timeIntervalSince(started) * 1000))
        }

        if let key = Keys.get(.groq), QuotaBook.shared.available("groq.chat") {
            QuotaBook.shared.record("groq.chat")
            let body = CloudRequests.chatBody(model: Models.groqCleanup, system: Dictation.systemPrompt, user: message,
                                              maxTokens: maxTokens, reasoningEffort: "low")
            let reply = await cloud(base: Models.groqBase, key: key, body: body, quota: "groq.chat")
            if let good = accepted(reply) { return done(good, .groq) }
        }
        if let key = Keys.get(.gemini), QuotaBook.shared.available("gemini.chat") {
            QuotaBook.shared.record("gemini.chat")
            let body = CloudRequests.chatBody(model: Models.geminiCleanup, system: Dictation.systemPrompt, user: message,
                                              maxTokens: maxTokens, reasoningEffort: "none")
            let reply = await cloud(base: Models.geminiBase, key: key, body: body, quota: "gemini.chat")
            if let good = accepted(reply) { return done(good, .gemini) }
        }
        if case .available = SystemLanguageModel.default.availability {
            let reply = await withTimeout(2.5) { () async -> String? in
                let session = LanguageModelSession(instructions: Dictation.systemPrompt)
                return try? await session.respond(to: message).content
            }
            if let good = accepted(reply) { return done(good, .apple) }
        }
        return done(nil, .rules)
    }

    private func cloud(base: URL, key: String, body: Data, quota: String) async -> String? {
        await withTimeout(2.0) { () async -> String? in
            do {
                return try await CloudClient.shared.chat(base: base, key: key, body: body)
            } catch {
                await MainActor.run { QuotaBook.shared.failed(quota, error) }
                return nil
            }
        }
    }
}
