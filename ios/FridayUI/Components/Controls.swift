import SwiftUI

/// What the talk pill shows.
enum TalkState: Equatable {
    case idle
    /// Live mic levels 0…1, oldest first.
    case listening([CGFloat])
    /// Speech is being turned into text.
    case writing
}

/// The black talk pill, the same one as on the keyboard (Wispr style). Idle it says "Talk";
/// listening it widens to ✕, live bars and ✓; while writing it shows three dots.
struct TalkPill: View {
    let state: TalkState
    var title = "Talk"
    var onTalk: () -> Void = {}
    var onCancel: () -> Void = {}
    var onDone: () -> Void = {}
    @Namespace private var pill

    var body: some View {
        ZStack {
            switch state {
            case .idle:
                Button(action: onTalk) {
                    HStack(spacing: 8) {
                        Image(systemName: "mic.fill").font(.system(size: 16, weight: .semibold))
                        Text(title).scaledFont(17, .semibold)
                    }
                    .foregroundStyle(Palette.onInverse)
                    .padding(.horizontal, 26)
                    .frame(height: 56)
                    .background(Palette.inverse, in: Capsule())
                    .matchedGeometryEffect(id: "pill", in: pill)
                }
                .buttonStyle(PressScale())
                .accessibilityLabel(title)
            case .listening(let levels):
                HStack(spacing: 0) {
                    round("xmark", label: "Cancel", action: onCancel)
                    Bars(levels: levels).frame(maxWidth: .infinity)
                    round("checkmark", label: "Done", action: onDone)
                }
                .padding(.horizontal, 6)
                .frame(width: 280, height: 56)
                .background(Palette.inverse, in: Capsule())
                .matchedGeometryEffect(id: "pill", in: pill)
            case .writing:
                WorkingDots(color: Palette.onInverse)
                    .frame(width: 120, height: 56)
                    .background(Palette.inverse, in: Capsule())
                    .matchedGeometryEffect(id: "pill", in: pill)
            }
        }
        .animation(Motion.spring, value: kind)
        .sensoryFeedback(trigger: kind) { old, new in
            switch (old, new) {
            case (0, 1): .impact(weight: .light)
            case (1, 2): .success
            default: nil
            }
        }
    }

    /// 0 idle, 1 listening, 2 writing: only changes of state animate, not every level update.
    private var kind: Int {
        switch state {
        case .idle: 0
        case .listening: 1
        case .writing: 2
        }
    }

    private func round(_ symbol: String, label: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: symbol)
                .font(.system(size: 16, weight: .bold))
                .foregroundStyle(Palette.inverse)
                .frame(width: 44, height: 44)
                .background(Palette.onInverse, in: Circle())
        }
        .buttonStyle(PressScale())
        .accessibilityLabel(label)
    }

    /// 20 thin bars from the newest levels, centred.
    private struct Bars: View {
        let levels: [CGFloat]

        var body: some View {
            let shown = Array(levels.suffix(20))
            HStack(spacing: 3) {
                ForEach(0..<20, id: \.self) { i in
                    let level = i < 20 - shown.count ? 0 : shown[i - (20 - shown.count)]
                    Capsule()
                        .fill(Palette.onInverse)
                        .frame(width: 3, height: max(3, min(1, level) * 30))
                }
            }
            .animation(.easeOut(duration: 0.08), value: levels)
            .accessibilityHidden(true)
        }
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
            .scaleEffect(configuration.isPressed ? 0.96 : 1)
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
            .foregroundStyle(style == .primary ? Palette.onInverse : Palette.text)
            .frame(maxWidth: .infinity)
            .frame(height: 54)
            .background(style == .primary ? Palette.inverse : Palette.raised, in: Capsule())
        }
        .buttonStyle(PressScale())
    }
}
