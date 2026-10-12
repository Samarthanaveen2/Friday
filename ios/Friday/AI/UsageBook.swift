import Foundation
import FridayCore
import Observation

/// Today's usage per model, saved between launches, for Settings → AI usage.
@MainActor
@Observable
final class UsageBook {
    static let shared = UsageBook()

    private(set) var usage: Usage
    private let defaults = UserDefaults.standard

    private init() {
        usage = defaults.data(forKey: "ai.usage").flatMap { try? JSONDecoder().decode(Usage.self, from: $0) } ?? Usage()
    }

    var lastCleanup: String? {
        get { usage.lastCleanup }
        set { usage.lastCleanup = newValue; save() }
    }

    var lastSpeech: String? {
        get { usage.lastSpeech }
        set { usage.lastSpeech = newValue; save() }
    }

    func record(model: String, headers: [String: String], body: Data?, audioSeconds: Double?, ok: Bool) {
        usage.record(model: model, headers: headers, body: body, audioSeconds: audioSeconds, ok: ok,
                     now: .now, day: Usage.dayKey(.now, in: .current))
        save()
    }

    func today(_ model: String) -> ModelUsage {
        usage.today(model, day: Usage.dayKey(.now, in: .current))
    }

    private func save() {
        if let data = try? JSONEncoder().encode(usage) { defaults.set(data, forKey: "ai.usage") }
    }
}
