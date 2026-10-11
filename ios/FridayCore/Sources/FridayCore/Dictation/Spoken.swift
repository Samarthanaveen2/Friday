import Foundation

/// Spoken symbols in emails, links and numbers, turned into the real thing before cleanup
/// so neither the AI nor the rules have to guess: "samarth underscore n07 at gmail dot com",
/// "forms dot gle slash friday", "98450 12346".
public enum Spoken {
    static let tlds: Set<String> = ["com", "in", "org", "net", "io", "ai", "co", "edu", "dev", "app", "gle", "ly", "me", "gg", "xyz", "us", "uk"]

    /// Applied to the transcript (before cleanup).
    public static func symbols(_ text: String) -> String {
        var t = text
        // "n underscore 07" -> "n_07"
        t = Rx.replace(t, "([\\p{L}\\p{N}])\\s+underscore\\s+([\\p{L}\\p{N}])", with: "$1_$2")
        // "forms dot gle slash friday", "iitkgp dot ac dot in": join when it's clearly an address.
        t = Rx.replace(t, address) { piece in
            let lower = piece.lowercased()
            let parts = lower.components(separatedBy: " dot ")
            let last = parts.last?.components(separatedBy: " slash ").first ?? ""
            guard lower.contains(" slash ") || tlds.contains(last.trimmingCharacters(in: .whitespaces)) else { return piece }
            return Rx.replace(Rx.replace(piece, "\\s+dot\\s+", with: "."), "\\s+slash\\s+", with: "/")
        }
        // "forms.gle slash friday" (dot already written by speech-to-text)
        t = Rx.replace(t, "([\\p{L}\\p{N}-]+\\.[\\p{L}]{2,})\\s+slash\\s+([\\p{L}\\p{N}_-]+)", with: "$1/$2")
        // "samarth_n07 at gmail.com" -> email
        // (not "the form is at forms.gle/x": a link, and "is" is no one's name)
        t = Rx.replace(t, email) { match in
            let local = match.components(separatedBy: " ").first ?? ""
            guard !notNames.contains(local.lowercased()) else { return match }
            return Rx.replace(match, "\\s+at\\s+", with: "@")
        }
        return t
    }

    private static let email = Rx.make(Rx.wordStart + "[\\p{L}\\p{N}._-]+\\s+at\\s+[\\p{L}\\p{N}-]+(?:\\.[\\p{L}]{2,})+(?![/\\p{L}\\p{N}])")
    static let notNames: Set<String> = ["is", "it", "me", "us", "him", "her", "them", "here", "there", "was", "are", "be",
                                        "form", "link", "site", "page", "available", "online", "posted", "live", "up", "out"]

    private static let address = Rx.make("(?<![\\p{L}\\p{N}])[\\p{L}\\p{N}_-]+(?:\\s+dot\\s+[\\p{L}\\p{N}_-]+)+(?:\\s+slash\\s+[\\p{L}\\p{N}_-]+)*")

    /// Applied to the final text: a 10-digit Indian mobile number split by dashes or spaces
    /// ("984-50-12346", "98450 12346") is written as one number.
    public static func phoneNumbers(_ text: String) -> String {
        Rx.replace(text, phone) { match in
            let digits = match.filter(\.isNumber)
            return digits.count == 10 ? digits : match
        }
    }

    private static let phone = Rx.make("(?<![\\p{N}-])[6-9]\\d{1,4}(?:[-\\s]\\d{1,5}){1,3}(?![\\p{N}-])")
}
