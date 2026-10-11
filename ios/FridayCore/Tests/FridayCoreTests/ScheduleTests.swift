import Foundation
import XCTest
@testable import FridayCore

private let ist = TimeZone(identifier: "Asia/Kolkata")!

private func date(_ iso: String) -> Date {
    ISO8601DateFormatter().date(from: iso)!
}

private func day(_ s: String) -> Day { Day(s)! }
private func time(_ s: String) -> TimeOfDay { TimeOfDay(s)! }

final class DayTests: XCTestCase {
    func testParseAndFormat() {
        XCTAssertEqual(day("2026-10-11").description, "2026-10-11")
        XCTAssertNil(Day("2026-02-30"))
        XCTAssertNil(Day("2026-1-5"))
        XCTAssertNil(Day("tomorrow"))
        XCTAssertEqual(time("9:05").description, "09:05")
        XCTAssertNil(TimeOfDay("24:00"))
        XCTAssertNil(TimeOfDay("5pm"))
    }

    func testArithmetic() {
        XCTAssertEqual(day("2026-12-31").adding(days: 1), day("2027-01-01"))
        XCTAssertEqual(day("2028-03-01").adding(days: -1), day("2028-02-29"))
        XCTAssertEqual(day("2026-10-11").days(until: day("2026-10-18")), 7)
        XCTAssertEqual(day("2026-10-11").shortWeekday, "Sun")
        XCTAssertTrue(day("2026-10-11") < day("2026-11-01"))
    }

    func testLocalDay() {
        // 20:00 UTC on the 10th is 01:30 on the 11th in India.
        XCTAssertEqual(Day(date("2026-10-10T20:00:00Z"), in: ist), day("2026-10-11"))
    }

    func testCodable() throws {
        let item = Item(id: "a1", title: "Gym", date: day("2026-10-11"), time: time("17:00"), created: Date(timeIntervalSince1970: 0))
        let data = try JSONEncoder().encode(item)
        XCTAssertTrue(String(data: data, encoding: .utf8)!.contains("\"2026-10-11\""))
        XCTAssertEqual(try JSONDecoder().decode(Item.self, from: data), item)
    }
}

final class TimeRulesTests: XCTestCase {
    func testDayStartsAtFour() {
        XCTAssertEqual(TimeRules.today(now: date("2026-10-10T20:00:00Z"), in: ist), day("2026-10-10"))  // 01:30
        XCTAssertEqual(TimeRules.today(now: date("2026-10-10T23:00:00Z"), in: ist), day("2026-10-11"))  // 04:30
    }

    func testTomorrowAfterMidnight() {
        let oneThirty = date("2026-10-10T20:00:00Z")  // 01:30 on the 11th
        XCTAssertEqual(TimeRules.fixTomorrow(day("2026-10-12"), said: "gym tomorrow", now: oneThirty, in: ist), day("2026-10-11"))
        XCTAssertEqual(TimeRules.fixTomorrow(day("2026-10-12"), said: "gym on monday", now: oneThirty, in: ist), day("2026-10-12"))
        let noon = date("2026-10-11T06:30:00Z")
        XCTAssertEqual(TimeRules.fixTomorrow(day("2026-10-12"), said: "gym tomorrow", now: noon, in: ist), day("2026-10-12"))
    }

    func testBareHours() {
        XCTAssertEqual(TimeRules.fixBareHour(time("03:00"), said: "warden at 3"), time("15:00"))
        XCTAssertEqual(TimeRules.fixBareHour(time("05:30"), said: "call at five thirty"), time("17:30"))
        XCTAssertEqual(TimeRules.fixBareHour(time("21:00"), said: "class at 9"), time("09:00"))
        XCTAssertEqual(TimeRules.fixBareHour(time("21:00"), said: "class at 21:00"), time("21:00"))
        XCTAssertEqual(TimeRules.fixBareHour(time("06:00"), said: "wake me at 6 am"), time("06:00"))
        XCTAssertEqual(TimeRules.fixBareHour(time("07:00"), said: "run at 7 in the morning"), time("07:00"))
        XCTAssertEqual(TimeRules.fixBareHour(time("21:00"), said: "movie at 9 tonight"), time("21:00"))
        XCTAssertEqual(TimeRules.fixBareHour(time("12:00"), said: "lunch at 12"), time("12:00"))
    }
}

final class DecisionParserTests: XCTestCase {
    let noon = date("2026-10-11T06:30:00Z")

    func testParsesManyActions() {
        let reply = """
        Here you go: {"actions":[
          {"a":"add","title":"Warden","date":"2026-10-11","time":"03:00","focus":true,"place":null},
          {"a":"complete","id":"a1"},
          {"a":"move","id":"a2","date":"2026-10-18","time":null},
          {"a":"note","text":"poster idea, blue background"},
          {"a":"message","app":"whatsapp","to":"Rahul","text":"I'll be 10 min late"},
          {"a":"timer","minutes":20,"label":null},
          {"a":"ask","kind":"web","query":"next Arsenal match"}
        ]}
        """
        let (actions, problems) = DecisionParser.parse(reply, said: "warden at 3", now: noon, timeZone: ist)
        XCTAssertEqual(problems, [])
        XCTAssertEqual(actions, [
            .add(title: "Warden", date: day("2026-10-11"), time: time("15:00"), focus: true, place: nil),
            .complete(id: "a1"),
            .move(id: "a2", date: day("2026-10-18"), time: nil),
            .note(text: "poster idea, blue background"),
            .message(app: "whatsapp", to: "Rahul", text: "I'll be 10 min late"),
            .timer(minutes: 20, label: nil),
            .ask(kind: "web", query: "next Arsenal match"),
        ])
    }

    func testBadPartsAreDroppedNotGuessed() {
        let reply = """
        {"actions":[{"a":"add","title":"Gym","date":"next friday"},{"a":"add","date":"2026-10-11"},
                    {"a":"teleport"},{"a":"complete","id":"a1"}]}
        """
        let (actions, problems) = DecisionParser.parse(reply, now: noon, timeZone: ist)
        XCTAssertEqual(actions, [.complete(id: "a1")])
        XCTAssertEqual(problems, [.badDate("next friday"), .malformed("add: missing title"), .unsupported("teleport")])
    }

    func testNotJSON() {
        XCTAssertEqual(DecisionParser.parse("sorry, I can't").problems, [.notJSON])
        XCTAssertEqual(DecisionParser.parse("{\"actions\":[]}").actions, [])
    }
}

final class ScheduleTests: XCTestCase {
    let now = date("2026-10-11T06:30:00Z")
    let today = day("2026-10-11")

    private func store() -> Store {
        Store(items: [
            Item(id: "a1", title: "Lab report", date: day("2026-10-11"), time: time("11:30"), created: Date(timeIntervalSince1970: 1)),
            Item(id: "a2", title: "Laundry", date: day("2026-10-11"), created: Date(timeIntervalSince1970: 2)),
            Item(id: "a3", title: "Gym", date: day("2026-10-11"), time: time("14:00"), created: Date(timeIntervalSince1970: 3)),
        ], nextID: 4)
    }

    func testApplyAndChanges() {
        let result = Schedule.apply([
            .complete(id: "a1"),
            .move(id: "a3", date: day("2026-10-11"), time: time("17:00")),
            .move(id: "a2", date: day("2026-10-16"), time: nil),
            .add(title: "Warden", date: day("2026-10-11"), time: time("15:00"), focus: true, place: nil),
            .note(text: "poster idea"),
            .call(to: "warden"),
            .delete(id: "zz"),
        ], to: store(), now: now)

        let s = result.store
        XCTAssertTrue(s.item("a1")!.done)
        XCTAssertEqual(s.item("a3")!.time, time("17:00"))
        XCTAssertEqual(s.item("a2")!.date, day("2026-10-16"))
        XCTAssertEqual(s.item("a4")!.title, "Warden")
        XCTAssertEqual(s.notes.first?.text, "poster idea")
        XCTAssertEqual(result.other, [.call(to: "warden")])
        XCTAssertEqual(result.problems, [.unknownItem("zz")])
        XCTAssertEqual(result.changes.map { $0.label(in: s, today: today) },
                       ["Done", "from 14:00", "→ Fri", "New", "Saved"])
    }

    func testUndoIsTheOldStore() {
        let before = store()
        let after = Schedule.apply([.delete(id: "a1")], to: before, now: now).store
        XCTAssertNil(after.item("a1"))
        XCTAssertNotNil(before.item("a1"))
    }

    func testMoveLabels() {
        var s = store()
        s.items[0].date = today.adding(days: 1)
        XCTAssertEqual(Change.moved(id: "a1", fromDate: today, fromTime: nil).label(in: s, today: today), "→ Tomorrow")
        s.items[0].date = today.adding(days: 20)
        XCTAssertEqual(Change.moved(id: "a1", fromDate: today, fromTime: nil).label(in: s, today: today), "→ 31/10")
    }

    func testRollover() {
        var s = store()
        s.items[0].date = day("2026-10-09")
        s.items[0].focus = true
        s.items[1].date = day("2026-10-10")
        s.items[1].done = true
        s.items[2].date = day("2026-10-15")
        let (rolled, moved) = Schedule.rollover(s, today: today)
        XCTAssertEqual(moved, ["a1"])
        XCTAssertEqual(rolled.item("a1")!.date, today)
        XCTAssertEqual(rolled.item("a1")!.time, time("11:30"))
        XCTAssertFalse(rolled.item("a1")!.focus)
        XCTAssertEqual(rolled.item("a2")!.date, day("2026-10-10"))
        XCTAssertEqual(rolled.item("a3")!.date, day("2026-10-15"))
    }

    func testTodayLayout() {
        var s = store()
        s.items[2].focus = true
        s.items[0].done = true
        s.items.append(Item(id: "a9", title: "Project meeting", date: day("2026-10-17"), time: time("16:00"), created: .now))
        s.items.append(Item(id: "a8", title: "Later thing", date: day("2026-10-20"), created: .now))
        let layout = TodayLayout(store: s, today: today)
        XCTAssertEqual(layout.focus.map(\.id), ["a3"])
        XCTAssertEqual(layout.also.map(\.id), ["a2", "a1"])
        XCTAssertEqual(layout.next?.id, "a9")
    }

    func testIDs() {
        var s = Store(nextID: 35)
        XCTAssertEqual(s.makeID("a"), "az")
        XCTAssertEqual(s.makeID("n"), "n10")
    }

    func testPromptItems() {
        var s = store()
        s.items.append(Item(id: "a7", title: "Far away", date: day("2026-12-01"), created: .now))
        let json = promptItems(s, today: today)
        XCTAssertTrue(json.contains("\"id\":\"a1\""))
        XCTAssertTrue(json.contains("\"tm\":\"11:30\""))
        XCTAssertTrue(json.contains("\"tm\":null"))
        XCTAssertFalse(json.contains("Far away"))
        let input = DecisionPrompt.input(now: now, timeZone: ist, store: s, places: ["hostel"], said: "say \"hi\"")
        XCTAssertTrue(input.hasPrefix("NOW: 2026-10-11T12:00 Sun (Asia/Kolkata)"))
        XCTAssertTrue(input.contains("PLACES: [\"hostel\"]"))
        XCTAssertTrue(input.hasSuffix("SAID: \"say \\\"hi\\\"\""))
    }
}
