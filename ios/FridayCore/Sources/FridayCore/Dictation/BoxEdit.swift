import Foundation

/// "Talk to this box" when what you say is an instruction for Friday ("Friday, make this a
/// checklist", "Friday, remove the eggs", "Friday, what's left to buy?"): the AI edits the
/// whole box instead of the words being added to it.
public enum BoxEdit {
    /// True when the dictation is just a Friday command or question (it starts with "Friday,").
    /// "Add milk" or "…eggs. Friday, make that a list" (words first) stay normal dictation.
    public static func isEdit(_ dictation: String) -> Bool {
        let t = dictation.trimmingCharacters(in: .whitespacesAndNewlines)
        guard Rx.contains(t, "^(?:hey\\s+|okay\\s+|ok\\s+)?friday\\b") else { return false }
        return Dictation.hasCommand(t) || Dictation.asksFriday(t)
    }

    public static let systemPrompt = """
    You edit a note for the user. Apply their spoken INSTRUCTION to the NOTE and reply with the whole updated note inside <out></out>, nothing else.
    - Keep every part the instruction doesn't touch exactly as it is, word for word.
    - "Cancel/remove/delete X" removes the line or item about X; "mark X done" ticks it ("- [x]").
    - Checklist items are lines "- [ ] item" (done: "- [x] item"). "Make this a checklist" turns items into such lines; a lead-in line stays first.
    - If the instruction is a question about the note ("what's left?", "how much in total?"), keep the note and add one short answer line at the end.
    - Never invent items, names or numbers that aren't in the note or the instruction.
    Example: <note>Buy chicken, eggs and vegetables</note><instruction>Friday, make this a checklist</instruction> -> <out>- [ ] Chicken
    - [ ] Eggs
    - [ ] Vegetables</out>
    """

    public static func message(note: String, instruction: String) -> String {
        "<note>\(note)</note>\n<instruction>\(instruction)</instruction>"
    }

    /// Guard: no made-up numbers (unless it's a question), and not wildly longer than the note.
    public static func accept(output: String, note: String, instruction: String) -> Bool {
        let out = output.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !out.isEmpty, out.count <= note.count * 2 + 200 else { return false }
        if Dictation.asksFriday(instruction) { return true }
        let known = Set(numbers(note) + numbers(instruction))
        return numbers(out).allSatisfy(known.contains)
    }

    static func numbers(_ text: String) -> [String] {
        Words.split(text.replacingOccurrences(of: ",", with: "")).filter { $0.first?.isNumber == true }
    }
}
