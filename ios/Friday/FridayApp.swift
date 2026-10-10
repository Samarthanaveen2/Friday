import SwiftUI

@main
struct FridayApp: App {
    var body: some Scene {
        WindowGroup {
            ContentView()
                .onOpenURL { _ in
                    // The keyboard's "Open Friday" button lands here (friday://probe).
                    AppGroup.bump("opened.json")
                }
        }
    }
}
