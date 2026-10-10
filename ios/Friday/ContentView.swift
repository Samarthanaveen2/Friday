import SwiftUI
import UIKit

/// Install probe report screen. It answers: does each risky thing work with free signing?
struct ContentView: View {
    private let session = ProbeSession.shared

    var body: some View {
        TimelineView(.periodic(from: .now, by: 1)) { _ in
            NavigationStack {
                List {
                    appGroupSection
                    keyboardSection
                    micSection
                    intentSection
                    signingSection
                    Section {
                        Button("Copy report") { UIPasteboard.general.string = report() }
                    }
                }
                .navigationTitle("Friday probe")
            }
        }
    }

    // MARK: - Sections

    private var appGroupSection: some View {
        Section("1 · App Group (app ↔ keyboard)") {
            row("Group name", AppGroup.identifier)
            row("Shared folder", AppGroup.containerURL == nil ? "❌ missing" : "✅ found")
            row("Names tried", AppGroup.diagnostics)
        }
    }

    private var keyboardSection: some View {
        let kb = AppGroup.read("keyboard.json")
        let opened = AppGroup.read("opened.json")
        return Section("2 · Keyboard") {
            row("Keyboard last seen", kb == nil ? "never — add it in Settings → Keyboards" : AppGroup.ageText(kb?["t"]))
            row("Full Access", kb == nil ? "?" : (kb?["fullAccess"] == 1 ? "✅ on" : "❌ off"))
            row("Keyboard opened Friday", opened == nil ? "not yet" : "✅ \(Int(opened?["count"] ?? 0))× (\(AppGroup.ageText(opened?["t"])))")
        }
    }

    private var micSection: some View {
        let hb = AppGroup.read("heartbeat.json")
        return Section("3 · Background mic session") {
            Button(session.running ? "Stop session" : "Start session") {
                session.running ? session.stop() : session.start()
            }
            row("State", session.running ? "🟢 running" : "⚪️ stopped")
            if let started = session.startedAt, session.running {
                row("Running for", "\(Int(Date().timeIntervalSince(started))) s")
            }
            row("Heartbeats", "\(session.beats)")
            row("Longest gap", String(format: "%.1f s (should stay near 1)", session.maxGap))
            row("Engine restarts", "\(session.restarts)")
            row("Interruptions", "\(session.interruptions)")
            row("Last heartbeat", AppGroup.ageText(hb?["t"]))
            row("Live Activity", session.activityStatus)
            if let e = session.lastError { row("Error", e) }
            Text("Test: start the session, open another app for 2 minutes, come back. Longest gap should stay small.")
                .font(.footnote).foregroundStyle(.secondary)
        }
    }

    private var intentSection: some View {
        let i = AppGroup.read("intent.json")
        return Section("4 · Start from outside the app") {
            row("Ran from Control Center / Action button / Shortcuts", i == nil ? "not yet" : "✅ \(Int(i?["count"] ?? 0))× (\(AppGroup.ageText(i?["t"])))")
        }
    }

    private var signingSection: some View {
        Section("5 · Signing") {
            row("Expires", Signing.expiryText)
        }
    }

    // MARK: - Helpers

    private func row(_ label: String, _ value: String) -> some View {
        HStack(alignment: .top) {
            Text(label)
            Spacer()
            Text(value).foregroundStyle(.secondary).multilineTextAlignment(.trailing)
        }
        .font(.callout)
    }

    private func report() -> String {
        let kb = AppGroup.read("keyboard.json")
        let hb = AppGroup.read("heartbeat.json")
        let opened = AppGroup.read("opened.json")
        let i = AppGroup.read("intent.json")
        return """
        Friday probe
        group: \(AppGroup.identifier) · folder: \(AppGroup.containerURL == nil ? "MISSING" : "ok")
        names tried: \(AppGroup.diagnostics.replacingOccurrences(of: "\n", with: " | "))
        keyboard seen: \(AppGroup.ageText(kb?["t"])) · full access: \(kb?["fullAccess"] == 1 ? "yes" : "no")
        keyboard opened app: \(Int(opened?["count"] ?? 0))×
        session running: \(session.running) · beats: \(session.beats) · max gap: \(String(format: "%.1f", session.maxGap)) s · restarts: \(session.restarts) · interruptions: \(session.interruptions)
        last heartbeat: \(AppGroup.ageText(hb?["t"]))
        live activity: \(session.activityStatus)
        intent ran: \(Int(i?["count"] ?? 0))×
        signing expires: \(Signing.expiryText)
        """
    }
}
