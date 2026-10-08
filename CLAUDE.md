# Friday

This repo has two things:
- `extension/` — Friday, a Chrome extension (run commands from any text box). Done; leave it alone unless asked.
- `ios/` — **Friday for iPhone**, the active project. `ios/PLAN.md` is the full spec and the source of truth; read it before any iOS work. `ios/design/` has the agreed mockups.

Working rules for the iOS app:
- The owner has no Mac and no paid Apple developer account. Code is built only by GitHub Actions (unsigned .ipa → GitHub Release `latest`) and installed with SideStore. Never ask the owner to open Xcode.
- Generate the Xcode project with XcodeGen (`ios/project.yml`); don't commit hand-edited `.xcodeproj` files.
- Keep pure logic in the `FridayCore` Swift package (no UIKit/SwiftUI) and test it with `swift test` locally before pushing.
- Bundle IDs must never change once installed (data would be lost).
- The owner prefers very short messages, plain words, no jargon.
