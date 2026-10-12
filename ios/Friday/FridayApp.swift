import AppIntents
import SwiftUI
import UIKit

@main
struct FridayApp: App {
    @State private var model = ProbeModel()

    @State private var app = AppState.shared

    init() {
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
            .onOpenURL { model.handle($0) }
            .onReceive(NotificationCenter.default.publisher(for: UIApplication.didEnterBackgroundNotification)) { _ in
                app.showSwipeBack = false
            }
        }
    }
}

struct FridayShortcuts: AppShortcutsProvider {
    static var appShortcuts: [AppShortcut] {
        AppShortcut(intent: StartFridayIntent(),
                    phrases: ["Start \(.applicationName)"],
                    shortTitle: "Start Friday",
                    systemImageName: "waveform")
    }
}
