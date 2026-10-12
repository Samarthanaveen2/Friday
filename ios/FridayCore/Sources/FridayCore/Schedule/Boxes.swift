import Foundation

/// What Home does to boxes and today's items, as plain value changes (each a new undo point).
extension Store {
    /// A new box at the top. Returns its id.
    @discardableResult
    public mutating func addNote(title: String? = nil, text: String, now: Date) -> String {
        let id = makeID("n")
        notes.insert(Note(id: id, title: title, text: text, created: now), at: 0)
        return id
    }

    public mutating func editNote(_ id: String, title: String?, text: String, now: Date) {
        guard let i = notes.firstIndex(where: { $0.id == id }) else { return }
        let cleanTitle = title.flatMap { $0.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? nil : $0 }
        guard notes[i].title != cleanTitle || notes[i].text != text else { return }
        notes[i].title = cleanTitle
        notes[i].text = text
        notes[i].edited = now
    }

    /// Adds dictated words to the end of a box, as a new paragraph.
    public mutating func appendToNote(_ id: String, text: String, now: Date) {
        guard let i = notes.firstIndex(where: { $0.id == id }) else { return }
        let words = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !words.isEmpty else { return }
        let current = notes[i].text.trimmingCharacters(in: .whitespacesAndNewlines)
        notes[i].text = current.isEmpty ? words : current + "\n\n" + words
        notes[i].edited = now
    }

    public mutating func deleteNote(_ id: String) {
        notes.removeAll { $0.id == id }
    }

    public mutating func togglePin(_ id: String) {
        guard let i = notes.firstIndex(where: { $0.id == id }) else { return }
        notes[i].pinned.toggle()
    }

    public mutating func setColor(_ id: String, _ color: String?) {
        guard let i = notes.firstIndex(where: { $0.id == id }) else { return }
        notes[i].color = color
    }

    public mutating func setReminder(_ id: String, _ date: Date?) {
        guard let i = notes.firstIndex(where: { $0.id == id }) else { return }
        notes[i].reminder = date
    }

    /// Ticks a today item done or not done.
    public mutating func toggleItem(_ id: String, now: Date) {
        guard let i = items.firstIndex(where: { $0.id == id }) else { return }
        items[i].done.toggle()
        items[i].doneAt = items[i].done ? now : nil
    }

    /// Home's order: pinned first, then the most recently changed.
    public var boxesInOrder: [Note] {
        notes.sorted { a, b in
            if a.pinned != b.pinned { return a.pinned }
            return (a.edited ?? a.created) > (b.edited ?? b.created)
        }
    }

    /// Boxes whose reminder falls on `today` (Friday's day runs 04:00 to 04:00), earliest first.
    public func reminders(on today: Day, in timeZone: TimeZone) -> [Note] {
        notes.filter { note in
            guard let at = note.reminder else { return false }
            return TimeRules.today(now: at, in: timeZone) == today
        }
        .sorted { ($0.reminder ?? .distantFuture) < ($1.reminder ?? .distantFuture) }
    }

    /// Boxes whose title or text contains every word of `query`.
    public func search(_ query: String) -> [Note] {
        let words = query.lowercased().split(whereSeparator: \.isWhitespace).map(String.init)
        guard !words.isEmpty else { return [] }
        return boxesInOrder.filter { note in
            let hay = ((note.title ?? "") + " " + note.text).lowercased()
            return words.allSatisfy { hay.contains($0) }
        }
    }
}

/// The saved file: JSON with ISO dates. Decoding never throws away a store it can't fully read.
public enum StoreCodec {
    public static func encode(_ store: Store) -> Data? {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        encoder.outputFormatting = [.sortedKeys]
        return try? encoder.encode(store)
    }

    public static func decode(_ data: Data) -> Store? {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return try? decoder.decode(Store.self, from: data)
    }

    /// One backup slot per weekday, overwritten a week later: the last 7 days are always kept.
    public static func backupName(for date: Date, in timeZone: TimeZone) -> String {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = timeZone
        return "store-backup-\(calendar.component(.weekday, from: date)).json"
    }
}
