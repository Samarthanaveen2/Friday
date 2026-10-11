import Foundation
import XCTest
@testable import FridayCore

final class RequestTests: XCTestCase {
    func testWhisperBody() {
        let body = CloudRequests.whisperBody(wav: Data([1, 2, 3]), prompt: "Samartha, Kharagpur", boundary: "XYZ")
        let text = String(decoding: body, as: UTF8.self)
        XCTAssertTrue(text.hasPrefix("--XYZ\r\n"))
        XCTAssertTrue(text.contains("name=\"model\"\r\n\r\nwhisper-large-v3-turbo\r\n"))
        XCTAssertTrue(text.contains("name=\"language\"\r\n\r\nen\r\n"))
        XCTAssertTrue(text.contains("name=\"temperature\"\r\n\r\n0\r\n"))
        XCTAssertTrue(text.contains("name=\"prompt\"\r\n\r\nSamartha, Kharagpur\r\n"))
        XCTAssertTrue(text.contains("filename=\"audio.wav\"\r\nContent-Type: audio/wav\r\n\r\n"))
        XCTAssertTrue(text.hasSuffix("\r\n--XYZ--\r\n"))
        XCTAssertFalse(String(decoding: CloudRequests.whisperBody(wav: Data(), prompt: "", boundary: "B"), as: UTF8.self)
            .contains("name=\"prompt\""))
        let m4a = String(decoding: CloudRequests.whisperBody(wav: Data(), prompt: "", boundary: "B",
                                                             filename: "audio.m4a", contentType: "audio/mp4"), as: UTF8.self)
        XCTAssertTrue(m4a.contains("filename=\"audio.m4a\"\r\nContent-Type: audio/mp4\r\n\r\n"))
    }

    func testWhisperPromptAsksForEveryWord() {
        XCTAssertEqual(Dictation(dictionary: []).whisperPrompt(), Dictation.verbatimStyle)
        XCTAssertEqual(Dictation(dictionary: ["Samarth", "Groq"]).whisperPrompt(), Dictation.verbatimStyle + " Samarth, Groq")
    }

    func testChatBody() throws {
        let data = CloudRequests.chatBody(model: "m", system: "S", user: "U", maxTokens: 300, reasoningEffort: "low", json: true)
        let object = try XCTUnwrap(JSONSerialization.jsonObject(with: data) as? [String: Any])
        XCTAssertEqual(object["model"] as? String, "m")
        XCTAssertEqual(object["max_tokens"] as? Int, 300)
        XCTAssertEqual(object["reasoning_effort"] as? String, "low")
        XCTAssertEqual((object["response_format"] as? [String: String])?["type"], "json_object")
        let messages = try XCTUnwrap(object["messages"] as? [[String: String]])
        XCTAssertEqual(messages.map { $0["role"]! }, ["system", "user"])
        let plain = try XCTUnwrap(JSONSerialization.jsonObject(with: CloudRequests.chatBody(
            model: "m", system: "S", user: "U", maxTokens: 1, reasoningEffort: nil)) as? [String: Any])
        XCTAssertNil(plain["reasoning_effort"])
        XCTAssertNil(plain["include_reasoning"])
        let oss = try XCTUnwrap(JSONSerialization.jsonObject(with: CloudRequests.chatBody(
            model: "openai/gpt-oss-20b", system: "S", user: "U", maxTokens: 1, reasoningEffort: "low")) as? [String: Any])
        XCTAssertEqual(oss["include_reasoning"] as? Bool, false)
        XCTAssertNil(plain["response_format"])
    }

    func testReplies() {
        XCTAssertEqual(CloudRequests.whisperText(Data("{\"text\":\" hello there \"}".utf8)), "hello there")
        XCTAssertNil(CloudRequests.whisperText(Data("oops".utf8)))
        let chat = "{\"choices\":[{\"message\":{\"role\":\"assistant\",\"content\":\"<out>Hi.</out>\"}}]}"
        XCTAssertEqual(CloudRequests.chatText(Data(chat.utf8)), "<out>Hi.</out>")
        XCTAssertNil(CloudRequests.chatText(Data("{\"error\":{}}".utf8)))
    }

    func testMaxTokens() {
        XCTAssertEqual(CloudRequests.cleanupMaxTokens(for: "", model: "qwen/qwen3.8-27b"), 64)
        XCTAssertEqual(CloudRequests.cleanupMaxTokens(for: String(repeating: "word ", count: 100), model: "qwen/x"), 364)
        XCTAssertEqual(CloudRequests.cleanupMaxTokens(for: String(repeating: "word ", count: 5000), model: "qwen/x"), 2_000)
        XCTAssertEqual(CloudRequests.cleanupMaxTokens(for: "", model: "openai/gpt-oss-120b"), 1_024)
    }

    func testCleanupChain() throws {
        let chain = Models.groqCleanupChain
        XCTAssertEqual(chain.map(\.model), ["qwen/qwen3.8-27b", "openai/gpt-oss-120b", "openai/gpt-oss-20b"])
        XCTAssertEqual(chain.map(\.quota), ["groq.chat", "groq.chat.backup", "groq.chat.backup2"])
        XCTAssertEqual(Set(chain.map(\.quota)).count, chain.count, "each model needs its own counter")
        XCTAssertEqual(Set(chain.map(\.name)).count, chain.count)
        for step in chain {
            XCTAssertNotNil(Quota.limits[step.quota], step.quota)
        }

        // Backup 2 (gpt-oss-20b): low thinking, thinking hidden, room to think.
        let model = Models.groqCleanupBackup2
        XCTAssertEqual(Models.reasoningEffort(for: model), "low")
        XCTAssertEqual(CloudRequests.cleanupMaxTokens(for: "", model: model), 1_024)
        let body = try XCTUnwrap(JSONSerialization.jsonObject(with: CloudRequests.chatBody(
            model: model, system: "S", user: "U", maxTokens: 9,
            reasoningEffort: Models.reasoningEffort(for: model))) as? [String: Any])
        XCTAssertEqual(body["model"] as? String, "openai/gpt-oss-20b")
        XCTAssertEqual(body["reasoning_effort"] as? String, "low")
        XCTAssertEqual(body["include_reasoning"] as? Bool, false)

        // gpt-oss rejects "none"; qwen gets it; unknown models get no reasoning field at all.
        XCTAssertEqual(Models.reasoningEffort(for: Models.groqCleanup), "none")
        XCTAssertNil(Models.reasoningEffort(for: "llama-3.3-70b-versatile"))
        let qwen = try XCTUnwrap(JSONSerialization.jsonObject(with: CloudRequests.chatBody(
            model: Models.groqCleanup, system: "S", user: "U", maxTokens: 9,
            reasoningEffort: Models.reasoningEffort(for: Models.groqCleanup))) as? [String: Any])
        XCTAssertNil(qwen["include_reasoning"])
    }

    func testOutcomes() {
        XCTAssertEqual(CallOutcome.from(status: 200), .ok)
        XCTAssertEqual(CallOutcome.from(status: 429), .useBackup(coolDown: 60))
        XCTAssertEqual(CallOutcome.from(status: 429, body: "Rate limit reached ... on tokens per day (TPD)"), .useBackup(coolDown: 3_600))
        XCTAssertEqual(CallOutcome.from(status: 429, body: """
            {"error":{"message":"Rate limit reached for model `openai/gpt-oss-20b` in organization `org_x` service tier \
            `on_demand` on requests per day (RPD): Limit 1000, Used 1000, Requested 1.","type":"requests","code":"rate_limit_exceeded"}}
            """), .useBackup(coolDown: 3_600))
        XCTAssertEqual(CallOutcome.from(status: 429, body: "Rate limit reached ... on tokens per minute (TPM)"), .useBackup(coolDown: 60))
        XCTAssertEqual(CallOutcome.from(status: 503), .useBackup(coolDown: 20))
        XCTAssertEqual(CallOutcome.from(status: 401), .badKey)
        XCTAssertEqual(CallOutcome.from(status: 400), .failed)
    }
}

final class QuotaTests: XCTestCase {
    func testStopsBeforeTheMinuteLimit() {
        var q = Quota()
        let t = Date(timeIntervalSince1970: 1_000_000)
        for i in 0..<17 { q.record("groq.whisper", now: t.addingTimeInterval(Double(i))) }
        XCTAssertTrue(q.available("groq.whisper", now: t.addingTimeInterval(20)))
        q.record("groq.whisper", now: t.addingTimeInterval(18))
        XCTAssertFalse(q.available("groq.whisper", now: t.addingTimeInterval(20)))
        XCTAssertTrue(q.available("groq.whisper", now: t.addingTimeInterval(90)))
        XCTAssertTrue(q.available("unknown.key", now: t))
    }

    func testCoolDown() {
        var q = Quota()
        let t = Date(timeIntervalSince1970: 1_000_000)
        q.coolDown("groq.chat", for: 60, now: t)
        XCTAssertFalse(q.available("groq.chat", now: t.addingTimeInterval(30)))
        XCTAssertTrue(q.available("groq.chat", now: t.addingTimeInterval(61)))
    }

    func testDailyLimitRestsOnlyThatModel() {
        // A "per day" 429 on the main model rests it for an hour; the backups stay usable.
        var q = Quota()
        let t = Date(timeIntervalSince1970: 1_000_000)
        guard case .useBackup(let seconds) = CallOutcome.from(status: 429, body: "on tokens per day (TPD)") else {
            return XCTFail("expected useBackup")
        }
        q.coolDown("groq.chat", for: seconds, now: t)
        XCTAssertFalse(q.available("groq.chat", now: t.addingTimeInterval(1_800)))
        XCTAssertTrue(q.available("groq.chat.backup", now: t.addingTimeInterval(1_800)))
        XCTAssertTrue(q.available("groq.chat.backup2", now: t.addingTimeInterval(1_800)))
        q.coolDown("groq.chat.backup2", for: seconds, now: t)
        XCTAssertFalse(q.available("groq.chat.backup2", now: t.addingTimeInterval(1_800)))
        XCTAssertTrue(q.available("groq.chat", now: t.addingTimeInterval(3_601)))
        // Backup 2 has its own request count too.
        for i in 0..<27 { q.record("groq.chat.backup", now: t.addingTimeInterval(4_000 + Double(i))) }
        XCTAssertFalse(q.available("groq.chat.backup", now: t.addingTimeInterval(4_030)))
        XCTAssertTrue(q.available("groq.chat.backup2", now: t.addingTimeInterval(4_030)))
    }

    func testDailyResets() throws {
        var q = Quota()
        let t = Date(timeIntervalSince1970: 1_000_000)
        for i in 0..<900 { q.record("groq.chat", now: t.addingTimeInterval(Double(i) * 3)) }
        XCTAssertFalse(q.available("groq.chat", now: t.addingTimeInterval(3_000)))
        XCTAssertTrue(q.available("groq.chat", now: t.addingTimeInterval(86_400 * 2)))
        let data = try JSONEncoder().encode(q)
        XCTAssertEqual(try JSONDecoder().decode(Quota.self, from: data), q)
    }
}

final class RaceTests: XCTestCase {
    func testCloudWins() {
        XCTAssertEqual(SpeechRace.pick(cloud: "Hello there", device: "hello their", heardSpeech: true), .cloud("Hello there"))
    }

    func testDeviceWhenCloudLateOrMissing() {
        XCTAssertEqual(SpeechRace.pick(cloud: nil, device: "hello", heardSpeech: true), .device("hello"))
        XCTAssertEqual(SpeechRace.pick(cloud: "  ", device: "hello", heardSpeech: true), .device("hello"))
    }

    func testPhantomTextIsDropped() {
        XCTAssertEqual(SpeechRace.pick(cloud: "Thank you for watching.", device: nil, heardSpeech: false), .nothing)
        XCTAssertEqual(SpeechRace.pick(cloud: "Thanks for watching!", device: "", heardSpeech: true), .nothing)
        XCTAssertEqual(SpeechRace.pick(cloud: nil, device: nil, heardSpeech: true), .nothing)
    }

    func testTimingLine() {
        let t = Timings(speechMs: 310, cleanupMs: 240, totalMs: 640, speechBy: .groq, cleanupBy: .groq)
        XCTAssertEqual(t.line, "Speech 310 ms (Groq) · cleanup 240 ms (Groq) · total 640 ms")
        let offline = Timings(speechMs: nil, cleanupMs: 12, totalMs: 90, speechBy: .device, cleanupBy: .rules)
        XCTAssertEqual(offline.line, "Speech (phone) · cleanup 12 ms (rules) · total 90 ms")
    }
}
