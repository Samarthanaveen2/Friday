import Foundation

/// Counts calls per provider so Friday switches to the backup *before* a free limit, and
/// cools a provider down after a 429/5xx (PLAN §4).
public struct Quota: Codable, Equatable, Sendable {
    public struct Limits: Sendable {
        public var perMinute: Int
        public var perDay: Int

        public init(perMinute: Int, perDay: Int) {
            self.perMinute = perMinute
            self.perDay = perDay
        }
    }

    /// Free-tier figures (verify in the consoles); Friday stops at 90 % of them.
    public static let limits: [String: Limits] = [
        "groq.whisper": Limits(perMinute: 20, perDay: 2_000),
        "groq.chat": Limits(perMinute: 30, perDay: 1_000),
        "groq.chat.backup": Limits(perMinute: 30, perDay: 1_000),
        "groq.chat.backup2": Limits(perMinute: 30, perDay: 1_000),
        "gemini.chat": Limits(perMinute: 15, perDay: 1_000),
    ]

    private var recent: [String: [Date]] = [:]
    private var daily: [String: Int] = [:]
    private var day: String = ""
    private var coolUntil: [String: Date] = [:]

    public init() {}

    public mutating func record(_ key: String, now: Date) {
        roll(now)
        recent[key, default: []].append(now)
        recent[key] = recent[key]!.filter { now.timeIntervalSince($0) < 60 }
        daily[key, default: 0] += 1
    }

    public mutating func coolDown(_ key: String, for seconds: TimeInterval, now: Date) {
        coolUntil[key] = now.addingTimeInterval(seconds)
    }

    public func available(_ key: String, now: Date) -> Bool {
        if let until = coolUntil[key], now < until { return false }
        guard let limit = Quota.limits[key] else { return true }
        let minute = (recent[key] ?? []).filter { now.timeIntervalSince($0) < 60 }.count
        let today = Quota.dayKey(now) == day ? (daily[key] ?? 0) : 0
        return Double(minute) < Double(limit.perMinute) * 0.9 && Double(today) < Double(limit.perDay) * 0.9
    }

    /// When a provider resting after a limit can be used again (nil if it isn't resting).
    public func restingUntil(_ key: String, now: Date) -> Date? {
        guard let until = coolUntil[key], now < until else { return nil }
        return until
    }

    private mutating func roll(_ now: Date) {
        let key = Quota.dayKey(now)
        if key != day {
            day = key
            daily = [:]
        }
    }

    static func dayKey(_ date: Date) -> String {
        String(Int(date.timeIntervalSince1970 / 86_400))
    }
}
