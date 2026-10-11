import SwiftUI

/// Design tokens (PLAN §13). Every screen uses these, never raw values.
enum Theme {
    static let accent = Color(hex: 0x4338CA)
    static let changeTint = Color(hex: 0xEEF0FF)
    static let stop = Color(hex: 0xD92D20)
    static let pass = Color(hex: 0x1F9D55)
    static let pill = Color(hex: 0x111114)

    static let radius: CGFloat = 16
    static let micSize: CGFloat = 76
}

enum Motion {
    /// The one spring used for every state change.
    static let spring = Animation.spring(response: 0.32, dampingFraction: 0.86)
    static let fade = Animation.easeOut(duration: 0.2)
}

extension Color {
    init(hex: UInt32) {
        self.init(.sRGB,
                  red: Double((hex >> 16) & 0xFF) / 255,
                  green: Double((hex >> 8) & 0xFF) / 255,
                  blue: Double(hex & 0xFF) / 255,
                  opacity: 1)
    }
}
