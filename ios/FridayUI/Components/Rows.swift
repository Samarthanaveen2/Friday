import SwiftUI

/// What a Today row shows. The app maps its items onto this.
struct RowModel: Identifiable, Equatable {
    var id: String
    var title: String
    var time: String?
    var done = false
    /// Short change note after Done ("New", "from 14:00", "→ Sun"), shown for ~5 s.
    var note: String?
    var highlighted = false
    /// Read-only calendar event: a coloured dot instead of a checkbox.
    var calendarColor: Color?
}

struct CheckCircle: View {
    let done: Bool
    let size: CGFloat

    var body: some View {
        Image(systemName: done ? "checkmark.circle.fill" : "circle")
            .font(.system(size: size, weight: .regular))
            .symbolRenderingMode(.palette)
            .foregroundStyle(done ? Color.white : Palette.tertiary, Palette.accent)
            .contentTransition(.symbolEffect(.replace))
            .frame(width: 44, height: 44)
            .contentShape(Rectangle())
    }
}

struct SectionLabel: View {
    let text: String
    var color: Color = Palette.secondary

    var body: some View {
        Text(text.uppercased())
            .scaledFont(13, .bold, relativeTo: .footnote)
            .tracking(0.4)
            .foregroundStyle(color)
            .padding(.horizontal, 4)
    }
}

/// A big Focus row inside the white card.
struct FocusRow: View {
    let row: RowModel
    var onToggle: () -> Void = {}

    var body: some View {
        HStack(spacing: 8) {
            Button(action: onToggle) { CheckCircle(done: row.done, size: 26) }
                .buttonStyle(.plain)
                .accessibilityLabel(row.done ? "Mark not done: \(row.title)" : "Mark done: \(row.title)")
            VStack(alignment: .leading, spacing: 1) {
                Text(row.title)
                    .scaledFont(18, .semibold)
                    .strikethrough(row.done, color: Palette.secondary)
                    .foregroundStyle(row.done ? Palette.secondary : Palette.text)
                if let note = row.note {
                    Text(note).scaledFont(13, .semibold, relativeTo: .footnote).foregroundStyle(Palette.accent)
                }
            }
            Spacer(minLength: 8)
            if let time = row.time {
                Text(time).scaledFont(16, .medium, digits: true).foregroundStyle(Palette.secondary)
            }
        }
        .padding(.leading, 6)
        .padding(.trailing, 16)
        .padding(.vertical, 8)
        .frame(minHeight: 68)
        .background(row.highlighted ? Palette.changeTint : Palette.card)
    }
}

/// A small grey Also row, no card.
struct AlsoRow: View {
    let row: RowModel
    var onToggle: () -> Void = {}

    var body: some View {
        HStack(spacing: 4) {
            if let color = row.calendarColor {
                Circle().fill(color).frame(width: 8, height: 8).frame(width: 44, height: 44)
                    .accessibilityHidden(true)
            } else {
                Button(action: onToggle) { CheckCircle(done: row.done, size: 20) }
                    .buttonStyle(.plain)
                    .accessibilityLabel(row.done ? "Mark not done: \(row.title)" : "Mark done: \(row.title)")
            }
            HStack(alignment: .firstTextBaseline, spacing: 8) {
                Text(row.title)
                    .scaledFont(15)
                    .strikethrough(row.done, color: Palette.secondary)
                    .foregroundStyle(row.done ? Palette.secondary : Palette.alsoText)
                if let note = row.note {
                    Text(note).scaledFont(13, .semibold, relativeTo: .footnote).foregroundStyle(Palette.accent)
                }
            }
            Spacer(minLength: 8)
            if let time = row.time {
                Text(time).scaledFont(14, digits: true).foregroundStyle(Palette.secondary)
            }
        }
        .padding(.trailing, 8)
        .frame(minHeight: 44)
        .background(row.highlighted ? Palette.changeTint : Color.clear, in: RoundedRectangle(cornerRadius: 10, style: .continuous))
    }
}

struct FocusCard: View {
    let rows: [RowModel]
    var emptyText = "Say what matters today."
    var onToggle: (String) -> Void = { _ in }

    var body: some View {
        VStack(spacing: 0) {
            if rows.isEmpty {
                Text(emptyText)
                    .scaledFont(16)
                    .foregroundStyle(Palette.secondary)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.horizontal, 16)
                    .frame(minHeight: 60)
            }
            ForEach(Array(rows.enumerated()), id: \.element.id) { index, row in
                FocusRow(row: row) { onToggle(row.id) }
                if index < rows.count - 1 {
                    Rectangle().fill(Palette.separator).frame(height: 1).padding(.leading, 56)
                }
            }
        }
        .background(Palette.card)
        .clipShape(RoundedRectangle(cornerRadius: Theme.radius, style: .continuous))
    }
}
