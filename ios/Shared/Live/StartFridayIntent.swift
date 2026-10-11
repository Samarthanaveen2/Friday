import AppIntents
import Foundation

/// "Start Friday": Action button, Control Center, Siri and Shortcuts.
/// As an AudioRecordingIntent it may start the mic without opening the app.
/// The probe records which process it actually ran in.
struct StartFridayIntent: AudioRecordingIntent {
    static let title: LocalizedStringResource = "Start Friday"
    static let openAppWhenRun = false

    init() {}

    @MainActor
    func perform() async throws -> some IntentResult {
        #if FRIDAY_APP
        await Session.shared.start(source: .intent)
        #endif
        return .result()
    }
}
