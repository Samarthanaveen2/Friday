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
if CommandLine.arguments.count == 4, CommandLine.arguments[1] == "fill" {
    func load(_ path: String) throws -> [String: String] {
        try JSONDecoder().decode([String: String].self, from: Data(contentsOf: URL(fileURLWithPath: path)))
    }
    let whisper = try load(CommandLine.arguments[2]), device = try load(CommandLine.arguments[3])
    var filled: [String: String] = [:]
    for (id, text) in whisper {
        let result = Coverage.fill(primary: text, backup: device[id] ?? "")
        filled[id] = result.text
        for run in result.added { FileHandle.standardError.write(Data("\(id) added: \(run)\n".utf8)) }
    }
    let data = try JSONSerialization.data(withJSONObject: filled, options: [.sortedKeys, .prettyPrinted])
    print(String(decoding: data, as: UTF8.self))
    exit(0)
}

guard let key = ProcessInfo.processInfo.environment["GROQ_API_KEY"], !key.isEmpty else {
    print("GROQ_API_KEY not set; skipping evals.")
    exit(0)
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

    let ok = Set(c.expect.map(norm)).contains(norm(final))
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
