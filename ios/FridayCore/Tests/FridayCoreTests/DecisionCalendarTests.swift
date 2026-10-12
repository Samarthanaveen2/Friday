import XCTest
@testable import FridayCore

final class DecisionCalendarTests: XCTestCase {
    let ist = TimeZone(identifier: "Asia/Kolkata")!
    // 2026-10-12 10:00 IST
    let now = ISO8601DateFormatter().date(from: "2026-10-12T04:30:00Z")!

    func testParsesCalendarActionsAndNotes() {
        let reply = #"""
        {"actions":[
          {"a":"add_event","title":"Meet Rahul","date":"2026-10-13","time":"20:00","minutes":60},
          {"a":"move_event","id":"e2","date":"2026-10-14","time":"18:30"},
          {"a":"cancel_event","id":"e1"},
          {"a":"note","title":"Poster","text":"blue background","remind":"2026-10-13T09:00"},
          {"a":"add_event","title":"No time","date":"2026-10-13"}
        ]}
        """#
        let (actions, problems) = DecisionParser.parse(reply, said: "meet Rahul tomorrow at 8 pm, move it to 6:30 pm", now: now, timeZone: ist)
        XCTAssertEqual(actions.count, 4)
        XCTAssertEqual(actions[0], DecisionAction.addEvent(title: "Meet Rahul", date: Day("2026-10-13")!, time: TimeOfDay("20:00")!, minutes: 60))
        XCTAssertEqual(actions[1], DecisionAction.moveEvent(id: "e2", date: Day("2026-10-14")!, time: TimeOfDay("18:30")!))
        XCTAssertEqual(actions[2], DecisionAction.cancelEvent(id: "e1"))
        guard case let .note(text, title, remind) = actions[3] else { return XCTFail() }
        XCTAssertEqual(text, "blue background")
        XCTAssertEqual(title, "Poster")
        XCTAssertNotNil(remind)
        XCTAssertTrue(actions[0].isCalendarAction && !actions[0].isStoreAction)
        XCTAssertEqual(problems, [DecisionProblem.malformed("add_event: missing time")])
    }

    func testNoteBecomesABoxWithReminder() {
        let at = Date(timeIntervalSince1970: 1_791_100_000)
        let result = Schedule.apply([.note(text: "call the bank", title: "Bank", remind: at)], to: Store(), now: now)
        XCTAssertEqual(result.store.notes.first?.title, "Bank")
        XCTAssertEqual(result.store.notes.first?.reminder, at)
    }

    func testPromptListsEvents() {
        let events = [CalendarEvent(id: "e1", title: "Meeting with Arjun", date: Day("2026-10-13")!,
                                    time: TimeOfDay("21:00"), end: TimeOfDay("22:00"), calendar: "Friday")]
        let input = DecisionPrompt.input(now: now, timeZone: ist, store: Store(), places: [], said: "cancel it", events: events)
        XCTAssertTrue(input.contains(#"EVENTS: [{"cal":"Friday","d":"2026-10-13","end":"22:00","id":"e1","t":"Meeting with Arjun","tm":"21:00"}]"#), input)
        XCTAssertTrue(DecisionPrompt.system.contains("cancel_event"))
    }

    func testCancelIsACommandAndWakeWordPrompt() {
        XCTAssertTrue(Dictation.hasCommand("Friday, cancel my meeting with my other friend tomorrow"))
        XCTAssertTrue(BoxEdit.isEdit("Friday cancel my meeting with my other friend tomorrow"))
        XCTAssertTrue(Dictation(dictionary: ["Samartha"]).whisperPrompt().hasPrefix("Okay Friday,"))
    }
}

final class DecisionBoxTests: XCTestCase {
    func testBoxActionsAndAnswer() {
        var store = Store()
        let a = store.addNote(text: "Meeting with my friend at 8 pm tomorrow\nMeeting with my other friend at 9 pm tomorrow", now: .now)
        let b = store.addNote(text: "old idea", now: .now)
        let reply = """
        {"actions":[{"a":"edit_box","id":"\(a)","text":"Meeting with my friend at 8 pm tomorrow"},
                    {"a":"delete_box","id":"\(b)"},{"a":"answer","text":"You have 1 meeting tomorrow."},{"a":"delete_box","id":"zz"}]}
        """
        let (actions, problems) = DecisionParser.parse(reply)
        XCTAssertEqual(problems, [])
        XCTAssertEqual(actions.last, DecisionAction.deleteBox(id: "zz"))
        let result = Schedule.apply(actions, to: store, now: .now)
        XCTAssertEqual(result.store.notes.map(\.id), [a])
        XCTAssertEqual(result.store.note(a)?.text, "Meeting with my friend at 8 pm tomorrow")
        XCTAssertEqual(result.other, [DecisionAction.answer(text: "You have 1 meeting tomorrow.")])
        XCTAssertEqual(result.problems, [DecisionProblem.unknownItem("zz")])
        XCTAssertTrue(DecisionPrompt.input(now: .now, timeZone: .current, store: store, places: [], said: "x").contains("BOXES: [{"))
    }
}
