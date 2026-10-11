import Foundation
import FridayCore

/// The shared folder the app and keyboard both read and write.
/// SideStore may rename the App Group, so every likely name is tried at run time.
struct GroupStore: Sendable {
    let groupID: String?
    let folder: URL?
    /// Every name tried, with whether it worked. Shown on the probe screen.
    let tried: [Attempt]

    struct Attempt: Sendable {
        let name: String
        let ok: Bool
    }

    static let shared = GroupStore.resolve()

    static func resolve(bundle: Bundle = .main) -> GroupStore {
        let profile = embeddedProfile(bundle: bundle)
        let candidates = AppGroupCandidates.list(
            altAppGroups: bundle.object(forInfoDictionaryKey: "ALTAppGroups") as? [String] ?? [],
            profileGroups: profile?.appGroups ?? [],
            teamID: profile?.teamID
        )
        var tried: [Attempt] = []
        var found: (String, URL)?
        for name in candidates {
            let url = FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: name)
            let ok = url.map(isWritable) ?? false
            tried.append(Attempt(name: name, ok: ok))
            if ok, found == nil, let url { found = (name, url) }
        }
        return GroupStore(groupID: found?.0, folder: found?.1, tried: tried)
    }

    static func embeddedProfile(bundle: Bundle = .main) -> ProvisionProfile? {
        guard let url = bundle.url(forResource: "embedded", withExtension: "mobileprovision"),
              let data = try? Data(contentsOf: url) else { return nil }
        return ProvisionProfile.parse(data)
    }

    private static func isWritable(_ folder: URL) -> Bool {
        let probe = folder.appendingPathComponent(".write-test")
        do {
            try Data("ok".utf8).write(to: probe, options: .atomic)
            try? FileManager.default.removeItem(at: probe)
            return true
        } catch {
            return false
        }
    }

    func write<T: Encodable>(_ value: T, to file: String) {
        guard let folder, let data = try? ProbeCodec.encode(value) else { return }
        try? data.write(to: folder.appendingPathComponent(file), options: .atomic)
    }

    func read<T: Decodable>(_ type: T.Type, from file: String) -> T? {
        guard let folder, let data = try? Data(contentsOf: folder.appendingPathComponent(file)) else { return nil }
        return ProbeCodec.decode(type, from: data)
    }
}

/// Cross-process "something changed" pings (Darwin notifications). They carry no data;
/// the receiver re-reads the shared file. Re-posted on the main thread as a normal Notification.
enum DarwinNotice {
    static func post(_ name: String) {
        CFNotificationCenterPostNotification(
            CFNotificationCenterGetDarwinNotifyCenter(), CFNotificationName(name as CFString), nil, nil, true)
    }

    static func observe(_ name: String) {
        CFNotificationCenterAddObserver(
            CFNotificationCenterGetDarwinNotifyCenter(), nil,
            { _, _, cfName, _, _ in
                guard let raw = cfName?.rawValue as String? else { return }
                DispatchQueue.main.async {
                    NotificationCenter.default.post(name: Notification.Name(raw), object: nil)
                }
            },
            name as CFString, nil, .deliverImmediately)
    }
}
