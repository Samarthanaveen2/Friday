import ActivityKit
import AVFoundation
import FridayCore
import Observation
import UIKit

enum SessionSource: String, Sendable {
    case app, intent, keyboard
}

/// How long a Flow session stays on (PLAN §2.3).
enum SessionLength: String, CaseIterable, Identifiable, Sendable {
    case untilLock, fifteenMinutes, oneHour, never

    var id: String { rawValue }

    var label: String {
        switch self {
        case .untilLock: "Until the phone locks"
        case .fifteenMinutes: "15 minutes"
        case .oneHour: "1 hour"
        case .never: "Never"
        }
    }

    var seconds: TimeInterval? {
        switch self {
        case .fifteenMinutes: 15 * 60
        case .oneHour: 60 * 60
        case .untilLock, .never: nil
        }
    }
}

/// The Flow session: the mic engine stays on (in the background too), keeps a 1 s pre-roll,
/// records dictations on request and publishes a heartbeat to the App Group every second.
@MainActor
@Observable
final class Session {
    enum State: String, Sendable {
        case off, holding, dictating, needsRestart
    }

    static let shared = Session()

    private(set) var state: State = .off
    private(set) var level: Float = 0
    private(set) var levels: [Float] = []
    private(set) var recordedSeconds = 0.0
    private(set) var lastError: String?
    private(set) var activityNote: String?
    private(set) var activityRunning = false
    private(set) var inBackground = false
    private(set) var bestBackgroundSeconds: Int
    private(set) var lastPingSeen = 0
    /// Times the engine came back by itself after a call, Siri or a route change.
    private(set) var recoveries = 0
    private(set) var lastRecording: Recording?
    private(set) var lastPreRollSeconds = 0.0

    var running: Bool { state != .off }

    /// The live audio, for the transcriber.
    var sink: AudioSink { engine.sink }

    var length: SessionLength {
        didSet { defaults.set(length.rawValue, forKey: "session.length") }
    }

    private let engine = AudioEngine()
    private var timer: Timer?
    private var backgroundSince: Date?
    private var endsAt: Date?
    /// Between an interruption's "began" and "ended": don't fight the call for the mic.
    private var interruptedNow = false
    private var activity: Activity<FridayActivityAttributes>?
    private let defaults = UserDefaults.standard

    private init() {
        bestBackgroundSeconds = defaults.integer(forKey: "probe.bestBackgroundSeconds")
        length = SessionLength(rawValue: defaults.string(forKey: "session.length") ?? "") ?? .untilLock
        engine.onFailure = { message in
            MainActor.assumeIsolated { Session.shared.failed(message) }
        }
        observe()
        timer = Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { _ in
            MainActor.assumeIsolated { Session.shared.tick() }
        }
    }

    // MARK: Session

    func start(source: SessionSource) async {
        let appWasActive = UIApplication.shared.applicationState == .active
        ensureActivity(source: source)
        if state == .off || state == .needsRestart {
            do {
                if state == .needsRestart { try engine.rebuild() } else { try engine.start() }
                state = .holding
                lastError = nil
                endsAt = length.seconds.map { Date.now.addingTimeInterval($0) }
                DictationPipeline.warm()
            } catch {
                state = .needsRestart
                lastError = error.localizedDescription
            }
        }
        if source == .intent {
            GroupStore.shared.write(IntentRun(at: .now, ranIn: .app, micStarted: running && state != .needsRestart,
                                              appWasActive: appWasActive),
                                    to: ProbeFile.intent)
        }
        publish()
    }

    func stop() {
        engine.stop()
        state = .off
        level = 0
        levels = []
        endsAt = nil
        endActivity()
        publish()
    }

    // MARK: Dictation

    /// Starts recording, with the last second already included. False if no session is running.
    @discardableResult
    func startDictation() -> Bool {
        guard state == .holding else { return false }
        engine.sink.begin()
        state = .dictating
        recordedSeconds = 0
        publish()
        return true
    }

    /// Stops recording and returns the audio (pre-roll included).
    func finishDictation() -> Recording? {
        guard state == .dictating else { return nil }
        let (samples, preRoll) = engine.sink.end()
        state = .holding
        let recording = Recording(samples: samples)
        lastRecording = recording
        lastPreRollSeconds = Double(preRoll) / Double(AudioFormat.sampleRate)
        publish()
        return recording
    }

    func cancelDictation() {
        guard state == .dictating else { return }
        engine.sink.cancel()
        state = .holding
        publish()
    }

    // MARK: Recovery

    private func observe() {
        let center = NotificationCenter.default
        center.addObserver(forName: UIApplication.didEnterBackgroundNotification, object: nil, queue: .main) { _ in
            MainActor.assumeIsolated { Session.shared.enteredBackground() }
        }
        center.addObserver(forName: UIApplication.willEnterForegroundNotification, object: nil, queue: .main) { _ in
            MainActor.assumeIsolated { Session.shared.enteredForeground() }
        }
        // Fires when the phone locks (with a passcode): the default session length.
        center.addObserver(forName: UIApplication.protectedDataWillBecomeUnavailableNotification, object: nil, queue: .main) { _ in
            MainActor.assumeIsolated {
                if Session.shared.length == .untilLock, Session.shared.running { Session.shared.stop() }
            }
        }
        center.addObserver(forName: AVAudioSession.interruptionNotification, object: nil, queue: .main) { note in
            let type = (note.userInfo?[AVAudioSessionInterruptionTypeKey] as? UInt).flatMap { AVAudioSession.InterruptionType(rawValue: $0) }
            MainActor.assumeIsolated {
                if type == .began { Session.shared.interrupted() }
                if type == .ended { Session.shared.recover() }
            }
        }
        center.addObserver(forName: AVAudioSession.routeChangeNotification, object: nil, queue: .main) { _ in
            MainActor.assumeIsolated { Session.shared.routeChanged() }
        }
        center.addObserver(forName: AVAudioSession.mediaServicesWereResetNotification, object: nil, queue: .main) { _ in
            MainActor.assumeIsolated { Session.shared.mediaServicesReset() }
        }
        DarwinNotice.observe(ProbeNotice.keyboardPing)
        center.addObserver(forName: Notification.Name(ProbeNotice.keyboardPing), object: nil, queue: .main) { _ in
            MainActor.assumeIsolated { Session.shared.keyboardPinged() }
        }
    }

    private func interrupted() {
        // iOS has stopped the engine; a dictation in progress can't continue.
        interruptedNow = true
        if state == .dictating {
            // Stops the live uploads and on-device speech too, not just the recording.
            DictationPipeline.shared.cancel()
        }
        publish()
    }

    private func recover() {
        interruptedNow = false
        guard running, !engine.isRunning else { return }
        do {
            try engine.restart()
            // The recording buffer survives a restart, so a dictation in progress just carries on
            // (e.g. AirPods connected mid-sentence).
            if state != .dictating { state = .holding }
            recoveries += 1
            lastError = nil
        } catch {
            failed("Mic stopped: \(error.localizedDescription)")
        }
        publish()
    }

    private func routeChanged() {
        guard running else { return }
        engine.preferBuiltInMic()
        if !engine.isRunning { recover() }
    }

    private func mediaServicesReset() {
        guard running else { return }
        do {
            try engine.rebuild()
            if state != .dictating { state = .holding }
            recoveries += 1
        } catch {
            failed("Mic stopped: \(error.localizedDescription)")
        }
        publish()
    }

    private func failed(_ message: String) {
        state = .needsRestart
        lastError = message
        publish()
    }

    // MARK: Live Activity

    /// Reuses a running "Friday on" activity, otherwise starts one.
    func ensureActivity(source: SessionSource) {
        if let existing = Activity<FridayActivityAttributes>.activities.first {
            activity = existing
            activityRunning = true
            activityNote = nil
            return
        }
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

    private var phaseReset: Task<Void, Never>?

    /// Shows what talking to Friday is doing in the Dynamic Island / Lock Screen card.
    /// "done" falls back to plain "Friday on" after 5 s.
    func setActivity(phase: String, message: String? = nil) {
        if activity == nil { ensureActivity(source: .app) }
        let started = activity?.content.state.startedAt ?? .now
        let source = activity?.content.state.source ?? SessionSource.app.rawValue
        let state = FridayActivityAttributes.ContentState(startedAt: started, source: source,
                                                          phase: phase == "on" ? nil : phase, message: message)
        Task { await Session.updateAllActivities(state) }
        phaseReset?.cancel()
        if phase == "done" {
            phaseReset = Task {
                try? await Task.sleep(for: .seconds(5))
                guard !Task.isCancelled else { return }
                Session.shared.setActivity(phase: "on")
            }
        }
    }

    nonisolated private static func updateAllActivities(_ state: FridayActivityAttributes.ContentState) async {
        for activity in Activity<FridayActivityAttributes>.activities {
            await activity.update(ActivityContent(state: state, staleDate: nil))
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

    private func tick() {
        if let endsAt, Date.now >= endsAt, state == .holding { stop(); return }
        level = running ? engine.sink.currentLevel : 0
        levels = running ? engine.sink.levels : []
        if state == .dictating { recordedSeconds = engine.sink.recordedSeconds }
        // The engine can die without telling us (e.g. a call that never sends "ended").
        if state == .holding || state == .dictating, !engine.isRunning, !interruptedNow { recover() }
        if inBackground, running, let since = backgroundSince {
            let seconds = Int(Date.now.timeIntervalSince(since))
            if seconds > bestBackgroundSeconds {
                bestBackgroundSeconds = seconds
                defaults.set(seconds, forKey: "probe.bestBackgroundSeconds")
            }
        }
        publish()
    }

    private func enteredBackground() {
        inBackground = true
        backgroundSince = .now
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
                           lastPingSeen: lastPingSeen, state: state.rawValue)
        GroupStore.shared.write(beat, to: ProbeFile.app)
        DarwinNotice.post(ProbeNotice.appBeat)
    }
}
