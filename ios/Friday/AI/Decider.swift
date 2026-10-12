import Foundation
import FridayCore

/// The decision engine (PLAN §7.2): what you said on Home → actions (to-dos, calendar events,
/// boxes). Groq's models in turn, then Gemini; nil if none answered.
@MainActor
final class Decider {
    static let shared = Decider()

    private let steps: [(model: String, quota: String)] = [
        (Models.groqDecision, "groq.chat.backup"),
        (Models.groqCleanup, "groq.chat"),
        (Models.groqCleanupBackup2, "groq.chat.backup2"),
    ]

    func decide(said: String, store: Store, events: [CalendarEvent]) async -> [DecisionAction]? {
        let input = DecisionPrompt.input(now: .now, timeZone: .current, store: store, places: [], said: said, events: events)
        if let key = Keys.get(.groq) {
            for step in steps where QuotaBook.shared.available(step.quota) {
                QuotaBook.shared.record(step.quota)
                let body = CloudRequests.chatBody(model: step.model, system: DecisionPrompt.system, user: input,
                                                  maxTokens: step.model.hasPrefix("openai/gpt-oss") ? 2_500 : 1_200,
                                                  reasoningEffort: Models.reasoningEffort(for: step.model), json: true)
                if let actions = await ask(base: Models.groqBase, key: key, body: body, quota: step.quota, said: said) {
                    return actions
                }
            }
        }
        if let key = Keys.get(.gemini), QuotaBook.shared.available("gemini.chat") {
            QuotaBook.shared.record("gemini.chat")
            let body = CloudRequests.chatBody(model: Models.geminiDecision, system: DecisionPrompt.system, user: input,
                                              maxTokens: 1_200, reasoningEffort: nil, json: true)
            if let actions = await ask(base: Models.geminiBase, key: key, body: body, quota: "gemini.chat", said: said) {
                return actions
            }
        }
        return nil
    }

    /// One call. nil if it failed or the reply wasn't the JSON we asked for.
    private func ask(base: URL, key: String, body: Data, quota: String, said: String) async -> [DecisionAction]? {
        let reply: String? = await withTimeout(9) {
            do {
                return try await CloudClient.shared.chat(base: base, key: key, body: body)
            } catch {
                await MainActor.run { QuotaBook.shared.failed(quota, error) }
                return nil
            }
        }
        guard let reply else { return nil }
        let parsed = DecisionParser.parse(reply, said: said, now: .now, timeZone: .current)
        if parsed.problems.contains(.notJSON) { return nil }
        return parsed.actions
    }
}
