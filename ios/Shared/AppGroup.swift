import Foundation

/// Small JSON files in the App Group container, shared by the app, the keyboard and the widget.
/// Every file is a flat dictionary of numbers (timestamps, counters, flags).
enum AppGroup {
    static let base = "group.com.samarth.friday"

    /// The signing profile SideStore embeds in this app or extension (nil if missing).
    static let profile: [String: Any]? = {
        guard let url = Bundle.main.url(forResource: "embedded", withExtension: "mobileprovision"),
              let data = try? Data(contentsOf: url),
              let start = data.range(of: Data("<?xml".utf8)),
              let end = data.range(of: Data("</plist>".utf8)) else { return nil }
        let plistData = data.subdata(in: start.lowerBound..<end.upperBound)
        return try? PropertyListSerialization.propertyList(from: plistData, format: nil) as? [String: Any]
    }()

    /// SideStore re-signs on a free Apple ID and may rename the group (for example by adding the
    /// team ID). Every name it could have used, most likely first.
    static var candidates: [String] {
        var out: [String] = []
        if let ids = Bundle.main.object(forInfoDictionaryKey: "ALTAppGroups") as? [String] { out += ids }
        if let ents = profile?["Entitlements"] as? [String: Any],
           let groups = ents["com.apple.security.application-groups"] as? [String] { out += groups }
        if let team = (profile?["TeamIdentifier"] as? [String])?.first { out.append("\(base).\(team)") }
        out.append(base)
        var seen = Set<String>()
        return out.filter { seen.insert($0).inserted }
    }

    private static func container(for id: String) -> URL? {
        FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: id)
    }

    /// First candidate that really has a folder on this phone.
    static var identifier: String {
        candidates.first(where: { container(for: $0) != nil }) ?? candidates.first ?? base
    }

    static var containerURL: URL? { container(for: identifier) }

    /// One line per name tried, for the report screens.
    static var diagnostics: String {
        let tried = candidates.map { (container(for: $0) != nil ? "✅ " : "❌ ") + $0 }.joined(separator: "\n")
        let hasProfile = profile != nil ? "profile found" : "no profile"
        return "\(hasProfile)\n\(tried)"
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
