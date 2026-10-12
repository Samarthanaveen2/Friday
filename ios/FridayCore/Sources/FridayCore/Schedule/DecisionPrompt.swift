import Foundation

/// A calendar event as the decision engine sees it (ids "e1", "e2"… are mapped by the app).
public struct CalendarEvent: Equatable, Sendable {
    public var id: String
    public var title: String
    public var date: Day
    public var time: TimeOfDay?
    public var end: TimeOfDay?
    public var calendar: String

    public init(id: String, title: String, date: Day, time: TimeOfDay?, end: TimeOfDay?, calendar: String) {
        self.id = id
        self.title = title
        self.date = date
        self.time = time
        self.end = end
        self.calendar = calendar
    }
}

/// The decision engine's prompt (PLAN §7.2).
public enum DecisionPrompt {
    public static func input(now: Date, timeZone: TimeZone, store: Store, places: [String], said: String,
                             events: [CalendarEvent] = []) -> String {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = timeZone
        let c = calendar.dateComponents([.hour, .minute], from: now)
        let day = Day(now, in: timeZone)
        let today = TimeRules.today(now: now, in: timeZone)
        let placesJSON = String(data: try! JSONSerialization.data(withJSONObject: places), encoding: .utf8)!
        let saidJSON = String(data: try! JSONSerialization.data(withJSONObject: [said]), encoding: .utf8)!.dropFirst().dropLast()
        return """
        NOW: \(day)T\(String(format: "%02d:%02d", c.hour!, c.minute!)) \(day.shortWeekday) (\(timeZone.identifier))
        ITEMS: \(promptItems(store, today: today))
        EVENTS: \(promptEvents(events))
        BOXES: \(promptBoxes(store))
        PLACES: \(placesJSON)
        SAID: \(saidJSON)
        """
    }

    public static let system = """
    Decide what the user wants done and output the actions. JSON only: {"actions":[...]}.
    Calendar (the user's iPhone Calendar; ids from EVENTS):
     {"a":"add_event","title":s,"date":"YYYY-MM-DD","time":"HH:MM","minutes":n|null}
     {"a":"move_event","id":s,"date":"YYYY-MM-DD","time":"HH:MM"|null}
     {"a":"cancel_event","id":s}
    Friday's to-dos (ITEMS):
     {"a":"add","title":s,"date":"YYYY-MM-DD","time":"HH:MM"|null,"focus":b,"place":s|null}
     {"a":"complete","id":s} {"a":"uncomplete","id":s} {"a":"delete","id":s}
     {"a":"move","id":s,"date":"YYYY-MM-DD","time":"HH:MM"|null}
     {"a":"rename","id":s,"title":s} {"a":"focus","id":s,"on":b}
    Boxes (the user's notes; ids from BOXES):
     {"a":"note","title":s|null,"text":s,"remind":"YYYY-MM-DDTHH:MM"|null}   (a new box)
     {"a":"delete_box","id":s} {"a":"edit_box","id":s,"title":s|null,"text":s}
     {"a":"pin_box","id":s,"on":b} {"a":"remind_box","id":s,"at":"YYYY-MM-DDTHH:MM"|null}
    Answer:
     {"a":"answer","text":s}   (1-3 short sentences, spoken style)
    Other:
     {"a":"message","app":"whatsapp"|"sms","to":s,"text":s}
     {"a":"email","to":s,"subject":s,"body":s}
     {"a":"call","to":s}
     {"a":"alarm","time":"HH:MM","date":"YYYY-MM-DD"|null,"label":s|null}
     {"a":"timer","minutes":n,"label":s|null}
     {"a":"save_place","name":s}
     {"a":"music","service":"spotify"|"apple","query":s}
     {"a":"notion","text":s}
     {"a":"shortcut","name":s,"input":s|null}
     {"a":"open","target":s}
     {"a":"ask","kind":"web"|"email"|"health"|"contacts","query":s}
    Rules:
    - One utterance can hold many actions; output all of them in order.
    - Match existing items by meaning; use their id; never invent ids.
    - Meetings, appointments, classes, calls at a time, anything with other people at a set time -> add_event.
      Plain to-dos ("buy milk", "finish the report") -> add. "Remind me at 6 to X" -> add with that time.
    - Cancel or move a meeting -> cancel_event / move_event with the matching EVENTS id (match by meaning and day).
      If the meeting is only written in a box (not in EVENTS), edit_box to remove that line instead.
    - "Delete/clear all (my) boxes" -> delete_box for every BOXES id. Delete a box only when clearly asked.
    - Questions (about the schedule, boxes, money in a box, or general knowledge) -> answer, using ITEMS/EVENTS/BOXES.
      Things needing live info (news, weather, scores) -> answer saying you can't look that up yet.
    - delete only if the user clearly says delete/remove/cancel/drop.
    - focus=true ONLY if the user explicitly calls it priority/important/top/focus.
    - Thoughts, ideas, lists, anything worth keeping that isn't a to-do, event, question or command -> note (a box), the user's words cleaned, not summarised. Short title only if obvious.
    - Never save a command or a question as a note.
    - Messages and emails: write the text the user would send, in their voice.
    - Use "ask" only when an answer needs outside info.
    - Titles short, no dates/times inside. If unsure, use note: never drop what was said.
    """
}

/// The EVENTS line: compact keys to keep the prompt small.
public func promptEvents(_ events: [CalendarEvent], limit: Int = 40) -> String {
    let rows = events.prefix(limit).map { e -> [String: Any] in
        var row: [String: Any] = ["id": e.id, "t": e.title, "d": e.date.description, "cal": e.calendar]
        if let time = e.time { row["tm"] = time.description }
        if let end = e.end { row["end"] = end.description }
        return row
    }
    let data = (try? JSONSerialization.data(withJSONObject: rows, options: [.sortedKeys])) ?? Data("[]".utf8)
    return String(decoding: data, as: UTF8.self)
}

/// The BOXES line: id, title and the start of the text.
public func promptBoxes(_ store: Store, limit: Int = 40) -> String {
    let rows = store.boxesInOrder.prefix(limit).map { note -> [String: Any] in
        var row: [String: Any] = ["id": note.id, "x": String(note.text.prefix(160))]
        if let title = note.title { row["t"] = title }
        if note.pinned { row["p"] = true }
        return row
    }
    let data = (try? JSONSerialization.data(withJSONObject: rows, options: [.sortedKeys])) ?? Data("[]".utf8)
    return String(decoding: data, as: UTF8.self)
}
