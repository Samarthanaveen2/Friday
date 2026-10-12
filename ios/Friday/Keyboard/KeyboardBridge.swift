import FridayCore
import Foundation
import Observation

/// The app side of the Friday Keyboard: records and cleans up dictations the keyboard asks
/// for, and sends back the text to insert (PLAN §2.3, §8).
@MainActor
final class KeyboardBridge {
    static let shared = KeyboardBridge()

    private var levelTimer: Timer?
    private var handled: Set<String> = []

    func start() {
        DarwinNotice.observe(BridgeNotice.request)
        NotificationCenter.default.addObserver(forName: Notification.Name(BridgeNotice.request), object: nil, queue: .main) { _ in
            MainActor.assumeIsolated { KeyboardBridge.shared.handleRequest() }
        }
    }

    private func handleRequest() {
        guard let request = GroupStore.shared.read(KeyboardRequest.self, from: BridgeFile.request) else { return }
        let key = "\(request.id)-\(request.kind.rawValue)"
        guard !handled.contains(key) else { return }
        handled.insert(key)
        if handled.count > 200 { handled.removeAll() }

        let pipeline = DictationPipeline.shared
        let session = Session.shared
        switch request.kind {
        case .start:
            // A new tap always wins: drop a recording left hanging (keyboard closed mid-dictation).
            if session.state == .dictating {
                stopLevels()
                pipeline.cancel()
            }
            guard session.state == .holding else {
                reply(request, .failed, message: "Session ended — tap 🎤")
                return
            }
            pipeline.tone = request.tone
            guard pipeline.begin() else {
                reply(request, .failed, message: "Session ended — tap 🎤")
                return
            }
            reply(request, .started)
            startLevels()

        case .stop:
            stopLevels()
            guard session.state == .dictating else {
                reply(request, .failed, message: "Didn't catch that")
                return
            }
            reply(request, .working)
            Task {
                guard let outcome = await pipeline.finish(context: request.context), !outcome.nothing else {
                    self.reply(request, .failed, message: "Didn't catch that")
                    return
                }
                let raw = Continuation.apply(outcome.raw, after: request.context)
                GroupStore.shared.write(Insertion(text: outcome.text, raw: raw, at: .now), to: BridgeFile.last)
                self.reply(request, .result, text: outcome.text, raw: raw,
                           message: outcome.timings.speechBy == .device ? (outcome.fallback ?? "Used phone") : nil)
            }

        case .cancel:
            stopLevels()
            pipeline.cancel()
            reply(request, .cancelled)
        }
    }

    private func reply(_ request: KeyboardRequest, _ kind: AppReply.Kind, text: String? = nil, raw: String? = nil,
                       message: String? = nil) {
        GroupStore.shared.write(AppReply(requestID: request.id, kind: kind, text: text, raw: raw, message: message, at: .now),
                                to: BridgeFile.reply)
        DarwinNotice.post(BridgeNotice.reply)
    }

    /// The keyboard draws its waveform from this, ~20 times a second.
    private func startLevels() {
        levelTimer?.invalidate()
        levelTimer = Timer.scheduledTimer(withTimeInterval: 0.05, repeats: true) { _ in
            MainActor.assumeIsolated {
                GroupStore.shared.writeData(LevelCodec.encode(Session.shared.sink.currentLevel), to: BridgeFile.level)
            }
        }
    }

    private func stopLevels() {
        levelTimer?.invalidate()
        levelTimer = nil
        GroupStore.shared.writeData(LevelCodec.encode(0), to: BridgeFile.level)
    }
}

/// App-wide UI state that isn't part of a screen.
@MainActor
@Observable
final class AppState {
    static let shared = AppState()
    /// Shown after the keyboard opened Friday to start a session, if jumping back failed.
    var showSwipeBack = false
    /// Whether the last keyboard bounce jumped back to the chat by itself.
    var lastAutoReturn: Bool?
    /// How it got back: "breadcrumb", "bundle" or "link".
    var lastReturnWay: String?
}
