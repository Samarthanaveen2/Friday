import SwiftUI

/// The 76 pt talk button at the bottom of Today.
struct MicButton: View {
    var action: () -> Void = {}

    var body: some View {
        Button(action: action) {
            Image(systemName: "mic.fill")
                .font(.system(size: 30, weight: .semibold))
                .foregroundStyle(.white)
                .frame(width: Theme.micSize, height: Theme.micSize)
                .background(Palette.accent, in: Circle())
                .shadow(color: Palette.accent.opacity(0.30), radius: 16, y: 6)
        }
        .buttonStyle(PressScale())
        .accessibilityLabel("Talk")
    }
}

/// Dark pill above the mic: "4 changes · Undo" or "Didn't catch that".
struct ChangePill: View {
    let text: String
    var undo: (() -> Void)?

    var body: some View {
        HStack(spacing: 14) {
            Text(text).scaledFont(15).foregroundStyle(.white)
            if let undo {
                Button("Undo", action: undo)
                    .scaledFont(15, .semibold)
                    .foregroundStyle(.white)
                    .padding(.horizontal, 14)
                    .frame(height: 32)
                    .background(Color.white.opacity(0.16), in: Capsule())
                    .buttonStyle(.plain)
            }
        }
        .padding(.leading, 18)
        .padding(.trailing, undo == nil ? 18 : 8)
        .frame(height: 44)
        .background(Palette.pill, in: Capsule())
    }
}

/// Voice-memo style bars. `levels` are 0…1, oldest first.
struct Waveform: View {
    let levels: [CGFloat]
    var height: CGFloat = 48
    var barWidth: CGFloat = 4
    var color: Color = Palette.accent

    var body: some View {
        HStack(alignment: .center, spacing: barWidth) {
            ForEach(Array(levels.enumerated()), id: \.offset) { _, level in
                Capsule()
                    .fill(color)
                    .frame(width: barWidth, height: max(barWidth, min(1, level) * height))
            }
        }
        .frame(height: height)
        .animation(.easeOut(duration: 0.08), value: levels)
        .accessibilityHidden(true)
    }
}

/// Three soft dots while the text is being cleaned up.
struct WorkingDots: View {
    var color: Color = Palette.secondary
    @State private var phase = 0.0

    var body: some View {
        HStack(spacing: 7) {
            ForEach(0..<3) { i in
                Circle()
                    .fill(color)
                    .frame(width: 8, height: 8)
                    .opacity(0.35 + 0.65 * max(0, sin(phase - Double(i) * 0.6)))
            }
        }
        .onAppear {
            withAnimation(.linear(duration: 1.1).repeatForever(autoreverses: false)) { phase = .pi * 2 }
        }
        .accessibilityLabel("Working")
    }
}

/// Slight shrink on press, used by round buttons.
struct PressScale: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.94 : 1)
            .animation(.easeOut(duration: 0.12), value: configuration.isPressed)
    }
}

/// Full-width capsule button (sheet and card actions).
struct CapsuleButton: View {
    enum Style { case primary, secondary }

    let title: String
    var systemImage: String?
    var style: Style = .primary
    var action: () -> Void = {}

    var body: some View {
        Button(action: action) {
            HStack(spacing: 8) {
                if let systemImage { Image(systemName: systemImage) }
                Text(title)
            }
            .scaledFont(17, .semibold)
            .foregroundStyle(style == .primary ? Color.white : Palette.text)
            .frame(maxWidth: .infinity)
            .frame(height: 52)
            .background(style == .primary ? Palette.accent : Palette.raised, in: Capsule())
        }
        .buttonStyle(PressScale())
    }
}
