import Foundation

/// The decision engine's prompt (PLAN §7.2).
public enum DecisionPrompt {
    public static func input(now: Date, timeZone: TimeZone, store: Store, places: [String], said: String) -> String {
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
        PLACES: \(placesJSON)
        SAID: \(saidJSON)
        """
    }

    public static let system = """
    Decide what the user wants done and output the actions. JSON only: {"actions":[...]}.
    Schedule:
     {"a":"add","title":s,"date":"YYYY-MM-DD","time":"HH:MM"|null,"focus":b,"place":s|null}
     {"a":"complete","id":s} {"a":"uncomplete","id":s} {"a":"delete","id":s}
     {"a":"move","id":s,"date":"YYYY-MM-DD","time":"HH:MM"|null}
     {"a":"rename","id":s,"title":s} {"a":"focus","id":s,"on":b}
    Other:
     {"a":"note","text":s}
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
    - delete only if the user clearly says delete/remove/cancel/drop.
    - focus=true ONLY if the user explicitly calls it priority/important/top/focus.
    - "note"/"remember this"/"idea" -> note with the user's words cleaned, not summarised.
    - Messages and emails: write the text the user would send, in their voice.
    - Use "ask" only when an answer needs outside info.
    - Titles short, no dates/times inside. Nothing actionable -> {"actions":[]}.
    """
}
