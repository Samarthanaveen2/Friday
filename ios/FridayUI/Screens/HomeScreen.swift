import SwiftUI

/// Everything home shows. The app builds this from its store.
struct HomeModel: Equatable {
    var dateLabel: String
    var today: [RowModel]
    var next: (title: String, when: String)?
    var boxes: [BoxModel]
    var pill: String?
    var pillUndo = true
    var card: ResultCardModel?

    static func == (a: HomeModel, b: HomeModel) -> Bool {
        a.dateLabel == b.dateLabel && a.today == b.today && a.boxes == b.boxes
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

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                header
                VStack(alignment: .leading, spacing: 8) {
                    SectionLabel(text: "Today", color: Palette.accent)
                    TodayStrip(rows: model.today, next: model.next, onToggle: onToggle)
                }
                BoxGrid(boxes: model.boxes, onOpen: onOpenBox)
            }
            .padding(.horizontal, 14)
            .padding(.top, 8)
            .padding(.bottom, 16)
        }
        .scrollIndicators(.hidden)
        .safeAreaInset(edge: .bottom, spacing: 0) { bottomBar }
        .background(Palette.background.ignoresSafeArea())
        .animation(Motion.spring, value: model)
    }

    private var header: some View {
        HStack(alignment: .bottom) {
            VStack(alignment: .leading, spacing: 2) {
                Text(model.dateLabel.uppercased())
                    .scaledFont(13, .semibold, relativeTo: .footnote)
                    .tracking(0.4)
                    .foregroundStyle(Palette.secondary)
                Text("Friday")
                    .scaledFont(34, .bold, relativeTo: .largeTitle)
                    .tracking(0.3)
                    .foregroundStyle(Palette.text)
            }
            Spacer()
            HStack(spacing: 10) {
                RoundIcon(systemName: "magnifyingglass", label: "Search", action: onSearch)
                RoundIcon(systemName: "gearshape", label: "Settings", action: onSettings)
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
        .padding(.bottom, 12)
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

    var body: some View {
        Button(action: action) {
            Image(systemName: systemName)
                .font(.system(size: 16, weight: .medium))
                .foregroundStyle(Palette.secondary)
                .frame(width: 36, height: 36)
                .background(Palette.card, in: Circle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel(label)
    }
}

/// The bottom sheet while you talk to Friday: waveform, live words, Cancel / Done.
struct TalkingSheet: View {
    let transcript: String
    let levels: [CGFloat]
    var onCancel: () -> Void = {}
    var onDone: () -> Void = {}

    var body: some View {
        VStack(spacing: 20) {
            Capsule().fill(Palette.grabber).frame(width: 36, height: 5)
            Waveform(levels: levels)
            (Text(transcript).foregroundStyle(Palette.text) + Text(" …").foregroundStyle(Palette.tertiary))
                .scaledFont(20, .medium, relativeTo: .title3)
                .lineSpacing(6)
                .frame(maxWidth: .infinity, alignment: .leading)
            Spacer(minLength: 0)
            HStack(spacing: 12) {
                CapsuleButton(title: "Cancel", style: .secondary, action: onCancel)
                CapsuleButton(title: "Done", systemImage: "checkmark", action: onDone)
            }
        }
        .padding(.top, 12)
        .padding(.horizontal, 24)
        .padding(.bottom, 12)
        .frame(height: 400)
        .background(Palette.card, in: UnevenRoundedRectangle(topLeadingRadius: 28, topTrailingRadius: 28, style: .continuous))
        .shadow(color: .black.opacity(0.12), radius: 30, y: -8)
    }
}
