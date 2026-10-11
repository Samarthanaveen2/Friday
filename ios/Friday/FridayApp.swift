import AppIntents
import SwiftUI

@main
struct FridayApp: App {
    @State private var model = ProbeModel()

    init() {
        _ = Session.shared
    }

    var body: some Scene {
        WindowGroup {
            ProbeView(model: model)
                .tint(Theme.accent)
                .onOpenURL { model.handle($0) }
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
