import Foundation

/// The parts of `embedded.mobileprovision` Friday cares about: who signed it,
/// when it expires, and which App Groups free signing actually granted.
public struct ProvisionProfile: Equatable, Sendable {
    public var name: String?
    public var teamID: String?
    public var expirationDate: Date?
    public var appGroups: [String]

    public init(name: String? = nil, teamID: String? = nil, expirationDate: Date? = nil, appGroups: [String] = []) {
        self.name = name
        self.teamID = teamID
        self.expirationDate = expirationDate
        self.appGroups = appGroups
    }

    /// The file is a signed CMS blob with a plain XML plist inside; pull the plist out.
    public static func parse(_ data: Data) -> ProvisionProfile? {
        guard let start = data.range(of: Data("<?xml".utf8)),
              let end = data.range(of: Data("</plist>".utf8), in: start.lowerBound..<data.endIndex)
        else { return nil }
        let xml = Data(data[start.lowerBound..<end.upperBound])
        guard let plist = (try? PropertyListSerialization.propertyList(from: xml, format: nil)) as? [String: Any]
        else { return nil }
        let entitlements = plist["Entitlements"] as? [String: Any] ?? [:]
        return ProvisionProfile(
            name: plist["Name"] as? String,
            teamID: (plist["TeamIdentifier"] as? [String])?.first,
            expirationDate: plist["ExpirationDate"] as? Date,
            appGroups: entitlements["com.apple.security.application-groups"] as? [String] ?? []
        )
    }

    /// Whole days until expiry (0 on the last day), nil if unknown.
    public func daysLeft(now: Date) -> Int? {
        guard let expirationDate else { return nil }
        return max(0, Int(expirationDate.timeIntervalSince(now) / 86_400))
    }
}
