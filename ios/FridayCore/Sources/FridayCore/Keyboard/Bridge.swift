import Foundation

/// Messages between the Friday Keyboard and the app, passed as JSON files in the App Group
/// plus a Darwin notification (PLAN §8). The keyboard never records or calls the network;
/// it only asks the app and inserts what comes back.
public enum BridgeFile {
    public static let request = "kb-request.json"
    public static let reply = "app-reply.json"
    /// Last text produced, for "Paste last" when an insert couldn't happen.
    public static let last = "last-insert.json"
    /// 4-byte float, the live mic level while dictating (read ~20×/s by the keyboard).
    public static let level = "level.bin"
}

public enum BridgeNotice {
    public static let request = "com.samarth.friday.kb.request"
    public static let reply = "com.samarth.friday.app.reply"
}

public struct KeyboardRequest: Codable, Equatable, Sendable {
    public enum Kind: String, Codable, Sendable { case start, stop, cancel }

    public var id: String
    public var kind: Kind
    /// The text field this dictation is for; the result is only inserted into the same one.
    public var documentID: String?
    /// Up to 300 characters before the cursor, so the text continues naturally.
    public var context: String
    public var tone: Tone
    public var at: Date

    public init(id: String, kind: Kind, documentID: String?, context: String, tone: Tone, at: Date) {
        self.id = id
        self.kind = kind
        self.documentID = documentID
        self.context = String(context.suffix(300))
        self.tone = tone
        self.at = at
    }
}

public struct AppReply: Codable, Equatable, Sendable {
    public enum Kind: String, Codable, Sendable { case started, working, result, failed, cancelled }

    public var requestID: String
    public var kind: Kind
    /// The cleaned text to insert (result).
    public var text: String?
    /// The plain transcript, already fitted to the context, for "Raw".
    public var raw: String?
    /// One short line for the keyboard strip (failed).
    public var message: String?
    public var at: Date

    public init(requestID: String, kind: Kind, text: String? = nil, raw: String? = nil, message: String? = nil, at: Date) {
        self.requestID = requestID
        self.kind = kind
        self.text = text
        self.raw = raw
        self.message = message
        self.at = at
    }
}

/// What the keyboard just typed, so Undo and Raw can take it back.
public struct Insertion: Codable, Equatable, Sendable {
    public var text: String
    public var raw: String?
    public var at: Date

    public init(text: String, raw: String?, at: Date) {
        self.text = text
        self.raw = raw
        self.at = at
    }
}

public enum InsertDecision: Equatable, Sendable {
    case insert(String)
    /// Can't safely type it here (different box, or the keyboard lost track): offer "Paste last".
    case pasteLast
    case ignore
}

public enum KeyboardLogic {
    /// Never insert into the wrong box (RISKS A7): the reply must answer the request we're
    /// waiting on, in the same text field it was made in.
    public static func decide(reply: AppReply, pending: KeyboardRequest?, currentDocument: String?) -> InsertDecision {
        guard reply.kind == .result, let text = reply.text, !text.isEmpty else { return .ignore }
        guard let pending, pending.id == reply.requestID else { return .pasteLast }
        if let wanted = pending.documentID, wanted != currentDocument { return .pasteLast }
        return .insert(text)
    }

    /// Undo/Raw only act while the cursor is still right after what Friday typed.
    /// iOS may give only the last part of the text before the cursor, so a long insert
    /// counts as "still there" when everything iOS shows is the end of it.
    public static func canRevert(_ insertion: Insertion, contextBefore: String?) -> Bool {
        guard let context = contextBefore, !context.isEmpty, !insertion.text.isEmpty else { return false }
        if context.count >= insertion.text.count { return context.hasSuffix(insertion.text) }
        return insertion.text.hasSuffix(context)
    }

    /// The app's heartbeat is "fresh" if it's under 3 s old.
    public static func sessionLive(beat: AppBeat?, now: Date) -> Bool {
        guard let beat, now.timeIntervalSince(beat.at) < 3 else { return false }
        return beat.state == "holding" || beat.state == "dictating"
    }
}

/// Float level <-> 4 bytes, for the live waveform file.
public enum LevelCodec {
    public static func encode(_ level: Float) -> Data {
        withUnsafeBytes(of: max(0, min(1, level)).bitPattern.littleEndian) { Data($0) }
    }

    public static func decode(_ data: Data) -> Float {
        guard data.count == 4 else { return 0 }
        let bits = data.withUnsafeBytes { $0.loadUnaligned(as: UInt32.self) }
        return Float(bitPattern: UInt32(littleEndian: bits))
    }
}
