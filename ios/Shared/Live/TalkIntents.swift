import AppIntents
import Foundation

/// "Talk to Friday" from the Action button, Siri or Shortcuts: press once to start listening,
/// again to finish. Friday does what you said (calendar, to-dos, boxes) without opening, and the
/// Dynamic Island shows the result. Runs in the app process; if iOS runs it in the widget
/// extension (Control Center), it opens Friday, which starts listening.
struct TalkToFridayIntent: AudioRecordingIntent {
    static let title: LocalizedStringResource = "Talk to Friday"
    static let description = IntentDescription("Talk to Friday: add meetings and to-dos, cancel or move events, save notes, ask about your day.")
    static let openAppWhenRun = false

    init() {}

    #if FRIDAY_APP
    @MainActor
    func perform() async throws -> some IntentResult {
        // Waits for the mic (or the result): iOS stops Friday if the action ends first.
        if Talk.shared.listening {
            await Talk.shared.finish()
        } else {
            await Talk.shared.begin(.newBox, source: .intent)
        }
        return .result()
    }
    #else
    @MainActor
    func perform() async throws -> some IntentResult & OpensIntent {
        .result(opensIntent: OpenURLIntent(URL(string: "friday://talk")!))
    }
    #endif
}

/// ✓ in the Dynamic Island / Lock Screen while listening.
struct FinishTalkIntent: LiveActivityIntent {
    static let title: LocalizedStringResource = "Done talking"
    init() {}

    #if FRIDAY_APP
    @MainActor
    func perform() async throws -> some IntentResult {
        await Talk.shared.finish()
        return .result()
    }
    #else
    func perform() async throws -> some IntentResult { .result() }
    #endif
}

/// ✕ in the Dynamic Island / Lock Screen while listening.
struct CancelTalkIntent: LiveActivityIntent {
    static let title: LocalizedStringResource = "Cancel talking"
    init() {}

    #if FRIDAY_APP
    @MainActor
    func perform() async throws -> some IntentResult {
        Talk.shared.cancel()
        return .result()
    }
    #else
    func perform() async throws -> some IntentResult { .result() }
    #endif
}
