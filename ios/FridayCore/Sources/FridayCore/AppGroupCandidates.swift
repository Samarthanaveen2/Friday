import Foundation

/// SideStore renames App Groups on a free Apple ID, so the real name is only known at run time.
/// This builds the list of names to try, best guess first.
public enum AppGroupCandidates {
    public static let base = "group.com.samarth.friday"

    public static func list(altAppGroups: [String], profileGroups: [String], teamID: String?) -> [String] {
        var out: [String] = []
        func add(_ raw: String) {
            let name = raw.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !name.isEmpty, !name.contains("*"), !out.contains(name) else { return }
            out.append(name)
        }
        altAppGroups.forEach(add)
        profileGroups.forEach(add)
        if let teamID, !teamID.isEmpty { add("\(base).\(teamID)") }
        add(base)
        return out
    }
}
