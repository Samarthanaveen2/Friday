import Foundation

/// Step-by-step log of the last "Talk to Friday" run, kept in the App Group so it survives a
/// crash and can be read in Setup check. Each step is written to disk right away.
enum IntentTrail {
    static let file = "talk-trail.txt"
    static let endMark = "— end"
    private static let lock = NSLock()

    /// Starts a new trail (the previous one is replaced).
    static func begin(_ step: String) {
        lock.lock(); defer { lock.unlock() }
        save(line(step))
    }

    static func add(_ step: String) {
        lock.lock(); defer { lock.unlock() }
        save(read() + "\n" + line(step))
    }

    /// The run finished (well or with an error it reported).
    static func end(_ step: String) {
        add(step)
        add(endMark)
    }

    static func read() -> String {
        GroupStore.shared.readData(file).flatMap { String(data: $0, encoding: .utf8) } ?? ""
    }

    /// On launch: a trail without an end step means Friday quit in the middle.
    static func markIfCut() {
        let text = read()
        guard !text.isEmpty, !text.hasSuffix(endMark) else { return }
        end("stopped here (Friday quit)")
    }

    private static func line(_ step: String) -> String {
        let f = DateFormatter()
        f.dateFormat = "HH:mm:ss.SSS"
        return f.string(from: .now) + "  " + step
    }

    private static func save(_ text: String) {
        GroupStore.shared.writeData(Data(text.utf8), to: file, atomic: true)
    }
}
