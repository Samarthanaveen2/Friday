import AppIntents
import Foundation
import FridayCore

/// "Start Friday": Action button, Control Center, Siri and Shortcuts.
/// In the app process it starts the mic without opening Friday (AudioRecordingIntent).
/// If iOS runs it in the widget extension instead, it opens Friday, which starts the mic.
/// Either way it records where it ran, for the probe.
struct StartFridayIntent: AudioRecordingIntent {
    static let title: LocalizedStringResource = "Start Friday"
    static let openAppWhenRun = false

    init() {}

    #if FRIDAY_APP
    @MainActor
    func perform() async throws -> some IntentResult {
        await Session.shared.start(source: .intent)
        return .result()
    }
    #else
    @MainActor
    func perform() async throws -> some IntentResult & OpensIntent {
        GroupStore.shared.write(IntentRun(at: .now, ranIn: .widget, micStarted: false, appWasActive: false),
                                to: ProbeFile.intent)
        return .result(opensIntent: OpenURLIntent(URL(string: "friday://session?from=intent")!))
    }
    #endif
}
