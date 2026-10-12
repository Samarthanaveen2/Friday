import SwiftUI
import UIKit

/// Colours, each with a dark-mode partner. Every view uses these, never raw values.
/// Light is Wispr-style: warm white paper, near-black ink, a soft lilac for highlights.
/// The app always runs light; dark values are for the keyboard in dark mode.
enum Palette {
    static let background = dynamic(0xFAF9F4, 0x000000)
    static let card = dynamic(0xFFFFFF, 0x1C1C1E)
    static let raised = dynamic(0xF3F1EA, 0x2C2C2E)
    static let separator = dynamic(0xEEECE4, 0x38383A)
    /// Hairline around cards and round buttons.
    static let border = dynamic(0xE9E6DC, 0x2C2C2E)
    static let text = dynamic(0x1A1A1A, 0xF5F5F7)
    static let secondary = dynamic(0x6E6C64, 0x98989F)
    static let tertiary = dynamic(0xAAA79D, 0x636366)
    static let alsoText = dynamic(0x3C3B36, 0xD1D1D6)
    /// Primary controls are ink, not colour.
    static let accent = dynamic(0x1A1A1A, 0xF0D7FF)
    static let lilac = dynamic(0xF0D7FF, 0x3A2D4F)
    static let changeTint = dynamic(0xF7EEFF, 0x2A2238)
    static let stop = dynamic(0xD92D20, 0xFF453A)
    static let pass = dynamic(0x1F7A4D, 0x30D158)
    static let pill = dynamic(0x1A1A1A, 0x2C2C2E)
    static let grabber = dynamic(0xDCD9CF, 0x48484A)

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
    static let radius: CGFloat = 20
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
    private let design: Font.Design

    init(size: CGFloat, weight: Font.Weight, relativeTo style: Font.TextStyle, monospacedDigits: Bool, design: Font.Design) {
        _size = ScaledMetric(wrappedValue: size, relativeTo: style)
        self.weight = weight
        self.monospacedDigits = monospacedDigits
        self.design = design
    }

    func body(content: Content) -> some View {
        let font = Font.system(size: size, weight: weight, design: design)
        return content.font(monospacedDigits ? font.monospacedDigit() : font)
    }
}

extension View {
    /// `serif`: Apple's New York, for titles (the Wispr look); everything else stays SF.
    func scaledFont(_ size: CGFloat, _ weight: Font.Weight = .regular, relativeTo style: Font.TextStyle = .body,
                    digits: Bool = false, serif: Bool = false) -> some View {
        modifier(ScaledFont(size: size, weight: weight, relativeTo: style, monospacedDigits: digits,
                            design: serif ? .serif : .default))
    }

    /// White card with a hairline edge, the one card style everywhere.
    func card(radius: CGFloat = Theme.radius, fill: Color = Palette.card) -> some View {
        background(fill, in: RoundedRectangle(cornerRadius: radius, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: radius, style: .continuous).strokeBorder(Palette.border, lineWidth: 1))
    }
}
