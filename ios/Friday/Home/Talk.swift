import Foundation
import FridayCore
import Observation

/// Talking on Home or inside a box: dictate, then the words become a new box or are added to
/// the open one. (The decision engine, which files things for you, comes next.)
@MainActor
@Observable
final class Talk {
    static let shared = Talk()

    enum Target: Equatable {
        case newBox
        case box(String)
    }

    private(set) var target: Target?
    private(set) var working = false
    /// Where the words of the dictation being written will go.
    private var writingFor: Target?

    /// The talk pill's state for one place (Home or a box): only that place shows listening.
    func state(for place: Target, levels: [Float]) -> TalkState {
        if target == place { return .listening(levels.suffix(20).map { CGFloat($0) }) }
        if working && writingFor == place { return .writing }
        return .idle
    }

    var listening: Bool { target != nil }

    func start(_ target: Target) {
        guard self.target == nil, !working else { return }
        Task {
            if !Session.shared.running { await Session.shared.start(source: .app) }
            guard DictationPipeline.shared.begin() else {
                BoxStore.shared.flash("Mic isn't ready")
                return
            }
            Haptics.tap()
            self.target = target
            if target == .newBox { Session.shared.setActivity(phase: "listening") }
        }
    }

    func cancel() {
        guard let target else { return }
        if target == .newBox { Session.shared.setActivity(phase: "on") }
        self.target = nil
        DictationPipeline.shared.cancel()
    }

    func done() {
        guard let target else { return }
        self.target = nil
        working = true
        writingFor = target
        if target == .newBox { Session.shared.setActivity(phase: "thinking") }
        Task {
            let outcome = await DictationPipeline.shared.finish()
            defer {
                working = false
                writingFor = nil
            }
            guard let outcome, !outcome.nothing,
                  !outcome.raw.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
                BoxStore.shared.flash("Didn't catch that")
                if target == .newBox { Session.shared.setActivity(phase: "done", message: "Didn't catch that") }
                return
            }
            switch target {
            case .newBox:
                // Home: Friday decides what you meant (to-do, calendar event, box) and does it.
                let said = outcome.text.trimmingCharacters(in: .whitespacesAndNewlines)
                guard !said.isEmpty else {
                    BoxStore.shared.flash("Didn't catch that")
                    Session.shared.setActivity(phase: "done", message: "Didn't catch that")
                    return
                }
                let summary = await Manager.handle(said)
                Session.shared.setActivity(phase: "done", message: summary)
                Haptics.success()
            case .box(let id):
                let note = BoxStore.shared.store.note(id)
                let current = note?.text ?? ""
                // "Friday, make this a checklist": the instruction edits what's already in the box.
                if BoxEdit.isEdit(outcome.raw), !current.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                    guard let edited = await Cleaner.shared.edit(note: current, instruction: outcome.raw) else {
                        BoxStore.shared.flash("Couldn't change the box")
                        return
                    }
                    Haptics.success()
                    BoxStore.shared.change("Box updated") { $0.editNote(id, title: note?.title, text: edited, now: .now) }
                    return
                }
                guard !outcome.text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
                    BoxStore.shared.flash("Didn't catch that")
                    return
                }
                Haptics.success()
                BoxStore.shared.change("Added to the box") { $0.appendToNote(id, text: outcome.text, now: .now) }
            }
        }
    }
}
