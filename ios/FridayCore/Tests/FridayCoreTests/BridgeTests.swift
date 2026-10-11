import Foundation
import XCTest
@testable import FridayCore

final class BridgeTests: XCTestCase {
    private let t = Date(timeIntervalSince1970: 1_000)

    private func request(_ id: String = "r1", doc: String? = "doc-A") -> KeyboardRequest {
        KeyboardRequest(id: id, kind: .stop, documentID: doc, context: "", tone: .asSaid, at: t)
    }

    private func result(_ id: String = "r1", text: String? = "Hello.") -> AppReply {
        AppReply(requestID: id, kind: .result, text: text, raw: "hello", at: t)
    }

    func testInsertsOnlyIntoTheSameBox() {
        XCTAssertEqual(KeyboardLogic.decide(reply: result(), pending: request(), currentDocument: "doc-A"), .insert("Hello."))
        XCTAssertEqual(KeyboardLogic.decide(reply: result(), pending: request(), currentDocument: "doc-B"), .pasteLast)
        XCTAssertEqual(KeyboardLogic.decide(reply: result(), pending: request(doc: nil), currentDocument: "doc-B"), .insert("Hello."))
    }

    func testStaleOrUnknownRepliesAreNotTyped() {
        XCTAssertEqual(KeyboardLogic.decide(reply: result("old"), pending: request(), currentDocument: "doc-A"), .pasteLast)
        XCTAssertEqual(KeyboardLogic.decide(reply: result(), pending: nil, currentDocument: "doc-A"), .pasteLast)
        XCTAssertEqual(KeyboardLogic.decide(reply: result(text: ""), pending: request(), currentDocument: "doc-A"), .ignore)
        let working = AppReply(requestID: "r1", kind: .working, at: t)
        XCTAssertEqual(KeyboardLogic.decide(reply: working, pending: request(), currentDocument: "doc-A"), .ignore)
    }

    func testRevertOnlyRightAfterTheInsert() {
        let ins = Insertion(text: " see you at 5.", raw: " see you at five", at: t)
        XCTAssertTrue(KeyboardLogic.canRevert(ins, contextBefore: "Okay, see you at 5."))
        XCTAssertFalse(KeyboardLogic.canRevert(ins, contextBefore: "Okay, see you at 5. Bye"))
        XCTAssertFalse(KeyboardLogic.canRevert(ins, contextBefore: nil))
        // iOS only showed the tail of a long insert.
        XCTAssertTrue(KeyboardLogic.canRevert(ins, contextBefore: "you at 5."))
        XCTAssertFalse(KeyboardLogic.canRevert(ins, contextBefore: "at 6."))
    }

    func testSessionLive() {
        let beat = AppBeat(at: t, micRunning: true, level: 0, inBackground: true, bestBackgroundSeconds: 0, lastPingSeen: 0, state: "holding")
        XCTAssertTrue(KeyboardLogic.sessionLive(beat: beat, now: t.addingTimeInterval(2)))
        XCTAssertFalse(KeyboardLogic.sessionLive(beat: beat, now: t.addingTimeInterval(4)))
        var off = beat
        off.state = "off"
        XCTAssertFalse(KeyboardLogic.sessionLive(beat: off, now: t))
        XCTAssertFalse(KeyboardLogic.sessionLive(beat: nil, now: t))
    }

    func testCodableAndContextLimit() throws {
        let r = KeyboardRequest(id: "x", kind: .start, documentID: nil, context: String(repeating: "a", count: 500), tone: .casual, at: t)
        XCTAssertEqual(r.context.count, 300)
        XCTAssertEqual(ProbeCodec.decode(KeyboardRequest.self, from: try ProbeCodec.encode(r)), r)
        let reply = AppReply(requestID: "x", kind: .failed, message: "Session ended — tap 🎤", at: t)
        XCTAssertEqual(ProbeCodec.decode(AppReply.self, from: try ProbeCodec.encode(reply)), reply)
    }

    func testLevelCodec() {
        XCTAssertEqual(LevelCodec.decode(LevelCodec.encode(0.42)), 0.42, accuracy: 0.0001)
        XCTAssertEqual(LevelCodec.decode(LevelCodec.encode(3)), 1)
        XCTAssertEqual(LevelCodec.decode(Data([1, 2])), 0)
    }
}
