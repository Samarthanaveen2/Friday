import SwiftUI

/// Everything home shows. The app builds this from its store.
struct HomeModel: Equatable {
    var dateLabel: String
    /// Handwritten line above the title ("Good evening,").
    var greeting = "Hello,"
    var today: [RowModel]
    var next: (title: String, when: String)?
    var boxes: [BoxModel]
    var pill: String?
    var pillUndo = true
    var card: ResultCardModel?

    static func == (a: HomeModel, b: HomeModel) -> Bool {
        a.dateLabel == b.dateLabel && a.greeting == b.greeting && a.today == b.today && a.boxes == b.boxes
            && a.next?.title == b.next?.title && a.next?.when == b.next?.when
            && a.pill == b.pill && a.pillUndo == b.pillUndo && a.card == b.card
    }
}

/// One place, like Keep: a thin Today strip, then everything you've said as boxes.
struct HomeScreen: View {
    let model: HomeModel
    var onToggle: (String) -> Void = { _ in }
    var onOpenBox: (String) -> Void = { _ in }
    var onTalk: () -> Void = {}
    var onUndo: () -> Void = {}
    var onSearch: () -> Void = {}
    var onSettings: () -> Void = {}
    var onCloseCard: () -> Void = {}
    var onNew: () -> Void = {}
    /// For the zoom from a box card into the box (set by the app; nil in previews).
    var zoom: Namespace.ID?

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                header
                VStack(alignment: .leading, spacing: 8) {
                    SectionLabel(text: "Today")
                    TodayStrip(rows: model.today, next: model.next, onToggle: onToggle)
                }
                BoxGrid(boxes: model.boxes, zoom: zoom, onOpen: onOpenBox)
            }
            .padding(.horizontal, 14)
            .padding(.top, 8)
            .padding(.bottom, 16)
        }
        .scrollIndicators(.hidden)
        .safeAreaInset(edge: .bottom, spacing: 0) { bottomBar }
        .background(alignment: .top) {
            ZStack(alignment: .top) {
                Palette.background
                AuroraWash()
            }
            .ignoresSafeArea()
        }
        .animation(Motion.spring, value: model)
    }

    private var header: some View {
        HStack(alignment: .bottom) {
            VStack(alignment: .leading, spacing: 0) {
                Text(model.dateLabel.uppercased())
                    .scaledFont(12, .semibold, relativeTo: .footnote)
                    .tracking(0.8)
                    .foregroundStyle(Palette.secondary)
                    .padding(.bottom, 6)
                Text(model.greeting)
                    .cursive(26)
                    .foregroundStyle(Palette.secondary)
                Text("Friday")
                    .scaledFont(40, .semibold, relativeTo: .largeTitle, serif: true)
                    .foregroundStyle(Palette.text)
            }
            Spacer()
            GlassEffectContainer(spacing: 10) {
                HStack(spacing: 10) {
                    RoundIcon(systemName: "plus", label: "New box", action: onNew)
                    RoundIcon(systemName: "magnifyingglass", label: "Search", action: onSearch)
                    RoundIcon(systemName: "gearshape", label: "Settings", action: onSettings)
                }
            }
            .padding(.bottom, 4)
        }
        .padding(.horizontal, 4)
    }

    /// Result card, change pill and mic. Content scrolls under it and fades instead of colliding.
    private var bottomBar: some View {
        VStack(spacing: 12) {
            if let card = model.card {
                ResultCard(model: card, onClose: onCloseCard)
                    .padding(.horizontal, 16)
                    .transition(.move(edge: .bottom).combined(with: .opacity))
            }
            if let pill = model.pill {
                ChangePill(text: pill, undo: model.pillUndo ? onUndo : nil)
                    .transition(.scale(scale: 0.9).combined(with: .opacity))
            }
            MicButton(action: onTalk)
        }
        .padding(.top, 16)
        .padding(.bottom, 0)
        .frame(maxWidth: .infinity)
        .background(alignment: .top) {
            LinearGradient(colors: [Palette.background.opacity(0), Palette.background],
                           startPoint: .top, endPoint: UnitPoint(x: 0.5, y: 0.25))
                .ignoresSafeArea(edges: .bottom)
        }
    }
}

struct RoundIcon: View {
    let systemName: String
    let label: String
    var action: () -> Void = {}
    @State private var taps = 0

    var body: some View {
        Button {
            taps += 1
            action()
        } label: {
            Image(systemName: systemName)
                .font(.system(size: 16, weight: .medium))
                .foregroundStyle(Palette.text)
                .frame(width: 42, height: 42)
                .glassCircle()
        }
        .buttonStyle(.plain)
        .sensoryFeedback(.selection, trigger: taps)
        .accessibilityLabel(label)
    }
}

/// While you talk to Friday: the aurora fills the sheet and moves with your voice, the orb
/// swells as you speak, and the words appear in a calm serif.
struct TalkingSheet: View {
    let transcript: String
    let levels: [CGFloat]
    var onCancel: () -> Void = {}
    var onDone: () -> Void = {}

    private var level: Double {
        let recent = levels.suffix(6)
        return recent.isEmpty ? 0 : Double(recent.reduce(0, +)) / Double(recent.count)
    }

    var body: some View {
        VStack(spacing: 22) {
            Capsule().fill(Palette.grabber).frame(width: 36, height: 5)
            Text("I'm listening…")
                .cursive(30)
                .foregroundStyle(Palette.text.opacity(0.75))
            VoiceOrb(size: 112, level: level, listening: true)
                .frame(height: 170)
            LiveWave(levels: levels, color: Palette.text, height: 54)
                .padding(.horizontal, 8)
            if !transcript.isEmpty && transcript != "Listening" {
                Text(transcript)
                    .scaledFont(21, .regular, relativeTo: .title3, serif: true)
                    .foregroundStyle(Palette.text)
                    .lineSpacing(5)
                    .lineLimit(4)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .transition(.opacity)
            }
            Spacer(minLength: 0)
            HStack(spacing: 12) {
                CapsuleButton(title: "Cancel", style: .secondary, action: onCancel)
                CapsuleButton(title: "Done", systemImage: "checkmark", action: onDone)
            }
        }
        .padding(.top, 12)
        .padding(.horizontal, 24)
        .padding(.bottom, 14)
        .frame(height: 520)
        .frame(maxWidth: .infinity)
        .background {
            ZStack {
                Palette.card
                AuroraMesh(energy: min(1, level * 1.4), speed: 0.3).opacity(0.85)
            }
            .clipShape(UnevenRoundedRectangle(topLeadingRadius: 34, topTrailingRadius: 34, style: .continuous))
        }
        .shadow(color: .black.opacity(0.14), radius: 30, y: -6)
    }
}
