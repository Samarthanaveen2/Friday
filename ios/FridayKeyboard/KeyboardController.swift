import FridayCore
import Observation
import SwiftUI
import UIKit

/// Everything the Friday Keyboard does. It never records or touches the network: it asks the
/// app (over the App Group) and types what comes back (PLAN §2).
@MainActor
@Observable
final class KeyboardController {
    var model = KeyboardModel()

    @ObservationIgnored weak var input: UIInputViewController?
    @ObservationIgnored private let store = GroupStore.shared
    @ObservationIgnored private var pending: KeyboardRequest?
    @ObservationIgnored private var lastInsertion: Insertion?
    @ObservationIgnored private var recordingStarted: Date?
    @ObservationIgnored private var levelTimer: Timer?
    @ObservationIgnored private var deleteTimer: Timer?
    @ObservationIgnored private var watchdog: Task<Void, Never>?
    @ObservationIgnored private var stripTask: Task<Void, Never>?
    @ObservationIgnored private var tone: Tone
    /// Replies already acted on (request id + kind), so a repeat delivery does nothing.
    @ObservationIgnored private var seenReplies: Set<String> = []
    /// Set when 🎤 opened Friday to start the session: once it's live, start dictating by itself.
    @ObservationIgnored private var autoStartUntil: Date?
    @ObservationIgnored private var autoStartTimer: Timer?

    init() {
        tone = Tone(rawValue: UserDefaults.standard.string(forKey: "tone") ?? "") ?? .asSaid
        model.tone = tone.label
        DarwinNotice.observe(BridgeNotice.reply)
        NotificationCenter.default.addObserver(forName: Notification.Name(BridgeNotice.reply), object: nil, queue: .main) {
            [weak self] _ in
            MainActor.assumeIsolated { self?.handleReply() }
        }
    }

    var actions: KeyboardActions {
        KeyboardActions(
            key: { [weak self] in self?.type($0) },
            delete: { [weak self] in self?.proxy?.deleteBackward() },
            deleteDown: { [weak self] in self?.deleteDown() },
            deleteUp: { [weak self] in self?.deleteUp() },
            cursor: { [weak self] in self?.moveCursor($0) },
            undo: { [weak self] in self?.undo() },
            raw: { [weak self] in self?.useRaw() },
            space: { [weak self] in self?.type(" ") },
            returnKey: { [weak self] in self?.type("\n") },
            nextKeyboard: { [weak self] in self?.input?.advanceToNextInputMode() },
            toggleSymbols: { [weak self] in self?.toggleSymbols() },
            mic: { [weak self] in self?.mic() },
            cancel: { [weak self] in self?.cancel() },
            done: { [weak self] in self?.done() },
            tone: { [weak self] in self?.cycleTone() },
            menu: { [weak self] in self?.openFriday(path: "home") },
            pasteLast: { [weak self] in self?.pasteLast() }
        )
    }

    private var proxy: UITextDocumentProxy? { input?.textDocumentProxy }

    /// Called when the keyboard appears: lets the setup check see it, and resets a stuck state.
    func appeared() {
        store.write(KeyboardBeat(at: .now, fullAccess: input?.hasFullAccess ?? false, ping: 0, roundTrip: false),
                    to: ProbeFile.keyboard)
        if pending == nil, model.mode != .idle { model.mode = .idle }
        if let until = autoStartUntil, Date.now < until { waitForSessionThenDictate() }
    }

    /// Back from the bounce: as soon as the app's session is live, start recording (one tap total).
    private func waitForSessionThenDictate() {
        autoStartTimer?.invalidate()
        autoStartTimer = Timer.scheduledTimer(withTimeInterval: 0.15, repeats: true) { [weak self] _ in
            MainActor.assumeIsolated { self?.checkAutoStart() }
        }
    }

    private func checkAutoStart() {
        guard let until = autoStartUntil, Date.now < until else {
            autoStartTimer?.invalidate()
            autoStartTimer = nil
            return
        }
        if KeyboardLogic.sessionLive(beat: store.read(AppBeat.self, from: ProbeFile.app), now: .now) {
            autoStartTimer?.invalidate()
            autoStartTimer = nil
            autoStartUntil = nil
            if pending == nil { mic() }
        }
    }

    // MARK: Typing

    private func type(_ text: String) {
        proxy?.insertText(text)
        tap()
        lastInsertion = nil
        if case .undoRaw = model.strip { model.strip = nil }
    }

    private func toggleSymbols() {
        model.symbolsPage = model.symbolsPage == 0 ? 1 : 0
        tap()
    }

    private func deleteDown() {
        proxy?.deleteBackward()
        tap()
        deleteTimer?.invalidate()
        // Like Apple's: a short wait, then repeat while held.
        deleteTimer = Timer.scheduledTimer(withTimeInterval: 0.45, repeats: false) { [weak self] _ in
            MainActor.assumeIsolated { self?.startDeleteRepeat() }
        }
    }

    private func startDeleteRepeat() {
        deleteTimer = Timer.scheduledTimer(withTimeInterval: 0.07, repeats: true) { [weak self] _ in
            MainActor.assumeIsolated { _ = self?.proxy?.deleteBackward() }
        }
    }

    private func deleteUp() {
        deleteTimer?.invalidate()
        deleteTimer = nil
    }

    private func moveCursor(_ offset: Int) {
        proxy?.adjustTextPosition(byCharacterOffset: offset)
        UISelectionFeedbackGenerator().selectionChanged()
    }

    private func cycleTone() {
        tone = tone.next
        model.tone = tone.label
        UserDefaults.standard.set(tone.rawValue, forKey: "tone")
        tap()
    }

    // MARK: Dictation

    private func mic() {
        tap()
        guard input?.hasFullAccess == true else {
            flash(.warning("Turn on Full Access for Friday"))
            return
        }
        guard KeyboardLogic.sessionLive(beat: store.read(AppBeat.self, from: ProbeFile.app), now: .now) else {
            // First tap of a session: Friday has to start the mic in the foreground (PLAN §2.3).
            // It jumps straight back and recording starts by itself.
            autoStartUntil = Date.now.addingTimeInterval(8)
            openFriday(path: "session")
            waitForSessionThenDictate()
            return
        }
        let request = KeyboardRequest(id: UUID().uuidString, kind: .start, documentID: documentID,
                                      context: proxy?.documentContextBeforeInput ?? "", tone: tone, at: .now)
        pending = request
        send(request)
        recordingStarted = .now
        model.levels = []
        model.strip = nil
        withAnimation(Motion.fade) { model.mode = .recording(seconds: 0) }
        startLevels()
        guardReply(within: 2.5, message: "Session ended — tap 🎤")
    }

    private func done() {
        guard var request = pending else { return }
        tap()
        request.kind = .stop
        request.documentID = documentID
        request.context = String((proxy?.documentContextBeforeInput ?? "").suffix(300))
        pending = request
        send(request)
        stopLevels()
        withAnimation(Motion.fade) { model.mode = .working }
        guardReply(within: 15, message: nil)
    }

    private func cancel() {
        tap()
        if var request = pending {
            request.kind = .cancel
            send(request)
        }
        pending = nil
        stopLevels()
        watchdog?.cancel()
        withAnimation(Motion.fade) { model.mode = .idle }
    }

    private func handleReply() {
        guard let reply = store.read(AppReply.self, from: BridgeFile.reply) else { return }
        let key = "\(reply.requestID)-\(reply.kind.rawValue)"
        guard !seenReplies.contains(key) else { return }
        seenReplies.insert(key)
        guard let pending, reply.requestID == pending.id else {
            // A fresh result nobody was waiting for (e.g. the keyboard was reloaded mid-dictation).
            if reply.kind == .result, Date.now.timeIntervalSince(reply.at) < 30 { model.strip = .pasteLast }
            return
        }
        switch reply.kind {
        case .started:
            watchdog?.cancel()
        case .working:
            watchdog?.cancel()
            guardReply(within: 15, message: nil)
            if model.mode != .working { withAnimation(Motion.fade) { model.mode = .working } }
        case .result:
            finish()
            switch KeyboardLogic.decide(reply: reply, pending: pending, currentDocument: documentID) {
            case .insert(let text):
                proxy?.insertText(text)
                lastInsertion = Insertion(text: text, raw: reply.raw, at: .now)
                UINotificationFeedbackGenerator().notificationOccurred(.success)
                let hasRaw = reply.raw.map { !$0.isEmpty && $0 != text } ?? false
                flash(.undoRaw(hasRaw: hasRaw), for: 4) { [weak self] in
                    if let message = reply.message { self?.flash(.info(message)) }
                }
            case .pasteLast:
                model.strip = .pasteLast
            case .ignore:
                break
            }
        case .failed:
            finish()
            UINotificationFeedbackGenerator().notificationOccurred(.warning)
            flash(.warning(reply.message ?? "Didn't catch that"))
        case .cancelled:
            finish()
        }
    }

    private func finish() {
        pending = nil
        watchdog?.cancel()
        stopLevels()
        withAnimation(Motion.fade) { model.mode = .idle }
    }

    /// If the app doesn't answer in time, never leave the keyboard stuck.
    private func guardReply(within seconds: Double, message: String?) {
        watchdog?.cancel()
        let id = pending?.id
        watchdog = Task { [weak self] in
            try? await Task.sleep(for: .seconds(seconds))
            guard !Task.isCancelled, let self, self.pending?.id == id else { return }
            self.finish()
            if let message { self.flash(.warning(message)) } else { self.model.strip = .pasteLast }
        }
    }

    // MARK: Undo, Raw, Paste last

    private func undo() {
        guard let insertion = lastInsertion,
              KeyboardLogic.canRevert(insertion, contextBefore: proxy?.documentContextBeforeInput) else {
            model.strip = nil
            return
        }
        for _ in insertion.text { proxy?.deleteBackward() }
        lastInsertion = nil
        model.strip = nil
        tap()
    }

    private func useRaw() {
        guard let insertion = lastInsertion, let raw = insertion.raw,
              KeyboardLogic.canRevert(insertion, contextBefore: proxy?.documentContextBeforeInput) else {
            model.strip = nil
            return
        }
        for _ in insertion.text { proxy?.deleteBackward() }
        proxy?.insertText(raw)
        lastInsertion = Insertion(text: raw, raw: nil, at: .now)
        flash(.undoRaw(hasRaw: false), for: 3)
        tap()
    }

    private func pasteLast() {
        guard let last = store.read(Insertion.self, from: BridgeFile.last) else {
            model.strip = nil
            return
        }
        proxy?.insertText(last.text)
        lastInsertion = last
        model.strip = nil
        tap()
    }

    // MARK: Plumbing

    private var documentID: String? { proxy?.documentIdentifier.uuidString }

    private func send(_ request: KeyboardRequest) {
        store.write(request, to: BridgeFile.request)
        DarwinNotice.post(BridgeNotice.request)
    }

    private func startLevels() {
        levelTimer?.invalidate()
        levelTimer = Timer.scheduledTimer(withTimeInterval: 0.05, repeats: true) { [weak self] _ in
            MainActor.assumeIsolated { self?.tickLevels() }
        }
    }

    private func tickLevels() {
        let level = store.readData(BridgeFile.level).map(LevelCodec.decode) ?? 0
        var levels = model.levels
        levels.append(CGFloat(max(0.06, level)))
        if levels.count > 24 { levels.removeFirst(levels.count - 24) }
        model.levels = levels
        if let started = recordingStarted, case .recording = model.mode {
            model.mode = .recording(seconds: Int(Date.now.timeIntervalSince(started)))
        }
    }

    private func stopLevels() {
        levelTimer?.invalidate()
        levelTimer = nil
    }

    private func flash(_ strip: KeyboardModel.Strip, for seconds: Double = 2.5, then next: (() -> Void)? = nil) {
        stripTask?.cancel()
        withAnimation(Motion.fade) { model.strip = strip }
        stripTask = Task { [weak self] in
            try? await Task.sleep(for: .seconds(seconds))
            guard !Task.isCancelled, let self, self.model.strip == strip else { return }
            withAnimation(Motion.fade) { self.model.strip = nil }
            next?()
        }
    }

    private func tap() {
        UIImpactFeedbackGenerator(style: .light).impactOccurred()
    }

    /// Keyboards can't call UIApplication.open directly. Find the app object and call open
    /// through the Objective-C runtime.
    private func openFriday(path: String) {
        guard let url = URL(string: "friday://\(path)?from=keyboard") else { return }
        let selector = NSSelectorFromString("openURL:options:completionHandler:")
        var responder: UIResponder? = input
        var app: NSObject?
        while let current = responder {
            if let found = current as? UIApplication { app = found; break }
            responder = current.next
        }
        if app == nil, UIApplication.responds(to: NSSelectorFromString("sharedApplication")) {
            app = UIApplication.perform(NSSelectorFromString("sharedApplication"))?.takeUnretainedValue() as? NSObject
        }
        guard let app, app.responds(to: selector) else {
            flash(.warning("Open Friday to start"))
            return
        }
        typealias OpenURL = @convention(c) (AnyObject, Selector, NSURL, NSDictionary, AnyObject?) -> Void
        let open = unsafeBitCast(app.method(for: selector), to: OpenURL.self)
        open(app, selector, url as NSURL, NSDictionary(), nil)
    }
}
