import Foundation
import AVFoundation
import ActivityKit
import AppIntents
import Observation

/// Live Activity data. Compiled into the app and the widget.
struct ProbeAttributes: ActivityAttributes {
    struct ContentState: Codable, Hashable {
        var seconds: Int
    }
}

private let discardTap: AVAudioNodeTapBlock = { _, _ in }

/// The install probe's "session": keeps the mic engine running (audio thrown away),
/// writes a heartbeat every second, and counts anything that goes wrong.
/// This is the same trick the real Friday session will use (RISKS A2).
@MainActor
@Observable
final class ProbeSession {
    static let shared = ProbeSession()

    var running = false
    var startedAt: Date?
    var beats = 0
    var maxGap: Double = 0
    var restarts = 0
    var interruptions = 0
    var lastError: String?
    var activityStatus = "not started"

    private let engine = AVAudioEngine()
    private var timer: Timer?
    private var lastBeat: Date?
    private var observers: [NSObjectProtocol] = []
    private var activity: Activity<ProbeAttributes>?

    func start() {
        guard !running else { return }
        lastError = nil
        startActivity()
        do {
            try startEngine()
        } catch {
            lastError = "Mic failed: \(error.localizedDescription)"
            return
        }
        running = true
        startedAt = Date()
        beats = 0
        maxGap = 0
        restarts = 0
        interruptions = 0
        lastBeat = Date()
        observe()
        timer = Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { [weak self] _ in
            MainActor.assumeIsolated { self?.tick() }
        }
        writeHeartbeat()
    }

    func stop() {
        timer?.invalidate()
        timer = nil
        observers.forEach { NotificationCenter.default.removeObserver($0) }
        observers = []
        engine.inputNode.removeTap(onBus: 0)
        engine.stop()
        try? AVAudioSession.sharedInstance().setActive(false, options: .notifyOthersOnDeactivation)
        running = false
        writeHeartbeat()
        let a = activity
        activity = nil
        Task { await a?.end(nil, dismissalPolicy: .immediate) }
        activityStatus = "ended"
    }

    // MARK: - Engine

    private func startEngine() throws {
        let s = AVAudioSession.sharedInstance()
        // Music keeps playing (RISKS A3); the phone's own mic is used so AirPods stay hi-fi (A4).
        try s.setCategory(.playAndRecord, mode: .default,
                          options: [.mixWithOthers, .allowBluetoothA2DP, .defaultToSpeaker])
        try s.setActive(true)
        if let builtIn = s.availableInputs?.first(where: { $0.portType == .builtInMic }) {
            try s.setPreferredInput(builtIn)
        }
        let input = engine.inputNode
        input.removeTap(onBus: 0)
        input.installTap(onBus: 0, bufferSize: 4096, format: input.outputFormat(forBus: 0), block: discardTap)
        engine.prepare()
        try engine.start()
    }

    private func restartEngine() {
        do {
            engine.stop()
            try startEngine()
            restarts += 1
        } catch {
            lastError = "Restart failed: \(error.localizedDescription)"
        }
    }

    private func observe() {
        let nc = NotificationCenter.default
        let session = AVAudioSession.sharedInstance()
        observers.append(nc.addObserver(forName: AVAudioSession.interruptionNotification, object: session, queue: .main) { [weak self] note in
            let raw = note.userInfo?[AVAudioSessionInterruptionTypeKey] as? UInt
            MainActor.assumeIsolated {
                guard let self else { return }
                if raw == AVAudioSession.InterruptionType.began.rawValue {
                    self.interruptions += 1
                } else {
                    self.restartEngine()
                }
            }
        })
        observers.append(nc.addObserver(forName: AVAudioSession.routeChangeNotification, object: session, queue: .main) { [weak self] _ in
            MainActor.assumeIsolated {
                guard let self, self.running, !self.engine.isRunning else { return }
                self.restartEngine()
            }
        })
        observers.append(nc.addObserver(forName: AVAudioSession.mediaServicesWereResetNotification, object: session, queue: .main) { [weak self] _ in
            MainActor.assumeIsolated { self?.restartEngine() }
        })
    }

    // MARK: - Heartbeat

    private func tick() {
        let now = Date()
        if let last = lastBeat { maxGap = max(maxGap, now.timeIntervalSince(last)) }
        lastBeat = now
        beats += 1
        if !engine.isRunning { restartEngine() }
        writeHeartbeat()
        if beats % 5 == 0 { updateActivity() }
    }

    private func writeHeartbeat() {
        AppGroup.write([
            "t": Date().timeIntervalSince1970,
            "running": running ? 1 : 0,
            "started": startedAt?.timeIntervalSince1970 ?? 0,
            "beats": Double(beats),
            "maxGap": maxGap,
            "restarts": Double(restarts),
        ], to: "heartbeat.json")
    }

    // MARK: - Live Activity

    private func startActivity() {
        guard ActivityAuthorizationInfo().areActivitiesEnabled else {
            activityStatus = "Live Activities are off (Settings → Friday)"
            return
        }
        do {
            activity = try Activity.request(
                attributes: ProbeAttributes(),
                content: ActivityContent(state: .init(seconds: 0), staleDate: nil))
            activityStatus = "running"
        } catch {
            activityStatus = "failed: \(error.localizedDescription)"
        }
    }

    private func updateActivity() {
        guard let a = activity, let started = startedAt else { return }
        let seconds = Int(Date().timeIntervalSince(started))
        Task { await a.update(ActivityContent(state: .init(seconds: seconds), staleDate: nil)) }
    }
}

/// Runs from Control Center, the Action button, Shortcuts and Siri. Because it is an
/// AudioRecordingIntent it is allowed to start the mic without opening the app.
struct StartProbeIntent: AudioRecordingIntent {
    static let title: LocalizedStringResource = "Start Friday mic test"
    static let description = IntentDescription("Starts the Friday install probe's mic session.")

    @MainActor
    func perform() async throws -> some IntentResult {
        AppGroup.bump("intent.json")
        ProbeSession.shared.start()
        return .result()
    }
}
