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
        /// Why earlier providers weren't used ("Groq: no key", "Apple AI: rejected"), for tuning.
        var notes: [String] = []
    }

    private enum Attempt: Sendable {
        case reply(String)
        case error(String)
    }

    func clean(_ prepared: String, dictation: Dictation, context: String, tone: Tone) async -> Result {
        let started = Date.now
        let message = dictation.aiMessage(prepared: prepared, context: context, tone: tone)
        let maxTokens = CloudRequests.cleanupMaxTokens(for: prepared)

        var notes: [String] = []
        func accepted(_ attempt: Attempt?, _ name: String) -> String? {
            switch attempt {
            case nil:
                notes.append("\(name): timed out")
                return nil
            case .error(let why):
                notes.append("\(name): \(why)")
                return nil
            case .reply(let reply):
                guard let text = extractOut(reply) else {
                    notes.append("\(name): bad reply")
                    return nil
                }
                let verdict = CleanupGuard.check(output: text, transcript: prepared, relaxed: tone != .asSaid)
                guard verdict.accepted else {
                    notes.append("\(name): rejected (\(text.prefix(40)))")
                    return nil
                }
                return reply
            }
        }
        func done(_ reply: String?, _ by: Provider) -> Result {
            let text = dictation.finish(prepared: prepared, aiOutput: reply, context: context, tone: tone)
            return Result(text: text, by: by, ms: Int(Date.now.timeIntervalSince(started) * 1000), notes: notes)
        }

        if let key = Keys.get(.groq), QuotaBook.shared.available("groq.chat") {
            QuotaBook.shared.record("groq.chat")
            let body = CloudRequests.chatBody(model: Models.groqCleanup, system: Dictation.systemPrompt, user: message,
                                              maxTokens: maxTokens, reasoningEffort: "low")
            let reply = await cloud(base: Models.groqBase, key: key, body: body, quota: "groq.chat")
            if let good = accepted(reply, "Groq") { return done(good, .groq) }
        } else {
            notes.append(Keys.get(.groq) == nil ? "Groq: no key" : "Groq: resting (limit)")
        }
        if let key = Keys.get(.gemini), QuotaBook.shared.available("gemini.chat") {
            QuotaBook.shared.record("gemini.chat")
            let body = CloudRequests.chatBody(model: Models.geminiCleanup, system: Dictation.systemPrompt, user: message,
                                              maxTokens: maxTokens, reasoningEffort: "none")
            let reply = await cloud(base: Models.geminiBase, key: key, body: body, quota: "gemini.chat")
            if let good = accepted(reply, "Gemini") { return done(good, .gemini) }
        }
        if case .available = SystemLanguageModel.default.availability {
            let reply = await withTimeout(2.5) { () async -> Attempt? in
                let session = LanguageModelSession(instructions: Dictation.systemPrompt)
                do {
                    return .reply(try await session.respond(to: message).content)
                } catch {
                    return .error(String(describing: error).prefix(60).description)
                }
            }
            if let good = accepted(reply, "Apple AI") { return done(good, .apple) }
        } else {
            notes.append("Apple AI: not available")
        }
        return done(nil, .rules)
    }

    private func cloud(base: URL, key: String, body: Data, quota: String) async -> Attempt? {
        await withTimeout(2.0) { () async -> Attempt? in
            do {
                return .reply(try await CloudClient.shared.chat(base: base, key: key, body: body))
            } catch {
                await MainActor.run { QuotaBook.shared.failed(quota, error) }
                if let error = error as? CloudError {
                    switch error.kind {
                    case .badKey: return .error("key not accepted")
                    case .useBackup: return .error("busy or limit")
                    case .network: return .error("no internet")
                    default: return .error("failed")
                    }
                }
                return .error("failed")
            }
        }
    }
}
