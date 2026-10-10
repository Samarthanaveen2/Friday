import Foundation

/// When the free-account signing runs out (RISKS E1). Read from the profile SideStore embeds.
enum Signing {
    static var expiry: Date? {
        guard let url = Bundle.main.url(forResource: "embedded", withExtension: "mobileprovision"),
              let data = try? Data(contentsOf: url),
              let start = data.range(of: Data("<?xml".utf8)),
              let end = data.range(of: Data("</plist>".utf8)) else { return nil }
        let plistData = data.subdata(in: start.lowerBound..<end.upperBound)
        guard let obj = try? PropertyListSerialization.propertyList(from: plistData, format: nil) as? [String: Any]
        else { return nil }
        return obj["ExpirationDate"] as? Date
    }

    static var expiryText: String {
        guard let d = expiry else { return "not found (normal if SideStore removed the profile)" }
        let days = Calendar.current.dateComponents([.day], from: Date(), to: d).day ?? 0
        return "\(d.formatted(date: .abbreviated, time: .shortened)) (\(days) days left)"
    }
}
