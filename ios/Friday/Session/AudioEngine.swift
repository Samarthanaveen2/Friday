import AVFoundation
import FridayCore

/// Receives 16 kHz mono samples from the audio thread. Between dictations it only keeps the
/// last second (the pre-roll); while dictating it keeps everything.
final class AudioSink: @unchecked Sendable {
    private let lock = NSLock()
    private var ring = RingBuffer(capacity: AudioFormat.sampleRate)
    private var recording: [Float]?
    private var preRollCount = 0
    private var level: Float = 0
    private var history: [Float] = []
    /// While dictating, every new block of samples also goes here (on-device speech).
    private var live: (@Sendable ([Float]) -> Void)?

    func push(_ samples: [Float]) {
        let rms = SpeechFrames.rms(samples[...])
        lock.lock()
        defer { lock.unlock() }
        if recording != nil {
            recording!.append(contentsOf: samples)
            live?(samples)
        } else {
            ring.append(contentsOf: samples)
        }
        level = min(1, rms * 9)
        history.append(level)
        if history.count > 48 { history.removeFirst(history.count - 48) }
    }

    /// Starts a dictation with the last second already in it.
    func begin() {
        lock.lock()
        defer { lock.unlock() }
        let preRoll = ring.snapshot()
        preRollCount = preRoll.count
        recording = preRoll
        ring.removeAll()
    }

    /// Ends the dictation and returns its audio and how much of it was pre-roll.
    func end() -> (samples: [Float], preRoll: Int) {
        lock.lock()
        defer { lock.unlock() }
        let samples = recording ?? []
        recording = nil
        return (samples, preRollCount)
    }

    /// Installs the live handler and returns what was recorded before it (the pre-roll), in one
    /// step, so the on-device recogniser hears the dictation from its very first sample.
    @discardableResult
    func setLive(_ handler: (@Sendable ([Float]) -> Void)?) -> [Float] {
        lock.lock()
        defer { lock.unlock() }
        live = handler
        return recording ?? []
    }

    /// A copy of what's been recorded so far, pre-roll included (for chunked uploads).
    func snapshot() -> [Float] {
        lock.lock()
        defer { lock.unlock() }
        return recording ?? []
    }

    func cancel() {
        lock.lock()
        recording = nil
        lock.unlock()
    }

    func reset() {
        lock.lock()
        ring.removeAll()
        recording = nil
        level = 0
        history = []
        lock.unlock()
    }

    var currentLevel: Float { lock.lock(); defer { lock.unlock() }; return level }
    var levels: [Float] { lock.lock(); defer { lock.unlock() }; return history }

    var recordedSeconds: Double {
        lock.lock()
        defer { lock.unlock() }
        return Double((recording?.count ?? 0) - preRollCount) / Double(AudioFormat.sampleRate)
    }
}

/// Holds the converter for the audio thread.
private final class Converter: @unchecked Sendable {
    let converter: AVAudioConverter
    let output: AVAudioFormat

    init(converter: AVAudioConverter, output: AVAudioFormat) {
        self.converter = converter
        self.output = output
    }
}

/// The one AVAudioEngine of a session. Mixes with music, keeps AirPods in full quality,
/// prefers the iPhone mic, never ducks (RISKS A3/A4).
@MainActor
final class AudioEngine {
    enum Failure: LocalizedError {
        case noInput, noConverter

        var errorDescription: String? {
            switch self {
            case .noInput: "No microphone available"
            case .noConverter: "Couldn't set up the audio format"
            }
        }
    }

    let sink = AudioSink()
    private var engine = AVAudioEngine()
    private var configObserver: NSObjectProtocol?
    /// Called when the engine stopped by itself and couldn't be restarted.
    var onFailure: (String) -> Void = { _ in }
    var useBluetoothMic = false
    /// True between start() and stop(); only then do format changes restart the engine.
    private var active = false

    var isRunning: Bool { engine.isRunning }

    init() {
        observeConfiguration()
    }

    func start() throws {
        try configureSession()
        try startEngine()
        active = true
    }

    func stop() {
        active = false
        engine.stop()
        engine.inputNode.removeTap(onBus: 0)
        sink.reset()
        try? AVAudioSession.sharedInstance().setActive(false, options: .notifyOthersOnDeactivation)
    }

    /// After an interruption or a route change: same engine, fresh tap and format.
    func restart() throws {
        engine.stop()
        engine.inputNode.removeTap(onBus: 0)
        try configureSession()
        try startEngine()
    }

    /// After iOS resets its media services, every audio object is dead: start over.
    func rebuild() throws {
        engine.stop()
        engine = AVAudioEngine()
        observeConfiguration()
        try configureSession()
        try startEngine()
    }

    func preferBuiltInMic() {
        guard !useBluetoothMic else { return }
        let session = AVAudioSession.sharedInstance()
        if let builtIn = session.availableInputs?.first(where: { $0.portType == .builtInMic }),
           session.preferredInput?.portType != .builtInMic {
            try? session.setPreferredInput(builtIn)
        }
    }

    private func configureSession() throws {
        let session = AVAudioSession.sharedInstance()
        try session.setCategory(.playAndRecord, mode: .default,
                                options: [.mixWithOthers, .allowBluetoothA2DP, .defaultToSpeaker])
        try session.setActive(true)
        preferBuiltInMic()
    }

    private func startEngine() throws {
        let input = engine.inputNode
        let format = input.outputFormat(forBus: 0)
        guard format.sampleRate > 0, format.channelCount > 0 else { throw Failure.noInput }
        guard let output = AVAudioFormat(commonFormat: .pcmFormatFloat32, sampleRate: Double(AudioFormat.sampleRate),
                                         channels: 1, interleaved: false),
              let converter = AVAudioConverter(from: format, to: output)
        else { throw Failure.noConverter }
        AudioEngine.installTap(on: input, format: format, converter: Converter(converter: converter, output: output), sink: sink)
        engine.prepare()
        try engine.start()
    }

    /// Nonisolated so the tap closure doesn't inherit main-actor isolation: it runs on the audio thread.
    nonisolated private static func installTap(on node: AVAudioInputNode, format: AVAudioFormat,
                                               converter: Converter, sink: AudioSink) {
        node.removeTap(onBus: 0)
        node.installTap(onBus: 0, bufferSize: 2048, format: format) { buffer, _ in
            let ratio = converter.output.sampleRate / buffer.format.sampleRate
            let capacity = AVAudioFrameCount(Double(buffer.frameLength) * ratio) + 32
            guard let out = AVAudioPCMBuffer(pcmFormat: converter.output, frameCapacity: capacity) else { return }
            var supplied = false
            var error: NSError?
            converter.converter.convert(to: out, error: &error) { _, status in
                if supplied {
                    status.pointee = .noDataNow
                    return nil
                }
                supplied = true
                status.pointee = .haveData
                return buffer
            }
            guard error == nil, let data = out.floatChannelData?[0], out.frameLength > 0 else { return }
            sink.push(Array(UnsafeBufferPointer(start: data, count: Int(out.frameLength))))
        }
    }

    /// The engine stops itself when the hardware format changes (AirPods in/out, etc.).
    private func observeConfiguration() {
        if let configObserver { NotificationCenter.default.removeObserver(configObserver) }
        configObserver = NotificationCenter.default.addObserver(
            forName: .AVAudioEngineConfigurationChange, object: engine, queue: .main
        ) { [weak self] _ in
            MainActor.assumeIsolated {
                guard let self, self.active else { return }
                do { try self.restart() } catch { self.onFailure(error.localizedDescription) }
            }
        }
    }
}
