import Foundation
import FridayCore

/// What speech-to-text produced for one dictation.
struct SpeechResult: Sendable {
    var choice: SpeechChoice
    var cloudText: String?
    var deviceText: String?
    var ms: Int?
    var by: Provider
}

/// Runs cloud and on-device speech side by side for one dictation (PLAN §5).
/// Long dictations upload finished parts at pauses while you're still talking.
@MainActor
final class Transcriber {
    static let shared = Transcriber()

    private var feed: AsyncStream<[Float]>.Continuation?
    private var chunkTimer: Timer?
    /// Uploads already running, keyed by the chunk's first sample.
    private var uploads: [Int: Task<String?, Never>] = [:]
    /// Decides the cut points; they never move, so live uploads always line up with the end result.
    private var chunker = LiveChunker()
    /// The newest live upload; the next piece waits for its text to use as context.
    private var lastUpload: Task<String?, Never>?
    private var prompt = ""

    func begin(sink: AudioSink, prompt: String) {
        self.prompt = prompt
        uploads = [:]
        lastUpload = nil
        chunker = LiveChunker()
        let (stream, continuation) = AsyncStream.makeStream(of: [Float].self)
        feed = continuation
        sink.setLive { samples in continuation.yield(samples) }
        Task { await OnDeviceSpeech.shared.start(stream) }

        if Keys.get(.groq) != nil {
            chunkTimer = Timer.scheduledTimer(withTimeInterval: 1.5, repeats: true) { _ in
                MainActor.assumeIsolated { Transcriber.shared.uploadFinishedChunks(sink: sink) }
            }
        }
    }

    func cancel(sink: AudioSink) {
        stopFeeding(sink: sink)
        uploads.values.forEach { $0.cancel() }
        uploads = [:]
        lastUpload = nil
        Task { _ = await OnDeviceSpeech.shared.finish() }
    }

    func finish(_ recording: Recording, sink: AudioSink) async -> SpeechResult {
        stopFeeding(sink: sink)
        let started = Date.now
        let heard = recording.hasSpeech

        var cloud: String?
        if heard, let key = Keys.get(.groq), QuotaBook.shared.available("groq.whisper") {
            // Back-to-back ranges from the first sample to the last: nothing can be skipped.
            var ranges = chunker.finalRanges(total: recording.samples.count)
            // Only a final tail with no speech is left out (Whisper invents text on silence).
            if ranges.count > 1, let tail = ranges.last, !Recording(samples: Array(recording.samples[tail])).hasSpeech {
                ranges.removeLast()
            }
            // Each piece not sent yet (normally just the tail) hears the text of the piece before it.
            var tasks: [Task<String?, Never>] = []
            for range in ranges {
                tasks.append(uploads[range.lowerBound]
                    ?? upload(Array(recording.samples[range]), key: key, trim: ranges.count == 1, after: tasks.last))
            }
            cloud = await withTimeout(ranges.count > 1 ? 2.5 : SpeechRace.cloudBudget) {
                var parts: [String] = []
                for task in tasks {
                    guard let text = await task.value else { return nil }
                    parts.append(text)
                }
                return parts.reduce("") { joinChunks($0, $1) }
            }
        }
        uploads = [:]
        lastUpload = nil

        let cloudMs = Int(Date.now.timeIntervalSince(started) * 1000)
        if let cloud, case .cloud(let text) = SpeechRace.pick(cloud: cloud, device: nil, heardSpeech: heard) {
            Task { _ = await OnDeviceSpeech.shared.finish() }
            return SpeechResult(choice: .cloud(text), cloudText: cloud, deviceText: nil, ms: cloudMs, by: .groq)
        }
        let device = await withTimeout(2.0) { await OnDeviceSpeech.shared.finish() }
        let choice = SpeechRace.pick(cloud: cloud, device: device, heardSpeech: heard)
        let by: Provider = { if case .cloud = choice { return .groq } else { return .device } }()
        return SpeechResult(choice: choice, cloudText: cloud, deviceText: device,
                            ms: Int(Date.now.timeIntervalSince(started) * 1000), by: by)
    }

    private func stopFeeding(sink: AudioSink) {
        chunkTimer?.invalidate()
        chunkTimer = nil
        sink.setLive(nil)
        feed?.finish()
        feed = nil
    }

    /// Commits cuts at pauses and uploads each finished chunk while you keep talking.
    private func uploadFinishedChunks(sink: AudioSink) {
        guard let key = Keys.get(.groq), QuotaBook.shared.available("groq.whisper") else { return }
        let samples = sink.snapshot()
        while let range = chunker.update(samples: samples) {
            let task = upload(Array(samples[range]), key: key, trim: false, after: lastUpload)
            uploads[range.lowerBound] = task
            lastUpload = task
        }
    }

    /// Sends one piece. With `after`, it first waits (up to 3 s) for the previous piece's text and
    /// passes its last words to Whisper, so a sentence split at a pause reads as one.
    private func upload(_ samples: [Float], key: String, trim: Bool,
                        after previous: Task<String?, Never>? = nil) -> Task<String?, Never> {
        let audio = trim ? Recording(samples: samples).trimmed().samples : samples
        let wav = WAV.encode(audio)
        let base = prompt
        QuotaBook.shared.record("groq.whisper")
        return Task {
            var earlier: String?
            if let previous {
                earlier = await withTimeout(3) { await previous.value }
            }
            let prompt = Dictation.piecePrompt(base: base, previous: earlier)
            do {
                return try await CloudClient.shared.transcribe(wav: wav, prompt: prompt, key: key)
            } catch {
                await MainActor.run { QuotaBook.shared.failed("groq.whisper", error) }
                return nil
            }
        }
    }
}
