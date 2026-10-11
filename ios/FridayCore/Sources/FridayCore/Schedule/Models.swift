import Foundation

/// A schedule item. Friday's own store is the source of truth (PLAN §3.2).
public struct Item: Codable, Equatable, Identifiable, Sendable {
    public var id: String
    public var title: String
    public var date: Day
    public var time: TimeOfDay?
    /// Named as a priority for its day (Focus). Cleared when it rolls over.
    public var focus: Bool
    public var done: Bool
    public var place: String?
    public var created: Date
    public var doneAt: Date?

    public init(id: String, title: String, date: Day, time: TimeOfDay? = nil, focus: Bool = false,
                done: Bool = false, place: String? = nil, created: Date, doneAt: Date? = nil) {
        self.id = id
        self.title = title
        self.date = date
        self.time = time
        self.focus = focus
        self.done = done
        self.place = place
        self.created = created
        self.doneAt = doneAt
    }
}

public struct Note: Codable, Equatable, Identifiable, Sendable {
    public var id: String
    public var text: String
    public var created: Date
    public var edited: Date?

    public init(id: String, text: String, created: Date, edited: Date? = nil) {
        self.id = id
        self.text = text
        self.created = created
        self.edited = edited
    }
}

/// Everything the app saves. A value type, so a copy before a change is the undo point.
public struct Store: Codable, Equatable, Sendable {
    public var items: [Item]
    public var notes: [Note]
    public var nextID: Int

    public init(items: [Item] = [], notes: [Note] = [], nextID: Int = 1) {
        self.items = items
        self.notes = notes
        self.nextID = nextID
    }

    /// Short ids keep the model's prompt small: "a1", "a2", … for items, "n1", … for notes.
    public mutating func makeID(_ prefix: String) -> String {
        defer { nextID += 1 }
        return prefix + String(nextID, radix: 36)
    }

    public func item(_ id: String) -> Item? { items.first { $0.id == id } }
}
