import Foundation

/// Writes rupee amounts the Indian way: "48500 rupees", "Rs. 48,500", "INR 48500" → "₹48,500";
/// "₹150000" → "₹1,50,000"; "5 lakh rupees" → "₹5 lakh". Only numbers with a rupee cue
/// (₹, Rs, INR, rupee/rupees) are touched, so years, times, phone numbers, PIN codes,
/// percentages, "$" amounts and plain numbers stay as they are.
public enum Money {
    public static func format(_ text: String) -> String {
        guard Rx.contains(text, "₹|rs|inr|rupee") else { return text }
        var t = Rx.replace(text, prefixed) { rewrite($0) }
        t = Rx.replace(t, suffixed) { rewrite($0) }
        return t
    }

    /// "48,500", "1,50,000" or "48500", then optional decimals.
    private static let amount = "(\\d{1,3}(?:,\\d{3})+|\\d{1,2}(?:,\\d{2})+,\\d{3}|\\d+)(?!\\d)(\\.\\d+)?"
    private static let scale = "(?:\\s+(lakhs?|lacs?|crores?))?"
    private static let before = "(?:₹|" + Rx.wordStart + "(?:rs\\.?|inr|rupees?))\\s*"
    private static let after = "(?:rupees?|rs|inr)" + Rx.wordEnd

    /// "₹48500", "Rs. 48,500", "rupees 5 lakh" (a repeated "rupees" after it is dropped).
    private static let prefixed = Rx.make(before + amount + scale + "(?:\\s*" + after + ")?")
    /// "48500 rupees", "5 lakh rupees". Not after ":" or "." so "5:30" and "1.5" stay whole.
    private static let suffixed = Rx.make("(?<![\\p{L}\\p{N}:.,₹])" + amount + scale + "\\s*" + after)

    private static let parts = Rx.make(amount + scale)

    private static func rewrite(_ match: String) -> String {
        let ns = match as NSString
        guard let m = parts.firstMatch(in: match, range: NSRange(location: 0, length: ns.length)) else { return match }
        let whole = ns.substring(with: m.range(at: 1)).replacingOccurrences(of: ",", with: "")
        let decimals = m.range(at: 2).location == NSNotFound ? "" : ns.substring(with: m.range(at: 2))
        if m.range(at: 3).location != NSNotFound {
            // "5 lakh", "2 crore": keep the word, don't group the small number before it.
            return "₹" + whole + decimals + " " + ns.substring(with: m.range(at: 3))
        }
        return "₹" + indianGrouping(whole) + decimals
    }

    /// "48500" → "48,500", "150000" → "1,50,000", "12500000" → "1,25,00,000".
    static func indianGrouping(_ digits: String) -> String {
        guard digits.count > 3 else { return digits }
        var head = Array(digits.dropLast(3))
        var groups = [String(digits.suffix(3))]
        while !head.isEmpty {
            groups.insert(String(head.suffix(2)), at: 0)
            head.removeLast(min(2, head.count))
        }
        return groups.joined(separator: ",")
    }
}
