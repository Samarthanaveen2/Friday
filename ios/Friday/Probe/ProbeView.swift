import SwiftUI

/// Setup check screen: one tap for the mic, then a ✓/✕ list of what this phone allows.
struct ProbeView: View {
    let model: ProbeModel
    /// Inside Settings' navigation: no own navigation stack or Settings button.
    var embedded = false
    @State private var session = Session.shared
    @State private var copied = false

    var body: some View {
        if embedded {
            content
        } else {
            NavigationStack {
                content
                    .toolbar {
                        ToolbarItem(placement: .topBarTrailing) {
                            NavigationLink { SettingsView() } label: { Image(systemName: "gearshape") }
                                .accessibilityLabel("Settings")
                        }
                    }
            }
        }
    }

    private var content: some View {
        List {
            Section {
                MicCard(session: session)
                    .listRowInsets(EdgeInsets())
                    .listRowBackground(Color.clear)
            }
            SessionTestSection(session: session)
            ForEach(model.sections) { section in
                Section(section.id) {
                    ForEach(section.checks) { CheckRow(check: $0) }
                }
            }
            Section {
                Button {
                    UIPasteboard.general.string = model.reportText
                    Haptics.success()
                    withAnimation(Motion.fade) { copied = true }
                } label: {
                    Label(copied ? "Copied — paste it to Claude" : "Copy report",
                          systemImage: copied ? "checkmark" : "doc.on.doc")
                        .frame(maxWidth: .infinity)
                }
            }
        }
        .listStyle(.insetGrouped)
        .navigationTitle("Setup check")
        .animation(Motion.spring, value: session.running)
        .task {
            await model.checkSpeech()
        }
        .task {
            while !Task.isCancelled {
                model.refresh()
                try? await Task.sleep(for: .seconds(1))
            }
        }
    }
}

private struct MicCard: View {
    let session: Session

    var body: some View {
        VStack(spacing: 14) {
            Button {
                Haptics.tap()
                if session.running {
                    session.stop()
                } else {
                    Task { await session.start(source: .app) }
                }
            } label: {
                ZStack {
                    Circle()
                        .fill(session.running ? Theme.stop : Theme.accent)
                        .frame(width: Theme.micSize, height: Theme.micSize)
                        .shadow(color: (session.running ? Theme.stop : Theme.accent).opacity(0.35), radius: 14, y: 6)
                    Image(systemName: session.running ? "stop.fill" : "mic.fill")
                        .font(.system(size: 28, weight: .semibold))
                        .foregroundStyle(.white)
                        .contentTransition(.symbolEffect(.replace))
                }
            }
            .buttonStyle(.plain)
            .accessibilityLabel(session.running ? "Turn mic off" : "Turn mic on")

            LevelBars(level: session.running ? session.level : 0)
                .frame(height: 22)
                .opacity(session.running ? 1 : 0.3)

            Text(session.running ? "Mic on" : "Mic off")
                .font(.footnote.weight(.medium))
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 18)
    }
}

/// A small voice-memo style meter.
private struct LevelBars: View {
    let level: Float
    private let weights: [Float] = [0.35, 0.6, 0.85, 1, 0.85, 0.6, 0.35]

    var body: some View {
        HStack(spacing: 4) {
            ForEach(weights.indices, id: \.self) { i in
                Capsule()
                    .fill(Theme.accent)
                    .frame(width: 4, height: max(4, CGFloat(level * weights[i]) * 22))
            }
        }
        .animation(.easeOut(duration: 0.12), value: level)
    }
}

private struct CheckRow: View {
    let check: Check

    var body: some View {
        HStack(alignment: .firstTextBaseline, spacing: 12) {
            icon
            VStack(alignment: .leading, spacing: 3) {
                Text(check.title)
                    .font(.body)
                Text(check.detail)
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                    .textSelection(.enabled)
                if let hint = check.hint {
                    Text(hint)
                        .font(.footnote)
                        .foregroundStyle(Theme.accent)
                }
            }
        }
        .padding(.vertical, 2)
    }

    @ViewBuilder private var icon: some View {
        switch check.status {
        case .pass:
            Image(systemName: "checkmark.circle.fill").foregroundStyle(Theme.pass)
        case .fail:
            Image(systemName: "xmark.circle.fill").foregroundStyle(Theme.stop)
        case .waiting:
            Image(systemName: "circle.dashed").foregroundStyle(.tertiary)
        }
    }
}
