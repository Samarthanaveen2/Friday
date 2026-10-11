import SwiftUI
import UIKit

/// Colours (PLAN §13), each with a dark-mode partner. Every view uses these, never raw values.
enum Palette {
    static let background = dynamic(0xF2F2F7, 0x000000)
    static let card = dynamic(0xFFFFFF, 0x1C1C1E)
    static let raised = dynamic(0xF2F2F7, 0x2C2C2E)
    static let separator = dynamic(0xE3E3E8, 0x38383A)
    static let text = dynamic(0x111114, 0xF5F5F7)
    static let secondary = dynamic(0x5F5F66, 0x98989F)
    static let tertiary = dynamic(0xA1A1A8, 0x636366)
    static let alsoText = dynamic(0x3A3A40, 0xD1D1D6)
    static let accent = dynamic(0x4338CA, 0x7C73FF)
    static let changeTint = dynamic(0xEEF0FF, 0x23264A)
    static let stop = dynamic(0xD92D20, 0xFF453A)
    static let pass = dynamic(0x1F9D55, 0x30D158)
    static let pill = dynamic(0x111114, 0x2C2C2E)
    static let grabber = dynamic(0xD1D1D6, 0x48484A)

    // Keyboard: keys look like Apple's in both modes; the Wispr-style pill is the only contrast.
    static let key = dynamic(0xFFFFFF, 0x6B6B6E, darkAlpha: 0.55)
    static let keyPressed = dynamic(0xC9CDD4, 0x8E8E93, darkAlpha: 0.75)
    static let keyShadow = dynamic(0x888B8F, 0x000000, lightAlpha: 0.55, darkAlpha: 0.35)
    static let keyText = dynamic(0x000000, 0xFFFFFF)
    static let inverse = dynamic(0x111114, 0xFFFFFF)
    static let onInverse = dynamic(0xFFFFFF, 0x000000)

    static func dynamic(_ light: UInt32, _ dark: UInt32, lightAlpha: CGFloat = 1, darkAlpha: CGFloat = 1) -> Color {
        Color(UIColor { traits in
            traits.userInterfaceStyle == .dark ? UIColor(hex: dark, alpha: darkAlpha) : UIColor(hex: light, alpha: lightAlpha)
        })
    }
}

/// Older names used by the setup-check screen.
enum Theme {
    static let accent = Palette.accent
    static let stop = Palette.stop
    static let pass = Palette.pass
    static let radius: CGFloat = 16
    static let micSize: CGFloat = 76
}

enum Motion {
    /// The one spring used for every state change.
    static let spring = Animation.spring(response: 0.32, dampingFraction: 0.86)
    static let fade = Animation.easeOut(duration: 0.2)
}

extension UIColor {
    convenience init(hex: UInt32, alpha: CGFloat = 1) {
        self.init(red: CGFloat((hex >> 16) & 0xFF) / 255, green: CGFloat((hex >> 8) & 0xFF) / 255,
                  blue: CGFloat(hex & 0xFF) / 255, alpha: alpha)
    }
}

/// System font at a fixed design size that still follows the user's text size setting.
struct ScaledFont: ViewModifier {
    @ScaledMetric private var size: CGFloat
    private let weight: Font.Weight
    private let monospacedDigits: Bool

    init(size: CGFloat, weight: Font.Weight, relativeTo style: Font.TextStyle, monospacedDigits: Bool) {
        _size = ScaledMetric(wrappedValue: size, relativeTo: style)
        self.weight = weight
        self.monospacedDigits = monospacedDigits
    }

    func body(content: Content) -> some View {
        let font = Font.system(size: size, weight: weight)
        return content.font(monospacedDigits ? font.monospacedDigit() : font)
    }
}

extension View {
    func scaledFont(_ size: CGFloat, _ weight: Font.Weight = .regular, relativeTo style: Font.TextStyle = .body,
                    digits: Bool = false) -> some View {
        modifier(ScaledFont(size: size, weight: weight, relativeTo: style, monospacedDigits: digits))
    }
}
