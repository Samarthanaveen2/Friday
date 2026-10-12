import XCTest
@testable import FridayCore

final class BoxesTests: XCTestCase {
    let ist = TimeZone(identifier: "Asia/Kolkata")!
    let t0 = Date(timeIntervalSince1970: 1_760_000_000)

    func testAddEditPinOrderDelete() {
        var s = Store()
        let a = s.addNote(text: "first", now: t0)
        let b = s.addNote(title: "Wifi", text: "pass on the board", now: t0.addingTimeInterval(10))
        XCTAssertEqual(s.boxesInOrder.map(\.id), [b, a])
        s.editNote(a, title: "  ", text: "first, edited", now: t0.addingTimeInterval(20))
        XCTAssertNil(s.note(a)?.title)
        XCTAssertEqual(s.boxesInOrder.map(\.id), [a, b])
        s.togglePin(b)
        XCTAssertEqual(s.boxesInOrder.map(\.id), [b, a])
        s.appendToNote(b, text: " also ask the warden ", now: t0.addingTimeInterval(30))
        XCTAssertEqual(s.note(b)?.text, "pass on the board\n\nalso ask the warden")
        s.deleteNote(a)
        XCTAssertNil(s.note(a))
        XCTAssertTrue(Note(id: "x", title: " ", text: "\n", created: t0).isBlank)
    }

    func testRemindersTodayAndSearch() {
        var s = Store()
        let a = s.addNote(title: "Poster", text: "print 40", now: t0)
        let b = s.addNote(text: "call mom", now: t0)
        let today = TimeRules.today(now: t0, in: ist)
        s.setReminder(a, t0.addingTimeInterval(3600))
        s.setReminder(b, t0.addingTimeInterval(3 * 86_400))
        XCTAssertEqual(s.reminders(on: today, in: ist).map(\.id), [a])
        XCTAssertEqual(s.search("POSTER print").map(\.id), [a])
        XCTAssertEqual(s.search("mom").map(\.id), [b])
        XCTAssertEqual(s.search("  "), [])
    }

    func testSavedFileRoundTripsAndOldFilesLoad() throws {
        var s = Store()
        let id = s.addNote(title: "T", text: "body", now: t0)
        s.setReminder(id, t0)
        s.togglePin(id)
        s.setColor(id, "sage")
        let data = try XCTUnwrap(StoreCodec.encode(s))
        XCTAssertEqual(StoreCodec.decode(data), s)
        // A file saved before titles, pins and reminders existed.
        let old = #"{"items":[],"notes":[{"id":"n1","text":"hi","created":"2026-10-01T10:00:00Z"}],"nextID":2}"#
        let loaded = try XCTUnwrap(StoreCodec.decode(Data(old.utf8)))
        XCTAssertEqual(loaded.notes.first?.text, "hi")
        XCTAssertEqual(loaded.notes.first?.pinned, false)
        XCTAssertNil(loaded.notes.first?.color)
        XCTAssertNil(StoreCodec.decode(Data("not json".utf8)))
        XCTAssertTrue(StoreCodec.backupName(for: t0, in: ist).hasPrefix("store-backup-"))
    }
}
