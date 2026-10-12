import FridayCore
import SwiftUI

/// Settings → AI usage: each model's share of today's free allowance, whether it's resting
/// after a limit, and which one handled your last dictation.
struct UsageSection: View {
    @State private var book = UsageBook.shared

    private struct Row: Identifiable {
        let id: String
        let name: String
        let quota: String
    }

    private let rows = [
        Row(id: Models.whisper, name: "Speech · Whisper", quota: "groq.whisper"),
        Row(id: Models.groqCleanup, name: "Cleanup · Qwen 3.8 27B (main)", quota: "groq.chat"),
        Row(id: Models.groqCleanupBackup, name: "Cleanup · GPT-OSS 120B (backup)", quota: "groq.chat.backup"),
        Row(id: Models.groqCleanupBackup2, name: "Cleanup · GPT-OSS 20B (backup 2)", quota: "groq.chat.backup2"),
    ]

    var body: some View {
        Section {
            ForEach(rows) { row in
                let today = book.today(row.id)
                let resting = QuotaBook.shared.restingUntil(row.quota)
                VStack(alignment: .leading, spacing: 6) {
                    HStack(alignment: .firstTextBaseline) {
                        Text(row.name).font(.subheadline.weight(.semibold))
                        if row.id == book.lastCleanup || row.id == book.lastSpeech {
                            Text("last used").font(.caption2.weight(.semibold)).foregroundStyle(Palette.accent)
                        }
                        Spacer()
                        Text("\(Int((today.used * 100).rounded()))%")
                            .font(.subheadline.monospacedDigit().weight(.semibold))
                            .foregroundStyle(color(today.used, resting: resting != nil))
                    }
                    ProgressView(value: today.used)
                        .tint(color(today.used, resting: resting != nil))
                    Text(detail(today, resting: resting)).font(.caption).foregroundStyle(.secondary)
                }
                .padding(.vertical, 2)
            }
            HStack {
                Text("Last cleanup by")
                Spacer()
                Text(name(book.lastCleanup)).foregroundStyle(.secondary)
            }
            .font(.subheadline)
        } header: {
            Text("AI usage today")
        } footer: {
            Text("Free daily allowance used. Groq limits both requests and tokens; anything else using the same Groq key counts too. Resets every day. When one model is resting, Friday moves to the next.")
        }
    }

    private func detail(_ u: ModelUsage, resting: Date?) -> String {
        if let resting {
            let back = "back at \(resting.formatted(date: .omitted, time: .shortened))"
            guard let kind = u.limitKind else { return "Resting after its limit · \(back)" }
            let size = u.limitValue.map { " (\($0 >= 1000 ? "\($0 / 1000)K" : "\($0)"))" } ?? ""
            let what = kind.replacingOccurrences(of: " per day", with: " for today")
                .replacingOccurrences(of: " per minute", with: " for this minute")
                .replacingOccurrences(of: " per hour", with: " for this hour")
            return "Used up its \(what)\(size) · \(back)"
        }
        guard u.requests > 0 || u.requestsLeft != nil else { return "Not used today" }
        var parts = ["\(u.requests) request\(u.requests == 1 ? "" : "s")"]
        if u.tokens > 0 { parts.append(u.tokens >= 1000 ? "\(u.tokens / 1000)K tokens" : "\(u.tokens) tokens") }
        if u.audioSeconds > 0 { parts.append("\(Int(u.audioSeconds / 60)) min audio") }
        if let left = u.requestsLeft { parts.append("\(left) requests left") }
        if !u.lastOK { parts.append("last call failed") }
        return parts.joined(separator: " · ")
    }

    private func color(_ used: Double, resting: Bool) -> Color {
        if resting || used >= 0.9 { return Palette.stop }
        if used >= 0.7 { return .orange }
        return Palette.accent
    }

    private func name(_ model: String?) -> String {
        switch model ?? "" {
        case "": "—"
        case "rules": "Simple rules (no AI)"
        case "apple": "Apple on-device AI"
        case Models.groqCleanup: "Qwen 3.8 27B"
        case Models.groqCleanupBackup: "GPT-OSS 120B"
        case Models.groqCleanupBackup2: "GPT-OSS 20B"
        case Models.geminiCleanup: "Gemini Flash-Lite"
        case let other: other
        }
    }
}
