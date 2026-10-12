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
    var color: BoxColor = .white
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

/// The soft colours a box can have (long-press → Colour). Keys are what's saved.
enum BoxColor: String, CaseIterable, Identifiable {
    case white, sand, sage, sky, lavender, rose

    var id: String { rawValue }
    var name: String { rawValue.capitalized }
    var fill: Color {
        switch self {
        case .white: Palette.background
        case .sand: Color(.sRGB, red: 1.0, green: 0.957, blue: 0.863)
        case .sage: Color(.sRGB, red: 0.910, green: 0.953, blue: 0.902)
        case .sky: Color(.sRGB, red: 0.890, green: 0.937, blue: 0.988)
        case .lavender: Color(.sRGB, red: 0.933, green: 0.910, blue: 0.984)
        case .rose: Color(.sRGB, red: 0.984, green: 0.906, blue: 0.925)
        }
    }

    init(key: String?) { self = key.flatMap(BoxColor.init(rawValue:)) ?? .white }
    /// What to save: nil for white.
    var key: String? { self == .white ? nil : rawValue }
}

/// What long-press (or a box's ⋯ menu) can do.
enum BoxAction: Equatable {
    case pin, reminder, delete
    case color(BoxColor)
}

/// The shared menu: Pin, Reminder, Colour, Delete.
struct BoxMenuItems: View {
    let pinned: Bool
    let color: BoxColor
    var onAction: (BoxAction) -> Void

    var body: some View {
        Button(pinned ? "Unpin" : "Pin to top", systemImage: pinned ? "pin.slash" : "pin") { onAction(.pin) }
        Button("Reminder", systemImage: "bell") { onAction(.reminder) }
        Menu {
            ForEach(BoxColor.allCases) { option in
                Button {
                    onAction(.color(option))
                } label: {
                    if option == color { Label(option.name, systemImage: "checkmark") } else { Text(option.name) }
                }
            }
        } label: {
            Label("Colour", systemImage: "paintpalette")
        }
        Divider()
        Button("Delete", systemImage: "trash", role: .destructive) { onAction(.delete) }
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
            .background(box.highlighted ? Palette.changeTint : box.color.fill,
                        in: RoundedRectangle(cornerRadius: Theme.radius, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: Theme.radius, style: .continuous)
                .strokeBorder(Palette.separator, lineWidth: 1))
            .contentShape(.contextMenuPreview, RoundedRectangle(cornerRadius: Theme.radius, style: .continuous))
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
    /// Long-press actions; nil (previews, the setup box) shows no menu.
    var onAction: ((String, BoxAction) -> Void)?

    var body: some View {
        let columns = BoxGrid.split(boxes)
        HStack(alignment: .top, spacing: 12) {
            ForEach(0..<2, id: \.self) { column in
                LazyVStack(spacing: 12) {
                    ForEach(columns[column]) { box in
                        BoxCard(box: box) { onOpen(box.id) }
                            .zoomSource(id: box.id, in: zoom)
                            .boxMenu(box, onAction)
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

extension View {
    /// Long-press menu on a box (not on the setup box or the Money box).
    @ViewBuilder func boxMenu(_ box: BoxModel, _ onAction: ((String, BoxAction) -> Void)?) -> some View {
        if let onAction, box.id != "setup", box.kind == .note {
            contextMenu {
                BoxMenuItems(pinned: box.pinned, color: box.color) { onAction(box.id, $0) }
            }
        } else {
            self
        }
    }
}
