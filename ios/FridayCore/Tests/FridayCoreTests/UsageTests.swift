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

final class LimitHitTests: XCTestCase {
    func testTokensPerDay() {
        let body = #"{"error":{"message":"Rate limit reached for model `qwen/qwen3.8-27b` in organization `org_x` service tier `on_demand` on tokens per day (TPD): Limit 500000, Used 499120, Requested 1830. Please try again in 9m12.5s. Need more tokens?","type":"tokens","code":"rate_limit_exceeded"}}"#
        let hit = Usage.limitHit(in: body)
        XCTAssertEqual(hit?.kind, "tokens per day")
        XCTAssertEqual(hit?.limit, 500_000)
        XCTAssertEqual(hit?.used, 499_120)
        XCTAssertEqual(hit?.retryAfter ?? 0, 552.5, accuracy: 0.01)
        XCTAssertEqual(CallOutcome.from(status: 429, body: body), .useBackup(coolDown: 554.5))
    }

    func testTokensPerMinuteAndRequestsPerDay() {
        let tpm = "Rate limit reached for model `x` on tokens per minute (TPM): Limit 6000, Used 5800, Requested 900. Please try again in 7s."
        XCTAssertEqual(Usage.limitHit(in: tpm), Usage.LimitHit(kind: "tokens per minute", limit: 6000, used: 5800, retryAfter: 7))
        let rpd = "Rate limit reached on requests per day (RPD): Limit 1000, Used 1000, Requested 1. Please try again in 1h2m3s."
        XCTAssertEqual(Usage.limitHit(in: rpd)?.retryAfter, 3723)
    }

    func testRecordStoresTheLimitAndFillsTheBar() {
        var usage = Usage()
        let body = "on tokens per day (TPD): Limit 200000, Used 199000, Requested 3000. Please try again in 5m."
        usage.record(model: "m", headers: [:], body: Data(body.utf8), ok: false, now: .now, day: "2026-10-12")
        let today = usage.today("m", day: "2026-10-12")
        XCTAssertEqual(today.limitKind, "tokens per day")
        XCTAssertEqual(today.used, 0.995, accuracy: 0.001)
    }

    func testGarbageIsNil() {
        XCTAssertNil(Usage.limitHit(in: "Internal server error"))
        XCTAssertEqual(CallOutcome.from(status: 429, body: "slow down"), .useBackup(coolDown: 60))
    }
}
