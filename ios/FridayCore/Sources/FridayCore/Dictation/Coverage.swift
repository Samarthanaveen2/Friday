import Foundation

/// Puts back words the cloud transcript skipped, using the iPhone's own transcript of the same
/// speech. Whisper sometimes silently drops a stretch (often a self-correction like "cancel beans");
/// Apple's on-device recogniser streams the whole time and doesn't skip, though it mishears more.
/// So: keep Whisper's words, and only insert runs that the iPhone heard and Whisper has nothing for.
public enum Coverage {
    /// One word (or a run of number words, which counts as one: "ten thousand" ≈ "10,000").
    struct Unit {
        var key: String
        var text: String
    }

    /// Whisper's text with any skipped runs put back, and the runs that were added.
    public static func fill(primary: String, backup: String) -> (text: String, added: [String]) {
        let p = units(primary)
        let b = units(backup).filter { !Words.fillers.contains($0.key) }
        let unchanged = (primary, [String]())
        // The device must have actually worked, and very long texts aren't worth aligning.
        guard !p.isEmpty, Double(b.count) >= Double(p.count) * 0.6, p.count <= 800, b.count <= 800 else { return unchanged }

        let pairs = align(p.map(\.key), b.map(\.key))
        guard !pairs.isEmpty else { return unchanged }

        // Gaps between matched words: (primary range, backup range).
        var gaps: [(Range<Int>, Range<Int>)] = []
        var lastP = 0, lastB = 0
        for (i, j) in pairs + [(p.count, b.count)] {
            if j - lastB > 0 { gaps.append((lastP..<i, lastB..<j)) }
            lastP = i + 1
            lastB = j + 1
        }

        var insertAt: [Int: [String]] = [:]   // insert before primary unit index
        var replace: [Range<Int>: [String]] = [:]
        var added: [String] = []
        var addedCount = 0
        for (pr, br) in gaps {
            let k = br.count, j = pr.count
            let run = Array(b[br])
            guard run.contains(where: { $0.key == "#" || ($0.key.count >= 4 && !Words.spokenMarks.contains($0.key)) }) else { continue }
            // Already said nearby (e.g. the iPhone also caught a false start of a later phrase):
            // putting it in would type it twice.
            let window = p[max(0, pr.lowerBound - 15)..<min(p.count, pr.upperBound + 15)].map(\.key)
            let shared = longestShared(run.map(\.key), window)
            if shared >= 2 && shared * 2 >= k { continue }
            let texts = run.map(\.text)
            if j == 0 && k >= 2 {
                insertAt[pr.lowerBound, default: []] += texts
            } else if j > 0 && k - j >= 3 {
                replace[pr] = texts
            } else {
                continue
            }
            added.append(texts.joined(separator: " "))
            addedCount += k
        }
        guard !added.isEmpty, Double(addedCount) <= Double(p.count) * 0.4 else { return unchanged }

        var out: [String] = []
        var i = 0
        while i <= p.count {
            if let texts = insertAt[i] { out += texts }
            if let (range, texts) = replace.first(where: { $0.key.lowerBound == i }) {
                out += texts
                i = range.upperBound
                continue
            }
            if i < p.count { out.append(p[i].text) }
            i += 1
        }
        return (out.joined(separator: " "), added)
    }

    /// Words with their original spelling and punctuation; punctuation-only tokens stick to the word before.
    static func units(_ text: String) -> [Unit] {
        var result: [Unit] = []
        for token in text.split(whereSeparator: \.isWhitespace).map(String.init) {
            let key = Words.split(token).joined()
            if key.isEmpty {
                if !result.isEmpty { result[result.count - 1].text += " " + token }
                continue
            }
            let isNumber = key.first?.isNumber == true || Words.numberWords.contains(key)
            if isNumber, let last = result.last, last.key == "#" {
                result[result.count - 1].text += " " + token
            } else {
                result.append(Unit(key: isNumber ? "#" : key, text: token))
            }
        }
        return result
    }

    /// Length of the longest run of words appearing, in order and back to back, in both lists.
    static func longestShared(_ a: [String], _ b: [String]) -> Int {
        guard !a.isEmpty, !b.isEmpty else { return 0 }
        var best = 0
        var previous = Array(repeating: 0, count: b.count + 1)
        for x in a {
            var current = Array(repeating: 0, count: b.count + 1)
            // Numbers don't count: "2,000 rupees" nearby doesn't mean "50,000 rupees" was already said.
            for (j, y) in b.enumerated() where x == y && x != "#" {
                current[j + 1] = previous[j] + 1
                best = max(best, current[j + 1])
            }
            previous = current
        }
        return best
    }

    /// Longest common subsequence: matched index pairs, in order.
    static func align(_ a: [String], _ b: [String]) -> [(Int, Int)] {
        let n = a.count, m = b.count
        guard n > 0, m > 0 else { return [] }
        var table = Array(repeating: Array(repeating: 0, count: m + 1), count: n + 1)
        for i in stride(from: n - 1, through: 0, by: -1) {
            for j in stride(from: m - 1, through: 0, by: -1) {
                table[i][j] = a[i] == b[j] ? table[i + 1][j + 1] + 1 : max(table[i + 1][j], table[i][j + 1])
            }
        }
        var pairs: [(Int, Int)] = []
        var i = 0, j = 0
        while i < n, j < m {
            if a[i] == b[j] {
                pairs.append((i, j))
                i += 1
                j += 1
            } else if table[i + 1][j] >= table[i][j + 1] {
                i += 1
            } else {
                j += 1
            }
        }
        return pairs
    }
}
