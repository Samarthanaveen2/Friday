import XCTest
@testable import FridayCore

final class UsageTests: XCTestCase {
    let now = Date(timeIntervalSince1970: 1_760_000_000)

    func testHeadersAndTokensGivePercentages() {
        var u = Usage()
        let body = Data(#"{"choices":[],"usage":{"prompt_tokens":900,"completion_tokens":100,"total_tokens":1000}}"#.utf8)
        u.record(model: Models.groqCleanup, headers: ["x-ratelimit-limit-requests": "1000", "x-ratelimit-remaining-requests": "750"],
                 body: body, ok: true, now: now, day: "2026-10-12")
        let e = u.today(Models.groqCleanup, day: "2026-10-12")
        XCTAssertEqual(e.requests, 1)
        XCTAssertEqual(e.tokens, 1000)
        XCTAssertEqual(e.used, 0.25, accuracy: 0.001)   // requests 25% beats tokens 0.5%
        u.record(model: Models.groqCleanup, headers: [:], body: Data(#"{"usage":{"total_tokens":150000}}"#.utf8),
                 ok: true, now: now, day: "2026-10-12")
        XCTAssertEqual(u.today(Models.groqCleanup, day: "2026-10-12").used, 0.755, accuracy: 0.001)
    }

    func testNewDayStartsFreshAndAudioCounts() {
        var u = Usage()
        u.record(model: Models.whisper, headers: [:], body: nil, audioSeconds: 2880, ok: true, now: now, day: "2026-10-12")
        XCTAssertEqual(u.today(Models.whisper, day: "2026-10-12").used, 0.1, accuracy: 0.001)
        XCTAssertEqual(u.today(Models.whisper, day: "2026-10-13").used, 0)
        u.record(model: Models.whisper, headers: [:], body: nil, ok: false, now: now, day: "2026-10-13")
        XCTAssertEqual(u.today(Models.whisper, day: "2026-10-13").requests, 1)
        XCTAssertEqual(Usage.model(inRequest: Data(#"{"model":"qwen/qwen3.8-27b"}"#.utf8)), "qwen/qwen3.8-27b")
    }
}
