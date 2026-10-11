import SwiftUI

/// Everything the Today screen shows. The app builds this from its store.
struct TodayModel: Equatable {
    enum Tab: String, CaseIterable { case today = "Today", notes = "Notes", money = "Money" }

    var dateLabel: String
    var focus: [RowModel]
    var also: [RowModel]
    var next: (title: String, when: String)?
    var pill: String?
    var pillUndo = true
    var card: ResultCardModel?

    static func == (a: TodayModel, b: TodayModel) -> Bool {
        a.dateLabel == b.dateLabel && a.focus == b.focus && a.also == b.also
            && a.next?.title == b.next?.title && a.next?.when == b.next?.when
            && a.pill == b.pill && a.pillUndo == b.pillUndo && a.card == b.card
    }
}

struct TodayScreen: View {
    let model: TodayModel
    @Binding var tab: TodayModel.Tab
    var onToggle: (String) -> Void = { _ in }
    var onTalk: () -> Void = {}
    var onUndo: () -> Void = {}
    var onSettings: () -> Void = {}
    var onCloseCard: () -> Void = {}

    var body: some View {
        ZStack(alignment: .bottom) {
            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    header
                    Picker("Screen", selection: $tab) {
                        ForEach(TodayModel.Tab.allCases, id: \.self) { Text($0.rawValue).tag($0) }
                    }
                    .pickerStyle(.segmented)

                    VStack(alignment: .leading, spacing: 8) {
                        SectionLabel(text: "Focus", color: Palette.accent)
                        FocusCard(rows: model.focus, onToggle: onToggle)
                    }

                    if !model.also.isEmpty {
                        VStack(alignment: .leading, spacing: 2) {
                            SectionLabel(text: "Also").padding(.bottom, 4)
                            ForEach(model.also) { row in
                                AlsoRow(row: row) { onToggle(row.id) }
                            }
                        }
                    }

                    if let next = model.next {
                        (Text("Next: ").foregroundStyle(Palette.secondary)
                            + Text(next.title).fontWeight(.semibold).foregroundStyle(Palette.text)
                            + Text(" · \(next.when)").foregroundStyle(Palette.secondary))
                            .scaledFont(14, relativeTo: .subheadline)
                            .padding(.horizontal, 4)
                    }
                }
                .padding(.horizontal, 16)
                .padding(.top, 8)
                .padding(.bottom, 200)
            }
            .scrollIndicators(.hidden)

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
            .padding(.bottom, 12)
        }
        .background(Palette.background.ignoresSafeArea())
        .animation(Motion.spring, value: model)
    }

    private var header: some View {
        HStack(alignment: .top) {
            VStack(alignment: .leading, spacing: 2) {
                Text(model.dateLabel.uppercased())
                    .scaledFont(13, .semibold, relativeTo: .footnote)
                    .tracking(0.4)
                    .foregroundStyle(Palette.secondary)
                Text(tab.rawValue)
                    .scaledFont(34, .bold, relativeTo: .largeTitle)
                    .tracking(0.3)
                    .foregroundStyle(Palette.text)
            }
            Spacer()
            Button(action: onSettings) {
                Image(systemName: "gearshape")
                    .font(.system(size: 17, weight: .medium))
                    .foregroundStyle(Palette.secondary)
                    .frame(width: 36, height: 36)
                    .background(Palette.card, in: Circle())
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Settings")
        }
        .padding(.horizontal, 4)
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
