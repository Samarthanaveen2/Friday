import SwiftUI

// Living pieces of the design: the aurora wash, the voice orb, the live waveform and the
// cursive accent. Everything moves slowly when idle and answers the voice when listening.

/// Warm aurora colours: peach, lilac, sky and cream, like light on paper.
enum Aurora {
    static let colors: [Color] = [
        Color(hex: 0xFFE3D3), Color(hex: 0xF0D7FF), Color(hex: 0xFFF4DA),
        Color(hex: 0xE6DCFF), Color(hex: 0xFFFFFF), Color(hex: 0xFFD9EC),
        Color(hex: 0xDDEBFF), Color(hex: 0xF7E8FF), Color(hex: 0xFFE9C9),
    ]
    /// Deeper version for the orb, so it reads on white.
    static let orb: [Color] = [
        Color(hex: 0xFF9F7A), Color(hex: 0xB98CFF), Color(hex: 0xFFC46B),
        Color(hex: 0x8E7BFF), Color(hex: 0xFFE8F4), Color(hex: 0xFF7EB6),
        Color(hex: 0x6FA8FF), Color(hex: 0xD49BFF), Color(hex: 0xFFB36B),
    ]
}

/// A 3×3 mesh gradient whose inner points drift. `energy` (0…1) speeds it up and swirls it more.
struct AuroraMesh: View {
    var colors: [Color] = Aurora.colors
    var energy: Double = 0
    var speed: Double = 0.25

    var body: some View {
        TimelineView(.animation) { context in
            let t = context.date.timeIntervalSinceReferenceDate * (speed + energy * 1.2)
            let swirl = Float(0.10 + energy * 0.18)
            MeshGradient(
                width: 3, height: 3,
                points: [
                    [0, 0], [0.5 + swirl * Float(sin(t * 0.7)), 0], [1, 0],
                    [0, 0.5 + swirl * Float(cos(t * 0.9))],
                    [0.5 + swirl * Float(sin(t * 1.1)), 0.5 + swirl * Float(cos(t * 0.8))],
                    [1, 0.5 + swirl * Float(sin(t * 0.6))],
                    [0, 1], [0.5 + swirl * Float(cos(t * 0.5)), 1], [1, 1],
                ],
                colors: colors
            )
        }
    }
}

/// The soft moving wash at the top of Home.
struct AuroraWash: View {
    var height: CGFloat = 340

    var body: some View {
        AuroraMesh(speed: 0.18)
            .opacity(0.55)
            .frame(height: height)
            .mask(LinearGradient(colors: [.black, .black.opacity(0.6), .clear], startPoint: .top, endPoint: .bottom))
            .ignoresSafeArea(edges: .top)
            .accessibilityHidden(true)
    }
}

/// The voice orb: a glassy sphere with a living gradient inside. It breathes when idle and
/// swells with your voice (`level` 0…1) when listening.
struct VoiceOrb: View {
    var size: CGFloat = 76
    var level: Double = 0
    var listening = false
    @State private var breathe = false

    var body: some View {
        let swell = listening ? 1 + min(0.22, level * 0.35) : (breathe ? 1.04 : 0.98)
        ZStack {
            // Glow that follows the voice.
            Circle()
                .fill(RadialGradient(colors: [Color(hex: 0xC9A2FF).opacity(0.55), .clear],
                                     center: .center, startRadius: size * 0.2, endRadius: size * 0.95))
                .frame(width: size * 1.9, height: size * 1.9)
                .scaleEffect(listening ? 1 + level * 0.6 : (breathe ? 1.05 : 0.9))
                .blur(radius: 6)
            AuroraMesh(colors: Aurora.orb, energy: listening ? 0.4 + level : 0.1, speed: 0.35)
                .clipShape(Circle())
                .frame(width: size, height: size)
                .overlay {
                    // Light from the top left, shade at the bottom: reads as a sphere.
                    Circle().fill(LinearGradient(colors: [.white.opacity(0.55), .clear, .black.opacity(0.12)],
                                                 startPoint: .topLeading, endPoint: .bottomTrailing))
                }
                .overlay(Circle().strokeBorder(.white.opacity(0.7), lineWidth: 1.2))
                .shadow(color: Color(hex: 0x8E7BFF).opacity(0.35), radius: 18, y: 8)
                .scaleEffect(swell)
        }
        .animation(.spring(response: 0.25, dampingFraction: 0.6), value: level)
        .onAppear {
            withAnimation(.easeInOut(duration: 2.4).repeatForever(autoreverses: true)) { breathe = true }
        }
        .accessibilityHidden(true)
    }
}

/// Smooth, centred waveform drawn in one pass. `levels` 0…1, oldest first.
struct LiveWave: View {
    let levels: [CGFloat]
    var color: Color = Palette.text
    var height: CGFloat = 64

    var body: some View {
        Canvas { context, size in
            guard !levels.isEmpty else { return }
            let gap: CGFloat = 4
            let bar = max(3, (size.width - gap * CGFloat(levels.count - 1)) / CGFloat(levels.count))
            for (i, level) in levels.enumerated() {
                // Fade the oldest bars so the wave seems to flow out to the left.
                let age = Double(i) / Double(max(1, levels.count - 1))
                let h = max(bar, min(1, level) * size.height)
                let rect = CGRect(x: CGFloat(i) * (bar + gap), y: (size.height - h) / 2, width: bar, height: h)
                context.fill(Path(roundedRect: rect, cornerRadius: bar / 2), with: .color(color.opacity(0.25 + 0.75 * age)))
            }
        }
        .frame(height: height)
        .animation(.easeOut(duration: 0.1), value: levels)
        .accessibilityHidden(true)
    }
}

extension Color {
    init(hex: UInt32, opacity: Double = 1) {
        self.init(.sRGB, red: Double((hex >> 16) & 0xFF) / 255, green: Double((hex >> 8) & 0xFF) / 255,
                  blue: Double(hex & 0xFF) / 255, opacity: opacity)
    }
}

extension View {
    /// Handwritten accent (Snell Roundhand), used sparingly: the greeting and "listening".
    func cursive(_ size: CGFloat, relativeTo style: Font.TextStyle = .title2) -> some View {
        font(.custom("SnellRoundhand-Bold", size: size, relativeTo: style))
    }

    /// Liquid Glass circle for small icon buttons.
    func glassCircle() -> some View {
        glassEffect(.regular.interactive(), in: Circle())
    }
}
