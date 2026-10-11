import Foundation

/// Messages the install probe passes between the app and the keyboard through the App Group.
public enum ProbeFile {
    public static let app = "probe-app.json"
    public static let keyboard = "probe-keyboard.json"
    public static let intent = "probe-intent.json"
}

public enum ProbeNotice {
    public static let appBeat = "com.samarth.friday.probe.app"
    public static let keyboardPing = "com.samarth.friday.probe.keyboard"
}

/// Written by the app every second while it runs.
public struct AppBeat: Codable, Equatable, Sendable {
    public var at: Date
    public var micRunning: Bool
    public var level: Float
    public var inBackground: Bool
    /// Longest stretch the mic has stayed live with the app in the background.
    public var bestBackgroundSeconds: Int
    /// Last keyboard ping the app saw (echoed back so the keyboard can prove a round trip).
    public var lastPingSeen: Int
    /// The session state ("off", "holding", "dictating", "needsRestart").
    public var state: String?

    public init(at: Date, micRunning: Bool, level: Float, inBackground: Bool, bestBackgroundSeconds: Int,
                lastPingSeen: Int, state: String? = nil) {
        self.at = at
        self.micRunning = micRunning
        self.level = level
        self.inBackground = inBackground
        self.bestBackgroundSeconds = bestBackgroundSeconds
        self.lastPingSeen = lastPingSeen
        self.state = state
    }
}

/// Written by "Start Friday" wherever it runs (app or widget extension).
public struct IntentRun: Codable, Equatable, Sendable {
    public enum Place: String, Codable, Sendable {
        /// Ran in the app process: can start the mic without opening Friday.
        case app
        /// Ran in the widget extension: had to open Friday to start the mic.
        case widget
    }

    public var at: Date
    public var ranIn: Place
    public var micStarted: Bool
    public var appWasActive: Bool

    public init(at: Date, ranIn: Place, micStarted: Bool, appWasActive: Bool) {
        self.at = at
        self.ranIn = ranIn
        self.micStarted = micStarted
        self.appWasActive = appWasActive
    }
}

/// Written by the keyboard whenever it appears or the user taps Ping.
public struct KeyboardBeat: Codable, Equatable, Sendable {
    public var at: Date
    public var fullAccess: Bool
    public var ping: Int
    public var roundTrip: Bool

    public init(at: Date, fullAccess: Bool, ping: Int, roundTrip: Bool) {
        self.at = at
        self.fullAccess = fullAccess
        self.ping = ping
        self.roundTrip = roundTrip
    }
}

public enum ProbeCodec {
    public static func encode<T: Encodable>(_ value: T) throws -> Data {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .secondsSince1970
        return try encoder.encode(value)
    }

    public static func decode<T: Decodable>(_ type: T.Type, from data: Data) -> T? {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .secondsSince1970
        return try? decoder.decode(type, from: data)
    }
}

/// "now", "8s ago", "3m ago", "2h ago", "4d ago".
public func ageLabel(_ seconds: TimeInterval) -> String {
    let s = max(0, Int(seconds))
    switch s {
    case ..<2: return "now"
    case ..<60: return "\(s)s ago"
    case ..<3_600: return "\(s / 60)m ago"
    case ..<86_400: return "\(s / 3_600)h ago"
    default: return "\(s / 86_400)d ago"
    }
}
