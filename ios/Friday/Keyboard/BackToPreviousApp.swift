import UIKit

/// Taps iOS's own "◀ Back to <app>" breadcrumb after the keyboard opened Friday, so the
/// user lands back in their chat without swiping. This uses a private UIKit action (fine for a
/// sideloaded app); if iOS ever removes it, this returns false and the swipe-back screen shows.
@MainActor
enum BackToPreviousApp {
    static func go() -> Bool {
        let app = UIApplication.shared
        let getter = NSSelectorFromString("_systemNavigationAction")
        guard app.responds(to: getter),
              let action = app.perform(getter)?.takeUnretainedValue() as? NSObject
        else { return false }

        // Destination 0 is "back to the previous app"; only fire if iOS offers it.
        let destinations = NSSelectorFromString("destinations")
        if action.responds(to: destinations),
           let list = action.perform(destinations)?.takeUnretainedValue() as? [NSNumber],
           !list.contains(0) {
            return false
        }
        let send = NSSelectorFromString("sendResponseForDestination:")
        guard action.responds(to: send) else { return false }
        typealias Send = @convention(c) (AnyObject, Selector, UInt) -> Void
        let call = unsafeBitCast(action.method(for: send), to: Send.self)
        call(action, send, 0)
        return true
    }
}

/// Gets you back to the app you were typing in, the way Wispr does, trying in order:
/// 1. iOS's own "◀ Back" breadcrumb (no prompt);
/// 2. reopen the app you came from by its bundle id (found from UIKit's keyboard state);
/// 3. reopen it by its link (iOS asks "Open …?" once per app, then never again).
/// Each step only counts if Friday actually left the screen. All private calls are checked
/// first, so if iOS removes them nothing crashes and the swipe-back screen shows instead.
@MainActor
enum ReturnToHost {
    /// Which way worked last time ("breadcrumb", "bundle", "link"), for Setup check.
    static func go() async -> String? {
        if BackToPreviousApp.go(), await left() { return "breadcrumb" }
        guard let host = await hostBundleID() else { return nil }
        if openByBundleID(host), await left() { return "bundle" }
        if let link = links[host], let url = URL(string: link), await UIApplication.shared.open(url), await left() {
            return "link"
        }
        return nil
    }

    /// Friday is no longer the app on screen.
    private static func left() async -> Bool {
        try? await Task.sleep(for: .milliseconds(700))
        return UIApplication.shared.applicationState != .active
    }

    /// The app the keyboard was open in, from UIKit's private keyboard state. It can take a moment
    /// to arrive after Friday opens, so this waits up to ~1.5 s.
    static func hostBundleID() async -> String? {
        for _ in 0..<8 {
            if let id = currentSourceBundleID(), !id.hasPrefix("com.samarth.friday") { return id }
            try? await Task.sleep(for: .milliseconds(200))
        }
        return nil
    }

    private static func currentSourceBundleID() -> String? {
        guard let cls = NSClassFromString("_UIRemoteKeyboards") as AnyObject?,
              cls.responds(to: NSSelectorFromString("sharedRemoteKeyboards")),
              let shared = cls.perform(NSSelectorFromString("sharedRemoteKeyboards"))?.takeUnretainedValue() as? NSObject,
              shared.responds(to: NSSelectorFromString("currentState")),
              let state = shared.perform(NSSelectorFromString("currentState"))?.takeUnretainedValue() as? NSObject,
              state.responds(to: NSSelectorFromString("sourceBundleIdentifier"))
        else { return nil }
        return state.perform(NSSelectorFromString("sourceBundleIdentifier"))?.takeUnretainedValue() as? String
    }

    private static func openByBundleID(_ id: String) -> Bool {
        guard let cls = NSClassFromString("LSApplicationWorkspace") as AnyObject?,
              cls.responds(to: NSSelectorFromString("defaultWorkspace")),
              let workspace = cls.perform(NSSelectorFromString("defaultWorkspace"))?.takeUnretainedValue() as? NSObject
        else { return false }
        let open = NSSelectorFromString("openApplicationWithBundleID:")
        guard workspace.responds(to: open) else { return false }
        typealias Open = @convention(c) (AnyObject, Selector, NSString) -> Bool
        let call = unsafeBitCast(workspace.method(for: open), to: Open.self)
        return call(workspace, open, id as NSString)
    }

    /// Links that open popular apps (used only if reopening by bundle id didn't work).
    static let links: [String: String] = [
        "net.whatsapp.WhatsApp": "whatsapp://",
        "net.whatsapp.WhatsAppSMB": "whatsapp-smb://",
        "com.openai.chat": "chatgpt://",
        "com.burbn.instagram": "instagram://",
        "com.apple.MobileSMS": "sms:",
        "com.apple.mobilenotes": "mobilenotes://",
        "com.apple.mobilemail": "message://",
        "com.apple.mobilesafari": "x-safari-https://",
        "com.google.Gmail": "googlegmail://",
        "com.google.chrome.ios": "googlechrome://",
        "ph.telegra.Telegraph": "tg://",
        "com.atebits.Tweetie2": "twitter://",
        "com.toyopagroup.picaboo": "snapchat://",
        "com.hammerandchisel.discord": "discord://",
        "com.tinyspeck.chatlyio": "slack://",
        "notion.id": "notion://",
        "com.linkedin.LinkedIn": "linkedin://",
        "com.facebook.Messenger": "fb-messenger://",
        "com.google.GoogleMobile": "google://",
        "com.anthropic.claude": "claude://",
        "com.microsoft.Office.Outlook": "ms-outlook://",
        "com.spotify.client": "spotify://",
        "com.apple.reminders": "x-apple-reminderkit://",
    ]
}
