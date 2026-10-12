import ActivityKit
import Foundation

/// The "Friday on" Live Activity shown in the Dynamic Island while a session runs.
struct FridayActivityAttributes: ActivityAttributes {
    struct ContentState: Codable, Hashable {
        var startedAt: Date
        var source: String
        /// "on" (default), "listening", "thinking" or "done". Optional so older states still decode.
        var phase: String?
        /// What Friday did ("Added ‘Meet Rahul’ · Tue 20:00"), shown while done.
        var message: String?
    }
}
