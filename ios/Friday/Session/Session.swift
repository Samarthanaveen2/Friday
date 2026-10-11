import ActivityKit
import AVFoundation
import FridayCore
import Observation
import UIKit

enum SessionSource: String, Sendable {
    case app, intent, keyboard
}

/// Thread-safe level value written from the audio thread, read on main.
final class LevelMeter: @unchecked Sendable {
    private let lock = NSLock()
    private var value: Float = 0

    func set(_ new: Float) { lock.lock(); value = new; lock.unlock() }
    func get() -> Float { lock.lock(); defer { lock.unlock() }; return value }
}

/// The Flow session: keeps the mic engine running (in the background too) and
/// publishes a heartbeat to the App Group every second.
@MainActor
@Observable
final class Session {
    static let shared = Session()

    private(set) var running = false
    private(set) var level: Float = 0
    private(set) var lastError: String?
    private(set) var activityNote: String?
    private(set) var activityRunning = false
    private(set) var inBackground = false
    private(set) var backgroundSeconds = 0
    private(set) var bestBackgroundSeconds: Int
    private(set) var lastPingSeen = 0

    private let engine = AVAudioEngine()
    private let meter = LevelMeter()
    private var timer: Timer?
    private var backgroundSince: Date?
    private var activity: Activity<FridayActivityAttributes>?
    private let defaults = UserDefaults.standard

    private init() {
        bestBackgroundSeconds = defaults.integer(forKey: "probe.bestBackgroundSeconds")
        let center = NotificationCenter.default
        center.addObserver(forName: UIApplication.didEnterBackgroundNotification, object: nil, queue: .main) { _ in
            MainActor.assumeIsolated { Session.shared.enteredBackground() }
        }
        center.addObserver(forName: UIApplication.willEnterForegroundNotification, object: nil, queue: .main) { _ in
            MainActor.assumeIsolated { Session.shared.enteredForeground() }
        }
        center.addObserver(forName: AVAudioSession.interruptionNotification, object: nil, queue: .main) { note in
            let ended = (note.userInfo?[AVAudioSessionInterruptionTypeKey] as? UInt)
                .flatMap { AVAudioSession.InterruptionType(rawValue: $0) } == .ended
            MainActor.assumeIsolated { if ended { Session.shared.resumeAfterInterruption() } }
        }
        DarwinNotice.observe(ProbeNotice.keyboardPing)
        center.addObserver(forName: Notification.Name(ProbeNotice.keyboardPing), object: nil, queue: .main) { _ in
            MainActor.assumeIsolated { Session.shared.keyboardPinged() }
        }
        startTimer()
    }

    func start(source: SessionSource) async {
        let appWasActive = UIApplication.shared.applicationState == .active
        if !running {
            do {
                try startEngine()
                running = true
                lastError = nil
                startActivity(source: source)
            } catch {
                lastError = error.localizedDescription
            }
        }
        if source == .intent {
            GroupStore.shared.write(IntentRun(at: .now, ranIn: .app, micStarted: running, appWasActive: appWasActive),
                                    to: ProbeFile.intent)
        }
        publish()
    }

    func stop() {
        engine.stop()
        engine.inputNode.removeTap(onBus: 0)
        try? AVAudioSession.sharedInstance().setActive(false, options: .notifyOthersOnDeactivation)
        running = false
        level = 0
        meter.set(0)
        endActivity()
        publish()
    }

    // MARK: Audio

    private func startEngine() throws {
        let audio = AVAudioSession.sharedInstance()
        // Mix with music, keep AirPods in full quality, prefer the iPhone mic (RISKS A3/A4).
        try audio.setCategory(.playAndRecord, mode: .default,
                              options: [.mixWithOthers, .allowBluetoothA2DP, .defaultToSpeaker])
        if let builtIn = audio.availableInputs?.first(where: { $0.portType == .builtInMic }) {
            try? audio.setPreferredInput(builtIn)
        }
        try audio.setActive(true)
        let input = engine.inputNode
        Session.installTap(on: input, format: input.outputFormat(forBus: 0), meter: meter)
        engine.prepare()
        try engine.start()
    }

    /// Kept nonisolated so the tap closure doesn't inherit main-actor isolation
    /// (it runs on the audio thread).
    nonisolated private static func installTap(on node: AVAudioInputNode, format: AVAudioFormat, meter: LevelMeter) {
        node.removeTap(onBus: 0)
        node.installTap(onBus: 0, bufferSize: 1024, format: format) { buffer, _ in
            guard let samples = buffer.floatChannelData?[0] else { return }
            let count = Int(buffer.frameLength)
            guard count > 0 else { return }
            var sum: Float = 0
            for i in 0..<count { sum += samples[i] * samples[i] }
            meter.set(min(1, (sum / Float(count)).squareRoot() * 10))
        }
    }

    private func resumeAfterInterruption() {
        guard running, !engine.isRunning else { return }
        do { try startEngine() } catch { lastError = "Mic stopped: \(error.localizedDescription)" }
    }

    // MARK: Live Activity

    private func startActivity(source: SessionSource) {
        guard ActivityAuthorizationInfo().areActivitiesEnabled else {
            activityNote = "Live Activities are off in Settings"
            return
        }
        do {
            activity = try Activity.request(
                attributes: FridayActivityAttributes(),
                content: .init(state: .init(startedAt: .now, source: source.rawValue), staleDate: nil))
            activityRunning = true
            activityNote = nil
        } catch {
            activityNote = error.localizedDescription
        }
    }

    private func endActivity() {
        activity = nil
        activityRunning = false
        Task { await Session.endAllActivities() }
    }

    nonisolated private static func endAllActivities() async {
        for activity in Activity<FridayActivityAttributes>.activities {
            await activity.end(nil, dismissalPolicy: .immediate)
        }
    }

    // MARK: Heartbeat

    private func startTimer() {
        timer = Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { _ in
            MainActor.assumeIsolated { Session.shared.tick() }
        }
    }

    private func tick() {
        level = running ? meter.get() : 0
        if inBackground, running, let since = backgroundSince {
            backgroundSeconds = Int(Date.now.timeIntervalSince(since))
            if backgroundSeconds > bestBackgroundSeconds {
                bestBackgroundSeconds = backgroundSeconds
                defaults.set(bestBackgroundSeconds, forKey: "probe.bestBackgroundSeconds")
            }
        }
        publish()
    }

    private func enteredBackground() {
        inBackground = true
        backgroundSince = .now
        backgroundSeconds = 0
        publish()
    }

    private func enteredForeground() {
        inBackground = false
        backgroundSince = nil
        publish()
    }

    private func keyboardPinged() {
        if let beat = GroupStore.shared.read(KeyboardBeat.self, from: ProbeFile.keyboard) {
            lastPingSeen = beat.ping
        }
        publish()
    }

    private func publish() {
        let beat = AppBeat(at: .now, micRunning: running && engine.isRunning, level: level,
                           inBackground: inBackground, bestBackgroundSeconds: bestBackgroundSeconds,
                           lastPingSeen: lastPingSeen)
        GroupStore.shared.write(beat, to: ProbeFile.app)
        DarwinNotice.post(ProbeNotice.appBeat)
    }
}
