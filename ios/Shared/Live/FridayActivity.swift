import ActivityKit
import Foundation

/// The "Friday on" Live Activity shown in the Dynamic Island while a session runs.
struct FridayActivityAttributes: ActivityAttributes {
    struct ContentState: Codable, Hashable {
        var startedAt: Date
        var source: String
    }
}
