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
    var talk: TalkState = .idle

    static func == (a: HomeModel, b: HomeModel) -> Bool {
        a.dateLabel == b.dateLabel && a.today == b.today && a.boxes == b.boxes
            && a.next?.title == b.next?.title && a.next?.when == b.next?.when
            && a.pill == b.pill && a.pillUndo == b.pillUndo && a.card == b.card && a.talk == b.talk
    }
}

/// One quiet page, like Notes: today's list, then your boxes, and the talk pill.
struct HomeScreen: View {
    let model: HomeModel
    var onToggle: (String) -> Void = { _ in }
    var onOpenBox: (String) -> Void = { _ in }
    var onTalk: () -> Void = {}
    var onCancelTalk: () -> Void = {}
    var onDoneTalk: () -> Void = {}
    var onUndo: () -> Void = {}
    var onSearch: () -> Void = {}
    var onSettings: () -> Void = {}
    var onCloseCard: () -> Void = {}
    var onNew: () -> Void = {}
    /// For the zoom from a box tile into the box (set by the app; nil in previews).
    var zoom: Namespace.ID?

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 28) {
                header
                VStack(alignment: .leading, spacing: 6) {
                    SectionLabel(text: "Today")
                    TodayStrip(rows: model.today, next: model.next, onToggle: onToggle)
                }
                if !model.boxes.isEmpty {
                    VStack(alignment: .leading, spacing: 10) {
                        SectionLabel(text: "Boxes")
                        BoxGrid(boxes: model.boxes, zoom: zoom, onOpen: onOpenBox)
                    }
                }
            }
            .padding(.horizontal, 16)
            .padding(.top, 4)
            .padding(.bottom, 24)
        }
        .scrollIndicators(.hidden)
        .safeAreaInset(edge: .bottom, spacing: 0) { bottomBar }
        .background(Palette.background.ignoresSafeArea())
        .animation(Motion.spring, value: model.boxes)
        .animation(Motion.spring, value: model.pill)
    }

    private var header: some View {
        HStack(alignment: .firstTextBaseline) {
            VStack(alignment: .leading, spacing: 2) {
                Text(model.dateLabel)
                    .scaledFont(13, .semibold, relativeTo: .footnote)
                    .foregroundStyle(Palette.secondary)
                Text("Friday")
                    .scaledFont(34, .bold, relativeTo: .largeTitle)
                    .foregroundStyle(Palette.text)
            }
            Spacer()
            HStack(spacing: 18) {
                Button(action: onNew) {
                    Image(systemName: "square.and.pencil")
                }
                .accessibilityLabel("New box")
                Menu {
                    Button("Search", systemImage: "magnifyingglass", action: onSearch)
                    Button("Settings", systemImage: "gearshape", action: onSettings)
                } label: {
                    Image(systemName: "ellipsis.circle")
                }
                .accessibilityLabel("More")
            }
            .font(.system(size: 21, weight: .regular))
            .foregroundStyle(Palette.text)
            .buttonStyle(.plain)
        }
        .padding(.top, 8)
    }

    /// Result card, change pill and the talk pill. Content fades out under it (plain gradient).
    private var bottomBar: some View {
        VStack(spacing: 12) {
            if let card = model.card {
                ResultCard(model: card, onClose: onCloseCard)
                    .padding(.horizontal, 16)
                    .transition(.move(edge: .bottom).combined(with: .opacity))
            }
            if let pill = model.pill {
                ChangePill(text: pill, undo: model.pillUndo ? onUndo : nil)
                    .transition(.opacity.combined(with: .move(edge: .bottom)))
            }
            TalkPill(state: model.talk, onTalk: onTalk, onCancel: onCancelTalk, onDone: onDoneTalk)
        }
        .padding(.top, 20)
        .padding(.bottom, 8)
        .frame(maxWidth: .infinity)
        .background(alignment: .top) {
            LinearGradient(colors: [Palette.background.opacity(0), Palette.background],
                           startPoint: .top, endPoint: UnitPoint(x: 0.5, y: 0.35))
                .ignoresSafeArea(edges: .bottom)
        }
    }
}
