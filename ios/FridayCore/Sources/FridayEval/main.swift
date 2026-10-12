import Foundation
#if canImport(FoundationNetworking)
import FoundationNetworking
#endif
import FridayCore

// Usage: GROQ_API_KEY=... swift run FridayEval path/to/dictation.jsonl
// Same request, reply parsing, guard and final text as the app's Cleaner (Groq step).
// Fails (exit 1) if fewer than 90 % of cases pass, so a bad prompt or model can't ship.

struct Case: Decodable {
    let id: Int
    let context: String
    let say: String
    let expect: [String]
    /// Long free-form cases: pass if every `must` phrase is kept and no `mustNot` phrase is left.
    var must: [String]? = nil
    var mustNot: [String]? = nil
}

func norm(_ text: String) -> String {
    var t = text.lowercased().replacingOccurrences(of: "’", with: "'")
    t = t.replacingOccurrences(of: "[ \\t]+", with: " ", options: .regularExpression)
    t = t.replacingOccurrences(of: "\\s*\\n\\s*", with: "\n", options: .regularExpression)
    t = t.trimmingCharacters(in: .whitespacesAndNewlines)
    while let last = t.last, ".!".contains(last) { t.removeLast() }
    return t
}

func post(_ body: Data, key: String) async -> (Int, Data) {
    var request = URLRequest(url: Models.groqBase.appendingPathComponent("chat/completions"))
    request.httpMethod = "POST"
    request.httpBody = body
    request.timeoutInterval = 40
    request.setValue("Bearer \(key)", forHTTPHeaderField: "Authorization")
    request.setValue("application/json", forHTTPHeaderField: "Content-Type")
    request.setValue("FridayEval/1.0", forHTTPHeaderField: "User-Agent")
    return await withCheckedContinuation { continuation in
        URLSession.shared.dataTask(with: request) { data, response, _ in
            continuation.resume(returning: ((response as? HTTPURLResponse)?.statusCode ?? 0, data ?? Data()))
        }.resume()
    }
}

// Speech bench helper: `FridayEval fill whisper.json iphone.json` prints the app's gap-filled text
// (Coverage.fill) for each clip as JSON, so the bench can score it.
func load(_ path: String) throws -> [String: String] {
    try JSONDecoder().decode([String: String].self, from: Data(contentsOf: URL(fileURLWithPath: path)))
}
func printJSON(_ map: [String: String]) throws {
    let data = try JSONSerialization.data(withJSONObject: map, options: [.sortedKeys, .prettyPrinted])
    print(String(decoding: data, as: UTF8.self))
}

if CommandLine.arguments.count == 4, CommandLine.arguments[1] == "fill" {
    let whisper = try load(CommandLine.arguments[2]), device = try load(CommandLine.arguments[3])
    var filled: [String: String] = [:]
    for (id, text) in whisper {
        let result = Coverage.fill(primary: text, backup: device[id] ?? "")
        filled[id] = result.text
        for run in result.added { FileHandle.standardError.write(Data("\(id) added: \(run)\n".utf8)) }
    }
    try printJSON(filled)
    exit(0)
}

guard let key = ProcessInfo.processInfo.environment["GROQ_API_KEY"], !key.isEmpty else {
    print("GROQ_API_KEY not set; skipping evals.")
    exit(0)
}
// Speech bench helper: `FridayEval clean transcripts.json` runs each transcript through the app's
// cleanup (Groq main model, guard, final text) and prints the typed text as JSON, so the bench can
// check the cleanup never drops what was said. Falls back to the rules text like the app would.
if CommandLine.arguments.count == 3, CommandLine.arguments[1] == "clean" {
    let dictation = Dictation(dictionary: [])
    var typed: [String: String] = [:]
    for (id, text) in try load(CommandLine.arguments[2]).sorted(by: { $0.key < $1.key }) {
        let prepared = dictation.prepare(text)
        let body = CloudRequests.chatBody(model: Models.groqCleanup, system: Dictation.systemPrompt,
                                          user: dictation.aiMessage(prepared: prepared, context: "", tone: .asSaid),
                                          maxTokens: CloudRequests.cleanupMaxTokens(for: prepared),
                                          reasoningEffort: Models.reasoningEffort(for: Models.groqCleanup))
        var (status, data) = await post(body, key: key)
        if status == 429 {
            try await Task.sleep(nanoseconds: 15_000_000_000)
            (status, data) = await post(body, key: key)
        }
        let reply = status == 200 ? CloudRequests.chatText(data) : nil
        let accepted = reply.flatMap(extractOut).map { CleanupGuard.check(output: $0, transcript: prepared).accepted } ?? false
        typed[id] = dictation.finish(prepared: prepared, aiOutput: reply, context: "")
        FileHandle.standardError.write(Data("\(id): \(status) \(accepted ? "AI" : "rules")\n".utf8))
        // Long transcripts are ~1.5k tokens each; stay under Groq's free per-minute token limit.
        try await Task.sleep(nanoseconds: 12_000_000_000)
    }
    try printJSON(typed)
    exit(0)
}

// Decision evals: `FridayEval decide ios/evals/decision.jsonl`. Each case: what was said, calendar
// events ("d" as days from today), the action kinds that must appear ("cancel_event:e2") and must not.
struct DecisionCase: Decodable {
    struct Event: Decodable { let id: String; let t: String; let d: String; let tm: String? }
    let id: Int
    let say: String
    let events: [Event]
    let expect: [String]
    let forbid: [String]
    /// Box texts; they get ids n1, n2… in order.
    var boxes: [String]? = nil
}

func kinds(_ action: DecisionAction) -> [String] {
    switch action {
    case .addEvent: ["add_event"]
    case .moveEvent(let id, _, _): ["move_event", "move_event:\(id)"]
    case .cancelEvent(let id): ["cancel_event", "cancel_event:\(id)"]
    case .add: ["add"]
    case .note: ["note"]
    case .delete(let id): ["delete", "delete:\(id)"]
    case .move(let id, _, _): ["move", "move:\(id)"]
    case .deleteBox(let id): ["delete_box", "delete_box:\(id)"]
    case .editBox(let id, _, _): ["edit_box", "edit_box:\(id)"]
    case .answer: ["answer"]
    default: ["other"]
    }
}

if CommandLine.arguments.count == 3, CommandLine.arguments[1] == "decide" {
    let zone = TimeZone(identifier: "Asia/Kolkata")!
    let now = Date.now
    let today = TimeRules.today(now: now, in: zone)
    let cases = try String(contentsOfFile: CommandLine.arguments[2], encoding: .utf8)
        .split(separator: "\n").map { try JSONDecoder().decode(DecisionCase.self, from: Data($0.utf8)) }
    var passed = 0
    for c in cases {
        let events = c.events.map { e in
            CalendarEvent(id: e.id, title: e.t, date: today.adding(days: Int(e.d) ?? 0), time: e.tm.flatMap(TimeOfDay.init),
                          end: nil, calendar: "Personal")
        }
        var store = Store()
        for text in (c.boxes ?? []).reversed() { store.addNote(text: text, now: now) }
        let input = DecisionPrompt.input(now: now, timeZone: zone, store: store, places: [], said: c.say, events: events)
        let body = CloudRequests.chatBody(model: Models.groqDecision, system: DecisionPrompt.system, user: input,
                                          maxTokens: 2_500, reasoningEffort: Models.reasoningEffort(for: Models.groqDecision), json: true)
        var (status, data) = await post(body, key: key)
        if status == 429 {
            if String(decoding: data, as: UTF8.self).contains("per day") {
                print("::warning::Groq daily limit reached; decision evals skipped.")
                exit(0)
            }
            try await Task.sleep(nanoseconds: 15_000_000_000)
            (status, data) = await post(body, key: key)
        }
        let reply = CloudRequests.chatText(data) ?? ""
        let actions = DecisionParser.parse(reply, said: c.say, now: now, timeZone: zone).actions
        let got = Set(actions.flatMap(kinds))
        let ok = c.expect.allSatisfy(got.contains) && !c.forbid.contains(where: got.contains)
        if ok { passed += 1 }
        print("\(ok ? "PASS" : "FAIL") #\(c.id) \(c.say.debugDescription) -> \(got.sorted())")
        if !ok { print("      reply: \(String(reply.prefix(300)).debugDescription)") }
        try await Task.sleep(nanoseconds: 3_000_000_000)
    }
    print("\n\(passed)/\(cases.count) decision cases passed")
    exit(Double(passed) >= Double(cases.count) * 0.85 ? 0 : 1)
}

let path = CommandLine.arguments.dropFirst().first ?? "ios/evals/dictation.jsonl"
let cases = try String(contentsOfFile: path, encoding: .utf8)
    .split(separator: "\n")
    .map { try JSONDecoder().decode(Case.self, from: Data($0.utf8)) }

let dictation = Dictation(dictionary: ["Samartha", "Kharagpur", "Arjun", "Priya"])
let model = Models.groqCleanup
print("Model: \(model)\n")
var passed = 0
var usedAI = 0
var times: [Double] = []

for c in cases {
    let prepared = dictation.prepare(c.say)
    let body = CloudRequests.chatBody(model: model, system: Dictation.systemPrompt,
                                      user: dictation.aiMessage(prepared: prepared, context: c.context, tone: .asSaid),
                                      maxTokens: CloudRequests.cleanupMaxTokens(for: prepared),
                                      reasoningEffort: Models.reasoningEffort(for: model))
    var status = 0
    var data = Data()
    let start = Date()
    for _ in 0..<4 {
        (status, data) = await post(body, key: key)
        if status != 429 { break }
        // Daily allowance used up: retrying only burns more. Skip instead of failing.
        if String(decoding: data, as: UTF8.self).contains("per day") {
            print("Groq daily limit reached — evals skipped, run again tomorrow.")
            print("::warning::Groq daily limit reached; dictation evals skipped (\(passed) passed before it).")
            exit(0)
        }
        try await Task.sleep(nanoseconds: 8_000_000_000)
    }
    times.append(Date().timeIntervalSince(start) * 1000)

    let reply = CloudRequests.chatText(data)
    let extracted = reply.flatMap(extractOut)
    let accepted = extracted.map { CleanupGuard.check(output: $0, transcript: prepared).accepted } ?? false
    let final = dictation.finish(prepared: prepared, aiOutput: reply, context: c.context)
    let why: String
    if status != 200 { why = "HTTP \(status): \(String(decoding: data.prefix(160), as: UTF8.self))" }
    else if reply == nil { why = "no content: \(String(decoding: data.prefix(200), as: UTF8.self))" }
    else if extracted == nil { why = "unreadable reply" }
    else if !accepted { why = "guard rejected" }
    else { why = "" }
    if accepted { usedAI += 1 }

    let lower = final.lowercased()
    let ok = c.must != nil || c.mustNot != nil
        ? (c.must ?? []).allSatisfy { lower.contains($0.lowercased()) }
            && !(c.mustNot ?? []).contains { lower.contains($0.lowercased()) }
        : Set(c.expect.map(norm)).contains(norm(final))
    if ok { passed += 1 }
    print("\(ok ? "PASS" : "FAIL") #\(c.id) [\(accepted ? "AI" : "rules")] \(c.say.debugDescription)")
    if !ok || !accepted {
        print("      final: \(final.debugDescription)")
        print("     expect: \(c.expect[0].debugDescription)")
        if !why.isEmpty { print("        why: \(why)") }
        if let reply { print("      reply: \(String(reply.prefix(200)).debugDescription)") }
    }
    try await Task.sleep(nanoseconds: 2_200_000_000)
}

let median = times.sorted()[times.count / 2]
print("\n\(passed)/\(cases.count) passed · AI used \(usedAI)/\(cases.count) · median \(Int(median)) ms")
exit(Double(passed) >= Double(cases.count) * 0.9 ? 0 : 1)
