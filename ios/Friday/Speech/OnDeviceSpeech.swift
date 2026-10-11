import AVFoundation
import FridayCore
import Speech

/// Apple's on-device recogniser (SpeechAnalyzer), fed live during a dictation. It's the instant
/// backup when the cloud is slow or offline, and tells us if anyone spoke at all (PLAN §5.2).
actor OnDeviceSpeech {
    static let shared = OnDeviceSpeech()

    private var locale: Locale?
    private var ready = false
    private var finalText = ""
    private var running: Task<Void, Never>?

    /// Finds the best English model and downloads it if needed. False if unavailable.
    func prepare() async -> Bool {
        if ready { return true }
        let wanted = await SpeechTranscriber.supportedLocale(equivalentTo: Locale(identifier: "en-IN"))
        let fallback = await SpeechTranscriber.supportedLocale(equivalentTo: Locale(identifier: "en-US"))
        guard let locale = wanted ?? fallback else { return false }
        let transcriber = SpeechTranscriber(locale: locale, transcriptionOptions: [], reportingOptions: [], attributeOptions: [])
        do {
            if let request = try await AssetInventory.assetInstallationRequest(supporting: [transcriber]) {
                try await request.downloadAndInstall()
            }
        } catch {
            return false
        }
        self.locale = locale
        ready = true
        return true
    }

    /// Transcribes everything that arrives on `samples` (16 kHz mono) until the stream ends.
    func start(_ samples: AsyncStream<[Float]>) {
        finalText = ""
        running = Task { await self.run(samples) }
    }

    /// Waits for the final text after the sample stream has been finished.
    func finish() async -> String {
        await running?.value
        running = nil
        return finalText.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private func run(_ samples: AsyncStream<[Float]>) async {
        if !ready { _ = await prepare() }
        guard ready, let locale else {
            for await _ in samples {}
            return
        }
        let transcriber = SpeechTranscriber(locale: locale, transcriptionOptions: [], reportingOptions: [], attributeOptions: [])
        let analyzer = SpeechAnalyzer(modules: [transcriber])
        guard let source = AVAudioFormat(commonFormat: .pcmFormatFloat32, sampleRate: Double(AudioFormat.sampleRate),
                                         channels: 1, interleaved: false),
              let target = await SpeechAnalyzer.bestAvailableAudioFormat(compatibleWith: [transcriber]),
              let converter = AVAudioConverter(from: source, to: target)
        else {
            for await _ in samples {}
            return
        }

        let (inputs, feed) = AsyncStream.makeStream(of: AnalyzerInput.self)
        let collector = Task { () -> String in
            var text = ""
            do {
                for try await result in transcriber.results where result.isFinal {
                    text += String(result.text.characters)
                }
            } catch {}
            return text
        }
        do {
            try await analyzer.start(inputSequence: inputs)
        } catch {
            feed.finish()
            for await _ in samples {}
            return
        }
        for await chunk in samples {
            if let buffer = OnDeviceSpeech.convert(chunk, from: source, with: converter, to: target) {
                feed.yield(AnalyzerInput(buffer: buffer))
            }
        }
        feed.finish()
        try? await analyzer.finalizeAndFinishThroughEndOfInput()
        finalText = await collector.value
    }

    private static func convert(_ samples: [Float], from source: AVAudioFormat, with converter: AVAudioConverter,
                                to target: AVAudioFormat) -> AVAudioPCMBuffer? {
        guard !samples.isEmpty,
              let input = AVAudioPCMBuffer(pcmFormat: source, frameCapacity: AVAudioFrameCount(samples.count))
        else { return nil }
        input.frameLength = AVAudioFrameCount(samples.count)
        samples.withUnsafeBufferPointer { input.floatChannelData![0].update(from: $0.baseAddress!, count: samples.count) }
        if source == target { return input }
        let capacity = AVAudioFrameCount(Double(samples.count) * target.sampleRate / source.sampleRate) + 32
        guard let output = AVAudioPCMBuffer(pcmFormat: target, frameCapacity: capacity) else { return nil }
        var supplied = false
        var error: NSError?
        converter.convert(to: output, error: &error) { _, status in
            if supplied {
                status.pointee = .noDataNow
                return nil
            }
            supplied = true
            status.pointee = .haveData
            return input
        }
        return error == nil && output.frameLength > 0 ? output : nil
    }
}
