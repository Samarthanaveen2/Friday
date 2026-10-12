import Foundation

/// One action from the decision engine's JSON (PLAN §7.2).
public enum DecisionAction: Equatable, Sendable {
    // Schedule
    case add(title: String, date: Day, time: TimeOfDay?, focus: Bool, place: String?)
    case complete(id: String)
    case uncomplete(id: String)
    case delete(id: String)
    case move(id: String, date: Day, time: TimeOfDay?)
    case rename(id: String, title: String)
    case focus(id: String, on: Bool)
    // Calendar (iPhone Calendar events, ids from EVENTS)
    case addEvent(title: String, date: Day, time: TimeOfDay, minutes: Int?)
    case moveEvent(id: String, date: Day, time: TimeOfDay?)
    case cancelEvent(id: String)
    // Other
    /// Becomes a box; `remind` sets its reminder.
    case note(text: String, title: String? = nil, remind: Date? = nil)
    // Boxes (ids from BOXES)
    case deleteBox(id: String)
    case editBox(id: String, title: String?, text: String)
    case pinBox(id: String, on: Bool)
    case remindBox(id: String, at: Date?)
    /// A short spoken-style answer shown in a card.
    case answer(text: String)
    case message(app: String, to: String, text: String)
    case email(to: String, subject: String, body: String)
    case call(to: String)
    case alarm(time: TimeOfDay, date: Day?, label: String?)
    case timer(minutes: Int, label: String?)
    case savePlace(name: String)
    case music(service: String, query: String)
    case notion(text: String)
    case shortcut(name: String, input: String?)
    case open(target: String)
    case ask(kind: String, query: String)

    /// Schedule and note actions are applied together in one step with one undo.
    public var isStoreAction: Bool {
        switch self {
        case .add, .complete, .uncomplete, .delete, .move, .rename, .focus, .note,
             .deleteBox, .editBox, .pinBox, .remindBox: true
        default: false
        }
    }

    public var isCalendarAction: Bool {
        switch self {
        case .addEvent, .moveEvent, .cancelEvent: true
        default: false
        }
    }
}

/// "2026-10-13T20:00" in the user's time zone.
func moment(_ text: String, timeZone: TimeZone) -> Date? {
    let parts = text.split(separator: "T")
    guard parts.count == 2, let day = Day(String(parts[0])), let time = TimeOfDay(String(parts[1].prefix(5))) else { return nil }
    var calendar = Calendar(identifier: .gregorian)
    calendar.timeZone = timeZone
    return calendar.date(from: DateComponents(year: day.year, month: day.month, day: day.day, hour: time.hour, minute: time.minute))
}

public enum DecisionProblem: Equatable, Sendable {
    case notJSON
    case malformed(String)
    case badDate(String)
    case unknownItem(String)
    case unsupported(String)
}

/// Turns the model's reply into checked actions. Bad parts are dropped and reported,
/// never guessed (RISKS C4).
public enum DecisionParser {
    public static func parse(_ reply: String, said: String = "", now: Date = .now,
                             timeZone: TimeZone = .current) -> (actions: [DecisionAction], problems: [DecisionProblem]) {
        guard let start = reply.firstIndex(of: "{"), let end = reply.lastIndex(of: "}"), start < end,
              let data = String(reply[start...end]).data(using: .utf8),
              let object = (try? JSONSerialization.jsonObject(with: data)) as? [String: Any],
              let list = object["actions"] as? [[String: Any]]
        else { return ([], [.notJSON]) }

        var actions: [DecisionAction] = []
        var problems: [DecisionProblem] = []
        for raw in list {
            switch action(raw, said: said, now: now, timeZone: timeZone) {
            case .success(let action): actions.append(action)
            case .failure(let problem): problems.append(problem.value)
            }
        }
        return (actions, problems)
    }

    private struct Failure: Error { let value: DecisionProblem }

    private static func action(_ raw: [String: Any], said: String, now: Date,
                               timeZone: TimeZone) -> Result<DecisionAction, Failure> {
        let kind = raw["a"] as? String ?? ""
        func str(_ key: String) -> String? {
            let value = (raw[key] as? String)?.trimmingCharacters(in: .whitespacesAndNewlines)
            return value?.isEmpty == false ? value : nil
        }
        func bool(_ key: String) -> Bool {
            if let b = raw[key] as? Bool { return b }
            if let s = raw[key] as? String { return s == "true" }
            return false
        }
        func need(_ key: String) throws -> String {
            guard let value = str(key) else { throw Failure(value: .malformed("\(kind): missing \(key)")) }
            return value
        }
        func day(_ key: String, required: Bool) throws -> Day? {
            guard let text = str(key) else {
                if required { throw Failure(value: .malformed("\(kind): missing \(key)")) }
                return nil
            }
            guard let parsed = Day(text) else { throw Failure(value: .badDate(text)) }
            return TimeRules.fixTomorrow(parsed, said: said, now: now, in: timeZone)
        }
        func time(_ key: String) throws -> TimeOfDay? {
            guard let text = str(key) else { return nil }
            guard let parsed = TimeOfDay(text) else { throw Failure(value: .badDate(text)) }
            return TimeRules.fixBareHour(parsed, said: said)
        }

        do {
            let action: DecisionAction
            switch kind {
            case "add":
                action = .add(title: try need("title"), date: try day("date", required: true)!, time: try time("time"),
                              focus: bool("focus"), place: str("place"))
            case "complete": action = .complete(id: try need("id"))
            case "uncomplete": action = .uncomplete(id: try need("id"))
            case "delete": action = .delete(id: try need("id"))
            case "move": action = .move(id: try need("id"), date: try day("date", required: true)!, time: try time("time"))
            case "rename": action = .rename(id: try need("id"), title: try need("title"))
            case "focus": action = .focus(id: try need("id"), on: raw["on"] == nil ? true : bool("on"))
            case "note":
                var remind: Date?
                if let text = str("remind") {
                    guard let at = moment(text, timeZone: timeZone) else { throw Failure(value: .badDate(text)) }
                    remind = at
                }
                action = .note(text: try need("text"), title: str("title"), remind: remind)
            case "delete_box": action = .deleteBox(id: try need("id"))
            case "edit_box": action = .editBox(id: try need("id"), title: str("title"), text: try need("text"))
            case "pin_box": action = .pinBox(id: try need("id"), on: raw["on"] == nil ? true : bool("on"))
            case "remind_box":
                var at: Date?
                if let text = str("at") {
                    guard let parsed = moment(text, timeZone: timeZone) else { throw Failure(value: .badDate(text)) }
                    at = parsed
                }
                action = .remindBox(id: try need("id"), at: at)
            case "answer": action = .answer(text: try need("text"))
            case "add_event":
                guard let t = try time("time") else { throw Failure(value: .malformed("add_event: missing time")) }
                let minutes = (raw["minutes"] as? Int) ?? (raw["minutes"] as? Double).map(Int.init) ?? str("minutes").flatMap(Int.init)
                action = .addEvent(title: try need("title"), date: try day("date", required: true)!, time: t,
                                   minutes: minutes.flatMap { $0 > 0 ? $0 : nil })
            case "move_event": action = .moveEvent(id: try need("id"), date: try day("date", required: true)!, time: try time("time"))
            case "cancel_event": action = .cancelEvent(id: try need("id"))
            case "message":
                action = .message(app: str("app") ?? "whatsapp", to: try need("to"), text: try need("text"))
            case "email": action = .email(to: try need("to"), subject: str("subject") ?? "", body: try need("body"))
            case "call": action = .call(to: try need("to"))
            case "alarm":
                guard let t = try time("time") else { throw Failure(value: .malformed("alarm: missing time")) }
                action = .alarm(time: t, date: try day("date", required: false), label: str("label"))
            case "timer":
                let minutes = (raw["minutes"] as? Int) ?? (raw["minutes"] as? Double).map(Int.init) ?? str("minutes").flatMap(Int.init)
                guard let minutes, minutes > 0 else { throw Failure(value: .malformed("timer: missing minutes")) }
                action = .timer(minutes: minutes, label: str("label"))
            case "save_place": action = .savePlace(name: try need("name"))
            case "music": action = .music(service: str("service") ?? "spotify", query: try need("query"))
            case "notion": action = .notion(text: try need("text"))
            case "shortcut": action = .shortcut(name: try need("name"), input: str("input"))
            case "open": action = .open(target: try need("target"))
            case "ask": action = .ask(kind: str("kind") ?? "web", query: try need("query"))
            default: throw Failure(value: .unsupported(kind))
            }
            return .success(action)
        } catch let failure as Failure {
            return .failure(failure)
        } catch {
            return .failure(Failure(value: .malformed(kind)))
        }
    }
}
