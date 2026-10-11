import FridayCore
import Observation
import SwiftUI

/// One dictation end to end: record → speech-to-text race → cleanup chain → text to insert.
@MainActor
@Observable
final class DictationPipeline {
    struct Outcome: Sendable {
        var text: String
        var raw: String
        var timings: Timings
        var nothing: Bool
        var notes: [String] = []
    }

    static let shared = DictationPipeline()

    private(set) var working = false
    private(set) var last: Outcome?

    var tone: Tone = .asSaid

    /// Starts recording. False if no session is running.
    func begin() -> Bool {
        let session = Session.shared
        guard session.startDictation() else { return false }
        Transcriber.shared.begin(sink: session.sink, prompt: dictation.whisperPrompt())
        Cleaner.shared.prewarm()
        return true
    }

    func cancel() {
        Transcriber.shared.cancel(sink: Session.shared.sink)
        Session.shared.cancelDictation()
    }

    /// Stops recording and returns the cleaned text (empty when nothing was said).
    func finish(context: String = "") async -> Outcome? {
        guard let recording = Session.shared.finishDictation() else { return nil }
        working = true
        defer { working = false }
        let started = Date.now
        let speech = await Transcriber.shared.finish(recording, sink: Session.shared.sink)

        let raw: String
        switch speech.choice {
        case .cloud(let text), .device(let text): raw = text
        case .nothing:
            let outcome = Outcome(text: "", raw: "",
                                  timings: Timings(speechMs: speech.ms, cleanupMs: nil,
                                                   totalMs: Int(Date.now.timeIntervalSince(started) * 1000),
                                                   speechBy: speech.by, cleanupBy: .rules),
                                  nothing: true)
            last = outcome
            return outcome
        }
        let d = dictation
        let cleaned = await Cleaner.shared.clean(d.prepare(raw), dictation: d, context: context, tone: tone)
        let outcome = Outcome(text: cleaned.text, raw: raw,
                              timings: Timings(speechMs: speech.by == .device ? nil : speech.ms, cleanupMs: cleaned.ms,
                                               totalMs: Int(Date.now.timeIntervalSince(started) * 1000),
                                               speechBy: speech.by, cleanupBy: cleaned.by),
                              nothing: false, notes: (speech.detail.map { ["Speech: \($0)"] } ?? []) + cleaned.notes)
        last = outcome
        return outcome
    }

    /// Settings → Dictionary (fix rules and snippets arrive in a later phase).
    var dictation: Dictation {
        Dictation(dictionary: UserDefaults.standard.stringArray(forKey: "dict.words") ?? [])
    }

    /// Warms the connection when a session starts.
    static func warm() {
        if let key = Keys.get(.groq) { CloudClient.shared.warm(key: key) }
        Task { _ = await OnDeviceSpeech.shared.prepare() }
        Cleaner.shared.prewarm()
    }
}
