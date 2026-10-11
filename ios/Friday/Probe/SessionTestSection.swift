import AVFoundation
import FridayCore
import SwiftUI

/// Phase 4 phone test: start a session, dictate, play it back.
/// Proves the pre-roll keeps the first word and that music and AirPods are left alone.
struct SessionTestSection: View {
    let session: Session
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
                        _ = session.finishDictation()
                    } else {
                        session.startDictation()
                    }
                }
                .buttonStyle(.borderedProminent)
                .tint(session.state == .dictating ? Palette.stop : Palette.accent)
                .disabled(!(session.state == .holding || session.state == .dictating))
            }
            .frame(maxWidth: .infinity)

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
            2. Tap Dictate and start talking at once. Stop, then play it back: your first word should be there.
            3. Try again with AirPods in: music should stay full quality.
            4. Take or make a call, hang up: the session should come back by itself.
            """)
        }
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
