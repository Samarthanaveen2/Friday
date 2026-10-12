import Foundation
import FridayCore
import Observation

/// Home's saved data: boxes and today's items, kept as JSON in the App Group with a
/// backup per weekday. Every change with a label can be undone from the pill for 5 s.
@MainActor
@Observable
final class BoxStore {
    static let shared = BoxStore()

    private(set) var store: Store
    /// The change pill ("New box", "Box deleted").
    private(set) var pill: String?
    var canUndo: Bool { undoPoint != nil }

    private var undoPoint: Store?
    /// Extra work to undo with the store (calendar changes).
    private var undoExtra: (() -> Void)?
    private var pillTask: Task<Void, Never>?
    private static let file = "store.json"

    private init() {
        store = GroupStore.shared.readData(BoxStore.file).flatMap(StoreCodec.decode) ?? Store()
    }

    /// Applies a change and saves it. With a `label`, shows the pill with Undo.
    /// `onUndo`: also run on Undo (e.g. put calendar changes back); then the pill shows even if
    /// the store itself didn't change.
    func change(_ label: String? = nil, onUndo: (() -> Void)? = nil, _ edit: (inout Store) -> Void) {
        let before = store
        edit(&store)
        guard store != before || onUndo != nil else { return }
        if store != before { save(before: before) }
        if let label {
            undoPoint = before
            undoExtra = onUndo
            show(label)
        }
    }

    func undo() {
        guard let point = undoPoint else { return }
        let before = store
        store = point
        undoPoint = nil
        undoExtra?()
        undoExtra = nil
        if store != before { save(before: before) }
        show(nil)
    }

    /// A pill without Undo ("Didn't catch that").
    func flash(_ text: String) {
        undoPoint = nil
        undoExtra = nil
        show(text)
    }

    private func show(_ text: String?) {
        pill = text
        pillTask?.cancel()
        guard text != nil else { return }
        pillTask = Task {
            try? await Task.sleep(for: .seconds(5))
            guard !Task.isCancelled else { return }
            pill = nil
            undoPoint = nil
            undoExtra = nil
        }
    }

    private func save(before: Store) {
        guard let data = StoreCodec.encode(store) else { return }
        // Once a day, keep yesterday's state in that weekday's backup slot (7 days of history).
        let today = TimeRules.today(now: .now, in: .current).description
        if UserDefaults.standard.string(forKey: "store.backupDay") != today, let old = StoreCodec.encode(before) {
            GroupStore.shared.writeData(old, to: StoreCodec.backupName(for: .now, in: .current), atomic: true)
            UserDefaults.standard.set(today, forKey: "store.backupDay")
        }
        GroupStore.shared.writeData(data, to: BoxStore.file, atomic: true)
        Notifier.sync(store)
    }
}
