import AVFoundation
import FridayCore
import SwiftUI

/// Phase 4 phone test: start a session, dictate, play it back.
/// Proves the pre-roll keeps the first word and that music and AirPods are left alone.
struct SessionTestSection: View {
    let session: Session
    @State private var pipeline = DictationPipeline.shared
    @State private var player: AVAudioPlayer?
    @State private var playing = false

    var body: some View {
        Section {
            HStack {
                Text("Session")
                Spacer()
                Text(stateLabel).foregroundStyle(.secondary)
            }

            if session.state == .dictating {
                Waveform(levels: session.levels.suffix(32).map { CGFloat($0) }, height: 36, barWidth: 3)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 4)
            }

            HStack(spacing: 10) {
                Button(session.running ? "End session" : "Start session") {
                    Haptics.tap()
                    if session.running { session.stop() } else { Task { await session.start(source: .app) } }
                }
                .buttonStyle(.bordered)

                Button(session.state == .dictating ? "Stop" : "Dictate") {
                    Haptics.tap()
                    if session.state == .dictating {
                        Task {
                            _ = await pipeline.finish()
                            Haptics.success()
                        }
                    } else {
                        _ = pipeline.begin()
                    }
                }
                .buttonStyle(.borderedProminent)
                .tint(session.state == .dictating ? Palette.stop : Palette.accent)
                .disabled(!(session.state == .holding || session.state == .dictating) || pipeline.working)
            }
            .frame(maxWidth: .infinity)

            if pipeline.working {
                HStack(spacing: 10) {
                    WorkingDots()
                    Text("Writing…").foregroundStyle(.secondary)
                }
            } else if let outcome = pipeline.last {
                VStack(alignment: .leading, spacing: 6) {
                    Text(outcome.nothing ? "Didn't catch that" : outcome.text)
                        .font(.body)
                        .textSelection(.enabled)
                    if !outcome.nothing, outcome.raw != outcome.text {
                        Text("Heard: \(outcome.raw)").font(.footnote).foregroundStyle(.secondary)
                    }
                    Text(outcome.timings.line).font(.caption.monospacedDigit()).foregroundStyle(Palette.accent)
                    if !outcome.notes.isEmpty {
                        Text(outcome.notes.joined(separator: " · ")).font(.caption2).foregroundStyle(.secondary)
                    }
                    if let cloud = outcome.cloudText {
                        Text("Groq heard: \(cloud)").font(.caption2).foregroundStyle(.secondary)
                    }
                    if let device = outcome.deviceText, !device.isEmpty {
                        Text("iPhone heard: \(device)").font(.caption2).foregroundStyle(.secondary)
                    }
                    copyButton(outcome.report)
                }
                .padding(.vertical, 2)
            } else if let saved = DictationPipeline.savedReport {
                VStack(alignment: .leading, spacing: 6) {
                    Text("Last dictation").font(.subheadline)
                    Text(saved).font(.caption2).foregroundStyle(.secondary).textSelection(.enabled)
                    copyButton(saved)
                }
                .padding(.vertical, 2)
            }

            let trail = IntentTrail.read()
            if !trail.isEmpty {
                VStack(alignment: .leading, spacing: 6) {
                    Text("Last Talk to Friday").font(.subheadline)
                    Text(trail).font(.caption2.monospaced()).foregroundStyle(.secondary).textSelection(.enabled)
                    copyButton(trail)
                }
                .padding(.vertical, 2)
            }

            if let recording = session.lastRecording {
                HStack {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(summary(recording)).font(.subheadline)
                        Text("Includes \(String(format: "%.1f", session.lastPreRollSeconds)) s from before you tapped")
                            .font(.footnote).foregroundStyle(.secondary)
                    }
                    Spacer()
                    Button {
                        play(recording)
                    } label: {
                        Image(systemName: playing ? "stop.circle.fill" : "play.circle.fill").font(.title)
                    }
                    .buttonStyle(.plain)
                    .foregroundStyle(Palette.accent)
                    .accessibilityLabel(playing ? "Stop playback" : "Play recording")
                }
            }

            Picker("Session lasts", selection: Binding(get: { session.length }, set: { session.length = $0 })) {
                ForEach(SessionLength.allCases) { Text($0.label).tag($0) }
            }
        } header: {
            Text("Session test")
        } footer: {
            Text("""
            1. Play music in Spotify, then Start session. Music should keep playing at full volume.
            2. Tap Dictate and start talking at once. Stop: the typed text and a timing line appear. Play it back to check your first word is there.
            3. Try again with AirPods in: music should stay full quality.
            4. Take or make a call, hang up: the session should come back by itself.
            """)
        }
    }

    /// Copies every step of the last dictation, to paste into a chat when something looks wrong.
    private func copyButton(_ report: String) -> some View {
        Button {
            UIPasteboard.general.string = report
            Haptics.success()
        } label: {
            Label("Copy steps", systemImage: "doc.on.doc").font(.footnote)
        }
        .buttonStyle(.borderless)
    }

    private var stateLabel: String {
        switch session.state {
        case .off: "Off"
        case .holding: "On"
        case .dictating: "Recording \(String(format: "%.0f", session.recordedSeconds)) s"
        case .needsRestart: "Stopped — tap Start session"
        }
    }

    private func summary(_ recording: Recording) -> String {
        let speech = recording.hasSpeech ? "speech heard" : "no speech heard"
        let trimmed = recording.trimmed().duration
        return String(format: "%.1f s · %@ · %.1f s after trimming", recording.duration, speech, trimmed)
    }

    private func play(_ recording: Recording) {
        if playing {
            player?.stop()
            playing = false
            return
        }
        guard let player = try? AVAudioPlayer(data: WAV.encode(recording.samples)) else { return }
        self.player = player
        player.play()
        playing = true
        let seconds = player.duration
        Task {
            try? await Task.sleep(for: .seconds(seconds))
            playing = false
        }
    }
}
