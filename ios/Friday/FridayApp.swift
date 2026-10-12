import AppIntents
import SwiftUI
import UIKit

@main
struct FridayApp: App {
    @State private var model = ProbeModel()

    @State private var app = AppState.shared

    init() {
        IntentTrail.markIfCut()
        // An Objective-C exception (AVAudioEngine and friends) is written down before the crash.
        NSSetUncaughtExceptionHandler { exception in
            IntentTrail.add("CRASH \(exception.name.rawValue): \(exception.reason ?? "")")
        }
        _ = Session.shared
        KeyboardBridge.shared.start()
    }

    var body: some Scene {
        WindowGroup {
            ZStack {
                HomeView(probe: model)
                if app.showSwipeBack {
                    SwipeBackView { withAnimation(Motion.fade) { app.showSwipeBack = false } }
                        .transition(.opacity)
                }
            }
            .tint(Theme.accent)
            // Wispr-style white, always: the app doesn't follow dark mode (the keyboard does).
            .preferredColorScheme(.light)
            .onOpenURL { model.handle($0) }
            .onReceive(NotificationCenter.default.publisher(for: UIApplication.didEnterBackgroundNotification)) { _ in
                app.showSwipeBack = false
            }
        }
    }
}

struct FridayShortcuts: AppShortcutsProvider {
    static var appShortcuts: [AppShortcut] {
        AppShortcut(intent: TalkToFridayIntent(),
                    phrases: ["Talk to \(.applicationName)", "Ask \(.applicationName)", "Tell \(.applicationName)"],
                    shortTitle: "Talk to Friday",
                    systemImageName: "mic.fill")
        AppShortcut(intent: StartFridayIntent(),
                    phrases: ["Start \(.applicationName)"],
                    shortTitle: "Start Friday",
                    systemImageName: "waveform")
    }
}
