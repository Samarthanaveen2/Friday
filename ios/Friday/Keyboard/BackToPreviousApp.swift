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
