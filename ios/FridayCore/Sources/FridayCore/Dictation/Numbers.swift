import Foundation

/// Writes rupee amounts the Indian way: "48500 rupees", "Rs. 48,500", "INR 48500" → "₹48,500";
/// "₹150000" → "₹1,50,000"; "5 lakh rupees" → "₹5 lakh". Only numbers with a rupee cue
/// (₹, Rs, INR, rupee/rupees) are touched, so years, times, phone numbers, PIN codes,
/// percentages, "$" amounts and plain numbers stay as they are.
public enum Money {
    public static func format(_ text: String) -> String {
        // "the 2500 lab fee", "owes me 850": money words that mean rupees without saying so.
        var t = Rx.replace(text, feeAfter, with: "₹$1$2")
        t = Rx.replace(t, owedBefore, with: "$1₹$2")
        guard Rx.contains(t, "₹|rs|inr|rupee") else { return t }
        t = Rx.replace(t, prefixed) { rewrite($0) }
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

    /// A bare amount (≥ 2 digits) followed within two words by fee/rent/deposit/fine/bill.
    private static let feeAfter = ("(?<![\\p{L}\\p{N}:.,₹$])(\\d{2,}(?:,\\d{2,3})*)((?:\\s+[a-z]+){0,2}\\s+(?:fees?|rent|deposit|fine|bill)" + Rx.wordEnd + ")")
    /// "owes me 850", "paid 2000", "costs 1200" (not followed by a unit like pages or km).
    private static let owedBefore = (Rx.wordStart + "((?:owes?|owed)(?:\\s+(?:me|you|us|him|her))?\\s+|paid\\s+|costs?\\s+|spent\\s+)(\\d{2,}(?:,\\d{2,3})*)(?![\\p{N}:.%])(?!\\s*(?:%|pages?|km|kms|kg|kgs|g|gb|mb|hours?|hrs?|minutes?|mins?|people|times|marks|points|steps|days?|weeks?|months?|years?|dollars|usd|\\$))")

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
