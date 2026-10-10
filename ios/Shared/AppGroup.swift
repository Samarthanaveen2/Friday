import Foundation

/// Small JSON files in the App Group container, shared by the app, the keyboard and the widget.
/// Every file is a flat dictionary of numbers (timestamps, counters, flags).
enum AppGroup {
    static let base = "group.com.samarth.friday"

    /// SideStore re-signs the app on a free Apple ID and may rename the group.
    /// It lists the real names in Info.plist under "ALTAppGroups"; use the first one if present.
    static var identifier: String {
        if let ids = Bundle.main.object(forInfoDictionaryKey: "ALTAppGroups") as? [String],
           let first = ids.first {
            return first
        }
        return base
    }

    static var containerURL: URL? {
        FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: identifier)
    }

    static func write(_ values: [String: Double], to name: String) {
        guard let url = containerURL?.appendingPathComponent(name),
              let data = try? JSONSerialization.data(withJSONObject: values) else { return }
        try? data.write(to: url, options: .atomic)
    }

    static func read(_ name: String) -> [String: Double]? {
        guard let url = containerURL?.appendingPathComponent(name),
              let data = try? Data(contentsOf: url),
              let obj = try? JSONSerialization.jsonObject(with: data) as? [String: Double] else { return nil }
        return obj
    }

    /// Adds one to the "count" in a file and stamps the time. Returns the new count.
    @discardableResult
    static func bump(_ name: String) -> Int {
        let count = Int(read(name)?["count"] ?? 0) + 1
        write(["t": Date().timeIntervalSince1970, "count": Double(count)], to: name)
        return count
    }

    static func ageText(_ t: Double?) -> String {
        guard let t else { return "never" }
        let s = max(0, Int(Date().timeIntervalSince1970 - t))
        if s < 60 { return "\(s)s ago" }
        if s < 3600 { return "\(s / 60) min ago" }
        return "\(s / 3600) h ago"
    }
}
