import Foundation

/// How much of each model's free daily allowance is used, for Settings → AI usage.
/// Requests come from Groq's own rate-limit headers (so they include every app or test using
/// the same key); tokens and audio seconds are counted here from each reply.
public struct ModelUsage: Codable, Equatable, Sendable {
    public var model: String
    /// Local day these counters belong to ("2026-10-12").
    public var day: String
    public var requests: Int = 0
    public var tokens: Int = 0
    public var audioSeconds: Double = 0
    /// From Groq's headers: requests allowed per day and left today.
    public var requestLimit: Int?
    public var requestsLeft: Int?
    public var lastUsed: Date?
    public var lastOK = true
    /// The limit Groq said was hit today ("tokens per day"), with its size and how much was used.
    /// Groq counts every app or test using the key, so this is the true picture.
    public var limitKind: String?
    public var limitValue: Int?
    public var limitUsed: Int?

    public init(model: String, day: String) {
        self.model = model
        self.day = day
    }

    /// Share of today's allowance used, 0...1: whichever of requests, tokens or audio is highest.
    public var used: Double {
        var parts: [Double] = []
        if let limit = requestLimit, limit > 0, let left = requestsLeft {
            parts.append(Double(limit - left) / Double(limit))
        } else if let limit = Usage.requestsPerDay[model] {
            parts.append(Double(requests) / Double(limit))
        }
        if let limit = Usage.tokensPerDay[model] { parts.append(Double(tokens) / Double(limit)) }
        if let limit = Usage.audioSecondsPerDay[model] { parts.append(audioSeconds / limit) }
        if let limit = limitValue, limit > 0, let usedSoFar = limitUsed, limitKind?.hasSuffix("per day") == true {
            parts.append(Double(usedSoFar) / Double(limit))
        }
        return min(1, max(0, parts.max() ?? 0))
    }
}

public struct Usage: Codable, Equatable, Sendable {
    public var models: [String: ModelUsage] = [:]
    /// The model whose text was used for the last dictation's cleanup ("rules", "apple" when no cloud).
    public var lastCleanup: String?
    public var lastSpeech: String?

    public init() {}

    /// Groq free tier, per model per day (console.groq.com/docs/rate-limits, Oct 2026).
    public static let tokensPerDay: [String: Int] = [
        Models.groqCleanup: 200_000, Models.groqCleanupBackup: 200_000, Models.groqCleanupBackup2: 200_000,
    ]
    public static let requestsPerDay: [String: Int] = [
        Models.groqCleanup: 1_000, Models.groqCleanupBackup: 1_000, Models.groqCleanupBackup2: 1_000,
        Models.whisper: 2_000,
    ]
    public static let audioSecondsPerDay: [String: Double] = [Models.whisper: 28_800]

    /// Records one call: Groq's headers (lowercased names), the reply body, and for speech the audio length.
    public mutating func record(model: String, headers: [String: String], body: Data?, audioSeconds: Double? = nil,
                                ok: Bool, now: Date, day: String) {
        var entry = models[model].flatMap { $0.day == day ? $0 : nil } ?? ModelUsage(model: model, day: day)
        entry.requests += 1
        entry.lastUsed = now
        entry.lastOK = ok
        if let limit = headers["x-ratelimit-limit-requests"].flatMap(Int.init) { entry.requestLimit = limit }
        if let left = headers["x-ratelimit-remaining-requests"].flatMap(Int.init) { entry.requestsLeft = left }
        if let body, let tokens = Usage.tokens(in: body) { entry.tokens += tokens }
        if let audioSeconds { entry.audioSeconds += audioSeconds }
        if !ok, let body, let hit = Usage.limitHit(in: String(decoding: body, as: UTF8.self)) {
            entry.limitKind = hit.kind
            entry.limitValue = hit.limit
            entry.limitUsed = hit.used
        }
        models[model] = entry
    }

    /// What a Groq 429 says: "Rate limit reached for model `x` … on tokens per day (TPD):
    /// Limit 500000, Used 499120, Requested 1830. Please try again in 9m12.5s."
    public struct LimitHit: Equatable, Sendable {
        /// "tokens per day", "requests per minute", "audio seconds per hour"…
        public var kind: String
        public var limit: Int?
        public var used: Int?
        public var retryAfter: TimeInterval?
    }

    public static func limitHit(in body: String) -> LimitHit? {
        guard let kind = Rx.firstMatch(body, "(tokens|requests|audio seconds) per (minute|hour|day)") else { return nil }
        func number(_ label: String) -> Int? {
            Rx.firstMatch(body, label + ":?\\s*\\d+").flatMap { Int($0.filter(\.isNumber)) }
        }
        var retry: TimeInterval?
        if let wait = Rx.firstMatch(body, "try again in\\s*(?:\\d+(?:\\.\\d+)?[hms])+") {
            var total = 0.0
            for part in Rx.matches(wait, "\\d+(?:\\.\\d+)?[hms]") {
                let value = Double(part.dropLast()) ?? 0
                total += value * (part.hasSuffix("h") ? 3600 : part.hasSuffix("m") ? 60 : 1)
            }
            retry = total
        }
        return LimitHit(kind: kind.lowercased(), limit: number("Limit"), used: number("Used"), retryAfter: retry)
    }

    /// Today's entry for a model (zero if it hasn't been used today).
    public func today(_ model: String, day: String) -> ModelUsage {
        models[model].flatMap { $0.day == day ? $0 : nil } ?? ModelUsage(model: model, day: day)
    }

    /// `usage.total_tokens` from an OpenAI-style chat reply.
    static func tokens(in body: Data) -> Int? {
        guard let object = (try? JSONSerialization.jsonObject(with: body)) as? [String: Any],
              let usage = object["usage"] as? [String: Any] else { return nil }
        return usage["total_tokens"] as? Int
    }

    /// The `model` field of a chat request body.
    public static func model(inRequest body: Data?) -> String? {
        guard let body, let object = (try? JSONSerialization.jsonObject(with: body)) as? [String: Any] else { return nil }
        return object["model"] as? String
    }

    public static func dayKey(_ date: Date, in timeZone: TimeZone) -> String {
        Day(date, in: timeZone).description
    }
}
