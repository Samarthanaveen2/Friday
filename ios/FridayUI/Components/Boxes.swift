import SwiftUI

/// One box on home: a note, idea, list, or the Money box.
struct BoxModel: Identifiable, Equatable {
    enum Kind: Equatable {
        case note
        /// Lines like ("Rahul owes you", "₹150", .positive).
        case money(lines: [MoneyLine])
    }

    struct MoneyLine: Equatable {
        enum Tone: Equatable { case positive, negative, neutral }
        var label: String
        var amount: String
        var tone: Tone = .neutral
    }

    var id: String
    var title: String?
    var text: String
    var kind: Kind = .note
    var reminder: String?
    var pinned = false
    var highlighted = false
    /// Change note after Done ("New", "Edited").
    var note: String?

    /// Rough height, used to balance the two columns.
    var weight: Int {
        switch kind {
        case .money(let lines): return 3 + lines.count * 2
        case .note:
            let lines = min(8, text.count / 18 + 1 + text.filter { $0 == "\n" }.count)
            return (title == nil ? 1 : 3) + lines + (reminder == nil ? 0 : 2)
        }
    }
}

struct BoxCard: View {
    let box: BoxModel
    var onOpen: () -> Void = {}

    var body: some View {
        Button(action: onOpen) {
            VStack(alignment: .leading, spacing: 8) {
                HStack(alignment: .firstTextBaseline, spacing: 6) {
                    if let title = box.title {
                        Text(title)
                            .scaledFont(16, .semibold)
                            .foregroundStyle(Palette.text)
                            .lineLimit(2)
                    }
                    Spacer(minLength: 0)
                    if box.pinned {
                        Image(systemName: "pin.fill")
                            .font(.system(size: 11, weight: .semibold))
                            .foregroundStyle(Palette.tertiary)
                            .rotationEffect(.degrees(40))
                            .accessibilityLabel("Pinned")
                    }
                }
                switch box.kind {
                case .note:
                    Text(box.text)
                        .scaledFont(15)
                        .foregroundStyle(Palette.alsoText)
                        .lineLimit(8)
                        .lineSpacing(2)
                        .multilineTextAlignment(.leading)
                case .money(let lines):
                    VStack(alignment: .leading, spacing: 6) {
                        ForEach(Array(lines.enumerated()), id: \.offset) { _, line in
                            HStack(alignment: .firstTextBaseline) {
                                Text(line.label).scaledFont(14).foregroundStyle(Palette.secondary).lineLimit(1)
                                Spacer(minLength: 6)
                                Text(line.amount)
                                    .scaledFont(15, .semibold, digits: true)
                                    .foregroundStyle(color(line.tone))
                            }
                        }
                    }
                }
                if box.reminder != nil || box.note != nil {
                    HStack(spacing: 6) {
                        if let reminder = box.reminder {
                            Label(reminder, systemImage: "bell.fill")
                                .scaledFont(12, .semibold, relativeTo: .caption)
                                .foregroundStyle(Palette.secondary)
                                .padding(.horizontal, 8)
                                .frame(height: 24)
                                .background(Palette.raised, in: Capsule())
                        }
                        if let note = box.note {
                            Text(note).scaledFont(12, .semibold, relativeTo: .caption).foregroundStyle(Palette.accent)
                        }
                    }
                }
            }
            .padding(16)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(box.highlighted ? Palette.changeTint : Palette.card,
                        in: RoundedRectangle(cornerRadius: Theme.radius, style: .continuous))
        }
        .buttonStyle(PressScale())
    }

    private func color(_ tone: BoxModel.MoneyLine.Tone) -> Color {
        switch tone {
        case .positive: Palette.pass
        case .negative: Palette.stop
        case .neutral: Palette.text
        }
    }
}

/// Two columns like Keep: each box goes to the shorter column, keeping the order top to bottom.
struct BoxGrid: View {
    let boxes: [BoxModel]
    var zoom: Namespace.ID?
    var onOpen: (String) -> Void = { _ in }

    var body: some View {
        let columns = BoxGrid.split(boxes)
        HStack(alignment: .top, spacing: 12) {
            ForEach(0..<2, id: \.self) { column in
                LazyVStack(spacing: 12) {
                    ForEach(columns[column]) { box in
                        BoxCard(box: box) { onOpen(box.id) }
                            .zoomSource(id: box.id, in: zoom)
                            .transition(.opacity)
                    }
                }
                .frame(maxWidth: .infinity, alignment: .top)
            }
        }
    }

    static func split(_ boxes: [BoxModel]) -> [[BoxModel]] {
        var columns: [[BoxModel]] = [[], []]
        var heights = [0, 0]
        for box in boxes {
            let target = heights[0] <= heights[1] ? 0 : 1
            columns[target].append(box)
            heights[target] += box.weight + 2
        }
        return columns
    }
}

extension View {
    /// Marks a card as the start of the zoom into its box (when the app supplies a namespace).
    @ViewBuilder func zoomSource(id: String, in namespace: Namespace.ID?) -> some View {
        if let namespace {
            matchedTransitionSource(id: id, in: namespace) { $0.clipShape(RoundedRectangle(cornerRadius: Theme.radius, style: .continuous)) }
        } else {
            self
        }
    }
}
