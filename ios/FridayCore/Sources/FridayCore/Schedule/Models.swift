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

/// A box on Home (PLAN §3): a note with an optional title, pin and reminder.
public struct Note: Codable, Equatable, Identifiable, Sendable {
    public var id: String
    public var title: String?
    public var text: String
    public var pinned: Bool
    /// Soft background colour key ("sand", "sage", "sky", "lavender", "rose"); nil = white.
    public var color: String?
    /// When to remind (shown on the box; notifications come with the calendar step).
    public var reminder: Date?
    public var created: Date
    public var edited: Date?

    public init(id: String, title: String? = nil, text: String, pinned: Bool = false, color: String? = nil,
                reminder: Date? = nil, created: Date, edited: Date? = nil) {
        self.id = id
        self.title = title
        self.text = text
        self.pinned = pinned
        self.color = color
        self.reminder = reminder
        self.created = created
        self.edited = edited
    }

    private enum CodingKeys: String, CodingKey { case id, title, text, pinned, color, reminder, created, edited }

    /// Fields added later decode as empty, so older saved data still loads.
    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = try c.decode(String.self, forKey: .id)
        title = try c.decodeIfPresent(String.self, forKey: .title)
        text = try c.decodeIfPresent(String.self, forKey: .text) ?? ""
        pinned = try c.decodeIfPresent(Bool.self, forKey: .pinned) ?? false
        color = try c.decodeIfPresent(String.self, forKey: .color)
        reminder = try c.decodeIfPresent(Date.self, forKey: .reminder)
        created = try c.decode(Date.self, forKey: .created)
        edited = try c.decodeIfPresent(Date.self, forKey: .edited)
    }

    /// Nothing written: a box like this is removed when you leave it.
    public var isBlank: Bool {
        (title ?? "").trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            && text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
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
    public func note(_ id: String) -> Note? { notes.first { $0.id == id } }

    private enum CodingKeys: String, CodingKey { case items, notes, nextID }

    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        items = try c.decodeIfPresent([Item].self, forKey: .items) ?? []
        notes = try c.decodeIfPresent([Note].self, forKey: .notes) ?? []
        nextID = try c.decodeIfPresent(Int.self, forKey: .nextID) ?? 1
    }
}
