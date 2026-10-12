import Foundation

/// What changed, for the highlight under each row after Done (PLAN §3).
public enum Change: Equatable, Sendable {
    case added(id: String)
    case completed(id: String)
    case uncompleted(id: String)
    case deleted(Item)
    case moved(id: String, fromDate: Day, fromTime: TimeOfDay?)
    case renamed(id: String)
    case focused(id: String, on: Bool)
    case noted(id: String)
    case deletedBox(Note)
    case editedBox(id: String)

    public var id: String {
        switch self {
        case .added(let id), .completed(let id), .uncompleted(let id), .moved(let id, _, _),
             .renamed(let id), .focused(let id, _), .noted(let id): id
        case .deleted(let item): item.id
        case .deletedBox(let note): note.id
        case .editedBox(let id): id
        }
    }

    /// The short note shown on the row for ~5 s: "New", "Done", "from 14:00", "→ Sun".
    public func label(in store: Store, today: Day) -> String {
        switch self {
        case .added: return "New"
        case .completed: return "Done"
        case .uncompleted: return "Not done"
        case .deleted: return "Deleted"
        case .renamed: return "Renamed"
        case .focused(_, let on): return on ? "Focus" : "Not focus"
        case .noted: return "Saved"
        case .deletedBox: return "Deleted"
        case .editedBox: return "Edited"
        case .moved(let id, let fromDate, let fromTime):
            guard let item = store.item(id) else { return "Moved" }
            if item.date != fromDate {
                if item.date == today { return "→ Today" }
                if item.date == today.adding(days: 1) { return "→ Tomorrow" }
                if today.days(until: item.date) < 7, item.date > today { return "→ \(item.date.shortWeekday)" }
                return "→ \(item.date.day)/\(item.date.month)"
            }
            if let fromTime { return "from \(fromTime)" }
            return "Moved"
        }
    }
}

public struct ApplyResult: Equatable, Sendable {
    public var store: Store
    public var changes: [Change]
    public var problems: [DecisionProblem]
    /// Everything that isn't a schedule/note action (messages, calls, web…), for the abilities.
    public var other: [DecisionAction]
}

public enum Schedule {
    /// Applies all store actions in one step. The caller keeps the old store as the single undo point.
    public static func apply(_ actions: [DecisionAction], to store: Store, now: Date) -> ApplyResult {
        var s = store
        var changes: [Change] = []
        var problems: [DecisionProblem] = []
        var other: [DecisionAction] = []

        func index(_ id: String) -> Int? {
            let i = s.items.firstIndex { $0.id == id }
            if i == nil { problems.append(.unknownItem(id)) }
            return i
        }

        for action in actions {
            switch action {
            case let .add(title, date, time, focus, place):
                let id = s.makeID("a")
                s.items.append(Item(id: id, title: title, date: date, time: time, focus: focus, place: place, created: now))
                changes.append(.added(id: id))
            case .complete(let id):
                guard let i = index(id) else { continue }
                s.items[i].done = true
                s.items[i].doneAt = now
                changes.append(.completed(id: id))
            case .uncomplete(let id):
                guard let i = index(id) else { continue }
                s.items[i].done = false
                s.items[i].doneAt = nil
                changes.append(.uncompleted(id: id))
            case .delete(let id):
                guard let i = index(id) else { continue }
                changes.append(.deleted(s.items.remove(at: i)))
            case let .move(id, date, time):
                guard let i = index(id) else { continue }
                let old = s.items[i]
                s.items[i].date = date
                s.items[i].time = time ?? old.time
                changes.append(.moved(id: id, fromDate: old.date, fromTime: old.time))
            case let .rename(id, title):
                guard let i = index(id) else { continue }
                s.items[i].title = title
                changes.append(.renamed(id: id))
            case let .focus(id, on):
                guard let i = index(id) else { continue }
                s.items[i].focus = on
                changes.append(.focused(id: id, on: on))
            case let .note(text, title, remind):
                let id = s.makeID("n")
                s.notes.insert(Note(id: id, title: title, text: text, reminder: remind, created: now), at: 0)
                changes.append(.noted(id: id))
            case .deleteBox(let id):
                guard let i = s.notes.firstIndex(where: { $0.id == id }) else { problems.append(.unknownItem(id)); continue }
                changes.append(.deletedBox(s.notes.remove(at: i)))
            case let .editBox(id, title, text):
                guard s.note(id) != nil else { problems.append(.unknownItem(id)); continue }
                s.editNote(id, title: title ?? s.note(id)?.title, text: text, now: now)
                changes.append(.editedBox(id: id))
            case let .pinBox(id, on):
                guard let i = s.notes.firstIndex(where: { $0.id == id }) else { problems.append(.unknownItem(id)); continue }
                s.notes[i].pinned = on
                changes.append(.editedBox(id: id))
            case let .remindBox(id, at):
                guard s.note(id) != nil else { problems.append(.unknownItem(id)); continue }
                s.setReminder(id, at)
                changes.append(.editedBox(id: id))
            default:
                other.append(action)
            }
        }
        return ApplyResult(store: s, changes: changes, problems: problems, other: other)
    }

    /// Unfinished items from past days move to today, keep their time, and land in Also
    /// (PLAN §3.1). Returns the ids that moved.
    public static func rollover(_ store: Store, today: Day) -> (store: Store, moved: [String]) {
        var s = store
        var moved: [String] = []
        for i in s.items.indices where !s.items[i].done && s.items[i].date < today {
            s.items[i].date = today
            s.items[i].focus = false
            moved.append(s.items[i].id)
        }
        return (s, moved)
    }
}

/// The Today screen's three parts (PLAN §3).
public struct TodayLayout: Equatable, Sendable {
    public var focus: [Item]
    public var also: [Item]
    public var next: Item?

    public init(store: Store, today: Day) {
        let todays = store.items.filter { $0.date == today }.sorted(by: TodayLayout.order)
        focus = todays.filter(\.focus)
        also = todays.filter { !$0.focus }
        next = store.items.filter { $0.date > today && !$0.done }
            .sorted { ($0.date, $0.time ?? TimeOfDay(hour: 23, minute: 59)!) < ($1.date, $1.time ?? TimeOfDay(hour: 23, minute: 59)!) }
            .first
    }

    /// Unfinished first; timed items by time, then untimed by when they were added.
    static func order(_ a: Item, _ b: Item) -> Bool {
        if a.done != b.done { return !a.done }
        switch (a.time, b.time) {
        case let (x?, y?) where x != y: return x < y
        case (_?, nil): return true
        case (nil, _?): return false
        default: return a.created < b.created
        }
    }
}

/// The ITEMS line of the decision prompt: today, the next 7 days and anything overdue,
/// in compact keys to keep the prompt small (RISKS G6).
public func promptItems(_ store: Store, today: Day, limit: Int = 40) -> String {
    let horizon = today.adding(days: 7)
    let rows = store.items
        .filter { $0.date <= horizon && (!$0.done || $0.date == today) }
        .sorted { ($0.date, $0.time?.description ?? "99") < ($1.date, $1.time?.description ?? "99") }
        .prefix(limit)
        .map { item -> [String: Any] in
            var row: [String: Any] = ["id": item.id, "t": item.title, "d": item.date.description,
                                      "f": item.focus, "x": item.done]
            row["tm"] = item.time?.description ?? NSNull()
            return row
        }
    let data = try! JSONSerialization.data(withJSONObject: Array(rows), options: [.sortedKeys])
    return String(data: data, encoding: .utf8)!
}
