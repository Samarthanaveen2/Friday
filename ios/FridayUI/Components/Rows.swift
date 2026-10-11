import SwiftUI

/// One line in the Today strip. The app maps its items onto this.
struct RowModel: Identifiable, Equatable {
    var id: String
    var title: String
    var time: String?
    var done = false
    /// Named as a priority today: accent dot, sorted to the top.
    var priority = false
    /// Short change note after Done ("New", "from 14:00", "→ Sun"), shown for ~5 s.
    var note: String?
    var highlighted = false
    /// Read-only calendar event: a coloured dot instead of a tick circle.
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

struct StripRow: View {
    let row: RowModel
    var onToggle: () -> Void = {}

    var body: some View {
        HStack(spacing: 4) {
            if let color = row.calendarColor {
                Circle().fill(color).frame(width: 8, height: 8).frame(width: 44, height: 44)
                    .accessibilityHidden(true)
            } else {
                Button(action: onToggle) { CheckCircle(done: row.done, size: 22) }
                    .buttonStyle(.plain)
                    .accessibilityLabel(row.done ? "Mark not done: \(row.title)" : "Mark done: \(row.title)")
            }
            HStack(alignment: .firstTextBaseline, spacing: 7) {
                if row.priority && !row.done {
                    Circle().fill(Palette.accent).frame(width: 7, height: 7)
                        .alignmentGuide(.firstTextBaseline) { $0[.bottom] - 1 }
                        .accessibilityLabel("Priority")
                }
                Text(row.title)
                    .scaledFont(16, row.priority ? .semibold : .regular)
                    .strikethrough(row.done, color: Palette.secondary)
                    .foregroundStyle(row.done ? Palette.secondary : Palette.text)
                    .lineLimit(1)
                if let note = row.note {
                    Text(note).scaledFont(13, .semibold, relativeTo: .footnote).foregroundStyle(Palette.accent)
                        .lineLimit(1)
                }
            }
            Spacer(minLength: 8)
            if let time = row.time {
                Text(time).scaledFont(15, .medium, digits: true).foregroundStyle(Palette.secondary)
            }
        }
        .padding(.trailing, 14)
        .frame(minHeight: 46)
        .background(row.highlighted ? Palette.changeTint : Color.clear)
    }
}

/// The thin card at the top of home: today's items, priorities first, up to 4 rows.
struct TodayStrip: View {
    let rows: [RowModel]
    var next: (title: String, when: String)?
    var limit = 4
    var onToggle: (String) -> Void = { _ in }
    @State private var expanded = false

    var body: some View {
        VStack(spacing: 0) {
            let open = rows.filter { !$0.done }
            if open.isEmpty {
                emptyLine
            }
            let shown = expanded ? rows : Array(rows.prefix(limit))
            ForEach(Array(shown.enumerated()), id: \.element.id) { index, row in
                StripRow(row: row) { onToggle(row.id) }
                if index < shown.count - 1 {
                    Rectangle().fill(Palette.separator).frame(height: 1).padding(.leading, 48)
                }
            }
            if rows.count > limit {
                Button {
                    withAnimation(Motion.spring) { expanded.toggle() }
                } label: {
                    Text(expanded ? "Show less" : "+\(rows.count - limit) more")
                        .scaledFont(14, .semibold, relativeTo: .subheadline)
                        .foregroundStyle(Palette.accent)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.leading, 48)
                        .frame(height: 40)
                }
                .buttonStyle(.plain)
            }
        }
        .background(Palette.card)
        .clipShape(RoundedRectangle(cornerRadius: Theme.radius, style: .continuous))
    }

    private var emptyLine: some View {
        Group {
            if let next {
                (Text("Nothing left today · ").foregroundStyle(Palette.secondary)
                    + Text("Next: ").foregroundStyle(Palette.secondary)
                    + Text(next.title).fontWeight(.semibold).foregroundStyle(Palette.text)
                    + Text(" · \(next.when)").foregroundStyle(Palette.secondary))
            } else {
                Text("Nothing today").foregroundStyle(Palette.secondary)
            }
        }
        .scaledFont(15, relativeTo: .subheadline)
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 16)
        .frame(minHeight: 50)
    }
}
