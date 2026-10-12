import ActivityKit
import AppIntents
import SwiftUI
import WidgetKit

@main
struct FridayLiveBundle: WidgetBundle {
    var body: some Widget {
        FridayLiveActivity()
        StartFridayControl()
        TalkToFridayControl()
    }
}

/// "Friday on" in the Dynamic Island and on the Lock Screen while a session runs. While you talk
/// to Friday it shows Listening (with ✕ / ✓), Thinking, then what it did.
struct FridayLiveActivity: Widget {
    var body: some WidgetConfiguration {
        ActivityConfiguration(for: FridayActivityAttributes.self) { context in
            LockScreenCard(state: context.state)
                .activityBackgroundTint(Color.black)
                .activitySystemActionForegroundColor(.white)
        } dynamicIsland: { context in
            let state = context.state
            return DynamicIsland {
                DynamicIslandExpandedRegion(.leading) {
                    Image(systemName: icon(state)).font(.title3.weight(.semibold)).padding(.leading, 6)
                }
                DynamicIslandExpandedRegion(.center) {
                    Text(title(state)).font(.headline).lineLimit(1)
                }
                DynamicIslandExpandedRegion(.trailing) {
                    if state.phase == nil {
                        Text(state.startedAt, style: .timer)
                            .font(.subheadline.monospacedDigit())
                            .multilineTextAlignment(.trailing)
                            .frame(width: 52)
                    }
                }
                DynamicIslandExpandedRegion(.bottom) {
                    BottomRow(state: state)
                }
            } compactLeading: {
                Image(systemName: icon(state))
            } compactTrailing: {
                Text(short(state)).font(.caption2.weight(.semibold))
            } minimal: {
                Image(systemName: icon(state))
            }
        }
    }
}

private func icon(_ state: FridayActivityAttributes.ContentState) -> String {
    switch state.phase {
    case "listening": "mic.fill"
    case "thinking": "ellipsis"
    case "done": "checkmark"
    default: "waveform"
    }
}

private func title(_ state: FridayActivityAttributes.ContentState) -> String {
    switch state.phase {
    case "listening": "Listening…"
    case "thinking": "Thinking…"
    case "done": "Done"
    default: "Friday on"
    }
}

private func short(_ state: FridayActivityAttributes.ContentState) -> String {
    switch state.phase {
    case "listening": "Listening"
    case "thinking": "…"
    case "done": "Done"
    default: "On"
    }
}

/// ✕ / ✓ while listening, or what Friday did.
private struct BottomRow: View {
    let state: FridayActivityAttributes.ContentState

    var body: some View {
        if state.phase == "listening" {
            HStack(spacing: 14) {
                Button(intent: CancelTalkIntent()) {
                    Image(systemName: "xmark").font(.headline).frame(maxWidth: .infinity, minHeight: 40)
                }
                .tint(.white.opacity(0.18))
                Button(intent: FinishTalkIntent()) {
                    Image(systemName: "checkmark").font(.headline).foregroundStyle(.black).frame(maxWidth: .infinity, minHeight: 40)
                }
                .tint(.white)
            }
            .buttonStyle(.borderedProminent)
            .buttonBorderShape(.capsule)
        } else if let message = state.message, state.phase == "done" {
            Text(message).font(.subheadline).lineLimit(3).frame(maxWidth: .infinity, alignment: .leading)
        }
    }
}

private struct LockScreenCard: View {
    let state: FridayActivityAttributes.ContentState

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 12) {
                Image(systemName: icon(state)).font(.title3.weight(.semibold))
                Text(title(state)).font(.headline)
                Spacer()
                if state.phase == nil {
                    Text(state.startedAt, style: .timer)
                        .font(.subheadline.monospacedDigit())
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.trailing)
                        .frame(width: 64)
                }
            }
            BottomRow(state: state)
        }
        .foregroundStyle(.white)
        .padding(.horizontal, 20)
        .padding(.vertical, 16)
    }
}

/// Control Center / Lock Screen / Action button control.
struct StartFridayControl: ControlWidget {
    var body: some ControlWidgetConfiguration {
        StaticControlConfiguration(kind: "com.samarth.friday.start") {
            ControlWidgetButton(action: StartFridayIntent()) {
                Label("Start Friday", systemImage: "waveform")
            }
        }
        .displayName("Start Friday")
        .description("Turns on Friday's mic.")
    }
}

/// Control Center / Lock Screen: talk to Friday (opens Friday briefly to listen).
struct TalkToFridayControl: ControlWidget {
    var body: some ControlWidgetConfiguration {
        StaticControlConfiguration(kind: "com.samarth.friday.talk") {
            ControlWidgetButton(action: TalkToFridayIntent()) {
                Label("Talk to Friday", systemImage: "mic.fill")
            }
        }
        .displayName("Talk to Friday")
        .description("Tell Friday what to add, cancel or remember.")
    }
}
