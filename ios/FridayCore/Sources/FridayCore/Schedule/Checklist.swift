import Foundation

/// A box's text read as lines, where "- [ ] milk" / "- [x] milk" (or "☐ milk" / "☑ milk")
/// are tappable checklist items and everything else is plain text.
public struct Checklist: Equatable, Sendable {
    public enum Line: Equatable, Sendable {
        case check(done: Bool, text: String)
        case text(String)
    }

    public var lines: [Line]

    public init(_ text: String) {
        lines = text.isEmpty ? [] : text.components(separatedBy: "\n").map(Checklist.parse)
    }

    public init(lines: [Line]) {
        self.lines = lines
    }

    /// Whether the box has any checklist items (then the box page shows checkboxes).
    public var hasItems: Bool {
        lines.contains { if case .check = $0 { return true } else { return false } }
    }

    public var text: String {
        lines.map { line in
            switch line {
            case .check(let done, let text): (done ? "- [x] " : "- [ ] ") + text
            case .text(let text): text
            }
        }
        .joined(separator: "\n")
    }

    public mutating func toggle(at index: Int) {
        guard lines.indices.contains(index), case .check(let done, let text) = lines[index] else { return }
        lines[index] = .check(done: !done, text: text)
    }

    public mutating func setText(_ value: String, at index: Int) {
        guard lines.indices.contains(index) else { return }
        switch lines[index] {
        case .check(let done, _): lines[index] = .check(done: done, text: value)
        case .text: lines[index] = .text(value)
        }
    }

    public mutating func add(_ item: String = "") {
        lines.append(.check(done: false, text: item))
    }

    public mutating func remove(at index: Int) {
        guard lines.indices.contains(index) else { return }
        lines.remove(at: index)
    }

    /// Every non-empty line becomes an item ("- a" bullets lose their dash).
    public static func makeChecklist(_ text: String) -> String {
        Checklist(lines: Checklist(text).lines.compactMap { line in
            switch line {
            case .check: return line
            case .text(let t):
                var item = t.trimmingCharacters(in: .whitespaces)
                for bullet in ["- ", "• ", "* "] where item.hasPrefix(bullet) { item.removeFirst(bullet.count) }
                return item.isEmpty ? nil : .check(done: false, text: item)
            }
        }).text
    }

    /// Items back to plain "- item" lines.
    public static func makePlain(_ text: String) -> String {
        Checklist(lines: Checklist(text).lines.map { line in
            if case .check(_, let t) = line { return .text("- " + t) }
            return line
        }).text
    }

    static func parse(_ raw: String) -> Line {
        let line = raw.trimmingCharacters(in: .whitespaces)
        for (prefix, done) in [("- [ ] ", false), ("- [x] ", true), ("- [X] ", true), ("[ ] ", false), ("[x] ", true),
                               ("☐ ", false), ("☑ ", true), ("✓ ", true)] where line.hasPrefix(prefix) {
            return .check(done: done, text: String(line.dropFirst(prefix.count)))
        }
        for (empty, done) in [("- [ ]", false), ("- [x]", true), ("☐", false), ("☑", true)] where line == empty {
            return .check(done: done, text: "")
        }
        return .text(raw)
    }
}
